/*
 * Open Firmware Client Interface Implementation
 */

#include "openfirmware.h"
#include <stdarg.h>
#include <string.h>

/* Global OF client interface function pointer */
int (*of_client_interface)(struct of_args *) = nullptr;

/* Global OF environment */
struct of_env of_env = {0};

/* Initialize OF client interface */
int of_init(int (*client_interface)(struct of_args *)) {
    of_client_interface = client_interface;

    /* Get console handles from /chosen */
    phandle chosen = of_finddevice("/chosen");
    if (chosen) {
        of_getprop(chosen, "stdin", &of_env.stdin, sizeof(of_env.stdin));
        of_getprop(chosen, "stdout", &of_env.stdout, sizeof(of_env.stdout));
    }

    /* Open screen and keyboard directly */
    of_env.screen = of_open("screen");
    of_env.keyboard = of_open("keyboard");

    /* Get framebuffer info */
    of_get_framebuffer();

    /* Set up heap (claim 16MB for now) */
    of_env.heap_size = 16 * 1024 * 1024;
    of_env.heap_base = of_claim(nullptr, of_env.heap_size, 0);

    return 0;
}

/* Find device node */
phandle of_finddevice(const char *path) {
    struct of_args args = {
        .service = "finddevice",
        .nargs = 1,
        .nreturns = 1
    };
    args.args[0] = (cell)path;

    if (of_call(&args) == 0) {
        return (phandle)args.args[1];
    }
    return 0;
}

/* Open device */
ihandle of_open(const char *device) {
    struct of_args args = {
        .service = "open",
        .nargs = 1,
        .nreturns = 1
    };
    args.args[0] = (cell)device;

    if (of_call(&args) == 0) {
        return (ihandle)args.args[1];
    }
    return 0;
}

/* Close device */
void of_close(ihandle ih) {
    struct of_args args = {
        .service = "close",
        .nargs = 1,
        .nreturns = 0
    };
    args.args[0] = (cell)ih;
    of_call(&args);
}

/* Read from device */
int of_read(ihandle ih, void *buf, int len) {
    struct of_args args = {
        .service = "read",
        .nargs = 3,
        .nreturns = 1
    };
    args.args[0] = (cell)ih;
    args.args[1] = (cell)buf;
    args.args[2] = (cell)len;

    if (of_call(&args) == 0) {
        return (int)args.args[3];
    }
    return -1;
}

/* Write to device */
int of_write(ihandle ih, const void *buf, int len) {
    struct of_args args = {
        .service = "write",
        .nargs = 3,
        .nreturns = 1
    };
    args.args[0] = (cell)ih;
    args.args[1] = (cell)buf;
    args.args[2] = (cell)len;

    if (of_call(&args) == 0) {
        return (int)args.args[3];
    }
    return -1;
}

/* Claim memory */
void *of_claim(void *virt, int size, int align) {
    struct of_args args = {
        .service = "claim",
        .nargs = 3,
        .nreturns = 1
    };
    args.args[0] = (cell)virt;
    args.args[1] = (cell)size;
    args.args[2] = (cell)align;

    if (of_call(&args) == 0) {
        return (void *)args.args[3];
    }
    return nullptr;
}

/* Release memory */
void of_release(void *virt, int size) {
    struct of_args args = {
        .service = "release",
        .nargs = 2,
        .nreturns = 0
    };
    args.args[0] = (cell)virt;
    args.args[1] = (cell)size;
    of_call(&args);
}

/* Get property */
int of_getprop(phandle ph, const char *name, void *buf, int len) {
    struct of_args args = {
        .service = "getprop",
        .nargs = 4,
        .nreturns = 1
    };
    args.args[0] = (cell)ph;
    args.args[1] = (cell)name;
    args.args[2] = (cell)buf;
    args.args[3] = (cell)len;

    if (of_call(&args) == 0) {
        return (int)args.args[4];
    }
    return -1;
}

/* Call device method */
int of_call_method(const char *method, ihandle ih, int nargs, int nreturns, ...) {
    struct of_args args = {
        .service = "call-method",
        .nargs = 2 + nargs,
        .nreturns = nreturns + 1
    };

    args.args[0] = (cell)method;
    args.args[1] = (cell)ih;

    va_list ap;
    va_start(ap, nreturns);
    for (int i = 0; i < nargs; i++) {
        args.args[2 + i] = va_arg(ap, cell);
    }
    va_end(ap);

    if (of_call(&args) == 0) {
        return (int)args.args[2 + nargs]; /* First return value is success */
    }
    return -1;
}

/* Get framebuffer info */
int of_get_framebuffer(void) {
    phandle screen_ph = of_finddevice("screen");
    if (!screen_ph) {
        screen_ph = of_finddevice("/chaos/control"); /* PowerBook G4 */
    }
    if (!screen_ph) {
        return -1;
    }

    /* Get framebuffer properties */
    of_getprop(screen_ph, "address", &of_env.fb_addr, sizeof(of_env.fb_addr));
    of_getprop(screen_ph, "width", &of_env.fb_width, sizeof(of_env.fb_width));
    of_getprop(screen_ph, "height", &of_env.fb_height, sizeof(of_env.fb_height));
    of_getprop(screen_ph, "depth", &of_env.fb_depth, sizeof(of_env.fb_depth));
    of_getprop(screen_ph, "linebytes", &of_env.fb_linebytes, sizeof(of_env.fb_linebytes));

    /* PowerBook G4 15" typical values:
     * width: 1280
     * height: 854
     * depth: 32
     * linebytes: 5120 (1280 * 4)
     */

    /* If properties aren't set, try calling methods */
    if (!of_env.fb_addr && of_env.screen) {
        of_call_method("frame-buffer-adr", of_env.screen, 0, 1, &of_env.fb_addr);
    }

    return 0;
}

/* Console I/O */
int of_getchar(void) {
    unsigned char ch;
    if (of_read(of_env.stdin ? of_env.stdin : of_env.keyboard, &ch, 1) == 1) {
        return ch;
    }
    return -1;
}

void of_putchar(int c) {
    unsigned char ch = c;
    of_write(of_env.stdout ? of_env.stdout : of_env.screen, &ch, 1);
}

void of_print(const char *str) {
    while (*str) {
        of_putchar(*str++);
    }
}

void of_print_hex(uint32_t value) {
    const char *hex = "0123456789ABCDEF";
    of_print("0x");
    for (int i = 28; i >= 0; i -= 4) {
        of_putchar(hex[(value >> i) & 0xF]);
    }
}

/* Exit back to OF */
void of_exit(void) {
    struct of_args args = {
        .service = "exit",
        .nargs = 0,
        .nreturns = 0
    };
    of_call(&args);
}

/* Simple heap allocator */
static uint8_t *heap_ptr = nullptr;

void *of_malloc(size_t size) {
    if (!heap_ptr) {
        heap_ptr = (uint8_t *)of_env.heap_base;
    }

    /* Align to 8 bytes */
    size = (size + 7) & ~7;

    void *result = heap_ptr;
    heap_ptr += size;

    /* Check bounds */
    if (heap_ptr > (uint8_t *)of_env.heap_base + of_env.heap_size) {
        return nullptr;
    }

    return result;
}