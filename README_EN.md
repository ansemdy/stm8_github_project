# STM8 Embedded Algorithm Library

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> A comprehensive embedded algorithm library for STM8 microcontrollers,  
> featuring zero-loop CRC, MD5, Base64, PID control, and more.

---

## ✨ Highlights

| Module | Feature | Memory | Code Size |
|--------|---------|--------|-----------|
| **Modbus CRC-16** | Lookup table (512B) | 512B Flash | ~50B |
| **Modbus CRC-16** | **Zero-loop computation** | **0B** | ~35B |
| **CRC-16-CCITT** | **Zero-loop (0x1021)** | **0B** | ~30B |
| **CRC-24** | Bit-by-bit | 0B | ~40B |
| **MD5** | Full implementation | ~120B RAM | ~2KB |
| **Base64** | Encode/Decode | 0B | ~150B |
| **PID Controller** | IQ10 fixed-point | ~20B RAM | ~80B |
| **NTC Thermistor** | Float calculation | 0B | ~100B |
| **Week Calculator** | Zeller's formula | 0B | ~80B |

---

## 🎯 The Philosophy: Zero-Loop CRC

This library demonstrates how **algorithmic insight** can overcome hardware limitations. The zero-loop CRC implementations prove that even on 8-bit microcontrollers without barrel shifters or single-cycle multipliers, deterministic timing can be achieved through clever bit manipulation.

### STM8-Specific Techniques

| Technique | Instruction | Purpose |
|-----------|-------------|---------|
| **SWAP nibble exchange** | `SWAP A` | Cross 4-bit halves (no ARM equivalent) |
| **Shift-rotate pair** | `SRL` + `RRC` | Multi-bit shift through carry |
| **Stack temporary storage** | `PUSH`/`POP` | Register-pressure relief |
| **Conditional INC+AND** | `INC A` + `AND A,#2` | Parity detection without loops |

---

## 📁 File Structure

```
.
├── README.md              # This file
├── README_CN.md           # Chinese version
├── LICENSE                # MIT License
├── src/
│   ├── crc_modbus_table.s     # Table-based Modbus CRC (fast)
│   ├── crc_modbus_noloop.s    # Zero-loop Modbus CRC (no memory)
│   ├── crc16_ccitt_noloop.s   # Zero-loop CRC-16-CCITT
│   ├── crc24.s                # CRC-24 implementation
│   ├── md5.s                  # Full MD5 with Base64/ASCII output
│   ├── base64.s               # Base64 encoder/decoder
│   ├── pid.s                  # IQ10 fixed-point PID controller
│   ├── ntc_thermistor.s       # NTC temperature calculation
│   └── week_calculator.s      # Day-of-week calculation
├── test/
│   └── test_vectors.h         # Standard test vectors
└── docs/
    └── whitepaper.md          # Technical whitepaper
```

---

## 🔧 Usage Examples

### Zero-Loop Modbus CRC-16

```c
// Initialize CRC
unsigned int crc = 0xFFFF;

// Update per byte (no lookup table!)
while (len--) {
    crc = UpdateModbusCRC(*data++, crc);
}
```

### Zero-Loop CRC-16-CCITT

```c
// Initialize CRC
unsigned int crc = 0xFFFF;

// Update per byte (polynomial 0x1021)
crc = UpdateCRC16_1021r(byte, crc);
```

### MD5 with Base64 Output

```c
// Calculate MD5, output as Base64
md5f(data, output_buffer, length, 2);  // mode 2 = Base64
```

### IQ10 PID Controller

```c
// PID with 10-bit fractional precision
unsigned int output = pid(target_value);
```

---

## 📊 Performance Comparison

### CRC-16 Implementations (STM8 @ 24MHz)

| Implementation | Code Size | Cycles/Byte | 1KB Time | Memory |
|----------------|-----------|-------------|----------|--------|
| Table lookup | ~50B + 512B table | ~15 | 625μs | 512B Flash |
| **Zero-loop** | ~35B | ~80 | 3333μs | **0B** |
| Bit-by-bit | ~30B | ~400 | 16667μs | 0B |

**Trade-off**: Zero-loop saves 512B Flash at the cost of ~5x speed vs table method.  
**Use case**: When Flash is precious and speed requirement is modest (<10KB/s data rate).

---

## 🏛️ Author & History

**臧德运 (Zang Deyun)**

- 🏆 1997 *《电脑爱好者》* Magazine Algorithm Contest — Honored Participant
- 📰 1998 *《电脑爱好者》* Issue 5 — Contest Review
- 💻 30+ years embedded systems development (DOS x86 → STM8 → ARM)
- 🔧 Specializing in resource-constrained optimization

> *"From 8-bit to 32-bit, the architecture changes, but the respect for  
> every clock cycle and every byte of memory never fades."*

---

## 📜 License

MIT License — See [LICENSE](LICENSE) file.

**Special Dedication:**

This library is freely dedicated to the **Chinese microcontroller developer  
community** and embedded engineers worldwide. May these algorithms serve  
as building blocks for the next generation of industrial IoT devices.

---

## 🤝 Contributing

This is a reference implementation for educational and industrial use.  
Ports to other 8-bit architectures (PIC, AVR, 8051) are welcome.

---

## 📧 Contact

For technical discussion: [Open an Issue](https://github.com/yourusername/stm8-embedded-algo-lib/issues)

---

*"True real-time performance comes not from faster CPUs, but from  
understanding every instruction and every clock cycle."*
