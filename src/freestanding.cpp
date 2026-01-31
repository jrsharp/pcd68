/*
 * Freestanding C/C++ Support Implementation
 */

#include "freestanding.h"

extern "C" {

/* Memory functions */
void *memcpy(void *dest, const void *src, size_t n) {
    unsigned char *d = (unsigned char *)dest;
    const unsigned char *s = (const unsigned char *)src;

    /* Use word copies for aligned data */
    if (((uintptr_t)d & 3) == 0 && ((uintptr_t)s & 3) == 0) {
        uint32_t *d32 = (uint32_t *)d;
        const uint32_t *s32 = (const uint32_t *)s;
        size_t n32 = n / 4;

        while (n32--) {
            *d32++ = *s32++;
        }

        d = (unsigned char *)d32;
        s = (const unsigned char *)s32;
        n = n & 3;
    }

    /* Copy remaining bytes */
    while (n--) {
        *d++ = *s++;
    }

    return dest;
}

void *memset(void *s, int c, size_t n) {
    unsigned char *p = (unsigned char *)s;
    unsigned char val = (unsigned char)c;

    /* Use word fills for aligned data */
    if (((uintptr_t)p & 3) == 0 && n >= 4) {
        uint32_t *p32 = (uint32_t *)p;
        uint32_t val32 = val | (val << 8) | (val << 16) | (val << 24);
        size_t n32 = n / 4;

        while (n32--) {
            *p32++ = val32;
        }

        p = (unsigned char *)p32;
        n = n & 3;
    }

    /* Fill remaining bytes */
    while (n--) {
        *p++ = val;
    }

    return s;
}

void *memmove(void *dest, const void *src, size_t n) {
    unsigned char *d = (unsigned char *)dest;
    const unsigned char *s = (const unsigned char *)src;

    if (d <= s || d >= s + n) {
        /* No overlap, use memcpy */
        return memcpy(dest, src, n);
    }

    /* Copy backwards */
    d += n;
    s += n;
    while (n--) {
        *--d = *--s;
    }

    return dest;
}

int memcmp(const void *s1, const void *s2, size_t n) {
    const unsigned char *p1 = (const unsigned char *)s1;
    const unsigned char *p2 = (const unsigned char *)s2;

    while (n--) {
        if (*p1 != *p2) {
            return *p1 - *p2;
        }
        p1++;
        p2++;
    }

    return 0;
}

/* String functions */
size_t strlen(const char *s) {
    size_t len = 0;
    while (*s++) {
        len++;
    }
    return len;
}

char *strcpy(char *dest, const char *src) {
    char *d = dest;
    while ((*d++ = *src++) != '\0') {
        /* Copy until null terminator */
    }
    return dest;
}

char *strncpy(char *dest, const char *src, size_t n) {
    char *d = dest;
    while (n && (*d++ = *src++) != '\0') {
        n--;
    }
    while (n--) {
        *d++ = '\0';
    }
    return dest;
}

int strcmp(const char *s1, const char *s2) {
    while (*s1 && *s1 == *s2) {
        s1++;
        s2++;
    }
    return *(unsigned char *)s1 - *(unsigned char *)s2;
}

int strncmp(const char *s1, const char *s2, size_t n) {
    while (n && *s1 && *s1 == *s2) {
        s1++;
        s2++;
        n--;
    }
    if (n == 0) {
        return 0;
    }
    return *(unsigned char *)s1 - *(unsigned char *)s2;
}

char *strchr(const char *s, int c) {
    while (*s) {
        if (*s == (char)c) {
            return (char *)s;
        }
        s++;
    }
    return (c == '\0') ? (char *)s : nullptr;
}

char *strrchr(const char *s, int c) {
    const char *last = nullptr;

    while (*s) {
        if (*s == (char)c) {
            last = s;
        }
        s++;
    }

    if (c == '\0') {
        return (char *)s;
    }

    return (char *)last;
}

/* Math functions */
int abs(int n) {
    return (n < 0) ? -n : n;
}

long labs(long n) {
    return (n < 0) ? -n : n;
}

/* GCC builtins */
void __builtin_memcpy(void *dest, const void *src, size_t n) {
    memcpy(dest, src, n);
}

void __builtin_memset(void *s, int c, size_t n) {
    memset(s, c, n);
}

} /* extern "C" */

/* C++ support */
extern "C" void __cxa_pure_virtual() {
    /* Pure virtual function called - halt */
    while (1) {
        asm volatile("nop");
    }
}

/* Global constructors/destructors support (minimal) */
extern "C" {

void *__dso_handle = nullptr;

/* These might be called by compiler-generated code */
int __cxa_atexit(void (*)(void *), void *, void *) {
    /* Ignore destructors in freestanding environment */
    return 0;
}

void __cxa_finalize(void *) {
    /* Nothing to finalize */
}

/* Stack guard (if needed) */
uintptr_t __stack_chk_guard = 0xDEADBEEF;

void __stack_chk_fail() {
    /* Stack corruption detected - halt */
    while (1) {
        asm volatile("nop");
    }
}

} /* extern "C" */

/* Operators new/delete (minimal implementation) */
#include "openfirmware.h"

void *operator new(size_t size) {
    return of_malloc(size);
}

void *operator new[](size_t size) {
    return of_malloc(size);
}

void operator delete(void *ptr) {
    /* No free in our simple allocator */
    (void)ptr;
}

void operator delete[](void *ptr) {
    /* No free in our simple allocator */
    (void)ptr;
}

void operator delete(void *ptr, size_t) {
    /* No free in our simple allocator */
    (void)ptr;
}

void operator delete[](void *ptr, size_t) {
    /* No free in our simple allocator */
    (void)ptr;
}