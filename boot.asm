[bits 16]
[org 0x7C00]

SCREEN_WIDTH equ 20
SCREEN_HEIGHT equ 20
NUM_TITLES equ 3
STACK_SIZE equ 0xAAAA
STACK_BOTTOM equ 0x8000

; txt + data + bss : 0x7C00 (incl) - 0x7FFF (incl)
; heap : 0x8000 (incl) upwards
; stack : 0xFFFE (incl) downwards
section .data
	TITLE_ONE db "PONG"
	TITLE_TWO db "DEMO12"
	TITLE_THREE db "PLCEHLDR"
	TITLES dw TITLE_ONE, TITLE_TWO, TITLE_THREE
	TITLE_PADDINGS db 8, 8, 7, 7, 6, 6
	NA_GAME_MSG db "Roadworks", 0
	NA_GAME_MSG_PADDING db 35 
	GAME_ENTRY_POINTS dw pong_main, na_main, na_main

section .bss
	SCREEN_STRING resb SCREEN_WIDTH * SCREEN_HEIGHT + (SCREEN_HEIGHT * 2)
	SELECTION resb 1

	; Pong Data
	LEFT_PADDLE_Y resb 1
	LEFT_PADDLE_SCORE resb 1
	RIGHT_PADDLE_Y resb 1
	RIGHT_PADDLE_SCORE resb 1
	BALL_X resb 1
	BALL_Y resb 1
	BALL_VELOCITY resb 1 


; Common Instructions Reference
; push + pop = 4B
; logical r16, r16 = 2B

; cmp al, im8 = 2B
; cmp ax, im16 = 3B
; cmp r8, im8 = 3B
; cmp r16, im16 = 4B

; call (near) = 3B
; call (far) = 5B
; ret = 1B

; jump (relative) = 2B
; jump (near) = 3B
; jump (far) = 5B

; mov r8, r8 or r16, r16 = 2B
; mov r8, im8 = 2B
; move r16, im16 = 3B
; move m8, r8 or r8, m8 = 4B (3B if add in reg)
; move m16, r16, or r16, m16 =  4B (3B if add in reg)
section .text
setup_stack:
	mov ax, STACK_BOTTOM ; B8 00 80 (1op + 2im)
	mov ss, ax ; 8E D0 (1op + 1r)
	mov sp, STACK_SIZE ; BC AA AA (1op + 2im)
	; - SECTION 8B

