///////////////////////////////////////////////////////////////////////////////
//
// IAR C/C++ Compiler V2.20.3.189 for STM8                16/Jul/2026  18:21:53
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

        PUBLIC I2C_IRQHandler
        PUBLIC IIC_CMD
        PUBLIC IIC_Reg_Buff
        PUBLIC IIC_Slave_Init
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
          CFI Function IIC_Slave_Init
        CODE
//   10 void IIC_Slave_Init(void)
//   11 {
//   12   CLK->PCKENR1 |= CLK_PCKENR1_I2C;
IIC_Slave_Init:
        BSET      L:0x50c7, #0x0
//   13   
//   14   GPIOB->ODR |= GPIO_PIN_4|GPIO_PIN_5;
        LD        A, #0x30
        OR        A, L:0x5005
        LD        L:0x5005, A
//   15   GPIOB->DDR &=~ (GPIO_PIN_5|GPIO_PIN_4);
        LD        A, #0xcf
        AND       A, L:0x5007
        LD        L:0x5007, A
//   16 
//   17   I2C->CR1 = I2C_CR1_PE;
        MOV       L:0x5210, #0x1
//   18   I2C->CR2 = I2C_CR2_ACK;
        MOV       L:0x5211, #0x4
//   19   I2C->FREQR = 16;
        MOV       L:0x5212, #0x10
//   20   
//   21   I2C->OARL = 0x4A;//Address
        MOV       L:0x5213, #0x4a
//   22   I2C->OARH = I2C_OARH_ADDCONF;
        MOV       L:0x5214, #0x40
//   23   
//   24   /* ADDR events arm byte interrupts; terminal events disarm them. */
//   25   I2C->ITR = I2C_ITR_ITEVTEN | I2C_ITR_ITERREN;
        MOV       L:0x521a, #0x3
//   26   /* Keep I2C and UART at level 3 so neither ISR can preempt the other. */
//   27   ITC->ISPR5 |= 0xC0;
        LD        A, #0xc0
        OR        A, L:0x7f74
        LD        L:0x7f74, A
//   28   IIC_Reg_Addr_Point = 0;
        CLR       L:IIC_Reg_Addr_Point
//   29   IIC_Reg_Buff[CTRL_REG_ID] = 0xA5;
        MOV       L:IIC_Reg_Buff, #0xa5
//   30   IIC_Reg_Buff[CTRL_REG_PROTOCOL_VERSION] = CTRL_PROTOCOL_VERSION;
        MOV       L:IIC_Reg_Buff + 1, #0x3
//   31   IIC_Reg_Buff[CTRL_REG_REQUEST_SEQ] = 0;
        CLR       L:IIC_Reg_Buff + 2
//   32   IIC_Reg_Buff[CTRL_REG_CONTROL_FLAGS] = 0;
        CLR       L:IIC_Reg_Buff + 3
//   33   IIC_Reg_Addr_Get = 0;
        CLR       L:IIC_Reg_Addr_Get
//   34   IIC_CMD = 0;
        CLR       L:IIC_CMD
//   35 }
        RET
          CFI EndBlock cfiBlock0
//   36 
//   37 

        SECTION `.near_func.text`:CODE:REORDER:NOROOT(0)
          CFI Block cfiBlock1 Using cfiCommon1
          CFI Function I2C_IRQHandler
        CODE
//   38 INTERRUPT_HANDLER(I2C_IRQHandler, 19)
//   39 {
I2C_IRQHandler:
_interrupt_21:
        PUSH      S:?b0
          CFI ?b0 Frame(CFA, -9)
          CFI CFA SP+10
//   40   uint8_t Last_Event_SR1 = I2C->SR1;
        LD        A, L:0x5217
//   41   uint8_t Cache;
//   42 
//   43   if((Last_Event_SR1 & (I2C_SR1_ADDR | I2C_SR1_RXNE |
//   44                         I2C_SR1_STOPF | I2C_SR1_TXE)) == I2C_SR1_TXE)
        LD        S:?b0, A
        AND       A, #0xd2
        CP        A, #0x80
        JRNE      L:??I2C_IRQHandler_0
//   45   {
//   46     if((I2C->SR2 & (I2C_SR2_AF | I2C_SR2_BERR |
//   47                     I2C_SR2_OVR | I2C_SR2_ARLO)) == 0)
        LD        A, #0xf
        BCP       A, L:0x5218
        JRNE      L:??I2C_IRQHandler_0
