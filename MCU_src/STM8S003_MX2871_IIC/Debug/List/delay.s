///////////////////////////////////////////////////////////////////////////////
//
// IAR C/C++ Compiler V2.20.3.189 for STM8                16/Jul/2026  17:41:37
// Copyright 2010-2017 IAR Systems AB.
// Standalone license - IAR Embedded Workbench for STMicroelectronics STM8
//
//    Source file  =  
//        E:\JiangSiyi\FPGA\DPLL_Low_Freq_Track\MCU_src\STM8S003_MX2871_IIC\src\delay.c
//    Command line =  
//        E:\JiangSiyi\FPGA\DPLL_Low_Freq_Track\MCU_src\STM8S003_MX2871_IIC\src\delay.c
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
//        E:\JiangSiyi\FPGA\DPLL_Low_Freq_Track\MCU_src\STM8S003_MX2871_IIC\Debug\List\delay.s
//
///////////////////////////////////////////////////////////////////////////////

        RTMODEL "__SystemLibrary", "DLib"
        RTMODEL "__code_model", "small"
        RTMODEL "__core", "stm8"
        RTMODEL "__data_model", "medium"
        RTMODEL "__rt_version", "4"

        EXTERN ?b0
        EXTERN ?b3
        EXTERN ?epilogue_l2
        EXTERN ?mov_l2_l0
        EXTERN ?mov_l2_l1
        EXTERN ?mov_w1_w5
        EXTERN ?mul16_x_x_w0
        EXTERN ?push_l2
        EXTERN ?udiv32_l0_l0_dl
        EXTERN ?w0
        EXTERN ?w1
        EXTERN ?w4
        EXTERN ?w5

        PUBLIC delay_ms
        PUBLIC delay_us
        PUBLIC fac_us
        
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
        
// E:\JiangSiyi\FPGA\DPLL_Low_Freq_Track\MCU_src\STM8S003_MX2871_IIC\src\delay.c
//    1 #include "delay.h"
//    2 

        SECTION `.near.data`:DATA:REORDER:NOROOT(0)
//    3 uint8_t fac_us=3; //us延时倍乘数 
fac_us:
        DC8 3
//    4 
//    5 
//    6 //延时函数初始化
//    7 //为确保准确度,请保证时钟频率最好为4的倍数,最低8Mhz
//    8 //clk:时钟频率(24/16/12/8等) 
//    9 //void delay_init(u8 clk)
//   10 //{
//   11 // if(clk>16)fac_us=(16-4)/4;//24Mhz时,stm8大概19个周期为1us
//   12 // else if(clk>4)fac_us=(clk-4)/4; 
//   13 // else fac_us=1;
//   14 //}
//   15 
//   16 
//   17 //延时nus
//   18 //延时时间=(fac_us*4+4)*nus*(T)
//   19 //其中,T为CPU运行频率(Mhz)的倒数,单位为us.
//   20 //准确度:
//   21 //92%  @24Mhz
//   22 //98%  @16Mhz
//   23 //98%  @12Mhz
//   24 //86%  @8Mhz

        SECTION `.near_func.text`:CODE:REORDER:NOROOT(0)
          CFI Block cfiBlock0 Using cfiCommon0
          CFI Function delay_us
        CODE
//   25 void delay_us(uint16_t nus)
//   26 {  
//   27   __asm(
//   28     "PUSH A          \n"  //1T,压栈
//   29     "DELAY_XUS:      \n"   
//   30     "LD A,fac_us     \n"   //1T,fac_us加载到累加器A
//   31     "DELAY_US_1:     \n"  
//   32     "NOP             \n"  //1T,nop延时
//   33     "DEC A           \n"  //1T,A--
//   34     "JRNE DELAY_US_1 \n"   //不等于0,则跳转(2T)到DELAY_US_1继续执行,若等于0,则不跳转(1T).
//   35     "NOP             \n"  //1T,nop延时
//   36     "DECW X          \n"  //1T,x--
//   37     "JRNE DELAY_XUS  \n"    //不等于0,则跳转(2T)到DELAY_XUS继续执行,若等于0,则不跳转(1T).
//   38     "POP A           \n"  //1T,出栈
//   39   ); 
delay_us:
        PUSH A          
??DELAY_XUS:
        
        LD A,fac_us     
??DELAY_US_1:
        
        NOP             
        DEC A           
        JRNE ??DELAY_US_1 
        NOP             
        DECW X          
        JRNE ??DELAY_XUS  
        POP A           
//   40 } 
        RET
          CFI EndBlock cfiBlock0
//   41 //延时nms  
//   42 //为保证准确度,nms不要大于16640.

        SECTION `.near_func.text`:CODE:REORDER:NOROOT(0)
          CFI Block cfiBlock1 Using cfiCommon0
          CFI Function delay_ms
        CODE
//   43 void delay_ms(uint32_t nms)
//   44 {
delay_ms:
        CALL      L:?push_l2
          CFI ?b11 Frame(CFA, -2)
          CFI ?b10 Frame(CFA, -3)
          CFI ?b9 Frame(CFA, -4)
          CFI ?b8 Frame(CFA, -5)
          CFI CFA SP+6
        CALL      L:?mov_l2_l0
//   45  uint8_t t;
//   46  if(nms>65)
        LDW       X, S:?w4
        CPW       X, #0x0
        JRNE      L:??delay_ms_0
        LDW       X, S:?w5
        CPW       X, #0x42
??delay_ms_0:
        JRC       L:??delay_ms_1
//   47  {
//   48     t=nms/65;
        CALL      L:?udiv32_l0_l0_dl
        DATA
        DC32      0x41
        CODE
        LD        A, S:?b3
        JRA       L:??delay_ms_2
//   49     while(t--)delay_us(65000);
??delay_ms_3:
        LDW       X, #0xfde8
        CALL      L:delay_us
??delay_ms_2:
        LD        S:?b0, A
        DEC       A
        TNZ       S:?b0
        JRNE      L:??delay_ms_3
//   50     nms=nms%65;
        CALL      L:?mov_l2_l1
//   51  }
//   52  delay_us(nms*1000);
??delay_ms_1:
        CALL      L:?mov_w1_w5
        LDW       X, #0x3e8
        LDW       S:?w0, X
        LDW       X, S:?w1
        CALL      L:?mul16_x_x_w0
        CALL      L:delay_us
//   53 }
        JP        L:?epilogue_l2
          CFI EndBlock cfiBlock1

        SECTION VREGS:DATA:REORDER:NOROOT(0)

        END
//   54 
//   55 
// 
//  1 byte  in section .near.data
// 80 bytes in section .near_func.text
// 
// 80 bytes of CODE memory
//  1 byte  of DATA memory
//
//Errors: none
//Warnings: 1
