;=========================================
; MD5 算法模块
; 版本: 1.02.004 2025.09.02
; 支持输出: BIN / ASCII / Base64
;=========================================

; 定义b64是否支持写入EEPROM,1=支持
#define b64DeToEEP 0

  EXTERN EEPROM_UnLock,EEPROM_WaitForLastOperation
#define FLASH_IAPSR 0x505F

; 输出选择,数据输出格式,0=BIN,1=Base64,2=ASCII
; 只有Base64输出支持写入EEPROM
#define OutFormatAscii 1

; 性能选择,这里是否使用双向算法,0=单向,1=双向
; 双向算法执行速度快,每字节需要844时钟周期
#define RolBiDirectional 1

; 功能选择,选择是否支持扩展存储器,1=支持
#define EnableExtoff     0

;-----------------------------------------------------
; 栈内变量
#define md5_VarNum 103

; 输入缓冲,16 long,64 byte
#define md5_x   1
#define md5_x1  5
#define md5_x2  9
#define md5_x3  13
#define md5_x4  17
#define md5_x5  21
#define md5_x6  25
#define md5_x7  29
#define md5_x8  33
#define md5_x9  37
#define md5_x10 41
#define md5_x11 45
#define md5_x12 49
#define md5_x13 53
#define md5_x14 57
#define md5_x15 61

; 中间计算变量,4 long
#define md5_a   65
#define md5_b   69
#define md5_c   73
#define md5_d   77

; md5初始值,4 long
#define md5_s0  81
#define md5_s1  85
#define md5_s2  89
#define md5_s3  93

; int md5_ProChunk 返回指针
#define ProChunkRet 97

; int SourceLen,输入字节数
#define SourceLen 99

; int TransformTablePointer,变换表指针
#define TransformTablePointer 101

; char TransformTableLine,变换表中间行
#define TransformTableLine 103

; 用于传递参数压栈的偏移
#define StrLen  104
#define md5_op  106
#define md5_ipe 108
#define md5_ip  109
#define md5_mod 111
#define StackDatEnd  112
;===========================================================
  SECTION `.near_func.text`:CODE:NOROOT(0)
  CODE

  PUBLIC md5

; typedef char __far *md5str;
; void md5f(md5str l0_str, char *x_md5out, int y_len, char a_mode);
; 输入参数:
; l0=数据24位指针,寄存器1,2,3有效,寄存器0无效
; X =输出地址
; Y =字节长度,为0时自动计算地址长度,但不支持扩展存储器(extoff)
; A =输出模式,0-BIN,1-ASCII,2=Base64
md5:
  PUSH  #0
  JPF   md5f

;===========================================================
  SECTION `.far_func.text`:CODE:NOROOT(0)
  CODE

  PUBLIC md5f

; 调用前注意,本函数破坏A,X,Y,RAM(2-7)寄存器
; 本函数使用STM8单片机计算MD5哈希值,耗时1.86mS @24MHz(已包含看门狗刷新和访问等待)
;   CLR   1
;   LDW   Y,#12
;   LDW   X,#0x48CD
;   LDW   S:2,X
;   LDW   X,#0x1680
;   CALLF md5f
md5f:
  PUSH  9
  PUSH  8
  PUSH  A     ;md5输出模式,0,1,2
  PUSH  3     ;地址指针高位
  PUSH  2     ;地址指针中位
  PUSH  1     ;扩展存储器地址
  PUSHW X     ;MD5输出缓冲区地址
  TNZW  Y     ;要计算MD5字符串的字节数
  JRNE  md5f_start
  LDW   X,2
  TNZ   (X)
  JRNE  md5f_LenForIn
  ADD   SP,#8
  RETF
md5f_LenFor:
  TNZ   (X)
  JREQ  md5f_start
md5f_LenForIn:
  INCW  X
  INCW  Y
  JRA   md5f_LenFor
md5f_start:
  PUSHW Y

; 从堆栈分配一大块变量
; long x[] @ (1,SP) to (64,SP)
; long a,b,c,d @ (65,SP) to (80,SP)
; long state[] @ (81,SP) to (93,SP)
  SUB   SP,#md5_VarNum

