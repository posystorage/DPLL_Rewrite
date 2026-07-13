#include "FLASH.h"
//Use the last page of the stm32f030F4 to store settings and alignment data
//Page31:0x0800 7C00 - 0x0800 7FFF

#define FLASH_DATA_FIELD_ADDR 0x08007C00

//The size of a flash page on stm32f030 is 1KB. 
//We divide this sector into 8 shares, each time writing 128B storage settings and alignment data. 
//An erase is performed only after writing 8 times, and the flash life loss can be reduced.

//The first byte of each 128B data block is the data block number, and the second byte is the XOR checksum.
uint8_t FLASH_Mem_Cache[128];

uint8_t Flash_Writable_Block_Number;//A value of 0-7 equals the minimum number of writable blocks, and a value of 8 means that erasure is required for writing.
uint8_t Flash_Latest_Data_Block_Number;//A value of 0-7 equals the number of Latest_Data blocks, and a value of 8 means that no data available

//return 0 means data unavailable
//return 0 means data available
uint8_t FLASH_Found_The_Latest_Data(void)
{
	uint32_t i;
	uint8_t XOR_Checksum;
	uint32_t FLASH_READ_ADDR;
	uint16_t* SRAM_READ_BUFF=(uint16_t*)&FLASH_Mem_Cache;
	Flash_Latest_Data_Block_Number=7;
	do
	{
		FLASH_READ_ADDR=FLASH_DATA_FIELD_ADDR+Flash_Latest_Data_Block_Number*128;
		i=*(__IO uint16_t*)FLASH_READ_ADDR;
		if(i!=0xffff)			
		{
			for(i=0;i<64;i++)
			{
				SRAM_READ_BUFF[i]=*(__IO uint16_t*)FLASH_READ_ADDR;
				FLASH_READ_ADDR+=2;
			}	
			if(Flash_Latest_Data_Block_Number!=FLASH_Mem_Cache[0])continue;//Wrong data header
			XOR_Checksum=0;
			for(i=2;i<128;i++)
			{
				XOR_Checksum^=FLASH_Mem_Cache[i];		
			}
			if(XOR_Checksum==FLASH_Mem_Cache[1])
			{
				return 1;
			}
		}
	}
	while(Flash_Latest_Data_Block_Number--);
	Flash_Latest_Data_Block_Number=8;
	return 0;
}

void FLASH_Found_Writable_Block(void)
{
	uint32_t i;
	uint32_t FLASH_READ_ADDR;
	for(Flash_Writable_Block_Number=0;Flash_Writable_Block_Number<8;Flash_Writable_Block_Number++)
	{
		FLASH_READ_ADDR=FLASH_DATA_FIELD_ADDR+Flash_Writable_Block_Number*128;
		for(i=0;i<32;i++)
		{
			if((*(__IO uint32_t*)FLASH_READ_ADDR)!=0xffffffff)
			{
				goto Flash_Check_Next_Block;
			}
			FLASH_READ_ADDR+=4;
		}
		return;	
Flash_Check_Next_Block:;	
	}
}
//Write FLASH_Mem_Cache Data to Flash
void FLASH_Write_Block(void)
{
	uint32_t i;
	uint8_t XOR_Checksum;
	uint32_t FLASH_WRITE_ADDR;
	uint16_t* SRAM_WRITE_BUFF;

	FLASH_Found_Writable_Block();	
	//Unlock_Flash
	while ((FLASH->SR & FLASH_SR_BSY) != 0 );// Wait till no operation is on going
	if ((FLASH->CR & FLASH_CR_LOCK) != 0 ) //Check that the Flash is unlocked
	{
		FLASH->KEYR = FLASH_FKEY1; //Perform unlock sequence
		FLASH->KEYR = FLASH_FKEY2;
	}	
	if(Flash_Writable_Block_Number==8)//Page erasure
	{
		FLASH->CR |= FLASH_CR_PER;//Set the PER bit in the FLASH_CR register to enable page erasing
		FLASH->AR = FLASH_DATA_FIELD_ADDR;//Program the FLASH_AR register to select a page to erase
		FLASH->CR |= FLASH_CR_STRT;//Set the STRT bit in the FLASH_CR register to start the erasing
		while ((FLASH->SR & FLASH_SR_BSY) != 0);//Wait until the BSY bit is reset in the FLASH_SR register 
		if ((FLASH->SR & FLASH_SR_EOP) != 0)//Check the EOP flag in the FLASH_SR register
		{
			FLASH->SR = FLASH_SR_EOP;//Clear EOP flag by software by writing EOP at 1
		}
		else
		{
			FLASH->CR &= ~FLASH_CR_PER;
			return;
		}
		FLASH->CR &= ~FLASH_CR_PER;//Reset the PER Bit to disable the page erase
		Flash_Writable_Block_Number=0;
	}
	FLASH_WRITE_ADDR=FLASH_DATA_FIELD_ADDR+Flash_Writable_Block_Number*128;	
	FLASH_Mem_Cache[0]=Flash_Writable_Block_Number;
	XOR_Checksum=0;
	for(i=2;i<128;i++)
	{
		XOR_Checksum^=FLASH_Mem_Cache[i];
	}
	FLASH_Mem_Cache[1]=XOR_Checksum;
	SRAM_WRITE_BUFF=(uint16_t*)&FLASH_Mem_Cache;	
	
	FLASH->CR |= FLASH_CR_PG;//Set the PG bit in the FLASH_CR register to enable programming	
	for(i=0;i<64;i++)
	{
		*(__IO uint16_t*)(FLASH_WRITE_ADDR) = SRAM_WRITE_BUFF[i];
		FLASH_WRITE_ADDR+=2;
		while ((FLASH->SR & FLASH_SR_BSY) != 0);
		if ((FLASH->SR & FLASH_SR_EOP) != 0)//Check the EOP flag in the FLASH_SR register
		{
			FLASH->SR = FLASH_SR_EOP;//Clear EOP flag by software by writing EOP at 1
		}
		else
		{
			FLASH->CR &= ~FLASH_CR_PG;
			return;
		}		
	}
	FLASH->CR &= ~FLASH_CR_PG;//Reset the PG Bit to disable programming
	FLASH->KEYR = 0;//Lock Flash
}

