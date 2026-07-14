///////////////////////////////////////////////////////////////////////////////
//
// IAR C/C++ Compiler V2.20.3.189 for STM8                14/Jul/2026  16:44:57
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
        EXTERN ?pop_w0
        EXTERN ?push_w0

        PUBLIC I2C_IRQHandler
        PUBLIC IIC_CMD
        PUBLIC IIC_Reg_Addr_Get
        PUBLIC IIC_Reg_Addr_Point
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
//    5 uint8_t IIC_Reg_Addr_Point;
IIC_Reg_Addr_Point:
        DS8 1

        SECTION `.near.bss`:DATA:REORDER:NOROOT(0)
//    6 uint8_t IIC_Reg_Buff[IIC_REG_SIZE];
IIC_Reg_Buff:
        DS8 96

        SECTION `.near.bss`:DATA:REORDER:NOROOT(0)
//    7 uint8_t IIC_Reg_Addr_Get;//标记获得了地址位
IIC_Reg_Addr_Get:
        DS8 1

        SECTION `.near.bss`:DATA:REORDER:NOROOT(0)
//    8 uint8_t IIC_CMD;
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
//   24   I2C->ITR = I2C_ITR_ITBUFEN | I2C_ITR_ITEVTEN;
        MOV       L:0x521a, #0x6
//   25   ITC->ISPR5 |= 0xC0;
        LD        A, #0xc0
        OR        A, L:0x7f74
        LD        L:0x7f74, A
//   26   IIC_Reg_Addr_Point = 0;
        CLR       L:IIC_Reg_Addr_Point
//   27   IIC_Reg_Buff[CTRL_REG_ID] = 0xA5;
        MOV       L:IIC_Reg_Buff, #0xa5
//   28   IIC_Reg_Buff[CTRL_REG_PROTOCOL_VERSION] = CTRL_PROTOCOL_VERSION;
        MOV       L:IIC_Reg_Buff + 1, #0x3
//   29   IIC_Reg_Buff[CTRL_REG_REQUEST_SEQ] = 0;
        CLR       L:IIC_Reg_Buff + 2
//   30   IIC_Reg_Buff[CTRL_REG_CONTROL_FLAGS] = 0;
        CLR       L:IIC_Reg_Buff + 3
//   31   IIC_Reg_Addr_Get = 0;
        CLR       L:IIC_Reg_Addr_Get
//   32   IIC_CMD = 0;
        CLR       L:IIC_CMD
//   33 }
        RET
          CFI EndBlock cfiBlock0
//   34 
//   35 

        SECTION `.near_func.text`:CODE:REORDER:NOROOT(0)
          CFI Block cfiBlock1 Using cfiCommon0
          CFI Function IIC_Slave_RX_Byte
        CODE
//   36 void IIC_Slave_RX_Byte(uint8_t Last_Event_SR1)
//   37 {
//   38   uint8_t Cache;
//   39   if((Last_Event_SR1 & I2C_SR1_RXNE) == I2C_SR1_RXNE)
IIC_Slave_RX_Byte:
        BCP       A, #0x40
        JREQ      L:??IIC_Slave_RX_Byte_0
//   40   {
//   41     Cache = I2C->DR;
        MOV       S:?b0, L:0x5216
//   42     if(IIC_Reg_Addr_Get)
        LD        A, L:IIC_Reg_Addr_Get
        JREQ      L:??IIC_Slave_RX_Byte_1
//   43     {
//   44       if(((IIC_Reg_Addr_Point>=CTRL_PERSIST_BEGIN)&&
//   45           (IIC_Reg_Addr_Point<CTRL_PERSIST_END))||
//   46          (IIC_Reg_Addr_Point==CTRL_REG_DEBUG_DAC_PRESET))
        LD        A, #0xfc
        ADD       A, L:IIC_Reg_Addr_Point
        CP        A, #0x3c
        JRC       L:??IIC_Slave_RX_Byte_2
        LD        A, #0x47
        CP        A, L:IIC_Reg_Addr_Point
        JRNE      L:??IIC_Slave_RX_Byte_0
//   47       {
//   48         IIC_Reg_Buff[IIC_Reg_Addr_Point] = Cache;
??IIC_Slave_RX_Byte_2:
        LD        A, L:IIC_Reg_Addr_Point
        CLRW      X
        LD        XL, A
        LD        A, S:?b0
        LD        (L:IIC_Reg_Buff,X), A
