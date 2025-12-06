/*
 * Copyright (c) 2024, Jon Sharp
 *
 * SPDX-License-Identifier: MIT
 *
 * DOS compatibility header for PCD-68
 * Provides stubs and replacements for features not available in DOS/DJGPP
 */

#pragma once

#ifdef __DJGPP__

// DOS doesn't have threads, so we stub out mutex
namespace std {
    class mutex {
    public:
        void lock() {}
        void unlock() {}
    };

    template<typename T>
    class lock_guard {
    public:
        explicit lock_guard(T&) {}
        ~lock_guard() {}
    };
}

// Timing functions
#include <time.h>
#include <pc.h>

namespace dos {
    // Get tick count in milliseconds (approximate)
    inline unsigned long getTicks() {
        // BIOS tick counter at 0x46C, ~18.2 ticks per second
        unsigned long ticks = _farpeekl(_dos_ds, 0x46C);
        return (ticks * 1000) / 182;  // Convert to approximate milliseconds
    }

    // Simple delay in milliseconds
    inline void delay(unsigned int ms) {
        unsigned long start = getTicks();
        while ((getTicks() - start) < ms) {
            // Busy wait
        }
    }
}

#endif // __DJGPP__
