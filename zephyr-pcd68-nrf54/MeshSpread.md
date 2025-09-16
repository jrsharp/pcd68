# MeshSpread: A Mesh-Optimized Spreading Technique for Sub-GHz Networks

## Executive Summary

MeshSpread is a novel spreading spectrum technique designed specifically for mesh network topologies, addressing the fundamental limitations of star-topology-optimized protocols like LoRa. This document describes the theoretical framework and potential implementation on a hypothetical Nordic sub-GHz MCU with flexible radio architecture similar to the nRF54H20.

## Background: Why Mesh Networks Need Different Spreading

### Traditional LoRa Limitations for Mesh
- **Optimized for star topology** (gateway-centric)
- **High latency** (1-32ms symbols) compounds across hops
- **Fixed spreading factors** don't adapt to varying link distances
- **No routing awareness** in the physical layer
- **Sequential packet processing** prevents cut-through routing

### Mesh Network Requirements
- **Low per-hop latency** (cumulative delay matters)
- **Adaptive link parameters** (near vs far neighbors)
- **Quick routing decisions** (fast header decode)
- **Concurrent operations** (multiple simultaneous links)
- **Power-aware** (nodes are power-constrained)

## MeshSpread Core Innovations

### 1. Adaptive Symbol Duration Spreading (ADS)

Instead of fixed symbol duration, encode additional information in timing:

```c
typedef struct {
    uint8_t chirp_data;      // Traditional chirp-encoded bits
    uint8_t timing_data;     // Additional bits in duration
    uint16_t base_duration;  // Minimum symbol time (100us)
    uint8_t duration_steps;  // Number of timing levels (4-16)
} AdaptiveSymbol;

// Example: 2 bits in chirp + 2 bits in timing = 4 bits per symbol
// Result: 2x data rate without losing spreading gain
```

**Benefits:**
- Higher effective data rate
- Maintains spreading gain for noise immunity
- Backwards compatible with fixed-duration receivers

### 2. Hierarchical Packet Structure

Different spreading factors for different packet sections:

```c
typedef struct {
    // Ultra-robust preamble for detection
    SpreadingConfig preamble = {
        .spreading_factor = 10,
        .duration_ms = 2,
        .purpose = "Network detection and sync"
    };
    
    // Fast header for routing decisions
    SpreadingConfig header = {
        .spreading_factor = 4,
        .duration_ms = 0.5,
        .content = "Dest address, hop count, priority"
    };
    
    // Adaptive payload based on link quality
    SpreadingConfig payload = {
        .spreading_factor = adaptive_sf(2, 12),
        .duration_ms = variable,
        .optimization = "Per-link, per-packet"
    };
    
    // Minimal ACK slot
    SpreadingConfig ack = {
        .spreading_factor = 2,
        .duration_ms = 0.1,
        .purpose = "Instant acknowledgment"
    };
} MeshPacket;
```

### 3. Parallel Narrow-Band Chirps (PNC)

Split bandwidth into parallel channels with different purposes:

```c
// Instead of one 125kHz channel, use 5x25kHz parallel channels
typedef struct {
    Channel control = {
        .bandwidth_khz = 25,
        .spreading_factor = 8,
        .content = "Routing and control",
        .always_on = true
    };
    
    Channel data[3] = {
        {.bandwidth_khz = 25, .sf = adaptive, .content = "Payload"},
        {.bandwidth_khz = 25, .sf = adaptive, .content = "Payload"},
        {.bandwidth_khz = 25, .sf = adaptive, .content = "Payload"}
    };
    
    Channel beacon = {
        .bandwidth_khz = 25,
        .spreading_factor = 10,
        .content = "Continuous mesh beacon",
        .duty_cycle = 0.01
    };
} ParallelChannels;
```

### 4. Chirp Pattern Diversity

Use different chirp patterns to reduce interference:

```c
enum ChirpPattern {
    LINEAR_UP,      // Traditional LoRa-style
    LINEAR_DOWN,    // Reverse frequency sweep
    EXPONENTIAL,    // f(t) = f0 * e^(kt)
    LOGARITHMIC,    // f(t) = f0 * log(1 + kt)
    SINUSOIDAL,     // f(t) = f0 + A*sin(wt)
    STEPPED,        // Discrete frequency hops
    CUSTOM_POLY     // Polynomial frequency trajectory
};

// Each hop uses different pattern to avoid self-interference
ChirpPattern hop_pattern = (hop_count % NUM_PATTERNS);
```

### 5. Cognitive Link Optimization

Self-learning spreading parameters per link:

```c
typedef struct {
    NodeID neighbor;
    float distance_estimate;
    uint8_t optimal_sf;
    uint8_t min_tx_power;
    float link_quality;
    uint32_t success_count;
    uint32_t failure_count;
    ChirpPattern best_pattern;
} LinkProfile;

// Continuously optimize each link
void adapt_link_parameters(LinkProfile* link) {
    if (link->success_count > 10) {
        // Try reducing SF for lower latency
        link->optimal_sf = max(2, link->optimal_sf - 1);
    }
    if (link->failure_count > 2) {
        // Increase SF for reliability
        link->optimal_sf = min(12, link->optimal_sf + 2);
    }
}
```

## Implementation on Hypothetical Nordic Sub-GHz MCU

### Hardware Architecture Requirements

```c
typedef struct {
    // Multi-core system like nRF54H20
    Core application = {
        .type = "Cortex-M33",
        .frequency_mhz = 320,
        .purpose = "Application logic and protocol stack"
    };
    
    Core radio = {
        .type = "RISC-V",
        .frequency_mhz = 256,
        .purpose = "Real-time radio control and MeshSpread"
    };
    
    Core secure = {
        .type = "Cortex-M33",
        .purpose = "Cryptography and key management"
    };
} NordicSubGHz;
```

