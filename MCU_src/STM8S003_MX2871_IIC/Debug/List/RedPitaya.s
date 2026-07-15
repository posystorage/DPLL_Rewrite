///////////////////////////////////////////////////////////////////////////////
//
// IAR C/C++ Compiler V2.20.3.189 for STM8                15/Jul/2026  17:47:27
// Copyright 2010-2017 IAR Systems AB.
// Standalone license - IAR Embedded Workbench for STMicroelectronics STM8
//
//    Source file  =  
//        E:\JiangSiyi\FPGA\DPLL_Low_Freq_Track\MCU_src\STM8S003_MX2871_IIC\src\RedPitaya.c
//    Command line =  
//        E:\JiangSiyi\FPGA\DPLL_Low_Freq_Track\MCU_src\STM8S003_MX2871_IIC\src\RedPitaya.c
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
//        E:\JiangSiyi\FPGA\DPLL_Low_Freq_Track\MCU_src\STM8S003_MX2871_IIC\Debug\List\RedPitaya.s
//
///////////////////////////////////////////////////////////////////////////////

        RTMODEL "__SystemLibrary", "DLib"
        RTMODEL "__code_model", "small"
        RTMODEL "__core", "stm8"
        RTMODEL "__data_model", "medium"
        RTMODEL "__rt_version", "4"

        EXTERN ?b0
        EXTERN ?b1
        EXTERN ?b2
        EXTERN ?b3
        EXTERN ?b4
        EXTERN ?b5
        EXTERN ?b6
        EXTERN ?b7
        EXTERN ?b8
        EXTERN ?b9
        EXTERN ?epilogue_l2
        EXTERN ?epilogue_w4
        EXTERN ?mov_l0_l2
        EXTERN ?mov_l1_l0
        EXTERN ?or32_l0_l0_l1
        EXTERN ?pop_w0
        EXTERN ?push_l2
        EXTERN ?push_w0
        EXTERN ?push_w4
        EXTERN ?sll32_l0_l0_a
        EXTERN ?w0
        EXTERN ?w1
        EXTERN ?w3
        EXTERN ?w4
        EXTERN ?w5
        EXTERN EEPROM_Store_Data
        EXTERN IIC_Reg_Buff
        EXTERN MAX2871_RFOUT_OFF
        EXTERN MAX2871_RFOUT_ON
        EXTERN max2871_Set_Freq_10M

        PUBLIC RedPitaya_2ms_Tick
        PUBLIC RedPitaya_Service
        PUBLIC RedPitaya_Uart_Init
        PUBLIC UART1_RX_IRQHandler
        PUBLIC _interrupt_20
        
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
        
// E:\JiangSiyi\FPGA\DPLL_Low_Freq_Track\MCU_src\STM8S003_MX2871_IIC\src\RedPitaya.c
//    1 #include "RedPitaya.h"
//    2 #include "IIC.h"
//    3 #include "EEPROM.h"
//    4 #include "control_protocol.h"
//    5 #include "MAX2871.h"
//    6 
//    7 #define CTRL_UART_RX_SIZE 72
//    8 #define CTRL_UART_TX_SIZE 101
//    9 #define CTRL_ARM_TIMEOUT_TICKS 1000
//   10 

        SECTION `.near.bss`:DATA:REORDER:NOROOT(0)
//   11 static volatile uint8_t uart_rx_buff[CTRL_UART_RX_SIZE];
uart_rx_buff:
        DS8 72

        SECTION `.near.bss`:DATA:REORDER:NOROOT(0)
//   12 static volatile uint8_t uart_rx_count;
uart_rx_count:
        DS8 1

        SECTION `.near.bss`:DATA:REORDER:NOROOT(0)
//   13 static volatile uint8_t uart_frame_ready;
uart_frame_ready:
        DS8 1

        SECTION `.near.bss`:DATA:REORDER:NOROOT(0)
