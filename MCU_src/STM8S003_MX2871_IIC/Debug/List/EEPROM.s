///////////////////////////////////////////////////////////////////////////////
//
// IAR C/C++ Compiler V2.20.3.189 for STM8                16/Jul/2026  17:41:37
// Copyright 2010-2017 IAR Systems AB.
// Standalone license - IAR Embedded Workbench for STMicroelectronics STM8
//
//    Source file  =  
//        E:\JiangSiyi\FPGA\DPLL_Low_Freq_Track\MCU_src\STM8S003_MX2871_IIC\src\EEPROM.c
//    Command line =  
//        E:\JiangSiyi\FPGA\DPLL_Low_Freq_Track\MCU_src\STM8S003_MX2871_IIC\src\EEPROM.c
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
//        E:\JiangSiyi\FPGA\DPLL_Low_Freq_Track\MCU_src\STM8S003_MX2871_IIC\Debug\List\EEPROM.s
//
///////////////////////////////////////////////////////////////////////////////

        RTMODEL "__SystemLibrary", "DLib"
        RTMODEL "__code_model", "small"
        RTMODEL "__core", "stm8"
        RTMODEL "__data_model", "medium"
        RTMODEL "__rt_version", "4"

        #define SHT_PROGBITS 0x1
        #define SHF_WRITE 0x1
        #define SHF_EXECINSTR 0x4

        EXTERN ?b0
        EXTERN ?b1
        EXTERN ?b2
        EXTERN ?b3
        EXTERN ?b4
        EXTERN ?epilogue_w4
        EXTERN ?push_w4
        EXTERN ?w0
        EXTERN ?w1
        EXTERN ?w3
        EXTERN ?w4
        EXTERN ?xor16_x_x_dw
        EXTERN IIC_Reg_Buff

        PUBLIC EEPROM_Load_Defaults
        PUBLIC EEPROM_Read_Data
        PUBLIC EEPROM_Store_Data
        
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
        
// E:\JiangSiyi\FPGA\DPLL_Low_Freq_Track\MCU_src\STM8S003_MX2871_IIC\src\EEPROM.c
//    1 #include "EEPROM.h"
//    2 #include "IIC.h"
//    3 
//    4 #define EEPROM_Write_Addr 0x04240
//    5 #define EEPROM_MAGIC 0xA5
//    6 

        SECTION `.near_func.text`:CODE:NOROOT(0)
          CFI Block cfiBlock0 Using cfiCommon0
          CFI Function bank_put_u16
        CODE
//    7 static void bank_put_u16(uint8_t offset, uint16_t value)
//    8 {
//    9   IIC_Reg_Buff[offset] = (uint8_t)value;
bank_put_u16:
        CLRW      Y
        LD        YL, A
        ADDW      Y, #IIC_Reg_Buff
        LD        A, XL
        LD        (Y), A
//   10   IIC_Reg_Buff[offset + 1] = (uint8_t)(value >> 8);
        LD        A, XH
        LDW       X, Y
        INCW      X
        LD        (X), A
//   11 }
        RET
          CFI EndBlock cfiBlock0
//   12 

        SECTION `.near_func.text`:CODE:NOROOT(0)
          CFI Block cfiBlock1 Using cfiCommon0
          CFI Function bank_put_u32
        CODE
//   13 static void bank_put_u32(uint8_t offset, uint32_t value)
//   14 {
//   15   IIC_Reg_Buff[offset] = (uint8_t)value;
bank_put_u32:
        CLRW      X
        LD        XL, A
        ADDW      X, #IIC_Reg_Buff
        LD        A, S:?b3
        LD        (X), A
//   16   IIC_Reg_Buff[offset + 1] = (uint8_t)(value >> 8);
        LD        A, S:?b2
        INCW      X
        LD        (X), A
        DECW      X
//   17   IIC_Reg_Buff[offset + 2] = (uint8_t)(value >> 16);
        LD        A, S:?b1
        ADDW      X, #0x2
        LD        (X), A
        SUBW      X, #0x2
//   18   IIC_Reg_Buff[offset + 3] = (uint8_t)(value >> 24);
        LD        A, S:?b0
        ADDW      X, #0x3
        LD        (X), A