main:
	; Reset to Text mode
	mov ax, 0x0003 ; B8 03 00 (1op + 2im)
	int 0x10 ; CD 10 (1op + 1im)
	; - SECTION 5B

	; Menu Loop
	.start_game_loop:
		; Clear Menu
		call NEAR clear_screen ; E8 D6 00 (1op + 2near-add)
		
		; Menu Rendering Start
		mov di, SCREEN_STRING ; BF D8 7D (1op + 2ptr)
		mov si, TITLE_PADDINGS ; BE C0 7D (1op + 2ptr)
	; - SECTION 9B

		mov ax, 0 ; B8 00 00 (1op + 2im)
		.loop_y:
			mov bx, 0 ; BB 00 00 (1op + 2im)
			.loop_x:

				; cl = space
				mov cl, 0x20 ; B1 20 (1op + 1im)
	; - SECTION 8B

				; Create Border
				.if_top_boundry:
				cmp al, 0 ; 3C 00 (1op + 1im)
				jne SHORT .if_bottom_boundry ; 75 02 (1op + 1off)
				; if (y == 0)
					; cl = hash
					mov cl, 0x23 ; B1 23 (1op + 1im)
				.if_bottom_boundry:
				cmp al, SCREEN_HEIGHT - 1 ; 3C 13 (1op + 1im)
				jne SHORT .if_left_boundry ; 75 02 (1op + 1off)
				; if (y == SCREEN_HEIGHT - 1)
					mov cl, 0x23 ; B1 23 (1op + 1im)
				.if_left_boundry:
				cmp bl, 0 ; 80 FB 00 (1op + 1reg + 1im)
				jne SHORT .if_right_boundry ; 75 02 (1op + 1off)
				; if (x == 0)
					mov cl, 0x23 ; B1 23 (1op + 1im)
				.if_right_boundry:
				cmp bl, SCREEN_WIDTH - 1 ; 80 FB 13 (1op + 1reg + 1im)
				jne SHORT .endif_boundry ; 75 02 (1op + 1off)
				; if (x == SCREEN_WIDTH - 1)
					mov cl, 0x23 ; B1 23 (1op + 1im)
				.endif_boundry:
	; - SECTION	24B
		
				; ">" Char Rendering
				.if_selector_x:
				mov dl, [SELECTION] ; 8A 16 90 7F (1op + 1reg + 2add)
				add dl, 2 ; 80 C2 02 (1op + 1reg + 1im)
				cmp al, dl ; 38 D0 (1op + 1(reg + reg))
				jne SHORT .endif_selector ; 75 07 (1op + 1off)
				; if (y == SELECTION + 2)
					.if_selector_y:
					cmp bl, 2 ; 80 FB 02 (1op + 1reg + 1im)
					jne SHORT .endif_selector ; 75 02 (1op + 1off)
					; if (x == 2)
						; cl = >
						mov cl, 0x3E ; B1 3E (1op 1im)
				.endif_selector:
	; - SECTION 18B
				
				; Game Titles Rendering
				.if_text_y_gt:
				cmp al, 1 ; 3C 01 (1op + 1im)
				jle SHORT .end_text_if ; 7E 26 (1op + 1off)
				; if (y > 1)
					.if_text_y_le:
					cmp al, NUM_TITLES + 1 ; 3C 04 (1op + 1im)
					jg SHORT .end_text_if ; 7F 22 (1op + 1off)
					; if (y <= NUM_TITLES + 1)
						.if_text_x_gt:
						cmp bl, [si] ; 3A 1C (1op + 1(reg + regmem))
						jb SHORT .end_text_if ; 72 1E (1op + 1off) 
						; if (x > paddings[0])
							.if_text_x_2:
							mov dl, SCREEN_WIDTH ; B2 14 (1op + 1off)
							sub dl, [si + 1] ; 2A 54 01 (1op + 1regmem + 1im)
							cmp bl, dl ; 38 D3 (1 op + 1(reg + reg))
							jae SHORT .end_text_if ; 73 15 (1op + 1off)
							; if (x <= SCREEN_WIDTH - paddings[1])
	; - SECTION 21B
								; Render Text
								push di ; 57 (1(op + reg))

								; GAMES[y - 2]
								mov di, ax ; 89 C7 (1op + 1(reg + reg))
								sub di, 2 ; 83 EF 02 (1op 1reg 1im)
								; GAMES elem size is 16 bits, thus
								; bp = 2(y - 2) to index correctly
								shl di, 1 ; D1 E7 (1op + 1reg)
								mov di, [TITLES + di] ; 8B BD BA 7D
								; bp = char*
							
								; &GAMES[y - 2][x - paddings[0]]
								mov dl, bl ; 88 DA (1op + 1(reg + reg))
								sub dl, [si] ; 2A 14 (1op + 1regmem)
								add di, dx ; 01 D7 (1op + 1(reg + reg))
		
								mov cl, [di] ; 8A 0D (1op + 1(reg + regmem))

								pop di ; 5F (1(op + reg)
				.end_text_if:
	; - SECTION 21B				

				; set char
				mov [di], cl
				inc di

			inc bl
			cmp bl, SCREEN_WIDTH
			jl SHORT .loop_x

			; x == SCREEN_WIDTH	
			; add \r\n to screen_string
			mov word [di], 0x0A0D
			add di, 2
			
			; increment padding array to next padding pair
			; iff currently on a title row
			.if_text_y_gt_2:
				cmp al, 1
				jle SHORT .endif_text_2
				; y > 1
				; don't need to check y < GAMES_COUNT as the
				; padding will never be dereferenced
					add si, 2
			.endif_text_2:
			
		inc al
		cmp al, SCREEN_HEIGHT
		jl SHORT .loop_y

		; y == SCREEN_HEIGHT
		; Menu Rendering Stop

		; Display Rendered Menu
		mov di, SCREEN_STRING
		call print_string

		; Update Menu from Input Start
		mov ah, 0x00 ; read key press
		int 0x16 ; keyboard io interupt
		; ah = scan code, al = ascii
		; High = scan, low = ascii
		; < = 0x4B00, > = 0x4D00
		; ^ = 0x4800, dwn = 0x5000
		mov bl, [SELECTION]
		.if_up:
		cmp ah, 0x48
		jne SHORT .if_down
		; scancode = 0x48
			sub bl, 1
		.if_down:
		cmp ah, 0x50
		jne SHORT .endif_keycode
		; scancode = 0x50
			add bl, 1
		.endif_keycode:

		; Make sure SELECTION stays in a valid range
		.if_selection_over:
		cmp bl, NUM_TITLES
		jl SHORT .if_selection_under
		; SELECTION >= NUM_TITLES
			; SELECTION = NUM_TITLES - 1
			mov bl, NUM_TITLES - 1
		.if_selection_under:
		cmp bl, 0
		jge SHORT .endif_selection
		; SELECTION < 0
			mov bl, 0
		.endif_selection:

		mov [SELECTION], bl

		; Detect enter keypress
		; ENTER = 0x1C0D
		.if_enter:
		cmp ah, 0x1C
		jne SHORT .endif_enter
		; scancode = 0x1C 
			call clear_screen
			mov bl, [SELECTION]
			shl bl, 1 ; di = 2 * SELECTION
			mov bx, [GAME_ENTRY_POINTS + bx]
			jmp bx
		.endif_enter:
		; Update Menu from Input Stop

	jmp NEAR .start_game_loop


; void print_string(char* string)
; Prints the screen string to terminal.
; Args: 
;     string (di): string to print.
;         Assumes its not an empty string.
print_string:
	; Teletype
	mov ah, 0x0E 
	.print_char:
		mov al, [di]
		; Video Interupt
		int 0x10 
	inc di
	cmp byte [di], 0x00
	jne SHORT .print_char
	ret

; void clear_screen()
; Clears the terminal screen.
clear_screen:
	mov ax, 0x0700 ; scroll down window, clear
	mov bx, 0x0700 ; white foreground, black background
	mov cx, 0x0000 ; upper left position
	mov dx, 0x184F ; lower right position
	int 0x10 ; video services
	mov ah, 0x02 ; set cursor position
	mov bh, 0 ; page number
	mov dx, 0 ; row, col
	int 0x10 ; video services
	ret


; Non block escape check to go 
; back to the menu.
check_escape:
	mov ah, 0x01 ; keypress from buffer
	int 0x16 ; keyboard input
	jz SHORT .endif_escape
	; key buffer is not empty
		.if_escape:
		mov ah, 0x00
		int 0x16
		cmp ah, 0x01 ; ESC 
		jne SHORT .endif_escape
		; scancode == 0x01
			jmp NEAR main
		.endif_escape:
	ret

; Entry point for the pong game.
pong_main:
	; Change video mode to graphical
	; 320x200
	mov ax, 0x13
	int 0x10

	; Set video memory area
	; Memory is column major order
	mov ax, 0xA000
	mov es, ax

	.loop:
		call check_escape

		; Start Rendering
		mov di, 0
		mov ax, 0
		.y_loop:
			mov bx, 0
			.x_loop:
				mov cl, 0x00 ; Nothing

				; Ball Rendering
				.if_ball_x_gt:
				mov dx, bx
				add dx, 4
				cmp dx, [BALL_X]
				jl SHORT .end_ball_if
					.if_ball_x_lt:
					mov dx, bx
					sub dx, 4
					cmp dx, [BALL_X]
					jg SHORT .end_ball_if
						.if_ball_y_gt:
						mov dl, al
						add dl, 4
						cmp dl, [BALL_Y]
						jl SHORT .end_ball_if
							.if_ball_y_lt:
							mov dl, al
							sub dl, 4
							cmp dl, [BALL_Y]
							jg SHORT .end_ball_if
								mov cl, 0x0F
				.end_ball_if:


				; Left Paddle Rendering
				.if_lpaddle_x_gt:
				cmp bx, 10
				jl SHORT .endif_lpaddle
					.if_lpaddle_x_lt:
					cmp bx, 14
					jg SHORT .endif_lpaddle
						.if_lpaddle_y_gt:
						mov dl, al
						add dl, 20
						cmp dl, [LEFT_PADDLE_Y]
						jl SHORT .endif_lpaddle
							.if_lpaddle_y_lt:
							mov dl, al
							sub dl, 20
							cmp dl, [LEFT_PADDLE_Y]
							jg SHORT .endif_lpaddle
								mov cl, 0x0F
				.endif_lpaddle:

				; Right Paddle Rendering

				.if_rpaddle_x_gt:
				.if_rpaddle_x_lt:
				.if_rpaddle_y_gt:
				.if_rpaddle_y_lt:
				.endif_rpaddle:
				
				; Render Pixel
				mov [es:di], cl
				inc di
			inc bx
			cmp bx, 320
			jl SHORT .x_loop
		inc al
		cmp ax, 200
		jl SHORT .y_loop
		; End Rendering

	jmp SHORT .loop

; Entry point for games not yet constructed.
na_main:
	; move cursor to middle of screen
	mov ah, 0x02 ; cursor pos
	mov bx, 0x00 ; page num
	; row
	mov dl, [NA_GAME_MSG_PADDING]
	mov dh, 12 ; column
	int 0x10 ; video settings

	; print na game message
	mov di, NA_GAME_MSG
	call print_string

	.loop:
		call check_escape
	jmp SHORT .loop