//   48     {
//   49       if(IIC_Reg_Addr_Point >= IIC_REG_SIZE)
        LDW       X, #IIC_Reg_Addr_Point
        LD        A, (X)
        CP        A, #0x60
        JRC       L:??I2C_IRQHandler_1
//   50       {
//   51         I2C->DR = 0xA5;
        MOV       L:0x5216, #0xa5
        JP        L:??I2C_IRQHandler_2
//   52       }
//   53       else
//   54       {
//   55         I2C->DR = IIC_Reg_Buff[IIC_Reg_Addr_Point];
??I2C_IRQHandler_1:
        LD        A, L:IIC_Reg_Addr_Point
        CLRW      X
        LD        XL, A
        LD        A, (L:IIC_Reg_Buff,X)
        LD        L:0x5216, A
//   56         IIC_Reg_Addr_Point++;
        LD        A, #0x1
        ADD       A, L:IIC_Reg_Addr_Point
        LD        L:IIC_Reg_Addr_Point, A
//   57         if(IIC_Reg_Addr_Point >= IIC_REG_SIZE) IIC_Reg_Addr_Point = 0;
        LDW       X, #IIC_Reg_Addr_Point
        LD        A, (X)
        CP        A, #0x60
        JRNC      ??lb_0
        JP        L:??I2C_IRQHandler_2
??lb_0:
        CLR       L:IIC_Reg_Addr_Point
//   58       }
//   59       return;
        JP        L:??I2C_IRQHandler_2
//   60     }
//   61   }
//   62 
//   63   if((Last_Event_SR1 & I2C_SR1_RXNE) == I2C_SR1_RXNE)
??I2C_IRQHandler_0:
        LD        A, S:?b0
        BCP       A, #0x40
        JREQ      L:??I2C_IRQHandler_3
//   64   {
//   65     Cache = I2C->DR;
        MOV       S:?b0, L:0x5216
//   66     if(IIC_Reg_Addr_Get)
        LD        A, L:IIC_Reg_Addr_Get
        JREQ      L:??I2C_IRQHandler_4
//   67     {
//   68       if(((IIC_Reg_Addr_Point >= CTRL_PERSIST_BEGIN) &&
//   69           (IIC_Reg_Addr_Point < CTRL_PERSIST_END)) ||
//   70          (IIC_Reg_Addr_Point==CTRL_REG_DEBUG_DAC_PRESET))
        LDW       X, #IIC_Reg_Addr_Point
        LD        A, (X)
        CP        A, #0x4
        JRC       L:??I2C_IRQHandler_5
        LD        A, (X)
        CP        A, #0x40
        JRC       L:??I2C_IRQHandler_6
??I2C_IRQHandler_5:
        LD        A, #0x47
        CP        A, L:IIC_Reg_Addr_Point
        JREQ      ??lb_1
        JP        L:??I2C_IRQHandler_2
//   71       {
//   72         IIC_Reg_Buff[IIC_Reg_Addr_Point] = Cache;
??lb_1:
??I2C_IRQHandler_6:
        LD        A, L:IIC_Reg_Addr_Point
        CLRW      X
        LD        XL, A
        LD        A, S:?b0
        LD        (L:IIC_Reg_Buff,X), A
//   73         IIC_Reg_Addr_Point++;
        LD        A, #0x1
        ADD       A, L:IIC_Reg_Addr_Point
        LD        L:IIC_Reg_Addr_Point, A
        JP        L:??I2C_IRQHandler_2
//   74       }
//   75     }
//   76     else
//   77     {
//   78       IIC_Reg_Addr_Get = 1;
??I2C_IRQHandler_4:
        MOV       L:IIC_Reg_Addr_Get, #0x1
//   79       if(Cache < IIC_REG_SIZE)
        LD        A, S:?b0
        CP        A, #0x60
        JRNC      L:??I2C_IRQHandler_7
//   80       {
//   81         IIC_Reg_Addr_Point = Cache;
        LD        L:IIC_Reg_Addr_Point, A
        JP        L:??I2C_IRQHandler_2
//   82       }
//   83       else
//   84       {
//   85         if((Cache >= 0xC0) && (Cache <= 0xC9))
??I2C_IRQHandler_7:
        ADD       A, #0x40
        CP        A, #0xa
        JRNC      L:??I2C_IRQHandler_8
//   86         {
//   87           IIC_CMD = Cache;
        LD        A, S:?b0
        LD        L:IIC_CMD, A