; 暂存处理字节数和输入信息'位'数信息
  LDW   (SourceLen,SP),Y
  LDW   0,Y   ;为 md5_whileLen 和 md5_encode 预准备参数

; 初始化state[]
; 0.002.00 循环计数到X
  LDW   X,#15
  LDW   Y,SP
  ADDW  Y,#15
md5_state_init:
  LDF   A,(md5_state_table,X)
  LD    (md5_s0,Y),A
  DECW  Y
  DECW  X
  JRPL  md5_state_init

; 注意!调用md5_ProChunk子程序之前不能有任何堆栈操作
; 子程序破坏A,X,Y,RAM0-7寄存器,SP值不变
;======================
md5_whileLen:
  LDW   X,SP
  INCW  X
  LDW   Y,(md5_ip,SP)
  CALL  md5_encode ;void(*x,*ip,int len);

  LDW   X,(SourceLen,SP)
  SUBW  X,#64
  JRC   TheLastOne

; 保存数据长度和执行指针为下次准备
  LDW   (SourceLen,SP),X
  LDW   (md5_ip,SP),Y

; 处理需要移位的地方
  CALL  md5_ProChunk
;
  LDW   X,(SourceLen,SP)
  LDW   0,X
  JRA   md5_whileLen
;======================
TheLastOne:
; 处理需要补位的长度
  ADDW  X,#8 ;加64再加8等于等于0吗?
  JRMI  DataAppendage

; 当数据长度大于等于56时补加一次处理
  CALL  md5_ProChunk
  LDW   X,SP
  INCW  X
  LD    A,#64
  CALL  md5_clearX
DataAppendage:
; 附加'位'数信息到X[14]
  LDW    X,(StrLen,SP)
  SLAW  X
  RLC   (md5_x14+1,SP)
  SLAW  X
  RLC   (md5_x14+1,SP)
  SLAW  X
  RLC   (md5_x14+1,SP)
  LDW   (md5_x14+2,SP),X
  CALL  md5_ProChunk
;
;------ MD5输出处理,选择输出格式 ------
  LD    A,(md5_mod,SP)
  JREQ  md5_OutBin
  DEC   A
  JRNE  md5_OutAscii
OutEncoderBase64:
  LDW   Y,(md5_op,SP)
#if b64DeToEEP == 1
  CPW   Y,#0x4000
  JRC   OutEncoderBase64SetX
  CALL  EEPROM_UnLock
#endif
;
OutEncoderBase64SetX:
  LDW   X,SP
  CLR   0
  CLR   1
  MOV   2,#4
md5_OutBase64_loop:
  MOV   3,#4
  de_StoreBase64_for:
  LD    A,(md5_s0+3,X)
  CALL  EncoderBase64
  DECW  X
  DEC   3
  JRNE  de_StoreBase64_for
  ADDW  X,#8
  DEC   S:2
  JRNE  md5_OutBase64_loop
  CALLF b64encode_TailSweep
  JP    md5f_epilogue
;
; 输出BIN
md5_OutBin:
  LDW   X,(md5_op,SP) ;输出缓冲区指针
  ADD   SP,#md5_s0-1
  MOV   0,#4
md5_OutBin_loop:
  POP   A
  LD    (3,X),A
  POP   A
  LD    (2,X),A
  POP   A
  LD    (1,X),A
  POP   A
  LD    (X),A
  ADDW  X,#4
  DEC   S:0
  JRNE  md5_OutBin_loop
  ADD   SP,#StackDatEnd-ProChunkRet
  JP    md5f_end
;
; 输出ASCII
md5_OutAscii:
  LDW   X,(md5_op,SP)
  LDW   Y,SP
  MOV   0,#4
md5_OutAscii_loop:
  MOV   1,#4
  de_StoreAscii_for:
  LD    A,(md5_s0+3,Y)
  SWAP  A
  CALL  md5_Bin2Ascii
  LD    A,(md5_s0+3,Y)
  DECW  Y
  CALL  md5_Bin2Ascii
  DEC   S:1
  JRNE  de_StoreAscii_for
  ADDW  Y,#8
