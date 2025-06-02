#pragma once

#include <chrono>
#include <iostream>

class PerformanceBenchmark {
private:
    std::chrono::high_resolution_clock::time_point startTime;
    std::chrono::high_resolution_clock::time_point lastReportTime;
    uint64_t instructionCount;
    uint64_t lastInstructionCount;
    uint64_t cycleCount;
    uint64_t lastCycleCount;
    
public:
    PerformanceBenchmark() : instructionCount(0), lastInstructionCount(0), cycleCount(0), lastCycleCount(0) {
        startTime = std::chrono::high_resolution_clock::now();
        lastReportTime = startTime;
    }
    
    void recordInstruction() {
        instructionCount++;
    }
    
    void recordInstruction(uint64_t count) {
        instructionCount += count;
    }
    
    void recordCycle() {
        cycleCount++;
    }
    
    void reportPerformance(bool force = false) {
        auto now = std::chrono::high_resolution_clock::now();
        auto timeSinceLastReport = std::chrono::duration_cast<std::chrono::milliseconds>(now - lastReportTime).count();
        
        // Report every 5 seconds or when forced
        if (force || timeSinceLastReport >= 5000) {
            auto totalTime = std::chrono::duration_cast<std::chrono::milliseconds>(now - startTime).count();
            
            uint64_t instructionsDelta = instructionCount - lastInstructionCount;
            uint64_t cyclesDelta = cycleCount - lastCycleCount;
            
            double instructionsPerSecond = (double)instructionsDelta / (timeSinceLastReport / 1000.0);
            double cyclesPerSecond = (double)cyclesDelta / (timeSinceLastReport / 1000.0);
            double totalInstructionsPerSecond = (double)instructionCount / (totalTime / 1000.0);
            
            std::cout << "=== PERFORMANCE BENCHMARK ===" << std::endl;
            std::cout << "Time: " << totalTime << "ms" << std::endl;
            std::cout << "Instructions (last 5s): " << instructionsDelta << " (" << (int)instructionsPerSecond << " IPS)" << std::endl;
            std::cout << "Cycles (last 5s): " << cyclesDelta << " (" << (int)cyclesPerSecond << " CPS)" << std::endl;
            std::cout << "Total Instructions: " << instructionCount << " (" << (int)totalInstructionsPerSecond << " avg IPS)" << std::endl;
            std::cout << "=============================" << std::endl;
            
            lastReportTime = now;
            lastInstructionCount = instructionCount;
            lastCycleCount = cycleCount;
        }
    }
}; 