//   19 }
        RET
          CFI EndBlock cfiBlock1
//   20 

        SECTION `.near_func.text`:CODE:NOROOT(0)
          CFI Block cfiBlock2 Using cfiCommon0
          CFI Function eeprom_crc16
        CODE
//   21 static uint16_t eeprom_crc16(const volatile uint8_t *data, uint8_t length)
//   22 {
eeprom_crc16:
        LDW       S:?w3, X
        LD        S:?b4, A
//   23   uint8_t i;
//   24   uint8_t bit;
//   25   uint16_t crc = 0xFFFF;
        LDW       Y, #0xffff
//   26   for(i = 0; i < length; i++)
        CLR       S:?b2
        JRA       L:??eeprom_crc16_0
??eeprom_crc16_1:
        LD        A, S:?b2
        INC       A
        LD        S:?b2, A
??eeprom_crc16_0:
        LD        A, S:?b2
        CP        A, S:?b4
        JRNC      L:??eeprom_crc16_2
//   27   {
//   28     crc ^= (uint16_t)data[i] << 8;
        CLRW      X
        LD        XL, A
        ADDW      X, S:?w3
        LD        A, (X)
        CLRW      X
        LD        XL, A
        CLR       A
        RLWA      X, A
        LDW       S:?w0, X
        EXGW      X, Y
        RLWA      X, A
        XOR       A, S:?b0
        RRWA      X, A
        EXGW      X, Y
//   29     for(bit = 0; bit < 8; bit++)
        CLR       S:?b3
        JRA       L:??eeprom_crc16_3
//   30     {
//   31       if(crc & 0x8000) crc = (uint16_t)((crc << 1) ^ 0x1021);
//   32       else crc <<= 1;
??eeprom_crc16_4:
        LDW       Y, X
??eeprom_crc16_5:
        INC       A
        LD        S:?b3, A
??eeprom_crc16_3:
        LD        A, S:?b3
        CP        A, #0x8
        JRNC      L:??eeprom_crc16_1
        LDW       X, Y
        SLLW      X
        EXGW      X, Y
        RLWA      X, A
        AND       A, #0x80
        RLWA      X, A
        CLR       A
        RLWA      X, A
        EXGW      X, Y
        TNZW      Y
        JREQ      L:??eeprom_crc16_4
        CALL      L:?xor16_x_x_dw
        DATA
        DC16      0x1021
        CODE
        LDW       Y, X
        JRA       L:??eeprom_crc16_5
//   33     }
//   34   }
//   35   return crc;
??eeprom_crc16_2:
        LDW       X, Y
        RET
//   36 }
          CFI EndBlock cfiBlock2
//   37 

        SECTION `.near_func.text`:CODE:REORDER:NOROOT(0)
          CFI Block cfiBlock3 Using cfiCommon0
          CFI Function EEPROM_Load_Defaults
        CODE
//   38 void EEPROM_Load_Defaults(void)
//   39 {
//   40   uint8_t i;
//   41   for(i = CTRL_PERSIST_BEGIN; i < CTRL_PERSIST_END; i++) IIC_Reg_Buff[i] = 0;
EEPROM_Load_Defaults:
        MOV       S:?b0, #0x4
        JRA       L:??EEPROM_Load_Defaults_0
??EEPROM_Load_Defaults_1:
        CLRW      X
        LD        XL, A
        CLR       A
        LD        (L:IIC_Reg_Buff,X), A
        LD        A, S:?b0
        INC       A
        LD        S:?b0, A
??EEPROM_Load_Defaults_0:
        LD        A, S:?b0
        CP        A, #0x40
        JRC       L:??EEPROM_Load_Defaults_1
//   42 
//   43   bank_put_u32(CTRL_REG_MWS_FREQ_KHZ, 25000UL);
        LDW       X, #0x61a8
        LDW       S:?w1, X
        CLRW      X
        LDW       S:?w0, X
        LD        A, #0x4
        CALL      L:bank_put_u32
//   44   IIC_Reg_Buff[CTRL_REG_MWS_POWER] = 3;
        MOV       L:IIC_Reg_Buff + 8, #0x3
