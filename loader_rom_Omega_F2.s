; lz4.exe -9 --no-frame-crc <input_file> <output_file>

univ:
					.incbin "univ.bin"

					

					.include	"JAGUAR.INC"
			
					jmp		___loader___
					
fileindex:			dc.l	data_list		; 802006
					
___loader___:		lea		$3000,a7				; stack to memtop

					move.l	#$C00000, a5		; a5 = HPI write address, read data
					move.w	#$4003, (a5)		; set 6MB mode
					move.w	#$4BA0, (a5)		; Select bank 0
					
					move.w	#$2700,sr
					move.w	#$7fff,$f0004e				; no VI
					; OLP
					move.l	#$00000000,$800
					move.l	#$00000004,$804
					move.l	#$08000000,d0
					move.l	d0,OLP
		
					moveq	#0,d0
					move.l	d0,$f00000+$1a148			; L_I2S
					move.l	d0,$f00000+$1a14c			; R_I2S
					move.l	d0,$f00000+$2114			; G_CTRL 
					move.l	d0,$f00000+$1a114			; D_CTRL
					move.l	d0,$f00000+$2100			; G_FLAGS
					move.l	d0,$f00000+$1a100			; D_FLAGS

					move.l	#$00070007,$f00000+$1a10c	; D_END
					move.l	#$00070007,$f00000+$210c	; G_END
	
					move.l	#0,D_DIVCTRL	
					lea		local_rte(pc),a0
					move.l	a0,LEVEL0
					

					move.w	#491,VI
					;lea		$3000,a7					; stack 
					
					lea     GPU_START,a3      			; start of GPU code
					lea		$f03080,a4
					move.l	#(4096-$80/4)-1,d7
.gpuup:			
					move.l	(a3)+,(a4)+
					dbra	d7,.gpuup

					move.l	#$00000000,$800.w
					move.l	#$00000004,$804.w
					move.l	#GPU_Loader_Shutdown,a0
					bsr.s	go_GPU					

					lea		local_rte(pc),a0
					move.l	a0,LEVEL0
				
					move.w	#$1,INT1
					and.w   #$f8ff,sr

					move.l	#0,D_CTRL						; Stop DSP
					move.l	#0,D_FLAGS

;; put your copy loop here
;;	
;;
;;
					lea		$802006,a4
					move.l	(a4),a4
					move.l	(a4)+,a0			; source = first file
					move.l	(a4)+,a2			; source end = following file

					lea		$4000,a1
boucle_copie_4000:
					move.l	(a0)+,(a1)+
					cmp.l	a2,a0
					blt.s	boucle_copie_4000

					move.w	#$ffff,VI
					move.w	#$2000,sr
	
;; put your run address here
;;
;;
;;

					jmp		$4000

local_rte:			move.w  #$101,INT1              	; Signal we're done
					move.w  #$0,INT2
					rte

go_GPU:				move.l	d0,-(a7)
					moveq	#0,d0
					move.l	d0,G_CTRL				; HALT the GPU
					nop
					nop
					nop
					nop
					move.l	a0,G_PC
					move.l  #GPUGO,G_CTRL           ; Start GPU
.wait4flash:    	move.l  G_CTRL,d0               ; Wait for complete
					andi.l  #$1,d0
					bne.s   .wait4flash
					move.l	(a7)+,d0
					rts



					.phrase
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GPU_START:			.gpu
					.org	$f03080
		

GPU_Loader_Shutdown:
				moveq	#0,r0
				movei	#$08000000,r3	; pointer to list
				movei	#OLP,r4			
				movei	#$f02114,r5
				store	r3,(r4)			; update the OLP
				store	r0,(r5)			; stop the GPU
				nop
				nop
				
				.68000
				.phrase		
GPU_END:			


					.phrase
					
;; add pointers or data here
					
data_list:		
; core code =0
			dc.l		core_code,fin_core_code,0
; debut, fin, taille originale
; lsmusic =1
;			dc.l		music_module_music_data,fin_music_module_music_data, 13048 
; lsbank = 2
;			dc.l		music_module_sound_bank,fin_music_module_sound_bank, 87084
; tiles world 1 = 3
;			dc.l			tiles_world01,fin_tiles_world01, 512000
; tiles world 2 = 4
;			dc.l			tiles_background00,fin_tiles_background00,512000
; sprites = 5
;			dc.l			PNG_CRY_sprites, fin_PNG_CRY_sprites, 368640
			dc.l		data_list_FIN

	.long
core_code:									.incbin	"edz.bin"
fin_core_code:
;	.long
;music_module_music_data:					.incbin	"LSP/Jalaga/test2-4.lsmusic.lz4"
;fin_music_module_music_data:
;	.long
;music_module_sound_bank:					.incbin	"LSP/Jalaga/test2-4.lsbank.lz4"
;fin_music_module_sound_bank:
;	.long
;tiles_world01:
;											.incbin	"galaga_maps/World01.png_JAG_CRY.lz4"
;											;.incbin		"fondgris.png_JAG_CRY.lz4"
;
;fin_tiles_world01:
;	.long
;tiles_background00:
;
;											.incbin		"galaga_maps/Backgrd00.png_JAG_CRY.lz4"
;fin_tiles_background00:
;	.long
;
;PNG_CRY_sprites:
;			.incbin		"test23.png_JAG_CRY.lz4"
;fin_PNG_CRY_sprites:
;										
;	
	.long
data_list_FIN:
			

