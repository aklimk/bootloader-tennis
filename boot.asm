[bits 16]
[org 0x7C00]

SCREEN_WIDTH equ 20
SCREEN_HEIGHT equ 20
NUM_TITLES equ 3
STACK_TOP equ 0xFFFF
STACK_BOTTOM equ 0xAAAA

; txt + data + bss : 0x7C00 (incl) - 0x7FFF (incl)
; heap : 0x8000 (incl) upwards
; stack : 0xFFFF (incl) downwards
section .data
	TITLE_ONE db "PONG"
	TITLE_TWO db "DEMO-TITLE"
	TITLE_THREE db "PLCEHLDR"
	TITLES dw TITLE_ONE, TITLE_TWO, TITLE_THREE
	TITLE_PADDINGS db 8, 8, 5, 5, 6, 6
	NA_GAME_MSG db "Roadworks", 0
	NA_GAME_MSG_PADDING db 35 
	GAME_ENTRY_POINTS dw pong_main, na_main, na_main

section .bss
	SCREEN_STRING resb SCREEN_WIDTH * SCREEN_HEIGHT + (SCREEN_HEIGHT * 2)
	MENU_EXITED resb 1
	SELECTION resb 1

	; Pong Data
	LEFT_PADDLE_Y resb 1
	LEFT_PADDLE_SCORE resb 1
	RIGHT_PADDLE_Y resb 1
	RIGHT_PADDLE_SCORE resb 1
	BALL_X resb 1
	BALL_Y resb 1
	BALL_VELOCITY resb 1 

section .text
setup_stack:
	mov di, STACK_BOTTOM
	mov ss, di
	mov sp, STACK_TOP

main:
	mov byte [MENU_EXITED], 0
	mov di, SCREEN_STRING
	.start_game_loop:
		call clear_screen
		call fill_screen_string
		mov di, SCREEN_STRING
		call print_string
		call update_selection

		.if_exited:
		cmp byte [MENU_EXITED], 1
		jne .endif_exited
		; MENU_EXITED == 1
			mov bl, [SELECTION]
			shl bl, 1 ; di = 2 * SELECTION
			mov bx, [GAME_ENTRY_POINTS + bx]
			push bx
			call clear_screen
			pop bx
			jmp bx
		.endif_exited:
	jmp .start_game_loop

; void print_string(char* string)
; Prints the screen string to terminal.
; Args: 
;     di: string to print.
;         Assumes its not an empty string.
; Returns:
;     void
print_string:
	mov ah, 0x0E ; teletype
	.print_char:
		mov al, [di]
		int 0x10 ; video services
	inc di
	cmp byte [di], 0x00
	jne .print_char
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

; Reads key from bios interupt, if its wasd, update selection.
update_selection:
	mov ah, 0x00 ; read key press
	int 0x16 ; keyboard io interupt
	; ah = scan code, al = ascii
	; High = scan, low = ascii
	; < = 0x4B00, > = 0x4D00
	; ^ = 0x4800, dwn = 0x5000
	.if_up:
	cmp ah, 0x48
	jne .if_down
	; scancode = 0x48
		sub byte [SELECTION], 1
	.if_down:
	cmp ah, 0x50
	jne .endif_keycode
	; scancode = 0x50
		add byte [SELECTION], 1
	.endif_keycode:

	; Make sure SELECTION stays in a valid range
	.if_selection_over:
	cmp byte [SELECTION], NUM_TITLES
	jl .if_selection_under
	; SELECTION >= NUM_TITLES
		; SELECTION = NUM_TITLES - 1
		mov byte [SELECTION], NUM_TITLES
		sub byte [SELECTION], 1 
	.if_selection_under:
	cmp byte [SELECTION], 0
	jge .endif_selection
	; SELECTION < 0
		mov byte [SELECTION], 0
	.endif_selection:

	; Detect enter keypress
	; ENTER = 0x1C0D
	.if_enter:
	cmp ah, 0x1C
	jne .endif_enter
	; scancode = 0x1C 
		; Exit menu flag true
		mov byte [MENU_EXITED], 1
	.endif_enter:
	ret


