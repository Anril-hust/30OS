; hello-os
; TAB=4

CYLS	EQU		40				; ��Ҫ����������20�����棬һ��������������ͷ��ÿ���ͷ����18��������ÿ������512�ֽڣ�һ�����棺2*18*512=18K

		ORG		0x7c00			; ָ�������װ�ص�ַ

; �����������ڱ�׼FAT12��ʽ������

		JMP		entry
		DB		0x90
		DB		"HELLOIPL"		; �����������ƿ�����������ַ�����8�ֽڣ�
		DW		512						; ÿ��������sector���Ĵ�С������Ϊ512�ֽڣ�
		DB		1							; �أ�Cluster���Ĵ�С������Ϊһ������
		DW		1							; FAT����ʼ��ַ��һ��ӵ�һ��������ʼ��
		DB		2							; FAT�ĸ���������Ϊ2��
		DW		224						; ��Ŀ¼�Ĵ�С��һ�����ó�224��
		DW		2880					; �ô��̵Ĵ�С��������2880������
		DB		0xf0					; ���̵����ࣨ������0xF0��
		DW		9							; FAT�ĳ��ȣ�������9������
		DW		18						; 1���ŵ���track���м���������������18��
		DW		2							; ��ͷ����������2��
		DD		0							; ��ʹ�÷�����������0
		DD		2880					; ��дһ�δ��̴�С
		DB		0,0,0x29			; �̶������岻��
		DD		0xffffffff		; �������ǣ�������
		DB		"HELLO-OS   "	; ���̵����ƣ�11�ֽڣ�
		DB		"FAT12   "		; ���̸�ʽ���ƣ�8�ֽڣ�
		RESB	18						; �ȿճ�18�ֽ�
		
; ���Ĳ���

entry:
		MOV		AX,0			; ��ʼ��
		MOV		SS,AX
		MOV		SP,0x7c00
		MOV		DS,AX
		
		MOV		AX,0x0820
		MOV		ES,AX
		MOV		CH,0			; ����0
		MOV		DH,0			; ��ͷ0
		MOV		CL,2			; ����2
		
readloop:
		MOV		SI,0			;	��¼����ʧ�ܵĴ���

retry:							; ������
		MOV		AH,0x02		; AH=0x02 : ����
		MOV		AL,1			; 1������
		MOV		BX,0			; ES:BX = ��������ַ
		MOV		DL,0x00		; A������
		INT		0x13			; ���ô���BIOS
		JNC		next
		ADD		SI,1
		CMP		SI,5
		JAE		error
		MOV		AH,0x00
		MOV		DL,0x00		; ������A
		INT		0x13			; ����������
		JMP		retry

next:
		MOV		AX,ES			; ���ڴ��ַ����0x200
		ADD		AX,0x0020
		MOV		ES,AX			; ��Ϊû��ADD ES, 0x020��ָ������Ƹ���
		ADD		CL,1
		CMP		CL,18			;
		JBE		readloop	; CLС��18ʱ��ת�� readloop
		MOV		CL,1
		ADD		DH,1
		CMP		DH,2			; ��������ֻ�����棬���Դ�ͷ�����Ϊ1
		JB		readloop
		MOV		DH,0			; ���ô�ͷΪ0
		ADD		CH,1
		CMP		CH,CYLS		; ����CYLS������
		JB		readloop
		
success:
		JMP		fin1
		
error:
		MOV		SI,f_msg
		JMP		putloop
		
fin1:
		MOV		[0x0ff0],CH
		JMP		0xC200
		HLT							; ��CPUֹͣ
		JMP		fin1				
		
putloop:
		MOV		AL,[SI]
		ADD		SI,1			
		CMP		AL,0
		JE		fin1
		MOV		AH,0x0e		; ��ʾһ������
		MOV		BX,15			; ָ���ַ���ɫ
		INT		0x10			; �����Կ�BIOS
		JMP		putloop

f_msg:
		DB		0x0d, 0x0a	; ����2��
		DB		"load floppy disk error"
		DB		0x0a				; ����
		DB		0

	
		RESB	0x7dfe-$		;

		DB		0x55, 0xaa
