[bits 16]
[org 0x7C00]

SCREEN_WIDTH equ 20
SCREEN_HEIGHT equ 20
NUM_TITLES equ 2
STACK_SIZE equ 0xAAAA
STACK_BOTTOM equ 0x8000
NA_GAME_MSG_PADDING equ 38
NA_GAME_MSG_ROW_COL equ (12 << 8) | NA_GAME_MSG_PADDING

; txt + data + bss : 0x7C00 (incl) - 0x7FFF (incl)
; heap : 0x8000 (incl) upwards
; stack : 0xFFFE (incl) downwards
section .bss
	SELECTION resb 1

	; Pong Data
	LEFT_PADDLE_Y resb 2
	RIGHT_PADDLE_Y resb 2
	BALL_X resb 2
	BALL_Y resb 2
	BALL_VELOCITY_X resb 2
	BALL_VELOCITY_Y resb 2
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
	mov ah, 0x01
	mov cx, 0x2607
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
				je SHORT .apply_hash
				.if_bottom_boundry:
				cmp bl, SCREEN_HEIGHT - 1
				je SHORT .apply_hash
				.if_left_boundry:
				test cl, cl
				je SHORT .apply_hash
				.if_right_boundry:
				cmp cl, SCREEN_WIDTH - 1
				je SHORT .apply_hash
				jmp SHORT .endif_boundry
				.apply_hash:
					mov al, 0x23
				.endif_boundry:
		
				; ">" Char Rendering
				.if_selector_y:
				mov di, SELECTION
				mov dl, [di]
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
				
				int 0x10
				; Game Titles Rendering
				.if_text_y_gt:
				cmp bl, 1
				jbe SHORT .endif_text
				; if (y > 1)
					.if_text_y_le:
					cmp bl, NUM_TITLES + 1
					ja SHORT .endif_text
					; if (y <= NUM_TITLES + 1)
						.if_text_x_gt:
						cmp cl, [si]
						jb SHORT .endif_text
						; if x >= padding
							.if_text_x_le:
							cmp cl, SCREEN_WIDTH / 2
							jae SHORT .endif_text
							; if x < (SCREEN_WIDTH / 2)
								push bx

								dec bx
								dec bx
								shl bl, 1
								add bx, TITLES
								push di
								mov di, [bx]
								call print_string

								inc si
								pop di
								pop bx
					.endif_text:

			inc cx
			cmp cl, SCREEN_WIDTH
			jb SHORT .loop_x
			; x == SCREEN_WIDTH	

			; add \r\n to screen_string
			mov al, 0x0A
			int 0x10
			mov al, 0x0D
			int 0x10
		inc bx
		cmp bl, SCREEN_HEIGHT
		jb SHORT .loop_y
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
		mov bl, [di]
		.if_up:
		cmp al, 0x48
		jne SHORT .if_down
		test bl, bl
		jbe SHORT .if_down
		; scancode = 0x48
			dec bx
		.if_down:
		cmp al, 0x50
		jne SHORT .endif_keycode
		cmp bl, NUM_TITLES - 1
		je SHORT .endif_keycode
		; scancode = 0x50
			inc bx
		.endif_keycode:
		mov [di], bl

		; Detect enter keypress
		; ENTER = 0x1C0D
		.if_enter:
		cmp al, 0x1C
		jne SHORT .endif_enter
		; scancode = 0x1C 
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
	dec di
	.print_char:
		inc di
		inc cx
		mov al, [di]
		int 0x10 ; Video Interupt
	test al, al
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
	xor bx, bx
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

; ax = y
; bx = x
; bp = x position (modifies)
; si = y position (modifies)
; dx = object height (modifies)
; cl = rendered output (modifies)
master_renderer:
	shr bp, 7
	shr si, 7
	.if_x_gt:
	sub bp, 4
	cmp bx, bp
	jl SHORT .stop_render
		.if_x_lt:
		add bp, 8
		cmp bx, bp
		jg SHORT .stop_render
			.if_y_gt:
			sub si, dx
			cmp ax, si
			jl SHORT .stop_render
				.if_y_lt:
				shl dx, 1
				add si, dx
				cmp ax, si
				jg SHORT .stop_render 
					mov cl, 0x0F
	.stop_render:
	ret

