///////////////////////////////////////////////////////////////////////////////
//
// IAR C/C++ Compiler V2.20.3.189 for STM8                16/Jul/2026  18:21:53
// Copyright 2010-2017 IAR Systems AB.
// Standalone license - IAR Embedded Workbench for STMicroelectronics STM8
//
//    Source file  =  
//        E:\JiangSiyi\FPGA\DPLL_Low_Freq_Track\MCU_src\STM8S003_MX2871_IIC\src\MAX2871.c
//    Command line =  
//        E:\JiangSiyi\FPGA\DPLL_Low_Freq_Track\MCU_src\STM8S003_MX2871_IIC\src\MAX2871.c
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
//        E:\JiangSiyi\FPGA\DPLL_Low_Freq_Track\MCU_src\STM8S003_MX2871_IIC\Debug\List\MAX2871.s
//
///////////////////////////////////////////////////////////////////////////////

        RTMODEL "__SystemLibrary", "DLib"
        RTMODEL "__code_model", "small"
        RTMODEL "__core", "stm8"
        RTMODEL "__data_model", "medium"
        RTMODEL "__rt_version", "4"

        EXTERN ?add32_l0_l0_dl
        EXTERN ?b0
        EXTERN ?b1
        EXTERN ?b2
        EXTERN ?b4
        EXTERN ?epilogue_l2_w6
        EXTERN ?mov_l0_l2
        EXTERN ?mov_l2_l0
        EXTERN ?mov_w6_w1
        EXTERN ?or16_x_x_dw
        EXTERN ?push_l2
        EXTERN ?push_w6
        EXTERN ?sll16_x_x_4
        EXTERN ?sll16_x_x_6
        EXTERN ?sll32_l0_l0_a
        EXTERN ?udiv32_l0_l0_dl
        EXTERN ?umod32_l1_l0_dl
        EXTERN ?w0
        EXTERN ?w1
        EXTERN ?w3
        EXTERN ?w4
        EXTERN ?w5
        EXTERN ?w6

        PUBLIC MAX2871_GPIO_Init
        PUBLIC MAX2871_Init
        PUBLIC MAX2871_Init_Reg_Data
        PUBLIC MAX2871_RFOUT_OFF
        PUBLIC MAX2871_RFOUT_ON
        PUBLIC MAX2871_Reg_Data
        PUBLIC MAX2871_SPI_TX_Byte
        PUBLIC MAX2871_Send_Data
        PUBLIC max2871_Set_Freq_10M
        
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
        
// E:\JiangSiyi\FPGA\DPLL_Low_Freq_Track\MCU_src\STM8S003_MX2871_IIC\src\MAX2871.c
//    1 #include "MAX2871.h"
//    2 #include "control_protocol.h"
//    3 
//    4 //uint32_t MAX2871_Reg_Data[6]={0x00000000,0x20017D01,0x10004D42,0x00001F23,0x608C8104,0x00458005};

        SECTION `.near.data`:DATA:REORDER:NOROOT(0)
//    5 uint32_t MAX2871_Reg_Data[6]={0x00000000,0x20017D01,0x10004D42,0x00001F23,0x608C8124,0x00458005};
MAX2871_Reg_Data:
        DC32 0, 536968449, 268455234, 7971, 1619820836, 4554757

        SECTION `.near.rodata`:CONST:REORDER:NOROOT(0)
//    6 const uint32_t MAX2871_Init_Reg_Data[6]={0x00790000,0x2000CE21,0x11009EC2,0x00000283,0x63E201FC,0x01440005};
MAX2871_Init_Reg_Data:
        DC32 7929856, 536923681, 285253314, 643, 1675756028, 21233669
//    7 

        SECTION `.near_func.text`:CODE:REORDER:NOROOT(0)
          CFI Block cfiBlock0 Using cfiCommon0
          CFI Function MAX2871_GPIO_Init
        CODE
//    8 void MAX2871_GPIO_Init(void)
//    9 { 
//   10   MAX2871_RE_EN_PORT->ODR &=~MAX2871_RE_EN_PIN;
MAX2871_GPIO_Init:
        BRES      L:0x500a, #0x3