;
  DEC   S:0
  JRNE  md5_OutAscii_loop
md5f_epilogue:
  ADD   SP,#StackDatEnd-1
md5f_end:
  POP   8
  POP   9
  RETF
;-----------------
md5_Bin2Ascii:
  AND   A,#0x0F
  ADD   A,#'0'
  CP    A,#'\:'
  JRC   StoreAscii
  ADD   A,#'A'-':'
StoreAscii:
  LD    (X),A
  INCW  X
  RET
;===================== md5f 模块结束 =======================
;
;----------------------- md5 子程序 ------------------------
;!本函数为md5算法的核心
; 使用移动位运算和查表法
; 子程序需要保护局部变量:
; double=RAM(0-7)
; unsigned int=RAM(8-9),用于32位值字节偏移计数和加法运算
md5_ProChunk:
  POPW  X ;保存返回指针到临时变量RET地址,此值是当前SP值加16
  LDW   (ProChunkRet,SP),X

; a,b,c,d = state[]
  LDW   X,SP
  MOV   1,#16
  abcd_CopyLoop:
  LD    A,(md5_s0,X)
  LD    (md5_a,X),A
  INCW  X
  abcd_CopyNext:
  DEC   1
  JRNE  abcd_CopyLoop

; 初始化循环参数
  CLRW  X
  LDW   (TransformTablePointer,SP),X
  LD    A,#64
  LD    (TransformTableLine,SP),A

; 变换循环,4轮每轮16个共64次变换
md5_Transform_table_loop:

; 处理下次变换参数
; 循环计数器低4位计数,变换移位顺序0,3,2,1
; 变换结束后a,b,c,d的值需要传递,保存到栈中
; a=_ff(a,b,c,d,x[0],7,0xd76aa478)
; d=_ff(d,a,b,c,x[1],12,0xe8c7b756)
; c=_ff(c,d,a,b,x[2],17,0x242070db)
; b=_ff(b,c,d,a,x[3],22,0xc1bdceee)
  CLR   8
  LD    A,(TransformTableLine,SP)
  AND   A,#3
  SLA   A
  SLA   A
  LD    9,A   ;$9的值在调用copy_DC64_Y_X后不会变化,要保存到ADDW X,8
; 从栈中分配16字节,SP-16
  SUB   SP,#0x10
;! \SP指针减小0x10,注意对齐,SP指针的偏移需要+16
  CLRW  Y
  CALL  copy_DC64_Y_X
  LDW   Y,SP
  INCW  Y
  CALL  copy_DC64_Y_X

; 加载参数ac
  LDW   X,(TransformTablePointer+16,SP)
  LDF   A,(Transform_table+2,X)
  LD    (13,SP),A
  LDF   A,(Transform_table+3,X)
  LD    (14,SP),A
  LDF   A,(Transform_table+4,X)
  LD    (15,SP),A
  LDF   A,(Transform_table+5,X)
  LD    (16,SP),A

; 加载本次数据移位x[n]
  LDF   A,(Transform_table,X)
  EXGW  X,Y           ;为 CALL _fghi 保存Y值
  CLR   (9,SP)        ;设置(9-10,SP)为中间变量X
  LD    (10,SP),A
  LDW   X,SP
  ADDW  X,(9,SP)
  LD    A,(17,X)
  LD    (9,SP),A
  LD    A,(18,X)
  LD    (10,SP),A
  LDW   X,(19,X)
  LDW   (11,SP),X

; 处理中间变量使用变换公式__f?,...
; 每轮16次变换,按4位计数器选择变换公式,第1轮4位
  LD    A,(TransformTableLine+16,SP)
  DEC   A
  SWAP  A
  CALL  _fghi
;! \SP指针恢复
  ADD   SP,#0x10

; 处理中间变量保存到a?b?c?d?
  LDW   X,SP
  ADDW  X,8
  LD    A,0
  LD    (md5_a,X),A
  LD    A,1
  LD    (md5_a+1,X),A
  LD    A,2
  LD    (md5_a+2,X),A
  LD    A,3
  LD    (md5_a+3,X),A