//   49         IIC_Reg_Addr_Point++;
        LD        A, #0x1
        ADD       A, L:IIC_Reg_Addr_Point
        LD        L:IIC_Reg_Addr_Point, A
        RET
//   50       }
//   51     }
//   52     else
//   53     {
//   54       IIC_Reg_Addr_Get = 1;
??IIC_Slave_RX_Byte_1:
        MOV       L:IIC_Reg_Addr_Get, #0x1
//   55       if(Cache < IIC_REG_SIZE)//Data
        LD        A, S:?b0
        CP        A, #0x60
        JRNC      L:??IIC_Slave_RX_Byte_3
//   56       {
//   57         IIC_Reg_Addr_Point = Cache;
        LD        L:IIC_Reg_Addr_Point, A
        RET
//   58       }
//   59       else//CMD
//   60       {
//   61         if((Cache>=0xC0)&&(Cache<=0xC9))
??IIC_Slave_RX_Byte_3:
        ADD       A, #0x40
        CP        A, #0xa
        JRNC      L:??IIC_Slave_RX_Byte_4
//   62         {
//   63           
//   64           IIC_CMD = Cache;
        LD        A, S:?b0
        LD        L:IIC_CMD, A
//   65           IIC_Reg_Buff[CTRL_REG_BRIDGE_STATUS] |= CTRL_BRIDGE_STATUS_BUSY;//busy
        LD        A, #0x1
        OR        A, L:IIC_Reg_Buff + 70
        LD        L:IIC_Reg_Buff + 70, A
//   66           
//   67         }
//   68         IIC_Reg_Addr_Point = IIC_REG_SIZE;
??IIC_Slave_RX_Byte_4:
        MOV       L:IIC_Reg_Addr_Point, #0x60
//   69       }
//   70     }   
//   71   }  
//   72 }
??IIC_Slave_RX_Byte_0:
        RET
          CFI EndBlock cfiBlock1
//   73 

        SECTION `.near_func.text`:CODE:REORDER:NOROOT(0)
          CFI Block cfiBlock2 Using cfiCommon1
          CFI Function I2C_IRQHandler
        CODE
//   74 INTERRUPT_HANDLER(I2C_IRQHandler, 19)
//   75 {
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
        CALL      L:?push_w0
          CFI ?b1 Frame(CFA, -9)
          CFI ?b0 Frame(CFA, -10)
          CFI CFA SP+11
//   76   uint8_t Last_Event_SR1 = I2C->SR1;
        MOV       S:?b0, L:0x5217
//   77   uint8_t Last_Event_SR3 = I2C->SR3;
        LD        A, L:0x5219
//   78   if((Last_Event_SR3 & I2C_SR3_BUSY) == I2C_SR3_BUSY)
        LD        S:?b1, A
        BCP       A, #0x2
        JREQ      L:??I2C_IRQHandler_0
//   79   {
//   80     if((Last_Event_SR1 & I2C_SR1_ADDR) == I2C_SR1_ADDR)
        LD        A, S:?b0
        BCP       A, #0x2
        JREQ      L:??I2C_IRQHandler_1
//   81     {
//   82       if((Last_Event_SR3 & I2C_SR3_TRA) == I2C_SR3_TRA)
        LD        A, S:?b1
        BCP       A, #0x4
        JREQ      L:??I2C_IRQHandler_2
//   83       {
//   84         if(IIC_Reg_Addr_Point>=IIC_REG_SIZE)I2C->DR = 0xA5;
        LDW       X, #IIC_Reg_Addr_Point
        LD        A, (X)
        CP        A, #0x60
        JRC       L:??I2C_IRQHandler_3
        MOV       L:0x5216, #0xa5
        JRA       L:??I2C_IRQHandler_1
//   85         else
//   86         {
//   87           I2C->DR = IIC_Reg_Buff[IIC_Reg_Addr_Point];
??I2C_IRQHandler_3:
        LD        A, L:IIC_Reg_Addr_Point
        CLRW      X
        LD        XL, A
        LD        A, (L:IIC_Reg_Buff,X)
        LD        L:0x5216, A
//   88           IIC_Reg_Addr_Point++;
        LD        A, #0x1
        ADD       A, L:IIC_Reg_Addr_Point
        LD        L:IIC_Reg_Addr_Point, A
