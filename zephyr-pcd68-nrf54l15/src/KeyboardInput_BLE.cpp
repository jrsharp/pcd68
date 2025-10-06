#include "KeyboardInput_BLE.h"
#include "KCTL.h"
#include <zephyr/logging/log.h>
#include <zephyr/settings/settings.h>

LOG_MODULE_DECLARE(pcd68_main);

// Static instance for callbacks
KeyboardInput_BLE* KeyboardInput_BLE::instance = nullptr;

// HID keycode to ASCII mapping (same as Zephyr version)
const uint8_t KeyboardInput_BLE::hid_to_ascii[256] = {
    0, 0, 0, 0,           // 0x00-0x03: Reserved
    'a', 'b', 'c', 'd',   // 0x04-0x07: A-D
    'e', 'f', 'g', 'h',   // 0x08-0x0B: E-H
    'i', 'j', 'k', 'l',   // 0x0C-0x0F: I-L
    'm', 'n', 'o', 'p',   // 0x10-0x13: M-P
    'q', 'r', 's', 't',   // 0x14-0x17: Q-T
    'u', 'v', 'w', 'x',   // 0x18-0x1B: U-X
    'y', 'z',             // 0x1C-0x1D: Y-Z
    '1', '2', '3', '4',   // 0x1E-0x21: 1-4
    '5', '6', '7', '8',   // 0x22-0x25: 5-8
    '9', '0',             // 0x26-0x27: 9-0
    '\r', '\x1B', '\b',   // 0x28-0x2A: Enter, Escape, Backspace
    '\t', ' ',            // 0x2B-0x2C: Tab, Space
    '-', '=',             // 0x2D-0x2E: - =
    '[', ']',             // 0x2F-0x30: [ ]
    '\\', 0,              // 0x31-0x32: \ (non-US)
    ';', '\'',            // 0x33-0x34: ; '
    '`',                  // 0x35: `
    ',', '.', '/',        // 0x36-0x38: , . /
    0,                    // 0x39: Caps Lock
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  // 0x3A-0x45: F1-F12
    0, 0, 0,              // 0x46-0x48: Print Screen, Scroll Lock, Pause
    0, 0, 0,              // 0x49-0x4B: Insert, Home, Page Up
    0, 0, 0,              // 0x4C-0x4E: Delete, End, Page Down
    0, 0, 0, 0,           // 0x4F-0x52: Arrow keys
    0,                    // 0x53: Num Lock
    '/', '*', '-', '+',   // 0x54-0x57: Keypad operators
    '\r',                 // 0x58: Keypad Enter
    '1', '2', '3', '4',   // 0x59-0x5C: Keypad 1-4
    '5', '6', '7', '8',   // 0x5D-0x60: Keypad 5-8
    '9', '0', '.',        // 0x61-0x63: Keypad 9, 0, .
    // Rest initialized to 0
};

// Forward declaration for scan callbacks
extern "C" {
    static void scan_filter_match_wrapper(struct bt_scan_device_info *device_info,
                                         struct bt_scan_filter_match *filter_match,
                                         bool connectable);
    static void scan_filter_no_match_wrapper(struct bt_scan_device_info *device_info,
                                            bool connectable);
    static void scan_connecting_error_wrapper(struct bt_scan_device_info *device_info);
    static void scan_connecting_wrapper(struct bt_scan_device_info *device_info,
                                       struct bt_conn *conn);
}

// C wrapper functions for connection callbacks
extern "C" {
    static void connected_cb_wrapper(struct bt_conn *conn, uint8_t err) {
        KeyboardInput_BLE::connected_cb(conn, err);
    }
    
    static void disconnected_cb_wrapper(struct bt_conn *conn, uint8_t reason) {
        KeyboardInput_BLE::disconnected_cb(conn, reason);
    }
}

// Connection callbacks
BT_CONN_CB_DEFINE(conn_callbacks) = {
    .connected = connected_cb_wrapper,
    .disconnected = disconnected_cb_wrapper,
};

// C wrapper functions for scan callbacks
static void scan_filter_match_wrapper(struct bt_scan_device_info *device_info,
                                     struct bt_scan_filter_match *filter_match,
                                     bool connectable) {
    KeyboardInput_BLE::scan_filter_match(device_info, filter_match, connectable);
}

