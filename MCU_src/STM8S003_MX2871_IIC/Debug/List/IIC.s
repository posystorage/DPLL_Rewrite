///////////////////////////////////////////////////////////////////////////////
//
// IAR C/C++ Compiler V2.20.3.189 for STM8                16/Jul/2026  17:41:37
// Copyright 2010-2017 IAR Systems AB.
// Standalone license - IAR Embedded Workbench for STMicroelectronics STM8
//
//    Source file  =  
//        E:\JiangSiyi\FPGA\DPLL_Low_Freq_Track\MCU_src\STM8S003_MX2871_IIC\src\IIC.c
//    Command line =  
//        E:\JiangSiyi\FPGA\DPLL_Low_Freq_Track\MCU_src\STM8S003_MX2871_IIC\src\IIC.c
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
//        E:\JiangSiyi\FPGA\DPLL_Low_Freq_Track\MCU_src\STM8S003_MX2871_IIC\Debug\List\IIC.s
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
        EXTERN ?pop_l0
        EXTERN ?push_l0

        PUBLIC I2C_IRQHandler
        PUBLIC IIC_CMD
        PUBLIC IIC_Reg_Buff
        PUBLIC IIC_Slave_Init
        PUBLIC IIC_Slave_RX_Byte
        PUBLIC _interrupt_21
        
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
        
// E:\JiangSiyi\FPGA\DPLL_Low_Freq_Track\MCU_src\STM8S003_MX2871_IIC\src\IIC.c
//    1 #include "IIC.h"
//    2 
//    3 
//    4 

        SECTION `.near.bss`:DATA:REORDER:NOROOT(0)
//    5 static volatile uint8_t IIC_Reg_Addr_Point;
IIC_Reg_Addr_Point:
        DS8 1

        SECTION `.near.bss`:DATA:REORDER:NOROOT(0)
//    6 volatile uint8_t IIC_Reg_Buff[IIC_REG_SIZE];
IIC_Reg_Buff:
        DS8 96

        SECTION `.near.bss`:DATA:REORDER:NOROOT(0)
//    7 static volatile uint8_t IIC_Reg_Addr_Get;//标记获得了地址位
IIC_Reg_Addr_Get:
        DS8 1

        SECTION `.near.bss`:DATA:REORDER:NOROOT(0)
//    8 volatile uint8_t IIC_CMD;
IIC_CMD:
        DS8 1
//    9 

        SECTION `.near_func.text`:CODE:REORDER:NOROOT(0)
          CFI Block cfiBlock0 Using cfiCommon0
          CFI Function IIC_Slave_TX_Byte
        CODE
//   10 static void IIC_Slave_TX_Byte(void)
//   11 {
//   12   if(IIC_Reg_Addr_Point >= IIC_REG_SIZE)
IIC_Slave_TX_Byte:
        LDW       X, #IIC_Reg_Addr_Point
        LD        A, (X)
        CP        A, #0x60
        JRC       L:??IIC_Slave_TX_Byte_0
//   13   {
//   14     I2C->DR = 0xA5;
        MOV       L:0x5216, #0xa5
        RET
//   15   }
//   16   else
//   17   {
//   18     I2C->DR = IIC_Reg_Buff[IIC_Reg_Addr_Point];
??IIC_Slave_TX_Byte_0:
        LD        A, L:IIC_Reg_Addr_Point
        CLRW      X
        LD        XL, A
        LD        A, (L:IIC_Reg_Buff,X)
        LD        L:0x5216, A
//   19     IIC_Reg_Addr_Point++;
        LD        A, #0x1
        ADD       A, L:IIC_Reg_Addr_Point
        LD        L:IIC_Reg_Addr_Point, A
//   20     if(IIC_Reg_Addr_Point >= IIC_REG_SIZE) IIC_Reg_Addr_Point = 0;
        LDW       X, #IIC_Reg_Addr_Point
        LD        A, (X)
        CP        A, #0x60
        JRC       L:??IIC_Slave_TX_Byte_1
        CLR       L:IIC_Reg_Addr_Point
//   21   }
//   22 }
??IIC_Slave_TX_Byte_1:
        RET
          CFI EndBlock cfiBlock0