; 变换表指针指向下一个,每次(共) 6 byte (3 DC16)
  LDW   X,(TransformTablePointer,SP)
  ADDW  X,#6
  LDW   (TransformTablePointer,SP),X

; 中间一循环
  DEC   (TransformTableLine,SP)
  JRNE  md5_Transform_table_loop

; 最后分别处理结果,state[0-3] += a,b,c,d
; s[]和a,b,c,d使用X指针指向不同长度,缺点是不能使用s[]和a,d,c,d的连续运算
  LDW   X,SP
  MOV   0,#4
md5_state_add:
  LD    A,(md5_s0+3,X) ;a
  ADD   A,(md5_a+3,X)  ;state
  LD    (md5_s0+3,X),A
  LD    A,(md5_s0+2,X)
  ADC   A,(md5_a+2,X)
  LD    (md5_s0+2,X),A
  LD    A,(md5_s0+1,X)
  ADC   A,(md5_a+1,X)
  LD    (md5_s0+1,X),A
  LD    A,(md5_s0,X)
  ADC   A,(md5_a,X)
  LD    (md5_s0,X),A
  ADDW  X,#4
  DEC   0
  JRNE  md5_state_add
;------------------------
  LDW   X,(ProChunkRet,SP)
  JP    (X) ;恢复处理返回地址
;------------------------
copy_DC64_Y_X:
  LDW   X,SP
  CALL  copy_DC32_Y_X
  LDW   X,SP
copy_DC32_Y_X:
  ADDW  X,8
  MOV   8,#4             ;设置变换偏移量高位循环后保持0影响ADDW X,8
  cdc32_loop:
  LD    A,(md5_a+16+2,X) ;从栈中装载到SP的X偏移变量+2
  LD    (Y),A
  INCW  X
  INCW  Y
  DEC   8
  JRNE  cdc32_loop
  LD    A,9
  ADD   A,#4
  AND   A,#0x0F  ;模16加法
  LD    9,A
  RET
;==================== md5_ProChunk END =====================
;
;===========================================================
; void md5_encode(char *x,long *y,int len)
; md5编码
md5_encode:
  PUSHW X
  LDW   X,0
  SUBW  X,#64
  JRC   x_TailSweep
  MOV   1,#64
  POPW  X
  CALL  md5_encode_read
  RET
;-------------------
; 扫描x[n]尾部
x_TailSweep
  LDW   X,(1,SP)
  ADDW  X,0
  LD    A,#64
  SUB   A,1
  CALL  md5_clearX
  POPW  X
  CALL  md5_encode_read

; 附加填充字节(为凑足4字节的数据补位)
  CLR   (X)
  CLR   (1,X)
  CLR   (2,X)
  LD    A,#0x80
  LD    (3,X),A
  TNZ   1
  JREQ  md5_encode_e
  INCW  X
  INCW  X
Complement_for:
#if EnableExtoff == 1
  LD    A,(md5_ipe+2,SP)  ;只有一层返回栈
  JRNE  ?x_TailSweepExt1
#endif
  LD    A,(Y)
Complement_continue:
  LD    (1,X),A
  LD    A,#0x80
  LD    (X),A
  DECW  X
  INCW  Y
  DEC   1
  JRNE  Complement_for
md5_encode_e:
  RET
;-------------------
; 读取扩展存储器
#if EnableExtoff == 1
?x_TailSweepExt1:
  DEC   A
  JRNE  x_TailSweepExt2
  LDF   A,($10000,Y)
  JRA    Complement_continue
x_TailSweepExt2:
  LDF   A,($20000,Y)
  JRA   Complement_continue
#endif
;===========================================================
md5_encode_read:
md5_EncodeReadFor:
  LD    A,1
  SUB   A,#4
  JRC   md5_encode_end
  LD    1,A
#if EnableExtoff == 1
  LD    A,(md5_ipe+4,SP)  ;多层返回栈+4
  JRNE  ?md5_ext1