static void scan_filter_no_match_wrapper(struct bt_scan_device_info *device_info,
                                        bool connectable) {
    KeyboardInput_BLE::scan_filter_no_match(device_info, connectable);
}

static void scan_connecting_error_wrapper(struct bt_scan_device_info *device_info) {
    KeyboardInput_BLE::scan_connecting_error(device_info);
}

static void scan_connecting_wrapper(struct bt_scan_device_info *device_info,
                                   struct bt_conn *conn) {
    KeyboardInput_BLE::scan_connecting(device_info, conn);
}

// Scan callbacks using Nordic SDK macro
BT_SCAN_CB_INIT(scan_cb, scan_filter_match_wrapper, scan_filter_no_match_wrapper,
                scan_connecting_error_wrapper, scan_connecting_wrapper);

KeyboardInput_BLE::KeyboardInput_BLE()
    : keyboardController(nullptr), current_conn(nullptr),
      scanning(false), connected(false), ready(false)
{
    memset(&current_report, 0, sizeof(current_report));
    memset(&hogp_client, 0, sizeof(hogp_client));
    instance = this;
}

KeyboardInput_BLE::~KeyboardInput_BLE()
{
    if (current_conn) {
        bt_conn_disconnect(current_conn, BT_HCI_ERR_REMOTE_USER_TERM_CONN);
    }
    instance = nullptr;
}

int KeyboardInput_BLE::init()
{
    LOG_INF("Initializing BLE GATT HID keyboard host");
    
    int err;
    
    // Initialize Bluetooth
    err = bt_enable(NULL);
    if (err) {
        LOG_ERR("Bluetooth init failed (err %d)", err);
        return err;
    }
    
    LOG_INF("Bluetooth initialized");
    
    // Load settings
    if (IS_ENABLED(CONFIG_SETTINGS)) {
        settings_load();
    }
    
    // Initialize HOGP client with init params structure
    struct bt_hogp_init_params hogp_params = {
        .ready_cb = hogp_ready_cb,
        .pm_update_cb = hogp_pm_update_cb,
    };
    bt_hogp_init(&hogp_client, &hogp_params);
    LOG_INF("HOGP client initialized");
    
    // Initialize scanning  
    struct bt_scan_init_param scan_init = {
        .scan_param = NULL,
        .connect_if_match = 1,
        .conn_param = NULL  // Use default connection parameters
    };
    bt_scan_init(&scan_init);
    bt_scan_cb_register(&scan_cb);
    
    // Scan filters disabled to save space
    /*
    err = bt_scan_filter_add(BT_SCAN_FILTER_TYPE_UUID, BT_UUID_HIDS);
    if (err) {
        LOG_ERR("Scanning filters cannot be set (err %d)", err);
        return err;
    }
    
    err = bt_scan_filter_enable(BT_SCAN_UUID_FILTER, false);
    if (err) {
        LOG_ERR("Cannot enable scan filters (err %d)", err);
        return err;
    }
    */
    
    // Start scanning for HID devices
    scan_start();
    
    LOG_INF("BLE keyboard input initialized, scanning for devices...");
    return 0;
}

bool KeyboardInput_BLE::poll()
{
    // BLE operations are event-driven, so polling is minimal
    // We could check connection status or handle reconnection here
    
    if (!connected && !scanning) {
        // Restart scanning if disconnected
        LOG_INF("Restarting scan for HID devices");
        scan_start();
    }
    return true; // Always continue running
}

uint8_t KeyboardInput_BLE::asciiToHID(char ascii)
{
    // Simple ASCII to HID conversion (implement as needed)
    if (ascii >= 'a' && ascii <= 'z') {
        return 0x04 + (ascii - 'a');  // A-Z keys
    }
    if (ascii >= '1' && ascii <= '9') {
        return 0x1E + (ascii - '1');  // 1-9 keys
    }
    if (ascii == '0') return 0x27;
    if (ascii == ' ') return 0x2C;
    if (ascii == '\r' || ascii == '\n') return 0x28;
    if (ascii == '\t') return 0x2B;
    if (ascii == '\b') return 0x2A;
    
    return 0;  // Unknown key
}

char KeyboardInput_BLE::hidToAscii(uint8_t hid)
{
    if (hid < 256) {
        return hid_to_ascii[hid];
    }
    return 0;
}