//   23 

        SECTION `.near_func.text`:CODE:REORDER:NOROOT(0)
          CFI Block cfiBlock1 Using cfiCommon0
          CFI Function IIC_Slave_Init
        CODE
//   24 void IIC_Slave_Init(void)
//   25 {
//   26   CLK->PCKENR1 |= CLK_PCKENR1_I2C;
IIC_Slave_Init:
        BSET      L:0x50c7, #0x0
//   27   
//   28   GPIOB->ODR |= GPIO_PIN_4|GPIO_PIN_5;
        LD        A, #0x30
        OR        A, L:0x5005
        LD        L:0x5005, A
//   29   GPIOB->DDR &=~ (GPIO_PIN_5|GPIO_PIN_4);
        LD        A, #0xcf
        AND       A, L:0x5007
        LD        L:0x5007, A
//   30 
//   31   I2C->CR1 = I2C_CR1_PE;
        MOV       L:0x5210, #0x1
//   32   I2C->CR2 = I2C_CR2_ACK;
        MOV       L:0x5211, #0x4
//   33   I2C->FREQR = 16;
        MOV       L:0x5212, #0x10
//   34   
//   35   I2C->OARL = 0x4A;//Address
        MOV       L:0x5213, #0x4a
//   36   I2C->OARH = I2C_OARH_ADDCONF;
        MOV       L:0x5214, #0x40
//   37   
//   38   /* ADDR events arm byte interrupts; terminal events disarm them. */
//   39   I2C->ITR = I2C_ITR_ITEVTEN | I2C_ITR_ITERREN;
        MOV       L:0x521a, #0x3
//   40   /* Keep I2C and UART at level 3 so neither ISR can preempt the other. */
//   41   ITC->ISPR5 |= 0xC0;
        LD        A, #0xc0
        OR        A, L:0x7f74
        LD        L:0x7f74, A
//   42   IIC_Reg_Addr_Point = 0;
        CLR       L:IIC_Reg_Addr_Point
//   43   IIC_Reg_Buff[CTRL_REG_ID] = 0xA5;
        MOV       L:IIC_Reg_Buff, #0xa5
//   44   IIC_Reg_Buff[CTRL_REG_PROTOCOL_VERSION] = CTRL_PROTOCOL_VERSION;
        MOV       L:IIC_Reg_Buff + 1, #0x3
//   45   IIC_Reg_Buff[CTRL_REG_REQUEST_SEQ] = 0;
        CLR       L:IIC_Reg_Buff + 2
//   46   IIC_Reg_Buff[CTRL_REG_CONTROL_FLAGS] = 0;
        CLR       L:IIC_Reg_Buff + 3
//   47   IIC_Reg_Addr_Get = 0;
        CLR       L:IIC_Reg_Addr_Get
//   48   IIC_CMD = 0;
        CLR       L:IIC_CMD
//   49 }
        RET
          CFI EndBlock cfiBlock1
//   50 
//   51 

        SECTION `.near_func.text`:CODE:REORDER:NOROOT(0)
          CFI Block cfiBlock2 Using cfiCommon0
          CFI Function IIC_Slave_RX_Byte
        CODE
//   52 void IIC_Slave_RX_Byte(uint8_t Last_Event_SR1)
//   53 {
//   54   uint8_t Cache;
//   55   if((Last_Event_SR1 & I2C_SR1_RXNE) == I2C_SR1_RXNE)
IIC_Slave_RX_Byte:
        BCP       A, #0x40
        JREQ      L:??IIC_Slave_RX_Byte_0
//   56   {
//   57     Cache = I2C->DR;
        MOV       S:?b0, L:0x5216
//   58     if(IIC_Reg_Addr_Get)
        LD        A, L:IIC_Reg_Addr_Get
        JREQ      L:??IIC_Slave_RX_Byte_1
//   59     {
//   60       if(((IIC_Reg_Addr_Point>=CTRL_PERSIST_BEGIN)&&
//   61           (IIC_Reg_Addr_Point<CTRL_PERSIST_END))||
//   62          (IIC_Reg_Addr_Point==CTRL_REG_DEBUG_DAC_PRESET))
        LDW       X, #IIC_Reg_Addr_Point
        LD        A, (X)
        CP        A, #0x4
        JRC       L:??IIC_Slave_RX_Byte_2
        LD        A, (X)
        CP        A, #0x40
        JRC       L:??IIC_Slave_RX_Byte_3
