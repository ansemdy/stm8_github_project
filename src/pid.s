;=========================================
; PID 控制器模块
; IQ10定点算法，无超调，系统稳定性好
;=========================================

  PUBLIC pid

; 目标值,signed int 类型变量
#define TargetValue    EEP_Data+34

; Kp,Ki,Kd,signed int 类型变量
; 数值使用16位IQ10表示,数值范围为±32.000
#define Kp             EEP_Data+38
#define Ki             EEP_Data+40
#define Kd             EEP_Data+42

#define D_Time         EEP_Data+44
#define I_Time         EEP_Data+46

; 采集值,unsigned int 类型变量
#define CollectValue   RamData+22

; 积分值,signed int 类型变量
#define integral       RamData+40

; 上一次偏差,signed int 类型变量
#define l_error        RamData+44

; 栈内保存偏差量
; 当前偏差,signed int 类型变量
#define v_error  (1,SP)

  EXTERN RamData
  EXTERN EEP_Data
  EXTERN smlaw_l0_x_uy

  SECTION `.near_func.text`:CODE:NOROOT(0)
  CODE

;---------------------------------------------
; unsigned int pid(BASE)
; BASE=基值
; 标准PID算法没有超值和死区,也就是说当偏差值为0时
; 输出值就会是基值,这样系统会有不稳定性
; 实际上,当目标值为0时也要基值,这样PID应该增加一个基值
; 所以称之为BPID算法,增加基值,系统稳定性会大大提高
; 这里使用IQ算法,输出值=实际值*4096
; 输出值范围必须在 0-4096-61440 之间
;---------------------------------------------
pid:
  SUB   SP,#2
  LDW   X,EEP_Data+34    ;加载目标值
  SUBW  X,RamData+22     ;减采集值
  LDW   v_error,X        ;保存偏差值
;
; 计算微分项
  SUBW  X,l_error
  JREQ  pid_calc_P
  LDW   Y,Kd
  JREQ  pid_calc_P
  CALLF smlaw_l0_x_uy

; 计算比例项
pid_calc_P:
  LDW   X,v_error
  LDW   l_error,X        ;顺序保存到上次偏差值
  JREQ  pid_epilogue
  LDW   Y,Kp
  CALLF smlaw_l0_x_uy
;
; 计算积分项
  LDW   X,v_error
  ADDW  X,integral
  JRNV  pid_calc_I
  JRNC  integral_Infinity
  LDW   X,#0x8000
  JRA   pid_calc_I
integral_Infinity:
  LDW   X,#0x7FFF
pid_calc_I:
  LDW   integral,X
  LDW   Y,Ki
  CALLF smlaw_l0_x_uy
;
; 计算输出值
pid_epilogue:
  ADD   SP,#2
  TNZ    0
  JREQ   pid_completion
  JRPL   pid_overflow
pid_overrun:
  CLRW  X
  RET
pid_overflow:
  CLRW  X
  DECW  X
  RET
pid_completion:
  LDW   X,1
  RET

  END
