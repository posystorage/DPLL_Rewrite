#include "ADC.h"
//ADC0 VBIAS
//ADC1 VIN
//ADC17 VREFINT_CAL

#define ADC_DMACount 32  //连续转换的次数
#define ADC_ValueCount 2 //参与的通道


uint16_t AD_Value[ADC_DMACount][ADC_ValueCount]; //用来存放ADC转换结果，也是DMA的目标地址
uint32_t After_filter[ADC_ValueCount];

uint16_t ADC_TICK;

uint16_t VREFINT_CAL;
#define VREFINT_CAL_ADDR 0x1FFFF7BA
#define TS_CAL1_ADDR 0x1FFFF7B8
#define TS_CAL2_ADDR 0x1FFFF7C2
uint32_t ADC_P_CH1A;
uint32_t ADC_N_CH1A;
uint32_t ADC_S_CH1A;
uint32_t ADC_P_CH17A;
#define VBIAS_MUX_Res 256//257/20=12.8为衰减电阻放大系数(微调) (117.9K+10K)/10K
#define VBIAS_DIV_Res 20
#define VBIAS_TL432_Voltage 1250
#define VBIAS_Offset (-200)


int16_t ADC_VBIAS_Voltage;
uint16_t ADC_VSYS_Voltage;
uint8_t ADC_Value_Valid;

void ADC_DMA_Init(void)
{
	VREFINT_CAL=*(__IO uint16_t*)VREFINT_CAL_ADDR;
	//预计算
	ADC_P_CH17A = (uint32_t)VREFINT_CAL*3300*ADC_DMACount;
	ADC_P_CH1A = (uint32_t)VREFINT_CAL*3300*VBIAS_MUX_Res;
	ADC_N_CH1A = 0x1000*VBIAS_DIV_Res;
	ADC_S_CH1A = VBIAS_TL432_Voltage*VBIAS_MUX_Res/VBIAS_DIV_Res-VBIAS_TL432_Voltage+VBIAS_Offset;
	
	RCC->AHBENR |= RCC_AHBENR_GPIOAEN|RCC_AHBENR_GPIOBEN|RCC_AHBENR_DMAEN;//使能IO时钟 DMA
	RCC->APB2ENR |= RCC_APB2ENR_ADCEN;
	GPIOA->MODER |= 0x0000000F;//PA0 1模拟输入
	GPIOA->PUPDR &=~0x0000000F;//取消上下拉
	
	DMA1_Channel1->CPAR = (uint32_t)&ADC1->DR; //&ADC1->DR 或者 ADC1_DR_Address
	DMA1_Channel1->CMAR = (uint32_t)&AD_Value;//DMA内存基地址
	DMA1_Channel1->CNDTR = ADC_ValueCount*ADC_DMACount; //DMA通道的DMA缓存的大小
	DMA1_Channel1->CCR = DMA_CCR_PL_1|DMA_CCR_MSIZE_0|DMA_CCR_PSIZE_0|DMA_CCR_MINC|DMA_CCR_CIRC;//高优先级 外设 存储器都是16位 循环模式 外设到储存
	DMA1_Channel1->CCR |= DMA_CCR_EN;
	
	//ADC1->CFGR1 = ADC_CFGR1_CONT|ADC_CFGR1_DMACFG|ADC_CFGR1_DMAEN;//连续转换 右对齐 12位 上扫描 使能DMA 
	ADC1->CFGR1 = ADC_CFGR1_CONT;//此处暂时不使能DMA 否则校准结果会触发DMA
	ADC1->CFGR2 = 0;//使用内部14mhz ADC专用时钟
	//adc主时钟14mhz，采样239.5个周期，量化12.5个周期一次采样55K
	//按35次采样+采样8个通道，198hz采样一个循环
	//每5ms计算一次
	ADC1->SMPR = 0x07;
	ADC1->CHSELR=0x20001;//选择0,17通道
  ADC->CCR=1<<22;//使能内部基准
	
	ADC1->CR |= (uint32_t)ADC_CR_ADCAL;//开始较准
	while(ADC1->CR&ADC_CR_ADCAL);//等待较准
    
	ADC1->CFGR1 = ADC_CFGR1_CONT|ADC_CFGR1_DMACFG|ADC_CFGR1_DMAEN;//连续转换 右对齐 12位 上扫描 使能DMA	
  ADC1->CR |= ADC_CR_ADEN;
	while((ADC1->CR&ADC_CR_ADEN)==0);
	
	ADC1->CR |= ADC_CR_ADSTART;
	ADC_TICK = 350;
	ADC_Value_Valid = 0;
}
void ADC_Tick_Service(void)
{
	ADC_TICK++;
}

//为汇编函数
uint32_t ADC_QUICK_ADD(uint32_t* dat_addr,uint32_t nums,uint32_t jump_offset);//第一个数据的地址，要加的数据，每次加要偏移的地址数量

void ADC_Data_Service(void)
{
	uint32_t Cache;
	if(ADC_TICK<350)return;
	ADC_TICK=0;	
	After_filter[0]=ADC_QUICK_ADD((uint32_t*)&AD_Value[0][0],ADC_DMACount,ADC_ValueCount*2);//VBIAS
	After_filter[1]=ADC_QUICK_ADD((uint32_t*)&AD_Value[0][1],ADC_DMACount,ADC_ValueCount*2);//内部基准通道
	ADC_VSYS_Voltage = ADC_P_CH17A/After_filter[1];
	Cache = (uint64_t)After_filter[0]*(uint64_t)ADC_P_CH1A/(After_filter[1]*ADC_N_CH1A);
	//ADC_VBIAS_Voltage = (uint64_t)After_filter[0]*(uint64_t)ADC_P_CH1A/(After_filter[1]*ADC_N_CH1A);//计算得VBIAS
	ADC_VBIAS_Voltage = (int32_t)Cache - ADC_S_CH1A;
	ADC_Value_Valid = 1;
}