//   11   MAX2871_RE_EN_PORT->DDR |= MAX2871_RE_EN_PIN;//OUT
        BSET      L:0x500c, #0x3
//   12   MAX2871_RE_EN_PORT->CR1 |= MAX2871_RE_EN_PIN;//PP
        BSET      L:0x500d, #0x3
//   13   MAX2871_RE_EN_PORT->CR2 |= MAX2871_RE_EN_PIN;//10M 
        BSET      L:0x500e, #0x3
//   14   
//   15   MAX2871_LE_PORT->ODR |= MAX2871_LE_PIN;
        BSET      L:0x500f, #0x4
//   16   MAX2871_LE_PORT->DDR |= MAX2871_LE_PIN;//OUT
        BSET      L:0x5011, #0x4
//   17   MAX2871_LE_PORT->CR1 |= MAX2871_LE_PIN;//PP
        BSET      L:0x5012, #0x4
//   18   MAX2871_LE_PORT->CR2 |= MAX2871_LE_PIN;//10M 
        BSET      L:0x5013, #0x4
//   19     
//   20   MAX2871_CLK_PORT->ODR &=~MAX2871_CLK_PIN;
        BRES      L:0x500f, #0x3
//   21   MAX2871_CLK_PORT->DDR |= MAX2871_CLK_PIN;//OUT
        BSET      L:0x5011, #0x3
//   22   MAX2871_CLK_PORT->CR1 |= MAX2871_CLK_PIN;//PP
        BSET      L:0x5012, #0x3
//   23   MAX2871_CLK_PORT->CR2 |= MAX2871_CLK_PIN;//10M 
        BSET      L:0x5013, #0x3
//   24   
//   25   MAX2871_DATA_PORT->DDR |= MAX2871_DATA_PIN;//OUT
        BSET      L:0x5011, #0x2
//   26   MAX2871_DATA_PORT->CR1 |= MAX2871_DATA_PIN;//PP
        BSET      L:0x5012, #0x2
//   27   MAX2871_DATA_PORT->CR2 |= MAX2871_DATA_PIN;//10M 
        BSET      L:0x5013, #0x2
//   28    
//   29 #if (Use_MAX2871_LD_PIN!=0)  
//   30   //CFG->GCR |= 0x01;//disable SWIM interface
//   31   MAX2871_LD_PORT->CR2 &=~ MAX2871_LD_PIN;//interrupt disable
        BRES      L:0x5004, #0x3
//   32   MAX2871_LD_PORT->CR1 &=~ MAX2871_LD_PIN;//Floating input
        BRES      L:0x5003, #0x3
//   33   MAX2871_LD_PORT->DDR &=~ MAX2871_LD_PIN;//Input mode
        BRES      L:0x5002, #0x3
//   34 #endif
//   35 }
        RET
          CFI EndBlock cfiBlock0
//   36 

        SECTION `.near_func.text`:CODE:REORDER:NOROOT(0)
          CFI Block cfiBlock1 Using cfiCommon0
          CFI Function MAX2871_SPI_TX_Byte
        CODE
//   37 void MAX2871_SPI_TX_Byte(uint8_t Data)
//   38 {
MAX2871_SPI_TX_Byte:
        LD        S:?b1, A
//   39   uint8_t i;
//   40   for(i=0;i<8;i++)
        CLR       S:?b0
        JRA       L:??MAX2871_SPI_TX_Byte_0
//   41   {
//   42     MAX2871_CLK0();
//   43     if(Data&0x80)
//   44       MAX2871_DATA1();
//   45     else
//   46       MAX2871_DATA0();
??MAX2871_SPI_TX_Byte_1:
        BRES      L:0x500f, #0x2
//   47     Data<<=1;
??MAX2871_SPI_TX_Byte_2:
        LD        A, S:?b1
        SLL       A
        LD        S:?b1, A
//   48     MAX2871_CLK1();
        BSET      L:0x500f, #0x3
        LD        A, S:?b0
        INC       A
        LD        S:?b0, A
