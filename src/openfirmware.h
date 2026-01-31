/*
 * Open Firmware Client Interface for PCD68
 * Based on IEEE 1275-1994 and PowerPC OF bindings
 */

#pragma once

#include <stdint.h>
#include <stddef.h>

/* OF Client Interface types */
typedef void *phandle;
typedef void *ihandle;
typedef uint32_t cell;

/* OF Client Interface argument structure */
struct of_args {
    const char *service;
    int nargs;
    int nreturns;
    cell args[12]; /* Variable length in practice */
};

/* Entry point passed by OF */
extern int (*of_client_interface)(struct of_args *);

/* OF service wrappers */
static inline int of_call(struct of_args *args) {
    if (of_client_interface) {
        return of_client_interface(args);
    }
    return -1;
}

/* Core OF services */
phandle of_finddevice(const char *path);
ihandle of_open(const char *device);
void of_close(ihandle ih);
int of_read(ihandle ih, void *buf, int len);
int of_write(ihandle ih, const void *buf, int len);
int of_seek(ihandle ih, int pos_hi, int pos_lo);

/* Memory management */
void *of_claim(void *virt, int size, int align);
void of_release(void *virt, int size);

/* Property access */
int of_getprop(phandle ph, const char *name, void *buf, int len);
int of_setprop(phandle ph, const char *name, const void *buf, int len);

/* Method calls */
int of_call_method(const char *method, ihandle ih, int nargs, int nreturns, ...);

/* Console I/O */
int of_getchar(void);
void of_putchar(int c);

/* Control transfer */
void of_exit(void);
void of_enter(void);
void of_chain(void *virt, int size, void *entry, void *args, int arglen);

/* Utility functions */
void of_print(const char *str);
void of_print_hex(uint32_t value);

/* OF execution environment info */
struct of_env {
    /* Framebuffer info */
    uint32_t *fb_addr;
    int fb_width;
    int fb_height;
    int fb_depth;
    int fb_linebytes;

    /* Console handles */
    ihandle stdin;
    ihandle stdout;
    ihandle screen;
    ihandle keyboard;

    /* Memory info */
    void *heap_base;
    int heap_size;

    /* CPU info */
    int cpu_clock;
};

extern struct of_env of_env;

/* Initialize OF client interface */
int of_init(int (*client_interface)(struct of_args *));

/* Query display properties */
int of_get_framebuffer(void);

/* Simple memory allocator using OF */
void *of_malloc(size_t size);
void of_free(void *ptr);