//   14 static volatile uint16_t arm_timeout_ticks;
arm_timeout_ticks:
        DS8 2

        SECTION `.near.bss`:DATA:REORDER:NOROOT(0)
//   15 static uint8_t uart_tx_buff[CTRL_UART_TX_SIZE];
uart_tx_buff:
        DS8 101
//   16 

        SECTION `.near_func.text`:CODE:REORDER:NOROOT(0)
          CFI Block cfiBlock0 Using cfiCommon0
          CFI Function bank_get_u32
        CODE
//   17 static uint32_t bank_get_u32(uint8_t offset)
//   18 {
bank_get_u32:
        CALL      L:?push_l2
          CFI ?b11 Frame(CFA, -2)
          CFI ?b10 Frame(CFA, -3)
          CFI ?b9 Frame(CFA, -4)
          CFI ?b8 Frame(CFA, -5)
          CFI CFA SP+6
//   19   uint32_t value = IIC_Reg_Buff[offset];
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
//   20   value |= (uint32_t)IIC_Reg_Buff[offset + 1] << 8;
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
//   21   value |= (uint32_t)IIC_Reg_Buff[offset + 2] << 16;
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
//   22   value |= (uint32_t)IIC_Reg_Buff[offset + 3] << 24;
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
//   23   return value;
        JP        L:?epilogue_l2
//   24 }
          CFI EndBlock cfiBlock0
//   25 

        SECTION `.near_func.text`:CODE:REORDER:NOROOT(0)
          CFI Block cfiBlock1 Using cfiCommon0
          CFI Function ranges_overlap
        CODE
//   26 static uint8_t ranges_overlap(uint8_t offset, uint8_t length,
//   27                               uint8_t field, uint8_t field_length)
//   28 {
ranges_overlap:
        LD        S:?b3, A
        LD        A, S:?b2
//   29   return (offset < (uint8_t)(field + field_length)) &&
//   30          (field < (uint8_t)(offset + length));
        ADD       A, S:?b1
        LD        S:?b2, A
        LD        A, S:?b3
        CP        A, S:?b2
        JRNC      L:??ranges_overlap_0
        LD        A, S:?b0
        ADD       A, S:?b3
        LD        S:?b0, A
        LD        A, S:?b1
        CP        A, S:?b0
        JRNC      L:??ranges_overlap_0
        LD        A, #0x1
        RET
??ranges_overlap_0:
        CLR       A
        RET
//   31 }
          CFI EndBlock cfiBlock1
//   32 

        SECTION `.near_func.text`:CODE:REORDER:NOROOT(0)
          CFI Block cfiBlock2 Using cfiCommon0
          CFI Function apply_microwave_write
        CODE
//   33 static void apply_microwave_write(uint8_t offset, uint8_t length)
//   34 {
apply_microwave_write:
        PUSH      S:?b8
          CFI ?b8 Frame(CFA, -2)
          CFI CFA SP+3
        LD        S:?b4, A
        MOV       S:?b5, S:?b0
//   35   if(!ranges_overlap(offset, length, CTRL_REG_CONTROL_FLAGS, 1) &&
//   36      !ranges_overlap(offset, length, CTRL_REG_MWS_FREQ_KHZ, 5)) return;
        MOV       S:?b2, #0x1
        MOV       S:?b1, #0x3
        CALL      L:ranges_overlap
        CP        A, #0x0
        JRNE      L:??apply_microwave_write_0
        MOV       S:?b2, #0x5
        MOV       S:?b1, #0x4
        MOV       S:?b0, S:?b5
        LD        A, S:?b4
        CALL      L:ranges_overlap
        CP        A, #0x0
        JREQ      L:??apply_microwave_write_1
//   37 
//   38   if(IIC_Reg_Buff[CTRL_REG_CONTROL_FLAGS] & CTRL_FLAG_MWS_ENABLE)
??apply_microwave_write_0:
        BTJF      L:IIC_Reg_Buff + 3, #0x1, L:??apply_microwave_write_2
