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
	TITLE_ONE db "PONG", 0
	TITLE_TWO db "DEMO12", 0
	TITLE_THREE db "PLCEHLDR", 0
	TITLES dw TITLE_ONE, TITLE_TWO, TITLE_THREE
	TITLE_PADDINGS db 8, 7, 6
	NA_GAME_MSG db "Roadworks", 0
	NA_GAME_MSG_PADDING db 35
	GAME_ENTRY_POINTS dw pong_main, na_main, na_main

section .bss
	SCREEN_STRING resb SCREEN_WIDTH * SCREEN_HEIGHT + (SCREEN_HEIGHT * 2)
	SELECTION resb 1

	; Pong Data
	PADDLES_Y resb 2
	BALL_X resb 2
	BALL_Y resb 1
	BALL_VELOCITY resb 1 
	LEFT_PADDLE_SCORE resb 1
	RIGHT_PADDLE_SCORE resb 1

section .text
setup_stack:
	mov ax, STACK_BOTTOM
	mov ss, ax
	mov sp, STACK_SIZE

main:
	; Reset to Text mode
	mov ax, 0x0003
	int 0x10

	; Menu Loop
	.start_game_loop:
		call NEAR clear_screen
		
		; Menu Rendering Start
		mov ah, 0x0E
		mov si, TITLE_PADDINGS
	
		xor bx, bx 
		.loop_y:
			xor cx, cx
			.loop_x:
				mov al, 0x20 ; space

				; Create Border
				.if_top_boundry:
				test bl, bl
				jne SHORT .if_bottom_boundry
					; if (y == 0)
					mov al, 0x23 ; hash
				.if_bottom_boundry:
				cmp bl, SCREEN_HEIGHT - 1
				jne SHORT .if_left_boundry
					; if (y == SCREEN_HEIGHT - 1)
					mov al, 0x23
				.if_left_boundry:
				test cl, cl
				jne SHORT .if_right_boundry
					; if (x == 0)
					mov al, 0x23
				.if_right_boundry:
				cmp cl, SCREEN_WIDTH - 1
				jne SHORT .endif_boundry
					; if (x == SCREEN_WIDTH - 1)
					mov al, 0x23
				.endif_boundry:
		
				; ">" Char Rendering
				.if_selector_y:
				mov dl, [SELECTION]
				inc dx
				inc dx
				cmp bl, dl
				jne SHORT .endif_selector
					; if (y == SELECTION + 2)
					.if_selector_x:
					cmp cl, 2
					jne SHORT .endif_selector
						; if (x == 2)
						mov al, 0x3E
							; cl = >
				.endif_selector:
				
				; Game Titles Rendering
				.if_text_y_gt:
				cmp bl, 1
				jle SHORT .endif_text
				; if (y > 1)
					.if_text_y_le:
					cmp bl, NUM_TITLES + 1
					jg SHORT .endif_text
					; if (y <= NUM_TITLES + 1)
						.if_text_x_gt:
						cmp cl, [si]
						jl SHORT .endif_text
						; if x >= padding
							.if_text_x_le:
							cmp cl, SCREEN_WIDTH / 2
							jge SHORT .endif_text
							; if x < (SCREEN_WIDTH / 2)
								push bx

								dec bx
								dec bx
								shl bl, 1
								; bx = 2(y - 2)

								add bx, TITLES
								mov di, [bx]
								; di = TITLES[y - 2]
								
								call print_string

								xor al, al
								inc si

								pop bx
					.endif_text:

				int 0x10
			inc cx
			cmp cl, SCREEN_WIDTH
			jl SHORT .loop_x
			; x == SCREEN_WIDTH	

			; add \r\n to screen_string
			mov al, 0x0A
			int 0x10
			mov al, 0x0D
			int 0x10
		inc bx
		cmp bl, SCREEN_HEIGHT
		jl SHORT .loop_y
		; y == SCREEN_HEIGHT
		; Menu Rendering Stop

		; Update Menu from Input Start
		; read key press
		xor ah, ah
		; keyboard io interupt
		int 0x16
		mov al, ah

		; ah = scan code, al = ascii
		; High = scan, low = ascii
		; < = 0x4B00, > = 0x4D00
		; ^ = 0x4800, dwn = 0x5000
		mov bl, [SELECTION]
		.if_up:
		cmp al, 0x48
		jne SHORT .if_down
		; scancode = 0x48
			dec bx
		.if_down:
		cmp al, 0x50
		jne SHORT .endif_keycode
		; scancode = 0x50
			inc bx
		.endif_keycode:

		; Make sure SELECTION stays in a valid range
		.if_selection_over:
		cmp bl, NUM_TITLES
		jl SHORT .if_selection_under
			; SELECTION >= NUM_TITLES
			mov bl, NUM_TITLES - 1
		.if_selection_under:
		test bl, bl
		jge SHORT .endif_selection
			; SELECTION < 0
			xor bl, bl
		.endif_selection:

		mov [SELECTION], bl

		; Detect enter keypress
		; ENTER = 0x1C0D
		.if_enter:
		cmp al, 0x1C
		jne SHORT .endif_enter
		; scancode = 0x1C 
			call clear_screen
			mov bl, [SELECTION]
			shl bl, 1
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
		inc cx
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
	; scroll down window, clear
	mov ax, 0x0700
	; white foreground, black background
	mov bx, ax
	; upper left position
	xor cx, cx
	; lower right position
	mov dx, 0x184F
	; video services
	int 0x10
	; set cursor position
	mov ah, 0x02
	; page number
	xor bh, bh
	; row, col
	xor dx, dx
	; video services
	int 0x10
	ret

