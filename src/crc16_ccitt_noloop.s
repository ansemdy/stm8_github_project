;=========================================
; CRC-16-CCITT (Zero-Loop)
; 零循环计算实现，多项式 0x1021
; 用于 HDLC, XMODEM, 蓝牙等协议
;=========================================

  PUBLIC UpdateCRC16_1021r

  SECTION `.near_func.text`:CODE:NOROOT(0)
  CODE
;---------------------------------------------
; UpdateCRC16_1021r
; 输入: A=要更新的字节, X=CRC当前值
; 输出: X=更新后的CRC
; 特点: 使用SWAP+AND掩码，STM8特有优化
;---------------------------------------------
UpdateCRC16_1021r:
  PUSH  A        ;保存2字节临时变量空间
  PUSH  A
  RRWA  X,A
  XOR   A,(1,SP)
  LD    (1,SP),A ;保存计算结果
  SWAP  A        ;8408的低位是00001000b，需要ch^=(ch<<4)
  AND   A,#$F0   ;高低字节交换后的高4位和低4位交换
  XOR   A,(1,SP) ;得到交换后的结果
  LD    (1,SP),A ;保存到临时变量
  SWAP  A        ;再次高低字节交换得到高4位的值
  AND   A,#$0F
  LD    (2,SP),A
  SRL   A        ;右移1位作为16位的高字节有效位转换为short类型3位
  XOR   A,(1,SP) ;得到新的CRC低字节
  RRWA  X,A      ;保存到CRC值，高字节在A中作为char有效CRC的高8位
  SLA   (1,SP)   ;临时变量左移3位(8408字节的位3是1)
  SLA   (1,SP)
  SLA   (1,SP)
  XOR   A,(1,SP) ;异或临时变量
  XOR   A,(2,SP) ;异或临时变量得到新的CRC低字节
  LD    XL,A     ;保存低字节
  ADD   SP,#2
  RET

  END
