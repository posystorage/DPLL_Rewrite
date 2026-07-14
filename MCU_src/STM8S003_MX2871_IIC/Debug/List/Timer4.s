///////////////////////////////////////////////////////////////////////////////
//
// IAR C/C++ Compiler V2.20.3.189 for STM8                14/Jul/2026  16:44:58
// Copyright 2010-2017 IAR Systems AB.
// Standalone license - IAR Embedded Workbench for STMicroelectronics STM8
//
//    Source file  =  
//        E:\JiangSiyi\FPGA\DPLL_Low_Freq_Track\MCU_src\STM8S003_MX2871_IIC\src\Timer4.c
//    Command line =  
//        E:\JiangSiyi\FPGA\DPLL_Low_Freq_Track\MCU_src\STM8S003_MX2871_IIC\src\Timer4.c
//        -e -Om --no_unroll --no_inline --no_tbaa --no_cross_call --debug
//        --code_model small --data_model medium -o
//        E:\JiangSiyi\FPGA\DPLL_Low_Freq_Track\MCU_src\STM8S003_MX2871_IIC\Debug\Obj
//        --dlib_config "C:\Program Files (x86)\IAR Systems\Embedded Workbench
//        7.3\stm8\LIB\dlstm8smn.h" -lA
//        E:\JiangSiyi\FPGA\DPLL_Low_Freq_Track\MCU_src\STM8S003_MX2871_IIC\Debug\List
//        -I
//        E:\JiangSiyi\FPGA\DPLL_Low_Freq_Track\MCU_src\STM8S003_MX2871_IIC\src\
//        --vregs 16
//    List file    =  
//        E:\JiangSiyi\FPGA\DPLL_Low_Freq_Track\MCU_src\STM8S003_MX2871_IIC\Debug\List\Timer4.s
//
///////////////////////////////////////////////////////////////////////////////

        RTMODEL "__SystemLibrary", "DLib"
        RTMODEL "__code_model", "small"
        RTMODEL "__core", "stm8"
        RTMODEL "__data_model", "medium"
        RTMODEL "__rt_version", "4"

        EXTERN ?pop_l0
        EXTERN ?pop_l1
        EXTERN ?push_l0
        EXTERN ?push_l1
        EXTERN RedPitaya_2ms_Tick

        PUBLIC TIM4_Init
        PUBLIC TIM4_UPD_OVF_IRQHandler
        PUBLIC _interrupt_25
        PUBLIC sys_delay
        
          CFI Names cfiNames0
          CFI StackFrame CFA SP DATA
          CFI Resource A:8, XL:8, XH:8, YL:8, YH:8, SP:16, CC:8, PC:24, PCL:8
          CFI Resource PCH:8, PCE:8, ?b0:8, ?b1:8, ?b2:8, ?b3:8, ?b4:8, ?b5:8
          CFI Resource ?b6:8, ?b7:8, ?b8:8, ?b9:8, ?b10:8, ?b11:8, ?b12:8, ?b13:8
          CFI Resource ?b14:8, ?b15:8
          CFI ResourceParts PC PCE, PCH, PCL
          CFI EndNames cfiNames0
        
          CFI Common cfiCommon0 Using cfiNames0
          CFI CodeAlign 1
          CFI DataAlign 1
          CFI ReturnAddress PC CODE
          CFI CFA SP+2
          CFI A Undefined
          CFI XL Undefined
          CFI XH Undefined
          CFI YL Undefined
          CFI YH Undefined
          CFI CC Undefined
          CFI PC Concat
          CFI PCL Frame(CFA, 0)
          CFI PCH Frame(CFA, -1)
          CFI PCE SameValue
          CFI ?b0 Undefined
          CFI ?b1 Undefined
          CFI ?b2 Undefined
          CFI ?b3 Undefined
          CFI ?b4 Undefined
          CFI ?b5 Undefined
          CFI ?b6 Undefined
          CFI ?b7 Undefined
          CFI ?b8 SameValue
          CFI ?b9 SameValue
          CFI ?b10 SameValue
          CFI ?b11 SameValue
          CFI ?b12 SameValue
          CFI ?b13 SameValue
          CFI ?b14 SameValue
          CFI ?b15 SameValue
          CFI EndCommon cfiCommon0
        
        
          CFI Common cfiCommon1 Using cfiNames0
          CFI CodeAlign 1
          CFI DataAlign 1
          CFI ReturnAddress PC CODE
          CFI CFA SP+9
          CFI A Frame(CFA, -7)
          CFI XL Frame(CFA, -5)
          CFI XH Frame(CFA, -6)
          CFI YL Frame(CFA, -3)
          CFI YH Frame(CFA, -4)
          CFI CC Frame(CFA, -8)
          CFI PC Frame(CFA, -2)
          CFI PCL Undefined
          CFI PCH Undefined
          CFI PCE Undefined
          CFI ?b0 SameValue
          CFI ?b1 SameValue
          CFI ?b2 SameValue
          CFI ?b3 SameValue
          CFI ?b4 SameValue
          CFI ?b5 SameValue
          CFI ?b6 SameValue
          CFI ?b7 SameValue
          CFI ?b8 SameValue
          CFI ?b9 SameValue
          CFI ?b10 SameValue
          CFI ?b11 SameValue
          CFI ?b12 SameValue
          CFI ?b13 SameValue
          CFI ?b14 SameValue
          CFI ?b15 SameValue
          CFI EndCommon cfiCommon1
        