//   45   bank_put_u32(CTRL_REG_CENTER_FREQ_DHZ, 220000UL);
        LDW       X, #0x5b60
        LDW       S:?w1, X
        LDW       X, #0x3
        LDW       S:?w0, X
        LD        A, #0xc
        CALL      L:bank_put_u32
//   46   bank_put_u16(CTRL_REG_OUTPUT_MUL, 1);
        CLRW      X
        INCW      X
        LD        A, #0x10
        CALL      L:bank_put_u16
//   47   bank_put_u16(CTRL_REG_OUTPUT_DIV, 1);
        CLRW      X
        INCW      X
        LD        A, #0x12
        CALL      L:bank_put_u16
//   48   bank_put_u32(CTRL_REG_KP_TRACK, 6000000UL);
        LDW       X, #0x8d80
        LDW       S:?w1, X
        LDW       X, #0x5b
        LDW       S:?w0, X
        LD        A, #0x14
        CALL      L:bank_put_u32
//   49   bank_put_u32(CTRL_REG_KI_TRACK, 180000UL);
        LDW       X, #0xbf20
        LDW       S:?w1, X
        LDW       X, #0x2
        LDW       S:?w0, X
        LD        A, #0x18
        CALL      L:bank_put_u32
//   50   bank_put_u32(CTRL_REG_KF_ACQUIRE, 8000000UL);
        LDW       X, #0x1200
        LDW       S:?w1, X
        LDW       X, #0x7a
        LDW       S:?w0, X
        LD        A, #0x1c
        CALL      L:bank_put_u32
//   51   bank_put_u32(CTRL_REG_KF_BLEND, 1500000UL);
        LDW       X, #0xe360
        LDW       S:?w1, X
        LDW       X, #0x16
        LDW       S:?w0, X
        LD        A, #0x20
        CALL      L:bank_put_u32
//   52   bank_put_u32(CTRL_REG_POS_LIMIT_HZ, 4400UL);
        LDW       X, #0x1130
        LDW       S:?w1, X
        CLRW      X
        LDW       S:?w0, X
        LD        A, #0x24
        CALL      L:bank_put_u32
//   53   bank_put_u32(CTRL_REG_NEG_LIMIT_HZ, (uint32_t)(int32_t)-4400);
        LDW       X, #0xeed0
        LDW       S:?w1, X
        CLRW      X
        DECW      X
        LDW       S:?w0, X
        LD        A, #0x28
        CALL      L:bank_put_u32
//   54   bank_put_u16(CTRL_REG_PHASE_THRESHOLD_CDEG, 800);
        LDW       X, #0x320
        LD        A, #0x2c
        CALL      L:bank_put_u16
//   55   bank_put_u16(CTRL_REG_DAC_AMPLITUDE_MV, 2000);
        LDW       X, #0x7d0
        LD        A, #0x2e
        CALL      L:bank_put_u16
//   56   bank_put_u16(CTRL_REG_FREQ_THRESHOLD_HZ, 100);
        LDW       X, #0x64
        LD        A, #0x30
        CALL      L:bank_put_u16
//   57   bank_put_u16(CTRL_REG_FAST_INTERVAL_MS, 500);
        LDW       X, #0x1f4
        LD        A, #0x32
        JP        L:bank_put_u16
//   58 }
          CFI EndBlock cfiBlock3
//   59 

        SECTION `.near_func.textrw`:CODE:REORDER:NOROOT(0)
        SECTION_TYPE SHT_PROGBITS, SHF_WRITE | SHF_EXECINSTR
          CFI Block cfiBlock4 Using cfiCommon0
          CFI Function eeprom_store_crc
        CODE
//   60 static __ramfunc void eeprom_store_crc(uint16_t crc)
//   61 {
//   62   uint8_t i;
//   63   asm("sim");
eeprom_store_crc:
        sim
//   64   do
//   65   {
//   66     FLASH->DUKR = 0xae;
??eeprom_store_crc_0:
        MOV       L:0x5064, #0xae
//   67     FLASH->DUKR = 0x56;
        MOV       L:0x5064, #0x56