#endif
  LDF   A,(3,Y)
  LD    (X),A
  LD    A,(2,Y)
  LD    (1,X),A
  LD    A,(1,Y)
  LD    (2,X),A
  LD    A,(0,Y)
  LD    (3,X),A
md5_encodeReadNextY:
  ADDW  Y,#4
#if EnableExtoff == 1
  JRNC  md5_encodeReadNextX
  INC   (md5_ipe+4,SP)
#else
  JRC   md5_encode_end   ;不支持扩展存储器Y地址溢出
#endif
md5_encodeReadNextX:
  ADDW  X,#4
  JP    md5_EncodeReadFor
#if EnableExtoff == 1
?md5_ext1:
  DEC   A
  JRNE  ?md5_ext2
  LDF   A,($10003,Y)
  LD    (X),A
  LDF   A,($10002,Y)
  LD    (1,X),A
  LDF   A,($10001,Y)
  LD    (2,X),A
  LDF   A,($10000,Y)
  LD    (3,X),A
  JRA   md5_encodeReadNextY
?md5_ext2:
  LDF   A,($20003,Y)
  LD    (X),A
  LDF   A,($20002,Y)
  LD    (1,X),A
  LDF   A,($20001,Y)
  LD    (2,X),A
  LDF   A,($20000,Y)
  LD    (3,X),A
  ADDW  Y,#4
  ADDW  X,#4
  JRA   md5_EncodeReadFor
#endif
md5_encode_end:
  RET
;----------------------
md5_clearX:
  CLR   (X)
  INCW  X
  DEC   A
  JRNE  md5_clearX
  RET
;-----------------------------------------------------------
; long _ff(long a,long b,long c,long d,long x,long p,char n);
_fghi:
; 为md5_算法准备参数 x,y,z
; x@($0), y@($4), z@(20,SP)
; s@(5,SP) 1.00.000 保存到栈中传递,此参数也用于传递,下一轮得到
  SUB   SP,#13
  LDW   X,6
  LDW   (12,SP),X
  LDW   X,4
  LDW   (10,SP),X
  LDW   X,2
  LDW   (8,SP),X
  LDW   X,0
  LDW   (6,SP),X
; __f().z=d;d@(20,sp)
  LDW   X,(20,SP)
  LDW   (1,SP),X
  LDW   X,(22,SP)
  LDW   (3,SP),X
; __f().y=c,c@(16,sp)
  LDW   X,(16,SP)
  LDW   4,X
  LDW   X,(18,SP)
  LDW   6,X
; __f().x=b,b@(10,SP)
  LDW   X,(10,SP)
  LDW   0,X
  LDW   X,(12,SP)
  LDW   2,X

  AND   A,#3
  SLA   A
  CLRW  X
  LD    XL,A
  LDW   X,(SUB_ihgf,X)
  CALL  (X)
; a=RotateLeft32((a+F(b,c,d)+x+ac),s)+b;
; a=F()+a,a@(6,sp)
  LDW   X,SP
  ADDW  X,#6   ;从a偏移6,即+6
  CALL  add32_l0_l0_0x
; a=a+x,x@(24,sp)
  ADDW  X,#18  ;从a偏移6,即+18
  CALL  add32_l0_l0_0x
; a=a+ac,ac@(28,sp)
  ADDW  X,#4   ;从x偏移24,即+4
  CALL  add32_l0_l0_0x
; a=RotateLeft32(v,s)+b,b@(9,sp)
  LDF   A,(Transform_table+1,Y)
;----------------- 内联 RotateLeft32 -----------------------
; CALL  rol32_l0_a
rol32_l0_a:
  BCP   A,#4
  JREQ  RotateLeft32_rol
RotateLeft32_ror:
  RRC   0
  RRC   1
  RRC   2
  RRC   3
  BCCM  0,#7
  INC   A
  BCP   A,#7
  JRNE  RotateLeft32_ror
  JP    RotateLeft32_rol8
RotateLeft32_rol:
  BCP   A,#7
  JREQ  ?RotateLeft32_rol8
  RLC   3
  RLC   2
  RLC   1
  RLC   0
  BCCM  3,#0
  DEC   A
  JP    RotateLeft32_rol
