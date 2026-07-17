///////////////////////////////////////////////////////////////////////////////
//
// IAR C/C++ Compiler V2.20.3.189 for STM8                16/Jul/2026  18:21:53
// Copyright 2010-2017 IAR Systems AB.
// Standalone license - IAR Embedded Workbench for STMicroelectronics STM8
//
//    Source file  =  
//        E:\JiangSiyi\FPGA\DPLL_Low_Freq_Track\MCU_src\STM8S003_MX2871_IIC\src\main.c
//    Command line =  
//        E:\JiangSiyi\FPGA\DPLL_Low_Freq_Track\MCU_src\STM8S003_MX2871_IIC\src\main.c
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
//        E:\JiangSiyi\FPGA\DPLL_Low_Freq_Track\MCU_src\STM8S003_MX2871_IIC\Debug\List\main.s
//
///////////////////////////////////////////////////////////////////////////////

        RTMODEL "__SystemLibrary", "DLib"
        RTMODEL "__code_model", "small"
        RTMODEL "__core", "stm8"
        RTMODEL "__data_model", "medium"
        RTMODEL "__rt_version", "4"

        EXTERN ?epilogue_l2
        EXTERN ?mov_l0_l2
        EXTERN ?mov_l1_l0
        EXTERN ?or32_l0_l0_l1
        EXTERN ?push_l2
        EXTERN ?sll32_l0_l0_a
        EXTERN ?w0
        EXTERN ?w1
        EXTERN ?w4
        EXTERN ?w5
        EXTERN EEPROM_Read_Data
        EXTERN EEPROM_Store_Data
        EXTERN IIC_CMD
        EXTERN IIC_Reg_Buff
        EXTERN IIC_Slave_Init
        EXTERN MAX2871_Init
        EXTERN MAX2871_RFOUT_OFF
        EXTERN MAX2871_RFOUT_ON
        EXTERN RedPitaya_Service
        EXTERN RedPitaya_Uart_Init
        EXTERN TIM4_Init
        EXTERN max2871_Set_Freq_10M

        PUBLIC IIC_CMD_Service
        PUBLIC PLL_Lock_Read
        PUBLIC main
        PUBLIC sys_init
        
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
        
// E:\JiangSiyi\FPGA\DPLL_Low_Freq_Track\MCU_src\STM8S003_MX2871_IIC\src\main.c
//    1 #include "max2891_pll_conf.h"
//    2 #include "control_protocol.h"
//    3 

        SECTION `.near_func.text`:CODE:REORDER:NOROOT(0)
          CFI Block cfiBlock0 Using cfiCommon0
          CFI Function bank_get_u32
        CODE
//    4 static uint32_t bank_get_u32(uint8_t offset)
//    5 {
bank_get_u32:
        CALL      L:?push_l2
          CFI ?b11 Frame(CFA, -2)
          CFI ?b10 Frame(CFA, -3)
          CFI ?b9 Frame(CFA, -4)
          CFI ?b8 Frame(CFA, -5)
          CFI CFA SP+6
//    6   uint32_t value;
//    7   value = IIC_Reg_Buff[offset];
        CLRW      X
        LD        XL, A
        ADDW      X, #IIC_Reg_Buff
        LDW       Y, X
        LD        A, (X)
        CLRW      X
        LD        XL, A
        LDW       S:?w5, X
        CLRW      X
        LDW       S:?w4, X
//    8   value |= (uint32_t)IIC_Reg_Buff[offset + 1] << 8;
        LDW       X, Y
        INCW      X
        LD        A, (X)
        CLRW      X
        LD        XL, A
        LDW       S:?w1, X
        CLRW      X
        LDW       S:?w0, X
        LD        A, #0x8
        CALL      L:?sll32_l0_l0_a
        CALL      L:?mov_l1_l0
        CALL      L:?mov_l0_l2
        CALL      L:?or32_l0_l0_l1
        CALL      L:?mov_l1_l0