??MAX2871_SPI_TX_Byte_0:
        LD        A, S:?b0
        CP        A, #0x8
        JRNC      L:??MAX2871_SPI_TX_Byte_3
        BRES      L:0x500f, #0x3
        LD        A, S:?b1
        BCP       A, #0x80
        JREQ      L:??MAX2871_SPI_TX_Byte_1
        BSET      L:0x500f, #0x2
        JRA       L:??MAX2871_SPI_TX_Byte_2
//   49   }
//   50 }
??MAX2871_SPI_TX_Byte_3:
        RET
          CFI EndBlock cfiBlock1
//   51 

        SECTION `.near_func.text`:CODE:REORDER:NOROOT(0)
          CFI Block cfiBlock2 Using cfiCommon0
          CFI Function MAX2871_Send_Data
        CODE
//   52 void MAX2871_Send_Data(uint32_t* Reg_Data)
//   53 {
//   54   MAX2871_CLK0();
MAX2871_Send_Data:
        BRES      L:0x500f, #0x3
//   55   MAX2871_LE0();
        BRES      L:0x500f, #0x4
//   56 
//   57   MAX2871_SPI_TX_Byte(((uint8_t*)Reg_Data)[0]);
        LD        A, (X)
        CALL      L:MAX2871_SPI_TX_Byte
//   58   MAX2871_SPI_TX_Byte(((uint8_t*)Reg_Data)[1]);
        LDW       Y, X
        INCW      Y
        LD        A, (Y)
        CALL      L:MAX2871_SPI_TX_Byte
//   59   MAX2871_SPI_TX_Byte(((uint8_t*)Reg_Data)[2]);
        LDW       Y, X
        ADDW      Y, #0x2
        LD        A, (Y)
        CALL      L:MAX2871_SPI_TX_Byte
//   60   MAX2871_SPI_TX_Byte(((uint8_t*)Reg_Data)[3]);
        ADDW      X, #0x3
        LD        A, (X)
        CALL      L:MAX2871_SPI_TX_Byte
//   61 
//   62   MAX2871_CLK0();
        BRES      L:0x500f, #0x3
//   63   MAX2871_LE1();
        BSET      L:0x500f, #0x4
//   64 }
        RET
          CFI EndBlock cfiBlock2
//   65 
//   66 

        SECTION `.near_func.text`:CODE:REORDER:NOROOT(0)
          CFI Block cfiBlock3 Using cfiCommon0
          CFI Function MAX2871_RFOUT_ON
        CODE
//   67 void MAX2871_RFOUT_ON(void)
//   68 {
//   69   MAX2871_RE1();
MAX2871_RFOUT_ON:
        BSET      L:0x500a, #0x3
//   70 }
        RET
          CFI EndBlock cfiBlock3
//   71 

        SECTION `.near_func.text`:CODE:REORDER:NOROOT(0)
          CFI Block cfiBlock4 Using cfiCommon0
          CFI Function MAX2871_RFOUT_OFF
        CODE
//   72 void MAX2871_RFOUT_OFF(void)
//   73 {
//   74   MAX2871_RE0();
MAX2871_RFOUT_OFF:
        BRES      L:0x500a, #0x3
//   75 }
        RET
          CFI EndBlock cfiBlock4
//   76 

        SECTION `.near_func.text`:CODE:REORDER:NOROOT(0)
          CFI Block cfiBlock5 Using cfiCommon0
          CFI Function MAX2871_Init
        CODE
//   77 void MAX2871_Init(void)
//   78 {
//   79   uint8_t i=6;
MAX2871_Init:
        MOV       S:?b2, #0x6
//   80   MAX2871_GPIO_Init();
        CALL      L:MAX2871_GPIO_Init
        JRA       L:??MAX2871_Init_0
//   81   while(i--)
//   82   {
//   83     MAX2871_Send_Data((uint32_t*)&MAX2871_Init_Reg_Data[i]);
??MAX2871_Init_1:
        CLRW      X
        LD        XL, A
        SLLW      X
        SLLW      X
        ADDW      X, #MAX2871_Init_Reg_Data
        CALL      L:MAX2871_Send_Data
