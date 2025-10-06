#ifndef STORAGE_ZEPHYR_H
#define STORAGE_ZEPHYR_H

#include <zephyr/kernel.h>
#include <zephyr/storage/flash_map.h>
#include <zephyr/fs/fs.h>

class Storage_Zephyr {
public:
    Storage_Zephyr();
    virtual ~Storage_Zephyr();
    
    bool init();
    bool loadRom(const char* filename, uint8_t* buffer, size_t max_size);
    bool saveFile(const char* filename, const uint8_t* data, size_t size);
    bool loadFile(const char* filename, uint8_t* buffer, size_t max_size, size_t* actual_size = nullptr);
    bool fileExists(const char* filename);
    bool deleteFile(const char* filename);
    
    // List files in storage
    bool listFiles(void (*callback)(const char* filename, size_t size, void* user_data), void* user_data);

private:
    static struct fs_mount_t fs_mnt;
    bool initialized;
    
    const char* getFullPath(const char* filename);
    static char full_path_buffer[256];
};

#endif // STORAGE_ZEPHYR_H