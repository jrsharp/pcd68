/*
 * Freestanding C/C++ Support
 * Minimal libc replacements for PCD68 OF build
 */

#pragma once

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Memory functions */
void *memcpy(void *dest, const void *src, size_t n);
void *memset(void *s, int c, size_t n);
void *memmove(void *dest, const void *src, size_t n);
int memcmp(const void *s1, const void *s2, size_t n);

/* String functions */
size_t strlen(const char *s);
char *strcpy(char *dest, const char *src);
char *strncpy(char *dest, const char *src, size_t n);
int strcmp(const char *s1, const char *s2);
int strncmp(const char *s1, const char *s2, size_t n);
char *strchr(const char *s, int c);
char *strrchr(const char *s, int c);

/* Math helpers */
int abs(int n);
long labs(long n);

/* Compiler support functions (for G++) */
void __cxa_pure_virtual();
void *__dso_handle;

/* GCC builtins we might need */
void __builtin_memcpy(void *dest, const void *src, size_t n);
void __builtin_memset(void *s, int c, size_t n);

/* PowerPC specific */
static inline uint32_t read_tbl() {
    uint32_t tbl;
    asm volatile("mftbl %0" : "=r"(tbl));
    return tbl;
}

static inline uint32_t read_tbu() {
    uint32_t tbu;
    asm volatile("mftbu %0" : "=r"(tbu));
    return tbu;
}

static inline uint64_t read_tb() {
    uint32_t tbu1, tbu2, tbl;
    do {
        tbu1 = read_tbu();
        tbl = read_tbl();
        tbu2 = read_tbu();
    } while (tbu1 != tbu2);
    return ((uint64_t)tbu1 << 32) | tbl;
}

/* Cache control */
static inline void dcache_flush(void *addr, size_t len) {
    char *a = (char *)addr;
    char *end = a + len;

    for (; a < end; a += 32) {
        asm volatile("dcbf 0,%0" : : "r"(a) : "memory");
    }
    asm volatile("sync" : : : "memory");
}

static inline void icache_invalidate(void *addr, size_t len) {
    char *a = (char *)addr;
    char *end = a + len;

    for (; a < end; a += 32) {
        asm volatile("icbi 0,%0" : : "r"(a) : "memory");
    }
    asm volatile("sync; isync" : : : "memory");
}

/* Synchronization */
static inline void sync() {
    asm volatile("sync" : : : "memory");
}

static inline void isync() {
    asm volatile("isync" : : : "memory");
}

static inline void eieio() {
    asm volatile("eieio" : : : "memory");
}

#ifdef __cplusplus
}

/* C++ support */
namespace std {
    typedef ::size_t size_t;
    typedef ::ptrdiff_t ptrdiff_t;
}

/* Placement new */
inline void *operator new(size_t, void *p) noexcept { return p; }
inline void *operator new[](size_t, void *p) noexcept { return p; }
inline void operator delete(void *, void *) noexcept {}
inline void operator delete[](void *, void *) noexcept {}

#endif /* __cplusplus */