??IIC_Slave_RX_Byte_2:
        LD        A, #0x47
        CP        A, L:IIC_Reg_Addr_Point
        JRNE      L:??IIC_Slave_RX_Byte_0
//   63       {
//   64         IIC_Reg_Buff[IIC_Reg_Addr_Point] = Cache;
??IIC_Slave_RX_Byte_3:
        LD        A, L:IIC_Reg_Addr_Point
        CLRW      X
        LD        XL, A
        LD        A, S:?b0
        LD        (L:IIC_Reg_Buff,X), A
//   65         IIC_Reg_Addr_Point++;
        LD        A, #0x1
        ADD       A, L:IIC_Reg_Addr_Point
        LD        L:IIC_Reg_Addr_Point, A
        RET
//   66       }
//   67     }
//   68     else
//   69     {
//   70       IIC_Reg_Addr_Get = 1;
??IIC_Slave_RX_Byte_1:
        MOV       L:IIC_Reg_Addr_Get, #0x1
//   71       if(Cache < IIC_REG_SIZE)//Data
        LD        A, S:?b0
        CP        A, #0x60
        JRNC      L:??IIC_Slave_RX_Byte_4
//   72       {
//   73         IIC_Reg_Addr_Point = Cache;
        LD        L:IIC_Reg_Addr_Point, A
        RET
//   74       }
//   75       else//CMD
//   76       {
//   77         if((Cache>=0xC0)&&(Cache<=0xC9))
??IIC_Slave_RX_Byte_4:
        ADD       A, #0x40
        CP        A, #0xa
        JRNC      L:??IIC_Slave_RX_Byte_5
//   78         {
//   79           
//   80           IIC_CMD = Cache;
        LD        A, S:?b0
        LD        L:IIC_CMD, A
//   81           IIC_Reg_Buff[CTRL_REG_BRIDGE_STATUS] |= CTRL_BRIDGE_STATUS_BUSY;//busy
        LD        A, #0x1
        OR        A, L:IIC_Reg_Buff + 70
        LD        L:IIC_Reg_Buff + 70, A
//   82           
//   83         }
//   84         IIC_Reg_Addr_Point = IIC_REG_SIZE;
??IIC_Slave_RX_Byte_5:
        MOV       L:IIC_Reg_Addr_Point, #0x60
//   85       }
//   86     }   
//   87   }  
//   88 }
??IIC_Slave_RX_Byte_0:
        RET
          CFI EndBlock cfiBlock2
//   89 

        SECTION `.near_func.text`:CODE:REORDER:NOROOT(0)
          CFI Block cfiBlock3 Using cfiCommon1
          CFI Function I2C_IRQHandler
        CODE
//   90 INTERRUPT_HANDLER(I2C_IRQHandler, 19)
//   91 {
I2C_IRQHandler:
_interrupt_21:
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
        PUSH      S:?b4
          CFI ?b4 Frame(CFA, -13)
          CFI CFA SP+14
//   92   uint8_t Last_Event_SR1 = I2C->SR1;
        MOV       S:?b4, L:0x5217
//   93   uint8_t Last_Event_SR3 = I2C->SR3;
        MOV       S:?b3, L:0x5219
//   94   uint8_t Last_Event_SR2 = I2C->SR2;
        MOV       S:?b2, L:0x5218
//   95   uint8_t RX_Handled = 0;
        CLR       S:?b0
//   96   uint8_t Transfer_End = 0;
        CLR       S:?b1
//   97 
//   98   if((Last_Event_SR1 & I2C_SR1_RXNE) == I2C_SR1_RXNE)
        LD        A, S:?b4
        BCP       A, #0x40
        JREQ      L:??I2C_IRQHandler_0
//   99   {
//  100     IIC_Slave_RX_Byte(Last_Event_SR1);
        LD        A, S:?b4
        CALL      L:IIC_Slave_RX_Byte
//  101     RX_Handled = 1;
        MOV       S:?b0, #0x1