//   39   {
//   40     max2871_Set_Freq_10M(bank_get_u32(CTRL_REG_MWS_FREQ_KHZ),
//   41                          IIC_Reg_Buff[CTRL_REG_MWS_POWER] & 0x03);
        MOV       S:?b8, L:IIC_Reg_Buff + 8
        LD        A, #0x4
        CALL      L:bank_get_u32
        LD        A, S:?b8
        AND       A, #0x3
        CALL      L:max2871_Set_Freq_10M
//   42     MAX2871_RFOUT_ON();
        CALL      L:MAX2871_RFOUT_ON
//   43     IIC_Reg_Buff[CTRL_REG_MWS_STATUS] |= CTRL_MWS_STATUS_ENABLED;
        LD        A, #0x1
        OR        A, L:IIC_Reg_Buff + 66
        LD        L:IIC_Reg_Buff + 66, A
        JRA       L:??apply_microwave_write_1
//   44   }
//   45   else
//   46   {
//   47     MAX2871_RFOUT_OFF();
??apply_microwave_write_2:
        CALL      L:MAX2871_RFOUT_OFF
//   48     IIC_Reg_Buff[CTRL_REG_MWS_STATUS] &= (uint8_t)~CTRL_MWS_STATUS_ENABLED;
        LD        A, #0xfe
        AND       A, L:IIC_Reg_Buff + 66
        LD        L:IIC_Reg_Buff + 66, A
//   49   }
//   50 }
??apply_microwave_write_1:
        POP       S:?b8
          CFI ?b8 SameValue
          CFI CFA SP+2
        RET
          CFI EndBlock cfiBlock2

        SECTION `.near_func.text`:CODE:REORDER:NOROOT(0)
          CFI Block cfiBlock3 Using cfiCommon0
          CFI Function frame_checksum
        CODE
//   51 static uint8_t frame_checksum(const volatile uint8_t *data, uint8_t length)
//   52 {
frame_checksum:
        LD        S:?b4, A
//   53   uint8_t i;
//   54   uint8_t sum = 0;
        CLR       S:?b1
//   55   for(i = 0; i < length; i++) sum = (uint8_t)(sum + data[i]);
        CLR       S:?b0
        JRA       L:??frame_checksum_0
??frame_checksum_1:
        CLRW      Y
        LD        YL, A
        LDW       S:?w1, X
        ADDW      Y, S:?w1
        LD        A, (Y)
        ADD       A, S:?b1
        LD        S:?b1, A
        LD        A, S:?b0
        INC       A
        LD        S:?b0, A
??frame_checksum_0:
        LD        A, S:?b0
        CP        A, S:?b4
        JRC       L:??frame_checksum_1
//   56   return (uint8_t)(0U - sum);
        NEG       S:?b1
        LD        A, S:?b1
        RET
//   57 }
          CFI EndBlock cfiBlock3
//   58 

        SECTION `.near_func.text`:CODE:REORDER:NOROOT(0)
          CFI Block cfiBlock4 Using cfiCommon0
          CFI Function RedPitaya_Uart_Init
        CODE
//   59 void RedPitaya_Uart_Init(void)
//   60 {
//   61   /* The verified original STM8S003 design uses this misnamed library bit. */
//   62   CLK->PCKENR1 |= CLK_PCKENR1_UART2;
RedPitaya_Uart_Init:
        BSET      L:0x50c7, #0x3
//   63 
//   64   GPIOD->ODR |= GPIO_PIN_5;
        BSET      L:0x500f, #0x5
//   65   GPIOD->DDR |= GPIO_PIN_5;
        BSET      L:0x5011, #0x5
//   66   GPIOD->CR1 |= GPIO_PIN_5 | GPIO_PIN_6;
        LD        A, #0x60
        OR        A, L:0x5012
        LD        L:0x5012, A
//   67   GPIOD->CR2 |= GPIO_PIN_5;
        BSET      L:0x5013, #0x5
