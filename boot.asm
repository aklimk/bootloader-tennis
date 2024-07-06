[bits 16]
[org 0x7C00]

SCREEN_WIDTH equ 20
SCREEN_HEIGHT equ 20
NUM_TITLES equ 3
STACK_SIZE equ 0xAAAA
STACK_BOTTOM equ 0x8000
; SECTION TOTAL 0B

; txt + data + bss : 0x7C00 (incl) - 0x7FFF (incl)
; heap : 0x8000 (incl) upwards
; stack : 0xFFFE (incl) downwards
section .data
	TITLE_ONE db "PONG" ; 50 4F 4E 47
	TITLE_TWO db "DEMO12" ; 44 45 4D 4F 31 32
	TITLE_THREE db "PLCEHLDR" ; 50 4C 43 45 48 4C 44 52
	; - SECTION 18B
	TITLES dw TITLE_ONE, TITLE_TWO, TITLE_THREE  ; XX XX YY YY ZZ ZZ
	; - SECTION 6B
	TITLE_PADDINGS db 8, 8, 7, 7, 6, 6 ; 08 08 07 07 06 06
	; - SECTION 6B
	NA_GAME_MSG db "Roadworks", 0 ; 52 6F 61 64 77 6F 72 6B 73 00
	; - SECTION 10B
	NA_GAME_MSG_PADDING db 35 ; 23
	; - SECTION 1B
	GAME_ENTRY_POINTS dw pong_main, na_main, na_main ; XX XX YY YY ZZ ZZ
	; - SECTION 6B
; SECTION TOTAL 47B

section .bss
	SCREEN_STRING resb SCREEN_WIDTH * SCREEN_HEIGHT + (SCREEN_HEIGHT * 2)
	SELECTION resb 1

	; Pong Data
	LEFT_PADDLE_Y resb 1
	RIGHT_PADDLE_Y resb 1
	BALL_X resb 1
	BALL_Y resb 1
	BALL_VELOCITY resb 1 
	LEFT_PADDLE_SCORE resb 1
	RIGHT_PADDLE_SCORE resb 1
; SECTION TOTAL 0B

section .text
setup_stack:
	mov ax, STACK_BOTTOM ; B8 00 80 
	mov ss, ax ; 8E D0 
	mov sp, STACK_SIZE ; BC AA AA
	; - SECTION 8B
; - SECTION TOTAL 8B