; Non block escape check to go 
; back to the menu.
check_escape:
	; keypress from buffer
	mov ah, 0x01
	; keyboard input
	int 0x16
	jz SHORT .endif_escape
	; key buffer is not empty
		.if_escape:
		xor ah, ah
		int 0x16
		; ESC 
		cmp ah, 0x01
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
		xor di, di
		xor ax, ax
		.y_loop:
			xor bx, bx
			.x_loop:
				xor cl, cl

				; Ball Rendering
				mov si, [BALL_X]
				mov dl, [BALL_Y]

				push ax
				push bx
				.if_ball_x_gt:
				add bx, 4
				cmp bx, si
				jl SHORT .end_ball_if
					.if_ball_x_lt:
					sub bx, 8
					cmp bx, si
					jg SHORT .end_ball_if
						.if_ball_y_gt:
						add al, 4
						cmp al, dl
						jl SHORT .end_ball_if
							.if_ball_y_lt:
							sub al, 8
							cmp al, dl
							jg SHORT .end_ball_if
								mov cl, 0x0F
				.end_ball_if:
				pop bx
				pop ax

				; Left Paddle Rendering
				; dl = LPY, dr = RPY
				mov dx, [PADDLES_Y]

				push ax
				.if_lpaddle_x_gt:
				cmp bx, 10
				jl SHORT .endif_lpaddle
					.if_lpaddle_x_lt:
					cmp bx, 14
					jg SHORT .endif_lpaddle
						.if_lpaddle_y_gt:
						add al, 20
						cmp al, dl
						jl SHORT .endif_lpaddle
							.if_lpaddle_y_lt:
							sub al, 40
							cmp al, dl
							jg SHORT .endif_lpaddle
								mov cl, 0x0F
				.endif_lpaddle:
				pop ax

				; Right Paddle Rendering
				push ax
				.if_rpaddle_x_gt:
				cmp bx, 306
				jl SHORT .endif_rpaddle
					.if_rpaddle_x_lt:
					cmp bx, 310
					jg SHORT .endif_rpaddle
						.if_rpaddle_y_gt:
						add al, 20
						cmp al, dh
						jl SHORT .endif_rpaddle
							.if_rpaddle_y_lt:
							sub al, 40
							cmp al, dh
							jg SHORT .endif_rpaddle
								mov cl, 0x0F
				.endif_rpaddle:
				pop ax

				; Render Pixel
				mov [es:di], cl
				inc di
			inc bx
			cmp bx, 320
			jl SHORT .x_loop
		inc ax
		cmp ax, 200
		jl SHORT .y_loop
		; End Rendering

		
		; Start paddle input
		; keypress from buffer
		mov ah, 0x01
		; keyboard input
		int 0x16
		jz SHORT .endif
			; key buffer is not empty
			xor ah, ah
			int 0x16
			mov di, PADDLES_Y
			.if_up:
			cmp ah, 0x48
			jne SHORT .if_down
				sub byte [di], 10
			.if_down:
			cmp ah, 0x50
			jne SHORT .endif
				add byte [di], 10
			.endif:
		; End paddle input

		; Start ai paddle
		; End ai paddle

	jmp NEAR .loop

; Entry point for games not yet constructed.
na_main:
	; move cursor to middle of screen
	; cursor pos
	mov ah, 0x02
	; page num
	xor bx, bx
	; row
	mov dl, [NA_GAME_MSG_PADDING]
	; column
	mov dh, 12
	; video settings
	int 0x10

	; print na game message
	mov di, NA_GAME_MSG
	call print_string

	.loop:
		call check_escape
	jmp SHORT .loop