// Static callback methods
void KeyboardInput_BLE::scan_start()
{
    int err = bt_scan_start(BT_SCAN_TYPE_SCAN_ACTIVE);
    if (err) {
        LOG_ERR("Scanning failed to start (err %d)", err);
    } else {
        LOG_INF("Scanning for HID devices...");
        if (instance) {
            instance->scanning = true;
        }
    }
}

void KeyboardInput_BLE::scan_filter_match(struct bt_scan_device_info *device_info,
                                         struct bt_scan_filter_match *filter_match,
                                         bool connectable)
{
    char addr[BT_ADDR_LE_STR_LEN];
    bt_addr_le_to_str(device_info->recv_info->addr, addr, sizeof(addr));
    
    LOG_INF("HID device found: %s (RSSI %d)", addr, device_info->recv_info->rssi);
    
    // Stop scanning and connect to the first HID device found
    bt_scan_stop();
    if (instance) {
        instance->scanning = false;
    }
    
    LOG_INF("HID keyboard found, connection will be initiated automatically");
}

void KeyboardInput_BLE::scan_filter_no_match(struct bt_scan_device_info *device_info,
                                            bool connectable)
{
    // We can optionally log non-HID devices found
    // For now, just ignore them
}

void KeyboardInput_BLE::scan_connecting_error(struct bt_scan_device_info *device_info)
{
    LOG_WRN("Connection to HID device failed");
    scan_start();  // Restart scanning
}

void KeyboardInput_BLE::scan_connecting(struct bt_scan_device_info *device_info,
                                       struct bt_conn *conn)
{
    LOG_INF("Connecting to HID device...");
    if (instance && !instance->current_conn) {
        instance->current_conn = bt_conn_ref(conn);
    }
}

void KeyboardInput_BLE::connected_cb(struct bt_conn *conn, uint8_t err)
{
    char addr[BT_ADDR_LE_STR_LEN];
    bt_addr_le_to_str(bt_conn_get_dst(conn), addr, sizeof(addr));
    
    if (err) {
        LOG_ERR("Failed to connect to %s (err %d)", addr, err);
        scan_start();  // Restart scanning
        return;
    }
    
    LOG_INF("Connected to HID device: %s", addr);
    
    if (instance) {
        instance->current_conn = bt_conn_ref(conn);
        instance->connected = true;
        instance->scanning = false;
        
        // Set security and start GATT discovery - security temporarily disabled
        // int err = bt_conn_set_security(conn, BT_SECURITY_L2);
        // if (err) {
        //     LOG_ERR("Failed to set security: %d", err);
        gatt_discover(conn);
        // }
    }
}

void KeyboardInput_BLE::disconnected_cb(struct bt_conn *conn, uint8_t reason)
{
    char addr[BT_ADDR_LE_STR_LEN];
    bt_addr_le_to_str(bt_conn_get_dst(conn), addr, sizeof(addr));
    
    LOG_INF("Disconnected from HID device %s (reason %d)", addr, reason);
    
    if (instance && instance->current_conn == conn) {
        // Release HOGP client if active
        if (bt_hogp_assign_check(&instance->hogp_client)) {
            LOG_INF("HIDS client active - releasing");
            bt_hogp_release(&instance->hogp_client);
        }
        
        bt_conn_unref(instance->current_conn);
        instance->current_conn = nullptr;
        instance->connected = false;
        instance->ready = false;
        
        // Restart scanning for new devices
        int err = bt_scan_start(BT_SCAN_TYPE_SCAN_ACTIVE);
        if (err) {
            LOG_ERR("Scanning failed to start (err %d)", err);
        }
    }
}

void KeyboardInput_BLE::security_changed_cb(struct bt_conn *conn, bt_security_t level,
                                           enum bt_security_err err)
{
    char addr[BT_ADDR_LE_STR_LEN];
    bt_addr_le_to_str(bt_conn_get_dst(conn), addr, sizeof(addr));
    
    if (!err) {
        LOG_INF("Security changed: %s level %u", addr, level);
    } else {
        LOG_WRN("Security failed: %s level %u err %d", addr, level, err);
    }
    
    gatt_discover(conn);
}

// GATT Discovery callbacks
void KeyboardInput_BLE::discovery_completed_cb(struct bt_gatt_dm *dm, void *context)
{
    LOG_INF("GATT discovery completed");
    
    if (instance) {
        int err = bt_hogp_handles_assign(dm, &instance->hogp_client);
        if (err) {
            LOG_ERR("Could not init HOGP client object, error: %d", err);
        }
        
        err = bt_gatt_dm_data_release(dm);
        if (err) {
            LOG_ERR("Could not release the discovery data, error: %d", err);
        }
    }
}