//  102   }
//  103 
//  104   if(Last_Event_SR2 & (I2C_SR2_AF | I2C_SR2_BERR |
//  105                        I2C_SR2_OVR | I2C_SR2_ARLO))
??I2C_IRQHandler_0:
        LD        A, S:?b2
        BCP       A, #0xf
        JREQ      L:??I2C_IRQHandler_1
//  106   {
//  107     I2C->SR2 &= (uint8_t)~(I2C_SR2_AF | I2C_SR2_BERR |
//  108                             I2C_SR2_OVR | I2C_SR2_ARLO);
        LD        A, #0xf0
        AND       A, L:0x5218
        LD        L:0x5218, A
//  109     Transfer_End = 1;
        MOV       S:?b1, #0x1
//  110   }
//  111 
//  112   if((Last_Event_SR1 & I2C_SR1_STOPF) == I2C_SR1_STOPF)
??I2C_IRQHandler_1:
        LD        A, S:?b4
        BCP       A, #0x10
        JREQ      L:??I2C_IRQHandler_2
//  113   {
//  114     I2C->CR2 |= I2C_CR2_ACK;
        BSET      L:0x5211, #0x2
//  115     Transfer_End = 1;
        MOV       S:?b1, #0x1
//  116   }
//  117 
//  118   if(Transfer_End)
??I2C_IRQHandler_2:
        LD        A, S:?b4
        AND       A, #0x2
        TNZ       S:?b1
        JREQ      L:??I2C_IRQHandler_3
//  119   {
//  120     I2C->ITR &= (uint8_t)~I2C_ITR_ITBUFEN;
        BRES      L:0x521a, #0x2
//  121     IIC_Reg_Addr_Get = 0;
        CLR       L:IIC_Reg_Addr_Get
//  122     if((Last_Event_SR1 & I2C_SR1_ADDR) == 0) return;
        TNZ       A
        JREQ      L:??I2C_IRQHandler_4
//  123   }
//  124 
//  125   if((Last_Event_SR1 & I2C_SR1_ADDR) == I2C_SR1_ADDR)
??I2C_IRQHandler_3:
        TNZ       A
        JREQ      L:??I2C_IRQHandler_5
//  126   {
//  127     I2C->ITR |= I2C_ITR_ITBUFEN;
        BSET      L:0x521a, #0x2
//  128     if((Last_Event_SR3 & I2C_SR3_TRA) == I2C_SR3_TRA)
        LD        A, S:?b3
        BCP       A, #0x4
        JREQ      L:??I2C_IRQHandler_6
//  129     {
//  130       IIC_Slave_TX_Byte();
        CALL      L:IIC_Slave_TX_Byte
        JRA       L:??I2C_IRQHandler_4
//  131     }
//  132     else
//  133     {
//  134       IIC_Reg_Addr_Get = 0;
??I2C_IRQHandler_6:
        CLR       L:IIC_Reg_Addr_Get
//  135     }
//  136     return;
        JRA       L:??I2C_IRQHandler_4
//  137   }
//  138 
//  139   if(RX_Handled) return;
??I2C_IRQHandler_5:
        TNZ       S:?b0
        JRNE      L:??I2C_IRQHandler_4
//  140 
//  141   if(((Last_Event_SR3 & I2C_SR3_TRA) == I2C_SR3_TRA) &&
//  142      ((Last_Event_SR1 & I2C_SR1_TXE) == I2C_SR1_TXE))
        LD        A, S:?b3
        BCP       A, #0x4
        JREQ      L:??I2C_IRQHandler_4
        LD        A, S:?b4
        BCP       A, #0x80
        JREQ      L:??I2C_IRQHandler_4
//  143   {
//  144     IIC_Slave_TX_Byte();
        CALL      L:IIC_Slave_TX_Byte
//  145   }
//  146 }
??I2C_IRQHandler_4:
        POP       S:?b4
          CFI ?b4 SameValue
          CFI CFA SP+13
        CALL      L:?pop_l0
          CFI ?b0 SameValue
          CFI ?b1 SameValue
          CFI ?b2 SameValue
          CFI ?b3 SameValue
          CFI CFA SP+9
        IRET
          CFI EndBlock cfiBlock3

        SECTION VREGS:DATA:REORDER:NOROOT(0)

        END