//   89           if(IIC_Reg_Addr_Point>=IIC_REG_SIZE)IIC_Reg_Addr_Point = 0;         
        LDW       X, #IIC_Reg_Addr_Point
        LD        A, (X)
        CP        A, #0x60
        JRC       L:??I2C_IRQHandler_1
        CLR       L:IIC_Reg_Addr_Point
        JRA       L:??I2C_IRQHandler_1
//   90         }
//   91       }
//   92       else
//   93       {
//   94         IIC_Reg_Addr_Get = 0;
??I2C_IRQHandler_2:
        CLR       L:IIC_Reg_Addr_Get
//   95       }
//   96     }  
//   97     if(((Last_Event_SR3 & I2C_SR3_TRA) == I2C_SR3_TRA) && ((Last_Event_SR1 & I2C_SR1_TXE) == I2C_SR1_TXE))
??I2C_IRQHandler_1:
        LD        A, S:?b1
        BCP       A, #0x4
        JREQ      L:??I2C_IRQHandler_4
        LD        A, S:?b0
        BCP       A, #0x80
        JREQ      L:??I2C_IRQHandler_4
//   98     {
//   99       if(IIC_Reg_Addr_Point>=IIC_REG_SIZE)I2C->DR = 0xA5;
        LDW       X, #IIC_Reg_Addr_Point
        LD        A, (X)
        CP        A, #0x60
        JRC       L:??I2C_IRQHandler_5
        MOV       L:0x5216, #0xa5
        JRA       L:??I2C_IRQHandler_4
//  100       else
//  101       {
//  102         I2C->DR = IIC_Reg_Buff[IIC_Reg_Addr_Point];
??I2C_IRQHandler_5:
        LD        A, L:IIC_Reg_Addr_Point
        CLRW      X
        LD        XL, A
        LD        A, (L:IIC_Reg_Buff,X)
        LD        L:0x5216, A
//  103         IIC_Reg_Addr_Point++;
        LD        A, #0x1
        ADD       A, L:IIC_Reg_Addr_Point
        LD        L:IIC_Reg_Addr_Point, A
//  104         if(IIC_Reg_Addr_Point>=IIC_REG_SIZE)IIC_Reg_Addr_Point = 0;  
        LDW       X, #IIC_Reg_Addr_Point
        LD        A, (X)
        CP        A, #0x60
        JRC       L:??I2C_IRQHandler_4
        CLR       L:IIC_Reg_Addr_Point
//  105       }
//  106     }
//  107     IIC_Slave_RX_Byte(Last_Event_SR1); 
??I2C_IRQHandler_4:
        LD        A, S:?b0
        CALL      L:IIC_Slave_RX_Byte
//  108   }
//  109 
//  110   if((I2C->SR1&I2C_SR1_STOPF) == I2C_SR1_STOPF)
??I2C_IRQHandler_0:
        BTJF      L:0x5217, #0x4, L:??I2C_IRQHandler_6
//  111   {
//  112     I2C->CR2 = I2C_CR2_ACK;  
        MOV       L:0x5211, #0x4
//  113     IIC_Slave_RX_Byte(I2C->SR1);
        LD        A, L:0x5217
        CALL      L:IIC_Slave_RX_Byte
//  114   }
//  115   
//  116   if((I2C->SR2&I2C_SR2_AF) == I2C_SR2_AF)
??I2C_IRQHandler_6:
        BTJF      L:0x5218, #0x2, L:??I2C_IRQHandler_7
//  117   {
//  118     I2C->SR2 &=~ I2C_SR2_AF;
        BRES      L:0x5218, #0x2
//  119   }
//  120   if((I2C->SR2&I2C_SR2_BERR) == I2C_SR2_BERR)
??I2C_IRQHandler_7:
        BTJF      L:0x5218, #0x0, L:??I2C_IRQHandler_8
//  121   {
//  122     I2C->SR2 &=~ I2C_SR2_BERR;
        BRES      L:0x5218, #0x0
//  123   } 
//  124 }
??I2C_IRQHandler_8:
        CALL      L:?pop_w0
          CFI ?b0 SameValue
          CFI ?b1 SameValue
          CFI CFA SP+9
        IRET
          CFI EndBlock cfiBlock2

        SECTION VREGS:DATA:REORDER:NOROOT(0)

        END