invert_velocity_paddle:
	inc word [bx]
	inc word [bx + 2]
	neg word [bx]
	ret

invert_velocity_wall:
	inc word [bx]
	inc word [bx + 2]
	neg word [bx + 2]
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
				xor cx, cx
				xor dx, dx
				
				; Render Ball
				mov bp, [BALL_X]
				mov si, [BALL_Y]
				mov dl, 4
				call master_renderer

				; Render Left Paddle
				mov bp, 12 << 7
				mov si, [LEFT_PADDLE_Y]
				mov dl, 20
				call master_renderer

				; Render Right Paddle
				mov bp, 308 << 7
				mov si, [RIGHT_PADDLE_Y]
				mov dl, 20
				call master_renderer

				; Render Pixel
				mov [es:di], cl
				inc di
			inc bx
			cmp bx, 320
			jb SHORT .x_loop
		inc ax
		cmp ax, 200
		jb SHORT .y_loop
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
			mov di, LEFT_PADDLE_Y
			mov bx, 10 << 7

			.if_up:
			cmp ah, 0x48
			jne SHORT .if_down
				sub word [di], bx
			.if_down:
			cmp ah, 0x50
			jne SHORT .endif
				add word [di], bx
		.endif:
		; End paddle input

		; Start Ball Movement
		mov di, BALL_X
		mov si, BALL_Y
		mov bx, BALL_VELOCITY_X

		; Left Right Checks
		; If too far to the left, back to mid. Go Right.
		.check_ball_left:
		cmp word [di], 4 << 7
		jb SHORT .reset_ball
		; If too far to the right back to mid. Go Left.
		.check_ball_right:
		cmp word [di], 316 << 7
		ja SHORT .reset_ball

		jmp SHORT .endif_check_ball
		.reset_ball:
			mov word [di], (160 << 7)
			mov word [si], (100 << 7)
			mov word [bx], 0x0020
			mov word [bx + 2], 0x0008
		.endif_check_ball:
		
		; Bounce Checks

		; Bottom Wall
		.if_top_wall:
			cmp word [si], 196 << 7
			jb .endif_top_wall
				call invert_velocity_wall
		.endif_top_wall:

		; Top Wall
		.if_bottom_wall:
			cmp word [si], 4 << 7
			ja .endif_bottom_wall
				call invert_velocity_wall
		.endif_bottom_wall:

		; Left Paddle
		.if_lpc:
		cmp word [di], 16 << 7
		ja .endif_lpc
			jmp .if_y_paddle
		.endif_lpc:

		; Right Paddle
		.if_rpc:
		cmp word [di], 304 << 7
		jb SHORT .endif_rpc
			jmp .if_y_paddle
		.endif_rpc:

		; Y paddle Check
		jmp .endif_y_paddle
		.if_y_paddle:
			mov dx, [di - 2]
			.if_y_paddle_gt:
			sub dx, 20 << 7
			cmp [si], dx
			jl .endif_y_paddle
				.if_y_paddle_lt:
				add dx, 40 << 7
				cmp [si], dx
				jg .endif_y_paddle
					call invert_velocity_paddle
		.endif_y_paddle:
		
		; Apply Velocity
		mov word ax, [bx]
		add [di], ax
		mov word ax, [bx + 2]
		add [si], ax
		; End Ball Movement

		; AI input start
		mov di, RIGHT_PADDLE_Y
		mov dx, [di]
		sub word dx, [si]
		shr dx, 4
		sub word [di], dx
		; AI input stop

	jmp NEAR .loop

GAME_ENTRY_POINTS dw pong_main, na_main
TITLE_ONE db "PONG", 0
TITLE_THREE db "PLCEHLDR", 0
TITLES dw TITLE_ONE, TITLE_THREE
TITLE_PADDINGS db 7, 5
NA_GAME_MSG db "Nope", 0

; Entry point for games not yet constructed.
na_main:
	call clear_screen
	; move cursor to middle of screen
	; cursor pos and page num set by clear_screen
	mov dx, NA_GAME_MSG_ROW_COL
	; video settings
	int 0x10

	; print na game message
	mov di, NA_GAME_MSG
	call print_string

	.loop:
		call check_escape
	jmp SHORT .loop