//   68   GPIOD->CR2 &= (uint8_t)~GPIO_PIN_6;
        BRES      L:0x5013, #0x6
//   69   GPIOD->DDR &= (uint8_t)~GPIO_PIN_6;
        BRES      L:0x5011, #0x6
//   70 
//   71   UART1->CR1 = 0x00;
        CLR       L:0x5234
//   72   UART1->CR2 = 0x00;
        CLR       L:0x5235
//   73   UART1->CR3 = 0x00;
        CLR       L:0x5236
//   74   UART1->BRR2 = 0x00;
        CLR       L:0x5233
//   75   UART1->BRR1 = 0x01;
        MOV       L:0x5232, #0x1
//   76 
//   77   /* Keep 1 Mbps UART RX above the level-2 I2C interrupt. */
//   78   ITC->ISPR5 |= 0x30;
        LD        A, #0x30
        OR        A, L:0x7f74
        LD        L:0x7f74, A
//   79   UART1->CR2 = UART1_CR2_RIEN | UART1_CR2_TEN | UART1_CR2_REN;
        MOV       L:0x5235, #0x2c
//   80 
//   81   uart_rx_count = 0;
        CLR       L:uart_rx_count
//   82   uart_frame_ready = 0;
        CLR       L:uart_frame_ready
//   83   arm_timeout_ticks = 0;
        CLRW      X
        LDW       L:arm_timeout_ticks, X
//   84 }
        RET
          CFI EndBlock cfiBlock4
//   85 

        SECTION `.near_func.text`:CODE:NOROOT(0)
          CFI Block cfiBlock5 Using cfiCommon0
          CFI Function uart_send
        CODE
//   86 static void uart_send(const uint8_t *data, uint8_t length)
//   87 {
uart_send:
        LD        S:?b0, A
        JRA       L:??uart_send_0
//   88   while(length)
//   89   {
//   90     while((UART1->SR & UART1_SR_TXE) == 0);
??uart_send_1:
        BTJF      L:0x5230, #0x7, L:??uart_send_1
//   91     UART1->DR = *data;
        LD        A, (X)
        LD        L:0x5231, A
//   92     data++;
        INCW      X
//   93     length--;
        LD        A, S:?b0
        DEC       A
        LD        S:?b0, A
//   94   }
??uart_send_0:
        TNZ       S:?b0
        JRNE      L:??uart_send_1
//   95   while((UART1->SR & UART1_SR_TC) == 0);
??uart_send_2:
        BTJF      L:0x5230, #0x6, L:??uart_send_2
//   96 }
        RET
          CFI EndBlock cfiBlock5
//   97 

        SECTION `.near_func.text`:CODE:REORDER:NOROOT(0)
          CFI Block cfiBlock6 Using cfiCommon0
          CFI Function send_response
        CODE
//   98 static void send_response(uint8_t status, uint8_t offset, uint8_t length)
//   99 {
send_response:
        MOV       S:?b5, S:?b1
//  100   uint8_t i;
//  101   uint8_t total;
//  102 
//  103   uart_tx_buff[0] = CTRL_UART_RESP;
        MOV       L:uart_tx_buff, #0xb2
//  104   uart_tx_buff[1] = status;
        LD        L:uart_tx_buff + 1, A
//  105   uart_tx_buff[2] = length;
        LD        A, S:?b5
        LD        L:uart_tx_buff + 2, A
//  106   for(i = 0; i < length; i++) uart_tx_buff[3 + i] = IIC_Reg_Buff[offset + i];
        CLR       S:?b1
        JRA       L:??send_response_0
??send_response_1:
        CLR       S:?b2
        MOV       S:?b3, S:?b1
        CLRW      X
        LD        A, S:?b0
        LD        XL, A
        ADDW      X, S:?w1
        LD        A, (L:IIC_Reg_Buff,X)
        LDW       X, S:?w1
        ADDW      X, #uart_tx_buff + 3
        LD        (X), A
        LD        A, S:?b1
        INC       A
        LD        S:?b1, A