//   68   }
//   69   while(!(FLASH->IAPSR & FLASH_IAPSR_DUL));
        BTJF      L:0x505f, #0x3, L:??eeprom_store_crc_0
//   70 
//   71   FLASH->CR2 |= FLASH_CR2_PRG;
        BSET      L:0x505b, #0x0
//   72   FLASH->NCR2 &= (uint8_t)~FLASH_NCR2_NPRG;
        BRES      L:0x505c, #0x0
//   73 
//   74   *((unsigned char *)EEPROM_Write_Addr + 0) = EEPROM_MAGIC;
        MOV       L:0x4240, #0xa5
//   75   *((unsigned char *)EEPROM_Write_Addr + 1) = CTRL_PROTOCOL_VERSION;
        MOV       L:0x4241, #0x3
//   76   *((unsigned char *)EEPROM_Write_Addr + 2) = (uint8_t)crc;
        LD        A, XL
        LD        L:0x4242, A
//   77   *((unsigned char *)EEPROM_Write_Addr + 3) = (uint8_t)(crc >> 8);
        LD        A, XH
        LD        L:0x4243, A
//   78   for(i = CTRL_PERSIST_BEGIN; i < CTRL_PERSIST_END; i++)
        MOV       S:?b0, #0x4
        JRA       L:??eeprom_store_crc_1
//   79   {
//   80     *((unsigned char *)EEPROM_Write_Addr + i) = IIC_Reg_Buff[i];
??eeprom_store_crc_2:
        CLRW      X
        LD        XL, A
        LD        A, (L:IIC_Reg_Buff,X)
        ADDW      X, #0x4240
        LD        (X), A
//   81   }
        LD        A, S:?b0
        INC       A
        LD        S:?b0, A
??eeprom_store_crc_1:
        LD        A, S:?b0
        CP        A, #0x40
        JRC       L:??eeprom_store_crc_2
//   82 
//   83   while((FLASH->IAPSR & FLASH_IAPSR_EOP) == 0);
??eeprom_store_crc_3:
        BTJF      L:0x505f, #0x2, L:??eeprom_store_crc_3
//   84   FLASH->IAPSR = 0;
        CLR       L:0x505f
//   85   asm("rim");
        rim
//   86 }
        RET
          CFI EndBlock cfiBlock4
//   87 

        SECTION `.near_func.text`:CODE:REORDER:NOROOT(0)
          CFI Block cfiBlock5 Using cfiCommon0
          CFI Function EEPROM_Store_Data
        CODE
//   88 void EEPROM_Store_Data(void)
//   89 {
//   90   uint16_t crc = eeprom_crc16(&IIC_Reg_Buff[CTRL_PERSIST_BEGIN],
//   91                               CTRL_PERSIST_END - CTRL_PERSIST_BEGIN);
EEPROM_Store_Data:
        LD        A, #0x3c
        LDW       X, #IIC_Reg_Buff + 4
        CALL      L:eeprom_crc16
//   92   eeprom_store_crc(crc);
        JP        L:eeprom_store_crc
//   93 }
          CFI EndBlock cfiBlock5
//   94 

        SECTION `.near_func.text`:CODE:REORDER:NOROOT(0)
          CFI Block cfiBlock6 Using cfiCommon0
          CFI Function EEPROM_Read_Data
        CODE
//   95 void EEPROM_Read_Data(void)
//   96 {
EEPROM_Read_Data:
        CALL      L:?push_w4
          CFI ?b9 Frame(CFA, -2)
          CFI ?b8 Frame(CFA, -3)
          CFI CFA SP+4
//   97   uint8_t i;
//   98   uint16_t stored_crc;
//   99   uint16_t calculated_crc;
//  100 
//  101   IIC_Reg_Buff[CTRL_REG_ID] = EEPROM_MAGIC;
        MOV       L:IIC_Reg_Buff, #0xa5
//  102   IIC_Reg_Buff[CTRL_REG_PROTOCOL_VERSION] = CTRL_PROTOCOL_VERSION;
        MOV       L:IIC_Reg_Buff + 1, #0x3