//  125 
//  126 
//  127 
//  128 //typedef enum
//  129 //{
//  130 //  I2C_EVENT_SLAVE_RECEIVER_ADDRESS_MATCHED    = (uint16_t)0x0202,  /*!< BUSY and ADDR flags */
//  131 //  I2C_EVENT_SLAVE_TRANSMITTER_ADDRESS_MATCHED = (uint16_t)0x0682,  /*!< TRA, BUSY, TXE and ADDR flags */
//  132 //  I2C_EVENT_SLAVE_GENERALCALLADDRESS_MATCHED  = (uint16_t)0x1200,  /*!< EV2: GENCALL and BUSY flags */
//  133 //  I2C_EVENT_SLAVE_BYTE_RECEIVED              = (uint16_t)0x0240,  /*!< BUSY and RXNE flags */
//  134 //  I2C_EVENT_SLAVE_STOP_DETECTED              = (uint16_t)0x0010,  /*!< STOPF flag */
//  135 //  I2C_EVENT_SLAVE_BYTE_TRANSMITTED           = (uint16_t)0x0684,  /*!< TRA, BUSY, TXE and BTF flags */
//  136 //  I2C_EVENT_SLAVE_BYTE_TRANSMITTING          = (uint16_t)0x0680,  /*!< TRA, BUSY and TXE flags */
//  137 //} I2C_Event_TypeDef;  
//  138 
//  139 //INTERRUPT_HANDLER(I2C_IRQHandler, 19)
//  140 //{
//  141 //  uint8_t Cache;
//  142 //  __IO uint16_t lastevent=0;
//  143 //  *((uint8_t*)&lastevent+1)=I2C->SR1;
//  144 //  *(uint8_t*)&lastevent=I2C->SR3;
//  145 //  GPIOD->ODR &=~ GPIO_PIN_5;
//  146 //  
//  147 //  if((lastevent&I2C_EVENT_SLAVE_TRANSMITTER_ADDRESS_MATCHED) == I2C_EVENT_SLAVE_TRANSMITTER_ADDRESS_MATCHED)
//  148 //  {
//  149 //    I2C->DR = IIC_Reg_Buff[IIC_Reg_Addr_Point];
//  150 //    GPIOD->ODR |= GPIO_PIN_5;
//  151 //    IIC_Reg_Addr_Point++;
//  152 //    if(IIC_Reg_Addr_Point>=IIC_REG_SIZE)IIC_Reg_Addr_Point = 0;
//  153 //    GPIOD->ODR &=~ GPIO_PIN_5; 
//  154 //  }
//  155 //  else
//  156 //  if((lastevent&I2C_EVENT_SLAVE_RECEIVER_ADDRESS_MATCHED) == I2C_EVENT_SLAVE_RECEIVER_ADDRESS_MATCHED)  
//  157 //  {
//  158 //    IIC_Reg_Addr_Get = 0;
//  159 //  }
//  160 //  if((lastevent&I2C_EVENT_SLAVE_BYTE_TRANSMITTING) == I2C_EVENT_SLAVE_BYTE_TRANSMITTING)
//  161 //  {
//  162 //      I2C->DR = IIC_Reg_Buff[IIC_Reg_Addr_Point];
//  163 //      IIC_Reg_Addr_Point++;
//  164 //      if(IIC_Reg_Addr_Point>=IIC_REG_SIZE)IIC_Reg_Addr_Point = 0;    
//  165 //  }
//  166 //  if((lastevent&I2C_EVENT_SLAVE_BYTE_RECEIVED) == I2C_EVENT_SLAVE_BYTE_RECEIVED)
//  167 //  {
//  168 //    Cache = I2C->DR;
//  169 //    if(IIC_Reg_Addr_Get)
//  170 //    {
//  171 //      if(IIC_Reg_Addr_Point!=0)//0寄存器是只读
//  172 //      {
//  173 //        IIC_Reg_Buff[IIC_Reg_Addr_Point] = Cache;
//  174 //      }
//  175 //    }
//  176 //    else
//  177 //    {
//  178 //      if(Cache < IIC_REG_SIZE)//Data
//  179 //      {
//  180 //        IIC_Reg_Addr_Point = Cache;
//  181 //        IIC_Reg_Addr_Get = 1;
//  182 //      }
//  183 //      else//CMD
//  184 //      {
//  185 //      
//  186 //      }
//  187 //    }   
//  188 //  }
//  189 //  if((I2C->SR1&I2C_SR1_STOPF) == I2C_SR1_STOPF)
//  190 //  {
//  191 //    I2C->CR2 = I2C_CR2_ACK;    
//  192 //  }
//  193 //  
//  194 //  if((I2C->SR2&I2C_SR2_AF) == I2C_SR2_AF)
//  195 //  {
//  196 //    I2C->SR2 &=~ I2C_SR2_AF;
//  197 //  }
//  198 //  if((I2C->SR2&I2C_SR2_BERR) == I2C_SR2_BERR)
//  199 //  {
//  200 //    I2C->SR2 &=~ I2C_SR2_BERR;
//  201 //  }    
//  202 //  GPIOD->ODR |= GPIO_PIN_5;
//  203 //}
//  204 
//  205 
//  206 //INTERRUPT_HANDLER(I2C_IRQHandler, 19)
//  207 //{
//  208 //  uint8_t Cache;
//  209 //  __IO uint16_t lastevent=0;
//  210 //  *((uint8_t*)&lastevent+1)=I2C->SR1&(*((uint8_t*)&I2C_Event+1));
//  211 //  *(uint8_t*)&lastevent=I2C->SR3&(*(uint8_t*)&I2C_Event);
//  212 //  
//  213 //  
//  214 //  if((I2C->SR2&I2C_SR2_AF) == I2C_SR2_AF)
//  215 //  {
//  216 //    I2C->SR2 &=~ I2C_SR2_AF;
//  217 //  
//  218 //  }
//  219 //  if((I2C->SR2&I2C_SR2_BERR) == I2C_SR2_BERR)
//  220 //  {
//  221 //    I2C->SR2 &=~ I2C_SR2_BERR;
//  222 //  
//  223 //  }
//  224 //  if(I2C_CheckEvent(I2C_EVENT_SLAVE_RECEIVER_ADDRESS_MATCHED))
//  225 //  {
//  226 //    if(I2C_CheckEvent(I2C_EVENT_SLAVE_TRANSMITTER_ADDRESS_MATCHED))
//  227 //    {
//  228 //      I2C->DR = IIC_Reg_Buff[IIC_Reg_Addr_Point];
//  229 //      IIC_Reg_Addr_Point++;
//  230 //      if(IIC_Reg_Addr_Point>=IIC_REG_SIZE)IIC_Reg_Addr_Point = 0;
//  231 //    }
//  232 //    else
//  233 //    {
//  234 //      IIC_Reg_Addr_Get = 0;
//  235 //    }
//  236 //  }
//  237 //  if(I2C_CheckEvent(I2C_EVENT_SLAVE_BYTE_TRANSMITTING))
//  238 //  {
//  239 //      I2C->DR = IIC_Reg_Buff[IIC_Reg_Addr_Point];
//  240 //      IIC_Reg_Addr_Point++;
//  241 //      if(IIC_Reg_Addr_Point>=IIC_REG_SIZE)IIC_Reg_Addr_Point = 0;    
//  242 //  }
//  243 //  if(I2C_CheckEvent(I2C_EVENT_SLAVE_BYTE_RECEIVED))
//  244 //  {
//  245 //    Cache = I2C->DR;
//  246 //    if(IIC_Reg_Addr_Get)
//  247 //    {
//  248 //      if(IIC_Reg_Addr_Point!=0)//0寄存器是只读
//  249 //      {
//  250 //        IIC_Reg_Buff[IIC_Reg_Addr_Point] = Cache;
//  251 //      }
//  252 //    }
//  253 //    else
//  254 //    {
//  255 //      if(Cache < IIC_REG_SIZE)//Data
//  256 //      {
//  257 //        IIC_Reg_Addr_Point = Cache;
//  258 //        IIC_Reg_Addr_Get = 1;
//  259 //      }
//  260 //      else//CMD
//  261 //      {
//  262 //      
//  263 //      }
//  264 //    }   
//  265 //  }
//  266 //  
//  267 //}
//  268 
// 
//  99 bytes in section .near.bss
// 353 bytes in section .near_func.text
// 
// 353 bytes of CODE memory
//  99 bytes of DATA memory
//
//Errors: none
//Warnings: none