??send_response_0:
        LD        A, S:?b1
        CP        A, S:?b5
        JRC       L:??send_response_1
//  107   uart_tx_buff[3 + length] = frame_checksum(&uart_tx_buff[1], (uint8_t)(2 + length));
        CLRW      X
        LD        A, S:?b5
        LD        XL, A
        ADDW      X, #uart_tx_buff
        LDW       S:?w3, X
        ADD       A, #0x2
        LDW       X, #uart_tx_buff + 1
        CALL      L:frame_checksum
        LDW       X, S:?w3
        ADDW      X, #0x3
        LD        (X), A
//  108   uart_tx_buff[4 + length] = CTRL_UART_ETX;
        LD        A, #0xb3
        LDW       X, S:?w3
        ADDW      X, #0x4
        LD        (X), A
//  109   total = (uint8_t)(5 + length);
//  110   uart_send(uart_tx_buff, total);
        LD        A, S:?b5
        ADD       A, #0x5
        LDW       X, #uart_tx_buff
        JP        L:uart_send
//  111 }
          CFI EndBlock cfiBlock6
//  112 

        SECTION `.near_func.text`:CODE:REORDER:NOROOT(0)
          CFI Block cfiBlock7 Using cfiCommon1
          CFI Function UART1_RX_IRQHandler
        CODE
//  113 INTERRUPT_HANDLER(UART1_RX_IRQHandler, 18)
//  114 {
UART1_RX_IRQHandler:
_interrupt_20:
        CALL      L:?push_w0
          CFI ?b1 Frame(CFA, -9)
          CFI ?b0 Frame(CFA, -10)
          CFI CFA SP+11
//  115   uint8_t data = UART1->DR;
        MOV       S:?b1, L:0x5231
//  116   uint8_t expected;
//  117 
//  118   if(uart_frame_ready) return;
        LD        A, L:uart_frame_ready
        JRNE      L:??UART1_RX_IRQHandler_0
//  119 
//  120   if(uart_rx_count == 0)
        LD        A, L:uart_rx_count
        JRNE      L:??UART1_RX_IRQHandler_1
//  121   {
//  122     if(data == CTRL_UART_REQ)
        LD        A, S:?b1
        CP        A, #0xb1
        JRNE      L:??UART1_RX_IRQHandler_0
//  123     {
//  124       uart_rx_buff[0] = data;
        MOV       L:uart_rx_buff, #0xb1
//  125       uart_rx_count = 1;
        MOV       L:uart_rx_count, #0x1
//  126     }
//  127     return;
        JRA       L:??UART1_RX_IRQHandler_0
//  128   }
//  129 
//  130   if(uart_rx_count >= CTRL_UART_RX_SIZE)
??UART1_RX_IRQHandler_1:
        LDW       X, #uart_rx_count
        LD        A, (X)
        CP        A, #0x48
        JRNC      L:??UART1_RX_IRQHandler_2
//  131   {
//  132     uart_rx_count = 0;
//  133     return;
//  134   }
//  135 
//  136   uart_rx_buff[uart_rx_count++] = data;
        MOV       S:?b0, L:uart_rx_count
        LD        A, S:?b0
        INC       A
        LD        L:uart_rx_count, A
        CLRW      X
        LD        A, S:?b0
        LD        XL, A
        LD        A, S:?b1
        LD        (L:uart_rx_buff,X), A
//  137   if(uart_rx_count < 4) return;
        LDW       X, #uart_rx_count
        LD        A, (X)
        CP        A, #0x4
        JRC       L:??UART1_RX_IRQHandler_0
//  138 
//  139   expected = 6;
        MOV       S:?b0, #0x6
//  140   if(uart_rx_buff[1] == CTRL_UART_CMD_WRITE)
        LD        A, #0x2
        CP        A, L:uart_rx_buff + 1
        JRNE      L:??UART1_RX_IRQHandler_3