//   88           IIC_Reg_Buff[CTRL_REG_BRIDGE_STATUS] |= CTRL_BRIDGE_STATUS_BUSY;
        LD        A, #0x1
        OR        A, L:IIC_Reg_Buff + 70
        LD        L:IIC_Reg_Buff + 70, A
//   89         }
//   90         IIC_Reg_Addr_Point = IIC_REG_SIZE;
??I2C_IRQHandler_8:
        MOV       L:IIC_Reg_Addr_Point, #0x60
//   91       }
//   92     }
//   93     return;
        JRA       L:??I2C_IRQHandler_2
//   94   }
//   95 
//   96   if(I2C->SR2 & (I2C_SR2_AF | I2C_SR2_BERR |
//   97                  I2C_SR2_OVR | I2C_SR2_ARLO))
??I2C_IRQHandler_3:
        LD        A, #0xf
        BCP       A, L:0x5218
        JREQ      L:??I2C_IRQHandler_9
//   98   {
//   99     I2C->SR2 &= (uint8_t)~(I2C_SR2_AF | I2C_SR2_BERR |
//  100                             I2C_SR2_OVR | I2C_SR2_ARLO);
        LD        A, #0xf0
        AND       A, L:0x5218
        LD        L:0x5218, A
//  101     I2C->ITR &= (uint8_t)~I2C_ITR_ITBUFEN;
        BRES      L:0x521a, #0x2
//  102     IIC_Reg_Addr_Get = 0;
        CLR       L:IIC_Reg_Addr_Get
//  103     return;
        JRA       L:??I2C_IRQHandler_2
//  104   }
//  105 
//  106   if((Last_Event_SR1 & I2C_SR1_STOPF) == I2C_SR1_STOPF)
??I2C_IRQHandler_9:
        LD        A, S:?b0
        BCP       A, #0x10
        JREQ      L:??I2C_IRQHandler_10
//  107   {
//  108     I2C->CR2 |= I2C_CR2_ACK;
        BSET      L:0x5211, #0x2
//  109     I2C->ITR &= (uint8_t)~I2C_ITR_ITBUFEN;
        BRES      L:0x521a, #0x2
//  110     IIC_Reg_Addr_Get = 0;
        CLR       L:IIC_Reg_Addr_Get
//  111     return;
        JRA       L:??I2C_IRQHandler_2
//  112   }
//  113 
//  114   if((Last_Event_SR1 & I2C_SR1_ADDR) == I2C_SR1_ADDR)
??I2C_IRQHandler_10:
        LD        A, S:?b0
        BCP       A, #0x2
        JREQ      L:??I2C_IRQHandler_2
//  115   {
//  116     Cache = I2C->SR3;
        MOV       S:?b0, L:0x5219
//  117     I2C->ITR |= I2C_ITR_ITBUFEN;
        BSET      L:0x521a, #0x2
//  118     if((Cache & I2C_SR3_TRA) == I2C_SR3_TRA)
        LD        A, S:?b0
        BCP       A, #0x4
        JREQ      L:??I2C_IRQHandler_11
//  119     {
//  120       if(IIC_Reg_Addr_Point >= IIC_REG_SIZE)
        LDW       X, #IIC_Reg_Addr_Point
        LD        A, (X)
        CP        A, #0x60
        JRC       L:??I2C_IRQHandler_12
//  121       {
//  122         I2C->DR = 0xA5;
        MOV       L:0x5216, #0xa5
        JRA       L:??I2C_IRQHandler_2
//  123       }
//  124       else
//  125       {
//  126         I2C->DR = IIC_Reg_Buff[IIC_Reg_Addr_Point];
??I2C_IRQHandler_12:
        LD        A, L:IIC_Reg_Addr_Point
        CLRW      X
        LD        XL, A
        LD        A, (L:IIC_Reg_Buff,X)
        LD        L:0x5216, A
//  127         IIC_Reg_Addr_Point++;
        LD        A, #0x1
        ADD       A, L:IIC_Reg_Addr_Point
        LD        L:IIC_Reg_Addr_Point, A
//  128         if(IIC_Reg_Addr_Point >= IIC_REG_SIZE) IIC_Reg_Addr_Point = 0;
        LDW       X, #IIC_Reg_Addr_Point
        LD        A, (X)
        CP        A, #0x60
        JRC       L:??I2C_IRQHandler_2
        CLR       L:IIC_Reg_Addr_Point
        JRA       L:??I2C_IRQHandler_2
//  129       }
//  130     }
//  131     else
//  132     {
//  133       IIC_Reg_Addr_Get = 0;
??I2C_IRQHandler_11:
        CLR       L:IIC_Reg_Addr_Get
