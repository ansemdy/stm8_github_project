;=========================================
; CRC-24
; 多项式: 0x800063 (反转 0xC60001)
; 用于产品ID等场景
;=========================================

  PUBLIC crc24

  SECTION `.far_func.text`:CODE:NOROOT(0)
  CODE
;---------------------------------------------
; crc24
; 输入: A=字节数, X=数据指针, RAM 1-3=CRC初值
; 输出: RAM 1-3=CRC结果
;---------------------------------------------
crc24:
  PUSH  A
CRC24_loop:
  LD    A,(X)
UpdateCRC24_800063r:
  MOV   0,#8
  XOR   A,S:3
  LD    S:3,A
crc24r_loop_bit:
  SRL   S:1
  RRC   S:2
  RRC   S:3
  JRNC  crc24r_next_bit
  LD    A,S:1
  XOR   A,#0xC6
  LD    S:1,A
  LD    A,S:3
  XOR   A,#0x01
  LD    S:3,A
crc24r_next_bit:
  DEC   S:0
  JRNE  crc24r_loop_bit
  INCW  X
  DEC   (1,SP)
  JRNE  CRC24_loop
  POP   A
  RET

  END