//  141   {
//  142     if(uart_rx_buff[3] > (CTRL_UART_RX_SIZE - 6))
        LDW       X, #uart_rx_buff + 3
        LD        A, (X)
        CP        A, #0x43
        JRC       L:??UART1_RX_IRQHandler_4
//  143     {
//  144       uart_rx_count = 0;
??UART1_RX_IRQHandler_2:
        CLR       L:uart_rx_count
//  145       return;
        JRA       L:??UART1_RX_IRQHandler_0
//  146     }
//  147     expected = (uint8_t)(6 + uart_rx_buff[3]);
??UART1_RX_IRQHandler_4:
        LD        A, #0x6
        ADD       A, L:uart_rx_buff + 3
        LD        S:?b0, A
//  148   }
//  149 
//  150   if(uart_rx_count == expected)
??UART1_RX_IRQHandler_3:
        LD        A, S:?b0
        CP        A, L:uart_rx_count
        JRNE      L:??UART1_RX_IRQHandler_5
//  151   {
//  152     uart_frame_ready = 1;
        MOV       L:uart_frame_ready, #0x1
        JRA       L:??UART1_RX_IRQHandler_0
//  153   }
//  154   else if(uart_rx_count > expected)
??UART1_RX_IRQHandler_5:
        CP        A, L:uart_rx_count
        JRNC      L:??UART1_RX_IRQHandler_0
//  155   {
//  156     uart_rx_count = 0;
        CLR       L:uart_rx_count
//  157   }
//  158 }
??UART1_RX_IRQHandler_0:
        CALL      L:?pop_w0
          CFI ?b0 SameValue
          CFI ?b1 SameValue
          CFI CFA SP+9
        IRET
          CFI EndBlock cfiBlock7
//  159 

        SECTION `.near_func.text`:CODE:REORDER:NOROOT(0)
          CFI Block cfiBlock8 Using cfiCommon0
          CFI Function RedPitaya_2ms_Tick
        CODE
//  160 void RedPitaya_2ms_Tick(void)
//  161 {
//  162   if(arm_timeout_ticks)
RedPitaya_2ms_Tick:
        LDW       X, L:arm_timeout_ticks
        JREQ      L:??RedPitaya_2ms_Tick_0
//  163   {
//  164     arm_timeout_ticks--;
        LDW       X, L:arm_timeout_ticks
        DECW      X
        LDW       L:arm_timeout_ticks, X
//  165     if(arm_timeout_ticks == 0)
        LDW       X, L:arm_timeout_ticks
        JRNE      L:??RedPitaya_2ms_Tick_0
//  166     {
//  167       IIC_Reg_Buff[CTRL_REG_DPLL_STATUS] &= (uint8_t)~CTRL_DPLL_STATUS_ARM_ONLINE;
        LD        A, #0x7f
        AND       A, L:IIC_Reg_Buff + 65
        LD        L:IIC_Reg_Buff + 65, A
//  168       IIC_Reg_Buff[CTRL_REG_DPLL_STATUS] |= CTRL_DPLL_STATUS_ERROR;
        LD        A, #0x40
        OR        A, L:IIC_Reg_Buff + 65
        LD        L:IIC_Reg_Buff + 65, A
//  169     }
//  170   }
//  171 }
??RedPitaya_2ms_Tick_0:
        RET
          CFI EndBlock cfiBlock8
//  172 

        SECTION `.near_func.text`:CODE:REORDER:NOROOT(0)
          CFI Block cfiBlock9 Using cfiCommon0
          CFI Function RedPitaya_Service
        CODE
//  173 void RedPitaya_Service(void)
//  174 {
RedPitaya_Service:
        CALL      L:?push_w4
          CFI ?b9 Frame(CFA, -2)
          CFI ?b8 Frame(CFA, -3)
          CFI CFA SP+4