### Radio Core Capabilities

```c
// RadioCore firmware for MeshSpread
typedef struct {
    // Hardware acceleration
    bool hardware_chirp_generation = true;
    bool parallel_correlators[5] = {true};  // For PNC
    bool adaptive_frequency_synthesis = true;
    bool microsecond_timing = true;
    
    // Flexible radio control
    FrequencyRange range = {
        .min_mhz = 902,
        .max_mhz = 928,
        .step_hz = 1000
    };
    
    // Real-time capabilities
    uint32_t max_frequency_hops_per_second = 50000;
    uint32_t symbol_timing_resolution_ns = 100;
    uint8_t parallel_demodulators = 5;
    
} RadioCoreCapabilities;
```

### MeshSpread Protocol Stack

```c
// Layer architecture on Nordic MCU
typedef struct {
    // Physical Layer (RadioCore)
    PhysicalLayer phy = {
        .implementation = "RadioCore RISC-V",
        .features = {
            "Adaptive spreading factor",
            "Parallel narrow-band chirps",
            "Pattern diversity",
            "Hardware correlation"
        }
    };
    
    // MAC Layer (RadioCore + App Core)
    MACLayer mac = {
        .implementation = "Split processing",
        .radio_core = "Time-critical operations",
        .app_core = "Routing decisions",
        .features = {
            "Cut-through forwarding",
            "Adaptive slot allocation",
            "Collision avoidance"
        }
    };
    
    // Network Layer (App Core)
    NetworkLayer network = {
        .implementation = "Cortex-M33",
        .protocols = {
            "Mesh routing",
            "Topology management",
            "QoS enforcement"
        }
    };
} ProtocolStack;
```

## Performance Projections

### Latency Comparison

| Metric | LoRa SF7 | LoRa SF12 | MeshSpread (Adaptive) |
|--------|----------|-----------|----------------------|
| Symbol Duration | 1.024ms | 32.768ms | 0.1-10ms |
| Header Decode | 10ms | 320ms | 0.5-2ms |
| 5-Hop Latency | 50ms | 1600ms | 2.5-50ms |
| Network Formation | 10-30s | 30-120s | 1-5s |

### Range vs Data Rate

```
Distance | MeshSpread Mode | Effective Rate | Range
---------|-----------------|----------------|-------
<100m    | Fast FSK        | 100 kbps       | Urban dense
100-500m | Low SF (2-4)    | 10-50 kbps     | Suburban
500m-2km | Medium SF (4-8) | 1-10 kbps      | Rural
2-10km   | High SF (8-12)  | 0.1-1 kbps     | Long range
```

## Use Cases for Neighborhood Computing

### Real-Time Applications Enabled

1. **Voice Calls** - Sub-50ms latency enables mesh VoIP
2. **Gaming** - 5-10ms latency for local multiplayer
3. **Video Streaming** - Adaptive quality based on link
4. **Emergency Alerts** - Instant propagation across mesh
5. **Collaborative Apps** - Real-time document editing

### Network Behaviors

```c
// Self-organizing neighborhood network
typedef struct {
    // Time to form 100-node network: <5 seconds
    uint32_t network_formation_ms = 5000;
    
    // Concurrent conversations: 10-20
    uint8_t parallel_voice_calls = 15;
    
    // Emergency message propagation: <100ms
    uint32_t emergency_broadcast_ms = 100;
    
    // Power efficiency: 10x better than LoRa mesh
    float power_efficiency_gain = 10.0;
    
} NeighborhoodNetworkMetrics;
```

## Development Roadmap

### Phase 1: Simulation (Current)
- Mathematical modeling of MeshSpread
- NS-3 network simulation
- GNU Radio prototype

### Phase 2: FPGA Prototype
- Implement RadioCore in FPGA
- Real-world RF testing
- Protocol refinement

### Phase 3: Silicon (Hypothetical Nordic)
- Custom ASIC implementation
- Integrated with Nordic ecosystem
- Production-ready solution

## Advantages Over Existing Solutions

### vs LoRa
- **10-100x lower latency** for mesh applications
- **Adaptive optimization** per link
- **True mesh design** vs retrofitted star topology

### vs Standard FSK/GFSK
- **Better range** through spreading
- **Interference immunity** via chirp diversity
- **Coexistence** with other ISM users

### vs Wi-Fi HaLow
- **Lower power** consumption
- **Simpler** protocol stack
- **No infrastructure** required

## Conclusion

MeshSpread represents a fundamental rethinking of spread spectrum techniques for mesh networks. By co-designing the physical layer with mesh topology requirements, we can achieve order-of-magnitude improvements in latency while maintaining the range benefits of spreading techniques.

The hypothetical Nordic sub-GHz MCU with flexible radio architecture would be the ideal platform for implementing MeshSpread, combining the company's expertise in protocol processors with the growing need for responsive, neighborhood-scale mesh networks.

This approach enables a new class of applications for neighborhood computing - from real-time collaboration to emergency response - that are impossible with current star-topology-optimized protocols.

---

*This document describes a theoretical spreading technique for academic discussion and future innovation. Implementation would require careful consideration of regulatory requirements, IP landscape, and practical engineering constraints.*

## References

- Chirp Spread Spectrum fundamentals
- Mesh networking topology papers
- Nordic nRF54H20 RadioCore architecture
- GNU Radio prototyping frameworks
- NS-3 network simulation tools

## Contact

For collaboration on MeshSpread research and development:
- GitHub: [MeshSpread Protocol Research]
- Email: [research@meshspread.org]