# STM8 嵌入式算法库

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> 面向 STM8 微控制器的综合嵌入式算法库，  
> 包含零循环 CRC、MD5、Base64、PID 控制等。

---

## ✨ 核心亮点

| 模块 | 特性 | 内存占用 | 代码体积 |
|------|------|----------|----------|
| **Modbus CRC-16** | 查表法 (512B) | 512B Flash | ~50B |
| **Modbus CRC-16** | **零循环计算** | **0B** | ~35B |
| **CRC-16-CCITT** | **零循环 (0x1021)** | **0B** | ~30B |
| **CRC-24** | 逐位计算 | 0B | ~40B |
| **MD5** | 完整实现 | ~120B RAM | ~2KB |
| **Base64** | 编解码 | 0B | ~150B |
| **PID 控制器** | IQ10 定点 | ~20B RAM | ~80B |
| **NTC 热敏电阻** | 浮点计算 | 0B | ~100B |
| **星期计算** | 蔡勒公式 | 0B | ~80B |

---

## 🎯 核心理念：零循环 CRC

本库展示了**算法洞察**如何克服硬件限制。零循环 CRC 实现证明，即使在  
没有桶形移位器或单周期乘法器的 8 位微控制器上，也能通过巧妙的位操作  
实现确定性时序。

### STM8 特有技巧

| 技巧 | 指令 | 用途 |
|------|------|------|
| **SWAP 半字节交换** | `SWAP A` | 交叉 4 位（ARM 无等效指令） |
| **移位-旋转对** | `SRL` + `RRC` | 通过进位的多位移位 |
| **栈临时存储** | `PUSH`/`POP` | 缓解寄存器压力 |
| **条件 INC+AND** | `INC A` + `AND A,#2` | 无循环奇偶检测 |

---

## 📁 文件结构

```
.
├── README.md              # 英文说明
├── README_CN.md           # 中文版（本文件）
├── LICENSE                # MIT 许可证
├── src/
│   ├── crc_modbus_table.s     # 查表法 Modbus CRC（快）
│   ├── crc_modbus_noloop.s    # 零循环 Modbus CRC（零内存）
│   ├── crc16_ccitt_noloop.s   # 零循环 CRC-16-CCITT
│   ├── crc24.s                # CRC-24 实现
│   ├── md5.s                  # 完整 MD5（含 Base64/ASCII 输出）
│   ├── base64.s               # Base64 编解码
│   ├── pid.s                  # IQ10 定点 PID 控制器
│   ├── ntc_thermistor.s        # NTC 温度计算
│   └── week_calculator.s      # 星期计算
├── test/
│   └── test_vectors.h         # 标准测试向量
└── docs/
    └── whitepaper.md          # 技术白皮书
```

---

## 🔧 使用示例

### 零循环 Modbus CRC-16

```c
// 初始化 CRC
unsigned int crc = 0xFFFF;

// 逐字节更新（无查找表！）
while (len--) {
    crc = UpdateModbusCRC(*data++, crc);
}
```

### 零循环 CRC-16-CCITT

```c
// 初始化 CRC
unsigned int crc = 0xFFFF;

// 逐字节更新（多项式 0x1021）
crc = UpdateCRC16_1021r(byte, crc);
```

### MD5 + Base64 输出

```c
// 计算 MD5，Base64 输出
md5f(data, output_buffer, length, 2);  // mode 2 = Base64
```

### IQ10 PID 控制器

```c
// 10 位小数精度的 PID
unsigned int output = pid(target_value);
```

---

## 📊 性能对比

### CRC-16 实现对比（STM8 @ 24MHz）

| 实现方式 | 代码体积 | 每字节周期 | 1KB 耗时 | 内存占用 |
|----------|----------|-----------|----------|----------|
| 查表法 | ~50B + 512B 表 | ~15 | 625μs | 512B Flash |
| **零循环** | ~35B | ~80 | 3333μs | **0B** |
| 逐位法 | ~30B | ~400 | 16667μs | 0B |

**权衡**：零循环节省 512B Flash，速度约为查表法的 1/5。  
**适用场景**：Flash 紧张且速度要求不高（<10KB/s 数据率）。

---

## 🏛️ 作者与历史

**臧德运**

- 🏆 1997年《电脑爱好者》杂志算法擂台赛 — 优秀选手
- 📰 1998年《电脑爱好者》第5期 — 擂台赛点评收录
- 💻 30余年嵌入式开发经验（DOS x86 → STM8 → ARM）
- 🔧 专注于资源受限环境下的算法优化

> *"从8位到32位，架构在变，但对每一个时钟周期、  
> 每一字节内存的敬畏从未改变。"*

---

## 📜 许可证

MIT 许可证 — 详见 [LICENSE](LICENSE) 文件。

**特别奉献：**

本库无偿献给**中国单片机开发者社区**及全球嵌入式工程师，  
愿这些算法成为下一代工业物联网设备的基石。

---

## 🤝 贡献

本作为参考实现，供教育和工业使用。  
欢迎移植到其他 8 位架构（PIC、AVR、8051）。

---

## 📧 联系

技术讨论：[提交 Issue](https://github.com/yourusername/stm8-embedded-algo-lib/issues)

---

*"真正的实时性能，不只来自更快的 CPU，更来自  
对每一行代码、每一个时钟周期的敬畏与掌控。"*