//  175   uint8_t command;
//  176   uint8_t offset;
//  177   uint8_t length;
//  178   uint8_t checksum_index;
//  179   uint8_t status = CTRL_UART_STATUS_OK;
        CLR       S:?b6
//  180   uint8_t i;
//  181 
//  182   if(!uart_frame_ready) return;
        LD        A, L:uart_frame_ready
        JRNE      ??lb_0
        JP        L:??RedPitaya_Service_0
//  183 
//  184   command = uart_rx_buff[1];
??lb_0:
        MOV       S:?b8, L:uart_rx_buff + 1
//  185   offset = uart_rx_buff[2];
        MOV       S:?b5, L:uart_rx_buff + 2
//  186   length = uart_rx_buff[3];
        MOV       S:?b7, L:uart_rx_buff + 3
//  187   checksum_index = (command == CTRL_UART_CMD_WRITE) ? (uint8_t)(4 + length) : 4;
        LD        A, S:?b8
        CP        A, #0x2
        JRNE      L:??RedPitaya_Service_1
        LD        A, S:?b7
        ADD       A, #0x4
        LD        S:?b0, A
        JRA       L:??RedPitaya_Service_2
??RedPitaya_Service_1:
        MOV       S:?b0, #0x4
//  188 
//  189   if((uart_rx_buff[checksum_index + 1] != CTRL_UART_ETX) ||
//  190      (uart_rx_buff[checksum_index] !=
//  191       frame_checksum(&uart_rx_buff[1], (uint8_t)(checksum_index - 1))))
??RedPitaya_Service_2:
        CLRW      Y
        LD        A, S:?b0
        LD        YL, A
        ADDW      Y, #uart_rx_buff
        LDW       X, Y
        INCW      X
        LD        A, (X)
        CP        A, #0xb3
        JRNE      L:??RedPitaya_Service_3
        LD        A, (Y)
        LD        S:?b9, A
        LD        A, S:?b0
        DEC       A
        LDW       X, #uart_rx_buff + 1
        CALL      L:frame_checksum
        CP        A, S:?b9
        JREQ      L:??RedPitaya_Service_4
//  192   {
//  193     status = CTRL_UART_STATUS_BAD_FRAME;
??RedPitaya_Service_3:
        MOV       S:?b6, #0x1
        JRA       L:??RedPitaya_Service_5
//  194   }
//  195   else if(((uint16_t)offset + length) > CTRL_BANK_SIZE)
??RedPitaya_Service_4:
        CLR       S:?b0
        MOV       S:?b1, S:?b7
        CLRW      X
        LD        A, S:?b5
        LD        XL, A
        ADDW      X, S:?w0
        CPW       X, #0x61
        JRC       L:??RedPitaya_Service_6
//  196   {
//  197     status = CTRL_UART_STATUS_RANGE;
        MOV       S:?b6, #0x2
        JRA       L:??RedPitaya_Service_5
//  198   }
//  199   else
//  200   {
//  201     arm_timeout_ticks = CTRL_ARM_TIMEOUT_TICKS;
??RedPitaya_Service_6:
        LDW       X, #0x3e8
        LDW       L:arm_timeout_ticks, X
//  202   }
//  203 
//  204   if(status == CTRL_UART_STATUS_OK)
??RedPitaya_Service_5:
        TNZ       S:?b6
        JREQ      ??lb_1
        JP        L:??RedPitaya_Service_7
//  205   {
//  206     switch(command)
??lb_1:
        LD        A, S:?b8
        DEC       A
        JREQ      L:??RedPitaya_Service_8
        DEC       A
        JREQ      L:??RedPitaya_Service_9
        DEC       A
        JREQ      L:??RedPitaya_Service_10
        DEC       A
        JREQ      L:??RedPitaya_Service_11
        JRA       L:??RedPitaya_Service_12
//  207     {
//  208     case CTRL_UART_CMD_READ:
//  209       send_response(status, offset, length);
??RedPitaya_Service_8:
        MOV       S:?b1, S:?b7
        MOV       S:?b0, S:?b5
        CLR       A
        CALL      L:send_response