//   84   }
??MAX2871_Init_0:
        LD        A, S:?b2
        LD        S:?b0, A
        DEC       A
        LD        S:?b2, A
        TNZ       S:?b0
        JRNE      L:??MAX2871_Init_1
//   85   //MAX2871_RFOUT_ON();
//   86 }
        RET
          CFI EndBlock cfiBlock5
//   87 
//   88 //参考频率10MHz
//   89 //小数模式

        SECTION `.near_func.text`:CODE:REORDER:NOROOT(0)
          CFI Block cfiBlock6 Using cfiCommon0
          CFI Function max2871_Set_Freq_10M
        CODE
//   90 void max2871_Set_Freq_10M(uint32_t fre,uint8_t dbm)
//   91 {
max2871_Set_Freq_10M:
        CALL      L:?push_l2
          CFI ?b11 Frame(CFA, -2)
          CFI ?b10 Frame(CFA, -3)
          CFI ?b9 Frame(CFA, -4)
          CFI ?b8 Frame(CFA, -5)
          CFI CFA SP+6
        CALL      L:?push_w6
          CFI ?b13 Frame(CFA, -6)
          CFI ?b12 Frame(CFA, -7)
          CFI CFA SP+8
        CALL      L:?mov_l2_l0
        LD        S:?b4, A
//   92   uint16_t N,F;
//   93   uint8_t i,ADIV;
//   94   
//   95   if((fre < CTRL_MWS_FREQ_MIN_KHZ) || (fre > CTRL_MWS_FREQ_MAX_KHZ)) return;
        CALL      L:?add32_l0_l0_dl
        DATA
        DC32      0xffffa434
        CODE
        LDW       X, S:?w0
        CPW       X, #0x61
        JRNE      L:??max2871_Set_Freq_10M_0
        LDW       X, S:?w1
        CPW       X, #0x4c35
??max2871_Set_Freq_10M_0:
        JRC       ??lb_0
        JP        L:??max2871_Set_Freq_10M_1
//   96 
//   97   ((uint16_t*)&MAX2871_Reg_Data[4])[1]= 0x8124 | (dbm<<6)| (dbm<<3);
??lb_0:
        CLRW      Y
        LD        A, S:?b4
        LD        YL, A
        LDW       X, Y
        SLLW      X
        SLLW      X
        SLLW      X
        LDW       S:?w0, X
        LDW       X, Y
        CALL      L:?sll16_x_x_6
        RRWA      X, A
        OR        A, S:?b1
        RRWA      X, A
        OR        A, S:?b0
        RRWA      X, A
        CALL      L:?or16_x_x_dw
        DATA
        DC16      0x8124
        CODE
        LDW       L:MAX2871_Reg_Data + 18, X
//   98   if(fre>3000000)
        LDW       X, S:?w4
        CPW       X, #0x2d
        JRNE      L:??max2871_Set_Freq_10M_2
        LDW       X, S:?w5
        CPW       X, #0xc6c1
??max2871_Set_Freq_10M_2:
        JRC       L:??max2871_Set_Freq_10M_3
//   99   {
//  100           ADIV=0;
        CLR       A
        JP        L:??max2871_Set_Freq_10M_4
//  101   }
//  102   else if(fre>1500000)
??max2871_Set_Freq_10M_3:
        LDW       X, S:?w4
        CPW       X, #0x16
        JRNE      L:??max2871_Set_Freq_10M_5
        LDW       X, S:?w5
        CPW       X, #0xe361
??max2871_Set_Freq_10M_5:
        JRC       L:??max2871_Set_Freq_10M_6
//  103   {
//  104           fre=fre*2;
        CALL      L:?mov_l0_l2
        LD        A, #0x1
        CALL      L:?sll32_l0_l0_a
        CALL      L:?mov_l2_l0
//  105           ADIV=1;
        LD        A, #0x1
        JP        L:??max2871_Set_Freq_10M_4
