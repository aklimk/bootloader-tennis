[bits 16]
[org 0x7C00]

; Compile time constants.

STACK_SIZE equ 0xAAAA
STACK_BOTTOM equ 0x8000

SCREEN_WIDTH equ 320
SCREEN_HEIGHT equ 200
BALL_DIM equ 50
BALL_START_X equ (SCREEN_WIDTH - BALL_DIM) / 2
BALL_START_Y equ (SCREEN_HEIGHT - BALL_DIM) / 2
PLAYER_PADDLE_OFFSET equ 20
PLAYER_PADDLE_WIDTH equ 10
PLAYER_PADDLE_HEIGHT equ 50

section .bss

section .text

.test:
	jmp SHORT .test	

main:
	; Set up video and stack settings.

	; 320x200 8 bit color graphical mode.
	mov al, 0x13
	int 0x10

	; Memory adressing is done using a segment and offset.
	; Video memory starts at segment 0xA000.
	; Video memory is 1 byte per pixel, column major, index from top left.
	; Ds does not support direct mov, use a general register first.
	mov ax, 0xA000
	mov ds, ax

	; Set up stack space by setting stack segment register and stack pointer register.
	mov ax, STACK_BOTTOM
	mov ss, ax
	mov sp, STACK_SIZE

	
	; Map variables to available registers.

	; Registers
	; ax, bx, cx, dx - general purpose, 16 bit or byte adressable, supports immediate mov
	; si, di, bp, sp - general purpose, 16 bit, supports immediate mov
	; Note sp is reserved for stack usage.

	; Game variables
	; Left paddle vertical position : al 
	; Right paddle vertical position : ah
	; Ball velocity x : bl
	; Ball velocity y : bh
	; Ball position x : si
	; Ball position y : di 
	; Left paddle score : cl
	; Right paddle score : ch
	; Leaves dl, dh, bp free
	
	; Paddles start at the top.
	xor ax, ax ; one byte register clear

	; Ball velocity starst at 1.
	mov bl, 1
	mov bh, 1
	
	; Ball position starts at the center.
	mov si, BALL_START_X
	mov di, BALL_START_Y

	; Paddle scores start at 0.
	xor cx, cx


	; Main loop for the game.

	.game_loop:
		; Render left paddle
		pusha

		; Move left paddle vertical position to bx register.
		xor bx, bx
		mov bl, al
		; Left paddle horizontal position is constant.
		mov ax, PLAYER_PADDLE_OFFSET

		; Calculate bottom right position using preset width, height values.
		mov cx, ax
		add cx, PLAYER_PADDLE_WIDTH
		mov dx, bx
		add dx, PLAYER_PADDLE_HEIGHT

		call render_rectangle

		popa
		
		jmp SHORT .game_loop
	 
	

; ax = topleft x (also x counter)
; bx = topleft y (also y counter)
; cx = bottomright x
; dx = bottomright y
; also modifies si
; also modifies di
render_rectangle:
	.loop_y:
	; Jump to end of loop if topleft y > bottomright y.
	cmp bx, dx
	ja SHORT .end_loop_y
		.loop_x:
		; Jump to end if topleft x > bottomright x.
		cmp ax, cx
		ja SHORT .end_loop_x

			; Main rendering logic for rectangle.		
			; Render a white pixel at screen position (ax, bx).
			; Si holds the unrolled position.
			mov si, bx
			imul si, SCREEN_HEIGHT
			add si, ax
			mov BYTE [ds:si], 255

			; Increment the x counter.
			inc ax
		.end_loop_x:
		
		; Increment the y counter.
		inc bx
	.end_loop_y:
	ret