main:
	; Reset to Text mode
	mov ax, 0x0003 ; B8 03 00
	int 0x10 ; CD 10
	; - SECTION 5B

	; Menu Loop
	.start_game_loop:
		; Clear Menu
		call NEAR clear_screen ; E8 D6 00
		
		; Menu Rendering Start
		mov di, SCREEN_STRING ; BF XX XX
		mov si, TITLE_PADDINGS ; BE XX XX
	; - SECTION 9B
	
		xor ax, ax ; 31 C0
		.loop_y:
			xor bx, bx ; 31 DB
			.loop_x:

				; cl = space
				mov cl, 0x20 ; B1 20
	; - SECTION 6B

				; Create Border
				.if_top_boundry:
				cmp al, 0 ; 3C 00
				jne SHORT .if_bottom_boundry ; 75 02
				; if (y == 0)
					; cl = hash
					mov cl, 0x23 ; B1 23
				.if_bottom_boundry:
				cmp al, SCREEN_HEIGHT - 1 ; 3C 13
				jne SHORT .if_left_boundry ; 75 02
				; if (y == SCREEN_HEIGHT - 1)
					mov cl, 0x23 ; B1 23
				.if_left_boundry:
				cmp bl, 0 ; 80 FB 00
				jne SHORT .if_right_boundry ; 75 02
				; if (x == 0)
					mov cl, 0x23 ; B1 23
				.if_right_boundry:
				cmp bl, SCREEN_WIDTH - 1 ; 80 FB 13
				jne SHORT .endif_boundry ; 75 02
				; if (x == SCREEN_WIDTH - 1)
					mov cl, 0x23 ; B1 23
				.endif_boundry:
	; - SECTION	24B
		
				; ">" Char Rendering
				.if_selector_x:
				mov dl, [SELECTION] ; 8A 16 XX XX
				add dl, 2 ; 80 C2 02
				cmp al, dl ; 38 D0
				jne SHORT .endif_selector ; 75 07
				; if (y == SELECTION + 2)
					.if_selector_y:
					cmp bl, 2 ; 80 FB 02
					jne SHORT .endif_selector ; 75 02
					; if (x == 2)
						; cl = >
						mov cl, 0x3E ; B1 3E
				.endif_selector:
	; - SECTION 18B
				
				; Game Titles Rendering
				.if_text_y_gt:
				cmp al, 1 ; 3C 01
				jle SHORT .end_text_if ; 7E 26
				; if (y > 1)
					.if_text_y_le:
					cmp al, NUM_TITLES + 1 ; 3C 04
					jg SHORT .end_text_if ; 7F 22
					; if (y <= NUM_TITLES + 1)
						.if_text_x_gt:
						cmp bl, [si] ; 3A 1C
						jb SHORT .end_text_if ; 72 1E
						; if (x > paddings[0])
							.if_text_x_2:
							mov dl, SCREEN_WIDTH ; B2 14
							sub dl, [si + 1] ; 2A 54 01
							cmp bl, dl ; 38 D3
							jae SHORT .end_text_if ; 73 15
							; if (x <= SCREEN_WIDTH - paddings[1])
	; - SECTION 21B
								; Render Text
								push di ; 57

								; GAMES[y - 2]
								mov di, ax ; 89 C7
								sub di, 2 ; 83 EF 02
								; GAMES elem size is 16 bits, thus
								; bp = 2(y - 2) to index correctly
								shl di, 1 ; D1 E7
								mov di, [TITLES + di] ; 8B BD XX XX
								; bp = char*
							
								; &GAMES[y - 2][x - paddings[0]]
								mov dl, bl ; 88 DA
								sub dl, [si] ; 2A 14
								add di, dx ; 01 D7
		
								mov cl, [di] ; 8A 0D

								pop di ; 5F
				.end_text_if:
	; - SECTION 21B				

				; set char
				mov [di], cl ; 88 0D
				inc di ; 47

			inc bx ; 43 
			cmp bl, SCREEN_WIDTH ; 80 FB 14
			jl SHORT .loop_x ; 7C 9E

			; x == SCREEN_WIDTH	
			; add \r\n to screen_string
			mov word [di], 0x0A0D ; C7 05 0D 0A
			add di, 2 ; 83 C7 02
	; - SECTION 17B
			
			; increment padding array to next padding pair
			; iff currently on a title row
			.if_text_y_gt_2:
				cmp al, 1 ; 3C 01
				jle SHORT .endif_text_2 ; 7E 03
				; y > 1
				; don't need to check y < GAMES_COUNT as the
				; padding will never be dereferenced
					add si, 2 ; 83 C6 02
			.endif_text_2:
	; - SECTION 7B
			
		inc ax ; 40
		cmp al, SCREEN_HEIGHT ; 3C 14
		jl SHORT .loop_y ; 7C 87
	; - SECTION 6B

		; y == SCREEN_HEIGHT
		; Menu Rendering Stop

		; Display Rendered Menu
		mov di, SCREEN_STRING ; BF XX XX
		call print_string ; E8 XX XX
	; - SECTION 6B

		; Update Menu from Input Start
		; read key press
		xor ah, ah ; 30 E4
		; keyboard io interupt
		int 0x16 ; CD 16
		
		mov al, ah ; 88 E0
	; - SECTION 6B

		; ah = scan code, al = ascii
		; High = scan, low = ascii
		; < = 0x4B00, > = 0x4D00
		; ^ = 0x4800, dwn = 0x5000
		mov bl, [SELECTION] ; 8A 1E XX XX
		.if_up:
		cmp al, 0x48 ; 3C 48
		jne SHORT .if_down ; 75 03
		; scancode = 0x48
			sub bl, 1 ; 80 EB 01
		.if_down:
		cmp al, 0x50 ; 3C 50
		jne SHORT .endif_keycode ; 75 05
		; scancode = 0x50
			add bl, 1 ; 80 C3 01
		.endif_keycode:
	; - SECTION 18B

		; Make sure SELECTION stays in a valid range
		.if_selection_over:
		cmp bl, NUM_TITLES ; 80 FB 03
		jl SHORT .if_selection_under ; 7D 02
		; SELECTION >= NUM_TITLES
			; SELECTION = NUM_TITLES - 1
			mov bl, NUM_TITLES - 1 ; B3 02
		.if_selection_under:
		cmp bl, 0 ; 80 FB 00
		jge SHORT .endif_selection ; 7D 02
		; SELECTION < 0
			xor bl, bl ; 30 DB
		.endif_selection:

		mov [SELECTION], bl ; 88 1E XX XX
	; - SECTION 18B

		; Detect enter keypress
		; ENTER = 0x1C0D
		.if_enter:
		cmp al, 0x1C ; 3C 1C
		jne SHORT .endif_enter ; 75 0F
		; scancode = 0x1C 
			call clear_screen ; E8 1C 00
			mov bl, [SELECTION] ; 8A 1E XX XX
			shl bl, 1 ; D0 E3
			mov bx, [GAME_ENTRY_POINTS + bx] ; 8B 9F XX XX
			jmp bx ; FF E3
		.endif_enter:
		; Update Menu from Input Stop
	; - SECTION 19B	
		
	jmp NEAR .start_game_loop ; E9 34 FF
	; - SECTION 3B
