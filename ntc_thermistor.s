;=========================================
; NTC热敏电阻温度计算
; 声压/电压信号转换
;=========================================

  PUBLIC NtcToTemp
  PUBLIC SoundTodB
  PUBLIC ToVoltage

  EXTERN ufloat
  EXTERN fdiv32
  EXTERN _ln
  EXTERN fadd32_l0_l0_l1
  EXTERN fdiv32_l0_dc32_l1
  EXTERN fadd32_l0_l0_dc32
  EXTERN fshort
  EXTERN fmul32
  EXTERN _log

;---------------------------------------------
; unsigned int NtcToTemp(float B,unsigned int x)
; 计算公式: T=fshort(39500.0/(log(ufloat(ADC)/ufloat(1024-ADC))+13.248365)-2726.5)
; 输入参数: X=ADC转换值,B=ntc的B值（B值是浮点数）
; 输出参数: X=温度值的10倍
;
; 温度算法
; T=B/[ln(R)-ln(R25)+B/(273.15+25)] (K)
; R25=10k,ln(R25)=9.21034037
; B=3950,B/(273.15+25)=13.248365
; R0为偏移量的值,R=((float)(ADR[n])*R0)/(float)(1024-ADR[n])
;
; T=(int)(B/(log(((float)(n)*R0)/(float)(1024-n))+4.038025)-2726.5),耗时302uS
; 偏移量设为10k,B=3950,输出温度X10,公式为
; T=(int)(39500/(log(((float)(n))/(float)(1024-n))+13.248365)-2726.5),耗时295uS
;
; B值为3950,对应的电阻分别为5k,10k,50k,100k公式,使用计算公式
; 5k  T=(39500.0/(log((float)(n)/(float)(1024-n))+13.941512)-2726.5);T*10
; 10k T=(39500.0/(log((float)(n)/(float)(1024-n))+13.248365)-2726.5);T*10
; 50k T=(39500.0/(log((float)(n)/(float)(1024-n))+11.638927)-2726.5);T*10
; 100k T=(3950.0/(log((float)(n)/(float)(1024-n))+10.945780)-272.65);T*1
;---------------------------------------------
  SECTION `.near_func.text`:CODE:REORDER:NOROOT(0)
  CODE
NtcToTemp:
  PUSH  0
  PUSH  1
  PUSH  2
  PUSH  3
  PUSHW X
;
; (1024-n)
  SUBW  X,#1024
  NEGW  X
  CALL  ufloat
  MOVL  1,0
;
; n/(1024-n)
  POPW  X
  CALL  ufloat
  CALL  fdiv32
;
; ln(n/(1024-n))
  CALL  _ln
  POP   7
  POP   6
  POP   5
  POP   4
;
; ln()+对应B值常数
  CALL  fadd32_l0_l0_l1
;
  MOVL  1,0
  CALL  fdiv32_l0_dc32_l1
  DATA
  DC32 0x471a4c00  ;39500.0
  CODE
  CALL  fadd32_l0_l0_dc32
  DATA
  DC32 0xc52a6800  ;-2726.5
  CODE
  CALL  fshort
  TNZ   (1,SP)
  JRPL  2
  RET
  RETF

;---------------------------------------------
; 声压信号转换为分贝,ADC0转换为声压
;---------------------------------------------
  SECTION `.near_func.text`:CODE:REORDER:NOROOT(0)
  CODE
SoundTodB:
  LD    A,#5        ;声压参考值
  PUSHW X
  MUL   X,A
  LDW   0,X
  POPW  X
  SWAPW X
  MUL   X,A
  SWAPW X
  ADDW  X,0
  CALL  ufloat
  CALL  _ln
;
; 20*log(e) = 86.858894(0x42adb7c1)
  MOV   4,#0x42
  MOV   5,#0xad
  MOV   6,#0xb7
  MOV   7,#0xc1
To_dB_V_ret:
  CALL  fmul32
  CALL  fshort
  RETF

;---------------------------------------------
; 电压转换
;---------------------------------------------
ToVoltage:
  CALL  ufloat
  MOV   4,#0x40
  MOV   5,#0x26
  MOV   6,#0x97
  MOV   7,#0x1a
  JP    To_dB_V_ret

  END
