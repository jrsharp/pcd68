#pragma once

#include "../src/KeyboardInput.h"
#include <zephyr/kernel.h>
#include <zephyr/bluetooth/bluetooth.h>
#include <zephyr/bluetooth/gatt.h>
#include <zephyr/bluetooth/uuid.h>
#include <bluetooth/gatt_dm.h>
#include <bluetooth/services/hogp.h>
#include <bluetooth/scan.h>

class KeyboardInput_BLE : public KeyboardInput {
public:
    KeyboardInput_BLE();
    ~KeyboardInput_BLE();
    
    int init() override;
    bool poll() override;
    
    void setKeyboardController(class KCTL* controller) {
        keyboardController = controller;
    }
    
    uint8_t asciiToHID(char ascii);
    char hidToAscii(uint8_t hid);
    
public:
    // Bluetooth callbacks (must be public for C callback registration)
    static void scan_start();
    static void scan_filter_match(struct bt_scan_device_info *device_info,
                                 struct bt_scan_filter_match *filter_match,
                                 bool connectable);
    static void scan_connecting_error(struct bt_scan_device_info *device_info);
    static void scan_connecting(struct bt_scan_device_info *device_info,
                               struct bt_conn *conn);
    static void scan_filter_no_match(struct bt_scan_device_info *device_info,
                                    bool connectable);
    
    // Connection callbacks
    static void connected_cb(struct bt_conn *conn, uint8_t err);
    static void disconnected_cb(struct bt_conn *conn, uint8_t reason);
    static void security_changed_cb(struct bt_conn *conn, bt_security_t level,
                                   enum bt_security_err err);
                                   
private:
    
    // GATT Discovery callbacks
    static void discovery_completed_cb(struct bt_gatt_dm *dm, void *context);
    static void discovery_service_not_found_cb(struct bt_conn *conn, void *context);
    static void discovery_error_found_cb(struct bt_conn *conn, int err, void *context);
    static void gatt_discover(struct bt_conn *conn);
    
    // HOGP callbacks
    static void hogp_ready_cb(struct bt_hogp *hogp);
    static void hogp_pm_update_cb(struct bt_hogp *hogp);
    static uint8_t hogp_rep_handler(struct bt_hogp *hogp,
                                   struct bt_hogp_rep_info *rep,
                                   uint8_t err,
                                   const uint8_t *data);
    
    // HID report processing
    void processKeyboardReport(const uint8_t* report, uint16_t length);
    
    class KCTL* keyboardController;
    struct bt_conn* current_conn;
    struct bt_hogp hogp_client;
    
    // HID keycode to ASCII mapping
    static const uint8_t hid_to_ascii[256];
    
    // Current keyboard state
    struct {
        uint8_t modifiers;
        uint8_t keys[6];
        uint8_t key_count;
    } current_report;
    
    // BLE scanning and connection state
    bool scanning;
    bool connected;
    bool ready;
    
    // Static instance for callbacks
    static KeyboardInput_BLE* instance;
};