// E:\JiangSiyi\FPGA\DPLL_Low_Freq_Track\MCU_src\STM8S003_MX2871_IIC\src\Timer4.c
//    1 #include "Timer4.h"
//    2 #include "RedPitaya.h"

        SECTION `.near.bss`:DATA:REORDER:NOROOT(0)
//    3 uint16_t sys_delay;
sys_delay:
        DS8 2
//    4 

        SECTION `.near_func.text`:CODE:REORDER:NOROOT(0)
          CFI Block cfiBlock0 Using cfiCommon0
          CFI Function TIM4_Init
        CODE
//    5 void TIM4_Init(void)//2ms一次中断
//    6 { 
//    7   CLK->PCKENR1 |= 0x10;//time4 clk OPEN
TIM4_Init:
        BSET      L:0x50c7, #0x4
//    8   TIM4->CNTR =0;
        CLR       L:0x5346
//    9   TIM4->CR1 =0X80;   //允许自动重载
        MOV       L:0x5340, #0x80
//   10   /* Set the Prescaler value 128*/
//   11   TIM4->PSCR = 0x07;
        MOV       L:0x5347, #0x7
//   12   /* Set the Autoreload value 250-1*/
//   13   TIM4->ARR = 0xF9;
        MOV       L:0x5348, #0xf9
//   14   /* Enable the Interrupt sources */
//   15   TIM4->IER = 0x01; 
        MOV       L:0x5343, #0x1
//   16   TIM4->SR1  =0X00;   //清中断标志位
        CLR       L:0x5344
//   17   TIM4->EGR =0X00;   //更新事件产生
        CLR       L:0x5345
//   18   /* set or Reset the CEN Bit */
//   19   TIM4->CR1 |= TIM6_CR1_CEN;//使能
        BSET      L:0x5340, #0x0
//   20   ITC->ISPR6 &=~ 0xC0;
        LD        A, #0x3f
        AND       A, L:0x7f75
        LD        L:0x7f75, A
//   21   ITC->ISPR6 |=  0x40;
        BSET      L:0x7f75, #0x6
//   22   sys_delay=0;
        CLRW      X
        LDW       L:sys_delay, X
//   23 }
        RET
          CFI EndBlock cfiBlock0
//   24 
//   25 void EEPROM_Auto_Save_Timer(void);
//   26 

        SECTION `.near_func.text`:CODE:REORDER:NOROOT(0)
          CFI Block cfiBlock1 Using cfiCommon1
          CFI Function TIM4_UPD_OVF_IRQHandler
        CODE
//   27 INTERRUPT_HANDLER(TIM4_UPD_OVF_IRQHandler, 23)
//   28 {
TIM4_UPD_OVF_IRQHandler:
_interrupt_25:
        PUSH      CC
          CFI CFA SP+10
        POP       A
          CFI CFA SP+9
        AND       A, #0xbf
        PUSH      A
          CFI CFA SP+10
        POP       CC
          CFI CFA SP+9
        CALL      L:?push_l0
          CFI ?b3 Frame(CFA, -9)
          CFI ?b2 Frame(CFA, -10)
          CFI ?b1 Frame(CFA, -11)
          CFI ?b0 Frame(CFA, -12)
          CFI CFA SP+13
        CALL      L:?push_l1
          CFI ?b7 Frame(CFA, -13)
          CFI ?b6 Frame(CFA, -14)
          CFI ?b5 Frame(CFA, -15)
          CFI ?b4 Frame(CFA, -16)
          CFI CFA SP+17
//   29   TIM4->SR1=0;//清中断
        CLR       L:0x5344
//   30   RedPitaya_2ms_Tick();
        CALL      L:RedPitaya_2ms_Tick
//   31 }
        CALL      L:?pop_l1
          CFI ?b4 SameValue
          CFI ?b5 SameValue
          CFI ?b6 SameValue
          CFI ?b7 SameValue
          CFI CFA SP+13
        CALL      L:?pop_l0
          CFI ?b0 SameValue
          CFI ?b1 SameValue
          CFI ?b2 SameValue
          CFI ?b3 SameValue
          CFI CFA SP+9
        IRET
          CFI EndBlock cfiBlock1

        SECTION VREGS:DATA:REORDER:NOROOT(0)

        END
// 
//  2 bytes in section .near.bss
// 79 bytes in section .near_func.text
// 
// 79 bytes of CODE memory
//  2 bytes of DATA memory
//
//Errors: none
//Warnings: none