//  106   }
//  107   else if(fre>750000)
??max2871_Set_Freq_10M_6:
        LDW       X, S:?w4
        CPW       X, #0xb
        JRNE      L:??max2871_Set_Freq_10M_7
        LDW       X, S:?w5
        CPW       X, #0x71b1
??max2871_Set_Freq_10M_7:
        JRC       L:??max2871_Set_Freq_10M_8
//  108   {
//  109           fre=fre*4;
        CALL      L:?mov_l0_l2
        LD        A, #0x2
        CALL      L:?sll32_l0_l0_a
        CALL      L:?mov_l2_l0
//  110           ADIV=2;
        LD        A, #0x2
        JP        L:??max2871_Set_Freq_10M_4
//  111   }
//  112   else if(fre>375000)
??max2871_Set_Freq_10M_8:
        LDW       X, S:?w4
        CPW       X, #0x5
        JRNE      L:??max2871_Set_Freq_10M_9
        LDW       X, S:?w5
        CPW       X, #0xb8d9
??max2871_Set_Freq_10M_9:
        JRC       L:??max2871_Set_Freq_10M_10
//  113   {
//  114           fre=fre*8;
        CALL      L:?mov_l0_l2
        LD        A, #0x3
        CALL      L:?sll32_l0_l0_a
        CALL      L:?mov_l2_l0
//  115           ADIV=3;
        LD        A, #0x3
        JRA       L:??max2871_Set_Freq_10M_4
//  116   }
//  117   else if(fre>187500)
??max2871_Set_Freq_10M_10:
        LDW       X, S:?w4
        CPW       X, #0x2
        JRNE      L:??max2871_Set_Freq_10M_11
        LDW       X, S:?w5
        CPW       X, #0xdc6d
??max2871_Set_Freq_10M_11:
        JRC       L:??max2871_Set_Freq_10M_12
//  118   {
//  119           fre=fre*16;
        CALL      L:?mov_l0_l2
        LD        A, #0x4
        CALL      L:?sll32_l0_l0_a
        CALL      L:?mov_l2_l0
//  120           ADIV=4;
        LD        A, #0x4
        JRA       L:??max2871_Set_Freq_10M_4
//  121   }
//  122   else if(fre>93750)
??max2871_Set_Freq_10M_12:
        LDW       X, S:?w4
        CPW       X, #0x1
        JRNE      L:??max2871_Set_Freq_10M_13
        LDW       X, S:?w5
        CPW       X, #0x6e37
??max2871_Set_Freq_10M_13:
        JRC       L:??max2871_Set_Freq_10M_14
//  123   {
//  124           fre=fre*32;
        CALL      L:?mov_l0_l2
        LD        A, #0x5
        CALL      L:?sll32_l0_l0_a
        CALL      L:?mov_l2_l0
//  125           ADIV=5;
        LD        A, #0x5
        JRA       L:??max2871_Set_Freq_10M_4
//  126   }
//  127   else if(fre>46880)
??max2871_Set_Freq_10M_14:
        LDW       X, S:?w4
        CPW       X, #0x0
        JRNE      L:??max2871_Set_Freq_10M_15
        LDW       X, S:?w5
        CPW       X, #0xb721
??max2871_Set_Freq_10M_15:
        JRC       L:??max2871_Set_Freq_10M_16
//  128   {
//  129           fre=fre*64;
        CALL      L:?mov_l0_l2
        LD        A, #0x6
        CALL      L:?sll32_l0_l0_a
        CALL      L:?mov_l2_l0
//  130           ADIV=6;
        LD        A, #0x6
        JRA       L:??max2871_Set_Freq_10M_4
//  131   }
//  132   else
//  133   {
//  134           fre=fre*128;
??max2871_Set_Freq_10M_16:
        CALL      L:?mov_l0_l2
        LD        A, #0x7
        CALL      L:?sll32_l0_l0_a
        CALL      L:?mov_l2_l0
//  135           ADIV=7;
        LD        A, #0x7