; - SECTION TOTAL 204B

; void print_string(char* string)
; Prints the screen string to terminal.
; Args: 
;     string (di): string to print.
;         Assumes its not an empty string.
print_string:
	; Teletype
	mov ah, 0x0E ; B4 0E
	.print_char:
		mov al, [di] ; 8A 05
		; Video Interupt
		int 0x10 ; CD 10
	inc di ; 46
	cmp byte [di], 0x00 ; 80 3D 00
	jne SHORT .print_char ; 75 F6 
	ret ; C3
; - SECTION TOTAL 13B

; void clear_screen()
; Clears the terminal screen.
clear_screen:
	; scroll down window, clear
	mov ax, 0x0700 ; B8 00 07
	; white foreground, black background
	mov bx, 0x0700 ; BB 00 07
	; upper left position
	xor cx, cx ; 31 C9
	; lower right position
	mov dx, 0x184F ; BA 4F 18
	; video services
	int 0x10 ; CD 10
	; set cursor position
	mov ah, 0x02 ; B4 02
	; page number
	xor bh, bh ; 30 FF
	; row, col
	xor dx, dx ; 31 D2
	; video services
	int 0x10 ; CD 10
	ret ; C3
; - SECTION TOTAL 22B

; Non block escape check to go 
; back to the menu.
check_escape:
	; keypress from buffer
	mov ah, 0x01 ; B4 01
	; keyboard input
	int 0x16 ; CD 16
	jz SHORT .endif_escape ; 74 0C
	; key buffer is not empty
		.if_escape:
		xor ah, ah ; 30 E4
		int 0x16 ; CD 16
		; ESC 
		cmp ah, 0x01 ; 80 FC 01
		jne SHORT .endif_escape ; 75 03
		; scancode == 0x01
			jmp NEAR main ; E9 XX XX
		.endif_escape:
	ret ; C3
; - SECTION TOTAL 19B

