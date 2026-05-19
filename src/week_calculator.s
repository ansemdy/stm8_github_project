;=========================================
; 星期计算模块
; 使用蔡勒公式(Zeller's formula)
;=========================================

  PUBLIC week
  PUBLIC _week

  SECTION `.near_func.text`:CODE:NOROOT(0)
  CODE

;---------------------------------------------
; C接口: unsigned int week(char a_moon,char 0_day,unsigned int x_year)
; 输出: XH = 星期几的数值, XL = 一年中的第几周
; 破坏寄存器: A,X,RAM0
;---------------------------------------------
week:
  PUSH  #0
  JPF   _week

  DATA
WeekDays:
  ; 31+28+31+30+31+30+31+31+30+31+30+31
  DC16 31,59,90,120,151,181,212,243,273,304,334

;---------------------------------------------
  SECTION `.far_func.text`:CODE:NOROOT(0)
  CODE
_week:
  PUSHW Y
  PUSH  A
  PUSHW X

; 计算闰年校正1 (Year-1)/100
  DECW  X
  LDW   Y,X
  LD    A,#100
  DIV   X,A
  PUSHW X

; 计算闰年校正2 (Year-1)/4
  LDW   X,Y
  LD    A,#4
  DIV   X,A
  PUSHW X
;
; 判断当前是否闰年,如果是闰年则Day加1,二月中可能Day=32
; 能被4整除但不能被100整除,或者能被400整除的是闰年
  LD    A,(6,SP)  ;年的低字节
  AND   A,#3
  JRNE  WeekCalcDay
  LDW   X,Y
  INCW  X
  LD    A,#100
  DIV   X,A
  TNZ   A
  JRNE  LeapYearAdjustingDays
  LDW   X,(5,SP)  ;年
  LDW   Y,#400
  DIVW  X,Y
  TNZW  Y
  JRNE  WeekCalcDay
LeapYearAdjustingDays:
  INC   0

; 计算当前一年中的第几天
; 1,3,5,7,8,10,12月31天, 4,6,9,11月30天
WeekCalcDay:
  LD    A,(7,SP) ;月
  CLRW  X
  SUB   A,#2
  JRPL  LdWeekDays
  PUSH  0
  PUSH  #0
  JRA   CalcYearDiv400
LdWeekDays:
  RLWA  X,A
  SLAW  X
  LDW   X,(WeekDays,X)
  RRWA  X,A
  ADD   A,0
  RRWA  X,A
  ADC   A,#0
  RRWA  X,A
  PUSHW X

; 计算闰年校正3 (Year-1)/400
CalcYearDiv400:
  LDW   X,(7,SP)  ;年,减一次栈
  DECW  X
  LDW   Y,#400
  DIVW  X,Y

  ADDW  X,(3,SP) ;(Year-1)/4
  SUBW  X,(5,SP) ;(Year-1)/100
  ADDW  X,(7,SP) ;年
  LDW   Y,X
  ADDW  X,(1,SP) ;第几天
  DECW  X

  LD    A,#7
  DIV   X,A
  RLWA  X,A      ;星期几的数值到XL,再次就到XH
  LD    A,#7
  DIV   Y,A
  LD    0,A      ;1月1日是星期几
  LDW   Y,(1,SP) ;第几天
  LD    A,#7
  DIV   Y,A
  TNZ   A
  JREQ  WeekOffsetAdj
  INCW  Y
WeekOffsetAdj:
  SUB   A,0
  EXG   A,YL
  ADC   A,#0
  RLWA  X,A      ;星期几的数值到XL,年份的数值到XH
  ADD   SP,#9
  POPW  Y
  RETF

  END
