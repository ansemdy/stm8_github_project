;=========================================
; Modbus CRC-16 (Zero-Loop)
; 零循环计算实现，无查找表，零内存
; 多项式: 0x8005 (反转 0xA001)
;=========================================

  PUBLIC UpdateModbusCRC

  SECTION `.near_func.text`:CODE:NOROOT(0)
  CODE
;---------------------------------------------
; UpdateModbusCRC
; 输入: A=要更新的字节, X=CRC当前值
; 输出: X=更新后的CRC
; 特点: 无循环，确定性时序
;---------------------------------------------
UpdateModbusCRC:
  PUSHW X          ;保存2字节临时变量空间
  XOR   A,($1,SP)
  LD    ($1,SP),A
  SWAP  A
  XOR   A,($1,SP)
  LD    ($2,SP),A
  SRL   A
  SRL   A
  XOR   A,($2,SP)
  INC   A
  AND   A,#2
  JRNE  crc8005_xor_1
  EXG   A,XL
  JRA   crc8005_srlp
crc8005_xor_1:
  LD    A,#0xC0
  EXG   A,XL
  XOR   A,#0x01
crc8005_srlp:
  CLR   ($2,SP)
  SRL   ($1,SP)
  RRC   ($2,SP)
  XOR   A,($2,SP)
  RRWA  X,A
  XOR   A,($1,SP)
  SRL   ($1,SP)
  RRC   ($2,SP)
  XOR   A,($1,SP)
  RLWA  X,A
  XOR   A,($2,SP)
  LD    XH,A
  ADD   SP,#2
  RET

  END