void KeyboardInput_BLE::discovery_service_not_found_cb(struct bt_conn *conn, void *context)
{
    LOG_WRN("HIDS service not found");
}

void KeyboardInput_BLE::discovery_error_found_cb(struct bt_conn *conn, int err, void *context)
{
    LOG_ERR("Discovery procedure failed with %d", err);
}

void KeyboardInput_BLE::gatt_discover(struct bt_conn *conn)
{
    if (!instance || !instance->current_conn || conn != instance->current_conn) {
        return;
    }
    
    static const struct bt_gatt_dm_cb discovery_cb = {
        .completed = discovery_completed_cb,
        .service_not_found = discovery_service_not_found_cb,
        .error_found = discovery_error_found_cb,
    };
    
    int err = bt_gatt_dm_start(conn, BT_UUID_HIDS, &discovery_cb, NULL);
    if (err) {
        LOG_ERR("Could not start the discovery procedure, error: %d", err);
    }
}

void KeyboardInput_BLE::hogp_ready_cb(struct bt_hogp *hogp)
{
    LOG_INF("HOGP client ready");
    
    if (instance) {
        instance->ready = true;
        
        // Subscribe to all input reports (like Nordic sample does)
        int err;
        struct bt_hogp_rep_info *rep = NULL;
        
        while (NULL != (rep = bt_hogp_rep_next(hogp, rep))) {
            if (bt_hogp_rep_type(rep) == BT_HIDS_REPORT_TYPE_INPUT) {
                LOG_INF("Subscribe to report id: %u", bt_hogp_rep_id(rep));
                err = bt_hogp_rep_subscribe(hogp, rep, hogp_rep_handler);
                if (err) {
                    LOG_ERR("Subscribe error (%d)", err);
                }
            }
        }
        
        // Also subscribe to boot keyboard report if available
        if (hogp->rep_boot.kbd_inp) {
            LOG_INF("Subscribe to boot keyboard report");
            err = bt_hogp_rep_subscribe(hogp, hogp->rep_boot.kbd_inp, hogp_rep_handler);
            if (err) {
                LOG_ERR("Subscribe error (%d)", err);
            }
        }
    }
}

void KeyboardInput_BLE::hogp_pm_update_cb(struct bt_hogp *hogp)
{
    LOG_DBG("HOGP protocol mode updated");
}

uint8_t KeyboardInput_BLE::hogp_rep_handler(struct bt_hogp *hogp,
                                           struct bt_hogp_rep_info *rep,
                                           uint8_t err,
                                           const uint8_t *data)
{
    if (err) {
        LOG_ERR("HOGP report error: %d", err);
        return BT_GATT_ITER_STOP;
    }
    
    if (!data) {
        return BT_GATT_ITER_STOP;
    }
    
    uint8_t size = bt_hogp_rep_size(rep);
    
    if (instance && size >= 8) {
        LOG_DBG("Received HID report (id: %u, size: %u): %02x %02x %02x %02x %02x %02x %02x %02x",
                bt_hogp_rep_id(rep), size,
                data[0], data[1], data[2], data[3], data[4], data[5], data[6], data[7]);
        
        instance->processKeyboardReport(data, size);
    }
    
    return BT_GATT_ITER_CONTINUE;
}

void KeyboardInput_BLE::processKeyboardReport(const uint8_t* report, uint16_t length)
{
    if (!keyboardController || length < 8) {
        return;
    }
    
    // Standard USB HID keyboard report format:
    // Byte 0: Modifier keys
    // Byte 1: Reserved
    // Bytes 2-7: Key codes (up to 6 simultaneous keys)
    
    current_report.modifiers = report[0];
    current_report.key_count = 0;
    
    // Extract pressed keys
    for (int i = 2; i < 8 && i < length; i++) {
        if (report[i] != 0 && current_report.key_count < 6) {
            current_report.keys[current_report.key_count++] = report[i];
        }
    }
    
    // Forward the complete report to the PCD68 keyboard controller
    keyboardController->updateMultiKey(&report[2], 6, report[0]);
    
    LOG_DBG("Processed keyboard report: mod=0x%02x, keys=%d", 
            current_report.modifiers, current_report.key_count);
}