//  147 
//  148 
//  149 
//  150 //typedef enum
//  151 //{
//  152 //  I2C_EVENT_SLAVE_RECEIVER_ADDRESS_MATCHED    = (uint16_t)0x0202,  /*!< BUSY and ADDR flags */
//  153 //  I2C_EVENT_SLAVE_TRANSMITTER_ADDRESS_MATCHED = (uint16_t)0x0682,  /*!< TRA, BUSY, TXE and ADDR flags */
//  154 //  I2C_EVENT_SLAVE_GENERALCALLADDRESS_MATCHED  = (uint16_t)0x1200,  /*!< EV2: GENCALL and BUSY flags */
//  155 //  I2C_EVENT_SLAVE_BYTE_RECEIVED              = (uint16_t)0x0240,  /*!< BUSY and RXNE flags */
//  156 //  I2C_EVENT_SLAVE_STOP_DETECTED              = (uint16_t)0x0010,  /*!< STOPF flag */
//  157 //  I2C_EVENT_SLAVE_BYTE_TRANSMITTED           = (uint16_t)0x0684,  /*!< TRA, BUSY, TXE and BTF flags */
//  158 //  I2C_EVENT_SLAVE_BYTE_TRANSMITTING          = (uint16_t)0x0680,  /*!< TRA, BUSY and TXE flags */
//  159 //} I2C_Event_TypeDef;  
//  160 
//  161 //INTERRUPT_HANDLER(I2C_IRQHandler, 19)
//  162 //{
//  163 //  uint8_t Cache;
//  164 //  __IO uint16_t lastevent=0;
//  165 //  *((uint8_t*)&lastevent+1)=I2C->SR1;
//  166 //  *(uint8_t*)&lastevent=I2C->SR3;
//  167 //  GPIOD->ODR &=~ GPIO_PIN_5;
//  168 //  
//  169 //  if((lastevent&I2C_EVENT_SLAVE_TRANSMITTER_ADDRESS_MATCHED) == I2C_EVENT_SLAVE_TRANSMITTER_ADDRESS_MATCHED)
//  170 //  {
//  171 //    I2C->DR = IIC_Reg_Buff[IIC_Reg_Addr_Point];
//  172 //    GPIOD->ODR |= GPIO_PIN_5;
//  173 //    IIC_Reg_Addr_Point++;
//  174 //    if(IIC_Reg_Addr_Point>=IIC_REG_SIZE)IIC_Reg_Addr_Point = 0;
//  175 //    GPIOD->ODR &=~ GPIO_PIN_5; 
//  176 //  }
//  177 //  else
//  178 //  if((lastevent&I2C_EVENT_SLAVE_RECEIVER_ADDRESS_MATCHED) == I2C_EVENT_SLAVE_RECEIVER_ADDRESS_MATCHED)  
//  179 //  {
//  180 //    IIC_Reg_Addr_Get = 0;
//  181 //  }
//  182 //  if((lastevent&I2C_EVENT_SLAVE_BYTE_TRANSMITTING) == I2C_EVENT_SLAVE_BYTE_TRANSMITTING)
//  183 //  {
//  184 //      I2C->DR = IIC_Reg_Buff[IIC_Reg_Addr_Point];
//  185 //      IIC_Reg_Addr_Point++;
//  186 //      if(IIC_Reg_Addr_Point>=IIC_REG_SIZE)IIC_Reg_Addr_Point = 0;    
//  187 //  }
//  188 //  if((lastevent&I2C_EVENT_SLAVE_BYTE_RECEIVED) == I2C_EVENT_SLAVE_BYTE_RECEIVED)
//  189 //  {
//  190 //    Cache = I2C->DR;
//  191 //    if(IIC_Reg_Addr_Get)
//  192 //    {
//  193 //      if(IIC_Reg_Addr_Point!=0)//0寄存器是只读
//  194 //      {
//  195 //        IIC_Reg_Buff[IIC_Reg_Addr_Point] = Cache;
//  196 //      }
//  197 //    }
//  198 //    else
//  199 //    {
//  200 //      if(Cache < IIC_REG_SIZE)//Data
//  201 //      {
//  202 //        IIC_Reg_Addr_Point = Cache;
//  203 //        IIC_Reg_Addr_Get = 1;
//  204 //      }
//  205 //      else//CMD
//  206 //      {
//  207 //      
//  208 //      }
//  209 //    }   
//  210 //  }
//  211 //  if((I2C->SR1&I2C_SR1_STOPF) == I2C_SR1_STOPF)
//  212 //  {
//  213 //    I2C->CR2 = I2C_CR2_ACK;    
//  214 //  }
//  215 //  
//  216 //  if((I2C->SR2&I2C_SR2_AF) == I2C_SR2_AF)
//  217 //  {
//  218 //    I2C->SR2 &=~ I2C_SR2_AF;
//  219 //  }
//  220 //  if((I2C->SR2&I2C_SR2_BERR) == I2C_SR2_BERR)
//  221 //  {
//  222 //    I2C->SR2 &=~ I2C_SR2_BERR;
//  223 //  }    
//  224 //  GPIOD->ODR |= GPIO_PIN_5;
//  225 //}
//  226 
//  227 
//  228 //INTERRUPT_HANDLER(I2C_IRQHandler, 19)
//  229 //{
//  230 //  uint8_t Cache;
//  231 //  __IO uint16_t lastevent=0;
//  232 //  *((uint8_t*)&lastevent+1)=I2C->SR1&(*((uint8_t*)&I2C_Event+1));
//  233 //  *(uint8_t*)&lastevent=I2C->SR3&(*(uint8_t*)&I2C_Event);
//  234 //  
//  235 //  
//  236 //  if((I2C->SR2&I2C_SR2_AF) == I2C_SR2_AF)
//  237 //  {
//  238 //    I2C->SR2 &=~ I2C_SR2_AF;
//  239 //  
//  240 //  }
//  241 //  if((I2C->SR2&I2C_SR2_BERR) == I2C_SR2_BERR)
//  242 //  {
//  243 //    I2C->SR2 &=~ I2C_SR2_BERR;
//  244 //  
//  245 //  }
//  246 //  if(I2C_CheckEvent(I2C_EVENT_SLAVE_RECEIVER_ADDRESS_MATCHED))
//  247 //  {
//  248 //    if(I2C_CheckEvent(I2C_EVENT_SLAVE_TRANSMITTER_ADDRESS_MATCHED))
//  249 //    {
//  250 //      I2C->DR = IIC_Reg_Buff[IIC_Reg_Addr_Point];
//  251 //      IIC_Reg_Addr_Point++;
//  252 //      if(IIC_Reg_Addr_Point>=IIC_REG_SIZE)IIC_Reg_Addr_Point = 0;
//  253 //    }
//  254 //    else
//  255 //    {
//  256 //      IIC_Reg_Addr_Get = 0;
//  257 //    }
//  258 //  }
//  259 //  if(I2C_CheckEvent(I2C_EVENT_SLAVE_BYTE_TRANSMITTING))
//  260 //  {
//  261 //      I2C->DR = IIC_Reg_Buff[IIC_Reg_Addr_Point];
//  262 //      IIC_Reg_Addr_Point++;
//  263 //      if(IIC_Reg_Addr_Point>=IIC_REG_SIZE)IIC_Reg_Addr_Point = 0;    
//  264 //  }
//  265 //  if(I2C_CheckEvent(I2C_EVENT_SLAVE_BYTE_RECEIVED))
//  266 //  {
//  267 //    Cache = I2C->DR;
//  268 //    if(IIC_Reg_Addr_Get)
//  269 //    {
//  270 //      if(IIC_Reg_Addr_Point!=0)//0寄存器是只读
//  271 //      {
//  272 //        IIC_Reg_Buff[IIC_Reg_Addr_Point] = Cache;
//  273 //      }
//  274 //    }
//  275 //    else
//  276 //    {
//  277 //      if(Cache < IIC_REG_SIZE)//Data
//  278 //      {
//  279 //        IIC_Reg_Addr_Point = Cache;
//  280 //        IIC_Reg_Addr_Get = 1;
//  281 //      }
//  282 //      else//CMD
//  283 //      {
//  284 //      
//  285 //      }
//  286 //    }   
//  287 //  }
//  288 //  
//  289 //}
//  290 
// 
//  99 bytes in section .near.bss
// 364 bytes in section .near_func.text
// 
// 364 bytes of CODE memory
//  99 bytes of DATA memory
//
//Errors: none
//Warnings: 1