?RotateLeft32_rol8:
  TNZ   A
  JREQ  RotateLeft32_end
RotateLeft32_rol8:
  PUSH  0
  MOV   0,1
  MOV   1,2
  MOV   2,3
  POP   3
  SUB   A,#8
  JRNE  RotateLeft32_rol8
RotateLeft32_end:
  ; RET  ;rol32_l0_a RET
;---------------- 内联 RotateLeft32 结束 -------------------
  SUBW  X,#18    ;从ac偏移28,减去s,即-18
  ADD   SP,#13   ;释放局部变量加法,可修改下面的加法函数
;------
add32_l0_l0_0x:
  LD    A,3
  ADD   A,(3,X)
  LD    3,A
  LD    A,2
  ADC   A,(2,X)
  LD    2,A
  LD    A,1
  ADC   A,(1,X)
  LD    1,A
  LD    A,0
  ADC   A,(X)
  LD    0,A
  RET         ;(add32_l0_l0_0x) & (_fghi) RET
;-----------------------------------------------------------
; F算法: ((x&y)|(~x & z))
; x@0,y@1,z@(3,sp)
__f:
; 1.x&y 暂存到 y
  LD    A,4
  AND   A,0
  LD    4,A
  LD    A,5
  AND   A,1
  LD    5,A
  LD    A,6
  AND   A,2
  LD    6,A
  LD    A,7
  AND   A,3
  LD    7,A
; 2.(x取反&z)|y 到 x
  LD    A,0
  CPL   A
  AND   A,(3,SP)
  OR    A,4
  LD    0,A
  LD    A,1
  CPL   A
  AND   A,(4,SP)
  OR    A,5
  LD    1,A
  LD    A,2
  CPL   A
  AND   A,(5,SP)
  OR    A,6
  LD    2,A
  LD    A,3
  CPL   A
  AND   A,(6,SP)
  OR    A,7
  LD    3,A
  RET
;-----------------------------------------------------------
; G算法: ((x&z) | (y & ~z))
; x@0,y@1,z@(3,sp)
__g:
; 1.x&y 暂存到 x
  LD    A,0
  AND   A,(3,SP)
  LD    0,A
  LD    A,1
  AND   A,(4,SP)
  LD    1,A
  LD    A,2
  AND   A,(5,SP)
  LD    2,A
  LD    A,3
  AND   A,(6,SP)
  LD    3,A
; 2.(z取反&y)|x 到 x
  LD    A,(3,SP)
  CPL   A
  AND   A,4
  OR    A,0
  LD    0,A
  LD    A,(4,SP)
  CPL   A
  AND   A,5
  OR    A,1
  LD    1,A
  LD    A,(5,SP)
  CPL   A
  AND   A,6
  OR    A,2
  LD    2,A
  LD    A,(6,SP)
  CPL   A
  AND   A,7
  OR    A,3
  LD    3,A
  RET
;-----------------------------------------------------------
; H算法: (x ^ y ^ z)
; x@0,y@1,z@(3,sp)
__h:
; 1.x&y 暂存到 x
  LD    A,(3,SP)
  XOR   A,0
  XOR   A,4
  LD    0,A
  LD    A,(4,SP)
  XOR   A,1
  XOR   A,5
  LD    1,A
  LD    A,(5,SP)
  XOR   A,2
  XOR   A,6
  LD    2,A
  LD    A,(6,SP)
  XOR   A,3
  XOR   A,7
  LD    3,A
  RET
;-----------------------------------------------------------
; I算法: (y ^ (x | ~z))
; x@0,y@1,z@(3,sp)
__i:
; 1.x&y 暂存到 x
  LD    A,(3,SP)
  CPL   A
  OR    A,0
  XOR   A,4
  LD    0,A
  LD    A,(4,SP)
  CPL   A
  OR    A,1
  XOR   A,5
  LD    1,A
  LD    A,(5,SP)
  CPL   A
  OR    A,2
  XOR   A,6
  LD    2,A
  LD    A,(6,SP)
  CPL   A
  OR    A,3
  XOR   A,7
  LD    3,A
  RET