//    9   value |= (uint32_t)IIC_Reg_Buff[offset + 2] << 16;
        LDW       X, Y
        ADDW      X, #0x2
        LD        A, (X)
        CLRW      X
        LD        XL, A
        LDW       S:?w1, X
        LD        A, #0x10
        CALL      L:?sll32_l0_l0_a
        CALL      L:?or32_l0_l0_l1
        CALL      L:?mov_l1_l0
//   10   value |= (uint32_t)IIC_Reg_Buff[offset + 3] << 24;
        LDW       X, Y
        ADDW      X, #0x3
        LD        A, (X)
        CLRW      X
        LD        XL, A
        LDW       S:?w1, X
        CLRW      X
        LDW       S:?w0, X
        LD        A, #0x18
        CALL      L:?sll32_l0_l0_a
        CALL      L:?or32_l0_l0_l1
//   11   return value;
        JP        L:?epilogue_l2
//   12 }
          CFI EndBlock cfiBlock0
//   13 

        SECTION `.near_func.text`:CODE:REORDER:NOROOT(0)
          CFI Block cfiBlock1 Using cfiCommon0
          CFI Function sys_init
        CODE
//   14 void sys_init(void)
//   15 {
//   16   CLK->ECKR = 0;
sys_init:
        CLR       L:0x50c1
//   17   CLK->CKDIVR = 0;
        CLR       L:0x50c6
//   18   CLK->PCKENR1 = 0;
        CLR       L:0x50c7
//   19   CLK->PCKENR2 = 0;
        CLR       L:0x50ca
//   20 
//   21   IIC_Slave_Init();
        CALL      L:IIC_Slave_Init
//   22   RedPitaya_Uart_Init();
        CALL      L:RedPitaya_Uart_Init
//   23   MAX2871_Init();
        CALL      L:MAX2871_Init
//   24   MAX2871_RFOUT_OFF();
        CALL      L:MAX2871_RFOUT_OFF
//   25   TIM4_Init();
        CALL      L:TIM4_Init
//   26   EEPROM_Read_Data();
        CALL      L:EEPROM_Read_Data
//   27 
//   28   IIC_Reg_Buff[CTRL_REG_CONTROL_FLAGS] = 0;
        CLR       L:IIC_Reg_Buff + 3
//   29   IIC_Reg_Buff[CTRL_REG_DPLL_STATUS] = 0;
        CLR       L:IIC_Reg_Buff + 65
//   30   IIC_Reg_Buff[CTRL_REG_MWS_STATUS] = 0;
        CLR       L:IIC_Reg_Buff + 66
//   31   IIC_Reg_Buff[CTRL_REG_LAST_ERROR] = CTRL_ERROR_NONE;
        CLR       L:IIC_Reg_Buff + 67
//   32   asm("rim");
        rim
//   33 }
        RET
          CFI EndBlock cfiBlock1
//   34 

        SECTION `.near_func.text`:CODE:REORDER:NOROOT(0)
          CFI Block cfiBlock2 Using cfiCommon0
          CFI Function IIC_CMD_Service
        CODE
//   35 void IIC_CMD_Service(void)
//   36 {
//   37   uint32_t frequency;
//   38 
//   39   if((IIC_CMD < 0xC0) || (IIC_CMD > 0xC9)) return;
IIC_CMD_Service:
        LDW       X, #IIC_CMD
        LD        A, (X)
        CP        A, #0xc0
        JRC       L:??IIC_CMD_Service_0
        LD        A, (X)
        CP        A, #0xca
        JRC       L:??IIC_CMD_Service_1
??IIC_CMD_Service_0:
        RET
