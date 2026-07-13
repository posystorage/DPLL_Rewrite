#include "ENCODER.h"
#include "delay.h"
#include "LCD.h"

//ENCODER and KEY include shake key
//EC1 PB4 TIM3_CH1 AF1 
//EC2 PB5 TIM3_CH2 AF1 
//EC_KEY PA12
//KEY1 PF0
//KEY2 PF1
//KEY3 PA8
//KEY4 PA11

const GPIO_TypeDef * Key_GPIO_Ports[5] = 
{
  GPIOA,
  GPIOA,
  GPIOF,
  GPIOF,
  GPIOA,
};
const uint16_t Key_GPIO_Pins[5] = 
{
  (1<<8),
  (1<<11),
  (1<<0),
  (1<<1),
  (1<<12),
};

uint16_t Old_Encoder_Num=0x8000;
uint16_t Key_Value=0;
//uint16_t Encoder_Key_Press_Time=0;
//uint16_t Encoder_Key_Double_Press_Time=0;

uint16_t KEY_Press_Time[5];




void ENCODER_KEY_Init(void)
{
	//Configure TIM3 CH1/CH2 AS Encoder interface
	RCC->APB1ENR |= RCC_APB1ENR_TIM3EN;
	RCC->AHBENR |= RCC_AHBENR_GPIOAEN|RCC_AHBENR_GPIOBEN|RCC_AHBENR_GPIOFEN;
	
	GPIOB->MODER &=~ (GPIO_MODER_MODER4|GPIO_MODER_MODER5);//PA6/7  Alternate function mode
	GPIOB->MODER |= (GPIO_MODER_MODER4_1|GPIO_MODER_MODER5_1);
	GPIOB->AFR[0] &=~ (GPIO_AFRL_AFR4|GPIO_AFRL_AFR5); 
	GPIOB->AFR[0] |= (1<<4*4)|1<<5*4;//PA4/5 AF1 TIM3
	GPIOB->PUPDR &=~ (GPIO_PUPDR_PUPDR4|GPIO_PUPDR_PUPDR5);
	GPIOB->PUPDR |= GPIO_PUPDR_PUPDR4_0|GPIO_PUPDR_PUPDR5_0;
	
	GPIOF->MODER &=~ GPIO_MODER_MODER1|GPIO_MODER_MODER0;//PF1/PF0  Input with pull up mode 
	GPIOF->PUPDR = GPIO_PUPDR_PUPDR1_0|GPIO_PUPDR_PUPDR0_0;
	
	GPIOA->MODER &=~ GPIO_MODER_MODER8|GPIO_MODER_MODER11|GPIO_MODER_MODER12;//PA8/11/12  Input with pull up mode 
	GPIOA->PUPDR &=~ (GPIO_PUPDR_PUPDR8|GPIO_PUPDR_PUPDR11|GPIO_PUPDR_PUPDR12);
	GPIOA->PUPDR |= GPIO_PUPDR_PUPDR8_0|GPIO_PUPDR_PUPDR11_0|GPIO_PUPDR_PUPDR12_0;

	TIM3->CR1=0;
	TIM3->CCR2=0x0000;
	TIM3->PSC=0x0000;
	TIM3->ARR=0xffff;	
	TIM3->DIER=0x0000;
	TIM3->CNT=0x8000;
	
#if 1 //POSTIVE
	TIM3->CCER |= TIM_CCER_CC1P; //Configure TI1FP1 inverted and TI1FP2 non inverted (CC1P = 1 CC2P = 0)
	TIM3->CCER &= (uint16_t)(~TIM_CCER_CC2P);
#else //NEGTIVE
	TIM3->CCER &= (uint16_t)(~(TIM_CCER_CC1P|TIM_CCER_CC2P)); //Configure TI1FP1 and TI1FP2 non inverted (CC1P = CC2P = 0, resetvalue)
#endif
	TIM3->CCMR1 |= TIM_CCMR1_CC1S_0 | TIM_CCMR1_IC1F_1 | TIM_CCMR1_CC2S_0 | TIM_CCMR1_IC2F_1; //Configure TI1FP1 on TI1 (CC1S = 01),configure TI1FP2 on TI2 (CC2S = 01)  fSAMPLING = fCK_INT , N = 4
	TIM3->SMCR |= TIM_SMCR_SMS_1; //Configure Counter counts up/down on TI1FP2 edge depending on TI2FP1(SMS = 010)
	TIM3->CR1 |= TIM_CR1_CEN; //nable the counter by writing CEN=1 in the TIMx_CR1 register.
	
}


void ENCODER_KEY_Service(void)
{
	uint16_t New_Encoder_Num,Time_Cache;
  uint32_t i;
	
	New_Encoder_Num=TIM3->CNT;
	if(New_Encoder_Num!=Old_Encoder_Num)
	{
		if(New_Encoder_Num>Old_Encoder_Num)
		{
			if((New_Encoder_Num-Old_Encoder_Num)>1)
			{
				Old_Encoder_Num += 2;
				Key_Value |= Econder_State_UP;
			}			
		}
		else
		{
			if((Old_Encoder_Num-New_Encoder_Num)>1)
			{
				Old_Encoder_Num -= 2;	
				Key_Value |= Econder_State_DOWN;
			}
		}		
	}
	if(Old_Encoder_Num>0xfff0||Old_Encoder_Num<0x0f)//Overflow protect
	{
		Old_Encoder_Num=0x8000;
		TIM3->CNT=0x8000;
	}
	
	for(i=0;i<5;i++)
	{
		Time_Cache = KEY_Press_Time[i];
		if((Key_GPIO_Ports[i]->IDR&Key_GPIO_Pins[i])==0)
		{
			Time_Cache++;
      if(Time_Cache == Key_Long_Press_Time)
      {
        Key_Value|= 1<<(2*i+3);
      }
      if(Time_Cache>65530)Time_Cache = Key_Long_Press_Time+1;			
		}
		else
		{
      if((Time_Cache>Key_Short_Press_Time)&&(Time_Cache<Key_Long_Press_Time))
      {
        Key_Value|= 1<<(2*i+2);
      }
      Time_Cache=0;		
		}
		KEY_Press_Time[i] = Time_Cache;
	}
	
	
//	if(Encoder_Key_Double_Press_Time)
//	{
//		Encoder_Key_Double_Press_Time++;
//		if(Encoder_Key_Double_Press_Time>Key_Double_Press_Time)//Invalid Double Press
//		{
//			Encoder_State|=Econder_State_KEY_Short_Press;
//			Encoder_Key_Double_Press_Time=0;
//		}
//	}
//	
//	if((GPIOA->IDR&0x0020)==0x0020)
//	{
//		if((Encoder_Key_Press_Time>Key_Short_Press_Time)&&(Encoder_Key_Press_Time<Key_Long_Press_Time))
//		{
//			if(Encoder_Key_Double_Press_Time)//Valid Double Press
//			{
//				Encoder_State|=Econder_State_KEY_Double_Press;
//				Encoder_Key_Double_Press_Time=0;
//			}
//			else
//			Encoder_Key_Double_Press_Time=1;
//		}
//		Encoder_Key_Press_Time=0;
//	}
//	else
//	{
//		Encoder_Key_Press_Time++;
//		
//		if(Encoder_Key_Press_Time==Key_Long_Press_Time)
//		{
//			Encoder_State|=Econder_State_KEY_Long_Press;
//		}
//		if(Encoder_Key_Press_Time>65530)Encoder_Key_Press_Time=Key_Long_Press_Time+1;//Overflow protect
//	}	
	
	
}