;------------------------ md5 辅助表 -----------------------
  DATA
Transform_table:
  DC16 0x0007,0xd76a,0xa478
  DC16 0x040c,0xe8c7,0xb756
  DC16 0x0811,0x2420,0x70db
  DC16 0x0c16,0xc1bd,0xceee
  DC16 0x1007,0xf57c,0x0faf
  DC16 0x140c,0x4787,0xc62a
  DC16 0x1811,0xa830,0x4613
  DC16 0x1c16,0xfd46,0x9501
  DC16 0x2007,0x6980,0x98d8
  DC16 0x240c,0x8b44,0xf7af
  DC16 0x2811,0xffff,0x5bb1
  DC16 0x2c16,0x895c,0xd7be
  DC16 0x3007,0x6b90,0x1122
  DC16 0x340c,0xfd98,0x7193
  DC16 0x3811,0xa679,0x438e
  DC16 0x3c16,0x49b4,0x0821
  DC16 0x0405,0xf61e,0x2562
  DC16 0x1809,0xc040,0xb340
  DC16 0x2c0e,0x265e,0x5a51
  DC16 0x0014,0xe9b6,0xc7aa
  DC16 0x1405,0xd62f,0x105d
  DC16 0x2809,0x0244,0x1453
  DC16 0x3c0e,0xd8a1,0xe681
  DC16 0x1014,0xe7d3,0xfbc8
  DC16 0x2405,0x21e1,0xcde6
  DC16 0x3809,0xc337,0x07d6
  DC16 0x0c0e,0xf4d5,0x0d87
  DC16 0x2014,0x455a,0x14ed
  DC16 0x3405,0xa9e3,0xe905
  DC16 0x0809,0xfcef,0xa3f8
  DC16 0x1c0e,0x676f,0x02d9
  DC16 0x3014,0x8d2a,0x4c8a
  DC16 0x1404,0xfffa,0x3942
  DC16 0x200b,0x8771,0xf681
  DC16 0x2c10,0x6d9d,0x6122
  DC16 0x3817,0xfde5,0x380c
  DC16 0x0404,0xa4be,0xea44
  DC16 0x100b,0x4bde,0xcfa9
  DC16 0x1c10,0xf6bb,0x4b60
  DC16 0x2817,0xbebf,0xbc70
  DC16 0x3404,0x289b,0x7ec6
  DC16 0x000b,0xeaa1,0x27fa
  DC16 0x0c10,0xd4ef,0x3085
  DC16 0x1817,0x0488,0x1d05
  DC16 0x2404,0xd9d4,0xd039
  DC16 0x300b,0xe6db,0x99e5
  DC16 0x3c10,0x1fa2,0x7cf8
  DC16 0x0817,0xc4ac,0x5665
  DC16 0x0006,0xf429,0x2244
  DC16 0x1c0a,0x432a,0xff97
  DC16 0x380f,0xab94,0x23a7
  DC16 0x1415,0xfc93,0xa039
  DC16 0x3006,0x655b,0x59c3
  DC16 0x0c0a,0x8f0c,0xcc92
  DC16 0x280f,0xffef,0xf47d
  DC16 0x0415,0x8584,0x5dd1
  DC16 0x2006,0x6fa8,0x7e4f
  DC16 0x3c0a,0xfe2c,0xe6e0
  DC16 0x180f,0xa301,0x4314
  DC16 0x3415,0x4e08,0x11a1
  DC16 0x1006,0xf753,0x7e82
  DC16 0x2c0a,0xbd3a,0xf235
  DC16 0x080f,0x2ad7,0xd2bb
  DC16 0x2415,0xeb86,0xd391
;         | |  |          |
; x[g]----+ |  +----+-----+
; ss -------+       |
; ac ---------------+
md5_state_table:
  DC32 0x67452301,0xefcdab89,0x98badcfe,0x10325476

;-----------------------------------------------------------
  SECTION `.near.rodata`:CONST:REORDER:NOROOT(0)
  DATA
SUB_ihgf:
  DC16 LWRD(__i),LWRD(__h),LWRD(__g),LWRD(__f)

  END