; void fill_screen_string(char* screen_string, int selection, int* paddings)
; Renders the current menu state to screen_string.
; Args: 
;     none
; Returns:
;	  none
fill_screen_string:
	mov di, SCREEN_STRING
	mov si, TITLE_PADDINGS

	mov ax, 0
	.start_loop_y:
	cmp ax, SCREEN_HEIGHT
	je .end_loop_y
	; <<<for(int y = 0; y < SCREEN_HEIGHT;>>> y++)

		mov bx, 0
		.start_loop_x:
		cmp bx, SCREEN_WIDTH
		je .end_loop_x
		; <<<for(int x = 0; x < SCREEN_WIDTH;>>> x++)
			; Create Border
			mov cl, 0x20 ; Space
			.if_top_boundry:
			cmp ax, 0
			jne .if_bottom_boundry
			; if (y == 0)
				mov cl, 0x23 ; hash
			.if_bottom_boundry:
			cmp ax, SCREEN_HEIGHT - 1
			jne .if_left_boundry
			; if (y == SCREEN_HEIGHT - 1)
				mov cl, 0x23 ; hash
			.if_left_boundry:
			cmp bx, 0
			jne .if_right_boundry
			; if (x == 0)
				mov cl, 0x23 ; hash
			.if_right_boundry:
			cmp bx, SCREEN_WIDTH - 1
			jne .endif_boundry
			; if (x == SCREEN_WIDTH - 1)
				mov cl, 0x23 ; hash
			.endif_boundry:
			
	
			; Menu Rendering
			; char ">" rendering
			.if_selector_x:
			mov dx, [SELECTION]
			add dx, 2
			cmp ax, dx
			jne .endif_selector
			; if (y == SELECTION + 2)
				.if_selector_y:
				cmp bx, 2
				jne .endif_selector
				; if (x == 2)
					mov cl, 0x3E ; >
			.endif_selector:
			
			; title rendering
			.if_text_y_gt:
			cmp ax, 1
			jle .end_text_if
			; if (y > 1)
				.if_text_y_le:
				cmp ax, NUM_TITLES + 1
				jg .end_text_if
				; if (y <= NUM_TITLES + 1)
					.if_text_x_gt:
					cmp bl, [si]
					jb .end_text_if
					; if (x > paddings[0])
						.if_text_x_2:
						mov dx, SCREEN_WIDTH
						sub dl, [si + 1]
						cmp bl, dl
						jae .end_text_if
						; if (x <= SCREEN_WIDTH - paddings[1])
							; Render Text
							push di
							; GAMES[y - 2]
							mov di, ax 
							sub di, 2 ; bp = y - 2
							; GAMES elem size is 16 bits, thus
							; bp = 2(y - 2) to index correctly
							shl di, 1 
							; bp = char*
							mov di, [TITLES + di] ; bp = GAMES[y - 2]
						
							; GAMES[y - 2][x - paddings[0]]
							mov dx, bx ; dx = x
							sub dl, [si] ; dx = x - paddings[0]
							add di, dx ; bp = GAMES[y - 2] + (x - paddings[0])
	
							; derefernce using si instead of bp, as bp uses
							; ss instead of ds 
							mov cl, [di] ; cl = GAMES[y - 2][x - paddings[0]]
							pop di	
			.end_text_if:
			
			; set char
			mov [di], cl
			inc di

		; for(int x = 0; x < SCREEN_WIDTH; <<<x++)>>>
		inc bx
		jmp .start_loop_x
		.end_loop_x:

		; x == SCREEN_WIDTH	
		; add \r\n to screen_string
		mov word [di], 0x0A0D
		add di, 2
		
		; increment padding array to next padding pair
		; iff currently on a title row
		.if_text_y_gt_2:
			cmp ax, 1
			jle .endif_text_2
			; y > 1
			; don't need to check y < GAMES_COUNT as the
			; padding will never be dereferenced
				add si, 2
		.endif_text_2:
		

	; for(int y = 0; y < SCREEN_HEIGHT; <<<y++)>>>
	inc ax
	jmp .start_loop_y
	.end_loop_y:

	; y == SCREEN_HEIGHT
	ret

; Non block escape check to go 
; back to the menu.
check_escape:
	mov ah, 0x01 ; keypress from buffer
	int 0x16 ; keyboard input
	jz .endif_escape
	; key buffer is not empty
		.if_escape:
		mov ah, 0x00
		int 0x16
		cmp ah, 0x01 ; ESC 
		jne .endif_escape
		; scancode == 0x01
			jmp main
		.endif_escape:
	ret

; Entry point for the pong game.
pong_main:
	.loop:
		call check_escape
	jmp .loop

; Entry point for games not yet constructed.
na_main:
	; move cursor to middle of screen
	mov ah, 0x02 ; cursor pos
	mov bx, 0x00 ; page num
	; row
	mov dl, [NA_GAME_MSG_PADDING]
	add dl, 1
	mov dh, 12 ; column
	int 0x10 ; video settings

	; print na game message
	mov di, NA_GAME_MSG
	call print_string

	.loop:
		call check_escape
	jmp .loop