//  210       break;
        JRA       L:??RedPitaya_Service_13
//  211 
//  212     case CTRL_UART_CMD_WRITE:
//  213       if(offset < CTRL_REG_REQUEST_SEQ)
??RedPitaya_Service_9:
        LD        A, S:?b5
        CP        A, #0x2
        JRNC      L:??RedPitaya_Service_14
//  214       {
//  215         send_response(CTRL_UART_STATUS_RANGE, 0, 0);
        CLR       S:?b1
        CLR       S:?b0
        LD        A, #0x2
        CALL      L:send_response
        JRA       L:??RedPitaya_Service_13
//  216       }
//  217       else
//  218       {
//  219         for(i = 0; i < length; i++) IIC_Reg_Buff[offset + i] = uart_rx_buff[4 + i];
??RedPitaya_Service_14:
        CLR       S:?b1
        JRA       L:??RedPitaya_Service_15
??RedPitaya_Service_16:
        CLR       S:?b0
        CLRW      X
        LD        A, S:?b5
        LD        XL, A
        ADDW      X, S:?w0
        LDW       Y, S:?w0
        ADDW      Y, #uart_rx_buff + 4
        LD        A, (Y)
        LD        (L:IIC_Reg_Buff,X), A
        LD        A, S:?b1
        INC       A
        LD        S:?b1, A
??RedPitaya_Service_15:
        LD        A, S:?b1
        CP        A, S:?b7
        JRC       L:??RedPitaya_Service_16
//  220         apply_microwave_write(offset, length);
        MOV       S:?b0, S:?b7
        LD        A, S:?b5
        CALL      L:apply_microwave_write
//  221         send_response(status, 0, 0);
        CLR       S:?b1
        CLR       S:?b0
        CLR       A
        CALL      L:send_response
        JRA       L:??RedPitaya_Service_13
//  222       }
//  223       break;
//  224 
//  225     case CTRL_UART_CMD_SAVE:
//  226       EEPROM_Store_Data();
??RedPitaya_Service_10:
        CALL      L:EEPROM_Store_Data
//  227       send_response(status, 0, 0);
        CLR       S:?b1
        CLR       S:?b0
        CLR       A
        CALL      L:send_response
//  228       break;
        JRA       L:??RedPitaya_Service_13
//  229 
//  230     case CTRL_UART_CMD_PING:
//  231       send_response(status, CTRL_REG_PROTOCOL_VERSION, 1);
??RedPitaya_Service_11:
        MOV       S:?b1, #0x1
        MOV       S:?b0, #0x1
        CLR       A
        CALL      L:send_response
//  232       break;
        JRA       L:??RedPitaya_Service_13
//  233 
//  234     default:
//  235       send_response(CTRL_UART_STATUS_COMMAND, 0, 0);
??RedPitaya_Service_12:
        CLR       S:?b1
        CLR       S:?b0
        LD        A, #0x3
        CALL      L:send_response
//  236       break;
        JRA       L:??RedPitaya_Service_13
//  237     }
//  238   }
//  239   else
//  240   {
//  241     send_response(status, 0, 0);
??RedPitaya_Service_7:
        CLR       S:?b1
        CLR       S:?b0
        LD        A, S:?b6
        CALL      L:send_response
//  242   }
//  243 
//  244   uart_rx_count = 0;
??RedPitaya_Service_13:
        CLR       L:uart_rx_count
//  245   uart_frame_ready = 0;
        CLR       L:uart_frame_ready
//  246 }
??RedPitaya_Service_0:
        JP        L:?epilogue_w4
          CFI EndBlock cfiBlock9

        SECTION VREGS:DATA:REORDER:NOROOT(0)

        END
// 
// 177 bytes in section .near.bss
// 894 bytes in section .near_func.text
// 
// 894 bytes of CODE memory
// 177 bytes of DATA memory
//
//Errors: none
//Warnings: 1