//   40 
//   41   switch(IIC_CMD)
??IIC_CMD_Service_1:
        LD        A, (X)
        SUB       A, #0xc0
        JREQ      L:??IIC_CMD_Service_2
        DEC       A
        JREQ      L:??IIC_CMD_Service_3
        DEC       A
        JREQ      L:??IIC_CMD_Service_4
        DEC       A
        JREQ      L:??IIC_CMD_Service_5
        DEC       A
        JREQ      L:??IIC_CMD_Service_6
        SUB       A, #0x3
        JREQ      L:??IIC_CMD_Service_7
        DEC       A
        JREQ      L:??IIC_CMD_Service_8
        JRA       L:??IIC_CMD_Service_9
//   42   {
//   43   case 0xC0:
//   44     frequency = bank_get_u32(CTRL_REG_MWS_FREQ_KHZ);
??IIC_CMD_Service_2:
        LD        A, #0x4
        CALL      L:bank_get_u32
//   45     max2871_Set_Freq_10M(frequency, IIC_Reg_Buff[CTRL_REG_MWS_POWER] & 0x03);
        LD        A, #0x3
        AND       A, L:IIC_Reg_Buff + 8
        CALL      L:max2871_Set_Freq_10M
//   46     MAX2871_RFOUT_ON();
        CALL      L:MAX2871_RFOUT_ON
//   47     IIC_Reg_Buff[CTRL_REG_CONTROL_FLAGS] |= CTRL_FLAG_MWS_ENABLE;
        LD        A, #0x2
        OR        A, L:IIC_Reg_Buff + 3
        LD        L:IIC_Reg_Buff + 3, A
//   48     IIC_Reg_Buff[CTRL_REG_MWS_STATUS] |= CTRL_MWS_STATUS_ENABLED;
        LD        A, #0x1
        OR        A, L:IIC_Reg_Buff + 66
        LD        L:IIC_Reg_Buff + 66, A
//   49     break;
        JRA       L:??IIC_CMD_Service_9
//   50 
//   51   case 0xC1:
//   52     MAX2871_RFOUT_OFF();
??IIC_CMD_Service_3:
        CALL      L:MAX2871_RFOUT_OFF
//   53     IIC_Reg_Buff[CTRL_REG_CONTROL_FLAGS] &= (uint8_t)~CTRL_FLAG_MWS_ENABLE;
        LD        A, #0xfd
        AND       A, L:IIC_Reg_Buff + 3
        LD        L:IIC_Reg_Buff + 3, A
//   54     IIC_Reg_Buff[CTRL_REG_MWS_STATUS] &= (uint8_t)~CTRL_MWS_STATUS_ENABLED;
        LD        A, #0xfe
        AND       A, L:IIC_Reg_Buff + 66
        LD        L:IIC_Reg_Buff + 66, A
//   55     break;
        JRA       L:??IIC_CMD_Service_9
//   56 
//   57   case 0xC2:
//   58     EEPROM_Read_Data();
??IIC_CMD_Service_4:
        CALL      L:EEPROM_Read_Data
//   59     break;
        JRA       L:??IIC_CMD_Service_9
//   60 
//   61   case 0xC3:
//   62     EEPROM_Store_Data();
??IIC_CMD_Service_5:
        CALL      L:EEPROM_Store_Data
//   63     break;
        JRA       L:??IIC_CMD_Service_9
//   64 
//   65   case 0xC4:
//   66     IIC_Reg_Buff[CTRL_REG_REQUEST_SEQ]++;
??IIC_CMD_Service_6:
        LD        A, #0x1
        ADD       A, L:IIC_Reg_Buff + 2
        LD        L:IIC_Reg_Buff + 2, A
//   67     break;
        JRA       L:??IIC_CMD_Service_9
//   68 
//   69   case 0xC5:
//   70     break;
//   71 
//   72   case 0xC7:
//   73     IIC_Reg_Buff[CTRL_REG_CONTROL_FLAGS] |= CTRL_FLAG_DPLL_ENABLE;
??IIC_CMD_Service_7:
        LD        A, #0x1
        OR        A, L:IIC_Reg_Buff + 3
        LD        L:IIC_Reg_Buff + 3, A
