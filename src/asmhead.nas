; haribote-os boot asm
; TAB=4
[INSTRSET "i486p"]

BOTPAK	EQU		0x00280000		; bootpack�Ŀ���Ŀ�ĵ�ַ
DSKCAC	EQU		0x00100000		; IPL�Ŀ���Ŀ�ĵ�ַ IPL�Ĵ�С������512Byte
DSKCAC0	EQU		0x00008000		; IPL�������ж������ݵ�Դ������ַ 0x00008200


; BOOT_INFO
CYLS	EQU		0x0ff0
LEDS	EQU		0x0ff1			; �����ϵĸ���ָʾ��
VMODE	EQU		0x0ff2			; ��ʾģʽ
SCRNX	EQU		0x0ff4
SCRNY	EQU		0x0ff6
VRAM	EQU		0x0ff8			; ͼ�߿�ʼ������

;;;; resolution BX = 0x4000 + below value
;	0x100			640x400 8bit
; 0x101			640x480 8bit
; 0x103			800x600 8bit
; 0x105			1024x768 8bit
; 0x107			1280x1024 8bit
VBEMODE	EQU	0x105

	ORG		0xC200

	MOV		AX, 0x9000
	MOV		ES, AX
	MOV		DI, 0
	MOV		AX, 0x4f00
	INT		0x10
	CMP		AX, 0x004f		; �����VBE�Ļ���AX���Ϊ0x004f
	JNE		scrn320
	MOV		AX, [ES:DI + 4]	; ���VBE�İ汾
	CMP		AX, 0x0200
	JB		scrn320				; if (AX < 0x0200) goto scrn320
	MOV		CX, VBEMODE
	MOV		AX, 0x4f01
	INT		0x10
	CMP		AX, 0x004f
	JNE		scrn320
	
	CMP		BYTE[ES:DI + 0x19], 8			; ��ɫ����Ӧ��Ϊ8
	JNE		scrn320
	CMP		BYTE[ES:DI + 0x1b], 4			; ��ɫ��ָ������������Ϊ4��4Ϊ��ɫ��ģʽ
	JNE		scrn320
	MOV		AX, [ES:DI + 0x00]				;	ģʽ���ԣ�bit7����Ϊ1
	AND		AX, 0x0080
	JZ		scrn320		
	
	MOV		BX, VBEMODE + 0x4000
	MOV		AX, 0x4f02
	INT		0x10
	MOV		BYTE[VMODE],8
	MOV		AX, [ES:DI + 0x12]	; X �ķֱ���
	MOV		[SCRNX],AX
	MOV		AX, [ES:DI + 0x14]	; Y �ķֱ���
	MOV		[SCRNY],AX
	MOV		EAX, [ES:DI + 0x28]
	MOV		DWORD[VRAM],EAX
	JMP		get_led

scrn320:
	MOV		AL,0x13			; VGA �Կ���320x200x18λ��ɫ
	MOV		AH,0x00
	INT		0x10
	MOV		BYTE[VMODE],8
	MOV		WORD[SCRNX],320
	MOV		WORD[SCRNY],200
	MOV		DWORD[VRAM],0x000a0000

get_led:	
; ȡ�ü����ϸ���LEDָʾ��
	MOV		AH,0x02
	INT		0x16
	MOV		[LEDS],AL
	
;;;;;;;;;; COPY ;;;;;;;;;;;
	
		MOV		AL,0xff
		OUT		0x21,AL	; �൱�� io_out(PIC0_IMR, 0xff), ��ֹ��PIC��ȫ���ж�
		NOP						; �������ִ��OUTָ���Щ�������޷���������
		OUT		0xa1,AL ; �൱�� io_out(PIC1_IMR, 0xff), ��ֹ��PIC��ȫ���ж�
	
		CLI						; ��ֹCPU������ж�

		CALL	waitkbdout
		MOV		AL,0xd1
		OUT		0x64,AL
		CALL	waitkbdout
		MOV		AL,0xdf			; enable A20��Ϊ��ʹ1M���ϵ��ڴ����ʹ��
		OUT		0x60,AL
		CALL	waitkbdout

		LGDT	[GDTR0]			; �b��GDT��ݒ�
		MOV		EAX,CR0
		AND		EAX,0x7fffffff	; bit31��0�ɂ���i�y�[�W���O�֎~�̂��߁j
		OR		EAX,0x00000001	; bit0��1�ɂ���i�v���e�N�g���[�h�ڍs�̂��߁j
		MOV		CR0,EAX
		JMP		pipelineflush
pipelineflush:
		MOV		AX,1*8			;  �ǂݏ����\�Z�O�����g32bit
		MOV		DS,AX
		MOV		ES,AX
		MOV		FS,AX
		MOV		GS,AX
		MOV		SS,AX

; bootpack�Ŀ���

		MOV		ESI,bootpack	; ת��Դ
		MOV		EDI,BOTPAK		; ת��Ŀ�ĵ�
		MOV		ECX,512*1024/4
		CALL	memcpy

; ������������ת�͵���������λ��ȥ

; ���ȴ�����������ʼ��IPL

		MOV		ESI,0x7c00		; ת��Դ
		MOV		EDI,DSKCAC		; ת��Ŀ�ĵ�
		MOV		ECX,512/4
		CALL	memcpy

; IPL�������ж��������ݵĿ���

		MOV		ESI,DSKCAC0+512	; ת��Դ
		MOV		EDI,DSKCAC+512	; ת��Ŀ�ĵ�
		MOV		ECX,0
		MOV		CL,BYTE [CYLS]
		IMUL	ECX,512*18*2/4	; ��������ת��Ϊ�ֽ���
		SUB		ECX,512/4				; ��ȥIPL
		CALL	memcpy

; asmhead�ł��Ȃ���΂����Ȃ����Ƃ͑S�����I������̂ŁA
;	���Ƃ�bootpack�ɔC����

; bootpack������

		MOV		EBX,BOTPAK
		MOV		ECX,[EBX+16]
		ADD		ECX,3			; ECX += 3;
		SHR		ECX,2			; ECX /= 4;	ECX	>> 2
		JZ		skip			; û��Ҫת�͵Ķ���ʱ
		MOV		ESI,[EBX+20]	; ת��Դ
		ADD		ESI,EBX
		MOV		EDI,[EBX+12]	; ת��Ŀ�ĵ�
		CALL	memcpy
skip:
		MOV		ESP,[EBX+12]	; ջ��ʼ��ַ
		JMP		DWORD 2*8:0x0000001b

waitkbdout:
		IN		AL,0x64
		AND		AL,0x02
		JNZ		waitkbdout		; AND�̌��ʂ�0�łȂ����waitkbdout��
		RET

memcpy:
		MOV		EAX,[ESI]
		ADD		ESI,4
		MOV		[EDI],EAX
		ADD		EDI,4
		SUB		ECX,1
		JNZ		memcpy			; �����Z�������ʂ�0�łȂ����memcpy��
		RET
; memcpy�̓A�h���X�T�C�Y�v���t�B�N�X�����Y��Ȃ���΁A�X�g�����O���߂ł�������

		ALIGNB	16	;;�����ֱ��16�ֽڶ���
GDT0:
		RESB	8				; NULL sector
		DW		0xffff,0x0000,0x9200,0x00cf	; ���Զ�д�Ķ� 32bit
		DW		0xffff,0x0000,0x9a28,0x0047	; ����ִ�еĶ� 32bit bootpac ��

		DW		0
GDTR0:
		DW		8*3-1
		DD		GDT0

		ALIGNB	16
bootpack:
