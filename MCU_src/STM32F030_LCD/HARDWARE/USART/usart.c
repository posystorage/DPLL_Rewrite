#include <usart.h>

void USART_Configuration(void)
{     
	GPIO_InitTypeDef GPIO_InitStruct;
	USART_InitTypeDef USART_InitStruct;	
	//串口时钟配置	
	RCC_AHBPeriphClockCmd(RCC_AHBPeriph_GPIOA, ENABLE);
	RCC_APB1PeriphClockCmd(RCC_APB1Periph_USART2, ENABLE);  
 //gpio配置
	 /* Connect PXx to USARTx_Tx */
  GPIO_PinAFConfig(GPIOA, GPIO_PinSource2, GPIO_AF_1);

		/* Configure USART Tx as alternate function push-pull */
  GPIO_InitStruct.GPIO_Pin = GPIO_Pin_2;
  GPIO_InitStruct.GPIO_Mode = GPIO_Mode_AF;
  GPIO_InitStruct.GPIO_Speed = GPIO_Speed_Level_3;
  GPIO_InitStruct.GPIO_OType = GPIO_OType_PP;
  GPIO_InitStruct.GPIO_PuPd = GPIO_PuPd_UP;
  GPIO_Init(GPIOA, &GPIO_InitStruct);

	
		
//串口模式的配置
	 USART_InitStruct.USART_BaudRate = 115200;
	 USART_InitStruct.USART_WordLength = USART_WordLength_8b;
	 USART_InitStruct.USART_StopBits = USART_StopBits_1;
	 USART_InitStruct.USART_Parity = USART_Parity_No ;
	 USART_InitStruct.USART_HardwareFlowControl = USART_HardwareFlowControl_None;
	 USART_InitStruct.USART_Mode = USART_Mode_Tx;
	 USART_Init(USART2, &USART_InitStruct); 
	 USART_Cmd(USART2, ENABLE);
}			
		                                 
struct __FILE 
{ 
	int handle; 

}; 

FILE __stdout;       

void _sys_exit(int x) 
{ 
	x = x; 
} 
	int fputc(int ch, FILE *f)
{
  /* Place your implementation of fputc here */
  /* e.g. write a character to the USART */
	
  /* Loop until the end of transmission */
  while(USART_GetFlagStatus(USART2, USART_FLAG_TC) == RESET)
  {
  }

  USART_SendData(USART2, (uint8_t) ch);


  return ch;
}