//   74     IIC_Reg_Buff[CTRL_REG_REQUEST_SEQ]++;
        LD        A, #0x1
        ADD       A, L:IIC_Reg_Buff + 2
        LD        L:IIC_Reg_Buff + 2, A
//   75     break;
        JRA       L:??IIC_CMD_Service_9
//   76 
//   77   case 0xC8:
//   78     IIC_Reg_Buff[CTRL_REG_CONTROL_FLAGS] &= (uint8_t)~CTRL_FLAG_DPLL_ENABLE;
??IIC_CMD_Service_8:
        LD        A, #0xfe
        AND       A, L:IIC_Reg_Buff + 3
        LD        L:IIC_Reg_Buff + 3, A
//   79     IIC_Reg_Buff[CTRL_REG_REQUEST_SEQ]++;
        LD        A, #0x1
        ADD       A, L:IIC_Reg_Buff + 2
        LD        L:IIC_Reg_Buff + 2, A
//   80     break;
//   81 
//   82   case 0xC9:
//   83     break;
//   84 
//   85   default:
//   86     break;
//   87   }
//   88 
//   89   IIC_Reg_Buff[CTRL_REG_BRIDGE_STATUS] &= (uint8_t)(~CTRL_BRIDGE_STATUS_BUSY);
??IIC_CMD_Service_9:
        LD        A, #0xfe
        AND       A, L:IIC_Reg_Buff + 70
        LD        L:IIC_Reg_Buff + 70, A
//   90   IIC_CMD = 0;
        CLR       L:IIC_CMD
//   91 }
        RET
          CFI EndBlock cfiBlock2
//   92 

        SECTION `.near_func.text`:CODE:REORDER:NOROOT(0)
          CFI Block cfiBlock3 Using cfiCommon0
          CFI Function PLL_Lock_Read
        CODE
//   93 void PLL_Lock_Read(void)
//   94 {
//   95   if((MAX2871_LD_PORT->IDR & MAX2871_LD_PIN) == MAX2871_LD_PIN)
PLL_Lock_Read:
        BTJF      L:0x5001, #0x3, L:??PLL_Lock_Read_0
//   96   {
//   97     IIC_Reg_Buff[CTRL_REG_MWS_STATUS] |= CTRL_MWS_STATUS_LOCKED;
        LD        A, #0x2
        OR        A, L:IIC_Reg_Buff + 66
        LD        L:IIC_Reg_Buff + 66, A
        RET
//   98   }
//   99   else
//  100   {
//  101     IIC_Reg_Buff[CTRL_REG_MWS_STATUS] &= (uint8_t)~CTRL_MWS_STATUS_LOCKED;
??PLL_Lock_Read_0:
        LD        A, #0xfd
        AND       A, L:IIC_Reg_Buff + 66
        LD        L:IIC_Reg_Buff + 66, A
//  102   }
//  103 }
        RET
          CFI EndBlock cfiBlock3
//  104 

        SECTION `.near_func.text`:CODE:REORDER:NOROOT(0)
          CFI Block cfiBlock4 Using cfiCommon0
          CFI Function main
        CODE
//  105 void main(void)
//  106 {
//  107   sys_init();
main:
        CALL      L:sys_init
//  108   while(1)
//  109   {
//  110     IIC_CMD_Service();
??main_0:
        CALL      L:IIC_CMD_Service
//  111     RedPitaya_Service();
        CALL      L:RedPitaya_Service
//  112     PLL_Lock_Read();
        CALL      L:PLL_Lock_Read
        JRA       L:??main_0
//  113   }
//  114 }
          CFI EndBlock cfiBlock4

        SECTION VREGS:DATA:REORDER:NOROOT(0)

        END
// 
// 339 bytes in section .near_func.text
// 
// 339 bytes of CODE memory
//
//Errors: none
//Warnings: 1