; Entry point for the pong game.
pong_main:
	; Change video mode to graphical
	; 320x200
	mov ax, 0x13 ; B8 13 00
	int 0x10 ; CD 10

	; Set video memory area
	; Memory is column major order
	mov ax, 0xA000 ; B8 00 A0
	mov es, ax ; 8E C0
	; - SECTION 10B

	.loop:
		call check_escape ; E8 XX XX

		; Start Rendering
		xor di, di ; 31 FF
		xor ax, ax ; 31 C0
		.y_loop:
			xor bx, bx ; 31 DB
			.x_loop:
				; Nothing
				xor cl, cl ; 30 C9
	; - SECTION 11B

				; Ball Rendering
				mov si, [BALL_X] ; 8B 36 XX XX
				mov dl, [BALL_Y] ; 8A 16 XX XX

				push ax ; 50
				push bx ; 53
				.if_ball_x_gt:
				add bx, 4 ; 83 C3 04
				cmp bx, si ; 39 F3
				jl SHORT .end_ball_if ; 7C 15
					.if_ball_x_lt:
					sub bx, 8 ; 83 EB 08
					cmp bx, si ; 39 F3
					jg SHORT .end_ball_if ; 7F 12
						.if_ball_y_gt:
						add al, 4 ; 04 04
						cmp al, dl ; 38 D0
						jl SHORT .end_ball_if ; 7C 0A
							.if_ball_y_lt:
							sub al, 8 ; 2C 08 
							cmp al, dl ; 38 D0
							jg SHORT .end_ball_if ; 7F 02
								mov cl, 0x0F ; B1 0F
				.end_ball_if:
				pop bx ; 5B
				pop ax ; 58
	; - SECTION 40B

				; Left Paddle Rendering
				; dl = LPY, dr = RPY
				mov dx, [LEFT_PADDLE_Y] ; 8B 16 XX XX

				push ax ;  50
				.if_lpaddle_x_gt:
				cmp bx, 10 ; 83 FB 0A
				jl SHORT .endif_lpaddle ; 7C 17
					.if_lpaddle_x_lt:
					cmp bx, 14 ; 83 FB 0E
					jg SHORT .endif_lpaddle ; 7F 17
						.if_lpaddle_y_gt:
						add al, 20 ; 04 14
						cmp al, dl ; 38 D0
						jl SHORT .endif_lpaddle ; 7C 0A
							.if_lpaddle_y_lt:
							sub al, 40 ; 2C 28
							cmp al, dl ; 7F 02
							jg SHORT .endif_lpaddle ; 7F 02
								mov cl, 0x0F ; B1 0F
				.endif_lpaddle:
				pop ax ; 58
	; - SECTION 30B

				; Right Paddle Rendering
				.if_rpaddle_x_gt:
				.if_rpaddle_x_lt:
				.if_rpaddle_y_gt:
				.if_rpaddle_y_lt:
				.endif_rpaddle:
	; - SECTION 0B

				; Render Pixel
				mov [es:di], cl ; 26 88 0D
				inc di ; 47
			inc bx ; 43
			cmp bx, 320 ; 81 FB 40 01
			jl SHORT .x_loop ; 7C A3
		inc ax ; 40
		cmp ax, 200 ; 3D C8 00
		jl SHORT .y_loop ; 7C 99
		; End Rendering
	; - SECTION 18B

	jmp SHORT .loop ; EB 8E
	; - SECTION 4B
; - SECTION TOTAL 113B

; Entry point for games not yet constructed.
na_main:
	; move cursor to middle of screen
	; cursor pos
	mov ah, 0x02 ; B4 02
	; page num
	xor bx, bx ; 31 DB
	; row
	mov dl, [NA_GAME_MSG_PADDING] ; 8A 16 XX XX
	; column
	mov dh, 12 ; B6 0C
	; video settings
	int 0x10 ; CD 10

	; print na game message
	mov di, NA_GAME_MSG ; BF XX XX
	call print_string ; E8 XX XX

	.loop:
		call check_escape ; E8 XX XX
	jmp SHORT .loop ; EB FB
; - SECTION TOTAL 23B

