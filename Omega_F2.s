; rebuild demo Omega 2 , Swedish New Year 89-90
;

; scrolling:
;	- pointeur en cours sur texte 
;	- inserer 4 pixels par 4 pixels
;	- GPU_scrolling_offset_actuel_dans_la_lettre ( 0,4,8,12 ) / boucle à 16
;	- pointeur sur lettre en cours : GPU_scrolling_pointeur_sur_lettre_en_cours

; - gerer les 2 couleurs : avoir un paramètre de couleur

; logo :
; OK - init : copier chaque logo avec une ligne vide avant : chaque ligne fait ensuite 640 octets
; OK - init : multiplier la "table des lignes pour zoom Y" par 640
; OK - init : multiplier la "table waves en Y du logo" par 320 ( s'applique à la destination ) 
; OK - init : convertir table_2_positions_en_X : diviser par 320, multipler par 640, ajouter le reste de la division


; OK - switcher les pointeurs sur les buffers de zone d'affichage du logo
; OK - creer un sprite dans l'OL en 256 couleurs pour la zone de logo en cours
; OK - recalculer les entrées de la table 1 = commandes 
; OK - gestion des commandes à chaque frame
; - blitter pour effacer la zone du logo en cours
; OK - gestion des pointeurs à chaque frame
; OK - gestion deplacement horizontal 
; - voir si espace necessaire entre les 2 logos etendus

; scrolling:
; - switcher les pointeurs sur les buffers de zone d'affichage du scrolling
; - creer un sprite dans l'OL en 256 couleurs pour la zone de scrolling en cours

;;------------------
; OL+48 = debut des sprites
; phrase = 8 octets
;



	include	"jaguar.inc"

NUMERO_DE_MUSIQUE			.equ		1

premiere_ligne_a_l_ecran	.equ		49
CLS_BLITTER					.equ		1

nb_actuel_de_couleurs		.equ		48

DEBUG_LOGO					.equ		0					; 1 = freeze le logo

; l'original saute 2 lignes en haut du logo
decalage_debut_utilisation_logo		.equ		640*2


; ------------------
GPU_STACK_SIZE	equ		32	; long words
GPU_USP			equ		(G_ENDRAM-(4*GPU_STACK_SIZE))
GPU_ISP			equ		(GPU_USP-(4*GPU_STACK_SIZE))

ob_list_courante			equ		((ENDRAM-$4000)+$2000)				; address of read list
nb_octets_par_ligne			equ		640

ob_list_1				equ		(ENDRAM-52000)				; address of read list =  
ob_list_2				equ		(ENDRAM-104000)				; address of read list =  


;--------------------
; STEREO
STEREO									.equ			0			; 0=mono / 1=stereo
STEREO_shit_bits						.equ			4
; stereo weights : 0 to 16
YM_DSP_Voie_A_pourcentage_Gauche		.equ			14
YM_DSP_Voie_A_pourcentage_Droite		.equ			2
YM_DSP_Voie_B_pourcentage_Gauche		.equ			10
YM_DSP_Voie_B_pourcentage_Droite		.equ			6
YM_DSP_Voie_C_pourcentage_Gauche		.equ			6
YM_DSP_Voie_C_pourcentage_Droite		.equ			10
YM_DSP_Voie_D_pourcentage_Gauche		.equ			2
YM_DSP_Voie_D_pourcentage_Droite		.equ			14


; algo de la routine qui genere les samples
; 3 canaux : increment onde carrée * 3 , increment noise, volume voie * 3 , increment enveloppe

DSP_DEBUG			.equ			0
DSP_DEBUG_T1		.equ			0
DSP_DEBUG_BUZZER	.equ			0									; 0=Buzzer ON / 1=pas de gestion du buzzer
I2S_during_Timer1	.equ			0									; 0= I2S waits while timer 1 / 1=IMASK cleared while Timer 1
YM_avancer			.equ			1									; 0=on avance pas / 1=on avance
YM_position_debut_dans_musique		.equ		0
YM_Samples_SID_en_RAM_DSP			.equ		1						; 0 = samples SID en RAM 68000 / 1 = samples SID en RAM DSP.
DSP_random_Noise_generator_method	.equ		4						; algo to generate noise random number : 1 & 4 (LFSR) OK uniquement // 2 & 3 : KO
VBLCOUNTER_ON_DSP_TIMER1			.equ		0						; 0=vbl counter in VI interrupt CPU / 1=vbl counter in Timer 1


	
DSP_Audio_frequence					.equ			36000				; real hardware needs lower sample frequencies than emulators !
YM_frequence_YM2149					.equ			2000000				; 2 000 000 = Atari ST , 1 000 000 Hz = Amstrad CPC, 1 773 400 Hz = ZX spectrum 
YM_DSP_frequence_MFP				.equ			2457600
YM_DSP_precision_virgule_digidrums	.equ			11
YM_DSP_precision_virgule_SID		.equ			16
YM_DSP_precision_virgule_envbuzzer	.equ			16


DSP_STACK_SIZE	equ	32	; long words
DSP_USP			equ		(D_ENDRAM-(4*DSP_STACK_SIZE))
DSP_ISP			equ		(DSP_USP-(4*DSP_STACK_SIZE))


.opt "~Oall"

.text

			.68000


	move.l		#$70007,G_END
	move.l		#$70007,D_END
	

	move.l		#INITSTACK-128, sp	
	move.w		#%0000011011000111, VMODE			; 320x256 / RGB / pwidth = 011 = 3 320x256

	;move.w		#%0000010011000111, VMODE			; 320x256 / RGB / pwidth = 01 = 2 => ca divise par 3 :  320x256
	;move.w		#%0000011011000001, VMODE			; 320x256 / CRY / $6C7
	
	
	move.w		#$100,JOYSTICK
	
; clear BSS
	lea			DEBUT_BSS,a0
	lea			FIN_RAM,a1
	moveq		#0,d0
	
boucle_clean_BSS:
	move.b		d0,(a0)+
	cmp.l		a0,a1
	bne.s		boucle_clean_BSS
; clear stack
	lea			INITSTACK-100,a0
	lea			INITSTACK,a1
	moveq		#0,d0
	
boucle_clean_BSS2:
	move.b		d0,(a0)+
	cmp.l		a0,a1
	bne.s		boucle_clean_BSS2

; copie du code GPU
	move.l	#0,G_CTRL
; copie du code GPU dans la RAM GPU

	lea		GPU_debut,A0
	lea		G_RAM,A1
	move.l	#GPU_fin-GPU_base_memoire,d0
	lsr.l	#2,d0
	sub.l	#1,D0
boucle_copie_bloc_GPU:
	move.l	(A0)+,(A1)+
	dbf		D0,boucle_copie_bloc_GPU


; ------------------------
; debut DSP
	move.l	#0,D_CTRL

; copie du code DSP dans la RAM DSP

	lea		YM_DSP_debut,A0
	lea		D_RAM,A1
	move.l	#YM_DSP_fin-DSP_base_memoire,d0
	lsr.l	#2,d0
	sub.l	#1,D0
boucle_copie_bloc_DSP:
	move.l	(A0)+,(A1)+
	dbf		D0,boucle_copie_bloc_DSP


    bsr   		  InitVideo               	; Setup our video registers.

;check ntsc ou pal:

	moveq		#0,d0
	move.w		JOYBUTS ,d0

	move.l		#26593900,frequence_Video_Clock			; PAL
	move.l		#415530,frequence_Video_Clock_divisee

	
	btst		#4,d0
	beq.s		jesuisenpal
jesuisenntsc:
	move.l		#26590906,frequence_Video_Clock			; NTSC
	move.l		#415483,frequence_Video_Clock_divisee
jesuisenpal:





; creer les object listes
	lea		ob_list_1,a6
	bsr		preparation_OL
	lea		ob_list_2,a6
	bsr		preparation_OL



	move.w		#801,VI			; stop VI


; init CLUT

	lea			CLUT+2,a1
	lea			CLUT_RGB,a0
	move.w		#nb_actuel_de_couleurs-1,d0
copie_clut:
	move.w		(a0)+,(a1)+
	dbf			d0,copie_clut


; init DSP
; $40FC
	; set timers
	move.l		#DSP_Audio_frequence,d0
	move.l		frequence_Video_Clock_divisee,d1
	lsl.l		#8,d1
	divu		d0,d1
	and.l		#$ffff,d1
	add.l		#128,d1			; +0.5 pour arrondir
	lsr.l		#8,d1
	subq.l		#1,d1
	move.l		d1,DSP_parametre_de_frequence_I2S

;calcul inverse
 	addq.l	#1,d1
	add.l	d1,d1		; * 2 
	add.l	d1,d1		; * 2 
	lsl.l	#4,d1		; * 16
	move.l	frequence_Video_Clock,d0
	divu	d1,d0			; 26593900 / ( (16*2*2*(+1))
	and.l		#$ffff,d0
	move.l	d0,DSP_frequence_de_replay_reelle_I2S


; init coso
; ------------- numero de musique
	MOVEQ	#NUMERO_DE_MUSIQUE,D0
	lea		fichier_coso_depacked,a0
	bsr		INITMUSIC

; apres copie on init le YM Coso
	bsr			YM_init_coso

; init tables logo
	nop
	bsr		init_tables_logo_Omega_F2
	nop
	bsr		init_tables_scrolling
	bsr		convert_fonte_scrolling

; launch GPU

	move.l	#REGPAGE,G_FLAGS
	move.l	#GPU_init,G_PC
	move.l  #RISCGO,G_CTRL	; START GPU

; launch DSP
	move.l	#REGPAGE,D_FLAGS
	move.l	#DSP_routine_init_DSP,D_PC
	move.l	#DSPGO,D_CTRL
	move.l	#0,vbl_counter_replay_DSP
	move.l	#0,vbl_counter


    ;bsr     copy_olist              	; use Blitter to update active list from shadow

	;move.l	#ob_list_courante,d0					; set the object list pointer
	;swap	d0
	;move.l	d0,OLP


	.if		1=0
	move.l  #VBL,LEVEL0     	; Install 68K LEVEL0 handler
	move.w  a_vde,d0                	; Must be ODD
	sub.w   #16,d0
	ori.w   #1,d0
	move.w  d0,VI

	move.w  #%01,INT1                 	; Enable video interrupts 11101


	and.w   #%1111100011111111,sr				; 1111100011111111 => bits 8/9/10 = 0
	and.w   #$f8ff,sr
	.endif


	.if		1=0
; test, motif sur zones de scrolling
	lea		zone_scrolling_1+50,a1
	lea		zone_scrolling_2+50,a2
	move.w	#50,d0
	moveq	#1,d1
	moveq	#2,d2

fill_test_motif:
	move.b	d1,(a1)
	move.b	d2,(a2)
	lea		320(a1),a1
	lea		320(a2),a2
	dbf		d0,fill_test_motif
	.endif



main:
	move.l		DSP_flag_registres_YM_lus,d0
	cmp.l		#0,d0
	beq.s		main
	move.l		#0,DSP_flag_registres_YM_lus
	
	
	bsr		PLAYMUSIC

	lea		YM_registres_Coso,a6
	moveq		#0,d0
	move.b		8(a6),d0
	move.l		d0,GPU_volume_A
	move.b		9(a6),d0
	move.l		d0,GPU_volume_B
	move.b		10(a6),d0
	move.l		d0,GPU_volume_C


	bra.s		main



;--------------------------
; VBL

VBL:
                movem.l d0-d7/a0-a6,-(a7)
				

                ;bsr     copy_olist              	; use Blitter to update active list from shadow

                addq.l	#1,vbl_counter

                ;move.w  #$101,INT1              	; Signal we're done
				move.w	#$101,INT1
                move.w  #$0,INT2
.exit:
                movem.l (a7)+,d0-d7/a0-a6
                rte


				.if		1=0
;----------------------------------
; recopie l'object list dans la courante

copy_olist:
				move.l	#ob_list_courante,A1_BASE			; = DEST
				move.l	#$0,A1_PIXEL
				move.l	#PIXEL16|XADDPHR|PITCH1,A1_FLAGS
				move.l	#ob_liste_originale,A2_BASE			; = source
				move.l	#$0,A2_PIXEL
				move.l	#PIXEL16|XADDPHR|PITCH1,A2_FLAGS
				move.w	#1,d0
				swap	d0
				move.l	#fin_ob_liste_originale-ob_liste_originale,d1
				move.w	d1,d0
				move.l	d0,B_COUNT
				move.l	#LFU_REPLACE|SRCEN,B_CMD
				rts
				.endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Procedure: InitVideo (same as in vidinit.s)
;;            Build values for hdb, hde, vdb, and vde and store them.
;;

largeur_bande_gauche		.equ		24+8+4+12+2		; 24
largeur_bande_droite		.equ		24	; 4*4

InitVideo:
                movem.l d0-d6,-(sp)

				
				move.w	#-1,ntsc_flag
				move.l	#50,_50ou60hertz
	
				move.w  CONFIG,d0                ; Also is joystick register
                andi.w  #VIDTYPE,d0              ; 0 = PAL, 1 = NTSC
                beq.s     .palvals
				move.w	#1,ntsc_flag
				move.l	#60,_50ou60hertz
	

.ntscvals:		move.w  #NTSC_HMID,d2
                move.w  #NTSC_WIDTH,d0

                move.w  #NTSC_VMID,d6
                move.w  #NTSC_HEIGHT,d4
				
                bra.s    calc_vals
.palvals:
				move.w #PAL_HMID,d2
				move.w #PAL_WIDTH,d0

				move.w #PAL_VMID,d6				
				move.w #PAL_HEIGHT,d4

				
calc_vals:		
                move.w  d0,width
                move.w  d4,height
                move.w  d0,d1
                asr     #1,d1                   ; Width/2
                sub.w   d1,d2                   ; Mid - Width/2
                add.w   #4,d2                   ; (Mid - Width/2)+4
				
				sub.w	#largeur_bande_gauche,d2
				
                sub.w   #1,d1                   ; Width/2 - 1
				
				add.w	#largeur_bande_droite,d1
                
				
				ori.w   #$400,d1                ; (Width/2 - 1)|$400  : 
				
				
				
                move.w  d1,a_hde
                move.w  d1,HDE
				;add.w	#2,d1
				;move.w	d1,HBB
				
                move.w  d2,a_hdb
                move.w  d2,HDB1
                move.w  d2,HDB2
                move.w  d6,d5
                sub.w   d4,d5
                add.w   #16,d5
                move.w  d5,a_vdb
                add.w   d4,d6
                move.w  d6,a_vde
			
			    move.w  a_vdb,VDB
				move.w  a_vde,VDE    

		moveq	#0,d0
		move.w	a_vdb,d0
		addq.l	#1,d0
		move.l	d0,GPU_premiere_ligne				; $24 en pal => 36 / ntsc : 26 / $1a

		moveq	#0,d0
		move.w	a_vde,d0
		addq.l	#1,d0
		subq.l	#2,d0
		move.l	d0,GPU_derniere_ligne				; $262 en pal => 305 / ntsc : $1FC / 508 => 254
		
		;move.w		#$6b1,HBB
		;move.w		#$7d,HBE
	
		;move.w		#$A0,HDB1
		;move.w		#$A0,HDB2
		;move.w		#$6BF,HDE
	
		
; force ntsc pour pal
		;move.l	#premiere_ligne_a_l_ecran,GPU_premiere_ligne
		;move.l	#(200+premiere_ligne_a_l_ecran)*2,GPU_derniere_ligne			; 508/2=254 ; 254-13=241
		;move.l	#60,_50ou60hertz	

		move.l  #0,BORD1                ; Black border
        move.w  #0,BG                   ; Init line buffer to black

			
		cmp.w	#60,_50ou60hertz
		bne.s	initivdeo_pal_edz
			
		move.l	#26+40,GPU_premiere_ligne
		move.l	#508-42,GPU_derniere_ligne
		
				
                movem.l (sp)+,d0-d6
                rts

initivdeo_pal_edz:
		move.l	#26+40+16,GPU_premiere_ligne
		move.l	#508-42+16,GPU_derniere_ligne

                movem.l (sp)+,d0-d6
                rts


;-----------------------------------------------------------------------------------
; preparation de l'Objects list
;   Condition codes (CC):
;
;       Values     Comparison/Branch
;     --------------------------------------------------
;        000       Branch on equal            (VCnt==VC)
;        001       Branch on less than        (VCnt>VC)
;        010       Branch on greater than     (VCnt<VC)
;        011       Branch if OP flag is set
; input A6=adresse object list 
preparation_OL:
	move.l	a6,a1

;
; ============== insertion de Branch if YPOS < 0 a X+16

	move.l		#$00000003,d0					; branch
	or.l		#%0100000000000000,d0			; <
	move.l		GPU_premiere_ligne,d3
	;add.l		d3,d3							; *2 : half line
	lsl.l		#3,d3
	or.l		d3,d0							; Ymax	

	move.l		a1,d1
	add.l		#16,d1
	lsr.l		#3,d1							
	move.l		d1,d2
	lsl.l		#8,d1							; <<24 : 8 bits
	lsl.l		#8,d1
	lsl.l		#8,d1
	or.l		d1,d0
	lsr.l		#8,d2
	move.l		d2,(a1)+
	move.l		d0,(a1)+

; ============== insertion de Branch if YPOS < Ymax+1 à X+16

	move.l		#$00000003,d0					; branch
	or.l		#%0100000000000000,d0			; <
	;move.l		#derniere_ligne,d3
	;add.l		d3,d3							; *2 : half line
	;moveq		#0,d3
	move.l		GPU_derniere_ligne,d3
	;add.l		d3,d3							; *2 : half line
	add.l		#1,d3							; integre ligne gpu inteerupt
	lsl.l		#3,d3
	or.l		d3,d0							; Ymax	
	move.l		a1,d1
	add.l		#16,d1
	lsr.l		#3,d1							
	move.l		d1,d2
	lsl.l		#8,d1							; <<24 : 8 bits
	lsl.l		#8,d1
	lsl.l		#8,d1
	or.l		d1,d0
	lsr.l		#8,d2
	move.l		d2,(a1)+
	move.l		d0,(a1)+

; ============== insertion de STOP
	moveq		#0,d0
	move.l		d0,(a1)+
	move.l		#4,d0
	move.l		d0,(a1)+

; ============== insertion de Branch if YPOS < Ymax à X+16

	move.l		#$00000003,d0					; branch
	or.l		#%0100000000000000,d0			; <
	;move.l		#derniere_ligne,d3
	;add.l		d3,d3							; *2 : half line
	;moveq		#0,d3
	move.l		GPU_derniere_ligne,d3
	;add.l		d3,d3							; *2 : half line
	lsl.l		#3,d3
	or.l		d3,d0							; Ymax	
	move.l		a1,d1
	add.l		#16+8,d1						; branch+gpu interrupt+stop
	lsr.l		#3,d1							
	move.l		d1,d2
	lsl.l		#8,d1							; <<24 : 8 bits
	lsl.l		#8,d1
	lsl.l		#8,d1
	or.l		d1,d0
	lsr.l		#8,d2
	move.l		d2,(a1)+
	move.l		d0,(a1)+

; insertion GPU object
	moveq		#0,d0
	move.l		d0,(a1)+
	move.l		#$3FFA,d0				; $3FFA
	move.l		d0,(a1)+
	
; insertion de STOP
	moveq		#0,d0
	move.l		d0,(a1)+
	move.l		#4,d0
	move.l		d0,(a1)+

; A1 = debut bitmap = OL+48



; insertion de STOP
	moveq		#0,d0
	move.l		d0,(a1)+
	move.l		#4,d0
	move.l		d0,(a1)+
; insertion de STOP
	moveq		#0,d0
	move.l		d0,(a1)+
	move.l		#4,d0
	move.l		d0,(a1)+

; insertion de STOP
	moveq		#0,d0
	move.l		d0,(a1)+
	move.l		#4,d0
	move.l		d0,(a1)+


; insertion de STOP
	moveq		#0,d0
	move.l		d0,(a2)+
	move.l		#4,d0
	move.l		d0,(a2)+

	rts


; copie du logo en décalé
init_tables_logo_Omega_F2__copie_logo:
; A0 = source
; A1 = dest
	move.l	#66*640,d1
	move.l	a0,a2
	add.l	d1,a2

init_tables_logo_Omega_F2__copie_logo__boucle:
	move.b	(a0)+,(a1)+
	cmp.l	a2,a0
	bne.s	init_tables_logo_Omega_F2__copie_logo__boucle
	rts
	


;-------------------------------------
;	routines gestion du logo
;-------------------------------------
; - init : copier chaque logo avec une ligne vide avant : chaque ligne fait ensuite 640 octets
; - init : multiplier la "table des lignes pour zoom Y" par 640
; - init : multiplier la "table waves en Y du logo" par 320 ( s'applique à la destination ) 
init_tables_logo_Omega_F2:


; ajout d'espace avant chaque ligne du logo ATARI
; 66 lignes *2 
	lea		logo_ATARI,a0
	lea		buffer_logos_predecales_ATARI_0,a1
	move.w	#66-1,d2						; 66 lignes

; insertion 320 octets vide a gauche
init_tables_logo_atari_F2__boucle_une_ligne:	
	move.w	#(320/4)-1,d1
	moveq	#0,d0
init_tables_logo_atari_F2__ajoute_espace_debut_ligne:	
	move.l	d0,(a1)+
	dbf		d1,init_tables_logo_atari_F2__ajoute_espace_debut_ligne
; copie des octets du graph
	move.w	#(320/4)-1,d1
init_tables_logo_atari_F2__copie_ligne_logo:
	move.l	(a0)+,(a1)+
	dbf		d1,init_tables_logo_atari_F2__copie_ligne_logo
	dbf		d2,init_tables_logo_atari_F2__boucle_une_ligne


; copie de predecalage 0 dans predecalage 1
	lea		buffer_logos_predecales_ATARI_0,a0
	lea		buffer_logos_predecales_ATARI_1+1,a1
	bsr		init_tables_logo_Omega_F2__copie_logo
; copie de predecalage 0 dans predecalage 2
	lea		buffer_logos_predecales_ATARI_0,a0
	lea		buffer_logos_predecales_ATARI_2+2,a1
	bsr		init_tables_logo_Omega_F2__copie_logo
; copie de predecalage 0 dans predecalage 3
	lea		buffer_logos_predecales_ATARI_0,a0
	lea		buffer_logos_predecales_ATARI_3+3,a1
	bsr		init_tables_logo_Omega_F2__copie_logo



; ----------- logo OMEGA
; ajout d'espace avant chaque ligne du logo OMEGA
; 66 lignes *2 
	lea		logo_OMEGA,a0
	lea		buffer_logos_predecales_OMEGA_0,a1
	move.w	#66-1,d2						; 66 lignes

; insertion 320 octets vide a gauche
init_tables_logo_Omega_F2__boucle_une_ligne:	
	move.w	#(320/4)-1,d1
	moveq	#0,d0
init_tables_logo_Omega_F2__ajoute_espace_debut_ligne:	
	move.l	d0,(a1)+
	dbf		d1,init_tables_logo_Omega_F2__ajoute_espace_debut_ligne
; copie des octets du graph
	move.w	#(320/4)-1,d1
init_tables_logo_Omega_F2__copie_ligne_logo:
	move.l	(a0)+,(a1)+
	dbf		d1,init_tables_logo_Omega_F2__copie_ligne_logo
	dbf		d2,init_tables_logo_Omega_F2__boucle_une_ligne


; copie de predecalage 0 dans predecalage 1
	lea		buffer_logos_predecales_OMEGA_0,a0
	lea		buffer_logos_predecales_OMEGA_1+1,a1
	bsr		init_tables_logo_Omega_F2__copie_logo
; copie de predecalage 0 dans predecalage 2
	lea		buffer_logos_predecales_OMEGA_0,a0
	lea		buffer_logos_predecales_OMEGA_2+2,a1
	bsr		init_tables_logo_Omega_F2__copie_logo
; copie de predecalage 0 dans predecalage 3
	lea		buffer_logos_predecales_OMEGA_0,a0
	lea		buffer_logos_predecales_OMEGA_3+3,a1
	bsr		init_tables_logo_Omega_F2__copie_logo



	
	

; multiplier table_4_lignes_pour_zoom_Y par 640 ( source)
; la table est deja multipliée par 160*2=320
; maxi final = 640*66 = 42240
	lea		table_4_lignes_pour_zoom_Y,a0
	lea		FIN_table_4_lignes_pour_zoom_Y,a1
init_tables_logo_Omega_F2__double_index_ligne_zoom_Y:
	moveq	#0,d0
	move.w	(a0),d0
	add.w	d0,d0
	move.w	d0,(a0)+
	cmp.l	a1,a0
	blt.s	init_tables_logo_Omega_F2__double_index_ligne_zoom_Y

; multiplier table_5_waves_en_Y par 320 ( destination )
	lea		table_5_waves_en_Y,a0
	lea		FIN_table_5_waves_en_Y,a1
	
init_tables_logo_Omega_F2__multiplie_par_320_wave_Y:
	moveq	#0,d0
	move.w	(a0),d0
	mulu	#320,d0
	move.w	d0,(a0)+
	cmp.l	a1,a0
	blt.s	init_tables_logo_Omega_F2__multiplie_par_320_wave_Y

; inutile, ce sont des X, pas des offsets mémoire
	.if		1=0
; convertir table_2_positions_en_X : diviser par 320, multipler par 640, ajouter le reste de la division
	lea		table_2_positions_en_X,a0
	lea		FIN_table_2_positions_en_X,a1

init_tables_logo_Omega_F2__table2:
	moveq	#0,d0
	move.w	(a0),d0
	move.l	d0,d1
	divu	#320,d0				; reste.w quotient.w
	move.l	d0,d2
	ext.l	d0					; D0 = quotient .L
	swap	d2
	ext.l	d2					; D2 = reste .L
	mulu	#640,d0
	add.l	d2,d0
	move.w	d0,(a0)+
	cmp.l	a1,a0
	blt.s	init_tables_logo_Omega_F2__table2
	.endif
	
	rts


;-------------------------------------
; init table Y scrolling : multiplie par 320
init_tables_scrolling:

	lea		table_Y_scrolling,a0
	lea		FIN_table_Y_scrolling,a3
	move.l	a0,a1
init_tables_scrolling__boucle:
	move.w	(a0)+,d1
	ext.l	d1
	mulu	#320,d1
	move.w	d1,(a1)+
	cmp.l	a0,a3
	bne.s	init_tables_scrolling__boucle
	rts
	
;-------------------------------------
; conversion de la fonte en 256 couleurs	
; 38 caracteres * 13 lignes * 16 pixels
convert_fonte_scrolling:
	lea		fonte_originale,a0
	lea		fonte_256_couleurs,a1
	move.w	#38-1,d7							; 38 caracteres
convert_fonte_scrolling__boucle_caractere:
	move.w	#13-1,d6							; 13 lignes
convert_fonte_scrolling__boucle_ligne:	
	move.w	#16-1,d5							; 16 pixels
	move.l	#15,d4							; mask pour selectionner le pixel
convert_fonte_scrolling__boucle_16_pixels:
	move.w	6(a0),d0							; plan 3
	lsr.w	d4,d0
	add.w	d0,d0								; <<1
	move.w	4(a0),d1							; plan 2
	lsr.w	d4,d1
	or.w	d1,d0
	add.w	d0,d0								; <<1
	move.w	2(a0),d1							; plan 1
	lsr.w	d4,d1
	or.w	d1,d0
	add.w	d0,d0								; <<1
	move.w	(a0),d1								; plan 0
	lsr.w	d4,d1
	or.w	d1,d0
; d0 = numéro couleur
	move.b	d0,(a1)+
	subq.l	#1,d4
	dbf		d5,convert_fonte_scrolling__boucle_16_pixels
	lea		8(a0),a0
	dbf		d6,convert_fonte_scrolling__boucle_16_pixels
	dbf		d7,convert_fonte_scrolling__boucle_caractere
	rts

	
;-------------------------------------
;
;     COSO
;
;-------------------------------------
;----------------------------------------------------
YM_init_coso:
; tout le long de l'init D6=YM_nb_registres_par_frame



	moveq		#50,d0
	move.l		d0,YM_frequence_replay							; .w=frequence du replay ( 50 hz )


	rts



TIMER=0		;0=TIMER A,1=TIMER B,2=TIMER C,3=TIMER D
EQUALISEUR=1	;0=EQUALISEUR

TYPE=1			;1=MUSIQUE NORMALE,2=MUSIQUE DIGIT
PRG=0			;0=PRG,1=REPLAY BINAIRE
MONOCHROM=1		;0=REPLAY MONOCHROME,1=REPLAY COULEUR
PCRELATIF=1		;0=DIGIT PRES DU REPLAY,1=DIGIT LOIN DU REPLAY
AEI=0			;0=REPLAY MODE AEI,1=MODE SEI

CUTMUS=0		;0=INCLUT FIN MUSIQUE,1=ON NE PEUT COUPER LA MUSIQUE
DIGIT=1			;0=INCLUT REPLAY DIGIT,1=SANS
MMME=1			;0=INCLUT REPLAY MMME,1=SANS

TURRICAN=0		;0=REPLAY TURRICAN
OLD=1			;0=ANCIENNE VERSION,1=NOUVELLE



off22	equ		0					; rs.l	1	;ptr courant dans pattern								4
off0	equ		4					; rs.l	1	;ptr base patterns										4
off34	equ		8					; rs.w	1	;ptr fin musique										2

off4	equ		10					; rs.w	1	;ptr patterns (.W au lieu de .L)						2
offa	equ		12					; rs.l	1	;ptr base modulation volume								4
offe	equ		16					; rs.w	1	;ptr modulation volume (.W au lieu de .L)				2
off12	equ		18					; rs.l	1	;ptr base modulation fr‚quence							4
off30	equ		22					; rs.w	1	;ptr modulation fr‚quence (.W au lieu de .L)			2

off38	equ		24					; rs.l	1	;incr‚ment pour crescendo					4

off8	equ		28					; rs.b	1	;											1
off9	equ		29					; rs.b	1	;											1

off16	equ		30					; rs.b	1	;											1
off17	equ		31					; rs.b	1	;											1
off18	equ		32					; rs.b	1	;											1
off19	equ		33					; rs.b	1	;											1
off1a	equ		34					; rs.b	1	;											1
off1b	equ		35					; rs.b	1	;											1
off1c	equ		36					; rs.b	1	;											1
off1d	equ		37					; rs.b	1	;											1
off1e	equ		38					; rs.b	1	;											1
off1f	equ		39					; rs.b	1	;											1
off21	equ		40					; rs.b	1	;											1

off26	equ		41					; rs.b	1	;											1
off27	equ		42					; rs.b	1	;											1
off28	equ		43					; rs.b	1	;15-volume sonore de la voix				1
off2a	equ		44					; rs.b	1	;0,1 ou 2=type de son						1
off2b	equ		45					; rs.b	1	;											1
off2c	equ		46					; rs.b	1	;											1
off2d	equ		47					; rs.b	1	;volume sonore calculé						1
off2e	equ		48					; rs.b	1	;											1
;off3c	equ		47
off3c	equ		50

coso_envoi_registres:
	MOVEM.L			A0-A1,-(A7)
	LEA.L			PSGREG+2,A0											; = c177be
	lea		 		YM_registres_Coso,A1
	MOVE.B			(A0),(A1)+					; 0
	MOVE.B			4(A0),(A1)+					; 1
	MOVE.B			8(A0),(A1)+					; 2 
	MOVE.B			12(A0),(A1)+				; 3
	MOVE.B			16(A0),(A1)+				; 4
	MOVE.B			20(A0),(A1)+				; 5
	MOVE.B			24(A0),(A1)+				; 6
	MOVE.B			28(A0),(A1)+				; 7
	MOVE.B			32(A0),(A1)+				; 8
	MOVE.B			36(A0),(A1)+				; 9
	MOVE.B			40(A0),(A1)+				; A
	MOVEM.L 		(A7)+,A0-A1
	RTS


PLAYMUSIC:
	LEA	PSGREG(PC),A6
	TST.B	BLOQUEMUS-PSGREG(A6)
	BNE.S	L25A

	move.b	#$C0,$1E(A6)		;pour que ‡a tienne...

	SUBQ.B	#1,L80E-PSGREG(A6)
	BNE.S	L180
	MOVE.B	L810-PSGREG(A6),L80E-PSGREG(A6)
	MOVEQ	#0,D5
	LEA	voice0(PC),A0
	BSR.W	L25C
	LEA	voice1(PC),A0
	BSR.W	L25C
	LEA	voice2(PC),A0
	BSR.W	L25C
L180:
	LEA	voice0(PC),A0
	BSR	L39A
	move	d0,6(A6)
	MOVE.B	D0,2(A6)
	MOVE.B	D1,$22(A6)
	LEA	voice1(PC),A0
	BSR	L39A
	move	d0,$E(A6)
	MOVE.B	D0,$A(A6)
	MOVE.B	D1,$26(A6)
	LEA	voice2(PC),A0
	BSR	L39A
	move	D0,$16(A6)
	MOVE.B	D0,$12(A6)
	MOVE.B	D1,$2A(A6)

	;MOVEM.L	(A6),D0-D7/A0-A2
	;MOVEM.L	D0-D7/A0-A2,$FFFF8800.W
	bsr			coso_envoi_registres
L25A:	RTS

;
; calcule nouvelle note
;
L25C:	SUBQ.B	#1,off26(A0)
	BPL.S	L25A
	MOVE.B	off27(A0),off26(A0)
	MOVE.L	off22(A0),A1
L26C:	MOVE.B	(A1)+,D0
	CMP.B	#$FD,D0
	BLO.W	L308
	EXT	D0
	ADD	D0,D0
	JMP		COSO_CODEFD+(3*2)(PC,D0.W)
COSO_CODEFD:
	BRA.S	L2F4		;$FD
	BRA.S	L2E2		;$FE
				;$FF

; NOUVELLE VERSION
	move	off4(a0),d1
	cmp	off34(a0),d1
	blS.S	L288
	tst.b	off21(a0)		;nouveau replay !!!!
	bne.s	L288			;pour bien boucler !!!!
	clr	d1
	move	d5,off4+off3c(a0)
	move	d5,off4+(off3c*2)(a0)
L288:
	MOVE.L	off0(a0),a1
	add	d1,a1
	add	#$C,d1

	move	d1,off4(a0)

	MOVEQ	#0,D1
	move.b	(a1)+,D1
	move.b	(a1)+,off2c(A0)
	move.b	(a1)+,off16(A0)
	moveq	#$10,d0
	add.b	(a1)+,D0
	bcc.s	L2B4
	move.b	d0,off28(A0)		;F0-FF=volume … soustraire
	BRA.S	L2C4
L2B4:	add.b	#$10,d0
	bcc.S	L2C4
	move.B	d0,L810-PSGREG(A6)	;E0-EF=vitesse
L2C4:	ADD	D1,D1
	MOVE.L	L934(PC),A1
	ADD	$C+2(A1),D1
	ADD	(A1,D1.W),A1

	MOVE.L	A1,off22(A0)
	BRA.s	L26C

L2E2:
	MOVE.B	(A1)+,d0
	move.b	d0,off27(A0)
	MOVE.B	d0,off26(A0)
	BRA.s	L26C
L2F4:
	MOVE.B	(A1)+,d0
	move.b	d0,off27(A0)
	MOVE.B	d0,off26(A0)
	MOVE.L	A1,off22(A0)
	RTS

L308:	MOVE.B	D0,off8(a0)
	MOVE.B	(A1)+,D1
	MOVE.B	D1,off9(a0)
	AND	#$E0,D1			;d1=off9&$E0
	BEQ.S	.L31C
	MOVE.B	(A1)+,off1f(A0)
.L31C:	MOVE.L	A1,off22(A0)
	MOVE.L	D5,off38(A0)
	TST.B	D0
	BMI	L398
	MOVE.B	off9(a0),D0
	eor.b	d0,d1			;d1=off9&$1F
	ADD.B	off16(A0),D1

	MOVE.L	L934(PC),A1

	CMP	$26(A1),D1
	BLS.S	NOBUG2
;	CLR	D1
	move	$26(a1),d1
	move	#$700,$ffff8240.w
NOBUG2:
	ADD	D1,D1
	ADD	8+2(A1),D1
	ADD	(A1,D1.W),A1

	move	d5,offe(A0)
	MOVE.B	(a1)+,d1
	move.b	d1,off17(A0)
	MOVE.B	d1,off18(A0)
	MOVEQ	#0,D1
	MOVE.B	(a1)+,D1
	MOVE.B	(a1)+,off1b(A0)
;	MOVE.B	#$40,off2e(A0)
	clr.b	off2e(a0)
	MOVE.B	(a1)+,D2
	MOVE.B	D2,off1c(A0)
	MOVE.B	D2,off1d(A0)
	MOVE.B	(a1)+,off1e(A0)
	MOVE.L	a1,offa(A0)
	add.b	d0,d0			;test bit 6
	bpl.s	L37A
	MOVE.B	off1f(A0),D1
L37A:
	MOVE.L	L934(PC),A1
	CMP	$24(A1),D1
	BLS.S	NOBUG3
	move	$24(a1),d1
	move	#$070,$ffff8240.w
;	CLR	D1
NOBUG3:
	ADD	D1,D1

	ADD	4+2(A1),D1
	ADD	(A1,D1.W),A1

	MOVE.L	a1,off12(A0)
	move	d5,off30(A0)
	MOVE.B	D5,off1a(A0)
	MOVE.B	D5,off19(A0)
L398:	RTS

;
; calcul de la note … jouer
;
L39A:	MOVEQ	#0,D7
	MOVE	off30(a0),d6
L3A0:	TST.B	off1a(A0)
	BEQ.S	L3AE
	SUBQ.B	#1,off1a(A0)
	BRA	L4C01
L3AE:	MOVE.L	off12(A0),A1
	add	d6,a1
L3B6:	move.b	(a1)+,d0
	CMP.B	#$E0,D0
	BLO	L4B0
;	CMP.B	#$EA,D0		;inutile ???
;	BHS	L4B0

	EXT	D0
	ADD	#32,D0
	MOVE.B	COSO_CODES(PC,D0.W),D0
	JMP		BRANCH_COSO(PC,D0.W)

COSO_CODES:
	DC.B	E0-BRANCH_COSO
	DC.B	E1-BRANCH_COSO
	DC.B	E2-BRANCH_COSO
	DC.B	E3-BRANCH_COSO
	DC.B	E4-BRANCH_COSO
	DC.B	E5-BRANCH_COSO
	DC.B	E6-BRANCH_COSO
	DC.B	E7-BRANCH_COSO
	DC.B	E8-BRANCH_COSO
	DC.B	E9-BRANCH_COSO
	DC.B	EA-BRANCH_COSO
	EVEN
BRANCH_COSO:

BUG:	DCB.L	2,$4A780001
;	DCB.L	$100-$EA,$4A780001

E1:	BRA	L4C01
E0:
	moveq	#$3f,d6		;$E0
;clr d6 … pr‚sent !!!!
	and.B	(A1),D6
	BRA.S	L3AE
E2:
	clr	offe(a0)
	MOVE.B	#1,off17(A0)
	addq	#1,d6
	bra.s	L3B6

E9:
	;MOVE.B	#$B,$FFFF8800.W
	;move.b	(A1)+,$FFFF8802.W
	;move.l	#$0C0C0000,$FFFF8800.W
	;move.l	#$0D0D0A0A,$FFFF8800.W
	
	PEA			(A0)										; 00C0364E 4850                     PEA.L (A0)
	lea		 	YM_registres_Coso,A0			; 00C03650 207a 18fa                MOVEA.L (PC,$18fa) == $00c04f4c [00c0663e],A0
	MOVE.B 		(A1)+,$0B(A0)						; B=11				; 00C03654 1159 000b                MOVE.B (A1)+ [fd],(A0,$000b) == $00c051c9 [30]
	MOVE.B 		#$00,$0C(A0)					; C=12			; 00C03658 117c 0000 000c           MOVE.B #$00,(A0,$000c) == $00c051ca [3c]
	MOVE.B 		#$0a,$0D(A0)					; D=13			; 00C0365E 117c 000a 000d           MOVE.B #$0a,(A0,$000d) == $00c051cb [ac]
	MOVE.L 		(A7)+,A0									; 00C03664 205f                     MOVEA.L (A7)+ [00c0013e],A0
	
	addq	#2,d6
	bra.S	L3B6
E7:
	moveq	#0,d0
	move.b	(A1),D0
	ADD	D0,D0

	MOVE.L	L934(PC),A1
	ADD	4+2(A1),D0
	ADD	(A1,D0.W),A1

	MOVE.L	A1,off12(A0)
	clr	d6
	BRA	L3B6
EA:	move.b	#$20,off9(a0)
	move.b	(a1)+,off1f(a0)
	addq	#2,d6
	bra	L3B6
E8:	move.b	(A1)+,off1a(A0)
	addq	#2,d6
	BRA	L3A0

E4:	clr.b	off2a(A0)
	MOVE.B	(A1)+,d7
	addq	#2,d6
	BRA	L3B6		;4AE
E5:	MOVE.B	#1,off2a(A0)
	addq	#1,d6
	BRA	L3B6
E6:	MOVE.B	#2,off2a(A0)
	addq	#1,d6
	BRA	L3B6		;4AE

E3:	addq	#3,d6
	move.b	(A1)+,off1b(A0)
	move.b	(A1)+,off1c(A0)
	bra	L3B6		;nouveau

;L4AE:	move.b	(a1)+,d0
L4B0:
	MOVE.B	d0,off2b(A0)
	addq	#1,d6
L4C01:	move	d6,off30(a0)
;
; modulation volume
;
	move	offe(a0),d6
L4C0:	TST.B	off19(A0)
	BEQ.S	L4CC
	SUBQ.B	#1,off19(A0)
	BRA.S	L51A
L4CC:	SUBQ.B	#1,off17(A0)
	BNE.S	L51A
	MOVE.B	off18(A0),off17(A0)

	MOVE.L	offa(A0),A1
	add	d6,a1
	move.b	(A1)+,D0
	CMP.B	#$E0,D0
	BNE.S	L512
	moveq	#$3f,d6
; clr d6 … pr‚sent
	and.b	(A1),D6
	subq	#5,D6
	move.l	offa(a0),a1
	add	d6,a1
	move.b	(a1)+,d0
L512:
	CMP.B	#$E8,D0
	BNE.S	L4F4
	addq	#2,d6
	move.b	(A1)+,off19(A0)
	BRA.S	L4C0
L4F4:	CMP.B	#$E1,D0
	BEQ.S	L51A
	MOVE.B	d0,off2d(A0)
	addq	#1,d6
L51A:	move	d6,offe(a0)

	clr	d5
	MOVE.B	off2b(A0),D5
	BMI.S	L528
	ADD.B	off8(a0),D5
	ADD.B	off2c(A0),D5
L528:
	add.b	D5,D5
;	LEA	L94E(PC),A1
;	MOVE	(A1,d5.w),D0
	MOVE	L94E-PSGREG(A6,D5.W),D0

	move.b	off2a(A0),D1	;0,1 ou 2
	beq.S	L57E

	MOVE.B	off21(A0),D2
	ADDQ	#3,D2

	subq.b	#1,D1
	BNE.S	L578
	subq	#3,d2
	MOVE.B	off2b(A0),D7
	bclr	#7,d7
	bne.s	L578		;BMI impossible !!!
	add.b	off8(a0),d7
L578:

	BSET	D2,$1E(A6)
L57E:
	tst.b	d7
	BEQ.S	L594
	not.b	d7
	and.b	#$1F,D7
	MOVE.B	D7,$1A(A6)
L594:

	TST.B	off1e(A0)
	BEQ.S	L5A4
	SUBQ.B	#1,off1e(A0)
	BRA.S	L5FA
L5A4:
	clr	d2
	MOVE.B	off1c(A0),D2

;	bclr	#7,d2		;nouveau replay
;	beq.s	.ok		;BUG ????
;	add.b	d2,d2
;.ok

	clr	d1
	MOVE.B	off1d(A0),D1
	tst.b	off2e(a0)
	bmi.S	L5CE
	SUB.B	off1b(A0),D1
	BCC.S	L5DC
	tas	off2e(a0)	;ou bchg
	MOVEQ	#0,D1
	BRA.S	L5DC
L5CE:	ADD.B	off1b(A0),D1
	ADD.B	d2,d2
	CMP.B	d2,D1
	BCS.S	L5DA
	and.b	#$7f,off2e(a0)	;ou bchg
	MOVE.B	d2,D1
L5DA:	lsr.b	#1,d2
L5DC:	MOVE.B	D1,off1d(A0)
L5E0:
	sub	d2,D1

	ADD.B	#$A0,D5
	BCS.S	L5F8
	moveq	#$18,d2

	add	d1,d1
	add.b	d2,d5
	bcs.s	L5F8
	add	d1,d1
	add.b	d2,d5
	bcs.s	L5F8
	add	d1,d1
	add.b	d2,d5
	bcs.s	L5F8
	add	d1,d1
L5F8:	ADD	D1,D0
;;	EOR.B	#1,d6		;inutilis‚ !!!
;	MOVE.B	d6,off2e(A0)
L5FA:
	BTST	#5,off9(a0)
	BEQ.s	L628
	moveq	#0,D1
	MOVE.B	off1f(A0),D1
	EXT	D1
	swap	d1
	asr.l	#4,d1		;lsr.l #4,d1 corrige bug ???
	add.l	d1,off38(a0)
	SUB	off38(a0),D0
L628:
	MOVE.B	off2d(A0),D1

	;IFEQ	TURRICAN
	;SUB.B	off28(A0),D1
	;BPL.S	.NOVOL
	;CLR	D1
;.NOVOL:
	;RTS
	;ELSEIF
	MOVEQ	#-16,D2		;DEBUGGAGE VOLUME
	AND.B	D1,D2
	SUB.B	D2,D1
	SUB.B	off28(A0),D1
	BMI.S	.NOVOL
	OR.B	D2,D1
	RTS
.NOVOL:
	MOVE	D2,D1
	RTS
	;ENDC


LCA:


ZEROSND:
	clr.B	$22(A6)
	clr.B	$26(A6)
	clr.B	$2A(A6)
	MOVEM.L	$1C(A6),D0-D3
	MOVEM.L	D0-D3,$FFFF8800.W
	RTS

INITMUSIC:
;
; init musique
;
; entr‚e :
;	A0=pointe sur le texte 'COSO'
;	D0=num‚ro de la musique … jouer
;
	LEA	PSGREG(PC),A6
	ST	BLOQUEMUS-PSGREG(A6)

	subq	#1,d0
	BLT.S	LCA		;musique=0 -> cut mus



	;LEA		L51(PC),A1
	;MOVE.L	A1,MODIF1+2-PSGREG(A6)
	;LEA	flagdigit(PC),A1
	;MOVE.L	A1,MODIF2+2-PSGREG(A6)

	MOVE.L	A0,L934-PSGREG(A6)
	MOVE.L	$10(A0),A3
	ADD.L	A0,A3
	MOVE.L	$14(A0),A1
	ADD.L	A0,A1
;	ADD	D0,D0
;	ADD	D0,A1
;	ADD	D0,D0
	MULU	#6,D0
	ADD	D0,A1
	MOVEQ	#$C,D0
	MULU	(A1)+,D0	;PREMIER PATTERN
	MOVEQ	#$C,D2
	MULU	(A1)+,D2	;DERNIER PATTERN
	SUB	D0,D2

	ADD.L	D0,A3

	MOVE.B	1(A1),L810-PSGREG(A6)

	MOVEQ	#0,D0
	LEA	voice0(PC),A2
;
; REGISTRES UTILISES :
;
; D0=COMPTEUR VOIX 0-2
; D1=SCRATCH
; D2=PATTERN FIN
; A0={L934}
; A1=SCRATCH
; A2=VOICEX
; A3=PATTERN DEPART
; A6=BASE VARIABLES
;
L658:
	LEA	L7C6(PC),A1
	MOVE.L	A1,offa(A2)
	MOVE.L	A1,off12(A2)
	MOVEQ	#1,D1
	MOVE.B	D1,off17(A2)	;1
	MOVE.B	D1,off18(A2)	;1

	MOVE.B	d0,off21(A2)
	move.l	A3,off0(A2)
	move	D2,off34(A2)
	MOVE.B	#2,off2a(A2)

	moveq	#0,D1
	;IFEQ	OLD
	;MOVE	D1,off4(a2)
	;ELSEIF
	move	#$c,off4(A2)
	;ENDC

	MOVE	D1,offe(A2)
	MOVE.B	D1,off2d(A2)
	MOVE.B	D1,off8(A2)
	MOVE.B	D1,off9(A2)
	MOVE	D1,off30(A2)
	MOVE.B	D1,off19(A2)
	MOVE.B	D1,off1a(A2)
	MOVE.B	D1,off1b(A2)
	MOVE.B	D1,off1c(A2)
	MOVE.B	D1,off1d(A2)
	MOVE.B	D1,off1e(A2)
	MOVE.B	D1,off1f(A2)
	MOVE.L	D1,off38(A2)
	MOVE.B	D1,off26(A2)
	MOVE.B	D1,off27(A2)
	MOVE.B	D1,off2b(A2)

	move.b	(A3)+,D1
	ADD	D1,D1

	MOVE.L	A0,A1
	ADD	$C+2(A1),D1
	ADD	(A1,D1.W),A1

	MOVE.L	A1,off22(A2)
	move.b	(A3)+,off2c(A2)
	move.b	(A3)+,off16(A2)
	moveq	#$10,D1
	add.B	(A3)+,D1
	bcs.s	L712
	moveq	#0,D1
L712:
	MOVE.B	D1,off28(A2)
	lea	off3c(A2),A2
	ADDQ	#4,D2
	addq	#1,d0
	cmp	#3,d0
	blo	L658

	MOVE.B	#1,L80E-PSGREG(A6)
	;IFEQ	CUTMUS
;	CLR	BLOQUEMUS-PSGREG(A6)
	CLR.B	BLOQUEMUS-PSGREG(A6)
;	CLR.B	L813-PSGREG(A6)
	;ENDC
	RTS			;ou BRA ZEROSND

L7C6:	DC.B	1,0,0,0,0,0,0,$E1

PSGREG:	
	DC.W	$0000,$0000,$101,$0000
	DC.W	$0202,$0000,$303,$0000
	DC.W	$0404,$0000,$505,$0000
	DC.W	$0606,$0000,$707,$FFFF
	DC.W	$0808
	DC.W	$0000,$909,$0000
	DC.W	$0A0A,$0000

L94E:	DC.W	$EEE,$E17,$D4D,$C8E
	DC.W	$BD9,$B2F,$A8E,$9F7
	DC.W	$967,$8E0,$861,$7E8
	DC.W	$777,$70B,$6A6,$647
	DC.W	$5EC,$597,$547,$4FB
	DC.W	$4B3,$470,$430,$3F4
	DC.W	$3BB,$385,$353,$323
	DC.W	$2F6,$2CB,$2A3,$27D
	DC.W	$259,$238,$218,$1FA
	DC.W	$1DD,$1C2,$1A9,$191
	DC.W	$17B,$165,$151,$13E
	DC.W	$12C,$11C,$10C,$FD
	DC.W	$EE,$E1,$D4,$C8
	DC.W	$BD,$B2,$A8,$9F
	DC.W	$96,$8E,$86,$7E
	DC.W	$77,$70,$6A,$64
	DC.W	$5E,$59,$54,$4F
	DC.W	$4B,$47,$43,$3F
	DC.W	$3B,$38,$35,$32
	DC.W	$2F,$2C,$2A,$27
	DC.W	$25,$23,$21,$1F
	DC.W	$1D,$1C,$1A,$19
	DC.W	$17,$16,$15,$13
	DC.W	$12,$11,$10,$F
; amiga=C178a8
L80E:	DC.B	4
L810:	DC.B	4
	;IFEQ	CUTMUS
BLOQUEMUS:DC.B	-1
	;ENDC



	EVEN
voice0:	ds.B	off3c
voice1:	ds.B	off3c
voice2:	ds.B	off3c
L934:	DC.L	0


	

;-------------------------------------
;
;    FIN COSO
;
;-------------------------------------




;-----------------------------------------------------------------


	.gpu
GPU_debut:
	.org	G_RAM
GPU_base_memoire:

GPU_init:

	movei	#GPU_ISP+(GPU_STACK_SIZE*4),r31			; init isp				6
	moveq	#0,r1										;						2
	moveta	r31,r31									; ISP (bank 0)		2
	nop													;						2
	movei	#GPU_USP+(GPU_STACK_SIZE*4),r31			; init usp				6

	moveq	#$0,R0										; 2
	moveta	R0,R26							; compteur	  2
	movei	#interrupt_OP,R1							; 6
	moveta	R1,R27										; 2


	movei	#OBF,R0									; 6
	moveta	R0,R22										; 2

	movei	#G_FLAGS,R1											; GPU flags
	moveta	R1,R28


	jr		GPU_init_suite							;						2
	nop
; Object Processor interrupt
	jump	(R27)
	nop

;	.rept	6
;		nop
;	.endr
; Blitter
;	.rept	8
;		nop
;	.endr

GPU_init_suite:
	movei		#BG,R10
	moveta		R10,R10
	moveq		#0,R11
	moveta		R11,R11				; R11 = couleur en cours





	movei	#G_FLAGS,r30

	movei	#G_OPENA|REGPAGE,r29			; object list interrupt
	nop
	nop
	store	r29,(r30)
	nop
	nop



; swap les pointeurs d'OL
		movei	#GPU_pointeur_object_list_a_modifier,R0
		movei	#GPU_pointeur_object_list_a_afficher,R1
		load	(R0),R2
		load	(R1),R3
		store	R2,(R1)
		movei	#OLP,R4
		moveta	R3,R3
		rorq	#16,R2
		store	R3,(R0)

		store	R2,(R4)

		.if		1=0
; synchro avec l'interrupt object list
		movefa	R26,R26
		
GPU_boucle_wait_vsync2:
		movefa	R26,R25
		cmp		R25,R26
		jr		eq,GPU_boucle_wait_vsync2
		nop
		.endif
;----------------------------------------------
;----------------------------------------------
;----------------------------------------------


GPU_main_loop:
		movei	#BG,R26
		movei	#$8888,R25				; blanc en haut
		storew	R25,(R26)


;----------------------------------------------
; insertion dans l'object list de la zone du scrolling
;----------------------------------------------
		movei	#GPU_pointeur_object_list_a_modifier,R20
		movei	#GPU_pointeur_sur_zone_scrolling_a_modifier,R21
		movei	#GPU_premiere_ligne,R25
		load	(R20),R18			; R18 = pointeur sur OL
		load	(R21),R13			; R13=data
		load	(R25),R9
		movei	#(3<<12)+(1<<15)+((320/8)<<18)+(%1000<<28),R2		; 4 bits de iwidth << 28		; depth=3  / Pitch=1 / DWIDTH=(320/8) / IWIDTH=  : 3<<12 + 1<<15 + 40<<18 + 40<<28 : $4000 + $10000000
		
		

		;movei	#$8140C000,R2		; depth=4  / Pitch=1 / DWIDTH=80 / IWIDTH=8  : 4<<12 + 1<<15 + 80<<18 + 8<<28
		;movei	#$8280C000,R2		; depth=4  / Pitch=1 / DWIDTH=160 / IWIDTH=8  : 4<<12 + 1<<15 + 160<<18 + 8<<28 : $4000 + $8000 + $2800000 + $80000000

		;movei	#$10004000,R2		; depth=4  / Pitch=0 / DWIDTH=0 / IWIDTH=1  : 4<<12 + 0<<15 + 0<<18 + 1<<28 : $4000 + $10000000

		; la suite de IWIDTH va sur R4
		
		addq	#32,R18				; OL + 32
		shrq	#1,R9
		movei	#(1<<15)+(%0010),R4		; TRANS = 1 ( <<15 ) + 6 bits de iwidth			(5 = 320 pixels)
		addq	#16,R18				; OL + 16 = +48

		movei	#48,R12				; R12=Y
		movei	#0,R11				; R11=X
		;movei	#motif_raster__data,R13			; R13=data
		
		add		R9,R12				; Y + ligne du haut/1ere ligne
		sharq	#3,R13				; DATA sur phrase
		movei	#(83+13),R14				; R14=height = 83+13 lignes
		shlq	#3+1,R12			; Ypos * 2 << 3
		move	R18,R17				; R17=LINK
		shlq	#14,R14				; height << 14
		addq	#16,R17				; R17=LINK
		or		R14,R12				; R12 = Height  |   YPos   |000|
		sharq	#3,R17				; LINK sur phrase
		move	R17,R16				; R16=LINK pour 2eme mot
		shlq	#11,R13				; decalage DATA
		sharq	#8,R17				; R17=LINK pour 1er mot

		or		R17,R13				; 1er mot : LINK + data
		store	R13,(R18)				; store 1er mot
		shlq	#24,R16				; R16=LINK pour 2eme mot
		addq	#4,R18
		or		R16,R12				; Link-address    |   Height  |   YPos   |000|
		store	R12,(R18)				; store 2eme mot
		
		move	R2,R1		
		addq	#4,R18
		move	R4,R3			; TRANS=1
		or		R11,R1				; + X
		store	R3,(R18)
		addq	#4,R18
		store	R1,(R18)
		addq	#4,R18



;----------------------------------------------
; insertion dans l'object list de la zone du logo
;----------------------------------------------


 ;63       56        48        40       32        24       16       8        0
 ; +--------^---------^-----+------------^--------+--------^--+-----^----+---+
 ; |        data-address    |     Link-address    |   Height  |   YPos   |000|
 ; +------------------------+---------------------+-----------+----------+---+
 ;     63 .............43        42.........24      23....14    13....3   2.0
 ;          21 bits                 19 bits        10 bits     11 bits  3 bits
 ;                                   (11.8)

; 63       56        48        40       32       24       16        8        0
;  +--------^-+------+^----+----^--+-----^---+----^----+---+---+----^--------+
;  | unused   |1stpix| flag|  idx  | iwidth  | dwidth  | p | d |   x-pos     |
;  +----------+------+-----+-------+---------+---------+---+---+-------------+
;    63...55   54..49 48.45  44.38   37..28    27..18 17.15 14.12  11.....0
;      9bit      6bit  4bit   7bit    10bit    10bit   3bit 3bit    12bit
;                                    (6.4)

; R1 = 8140C000 = depth+pitch+dwidth+iwidth
; R2 = 8140C000 = depth+pitch+dwidth+iwidth
; R3 = TRANS
; R4 = 		movei	#$8000,R3			; TRANS=1

; R9 = premiere ligne haut OL

; R10 = Heigth + Ypos +000    / par ligne
; R11 = X
; R12 = Y
; R13 = data sprite
; R14 = height
; R16 = link tmp
; R17 = LINK
; R18 = pointeur sur bloc a utiliser
; R19 = Y tmp

; R20 = 
; R21 = 
; R23 = GPU_pointeurs_blocs_OL
; R24 = pointeur sur l'OL à modifier = GPU_pointeur_object_list_a_modifier + OL_taille_bloc_de_bras_tiles
; R28 = 

; phrase = 64 bits = 8 octets

; R21 = pointeur raster
		;movei	#GPU_pointeur_object_list_a_modifier,R20
		movei	#GPU_pointeur_sur_zone_logo_a_modifier,R21
		movei	#GPU_premiere_ligne,R25
		;load	(R20),R18			; R18 = pointeur sur OL
		load	(R21),R13			; R13=data
		load	(R25),R9
		movei	#(3<<12)+(1<<15)+((320/8)<<18)+(%1000<<28),R2		; 4 bits de iwidth << 28		; depth=3  / Pitch=1 / DWIDTH=(320/8) / IWIDTH=  : 3<<12 + 1<<15 + 40<<18 + 40<<28 : $4000 + $10000000
		
		

		;movei	#$8140C000,R2		; depth=4  / Pitch=1 / DWIDTH=80 / IWIDTH=8  : 4<<12 + 1<<15 + 80<<18 + 8<<28
		;movei	#$8280C000,R2		; depth=4  / Pitch=1 / DWIDTH=160 / IWIDTH=8  : 4<<12 + 1<<15 + 160<<18 + 8<<28 : $4000 + $8000 + $2800000 + $80000000

		;movei	#$10004000,R2		; depth=4  / Pitch=0 / DWIDTH=0 / IWIDTH=1  : 4<<12 + 0<<15 + 0<<18 + 1<<28 : $4000 + $10000000

		; la suite de IWIDTH va sur R4
		
		;addq	#32,R18				; OL + 32
		shrq	#1,R9
		movei	#(1<<15)+(%0010),R4		; TRANS = 1 ( <<15 ) + 6 bits de iwidth			(5 = 320 pixels)
		;addq	#16,R18				; OL + 16 = +48

		movei	#0,R12				; R12=Y
		movei	#0,R11				; R11=X
		;movei	#motif_raster__data,R13			; R13=data
		
		add		R9,R12				; Y + ligne du haut/1ere ligne
		sharq	#3,R13				; DATA sur phrase
		movei	#106,R14				; R14=height = 106 lignes
		shlq	#3+1,R12			; Ypos * 2 << 3
		move	R18,R17				; R17=LINK
		shlq	#14,R14				; height << 14
		addq	#16,R17				; R17=LINK
		or		R14,R12				; R12 = Height  |   YPos   |000|
		sharq	#3,R17				; LINK sur phrase
		move	R17,R16				; R16=LINK pour 2eme mot
		shlq	#11,R13				; decalage DATA
		sharq	#8,R17				; R17=LINK pour 1er mot

		or		R17,R13				; 1er mot : LINK + data
		store	R13,(R18)				; store 1er mot
		shlq	#24,R16				; R16=LINK pour 2eme mot
		addq	#4,R18
		or		R16,R12				; Link-address    |   Height  |   YPos   |000|
		store	R12,(R18)				; store 2eme mot
		
		move	R2,R1		
		addq	#4,R18
		move	R4,R3			; TRANS=1
		or		R11,R1				; + X
		store	R3,(R18)
		addq	#4,R18
		store	R1,(R18)
		addq	#4,R18

; -----
; inserer un stop
		moveq	#0,R25			; STOP : 0
		moveq	#4,R16			; STOP : 4
		store	R25,(R18)
		addq	#4,R18
		store	R16,(R18)


;----------------------------------------------
; efface au blitter
;----------------------------------------------
; il faut effacer 320*(62+44) octets = 33920

	.if			CLS_BLITTER=1
	movei		#GPU_pointeur_sur_zone_logo_a_modifier,R10
	movei		#A1_BASE,R14
	moveq		#0,R0
	move		R14,R15
	load		(R10),R1					; R1 = zone a effacer
	movei		#PITCH1|PIXEL16|WID768|XADDPHR,R2
	store		R0,(R14+3)					; A1_PIXEL								F0220C				+3
	store		R0,(R15+$1A)				; B_PATD								F02268				+1A
	movei		#$00010000+(33920/2),R3
	store		R2,(R15+1)					; A1_FLAGS								F02204				+1
	store		R1,(R14)
	store		R0,(R15+$1B)				; B_PATD+4								F02268				+1A
	movei		#PATDSEL|UPDA1,R4
	store		R3,(R14+$0F)				; B_COUNT								F0223C				+0F
	store		R4,(R15+$0E)				; B_CMD									F02238				+0E

GPU_clear_zone_logo_waitblit:
	load		(r14+$0E), r0			; Read back blit status
	btst		#0, r0				; See if bit 0 is set
	jr			EQ,GPU_clear_zone_logo_waitblit
	nop

; efface zone du scrolling
	movei		#GPU_pointeur_sur_zone_scrolling_a_modifier,R10
	movei		#A1_BASE,R14
	moveq		#0,R0
	move		R14,R15
	load		(R10),R1					; R1 = zone a effacer
	movei		#PITCH1|PIXEL16|WID768|XADDPHR,R2
	store		R0,(R14+3)					; A1_PIXEL								F0220C				+3
	store		R0,(R15+$1A)				; B_PATD								F02268				+1A
	movei		#$00010000+(30720/2),R3
	store		R2,(R15+1)					; A1_FLAGS								F02204				+1
	store		R1,(R14)
	store		R0,(R15+$1B)				; B_PATD+4								F02268				+1A
	movei		#PATDSEL|UPDA1,R4
	store		R3,(R14+$0F)				; B_COUNT								F0223C				+0F
	store		R4,(R15+$0E)				; B_CMD									F02238				+0E

GPU_clear_zone_logo_waitblit_scrolling:
	load		(r14+$0E), r0			; Read back blit status
	btst		#0, r0				; See if bit 0 is set
	jr			EQ,GPU_clear_zone_logo_waitblit_scrolling
	nop


	.endif
		movei	#BG,R26
		movei	#$5028,R25				; blanc en haut
		storew	R25,(R26)


		.if		DEBUG_LOGO=0

;----------------------------------------------
; gere les commandes du logo
;----------------------------------------------
	movei		#GPU__logo__numero_commande_en_cours,R10
	movei		#GPU_logo_execute_commandes,R27
	load		(R10),R0				; R0=commande en cours
	cmpq		#0,R0
	jump		ne,(R27)
	nop


	movei		#GPU__logo__pointeur_sur_table_des_commandes,R11
	movei		#GPU_logo_lecture_commandes,R28
	load		(R11),R12
	movei		#GPU_logo_fin_test_des_commandes,R29
GPU_logo_lecture_commandes:
	load		(R12),R1			; R1 = nouvelle commande
	cmpq		#0,R1				; commande = 0 = fin de la liste ?
	jr			ne,GPU__logo__pas_fin_de_la_liste_de_commandes
	addqt		#4,R12
	
	movei		#logo_table_1_commandes,R12
	store		R12,(R11)
	jr			GPU_logo_lecture_commandes
	nop

GPU__logo__pas_fin_de_la_liste_de_commandes:
	cmpq		#1,R1
	jr			ne,GPU__logo__test_commande_2
	nop
; commande = 1
	load		(R12),R3
	movei		#GPU__logo__pointeur_sur_table4_pour_raz_de_commandes,R13
	addq		#4,R12
	store		R1,(R10)			; stocke commande en cours = 1
	store		R3,(R13)			
	jump		(R29)
	nop
GPU__logo__test_commande_2:
	cmpq		#2,R1
	jr			ne,GPU__logo__test_commande_3
	nop
; commande = 2
	load		(R12),R3
	movei		#GPU__logo__pointeur_sur_table4_pour_raz_de_commandes,R13
	addq		#1,R1				; R1 = 3
	addq		#4,R12
	store		R1,(R10)			; stocke commande en cours = 3
	store		R3,(R13)			
	jump		(R29)
	nop	
GPU__logo__test_commande_3:
	cmpq		#3,R1
	jr			ne,GPU__logo__test_commande_4
	nop
; commande = 3
	load		(R12),R3
	movei		#GPU__logo__pointeur_sur_table4_pour_raz_de_commandes,R13
	subq		#1,R1				; R1 = 2
	addq		#4,R12
	store		R1,(R10)			; stocke commande en cours = 2
	store		R3,(R13)			
	jump		(R29)
	nop	
GPU__logo__test_commande_4:
	cmpq		#4,R1
	jr			ne,GPU__logo__test_commande_5
	nop
; commande = 4 = logo ATARI
	movei		#GPU_pointeur_sur_data_graph_logo_actuel,R3
	movei		#table_adresses_logo_ATARI_predecale,R4
	store		R4,(R3)
	movei		#GPU_scrolling_offset_palette_actuelle,R5
	moveq		#0,R6
	store		R6,(R5)
	
	jump		(R28)
	nop
GPU__logo__test_commande_5:
	movei		#GPU__logo__test_commande_6,R27
	cmpq		#5,R1
	jump		ne,(R27)
	nop
; commande = 5 = logo OMEGA
	movei		#GPU_pointeur_sur_data_graph_logo_actuel,R3
	movei		#table_adresses_logo_OMEGA_predecale,R4
	store		R4,(R3)
	movei		#GPU_scrolling_offset_palette_actuelle,R5
	movei		#$20202020,R6
	store		R6,(R5)
	jump		(R28)
	nop
GPU__logo__test_commande_6:
; commande 6 = changement de palette => NULL
; il n'y a pas de commande 7 dans la ligne


GPU_logo_fin_test_des_commandes:
	store		R12,(R11)			; update GPU__logo__pointeur_sur_table_des_commandes



	
;----------------------------------------------
; avance tous les pointeurs du logo suivant la valeur de la commande
GPU_logo_execute_commandes:

;--------------
; - si $87E0 / GPU__logo__numero_commande_en_cours = 1

	movei		#GPU__logo__numero_commande_en_cours,R10
	movei		#GPU_logo_avance_pointeurs_commande_2,R27
	load		(R10),R0
	cmpq		#1,R0
	jump		ne,(R27)
	nop
; commande en cours = 1
	movei		#pointeur_actuel_sur_table_4_lignes_pour_zoom_Y,R11				; $87FE
	movei		#134,R2
	load		(R11),R1
	movei		#table_4_lignes_pour_zoom_Y+(134*150),R4								; $FD9A		// 150*134
	add			R2,R1
	cmp			R4,R1
	jr			ne,GPU_logo_avance_pointeurs_commande_1__pas_fin_table_4
	nop
	movei		#table_4_lignes_pour_zoom_Y,R1
GPU_logo_avance_pointeurs_commande_1__pas_fin_table_4:
; test par rapport à $87DC = GPU__logo__pointeur_sur_table4_pour_raz_de_commandes
	movei		#GPU__logo__pointeur_sur_table4_pour_raz_de_commandes,R12
	load		(R12),R5
	cmp			R5,R1
	jr			ne,GPU_logo_avance_pointeurs_commande_1__pas_arrive_a_GPU__logo__pointeur_sur_table4_pour_raz_de_commandes
	;nop
	moveq		#0,R6
	store		R6,(R10)			; update $87E0
GPU_logo_avance_pointeurs_commande_1__pas_arrive_a_GPU__logo__pointeur_sur_table4_pour_raz_de_commandes:
	store		R1,(R11)






GPU_logo_avance_pointeurs_commande_2:
;--------------
; - si $87E0 / GPU__logo__numero_commande_en_cours = 2
	movei		#GPU__logo__numero_commande_en_cours,R10
	movei		#GPU_logo_avance_pointeurs_commande_3,R27
	load		(R10),R0
	cmpq		#2,R0
	jump		ne,(R27)
	nop
; commande en cours = 2
	movei		#pointeur_actuel_sur_table_4_lignes_pour_zoom_Y,R11				; $87FE
	movei		#134,R2
	load		(R11),R1
	movei		#table_4_lignes_pour_zoom_Y-134,R4								; $FD9A		// 150*134
	sub			R2,R1				; -134
	cmp			R4,R1
	jr			ne,GPU_logo_avance_pointeurs_commande_2__pas_fin_table_4
	nop
	movei		#table_4_lignes_pour_zoom_Y+(134*149),R1					; $FD14 = $FD9A - 134
GPU_logo_avance_pointeurs_commande_2__pas_fin_table_4:
; test par rapport à $87DC = GPU__logo__pointeur_sur_table4_pour_raz_de_commandes
	movei		#GPU__logo__pointeur_sur_table4_pour_raz_de_commandes,R12
	load		(R12),R5
	cmp			R5,R1
	jr			ne,GPU_logo_avance_pointeurs_commande_2__pas_arrive_a_GPU__logo__pointeur_sur_table4_pour_raz_de_commandes
	;nop
	moveq		#0,R6
	store		R6,(R10)			; update $87E0 = 0
GPU_logo_avance_pointeurs_commande_2__pas_arrive_a_GPU__logo__pointeur_sur_table4_pour_raz_de_commandes:
	store		R1,(R11)




GPU_logo_avance_pointeurs_commande_3:
;--------------
; - si $87E0 / GPU__logo__numero_commande_en_cours = 3
	movei		#GPU__logo__numero_commande_en_cours,R10
	movei		#GPU_logo_avance_pointeurs_avance_pointeur_deplacement_en_X,R27
	load		(R10),R0
	cmpq		#3,R0
	jump		ne,(R27)
	nop
; commande en cours = 3
	movei		#GPU__logo__pointeur_sur_table4_pour_raz_de_commandes,R11
	load		(R11),R1
	subq		#1,R1
	store		R1,(R11)
	cmpq		#0,R1
	jr			ne,GPU_logo_avance_pointeurs_avance_pointeur_deplacement_en_X
	;nop
	moveq		#0,R6	
	store		R6,(R10)			; update $87E0 = 0



GPU_logo_avance_pointeurs_avance_pointeur_deplacement_en_X:
;--------------
; avance ou recule sur deplacement en X 
	movei		#pointeur_actuel_sur_table_2_positions_en_X,R11
	movei		#FIN_table_2_positions_en_X-192,R2
	load		(R11),R1
	addq		#2,R1
	cmp			R2,R1
	jr			ne,GPU_logo_avance_pointeurs_avance_pointeur_deplacement_en_X__pas_fin_table_deplacement_en_X
	nop
	movei		#table_2_positions_en_X,R1
GPU_logo_avance_pointeurs_avance_pointeur_deplacement_en_X__pas_fin_table_deplacement_en_X:
	store		R1,(R11)
	


;--------------
; pointeur_actuel_sur_table_5_waves_en_Y = $87F6
	movei		#pointeur_actuel_sur_table_5_waves_en_Y,R10
	movei		#(FIN_table_5_waves_en_Y+$86BE-$870E),R12
	load		(R10),R0
	addq		#2,R0
	cmp			R12,R0
	jr			ne,GPU_gestion_pointeurs_logo__pas_de_bouclage_sur_table5
	nop
	movei		#table_5_waves_en_Y,R0
GPU_gestion_pointeurs_logo__pas_de_bouclage_sur_table5:
	store		R0,(R10)

;  pointeur_actuel_sur_table_3_increments_en_X_pour_vague = 87F2 
; -2 par vbl, 
	movei		#pointeur_actuel_sur_table_3_increments_en_X_pour_vague,R10
	movei		#table_3_increments_en_X_pour_vague,R12
	load		(R10),R0
	subq		#2,R0
	cmp			R12,R0
	jr			ne,GPU_gestion_pointeurs_logo__pas_de_bouclage_sur_table3
	nop
	movei		#table_3_increments_en_X_pour_vague+$8204-$8196,R0							; boucle en $8204
GPU_gestion_pointeurs_logo__pas_de_bouclage_sur_table3:
	store		R0,(R10)


		.endif

		movei	#BG,R26
		movei	#$FFFF,R25				; blanc en haut
		storew	R25,(R26)


;----------------------------------------------
; routine affichae du logo, 8 pixels par 8 pixels

; R0=tmp
; R1=tmp
; R2 = tmp
; R3 = tmp
; R4 = tmp
; R5 =
; R6 = %11				masque pour determiner predecalage
; R7 = $FFFFFFFC		masque pour arrondir l'adresse en X
; R8 = 320
; R9 = 40
; ------
; R10= logo
; R11 = R10+1
; R12 = source des lignes de la wave en Y						*320
; R13 = pointeur sur graph logo actuel
; R14 = pointeur sur  table 4 des lignes pour zoom Y
; R15 = pointeur sur table 3 increments en X pour la vague
; R16 = table des positions en X
; R18 = pointeur sur le debut du logo en cours
; R19 = 
; ------
; R20 = dest en cours
; R21 = dest + 1 en cours
; R22 = destination en memoire
; R23 =  increment ligne source
; R24 = position dans la destination
; R25 = compteur de lignes à afficher ( 62 )
; R26 = compteur de blocs de 8 pixels (40)
; R27 = saut boucle 8 pixels = GPU_logo_Omega_boucle_8_pixels
; R28 = saut boucle 1 ligne = GPU_logo_Omega_boucle_1_ligne
; R29 =
; ------
; R30 =

	movei	#pointeur_actuel_sur_table_5_waves_en_Y,R1							; $87F6
	moveq	#%11,R6																; masque pour determiner predecalage
	movei	#GPU_pointeur_sur_zone_logo_a_modifier,R0
	movei	#$FFFFFFFC,R7														; masque pour arrondir l'adresse en X
	movei	#pointeur_actuel_sur_table_2_positions_en_X,R20						; $87EE
	movei	#pointeur_actuel_sur_table_4_lignes_pour_zoom_Y,R21					; $87FE
	movei	#pointeur_actuel_sur_table_3_increments_en_X_pour_vague,R10			; $87F2
	movei	#40,R9
	movei	#GPU_pointeur_sur_data_graph_logo_actuel,R13						; pointe sur la liste des prédecalages du logo actuel
	load	(R1),R12
	load	(R13),R18							 ; R18 = tables des adresses des graph du logo
	;movei	#buffer_logo_ATARI_etendu,R18
	load	(R20),R16
	movei	#62,R25								; 62
	load	(R0),R24
	movei	#GPU_logo_Omega_boucle_8_pixels,R27
	load	(R21),R14
	movei	#GPU_logo_Omega_boucle_1_ligne,R28
	load	(R10),R15
	movei	#320,R8

GPU_logo_Omega_boucle_1_ligne:
; determiner R18 en fonction de X

	
	loadw	(R16),R0						; R0=position en X
	move	R12,R13							; R13=pointeur table des waves en Y
	loadw	(R15),R4						; R4 = increment en X pour vague
	
	loadw	(R14),R1						; R14= table choix des lignes en Y
	add		R4,R0							; R0 = position en X

	move	R18,R3							; R18 = table datas graph logo predecalés
	move	R0,R2

	and		R6,R2							; sur 2 bits
	sub		R2,R0
	;and		R7,R0							; arrondit à multiple de 4


	shlq	#2,R2							; *4
	add		R2,R3
	
	
	
	load	(R3),R10						; R10=adresse relle du graph du logo, predecalé
	
	sub		R0,R10							; data graph logo + table 2 : positions en X
	
	
	
	addq	#2,R16
	addq	#2,R14
	
	addq	#2,R15
	add		R1,R10							; data graph logo + table 4 : table des lignes pour zoom Y	

	move	R24,R21
	move	R10,R11
	move	R9,R26
	move	R24,R20

	addq	#4,R21
	addq	#4,R11

GPU_logo_Omega_boucle_8_pixels:
	loadw	(R13),R2
	add		R2,R20
	load	(R10),R0
	addq	#2,R13
; version theorique 4 pixels d'un coup, consecutifs car prédécalés
; 8 pixels
	add		R2,R21
	load	(R11),R1			; R1=R0+4
	addq	#8,R10
	addq	#8,R11
	store	R0,(R20)
	store	R1,(R21)
	addq	#8,R20
	addq	#8,R21
	
;------------------	

	sub		R2,R20
	sub		R2,R21

	subq	#1,R26
	jump	ne,(R27)				; 40 * 8 = 320 pixels
	nop
	add		R8,R24					; prochaine ligne + 320

; ligne suivante
; 40*8 = 320
	;add		R8,R10
	;add		R8,R11
		
	subq	#1,R25
	jump	ne,(R28)
	nop


; --------------
; avancer pointeur Y du scrolling
	movei	#GPU_pointeur_actuel_sur_table_Y_scrolling,R1
	movei	#table_Y_scrolling+$210,R3
	load	(R1),R0
	addq	#8,R0
	cmp		R3,R0
	jr		ne,GPU_avance_pointeur_Y_scrolling__pas_de_bouclage
	nop
	movei	#table_Y_scrolling,R0
GPU_avance_pointeur_Y_scrolling__pas_de_bouclage:
	store	R0,(R1)
	





;----------------------------------------------
; routine affichae du scrolling, 16 pixels par 16 pixels
; R0=tmp
; R1=tmp
; R2 = 
; R3 = 
; R4 = 
; R5 =
; R6 = 
; R7 = GPU_scrolling_offset_palette_actuelle
; R8 = 320
; R9 = 20
; ------
; R10 = buffer scrolling
; R11 = buffer scrolling + 1
; R12 = 
; R13 = table des Y du scrolling actuelle
; R14 = table des Y du scrolling
; R15 = 
; R16 = 
; R18 = 
; R19 = 
; ------
; R20 = 
; R21 = 
; R22 = 
; R23 = 
; R24 = 
; R25 = compteur de lignes à afficher ( 13 )
; R26 = compteur boucles 16 pixels
; R27 = GPU_scrolling__boucle_16_pixels
; R28 = GPU_scrolling__boucle_lignes
; R29 =
; ------
; R30 =

	movei	#GPU_scrolling_offset_palette_actuelle,R20
	movei	#GPU_scrolling__boucle_16_pixels,R27
	movei	#GPU_scrolling__boucle_lignes,R28
	load	(R20),R7
	movei	#20,R9										; 320/16=20
	movei	#13,R25
	movei	#320,R8

; source des lignes en Y
	movei	#GPU_pointeur_actuel_sur_table_Y_scrolling,R1
	load	(R1),R14

; source
	movei	#buffer_scrolling_double_largeur,R10
	move	R10,R11
	addq	#4,R11
	
; dest
	movei	#GPU_pointeur_sur_zone_scrolling_a_modifier,R0
	load	(R0),R20
	move	R20,R21
	addq	#4,R21
	

GPU_scrolling__boucle_lignes:
		
	move	R14,R13
	move	R9,R26
	
GPU_scrolling__boucle_16_pixels:
	loadw	(R13),R2
	addq	#6,R13
	
	add		R2,R20
	add		R2,R21

			.rept	2
			load	(R10),R0			; 4 pixels
			load	(R11),R1			; R1=R0+4
			add		R7,R0
			addq	#8,R10
			add		R7,R1
			addq	#8,R11
			store	R0,(R20)
			store	R1,(R21)
			addq	#8,R20
			addq	#8,R21
			.endr

	sub		R2,R20
	sub		R2,R21

	subq	#1,R26
	jump	ne,(R27)				; 40 * 8 = 320 pixels
	nop

; next line
	add		R8,R10
	add		R8,R11

	subq	#1,R25
	jump	ne,(R28)
	nop



		movei	#BG,R26
		movei	#$0000,R25				; blanc en haut
		storew	R25,(R26)


;----------------------------------------------
; incremente compteur de VBL au GPU
		movei	#vbl_counter_GPU,R0
		load	(R0),R1
		addq	#1,R1
		store	R1,(R0)

		;movei	#BG,R26
		;moveq	#0,R25				; bleu
		;storew	R25,(R26)



;-------------------------------------
; synchro avec l'interrupt object list
		movefa	R26,R26
		
GPU_boucle_wait_vsync:
		movefa	R26,R25
		cmp		R25,R26
		jr		eq,GPU_boucle_wait_vsync
		nop
		

; swap les pointeur sur les zones de buffer des logo
		movei	#GPU_pointeur_sur_zone_logo_a_modifier,R0
		movei	#GPU_pointeur_sur_zone_logo_a_afficher,R1
		load	(R0),R2
		load	(R1),R3				
		store	R2,(R1)
		store	R3,(R0)

; swap les pointeur sur les zones de buffer du scrolling
		movei	#GPU_pointeur_sur_zone_scrolling_a_modifier,R20
		movei	#GPU_pointeur_sur_zone_scrolling_a_afficher,R21
		load	(R20),R2
		load	(R21),R3				
		store	R2,(R21)
		store	R3,(R20)


; swap les pointeurs d'OL
		movei	#GPU_pointeur_object_list_a_modifier,R0
		movei	#GPU_pointeur_object_list_a_afficher,R1
		load	(R0),R2
		load	(R1),R3				; R3 = pointeur sur l'object list a modifier prochaine frame
		store	R2,(R1)
		movei	#OLP,R4
		;moveta	R3,R3
		rorq	#16,R2
		store	R3,(R0)

		store	R2,(R4)


	movei	#GPU_main_loop,R27
	jump		(R27)
	nop

;----------------------------------------------
;----------------------------------------------
;----------------------------------------------



;--------------------------------------------------------
;
; interruption object processor
;	- libere l'OP
;	- incremente R26
; utilises : R0/R22/R26/R28/R29/R30/R31
;
;--------------------------------------------------------
interrupt_OP:
		storew		R0,(r22)					; R22 = OBF
		load     (R28),r29
		addq     #1,r26							; incremente R26
		load     (R31),r30
		bclr     #3,r29
		addq     #2,r30
		addq     #4,r31
		bset     #12,r29
		jump     (r30)
		store    r29,(r28)




























	.dphrase
vbl_counter_GPU:								dc.l		5424
GPU_pointeur_object_list_a_modifier:			dc.l			ob_list_1
GPU_pointeur_object_list_a_afficher:			dc.l			ob_list_2
GPU_premiere_ligne:				dc.l		0				; lus 2 fois
GPU_derniere_ligne:				dc.l		0
GPU_pointeur_sur_zone_logo_a_modifier:		dc.l		zone_logo_1
GPU_pointeur_sur_zone_logo_a_afficher:		dc.l		zone_logo_2
GPU_pointeur_sur_zone_scrolling_a_modifier:		dc.l		zone_scrolling_1
GPU_pointeur_sur_zone_scrolling_a_afficher:		dc.l		zone_scrolling_2



pointeur_actuel_sur_table_2_positions_en_X:						dc.l		table_2_positions_en_X					; $87EE
pointeur_actuel_sur_table_3_increments_en_X_pour_vague:			dc.l		table_3_increments_en_X_pour_vague+2	; $87F2
pointeur_actuel_sur_table_4_lignes_pour_zoom_Y:					dc.l		table_4_lignes_pour_zoom_Y				; $87FE
pointeur_actuel_sur_table_5_waves_en_Y:							dc.l		table_5_waves_en_Y+2					; $87F6

GPU_pointeur_actuel_sur_table_Y_scrolling:						dc.l		table_Y_scrolling						; $1C66=L0044 = offset actuel sur la courbe des Y
GPU_scrolling_offset_palette_actuelle:							dc.l		$0							; $00000000 ou $20202020


GPU_pointeur_sur_data_graph_logo_actuel:						dc.l		table_adresses_logo_ATARI_predecale

GPU__logo__pointeur_sur_table_des_commandes:					dc.l		logo_table_1_commandes
GPU__logo__numero_commande_en_cours:							dc.l		0										; $87E0
GPU__logo__pointeur_sur_table4_pour_raz_de_commandes:			dc.l		0										; $87DC 


GPU_volume_A:			dc.l		13			; de 0 a 15
GPU_volume_B:			dc.l		15			; de 0 a 15
GPU_volume_C:			dc.l		11			; de 0 a 15

;---------------------
; FIN DE LA RAM GPU
GPU_fin:
;---------------------	

GPU_DRIVER_SIZE			.equ			GPU_fin-GPU_base_memoire
	.print	"---------------------------------------------------------------"
	.print	"--- GPU code size : ", /u GPU_DRIVER_SIZE, " bytes / 4096 ---"
	.if GPU_DRIVER_SIZE > 4088
		.print		""
		.print		""
		.print		""
		.print	"---------------------------------------------------------------"
		.print	"          GPU code too large !!!!!!!!!!!!!!!!!! "
		.print	"---------------------------------------------------------------"
		.print		""
		.print		""
		.print		""
		
	.endif


		.68000






;-------------------------------------
;
;     DSP
;
;-------------------------------------

	.phrase
YM_DSP_debut:

	.dsp
	.org	D_RAM
DSP_base_memoire:

; CPU interrupt
	.rept	8
		nop
	.endr
; I2S interrupt
	movei	#DSP_LSP_routine_interruption_I2S,r28						; 6 octets
	movei	#D_FLAGS,r30											; 6 octets
	jump	(r28)													; 2 octets
	load	(r30),r29	; read flags								; 2 octets = 16 octets
; Timer 1 interrupt
	movei	#DSP_LSP_routine_interruption_Timer1,r12						; 6 octets
	movei	#D_FLAGS,r16											; 6 octets
	jump	(r12)													; 2 octets
	load	(r16),r13	; read flags								; 2 octets = 16 octets
; Timer 2 interrupt	
	movei	#DSP_LSP_routine_interruption_Timer2,r28						; 6 octets
	movei	#D_FLAGS,r30											; 6 octets
	jump	(r28)													; 2 octets
	load	(r30),r29	; read flags								; 2 octets = 16 octets
; External 0 interrupt
	.rept	8
		nop
	.endr
; External 1 interrupt
	.rept	8
		nop
	.endr













; -------------------------------
; DSP : routines en interruption
; -------------------------------
DSP_LSP_routine_interruption_I2S:
;-------------------------------------------------------------------------------------------------
;
; routine de replay, fabrication des samples
; bank 0 : 
; R28/R29/R30/R31
; +
; R18/R19/R20/R21/R22/R23/R24/R25/R26/R27
;
;-------------------------------------------------------------------------------------------------
; R28/R29/R30/R31 : utilisé par l'interruption

; - calculer le prochain noise : 0 ou $FFFF
; - calculer le prochain volume enveloppe
; - un canal = ( mixer

;		bt = ((((yms32)posA)>>31) | mixerTA) & (bn | mixerNA);
; (onde carrée normale OU mixerTA ) ET ( noise OU mixerNA ) 

;		vol  = (*pVolA)&bt;
;		volume ( suivant le pointeur, enveloppe ou fixe) ET mask du dessus
; - increment des positions apres : position A B C, position noise, position enveloppe

; mask = (mixerTA OR Tone calculé par frequence) AND ( mixerNA OR
; avec Tone calculé = FFFFFFFF bit 31=1 : bit 31 >> 31 = 1 : NEG 1 = -1

	.if		DSP_DEBUG
; change la couleur du fond
	movei	#$777,R26
	movei	#BG,r27
	storew	r26,(r27)
	.endif

	

;--------------------------
; gerer l'enveloppe
; - incrementer l'offset enveloppe
; partie entiere 16 bits : virgule 16 bits
; partie entiere and %1111 = position dans la sous partie d'enveloppe
; ( ( partie entiere >> 4 ) and %1 ) << 2 = pointeur sur la sous partie d'enveloppe


; si positif, limiter, masquer, à 11111 ( 5 bits:16 )

	movei	#YM_DSP_pointeur_enveloppe_en_cours,R24
	load	(R24),R24						; R24=pointeur sur la liste de 3 pointeur de sequence d'enveloppe : -1,0,1 : [ R24+(R25 * 4) ] + (R27*4)

YM_DSP_replay_sample_gere_env:
	movei	#YM_DSP_increment_enveloppe,R27
	movei	#YM_DSP_offset_enveloppe,R26
	load	(R27),R27
	load	(R26),R25				; R25 = offset en cours enveloppe
	add		R27,R25					; offset+increment 16:16
	
	move	R25,R23
	sharq	#16,R23					; on vire la virgule, on garde le signe
	moveq	#%1111,R21
	move	R23,R27
	and		R21,R27					; R27=partie entiere de l'offset AND 1111 = position dans la sous partie d'enveloppe
	

	sharq	#4,R23					; offset / 16, on garde le signe
	jr		mi, YM_DSP_replay_sample_offset_env_negatif
	moveq	#%1,R21
	movei	#$0FFFFFFF,R22
	and		R22,R25					; valeur positive : on limite la valeur pour ne pas qu'elle redevienne négative
	and		R21,R23					; R25 = pointeur sur la sous partie d'enveloppe
	
YM_DSP_replay_sample_offset_env_negatif:
	store	R25,(R26)				; sauvegarde YM_DSP_offset_enveloppe

	add		R23,R23					; R23*2 = partie entiere %1
	add		R27,R27					; R27*2
	add		R23,R23					; R23*4
	add		R27,R27					; R27*4
	
	add		R23,R24					; R24 = pointeur sur la partie d'enveloppe actuelle : R24+(R25 * 4) 
	load	(R24),R24				; R24 = pointeur sur la partie d'enveloppe actuelle :  [ R24+(R25 * 4) ]
	movei	#YM_DSP_volE,R26
	add		R27,R24					; [ R24+(R25 * 4) ] + (R27*4)
	load	(R24),R24				; R24 = volume actuel enveloppe
	or		R24,R24
	store	R24,(R26)				; volume de l'enveloppe => YM_DSP_volE


;--------------------------
; gérer le noise
; on avance le step de noise
; 	si on a 16 bits du haut>0 => on genere un nouveau noise
; 	et on masque le bas avec $FFFF
; l'increment de frequence du Noise est en 16:16

	movei	#YM_DSP_increment_Noise,R27
	movei	#YM_DSP_position_offset_Noise,R26
	movei	#YM_DSP_current_Noise_mask,R22
	load	(R27),R27
	load	(R26),R24
	load	(R22),R18			; R18 = current mask Noise
	add		R27,R24
	move	R24,R23
	shrq	#16,R23				; R23 = partie entiere, à zéro ?
	movei	#YM_DSP_replay_sample_pas_de_generation_nouveau_Noise,R20
	cmpq	#0,R23
	jump	eq,(R20)
	nop
; il faut generer un nouveau noise
; il faut masquer R24 avec $FFFF
	movei	#$FFFF,R23
	and		R23,R24				; YM_DSP_position_offset_Noise, juste virgule

	.if		DSP_random_Noise_generator_method=1
; generer un nouveau pseudo random methode 1
	MOVEI	#YM_DSP_current_Noise, R23		
	LOAD	(R23), R21			
	MOVEQ	#$01, R20			
	MOVE	R21, R27			
	MOVE	R21, R25			
	SHRQ	#$02, R25			
	AND		R20, R27			
	AND		R20, R25			
	XOR		R27, R25			
	MOVE	R21, R27			
	MOVE	R25, R20			
	SHRQ	#$01, R27			
	SHLQ	#$10, R20			
	OR		R27, R20			
	STORE	R20, (R23)	
	.endif

	.if		DSP_random_Noise_generator_method=2
; does not work !
; generer un nouveau pseudo random methode 2 : seed = seed * 1103515245 + 12345;
	MOVEI	#YM_DSP_Noise_seed, R23		
	LOAD	(R23), R21			
	movei	#1103515245,R20
	mult	R20,R21
	or		R21,R21
	movei	#12345,R27
	add		R27,R21
	STORE	R21, (R23)	
	.endif

	.if		DSP_random_Noise_generator_method=3
; wyhash16 : https://lemire.me/blog/2019/07/03/a-fast-16-bit-random-number-generator/
	MOVEI	#YM_DSP_Noise_seed, R23	
	movei	#$fc15,R20
	LOAD	(R23), R21
	add		R20,R21
	movei	#$2ab,R20
	mult	R20,R21
	move	R21,R25
	rorq	#16,R21
	xor		R25,R21
	store	R21,(R23)
	.endif

	.if		DSP_random_Noise_generator_method=4
; generer un nouveau pseudo random LFSR YM : https://www.smspower.org/Development/YM2413ReverseEngineeringNotes2018-05-13
	MOVEI	#YM_DSP_current_Noise, R23		
	LOAD	(R23), R21
	
	moveq	#1,R27
	move	R21,R20
	and		R27,R20				; 	bool output = state & 1;

	shrq	#1,R21				; 	state >>= 1;
	
	cmpq	#0,R20
	jr		eq,YM_DSP_replay_sample_LFSR_bit_0_egal_0
	
	nop
	movei	#$400181,R20
	xor		R20,R21
	
YM_DSP_replay_sample_LFSR_bit_0_egal_0:
	store	R21,(R23)
	.endif

; calcul masque 
	MOVEQ	#$01,R20
	and		R20,R21			; on garde juste le bit 0
	sub		R20,R21			; 0-1= -1 / 1-1=0 => mask sur 32 bits
	or		R21,R21
	store	R21,(R22)		; R21=>YM_DSP_current_Noise_mask
	move	R21,R18

YM_DSP_replay_sample_pas_de_generation_nouveau_Noise:
; en entrée : R24 = offset noise, R18 = current mask Noise

	store	R24,(R26)			; R24=>YM_DSP_position_offset_Noise


;---- ====> R18 = mask current Noise ----


;--------------------------
; ----- gerer digidrum A
	movei	#YM_DSP_pointeur_sample_digidrum_voie_A,R27					; pointeur << 21 + 11 bits de virgule 21:11
	load	(R27),R26
	movei	#YM_DSP_replay_sample_pas_de_digidrums_voie_A,R24
	cmpq	#0,R26
	jump	eq,(R24)
	nop

	move	R26,R24
	shrq	#YM_DSP_precision_virgule_digidrums,R24				; partie entiere du pointeur sample DG

	loadb	(R24),R23			; R23=sample DG sur 4 bits : de 0 a 15
	movei	#YM_DSP_table_de_volumes,R25
	shlq	#2,R23				; * 4 
	add		R23,R25
	movei	#YM_DSP_volA,R22
	movei	#YM_DSP_pointeur_sur_source_du_volume_A,R24
	load	(R25),R23
	store	R22,(R24)
	store	R23,(R22)			; volume du sample DG
	
	movei	#YM_DSP_increment_sample_digidrum_voie_A,R25				; increment << 21 + 11 bits de virgule 21:11
	movei	#YM_DSP_pointeur_fin_sample_digidrum_voie_A,R24
	load	(R25),R25
	load	(R24),R24					; pointeur de fin 21:11
	add		R25,R26						; pointeur + increment 21:11
	cmp		R24,R26
	jr		mi,YM_DSP_replay_DG_pas_fin_de_sample_voie_A
	nop
	moveq	#0,R26
YM_DSP_replay_DG_pas_fin_de_sample_voie_A:
	store	R26,(R27)			; YM_DSP_pointeur_sample_digidrum_voie_A

YM_DSP_replay_sample_pas_de_digidrums_voie_A:


; ----- gerer digidrum B
	movei	#YM_DSP_pointeur_sample_digidrum_voie_B,R27					; pointeur << 21 + 11 bits de virgule 21:11
	load	(R27),R26
	movei	#YM_DSP_replay_sample_pas_de_digidrums_voie_B,R24
	cmpq	#0,R26
	jump	eq,(R24)
	nop

	move	R26,R24
	shrq	#YM_DSP_precision_virgule_digidrums,R24				; partie entiere du pointeur sample DG

	loadb	(R24),R23			; R23=sample DG sur 4 bits : de 0 a 15
	movei	#YM_DSP_table_de_volumes,R25
	shlq	#2,R23				; * 4 
	add		R23,R25
	movei	#YM_DSP_volB,R22
	movei	#YM_DSP_pointeur_sur_source_du_volume_B,R24
	load	(R25),R23
	store	R22,(R24)
	store	R23,(R22)			; volume du sample DG
	
	movei	#YM_DSP_increment_sample_digidrum_voie_B,R25				; increment << 21 + 11 bits de virgule 21:11
	movei	#YM_DSP_pointeur_fin_sample_digidrum_voie_B,R24
	load	(R25),R25
	load	(R24),R24					; pointeur de fin 21:11
	add		R25,R26						; pointeur + increment 21:11
	cmp		R24,R26
	jr		mi,YM_DSP_replay_DG_pas_fin_de_sample_voie_B
	nop
	moveq	#0,R26
YM_DSP_replay_DG_pas_fin_de_sample_voie_B:
	store	R26,(R27)			; YM_DSP_pointeur_sample_digidrum_voie_B

YM_DSP_replay_sample_pas_de_digidrums_voie_B:


; ----- gerer digidrum C
	movei	#YM_DSP_pointeur_sample_digidrum_voie_C,R27					; pointeur << 21 + 11 bits de virgule 21:11
	load	(R27),R26
	movei	#YM_DSP_replay_sample_pas_de_digidrums_voie_C,R24
	cmpq	#0,R26
	jump	eq,(R24)
	nop

	move	R26,R24
	shrq	#YM_DSP_precision_virgule_digidrums,R24				; partie entiere du pointeur sample DG

	loadb	(R24),R23			; R23=sample DG sur 4 bits : de 0 a 15
	movei	#YM_DSP_table_de_volumes,R25
	shlq	#2,R23				; * 4 
	add		R23,R25
	movei	#YM_DSP_volC,R22
	movei	#YM_DSP_pointeur_sur_source_du_volume_C,R24
	load	(R25),R23
	store	R22,(R24)
	store	R23,(R22)			; volume du sample DG
	
	movei	#YM_DSP_increment_sample_digidrum_voie_C,R25				; increment << 21 + 11 bits de virgule 21:11
	movei	#YM_DSP_pointeur_fin_sample_digidrum_voie_C,R24
	load	(R25),R25
	load	(R24),R24					; pointeur de fin 21:11
	add		R25,R26						; pointeur + increment 21:11
	cmp		R24,R26
	jr		mi,YM_DSP_replay_DG_pas_fin_de_sample_voie_C
	nop
	moveq	#0,R26
YM_DSP_replay_DG_pas_fin_de_sample_voie_C:
	store	R26,(R27)			; YM_DSP_pointeur_sample_digidrum_voie_C

YM_DSP_replay_sample_pas_de_digidrums_voie_C:



;---- ====> R18 = mask current Noise ----
;--------------------------
; gérer les voies A B C 
; ---------------


; canal A

	movei	#YM_DSP_Mixer_NA,R26

	move	R18,R24				; R24 = on garde la masque du current Noise

	load	(R26),R26			; YM_DSP_Mixer_NA
	or		R26,R18				; YM_DSP_Mixer_NA OR Noise
; R18 = Noise OR mask du registre 7 de mixage du Noise A


	movei	#YM_DSP_increment_canal_A,R27
	movei	#YM_DSP_position_offset_A,R26
	load	(R27),R27
	load	(R26),R25
		
	add		R27,R25
	store	R25,(R26)							; YM_DSP_position_offset_A
	shrq	#31,R25
	neg		R25									; 0 devient 0, 1 devient -1 ($FFFFFFFF)
	
; R25 = onde carrée A

	movei	#YM_DSP_Mixer_TA,R26
	load	(R26),R26
	or		R26,R25
; R25 = onde carrée A OR mask du registre 7 de mixage Tone A


; Noise AND Tone

	movei	#YM_DSP_pointeur_sur_source_du_volume_A,R26
	and		R18,R25					; R25 = Noise and Tone

	load	(R26),R27				; R20 = pointeur sur la source de volume pour le canal A
	load	(r27),R20				; R20=volume pour le canal A 0 à 32767
	
	;movei	#pointeur_buffer_de_debug,R26
	;load	(R26),R18
	;store	R20,(R18)
	;addq	#4,R18
	;store	R18,(R26)
	;nop
	
	
	and		R25,R20					; R20=volume pour le canal A
; R20 = sample canal A



; ---------------
; canal B
	movei	#YM_DSP_Mixer_NB,R26
	move	R24,R18				; R24 = masque du current Noise
	
	load	(R26),R26
	or		R26,R18

; R18 = Noise OR mask du registre 7 de mixage du Noise B

	movei	#YM_DSP_increment_canal_B,R27
	movei	#YM_DSP_position_offset_B,R26
	load	(R27),R27
	load	(R26),R25
	add		R27,R25
	or		R25,R25
	store	R25,(R26)							; YM_DSP_position_offset_B
	shrq	#31,R25
	neg		R25									; 0 devient 0, 1 devient -1 ($FFFFFFFF)
; R25 = onde carrée B

	movei	#YM_DSP_Mixer_TB,R26
	load	(R26),R26
	or		R26,R25
; R25 = onde carrée B OR mask du registre 7 de mixage Tone B

; Noise AND Tone

	movei	#YM_DSP_pointeur_sur_source_du_volume_B,R23
	and		R18,R25					; R25 = Noise and Tone
	load	(R23),R23				; R23 = pointeur sur la source de volume pour le canal B
	load	(r23),R23				; R23=volume pour le canal B 0 à 32767
	and		R25,R23					; R23=volume pour le canal B
; R23 = sample canal B

; ---------------
; canal C
	movei	#YM_DSP_Mixer_NC,R26
	move	R24,R18				; R24 = masque du current Noise
	
	load	(R26),R26
	or		R26,R18

; R18 = Noise OR mask du registre 7 de mixage du Noise C

	movei	#YM_DSP_increment_canal_C,R27
	movei	#YM_DSP_position_offset_C,R26
	load	(R27),R27
	load	(R26),R25
	add		R27,R25
	or		R25,R25
	store	R25,(R26)							; YM_DSP_position_offset_B
	shrq	#31,R25
	neg		R25									; 0 devient 0, 1 devient -1 ($FFFFFFFF)
; R25 = onde carrée C

	movei	#YM_DSP_Mixer_TC,R26
	load	(R26),R26
	or		R26,R25
; R25 = onde carrée B OR mask du registre 7 de mixage Tone C

; Noise AND Tone

	movei	#YM_DSP_pointeur_sur_source_du_volume_C,R22
	and		R18,R25					; R25 = Noise and Tone
	load	(R22),R22				; R23 = pointeur sur la source de volume pour le canal B
	load	(r22),R22				; R23=volume pour le canal B 0 à 32767
	and		R25,R22					; R23=volume pour le canal B
; R22 = sample canal C

; sans stereo : R20=A / R23=B / R22=C / R21=//

; mono desactivé
	.if		STEREO=0
	shrq	#1,R20					; quand volume maxi = 32767
	;shrq	#1,R21					; quand volume maxi = 32767
	shrq	#1,R23
	shrq	#1,R22
	add		R23,R20					; R20 = R20=canal A + R23=canal B
	;add		R21,R20					; R20 = R20=canal A + R23=canal B + R21=canal D
	movei	#32768,R27
	add		R22,R20					; + canal C
	movei	#L_I2S,r26
	sub		R27,R20					; resultat signé sur 16 bits
	movei	#L_I2S+4,r24
	store	r20,(r26)				; write right channel
	store	r20,(r24)				; write left channel
	.endif

	
	.if		STEREO=1

	movei	#YM_DSP_Voie_A_pourcentage_Droite,R24
	move	R20,R26					; R26=A
	mult	R24,R26
	shrq	#STEREO_shit_bits,R26
	
	movei	#YM_DSP_Voie_B_pourcentage_Droite,R24
	move	R23,R25					; R27=B
	mult	R24,R25
	shrq	#STEREO_shit_bits,R25
	
	movei	#YM_DSP_Voie_C_pourcentage_Droite,R24
	move	R22,R18					; R18=C
	mult	R24,R18
	shrq	#STEREO_shit_bits,R18

	add		R26,R25					; R27=A+B

	movei	#YM_DSP_Voie_D_pourcentage_Droite,R24
	move	R21,R26					; R26=D
	mult	R24,R26
	shrq	#STEREO_shit_bits,R26
	
	add		R18,R25
	add		R26,R25					; R25=droite


	movei	#YM_DSP_Voie_A_pourcentage_Gauche,R24
	mult	R24,R20
	shrq	#STEREO_shit_bits,R20
	
	movei	#YM_DSP_Voie_B_pourcentage_Gauche,R24
	mult	R24,R23
	shrq	#STEREO_shit_bits,R23
	
	movei	#YM_DSP_Voie_C_pourcentage_Gauche,R24
	mult	R24,R22
	shrq	#STEREO_shit_bits,R22

	add		R20,R23					; R23=A+B

	movei	#YM_DSP_Voie_D_pourcentage_Gauche,R24
	mult	R24,R21
	shrq	#STEREO_shit_bits,R21

	movei	#32768,R27
	
	add		R22,R23
	add		R21,R23					; R23=gauche

	sub		R27,R25
	movei	#L_I2S,r26
	sub		R27,R23
	movei	#L_I2S+4,r24

	store	r25,(r26)				; write right channel
	store	r23,(r24)				; write left channel

	.endif

	.if		DSP_DEBUG
; change la couleur du fond
	movei	#$000,R26
	movei	#BG,r27
	storew	r26,(r27)
	.endif

;------------------------------------	
; return from interrupt I2S
	load	(r31),r28	; return address
	bset	#10,r29		; clear latch 1 = I2S
	;bset	#11,r29		; clear latch 1 = timer 1
	;bset	#12,r29		; clear latch 1 = timer 2
	bclr	#3,r29		; clear IMASK
	addq	#4,r31		; pop from stack
	addqt	#2,r28		; next instruction
	jump	t,(r28)		; return
	store	r29,(r30)	; restore flags




















;--------------------------------------------
; ---------------- Timer 1 ------------------
;--------------------------------------------
; autorise interruptions, pour timer I2S
	.if		I2S_during_Timer1=1
	bclr	#3,r13		; clear IMASK
	store	r13,(r16)	; restore flags
	.endif

DSP_LSP_routine_interruption_Timer1:
	.if		DSP_DEBUG_T1
; change la couleur du fond
	movei	#$077,R1
	movei	#BG,r0
	loadw	(r0),r1
	addq	#$1,r1
	storew	r1,(r0)
	.endif


;-------------------------------------------------------------------------------------------------
; -------------------------------------------------------------------------------
; routine de lecture des registres YM
; bank 0 : 
 ; gestion timer deplacé sur :
; R12(R28)/R13(R29)/R16(R30)
; +
; R0/R1/R2/R3/R4/R5/R6/R7/R8/R9/R10/R11 + R14
; -------------------------------------------------------------------------------
	;-------------------------------------------------------------------------------------------------
; COSO = 11+3 registres
	movei		#YM_registres_Coso,R1
	moveq		#1,R8



; round(  ((freq_YM / 16) / frequence_replay) * 65536) /x;	
; 
; registres 0+1 = frequence voie A
	loadb		(R1),R2						; registre 0
	add			R8,R1
	loadb		(R1),R3						; registre 1
	movei		#%1111,R7
	add			R8,R1


	and			R7,R3
	movei		#YM_frequence_predivise,R5
	shlq		#8,R3
	load		(R5),R5
	add			R2,R3						; R3 = frequence YM canal A

	move		R5,R6
	
	div			r3,R5
	or			R5,R5
	shlq		#16,R5
	
	movei		#YM_DSP_increment_canal_A,R2
	store		R5,(R2)

; registres 2+3 = frequence voie B
	loadb		(R1),R2						; registre 2
	add			R8,R1
	loadb		(R1),R3						; registre 3
	add			R8,R1

	and			R7,R3
	shlq		#8,R3
	move		R6,R5						; R5=YM_frequence_predivise
	add			R2,R3						; R3 = frequence YM canal B
	
	div			r3,R5
	or			R5,R5
	shlq		#16,R5
	
	movei		#YM_DSP_increment_canal_B,R2
	store		R5,(R2)
	
; registres 4+5 = frequence voie C
	loadb		(R1),R2						; registre 4
	add			R8,R1
	loadb		(R1),R3						; registre 5
	add			R8,R1

	and			R7,R3
	shlq		#8,R3
	move		R6,R5						; R5=YM_frequence_predivise
	add			R2,R3						; R3 = frequence YM canal C
	
	div			r3,R5
	or			R5,R5
	shlq		#16,R5
	
	movei		#YM_DSP_increment_canal_C,R2
	store		R5,(R2)
	
; registre 6
; 5 bit noise frequency
	loadb		(R1),R2						; registre 6
	movei		#%11111,R7
	add			R8,R1
	
	and			R7,R2						; on ne garde que 5 bits
	jr			ne,DSP_lecture_registre6_pas_zero
	move		R6,R5						; R5=YM_frequence_predivise

	moveq		#1,R2
DSP_lecture_registre6_pas_zero:
	
	movei		#YM_DSP_increment_Noise,R3
	div			R2,R5
	or			R5,R5
	; shlq		#15,R5						; on laisse l'increment frequence Noise sur 16(entier):16(virgule)
	store		R5,(R3)

; registre 7 
; 6 bits interessants
;	Noise	 Tone
;	C B A    C B A
	loadb		(R1),R2						; registre 7
	add			R8,R1


; bit 0 = Tone A
	move		R2,R4
	moveq		#%1,R3
	and			R3,R4					; 0 ou 1
	movei		#YM_DSP_Mixer_TA,R5
	;subq		#1,R4					; 0=>-1 / 1=>0 
	neg			R4						; 0=>0 / 1=>-1
	shlq		#1,R3					; bit suivant
	store		R4,(R5)

; bit 1 = Tone B
	move		R2,R4
	movei		#YM_DSP_Mixer_TB,R5
	and			R3,R4					; 0 ou 1
	shrq		#1,R4
	;subq		#1,R4					; 0=>-1 / 1=>0 
	neg			R4						; 0=>0 / 1=>-1
	shlq		#1,R3					; bit suivant
	store		R4,(R5)

; bit 2 = Tone C
	move		R2,R4
	movei		#YM_DSP_Mixer_TC,R5
	and			R3,R4					; 0 ou 1
	shrq		#2,R4
	;subq		#1,R4					; 0=>-1 / 1=>0 
	neg			R4						; 0=>0 / 1=>-1
	shlq		#1,R3					; bit suivant
	store		R4,(R5)
	
; bit 3 = Noise A
	move		R2,R4
	movei		#YM_DSP_Mixer_NA,R5
	and			R3,R4					; 0 ou 1
	shrq		#3,R4
	;subq		#1,R4					; 0=>-1 / 1=>0 
	neg			R4						; 0=>0 / 1=>-1
	shlq		#1,R3					; bit suivant
	store		R4,(R5)
	
; bit 4 = Noise B
	move		R2,R4
	movei		#YM_DSP_Mixer_NB,R5
	and			R3,R4					; 0 ou 1
	shrq		#4,R4
	neg			R4						; 0=>0 / 1=>-1
	;subq		#1,R4					; 0=>-1 / 1=>0 
	shlq		#1,R3					; bit suivant
	store		R4,(R5)
	
; bit 5 = Noise C
	move		R2,R4
	movei		#YM_DSP_Mixer_NC,R5
	and			R3,R4					; 0 ou 1
	shrq		#5,R4
	neg			R4						; 0=>0 / 1=>-1
;	subq		#1,R4					; 0=>-1 / 1=>0 
	shlq		#1,R3					; bit suivant
	store		R4,(R5)
	

	movei		#YM_DSP_table_de_volumes,R14

; registre 8 = volume canal A
; B4=1 bit =M / M=0=>volume fixe / M=1=>volume enveloppe
; B3/B2/B1/B0 = volume fixe pour le canal A
;	Noise	 Tone
;	C B A    C B A
	loadb		(R1),R2						; registre 8
	add			R8,R1	

	move		R2,R4
	movei		#YM_DSP_registre8,R6
	moveq		#%1111,R3
	store		R4,(R6)					; sauvegarde la valeur de volume sur 16, pour DG
	movei		#YM_DSP_volE,R5
	and			R3,R4
	
	shlq		#2,R4					; volume sur 16 *4 
	load		(R14+R4),R4

	movei		#YM_DSP_volA,R6
	store		R4,(R6)

	movei		#YM_DSP_pointeur_sur_source_du_volume_A,R3
	btst		#4,R2					; test bit M : M=0 => volume contenu dans registre 8 / M=1 => volume d'env
	jr			ne,DSP_lecture_registre8_pas_volume_A
	nop
	
	move		R6,R5
	
DSP_lecture_registre8_pas_volume_A:
	store		R5,(R3)


; registre 9 = volume canal B
; B4=1 bit =M / M=0=>volume fixe / M=1=>volume enveloppe
; B3/B2/B1/B0 = volume fixe pour le canal B
;	Noise	 Tone
;	C B A    C B A
	loadb		(R1),R2						; registre 9
	add			R8,R1	

	move		R2,R4
	movei		#YM_DSP_registre9,R6
	moveq		#%1111,R3
	store		R4,(R6)					; sauvegarde la valeur de volume sur 16, pour DG
	movei		#YM_DSP_volE,R5
	and			R3,R4

	shlq		#2,R4					; volume sur 16 *4 
	load		(R14+R4),R4

	movei		#YM_DSP_volB,R6
	store		R4,(R6)

	movei		#YM_DSP_pointeur_sur_source_du_volume_B,R3

	btst		#4,R2
	jr			ne,DSP_lecture_registre9_pas_env
	nop
	
	move		R6,R5
	
DSP_lecture_registre9_pas_env:
	store		R5,(R3)

; registre 10 = volume canal C
; B4=1 bit =M / M=0=>volume fixe / M=1=>volume enveloppe
; B3/B2/B1/B0 = volume fixe pour le canal C
;	Noise	 Tone
;	C B A    C B A
	loadb		(R1),R2						; registre 10
	add			R8,R1	

	move		R2,R4
	movei		#YM_DSP_registre10,R6
	moveq		#%1111,R3
	store		R4,(R6)					; sauvegarde la valeur de volume sur 16, pour DG
	movei		#YM_DSP_volE,R5
	and			R3,R4
	
	shlq		#2,R4					; volume sur 16 *4 
	load		(R14+R4),R4
	
	movei		#YM_DSP_volC,R6
	store		R4,(R6)

	movei		#YM_DSP_pointeur_sur_source_du_volume_C,R3

	btst		#4,R2
	jr			ne,DSP_lecture_registre10_pas_env
	nop

	move		R6,R5
	
DSP_lecture_registre10_pas_env:
	store		R5,(R3)



; registre 11 & 12 = frequence de l'enveloppe sur 16 bits
	loadb		(R1),R2						; registre 11 = 8 bits du bas
	add			R8,R1
	loadb		(R1),R3						; registre 12 = 8 bits du haut

	movei		#YM_frequence_predivise,R5
	add			R8,R1
	shlq		#8,R3
	load		(R5),R5						; R5=YM_frequence_predivise
	add			R2,R3						; R3 = frequence YM canal B

	jr			ne,DSP_lecture_registre11_12_pas_zero
	nop
	moveq		#0,R5
	jr			DSP_lecture_registre11_12_zero
	nop
	
DSP_lecture_registre11_12_pas_zero:	
	div			r3,R5

DSP_lecture_registre11_12_zero:	
	movei		#YM_DSP_increment_enveloppe,R2
	or			R5,R5
	store		R5,(R2)


; registre 13 = envelop shape
	loadb		(R1),R2						; registre 13 = Envelope shape control

	movei		#YM_DSP_registre13,R6

	add			R8,R1

	store		R2,(R6)					; sauvegarde la valeur env shape registre 13

; tester si bit 7 = 1 => ne pas modifier l'env en cours

	movei		#DSP_lecture_registre13_pas_env,R3
	btst		#7,R2
	jump		ne,(R3)
	nop

; - choix de la bonne enveloppe
	sub			R8,R1
	bset		#7,R2
	storeb		R2,(R1)
	add			R8,R1
	
	
	moveq		#%1111,R5
	movei		#$FFF00000,R3						; 16 bits du haut = -16, virgule = 0
	and			R5,R2
	movei		#YM_DSP_offset_enveloppe,R5
	movei		#YM_DSP_pointeur_enveloppe_en_cours,R0
	store		R3,(R5)
	movei		#YM_DSP_liste_des_enveloppes,R4
	shlq		#2,R2								; numero d'env dans registre 13 * 4
	add			R2,R4
	load		(R4),R4
	store		R4,(R0)								; pointe sur enveloppe

DSP_lecture_registre13_pas_env:


	.if		1=0
; ----------------
; registre R11 = flag effets sur les voies : A=bit 0, B=bit 1, C=bit 2, bit 3=buzzer , bit 4=Sinus Sid
	movei	#YM_flag_effets_sur_les_voies,R11
	load	(R11),R11

;--------------------------------
; gestion des effets par voie
; ------- effet sur voie A ?
	;movei		#YM_flag_effets_voie_A,R3
	;load		(R3),R3
	movei		#DSP_lecture_registre_effet_voie_A_pas_d_effet,R4
	;cmpq		#0,R3
	btst		#0,R11
	jump		eq,(R4)
	
	loadb		(R1),R2						; octet 1 effet sur la voie : 8 bits du haut = index prediv ( sur 3 bits 0-7 )
	add			R8,R1
	loadb		(R1),R3						; octet 2 effet sur la voie : 8 bits du bas = diviseur
	add			R8,R1

	movei		#DSP_lecture_registre_effet_voie_A_pas_de_DG,R4
	btst		#7,R2
	jump		eq,(R4)

;--------------------------------
; digidrums sur la voie A
;--------------------------------
	moveq		#%111,R5
	movei		#YM_DSP_table_prediviseur,R6
	and			R5,R2						; 3 bits de R2 = prediviseur
	shlq		#2,R2						; * 4 
	add			R2,R6
	load		(R6),R6						; R6=prediviseur
	
	mult		R6,R3						; R3=prediviseur * diviseur
	movei		#YM_DSP_frequence_MFP,R5
	div			R3,R5						; frequence du MFP / ( prediviseur * diviseur )
	movei		#DSP_frequence_de_replay_reelle_I2S,R4
	load		(R4),R4
	or			R5,R5
	shlq		#YM_DSP_precision_virgule_digidrums,R5
	div			R4,R5						; R5=increment digidrum=(frequence du MFP / ( prediviseur * diviseur ) ) / frequence_de_replay_reelle_I2S en 16:16
	movei		#YM_DSP_table_digidrums,R3
	movei		#YM_DSP_registre8,R6
	load		(R6),R6
	shlq		#3,R6						; numero sample * 8
	add			R6,R3						; pointe sur pointeur sample + pointeur fin de sample
	load		(R3),R2						; R2=pointeur debut sample DG en 21:11
	movei		#YM_DSP_pointeur_sample_digidrum_voie_A,R6
	addq		#4,R3
	load		(R3),R4						; R4=pointeur fin sample DG en 21:11
	store		R2,(R6)						; stocke debut sample DG en 21:11
	addq		#4,R6						; passe au pointeur de fin du sample
	store		R4,(R6)						; stocke fin sample DG en 21:11
	addq		#4,R6						; passe au pointeur de fin du sample
	store		R5,(R6)						; stocke increment sample DG en 21:11

; force volume sur volA, mixerTA et mixerNA = $FFFFFFFF
	movei		#YM_DSP_pointeur_sur_source_du_volume_A,R3
	movei		#-1,R2
	movei		#YM_DSP_volA,R5
	movei		#YM_DSP_Mixer_NA,R4
	store		R5,(R3)
	movei		#YM_DSP_Mixer_TA,R7
	store		R2,(R4)
	movei		#DSP_lecture_registre_effet_voie_A_pas_d_effet,R3
	store		R2,(R7)
	
	jump		(R3)		; saute par dessus la routine SID
	nop
	
; numero sample DG = registre 8
; R2 and 11 bits = frequence de replay : table de frequence mfp -$400 : 
; stop, no function executed		: 256 valeurs = 0
; subdivider divides by 4
; subdivider divides by 10
; subdivider divides by 16
; subdivider divides by 16
; subdivider divides by 50
; subdivider divides by 64
; subdivider divides by 100
; subdivider divides by 200
;
; ( 2457600 / DSP_frequence_de_replay_reelle_I2S ) / prediv (4/10/16/16/50/64/100/200) / valeur sur 8 bits
; => ( 2457600 / DSP_frequence_de_replay_reelle_I2S ) (précalcumé) / ( prediv * valeur )
; mfpPrediv[8] = {0,4,10,16,50,64,100,200};
; premiere valeur = index prediv ( sur 3 bits 0-7 )
; deuxieme valeur = diviseur

DSP_lecture_registre_effet_voie_A_pas_de_DG:

DSP_lecture_registre_effet_voie_A_pas_d_effet:

; -----------------------------
; ------- effet sur voie B ?

;	movei		#YM_flag_effets_voie_B,R3
;	load		(R3),R3
	movei		#DSP_lecture_registre_effet_voie_B_pas_d_effet,R4
	;cmpq		#0,R3
	btst		#1,R11
	jump		eq,(R4)
	
	loadb		(R1),R2						; octet 1 effet sur la voie : 8 bits du haut = index prediv ( sur 3 bits 0-7 )
	add			R8,R1
	loadb		(R1),R3						; octet 2 effet sur la voie : 8 bits du bas = diviseur
	add			R8,R1

	movei		#DSP_lecture_registre_effet_voie_B_pas_de_DG,R4
	btst		#7,R2
	jump		eq,(R4)
; digidrums sur la voie B
	moveq		#%111,R5
	movei		#YM_DSP_table_prediviseur,R6
	and			R5,R2						; 3 bits de R2 = prediviseur
	shlq		#2,R2						; * 4 
	add			R2,R6
	load		(R6),R6						; R6=prediviseur
	
	mult		R6,R3						; R3=prediviseur * diviseur
	movei		#YM_DSP_frequence_MFP,R5
	div			R3,R5						; frequence du MFP / ( prediviseur * diviseur )
	movei		#DSP_frequence_de_replay_reelle_I2S,R4
	load		(R4),R4
	or			R5,R5
	shlq		#YM_DSP_precision_virgule_digidrums,R5
	div			R4,R5						; R5=increment digidrum=(frequence du MFP / ( prediviseur * diviseur ) ) / frequence_de_replay_reelle_I2S en 16:16
	movei		#YM_DSP_table_digidrums,R3
	movei		#YM_DSP_registre9,R6
	load		(R6),R6
	shlq		#3,R6						; numero sample * 8
	add			R6,R3						; pointe sur pointeur sample + pointeur fin de sample
	load		(R3),R2						; R2=pointeur debut sample DG en 21:11
	movei		#YM_DSP_pointeur_sample_digidrum_voie_B,R6
	addq		#4,R3
	load		(R3),R4						; R4=pointeur fin sample DG en 21:11
	store		R2,(R6)						; stocke debut sample DG en 21:11
	addq		#4,R6						; passe au pointeur de fin du sample
	store		R4,(R6)						; stocke fin sample DG en 21:11
	addq		#4,R6						; passe au pointeur de fin du sample
	store		R5,(R6)						; stocke increment sample DG e: 21:11

; force volume sur volB, mixerTB et mixerNB = $FFFFFFFF
	movei		#YM_DSP_pointeur_sur_source_du_volume_B,R3
	movei		#-1,R2
	movei		#YM_DSP_volB,R5
	movei		#YM_DSP_Mixer_NB,R4
	store		R5,(R3)
	movei		#YM_DSP_Mixer_TB,R7
	store		R2,(R4)
	movei		#DSP_lecture_registre_effet_voie_B_pas_d_effet,R3
	store		R2,(R7)
	
	jump		(R3)		; saute par dessus la routine SID
	nop

DSP_lecture_registre_effet_voie_B_pas_de_DG:
DSP_lecture_registre_effet_voie_B_pas_d_effet:



; -----------------------------
; ------- effet sur voie C ?
	;movei		#YM_flag_effets_voie_C,R3
	;load		(R3),R3
	movei		#DSP_lecture_registre_effet_voie_C_pas_d_effet,R4
	;cmpq		#0,R3
	btst		#2,R11
	jump		eq,(R4)
	
	loadb		(R1),R2						; octet 1 effet sur la voie : 8 bits du haut = index prediv ( sur 3 bits 0-7 )
	add			R8,R1
	loadb		(R1),R3						; octet 2 effet sur la voie : 8 bits du bas = diviseur
	add			R8,R1

	movei		#DSP_lecture_registre_effet_voie_C_pas_de_DG,R4
	btst		#7,R2
	jump		eq,(R4)
; digidrums sur la voie C
	moveq		#%111,R5
	
	
	movei		#YM_DSP_table_prediviseur,R6
	and			R5,R2						; 3 bits de R2 = prediviseur
	shlq		#2,R2						; * 4 
	add			R2,R6
	load		(R6),R6						; R6=prediviseur
	
	mult		R6,R3						; R3=prediviseur * diviseur
	movei		#YM_DSP_frequence_MFP,R5
	div			R3,R5						; frequence du MFP / ( prediviseur * diviseur )
	movei		#DSP_frequence_de_replay_reelle_I2S,R4
	load		(R4),R4
	or			R5,R5
	shlq		#YM_DSP_precision_virgule_digidrums,R5
	div			R4,R5						; R5=increment digidrum=(frequence du MFP / ( prediviseur * diviseur ) ) / frequence_de_replay_reelle_I2S en 16:16
	movei		#YM_DSP_table_digidrums,R3
	movei		#YM_DSP_registre10,R6
	load		(R6),R6
	shlq		#3,R6						; numero sample * 8
	add			R6,R3						; pointe sur pointeur sample + pointeur fin de sample
	load		(R3),R2						; R2=pointeur debut sample DG en 21:11
	movei		#YM_DSP_pointeur_sample_digidrum_voie_C,R6
	addq		#4,R3
	load		(R3),R4						; R4=pointeur fin sample DG en 21:11
	store		R2,(R6)						; stocke debut sample DG en 21:11
	addq		#4,R6						; passe au pointeur de fin du sample
	store		R4,(R6)						; stocke fin sample DG en 21:11
	addq		#4,R6						; passe au pointeur de fin du sample
	store		R5,(R6)						; stocke increment sample DG en 21:11

; force volume sur volC, mixerTC et mixerNC = $FFFFFFFF
	movei		#YM_DSP_pointeur_sur_source_du_volume_C,R3
	movei		#-1,R2
	movei		#YM_DSP_volC,R5
	movei		#YM_DSP_Mixer_NC,R4
	store		R5,(R3)
	movei		#YM_DSP_Mixer_TC,R7
	store		R2,(R4)
	movei		#DSP_lecture_registre_effet_voie_C_pas_d_effet,R3
	store		R2,(R7)
	
	jump		(R3)		; saute par dessus la routine SID
	nop	

DSP_lecture_registre_effet_voie_C_pas_de_DG:
DSP_lecture_registre_effet_voie_C_pas_d_effet:


	.endif

;---> precalculer les valeurs qui ne bougent pas pendant 1 VBL entiere	

; debug raz pointeur buffer debug
	;movei		#pointeur_buffer_de_debug,R0
	;movei		#buffer_de_debug,R1
	;store		R1,(R0)	
	;nop

; reading coso registers is done
	movei	#DSP_flag_registres_YM_lus,R2
	moveq	#1,R0
	store	R0,(R2)


	movei	#vbl_counter_replay_DSP,R0
	load	(R0),R1
	addq	#1,R1
	store	R1,(R0)
	
	.if		DSP_DEBUG_T1
; change la couleur du fond
	movei	#$000,R0
	movei	#BG,R1
	;storew	R0,(R1)
	.endif

;------------------------------------	
; return from interrupt Timer 1
	load	(r31),r12	; return address
	;bset	#10,r29		; clear latch 1 = I2S
	bset	#11,r13		; clear latch 1 = timer 1
	;bset	#12,r29		; clear latch 1 = timer 2
	bclr	#3,r13		; clear IMASK
	addq	#4,r31		; pop from stack
	addqt	#2,r12		; next instruction
	jump	t,(r12)		; return
	store	r13,(r16)	; restore flags


; ------------------- N/A ------------------
DSP_LSP_routine_interruption_Timer2:
; ------------------- N/A ------------------













; ----------------------------------------------
; routine d'init du DSP
; registres bloqués par les interruptions : R29/R30/R31 ?
DSP_routine_init_DSP:
; assume run from bank 1
	movei	#DSP_ISP+(DSP_STACK_SIZE*4),r31			; init isp
	moveq	#0,r1
	moveta	r31,r31									; ISP (bank 0)
	movei	#DSP_USP+(DSP_STACK_SIZE*4),r31			; init usp
	
; -------------------------------------------------------------------------------
; calcul de la frequence prédivisee pour le YM
; ((YM_frequence_YM2149/16)*65536)/DSP_Audio_frequence

	movei	#YM_frequence_YM2149,r0
	shlq	#16-4-2,r0					; /16 puis * 65536
	
	movei	#DSP_frequence_de_replay_reelle_I2S,r2
	load	(r2),r2
	
	div		r2,r0
	or		r0,r0					; attente fin de division
	shlq	#2,r0					; ramene a *65536

	
	movei	#YM_frequence_predivise,r1
	store	r0,(r1)



;calcul de ( 1<<31) / frequence de replay réelle )

	moveq	#1,R0
	shlq	#31,R0
	div		r2,r0
	or		R0,R0
	
	movei	#DSP_UN_sur_frequence_de_replay_reelle_I2S,r1
	store	R0,(R1)



; init I2S
	movei	#SCLK,r10
	movei	#SMODE,r11
	movei	#DSP_parametre_de_frequence_I2S,r12
	movei	#%001101,r13			; SMODE bascule sur RISING
	load	(r12),r12				; SCLK
	store	r12,(r10)
	store	r13,(r11)

; init Timer 1

	movei	#182150,R10				; 26593900 / 146 = 182150
	movei	#YM_frequence_replay,R11
	load	(R11),R11
	or		R11,R11
	div		R11,R10
	or		R10,R10
	move	R10,R13
	
	subq	#1,R13					; -1 pour parametrage du timer 1
	
	

; 26593900 / 50 = 531 878 => 2 × 73 × 3643 => 146*3643
	movei	#JPIT1,r10				; F10000
	;movei	#JPIT2,r11				; F10002
	movei	#146-1,r12				; Timer 1 Pre-scaler
	;movei	#3643-1,r13				; Timer 1 Divider  
	
	shlq	#16,r12
	or		R13,R12
	
	store	r12,(r10)				; JPIT1 & JPIT2


; init timer 2

;	movei	#JPIT3,r10				; F10004
;	movei	#JPIT4,r11				; F10006



; enable interrupts
	movei	#D_FLAGS,r28
	
	movei	#D_I2SENA|D_TIM1ENA|REGPAGE,r29			; I2S+Timer 1
	
	;movei	#D_TIM1ENA|REGPAGE,r29					; Timer 1 only
	;movei	#D_I2SENA|REGPAGE,r29					; I2S only
	;movei	#D_TIM2ENA|REGPAGE,r29					; Timer 2 only
	
	store	r29,(r28)



DSP_boucle_centrale:
	movei	#DSP_boucle_centrale,R20
	jump	(R20)
	nop

	


	.phrase


; datas DSP
DSP_flag_registres_YM_lus:			dc.l			0

vbl_counter_replay_DSP:				dc.l			0
YM_DSP_pointeur_sur_table_des_pointeurs_env_Buzzer:		dc.l		0

YM_DSP_registre8:			dc.l			0
YM_DSP_registre9:			dc.l			0
YM_DSP_registre10:			dc.l			0
YM_DSP_registre13:			dc.l			0

DSP_frequence_de_replay_reelle_I2S:					dc.l			0
DSP_UN_sur_frequence_de_replay_reelle_I2S:			dc.l			0
DSP_parametre_de_frequence_I2S:						dc.l			0

YM_DSP_increment_canal_A:			dc.l			0
YM_DSP_increment_canal_B:			dc.l			0
YM_DSP_increment_canal_C:			dc.l			0
YM_DSP_increment_Noise:				dc.l			0
YM_DSP_increment_enveloppe:			dc.l			0

YM_DSP_Mixer_TA:					dc.l			0
YM_DSP_Mixer_TB:					dc.l			0
YM_DSP_Mixer_TC:					dc.l			0
YM_DSP_Mixer_NA:					dc.l			0
YM_DSP_Mixer_NB:					dc.l			0
YM_DSP_Mixer_NC:					dc.l			0

YM_DSP_volA:					dc.l			$1234
YM_DSP_volB:					dc.l			$1234
YM_DSP_volC:					dc.l			$1234

YM_DSP_volE:					dc.l			0
YM_DSP_offset_enveloppe:		dc.l			0
YM_DSP_pointeur_enveloppe_en_cours:	dc.l		0

YM_DSP_pointeur_sur_source_du_volume_A:				dc.l		YM_DSP_volA
YM_DSP_pointeur_sur_source_du_volume_B:				dc.l		YM_DSP_volB
YM_DSP_pointeur_sur_source_du_volume_C:				dc.l		YM_DSP_volC

YM_DSP_position_offset_A:		dc.l			0
YM_DSP_position_offset_B:		dc.l			0
YM_DSP_position_offset_C:		dc.l			0

YM_DSP_position_offset_Noise:	dc.l			0
YM_DSP_current_Noise:			dc.l			$12071971
YM_DSP_current_Noise_mask:		dc.l			0
YM_DSP_Noise_seed:				dc.l			$12071971


; variables DG
YM_DSP_pointeur_sample_digidrum_voie_A:				dc.l		0
YM_DSP_pointeur_fin_sample_digidrum_voie_A:			dc.l		0
YM_DSP_increment_sample_digidrum_voie_A:			dc.l		0

YM_DSP_pointeur_sample_digidrum_voie_B:				dc.l		0
YM_DSP_pointeur_fin_sample_digidrum_voie_B:			dc.l		0
YM_DSP_increment_sample_digidrum_voie_B:			dc.l		0

YM_DSP_pointeur_sample_digidrum_voie_C:				dc.l		0
YM_DSP_pointeur_fin_sample_digidrum_voie_C:			dc.l		0
YM_DSP_increment_sample_digidrum_voie_C:			dc.l		0


YM_DSP_table_de_volumes:
	dc.l				0,161,265,377,580,774,1155,1575,2260,3088,4570,6233,9330,13187,21220,32767
; table volumes Amiga:
	;dc.l				$00*$c0, $00*$c0, $00*$c0, $00*$c0, $01*$c0, $02*$c0, $02*$c0, $04*$c0, $05*$c0, $08*$c0, $0B*$c0, $10*$c0, $18*$c0, $22*$c0, $37*$c0, $55*$c0
	
; volume 4 bits en 8 bits
; $00 $00 $00 $00 $01 $02 $02 $04 $05 $08 $0B $10 $18 $22 $37 $55
; ramené à 16383 ( 65535 / 4)
; *$c0

	;dc.l				0,161/2,265/2,377/2,580/2,774/2,1155/2,1575/2,2260/2,3088/2,4570/2,6233/2,9330/2,13187/2,21220/2,32767/2

					; 62,161,265,377,580,774,1155,1575,2260,3088,4570,6233,9330,13187,21220,32767



YM_DSP_table_prediviseur:
	dc.l		0,4,10,16,50,64,100,200	

; flags pour nb octets à lire
YM_flag_effets_sur_les_voies:			dc.l				0
YM_flag_effets_voie_A:		dc.l		0
YM_flag_effets_voie_B:		dc.l		0
YM_flag_effets_voie_C:		dc.l		0


PSG_compteur_frames_restantes:			dc.l		0
YM_pointeur_actuel_ymdata:				dc.l		0

; - le registre 13 definit la forme de l'enveloppe
; - on initialise une valeur à -16
; partie entiere 16 bits : virgule 16 bits
; partie entiere and %1111 = position dans la sous partie d'enveloppe
; ( ( partie entiere >> 4 ) and %1 ) << 2 = pointeur sur la sous partie d'enveloppe


YM_DSP_forme_enveloppe_1:
; enveloppe montante
	dc.l				62,161,265,377,580,774,1155,1575,2260,3088,4570,6233,9330,13187,21220,32767
; table volumes Amiga:
	;dc.l				$00*$c0, $00*$c0, $00*$c0, $00*$c0, $01*$c0, $02*$c0, $02*$c0, $04*$c0, $05*$c0, $08*$c0, $0B*$c0, $10*$c0, $18*$c0, $22*$c0, $37*$c0, $55*$c0

YM_DSP_forme_enveloppe_2:
; enveloppe descendante
	dc.l				32767,21220,13187,9330,6233,4570,3088,2260,1575,1155,774,580,377,265,161,62
; table volumes Amiga:
	;dc.l				$55*$c0, $37*$c0, $22*$c0, $18*$c0,$10*$c0,$0B*$c0,$08*$c0, $05*$c0,$04*$c0,$02*$c0,$02*$c0,$01*$c0,$00*$c0,$00*$c0,$00*$c0,$00*$c0

YM_DSP_forme_enveloppe_3:
; enveloppe zero
	dc.l				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
YM_DSP_forme_enveloppe_4:
; enveloppe a 1
; table volumes Amiga:
	;dc.l				$55*$c0, $55*$c0,$55*$c0,$55*$c0,$55*$c0,$55*$c0,$55*$c0,$55*$c0,$55*$c0,$55*$c0,$55*$c0,$55*$c0,$55*$c0,$55*$c0,$55*$c0,$55*$c0
	dc.l				32767,32767,32767,32767,32767,32767,32767,32767,32767,32767,32767,32767,32767,32767,32767,32767

;-- formes des enveloppes
; forme enveloppe  0 0 x x
	dc.l		YM_DSP_forme_enveloppe_2	
YM_DSP_enveloppe00xx:
YM_DSP_enveloppe1001:
	dc.l		YM_DSP_forme_enveloppe_3,YM_DSP_forme_enveloppe_3
; forme enveloppe  0 1 x x
	dc.l		YM_DSP_forme_enveloppe_1	
YM_DSP_enveloppe01xx:
	dc.l		YM_DSP_forme_enveloppe_3,YM_DSP_forme_enveloppe_3
; forme enveloppe  1 0 0 0
	dc.l		YM_DSP_forme_enveloppe_2	
YM_DSP_enveloppe1000:
	dc.l		YM_DSP_forme_enveloppe_2,YM_DSP_forme_enveloppe_2
; forme enveloppe  1 0 0 1 = forme enveloppe  0 0 x x
; forme enveloppe  1 0 1 0
	dc.l		YM_DSP_forme_enveloppe_2	
YM_DSP_enveloppe1010:
	dc.l		YM_DSP_forme_enveloppe_1,YM_DSP_forme_enveloppe_2
; forme enveloppe  1 0 1 1
	dc.l		YM_DSP_forme_enveloppe_2
YM_DSP_enveloppe1011:
	dc.l		YM_DSP_forme_enveloppe_4,YM_DSP_forme_enveloppe_4
; forme enveloppe  1 1 0 0
	dc.l		YM_DSP_forme_enveloppe_1
YM_DSP_enveloppe1100:
	dc.l		YM_DSP_forme_enveloppe_1,YM_DSP_forme_enveloppe_1
; forme enveloppe  1 1 0 1
	dc.l		YM_DSP_forme_enveloppe_1
YM_DSP_enveloppe1101:
	dc.l		YM_DSP_forme_enveloppe_4,YM_DSP_forme_enveloppe_4
; forme enveloppe  1 1 1 0
	dc.l		YM_DSP_forme_enveloppe_1
YM_DSP_enveloppe1110:
	dc.l		YM_DSP_forme_enveloppe_2,YM_DSP_forme_enveloppe_1
; forme enveloppe  1 1 1 1
	dc.l		YM_DSP_forme_enveloppe_1
YM_DSP_enveloppe1111:
	dc.l		YM_DSP_forme_enveloppe_3,YM_DSP_forme_enveloppe_3

YM_DSP_liste_des_enveloppes:
	dc.l		YM_DSP_enveloppe00xx, YM_DSP_enveloppe00xx, YM_DSP_enveloppe00xx , YM_DSP_enveloppe00xx
	dc.l		YM_DSP_enveloppe01xx,YM_DSP_enveloppe01xx,YM_DSP_enveloppe01xx,YM_DSP_enveloppe01xx
	dc.l		YM_DSP_enveloppe1000,YM_DSP_enveloppe1001,YM_DSP_enveloppe1010,YM_DSP_enveloppe1011
	dc.l		YM_DSP_enveloppe1100,YM_DSP_enveloppe1101,YM_DSP_enveloppe1110,YM_DSP_enveloppe1111


; digidrums
; en memoire DSP
YM_DSP_table_digidrums:
	.rept		16			; maxi 16 digidrums
		dc.l		0			; pointeur adresse du sample
		dc.l		0			; pointeur fin du sample 
	.endr

	.phrase	


;---------------------
; FIN DE LA RAM DSP
YM_DSP_fin:
;---------------------


SOUND_DRIVER_SIZE			.equ			YM_DSP_fin-DSP_base_memoire
	.print	"--- Sound driver code size (DSP): ", /u SOUND_DRIVER_SIZE, " bytes / 8192 ---"




        .68000
		.dphrase
		
		.if			1=0
ob_liste_originale:           				 ; This is the label you will use to address this in 68K code
        .objproc 							   ; Engage the OP assembler
		.dphrase

        .org    ob_list_courante			 ; Tell the OP assembler where the list will execute
;
        branch      VC < 0, .stahp    			 ; Branch to the STOP object if VC < 0
        branch      VC > 200, .stahp   			 ; Branch to the STOP object if VC > 241
			; bitmap data addr, xloc, yloc, dwidth, iwidth, iheight, bpp, pallete idx, flags, firstpix, pitch
		bitmap		trame_ligne,50,150,nb_octets_par_ligne/8,nb_octets_par_ligne/8,1, 4,0, TRANS,0,0


        bitmap      ecran1, 16, 26, nb_octets_par_ligne/8, nb_octets_par_ligne/8, 246-26,4
		;bitmap		trame_ligne,50,150,nb_octets_par_ligne/8,nb_octets_par_ligne/8,1, 4, 0, TRANS,0,1
		;bitmap		trame_ligne+5120+512,50,150,nb_octets_par_ligne/8,nb_octets_par_ligne/8,1, 4,0, TRANS,0,0

		bitmap		trame_ligne,50,150,nb_octets_par_ligne/8,nb_octets_par_ligne/8,1, 4,0, TRANS,0,0

		bitmap		trame_ligne,52,150,nb_octets_par_ligne/8,nb_octets_par_ligne/8,1, 4,0, TRANS,0,0
		bitmap		trame_ligne,54,150,nb_octets_par_ligne/8,nb_octets_par_ligne/8,1, 4,0, TRANS,0,0


		;gpuobj		1,10
        jump        .haha
.stahp:
        stop
.haha:
        jump        .stahp
		
		.68000
		.dphrase
fin_ob_liste_originale:
		.endif
			
		.dphrase

	
	
	
	.phrase
CLUT_RGB:
; 15 couleurs pour logo ATARI
        ;dc.w    0x0000
        dc.w    $E738				; 1
        dc.w    $C720
        dc.w    $E728				;3
        dc.w    $E030
        dc.w    $E028				;5
        dc.w    $C020
        dc.w    $A710				;7
        dc.w    $E038
        dc.w    $6500				;9
        dc.w    $8600
        dc.w    $8010				;11
        dc.w    $A018
        dc.w    $4400				;13
        dc.w    $2300
        dc.w    $6008				;15
; 15 couleurs pour logo OMEGA
        dc.w    $0018				; 16
        dc.w    $0028
        dc.w    $8438
        dc.w    $E738
        dc.w    $A538				; 20
        dc.w    $E338
        dc.w    $E020
        dc.w    $C000
        dc.w    $0038				; 24
        dc.w    $E010
        dc.w    $E030
        dc.w    $6338
        dc.w    $0020				; 28
        dc.w    $8000
        dc.w    $6000
		dc.w	$0000				; 31
; 15 couleurs pour logo OMEGA
		dc.w	$0000				; 32
        dc.w    $0018				; 33
        dc.w    $0028
        dc.w    $8438
        dc.w    $E738
        dc.w    $A538				; 37
        dc.w    $E338
        dc.w    $E020
        dc.w    $C000
        dc.w    $0038				; 
        dc.w    $E010
        dc.w    $E030
        dc.w    $6338
        dc.w    $0020				; 45
        dc.w    $8000
        dc.w    $6000
		dc.w	$0000				; 48
		

	.dphrase
logos_originaux:
; 66*320
logo_ATARI:
	;.rept		640*10
	;dc.b		02,02,00,00
	;.endr

	.incbin		"c:\\jaguar\\logo_omega_atari.png_JAG"
logo_OMEGA:
	.incbin		"c:\\jaguar\\logo_omega_omega.png_JAG"
	.dphrase

logo_table_1_commandes:
; - 1: table des commandes de controle du logo : table pointée par 87E2 : de 8778, se termine par zéro en $87d8
		dc.l		$00000001				; s'applique sur 87DC donc sur 87FE donc sur table 4 
		dc.l		($C274-$AF16+table_4_lignes_pour_zoom_Y)				; OK
		dc.l		$00000002				; OK
		dc.l		$00000096				; s'applique sur 87DC, en fait sur 87EE => sur table positions en X
		dc.l		$00000003				; s'appliquer à 87FE donc sur table 4 
		dc.l		table_4_lignes_pour_zoom_Y								; OK
		dc.l		$00000001				; OK
		dc.l		($C274-$AF16+table_4_lignes_pour_zoom_Y)				; OK
		dc.l		$00000002				; OK
		dc.l		$00000032				; OK
		dc.l		$00000003				; s'appliquer à 87FE donc sur table 4 
		dc.l		table_4_lignes_pour_zoom_Y								; OK
		dc.l		$00000005				; OK changement de logo : on passe au logo OMEGA
		;dc.l		$00000006				; ok changement de palette
		;dc.l		$00006928				; ok changement de palette
		dc.l		$00000003				; OK
		dc.l		($C274-$AF16+table_4_lignes_pour_zoom_Y)				; OK
		dc.l		$00000002				; OK
		dc.l		$00000032				; OK
		dc.l		$00000001				; OK
		dc.l		table_4_lignes_pour_zoom_Y								; OK
		dc.l		$00000004				; OK changement de logo
		;dc.l		$00000006				; ok changement de palette
		;dc.l		$00006908				; ok changement de palette
		dc.l		$00000000				; OK FIN
FIN_logo_table_1_commandes:
	.dphrase

table_2_positions_en_X:
		.incbin		"Omega_logo_table2_6968_8198.bin"
FIN_table_2_positions_en_X:
		.dphrase
		
table_3_increments_en_X_pour_vague:
		.incbin		"Omega_logo_table3_8196_8280.bin"
FIN_table_3_increments_en_X_pour_vague:
		.dphrase

table_4_lignes_pour_zoom_Y:
		.incbin		"Omega_logo_table4_AF16_FD9A.bin"
FIN_table_4_lignes_pour_zoom_Y:
		.dphrase
table_5_waves_en_Y:
		.incbin		"Omega_logo_table5_8274_870E.bin"
FIN_table_5_waves_en_Y:
		.dphrase



	.phrase
fichier_coso_depacked:
		.incbin			"C:\\Jaguar\\COSO\\fichiers mus\\COSO\\NY2.MUS"			; demo OMEGA F2
		even
			
		.dphrase
table_Y_scrolling:
		DC.B     $00,'*',$00,'*',$00,'+' 
		DC.B      $00,',',$00,'-',$00,'.',$00,'/'
		DC.B      $00,'0',$00,'1',$00,'2',$00,'3'
		DC.B      $00,'4',$00,'5',$00,'6',$00,'7'
		DC.B      $00,'8',$00,'9',$00,':',$00,';'
		DC.B      $00,'<',$00,'=',$00,'>',$00,'?'
		DC.B      $00,'?',$00,'@',$00,'A',$00,'B'
		DC.B      $00,'C',$00,'C',$00,'D',$00,'E'
		DC.B      $00,'F',$00,'F',$00,'G',$00,'H'
		DC.B      $00,'I',$00,'I',$00,'J',$00,'K'
		DC.B      $00,'K',$00,'L',$00,'L',$00,'M'
		DC.B      $00,'M',$00,'N',$00,'N',$00,'O'
		DC.B      $00,'O',$00,'P',$00,'P',$00,'P'
		DC.B      $00,'Q',$00,'Q',$00,'R',$00,'R'
		DC.B      $00,'R',$00,'R',$00,'S',$00,'S'
		DC.B      $00,'S',$00,'S',$00,'S',$00,'S'
		DC.B      $00,'S',$00,'S',$00,'S',$00,'S'
		DC.B      $00,'S',$00,'S',$00,'S',$00,'S'
		DC.B      $00,'S',$00,'S',$00,'S',$00,'S'
		DC.B      $00,'S',$00,'R',$00,'R',$00,'R'
		DC.B      $00,'Q',$00,'Q',$00,'Q',$00,'P'
		DC.B      $00,'P',$00,'P',$00,'O',$00,'O'
		DC.B      $00,'N',$00,'N',$00,'M',$00,'M'
		DC.B      $00,'L',$00,'L',$00,'K',$00,'J'
		DC.B      $00,'J',$00,'I',$00,'I',$00,'H'
		DC.B      $00,'G',$00,'F',$00,'F',$00,'E'
		DC.B      $00,'D',$00,'C',$00,'C',$00,'B'
		DC.B      $00,'A',$00,'@',$00,'?',$00,'>'
		DC.B      $00,'>',$00,'=',$00,'<',$00,';'
		DC.B      $00,':',$00,'9',$00,'8',$00,'7'
		DC.B      $00,'6',$00,'5',$00,'4',$00,'3'
		DC.B      $00,'2',$00,'1',$00,'0',$00,'/'
		DC.B      $00,'.',$00,'-',$00,',',$00,'+'
		DC.B      $00,'*',$00,')',$00,'(',$00,$27
		DC.B      $00,'&',$00,'%',$00,'$',$00,'#'
		DC.B      $00,'"',$00,'!',$00,'!',$00,' '
		DC.B      $00,$1F,$00,$1E,$00,$1D,$00,$1C
		DC.B      $00,$1B,$00,$1A,$00,$19,$00,$18
		DC.B      $00,$17,$00,$16,$00,$15,$00,$14
		DC.B      $00,$14,$00,$13,$00,$12,$00,$11
		DC.B      $00,$10,$00,$0F,$00,$0F,$00,$0E
		DC.B      $00,$0D,$00,$0C,$00,$0C,$00,$0B
		DC.B      $00,$0A,$00,$0A,$00,$09,$00,$08
		DC.B      $00,$08,$00,$07,$00,$07,$00,$06
		DC.B      $00,$06,$00,$05,$00,$05,$00,$04
		DC.B      $00,$04,$00,$03,$00,$03,$00,$02
		DC.B      $00,$02,$00,$02,$00,$01,$00,$01
		DC.B      $00,$01,$00,$01,$00,$00,$00,$00
		DCB.W     17,0
		DC.B      $00,$01,$00,$01,$00,$01,$00,$02
		DC.B      $00,$02,$00,$02,$00,$03,$00,$03
		DC.B      $00,$03,$00,$04,$00,$04,$00,$05
		DC.B      $00,$05,$00,$06,$00,$06,$00,$07
		DC.B      $00,$07,$00,$08,$00,$09,$00,$09
		DC.B      $00,$0A,$00,$0A,$00,$0B,$00,$0C
		DC.B      $00,$0D,$00,$0D,$00,$0E,$00,$0F
		DC.B      $00,$10,$00,$10,$00,$11,$00,$12
		DC.B      $00,$13,$00,$14,$00,$15,$00,$15
		DC.B      $00,$16,$00,$17,$00,$18,$00,$19
		DC.B      $00,$1A,$00,$1B,$00,$1C,$00,$1D
		DC.B      $00,$1E,$00,$1F,$00,' ',$00,'!'
		DC.B      $00,'"',$00,'#',$00,'$',$00,'%'
		DC.B      $00,'&',$00,$27,$00,'(',$00,')'
		DC.B      $00,'*',$00,'*',$00,'+',$00,','
		DC.B      $00,'-',$00,'.',$00,'/',$00,'0'
		DC.B      $00,'1',$00,'2',$00,'3',$00,'4'
		DC.B      $00,'5',$00,'6',$00,'7',$00,'8'
		DC.B      $00,'9',$00,':',$00,';',$00,'<'
		DC.B      $00,'=',$00,'>',$00,'?',$00,'?'
		DC.B      $00,'@',$00,'A',$00,'B',$00,'C'
		DC.B      $00,'C',$00,'D',$00,'E',$00,'F'
		DC.B      $00,'F',$00,'G',$00,'H',$00,'I'
		DC.B      $00,'I',$00,'J',$00,'K',$00,'K'
		DC.B      $00,'L',$00,'L',$00,'M',$00,'M'
		DC.B      $00,'N',$00,'N',$00,'O',$00,'O'
		DC.B      $00,'P',$00,'P',$00,'P',$00,'Q'
		DC.B      $00,'Q',$00,'R',$00,'R',$00,'R'
		DC.B      $00,'R',$00,'S',$00,'S',$00,'S'
		DC.B      $00,'S',$00,'S',$00,'S',$00,'S'
		DC.B      $00,'S',$00,'S',$00,'S',$00,'S'
		DC.B      $00,'S',$00,'S',$00,'S',$00,'S'
		DC.B      $00,'S',$00,'S',$00,'S',$00,'S'
		DC.B      $00,'R',$00,'R',$00,'R',$00,'Q'
		DC.B      $00,'Q',$00,'Q',$00,'P',$00,'P'
		DC.B      $00,'P',$00,'O',$00,'O',$00,'N'
		DC.B      $00,'N',$00,'M',$00,'M',$00,'L'
		DC.B      $00,'L',$00,'K',$00,'J',$00,'J'
		DC.B      $00,'I',$00,'I',$00,'H',$00,'G'
		DC.B      $00,'F',$00,'F',$00,'E',$00,'D'
		DC.B      $00,'C',$00,'C',$00,'B',$00,'A'
		DC.B      $00,'@',$00,'?',$00,'>',$00,'>'
		DC.B      $00,'=',$00,'<',$00,';',$00,':'
		DC.B      $00,'9',$00,'8',$00,'7',$00,'6'
		DC.B      $00,'5',$00,'4',$00,'3',$00,'2'
		DC.B      $00,'1',$00,'0',$00,'/',$00,'.'
		DC.B      $00,'-',$00,',',$00,'+',$00,'*'
		DC.B      $00,')',$00,'(',$00,$27,$00,'&'
		DC.B      $00,'%',$00,'$',$00,'#',$00,'"'
		DC.B      $00,'!',$00,'!',$00,' ',$00,$1F
		DC.B      $00,$1E,$00,$1D,$00,$1C,$00,$1B
		DC.B      $00,$1A,$00,$19,$00,$18,$00,$17
		DC.B      $00,$16,$00,$15,$00,$14,$00,$14
		DC.B      $00,$13,$00,$12,$00,$11,$00,$10
		DC.B      $00,$0F,$00,$0F,$00,$0E,$00,$0D
		DC.B      $00,$0C,$00,$0C,$00,$0B,$00,$0A
		DC.B      $00,$0A,$00,$09,$00,$08,$00,$08
		DC.B      $00,$07,$00,$07,$00,$06,$00,$06
		DC.B      $00,$05,$00,$05,$00,$04,$00,$04
		DC.B      $00,$03,$00,$03,$00,$02,$00,$02
		DC.B      $00,$02,$00,$01,$00,$01,$00,$01
		DC.B      $00,$01,$00,$00,$00,$00,$00,$00
		DCB.W     16,0
		DC.B      $00,$01,$00,$01,$00,$01,$00,$02
		DC.B      $00,$02,$00,$02,$00,$03,$00,$03
		DC.B      $00,$03,$00,$04,$00,$04,$00,$05
		DC.B      $00,$05,$00,$06,$00,$06,$00,$07
		DC.B      $00,$07,$00,$08,$00,$09,$00,$09
		DC.B      $00,$0A,$00,$0A,$00,$0B,$00,$0C
		DC.B      $00,$0D,$00,$0D,$00,$0E,$00,$0F
		DC.B      $00,$10,$00,$10,$00,$11,$00,$12
		DC.B      $00,$13,$00,$14,$00,$15,$00,$15
		DC.B      $00,$16,$00,$17,$00,$18,$00,$19
		DC.B      $00,$1A,$00,$1B,$00,$1C,$00,$1D
		DC.B      $00,$1E,$00,$1F,$00,' ',$00,'!'
		DC.B      $00,'"',$00,'#',$00,'$',$00,'%'
		DC.B      $00,'&',$00,$27,$00,'(',$00,')'
FIN_table_Y_scrolling:
.dphrase
	

	.dphrase
table_adresses_logo_ATARI_predecale:		
		dc.l		buffer_logos_predecales_ATARI_0+decalage_debut_utilisation_logo
		dc.l		buffer_logos_predecales_ATARI_1+decalage_debut_utilisation_logo
		dc.l		buffer_logos_predecales_ATARI_2+decalage_debut_utilisation_logo
		dc.l		buffer_logos_predecales_ATARI_3+decalage_debut_utilisation_logo
table_adresses_logo_OMEGA_predecale:
		dc.l		buffer_logos_predecales_OMEGA_0+decalage_debut_utilisation_logo
		dc.l		buffer_logos_predecales_OMEGA_1+decalage_debut_utilisation_logo
		dc.l		buffer_logos_predecales_OMEGA_2+decalage_debut_utilisation_logo
		dc.l		buffer_logos_predecales_OMEGA_3+decalage_debut_utilisation_logo

texte_scrolling:
		DC.B      "JIPPIDIP"
		DC.B      "PIDOOOO_"
		DC.B      "___     "
		DC.B      "CREDITS "
		DC.B      "TO     L"
		DC.B      "IESEN DI"
		DC.B      "ST    HA"
		DC.B      "Q SCROLL"
		DC.B      "      RE"
		DC.B      "D LOGOS]"
		DC.B      "        "
		DC.B      "  HEJA^ "
		DC.B      "OSS VI E"
		DC.B      " KUL]]]]"
		DC.B      "        "
		DC.B      " THE FUN"
		DC.B      "NY MUPP "
		DC.B      "DEMO HID"
		DC.B      "DEN BEHI"
		DC.B      "ND THE F"
		DC.B      " BUTTON "
		DC.B      "NUMBER T"
		DC.B      "HREE^ WA"
		DC.B      "S ALSO M"
		DC.B      "ADE BY L"
		DC.B      "IESEN AN"
		DC.B      "D RED]]]"
		DC.B      "]]      "
		DC.B      " GREATER"
		DC.B      "S   TCB "
		DC.B      "[SUGER",92," "
		DC.B      "   SYNC "
		DC.B      "[FUNNY T"
		DC.B      "ALKERS",92," "
		DC.B      "     NO "
		DC.B      "CREW [KU"
		DC.B      "L PARTY",92
		DC.B      "     THE"
		DC.B      " REST OF"
		DC.B      " ALL MUP"
		DC.B      "PERS]]]]"
		DC.B      "]       "
		DC.B      "   GO HO"
		DC.B      "ME OR I "
		DC.B      "WILL WRA"
		DC.B      "P]]]]   "
		DC.B      "        "
		DC.B      "      ",$FF,$00
		.phrase

buffer_scrolling_double_largeur:		;ds.b		13*320*2
		.rept		13
			.rept	80
				dc.b	01,01,00,00
			.endr
			.rept	80
				dc.b	02,02,00,00
			.endr
		.endr


		.BSS
		.dphrase
DEBUT_BSS:
YM_registres_Coso:			ds.b		14

	.phrase
frequence_Video_Clock:					ds.l				1
frequence_Video_Clock_divisee :			.ds.l				1

YM_frequence_replay:					ds.l				1
	.phrase

YM_frequence_predivise:			ds.l		1


vbl_counter:			ds.l			1
_50ou60hertz:			ds.l	1
ntsc_flag:				ds.w	1
a_hdb:          		ds.w   1
a_hde:          		ds.w   1
a_vdb:          		ds.w   1
a_vde:          		ds.w   1
width:          		ds.w   1
height:         		ds.w   1
taille_liste_OP:		ds.l	1

            .dphrase
			ds.b		640
;buffer_logo_ATARI_etendu:
;			ds.b		66*640
;buffer_logo_OMEGA_etendu:
;			ds.b		66*640

            .dphrase
;buffer_logos_predecales:
buffer_logos_predecales_ATARI_0:		ds.b		67*640
buffer_logos_predecales_ATARI_1:		ds.b		67*640
buffer_logos_predecales_ATARI_2:		ds.b		67*640
buffer_logos_predecales_ATARI_3:		ds.b		67*640
buffer_logos_predecales_OMEGA_0:		ds.b		67*640
buffer_logos_predecales_OMEGA_1:		ds.b		67*640
buffer_logos_predecales_OMEGA_2:		ds.b		67*640
buffer_logos_predecales_OMEGA_3:		ds.b		67*640

; 13 lignes en hauteur
;buffer_scrolling_double_largeur:		ds.b		13*320*2

            .dphrase
fonte_256_couleurs:						ds.b		38*13*16		; 38 caracteres * 13 lignes * 16 pixels
; zones ecran
; en cours de modif & affichée
            .dphrase
zone_logo_1:						ds.b		320*(62+44)			; 106
            .dphrase
zone_logo_2:						ds.b		320*(62+44)
			.dphrase
; zones ecran scrolling = 83 lignes 
zone_scrolling_1:					ds.b		320*(83+13)
zone_scrolling_2:					ds.b		320*(83+13)

	.dphrase

FIN_RAM:



; ////////////////////////////////	
	.if		1=0
; 8 pixels
	.rept	2
	loadb	(R10),R0
	loadb	(R11),R1
	shlq	#24,R0
	addq	#2,R10
	shlq	#16,R1
	loadb	(R10),R4
	addq	#2,R11
	addq	#2,R10
	shlq	#8,R4
	loadb	(R11),R3
	or		R1,R0
	addq	#2,R11
	or		R4,R0
	or		R3,R0
	
	
	store	R0,(R20)
	;storeb	R1,(R21)
	addq	#4,R20
	;addq	#2,R21
	.endr
	.endif
; ////////////////////////////////	