//  134     }
//  135   }
//  136 }
??I2C_IRQHandler_2:
        POP       S:?b0
          CFI ?b0 SameValue
          CFI CFA SP+9
        IRET
          CFI EndBlock cfiBlock1

        SECTION VREGS:DATA:REORDER:NOROOT(0)

        END
//  137 
//  138 
//  139 
//  140 //typedef enum
//  141 //{
//  142 //  I2C_EVENT_SLAVE_RECEIVER_ADDRESS_MATCHED    = (uint16_t)0x0202,  /*!< BUSY and ADDR flags */
//  143 //  I2C_EVENT_SLAVE_TRANSMITTER_ADDRESS_MATCHED = (uint16_t)0x0682,  /*!< TRA, BUSY, TXE and ADDR flags */
//  144 //  I2C_EVENT_SLAVE_GENERALCALLADDRESS_MATCHED  = (uint16_t)0x1200,  /*!< EV2: GENCALL and BUSY flags */
//  145 //  I2C_EVENT_SLAVE_BYTE_RECEIVED              = (uint16_t)0x0240,  /*!< BUSY and RXNE flags */
//  146 //  I2C_EVENT_SLAVE_STOP_DETECTED              = (uint16_t)0x0010,  /*!< STOPF flag */
//  147 //  I2C_EVENT_SLAVE_BYTE_TRANSMITTED           = (uint16_t)0x0684,  /*!< TRA, BUSY, TXE and BTF flags */
//  148 //  I2C_EVENT_SLAVE_BYTE_TRANSMITTING          = (uint16_t)0x0680,  /*!< TRA, BUSY and TXE flags */
//  149 //} I2C_Event_TypeDef;  
//  150 
//  151 //INTERRUPT_HANDLER(I2C_IRQHandler, 19)
//  152 //{
//  153 //  uint8_t Cache;
//  154 //  __IO uint16_t lastevent=0;
//  155 //  *((uint8_t*)&lastevent+1)=I2C->SR1;
//  156 //  *(uint8_t*)&lastevent=I2C->SR3;
//  157 //  GPIOD->ODR &=~ GPIO_PIN_5;
//  158 //  
//  159 //  if((lastevent&I2C_EVENT_SLAVE_TRANSMITTER_ADDRESS_MATCHED) == I2C_EVENT_SLAVE_TRANSMITTER_ADDRESS_MATCHED)
//  160 //  {
//  161 //    I2C->DR = IIC_Reg_Buff[IIC_Reg_Addr_Point];
//  162 //    GPIOD->ODR |= GPIO_PIN_5;
//  163 //    IIC_Reg_Addr_Point++;
//  164 //    if(IIC_Reg_Addr_Point>=IIC_REG_SIZE)IIC_Reg_Addr_Point = 0;
//  165 //    GPIOD->ODR &=~ GPIO_PIN_5; 
//  166 //  }
//  167 //  else
//  168 //  if((lastevent&I2C_EVENT_SLAVE_RECEIVER_ADDRESS_MATCHED) == I2C_EVENT_SLAVE_RECEIVER_ADDRESS_MATCHED)  
//  169 //  {
//  170 //    IIC_Reg_Addr_Get = 0;
//  171 //  }
//  172 //  if((lastevent&I2C_EVENT_SLAVE_BYTE_TRANSMITTING) == I2C_EVENT_SLAVE_BYTE_TRANSMITTING)
//  173 //  {
//  174 //      I2C->DR = IIC_Reg_Buff[IIC_Reg_Addr_Point];
//  175 //      IIC_Reg_Addr_Point++;
//  176 //      if(IIC_Reg_Addr_Point>=IIC_REG_SIZE)IIC_Reg_Addr_Point = 0;    
//  177 //  }
//  178 //  if((lastevent&I2C_EVENT_SLAVE_BYTE_RECEIVED) == I2C_EVENT_SLAVE_BYTE_RECEIVED)
//  179 //  {
//  180 //    Cache = I2C->DR;
//  181 //    if(IIC_Reg_Addr_Get)
//  182 //    {
//  183 //      if(IIC_Reg_Addr_Point!=0)//0寄存器是只读
//  184 //      {
//  185 //        IIC_Reg_Buff[IIC_Reg_Addr_Point] = Cache;
//  186 //      }
//  187 //    }
//  188 //    else
//  189 //    {
//  190 //      if(Cache < IIC_REG_SIZE)//Data
//  191 //      {
//  192 //        IIC_Reg_Addr_Point = Cache;
//  193 //        IIC_Reg_Addr_Get = 1;
//  194 //      }
//  195 //      else//CMD
//  196 //      {
//  197 //      
//  198 //      }
//  199 //    }   
//  200 //  }
//  201 //  if((I2C->SR1&I2C_SR1_STOPF) == I2C_SR1_STOPF)
//  202 //  {
//  203 //    I2C->CR2 = I2C_CR2_ACK;    
//  204 //  }
//  205 //  
//  206 //  if((I2C->SR2&I2C_SR2_AF) == I2C_SR2_AF)
//  207 //  {
//  208 //    I2C->SR2 &=~ I2C_SR2_AF;
//  209 //  }
//  210 //  if((I2C->SR2&I2C_SR2_BERR) == I2C_SR2_BERR)
//  211 //  {
//  212 //    I2C->SR2 &=~ I2C_SR2_BERR;
//  213 //  }    
//  214 //  GPIOD->ODR |= GPIO_PIN_5;
//  215 //}
//  216 
//  217 
//  218 //INTERRUPT_HANDLER(I2C_IRQHandler, 19)
//  219 //{
//  220 //  uint8_t Cache;
//  221 //  __IO uint16_t lastevent=0;
//  222 //  *((uint8_t*)&lastevent+1)=I2C->SR1&(*((uint8_t*)&I2C_Event+1));
//  223 //  *(uint8_t*)&lastevent=I2C->SR3&(*(uint8_t*)&I2C_Event);
//  224 //  
//  225 //  
//  226 //  if((I2C->SR2&I2C_SR2_AF) == I2C_SR2_AF)
//  227 //  {
//  228 //    I2C->SR2 &=~ I2C_SR2_AF;
//  229 //  
//  230 //  }
//  231 //  if((I2C->SR2&I2C_SR2_BERR) == I2C_SR2_BERR)
//  232 //  {
//  233 //    I2C->SR2 &=~ I2C_SR2_BERR;
//  234 //  
//  235 //  }
//  236 //  if(I2C_CheckEvent(I2C_EVENT_SLAVE_RECEIVER_ADDRESS_MATCHED))
//  237 //  {
//  238 //    if(I2C_CheckEvent(I2C_EVENT_SLAVE_TRANSMITTER_ADDRESS_MATCHED))
//  239 //    {
//  240 //      I2C->DR = IIC_Reg_Buff[IIC_Reg_Addr_Point];
//  241 //      IIC_Reg_Addr_Point++;
//  242 //      if(IIC_Reg_Addr_Point>=IIC_REG_SIZE)IIC_Reg_Addr_Point = 0;
//  243 //    }
//  244 //    else
//  245 //    {
//  246 //      IIC_Reg_Addr_Get = 0;
//  247 //    }
//  248 //  }
//  249 //  if(I2C_CheckEvent(I2C_EVENT_SLAVE_BYTE_TRANSMITTING))
//  250 //  {
//  251 //      I2C->DR = IIC_Reg_Buff[IIC_Reg_Addr_Point];
//  252 //      IIC_Reg_Addr_Point++;
//  253 //      if(IIC_Reg_Addr_Point>=IIC_REG_SIZE)IIC_Reg_Addr_Point = 0;    
//  254 //  }
//  255 //  if(I2C_CheckEvent(I2C_EVENT_SLAVE_BYTE_RECEIVED))
//  256 //  {
//  257 //    Cache = I2C->DR;
//  258 //    if(IIC_Reg_Addr_Get)
//  259 //    {
//  260 //      if(IIC_Reg_Addr_Point!=0)//0寄存器是只读
//  261 //      {
//  262 //        IIC_Reg_Buff[IIC_Reg_Addr_Point] = Cache;
//  263 //      }
//  264 //    }
//  265 //    else
//  266 //    {
//  267 //      if(Cache < IIC_REG_SIZE)//Data
//  268 //      {
//  269 //        IIC_Reg_Addr_Point = Cache;
//  270 //        IIC_Reg_Addr_Get = 1;
//  271 //      }
//  272 //      else//CMD
//  273 //      {
//  274 //      
//  275 //      }
//  276 //    }   
//  277 //  }
//  278 //  
//  279 //}
//  280 
// 
//  99 bytes in section .near.bss
// 376 bytes in section .near_func.text
// 
// 376 bytes of CODE memory
//  99 bytes of DATA memory
//
//Errors: none
//Warnings: 1