//  103   IIC_Reg_Buff[CTRL_REG_REQUEST_SEQ] = 0;
        CLR       L:IIC_Reg_Buff + 2
//  104   IIC_Reg_Buff[CTRL_REG_CONTROL_FLAGS] = 0;
        CLR       L:IIC_Reg_Buff + 3
//  105 
//  106   for(i = CTRL_PERSIST_BEGIN; i < CTRL_PERSIST_END; i++)
        MOV       S:?b0, #0x4
        JRA       L:??EEPROM_Read_Data_0
//  107   {
//  108     IIC_Reg_Buff[i] = *((unsigned char *)EEPROM_Write_Addr + i);
??EEPROM_Read_Data_1:
        CLRW      X
        LD        XL, A
        LDW       Y, X
        ADDW      Y, #0x4240
        LD        A, (Y)
        LD        (L:IIC_Reg_Buff,X), A
//  109   }
        LD        A, S:?b0
        INC       A
        LD        S:?b0, A
??EEPROM_Read_Data_0:
        LD        A, S:?b0
        CP        A, #0x40
        JRC       L:??EEPROM_Read_Data_1
//  110 
//  111   stored_crc = *((unsigned char *)EEPROM_Write_Addr + 2);
//  112   stored_crc |= (uint16_t)(*((unsigned char *)EEPROM_Write_Addr + 3)) << 8;
        LD        A, L:0x4243
        CLRW      X
        LD        XL, A
        CLR       A
        RLWA      X, A
        LD        A, L:0x4242
        CLRW      Y
        LD        YL, A
        LDW       S:?w0, X
        EXGW      X, Y
        RLWA      X, A
        OR        A, S:?b0
        RRWA      X, A
        EXGW      X, Y
        LDW       S:?w4, Y
//  113   calculated_crc = eeprom_crc16(&IIC_Reg_Buff[CTRL_PERSIST_BEGIN],
//  114                                 CTRL_PERSIST_END - CTRL_PERSIST_BEGIN);
        LD        A, #0x3c
        LDW       X, #IIC_Reg_Buff + 4
        CALL      L:eeprom_crc16
//  115 
//  116   if((*((unsigned char *)EEPROM_Write_Addr + 0) == EEPROM_MAGIC) &&
//  117      (*((unsigned char *)EEPROM_Write_Addr + 1) == CTRL_PROTOCOL_VERSION) &&
//  118      (stored_crc == calculated_crc))
        LD        A, #0xa5
        CP        A, L:0x4240
        JRNE      L:??EEPROM_Read_Data_2
        LD        A, #0x3
        CP        A, L:0x4241
        JRNE      L:??EEPROM_Read_Data_2
        LDW       S:?w0, X
        LDW       X, S:?w4
        CPW       X, S:?w0
        JRNE      L:??EEPROM_Read_Data_2
//  119   {
//  120     IIC_Reg_Buff[CTRL_REG_BRIDGE_STATUS] &=
//  121         (uint8_t)~CTRL_BRIDGE_STATUS_EEPROM_CRC_ERROR;
        LD        A, #0xfd
        AND       A, L:IIC_Reg_Buff + 70
        LD        L:IIC_Reg_Buff + 70, A
//  122     return;
        JP        L:?epilogue_w4
//  123   }
//  124 
//  125   IIC_Reg_Buff[CTRL_REG_BRIDGE_STATUS] |=
//  126       CTRL_BRIDGE_STATUS_EEPROM_CRC_ERROR;
??EEPROM_Read_Data_2:
        LD        A, #0x2
        OR        A, L:IIC_Reg_Buff + 70
        LD        L:IIC_Reg_Buff + 70, A
//  127   EEPROM_Load_Defaults();
        CALL      L:EEPROM_Load_Defaults
//  128   EEPROM_Store_Data();
        CALL      L:EEPROM_Store_Data
//  129 }
        JP        L:?epilogue_w4
          CFI EndBlock cfiBlock6

        SECTION VREGS:DATA:REORDER:NOROOT(0)

        END
// 
// 458 bytes in section .near_func.text
//  75 bytes in section .near_func.textrw
// 
// 533 bytes of CODE memory
//
//Errors: none
//Warnings: 1