//  136   }
//  137   ((uint16_t*)&MAX2871_Reg_Data[4])[0]= 0x608C | (ADIV<<4);
??max2871_Set_Freq_10M_4:
        CLRW      X
        LD        XL, A
        CALL      L:?sll16_x_x_4
        CALL      L:?or16_x_x_dw
        DATA
        DC16      0x608c
        CODE
        LDW       L:MAX2871_Reg_Data + 16, X
//  138   N=fre/10000;
        CALL      L:?mov_l0_l2
        CALL      L:?udiv32_l0_l0_dl
        DATA
        DC32      0x2710
        CODE
        CALL      L:?mov_w6_w1
//  139   F=(fre%10000)*2;//M=4000
//  140   F/=5;  
//  141   ((uint16_t*)&MAX2871_Reg_Data[0])[0]= N>>1;
        LDW       X, S:?w6
        SRLW      X
        LDW       L:MAX2871_Reg_Data, X
//  142   ((uint16_t*)&MAX2871_Reg_Data[0])[1]= (N<<15)|(F<<3);
        CALL      L:?mov_l0_l2
        CALL      L:?umod32_l1_l0_dl
        DATA
        DC32      0x2710
        CODE
        LDW       X, S:?w3
        SLLW      X
        LDW       Y, #0x5
        DIVW      X, Y
        SLLW      X
        SLLW      X
        SLLW      X
        LDW       S:?w0, X
        LDW       X, S:?w6
        SRLW      X
        CLRW      X
        RRCW      X
        RRWA      X, A
        OR        A, S:?b1
        RRWA      X, A
        OR        A, S:?b0
        RRWA      X, A
        LDW       L:MAX2871_Reg_Data + 2, X
//  143   //MAX2871_Reg_Data[4] = 0x608C80E4|(ADIV<<20)|(dbm<<3);
//  144   //MAX2871_Reg_Data[0] = 0x00000000|(N<<15)|(F<<3);
//  145   i=6;
        MOV       S:?b2, #0x6
        JRA       L:??max2871_Set_Freq_10M_17
//  146   while(i--)
//  147   {
//  148     MAX2871_Send_Data(&MAX2871_Reg_Data[i]);
??max2871_Set_Freq_10M_18:
        CLRW      X
        LD        XL, A
        SLLW      X
        SLLW      X
        ADDW      X, #MAX2871_Reg_Data
        CALL      L:MAX2871_Send_Data
//  149   }
??max2871_Set_Freq_10M_17:
        LD        A, S:?b2
        LD        S:?b0, A
        DEC       A
        LD        S:?b2, A
        TNZ       S:?b0
        JRNE      L:??max2871_Set_Freq_10M_18
//  150   
//  151 //  max2871_send_data(0x00458005);   //0000 0001 0100 0000 0000 0000 0000 0101
//  152 //  max2871_send_data(0x608C80E4|(ADIV<<20)|(dbm<<3));   //0000 0000 0000 0000 0001 1111 0010 0011
//  153 //  max2871_send_data(0x00001F23);   //0000 0000 0000 0000 0001 1111 0010 0011
//  154 //  //max2871_send_data(0x10005F42);   //0010 0000 0000 0000 1000 0011 0010 0001
//  155 //  max2871_send_data(0x10004D42);   //0010 0000 0000 0000 1000 0011 0010 0001
//  156 //  max2871_send_data(0x20017D01);   //0010 0000 0000 0000 1000 0011 0010 0001
//  157 //  max2871_send_data(0x00000000|(N<<15)|(F<<3));   //0000 0000 1001 0110 0000 0000 0000 0000
//  158 }
??max2871_Set_Freq_10M_1:
        JP        L:?epilogue_l2_w6
          CFI EndBlock cfiBlock6

        SECTION VREGS:DATA:REORDER:NOROOT(0)

        END
//  159 
//  160 
//  161 
// 
//  24 bytes in section .near.data
//  24 bytes in section .near.rodata
// 582 bytes in section .near_func.text
// 
// 582 bytes of CODE  memory
//  24 bytes of CONST memory
//  24 bytes of DATA  memory
//
//Errors: none
//Warnings: 1
