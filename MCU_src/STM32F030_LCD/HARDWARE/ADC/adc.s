  THUMB
  REQUIRE8
  PRESERVE8

  AREA |.text|, CODE, READONLY, ALIGN=2
	  
ADC_QUICK_ADD 
		EXPORT	ADC_QUICK_ADD
		PUSH 	{R4,R5}
		
		MOVS    r3, #0x00  ;累加计数器	
		MOVS	r4, #0x00  ;偏移计数器
LOOP_ADD
		LDRH	r5,[r0,r4] ;r5数据暂存
		ADD		r3,r3,r5
		ADD		r4,r4,r2
		SUBS 	r1,#1  ;R1--   nums--
		BGT LOOP_ADD
		
		MOVS    r0, r3
		
		POP 	{R4,R5}
		
		BX lr		  
	  
	  
	  
	  
	  
  END		  
	  