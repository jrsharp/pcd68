#include "Storage_Zephyr.h"
#include <zephyr/logging/log.h>
#include <zephyr/fs/littlefs.h>
#include <string.h>

LOG_MODULE_DECLARE(pcd68_main);

// Static members
struct fs_mount_t Storage_Zephyr::fs_mnt;
char Storage_Zephyr::full_path_buffer[256];

// LittleFS configuration
FS_LITTLEFS_DECLARE_DEFAULT_CONFIG(storage);

Storage_Zephyr::Storage_Zephyr() : initialized(false)
{
}

Storage_Zephyr::~Storage_Zephyr()
{
}

bool Storage_Zephyr::init()
{
    if (initialized) {
        return true;
    }
    
    LOG_INF("Initializing storage");
    
    // Set up mount point
    fs_mnt.type = FS_LITTLEFS;
    fs_mnt.fs_data = &storage;
    fs_mnt.storage_dev = (void *)FLASH_AREA_ID(storage);
    fs_mnt.mnt_point = "/pcd68";
    
    int ret = fs_mount(&fs_mnt);
    if (ret < 0) {
        LOG_ERR("Failed to mount filesystem: %d", ret);
        
        // Try to format if mount failed
        LOG_WRN("Attempting to format storage...");
        ret = fs_mkfs(FS_LITTLEFS, (uintptr_t)FLASH_AREA_ID(storage), &storage, 0);
        if (ret < 0) {
            LOG_ERR("Failed to format filesystem: %d", ret);
            return false;
        }
        
        // Try mounting again
        ret = fs_mount(&fs_mnt);
        if (ret < 0) {
            LOG_ERR("Failed to mount formatted filesystem: %d", ret);
            return false;
        }
    }
    
    LOG_INF("Filesystem mounted at %s", fs_mnt.mnt_point);
    
    // Create ROMs directory if it doesn't exist
    struct fs_file_t file;
    fs_file_t_init(&file);
    
    ret = fs_open(&file, "/pcd68/roms", FS_O_READ);
    if (ret < 0) {
        // Directory doesn't exist, create it
        ret = fs_mkdir("/pcd68/roms");
        if (ret < 0) {
            LOG_WRN("Failed to create roms directory: %d", ret);
        } else {
            LOG_INF("Created /pcd68/roms directory");
        }
    } else {
        fs_close(&file);
    }
    
    initialized = true;
    return true;
}

const char* Storage_Zephyr::getFullPath(const char* filename)
{
    snprintf(full_path_buffer, sizeof(full_path_buffer), "/pcd68/roms/%s", filename);
    return full_path_buffer;
}

bool Storage_Zephyr::loadRom(const char* filename, uint8_t* buffer, size_t max_size)
{
    if (!initialized) {
        return false;
    }
    
    const char* full_path = getFullPath(filename);
    
    struct fs_file_t file;
    fs_file_t_init(&file);
    
    int ret = fs_open(&file, full_path, FS_O_READ);
    if (ret < 0) {
        LOG_WRN("Failed to open ROM file %s: %d", filename, ret);
        return false;
    }
    
    // Get file size
    struct fs_dirent entry;
    ret = fs_stat(full_path, &entry);
    if (ret < 0) {
        LOG_ERR("Failed to get file stats: %d", ret);
        fs_close(&file);
        return false;
    }
    
    size_t file_size = entry.size;
    if (file_size > max_size) {
        LOG_ERR("ROM file too large: %zu bytes (max %zu)", file_size, max_size);
        fs_close(&file);
        return false;
    }
    
    // Read file
    ssize_t bytes_read = fs_read(&file, buffer, file_size);
    fs_close(&file);
    
    if (bytes_read != file_size) {
        LOG_ERR("Failed to read complete ROM file: %zd/%zu bytes", bytes_read, file_size);
        return false;
    }
    
    LOG_INF("Loaded ROM %s: %zu bytes", filename, file_size);
    return true;
}

bool Storage_Zephyr::saveFile(const char* filename, const uint8_t* data, size_t size)
{
    if (!initialized) {
        return false;
    }
    
    const char* full_path = getFullPath(filename);
    
    struct fs_file_t file;
    fs_file_t_init(&file);
    
    int ret = fs_open(&file, full_path, FS_O_CREATE | FS_O_WRITE | FS_O_TRUNC);
    if (ret < 0) {
        LOG_ERR("Failed to create file %s: %d", filename, ret);
        return false;
    }
    
    ssize_t bytes_written = fs_write(&file, data, size);
    fs_close(&file);
    
    if (bytes_written != size) {
        LOG_ERR("Failed to write complete file: %zd/%zu bytes", bytes_written, size);
        return false;
    }
    
    LOG_INF("Saved file %s: %zu bytes", filename, size);
    return true;
}

bool Storage_Zephyr::loadFile(const char* filename, uint8_t* buffer, size_t max_size, size_t* actual_size)
{
    if (!initialized) {
        return false;
    }
    
    const char* full_path = getFullPath(filename);
    
    struct fs_file_t file;
    fs_file_t_init(&file);
    
    int ret = fs_open(&file, full_path, FS_O_READ);
    if (ret < 0) {
        return false;
    }
    
    ssize_t bytes_read = fs_read(&file, buffer, max_size);
    fs_close(&file);
    
    if (bytes_read < 0) {
        return false;
    }
    
    if (actual_size) {
        *actual_size = bytes_read;
    }
    
    return true;
}

bool Storage_Zephyr::fileExists(const char* filename)
{
    if (!initialized) {
        return false;
    }
    
    const char* full_path = getFullPath(filename);
    
    struct fs_dirent entry;
    return fs_stat(full_path, &entry) == 0;
}

bool Storage_Zephyr::deleteFile(const char* filename)
{
    if (!initialized) {
        return false;
    }
    
    const char* full_path = getFullPath(filename);
    
    int ret = fs_unlink(full_path);
    return ret == 0;
}

bool Storage_Zephyr::listFiles(void (*callback)(const char* filename, size_t size, void* user_data), void* user_data)
{
    if (!initialized || !callback) {
        return false;
    }
    
    struct fs_dir_t dir;
    fs_dir_t_init(&dir);
    
    int ret = fs_opendir(&dir, "/pcd68/roms");
    if (ret < 0) {
        return false;
    }
    
    struct fs_dirent entry;
    while (fs_readdir(&dir, &entry) == 0) {
        if (entry.name[0] == '\0') {
            break;  // End of directory
        }
        
        if (entry.type == FS_DIR_ENTRY_FILE) {
            callback(entry.name, entry.size, user_data);
        }
    }
    
    fs_closedir(&dir);
    return true;
}