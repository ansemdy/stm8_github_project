;=========================================
; Base64 编解码模块
; 支持标准Base64和URL安全变体
;=========================================

; 定义Base64编码字符集选择
; 标准Base64编码
; #define b64encode62  '+'
; #define b64encode63  '/'

; URL安全Base64编码
#define b64encode62  '-'
#define b64encode63  '_'

; 填充字符选择,如果剩余字节不需要填充'=',则速度快,但兼容性为0
#define b64EqualSign 0

  PUBLIC b64encode
  PUBLIC b64decode
  PUBLIC b64encodef
  PUBLIC b64decodef
  PUBLIC EncoderBase64
  PUBLIC b64encode_TailSweep

; 定义b64是否支持写入EEPROM,1=支持
#define b64DeToEEP 0

  EXTERN EEPROM_WaitForLastOperation
#define FLASH_IAPSR 0x505F

;---------------------------------------------
; near CODE - C接口
  SECTION `.near_func.text`:CODE:NOROOT(0)
  CODE

; void b64encode(char len,char *x_in,char *y_out)
b64encode:
  PUSH  #0
  JPF   b64encodef

;---------------------------------------------
; far CODE - Base64编码
  SECTION `.far_func.text`:CODE:NOROOT(0)
  CODE

; 输入参数:A=字节数,X=要编码的数据地址,Y=输出地址
b64encodef:
  PUSH  A
  CLR   0
  CLR   1
b64encode_loop:
  LD    A,(X)
  CALL  EncoderBase64
  INCW  X
  DEC   (1,SP)
  JRNE  b64encode_loop
  ADD   SP,#1
b64encode_TailSweep:
  DEC   1
  JRMI  b64encode_end
  LD    A,0
  CALL  Bin2Base64
;
#if b64EqualSign == 1
  LD    A,#'='
  LD    (Y),A
  BTJT  1,#0,b64encode_end
  LD    (1,Y),A
b64encode_end:
#else
b64encode_end:
  CLR   (Y)
#endif
;
#if b64DeToEEP == 1
  CPW   Y,#0x4000
  BTJF  FLASH_IAPSR,#3,b64encode_ret
  BSET  FLASH_IAPSR,#3
b64encode_ret:
#endif
  RETF

;---------------------------------------------
; Base64编码核心,用于内部调用和C接口
; 输入参数:A=bin字节,RAM0=剩余位数,RAM1=剩余位计数,Y=输出缓冲区指针
EncoderBase64:
  BTJT  1,#0,EncoderBase64_1
  BTJT  1,#1,EncoderBase64_2
; 0.无剩余位数
  SRL   A
  BCCM  0,#4
  SRL   A
  BCCM  0,#5
  INC   1
  JP    Bin2Base64
EncoderBase64_1:
; 1.有2位剩余位
  SWAP  A
  PUSH  A            ;有效SP--
  PUSH  A            ;保存A的值
  SRL   A
  SRL   A
  AND   A,#00111100b
  LD    (2,SP),A     ;保存剩余位,之后弹出到0
  POP   A            ;恢复原始A
  AND   A,#0x0F
  OR    A,0          ;得到下标,剩余位的值之后可以更新
  POP   0            ;弹出保存到剩余位的值
  INC   1
  JP    Bin2Base64
EncoderBase64_2:
; 2.有4位剩余位
  PUSH  A
  SWAP  A
  SRL   A
  SRL   A
  AND   A,#00000011b
  OR    A,0
  CALL  Bin2Base64
  POP   A
  AND   A,#00111111b
  CLR   0
  CLR   1
;------
Bin2Base64:
  ADD   A,#'A'
  CP    A,#'Z'+1
  JRC   StoreBase64
  ADD   A,#6         ;ASCII字符Z到a差6个字符
  CP    A,#'z'+1
  JRC   StoreBase64
  CP    A,#133
  JREQ  Base64_62
  JRNC  Base64_63
  SUB   A,#75
  JRA   StoreBase64
Base64_62:
  LD    A,#b64encode62
  JRA   StoreBase64
Base64_63:
  LD    A,#b64encode63
StoreBase64:
  LD    (Y),A
  INCW  Y
;
#if b64DeToEEP == 1
  CPW   Y,#0x4000
  JRC   StoreBase64_ret
  JP    EEPROM_WaitForLastOperation
#endif
;
StoreBase64_ret:
  RET

;---------------------------------------------
; near CODE - C接口
  SECTION `.near_func.text`:CODE:NOROOT(0)
  CODE

; void b64decode(char a_len,char *x_in,char *y_out)
; 输入参数:A=字符数,为0时自动计算输入长度(尾为0),X=输入地址,Y=输出地址
b64decode:
  PUSH  #0
  JPF   b64decodef

;---------------------------------------------
; far CODE - Base64解码
  SECTION `.far_func.text`:CODE:NOROOT(0)
  CODE

b64decodef:
  PUSH  A
  CLR   0
  CLR   1
b64decode_loop:
  LD    A,(X)
  JRMI  b64decode_ret
#if b64EqualSign == 1
  CP    A,#'='
  JREQ  b64decode_ret
#endif
  CP    A,#' '
  JRC   b64decode_ret
  CALL  DecoderBase64
  INCW  X
  DEC   (1,SP)
  JRNE  b64decode_loop
b64decode_ret:
  POP   A
  RETF

;-----------------------------
; 输入参数:A=bin字节,RAM0=剩余位数,RAM1=剩余位计数,Y=输出缓冲区指针
DecoderBase64_62:
  LD    A,#62
  JRA   deb64StoreBin
DecoderBase64_63:
  LD    A,#63
  JRA   deb64StoreBin
DecoderBase64:
  SUB   A,#'A'
  CP    A,#26
  JRC   deb64StoreBin
  SUB   A,#6
  CP    A,#26
  JRPL  deb64StoreBin
  CP    A,#(b64encode62-71)
  JREQ  DecoderBase64_62
  CP    A,#(b64encode63-71)
  JREQ  DecoderBase64_63
  ADD   A,#75
deb64StoreBin:
  BTJT  1,#0,DecoderBase64_1
  BTJT  1,#1,DecoderBase64_2
  BTJT  1,#2,DecoderBase64_3
  SLA   A
  SLA   A
  LD    0,A
  INC   1
  RET
DecoderBase64_1:
  SWAP  A
  PUSH  A
  AND   A,#3
  OR    A,0
  LD    (Y),A
  INCW  Y
  POP   A
  AND   A,#0xF0
  LD    0,A
  SLA   1
  RET
DecoderBase64_2:
  SLA   A
  SLA   A
  SWAP  A
  PUSH  A
  AND   A,#0x0F
  OR    A,0
  LD    (Y),A
  INCW  Y
  POP   A
  AND   A,#11000000b
  LD    0,A
  SLA   1
  RET
DecoderBase64_3:
  OR    A,0
  LD    (Y),A
  INCW  Y
  CLR   1
  RET

  END
