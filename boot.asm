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
	TITLE_ONE db "PONG", 0
	TITLE_TWO db "DEMO-TITLE", 0
	TITLE_THREE db "PLCEHLDR", 0
	TITLES dw TITLE_ONE, TITLE_TWO, TITLE_THREE
	TITLE_PADDINGS db 8, 8, 5, 5, 6, 6

section .bss
	SCREEN_STRING resb SCREEN_WIDTH * SCREEN_HEIGHT + (SCREEN_HEIGHT * 2)
	SELECTION resb 1

section .text
main:
	; Set up stack
	mov di, STACK_BOTTOM
	mov ss, di
	mov sp, STACK_TOP

	mov di, SCREEN_STRING
	.start_game_loop:
		call push_registers
		call clear_screen
		call pop_registers
		
		call push_registers
		call fill_screen_string
		call pop_registers
		
		call push_registers		
		call print_string
		call pop_registers
	jmp .start_game_loop

; Save all registers to the stack
; (except bp)
push_registers:
	pop bp ; bp = return address
	push ax
	push bx
	push cx
	push dx
	push si
	push di
	jmp bp

; Load all registers from the stack
; (except bp)
pop_registers:
	pop bp ; bp = return address
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop ax
	jmp bp

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

; void fill_screen_border(char* screen_string)
; Renders a border to screen_string.
; Args:
;     none
; Returns: 
;     none
fill_screen_border:
	mov di, SCREEN_STRING

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
			
			; set char
			mov [di], cl
			inc di
	
		; for(int x = 0; x < SCREEN_WIDTH; <<<x++)>>>
		inc bx
		jmp .start_loop_x
		.end_loop_x:

		; x == SCREEN_WIDTH
		; add \r\n to screen_string
		mov byte [di], 0x0A
		inc di
		mov byte [di], 0x0D
		inc di

	; for(int y = 0; y < SCREEN_HEIGHT; <<<y++)>>>
	inc ax
	jmp .start_loop_y
	.end_loop_y:

	; y == SCREEN_HEIGHT
	ret


; void fill_screen_string(char* screen_string, int selection, int* paddings)
; Renders the current menu state to screen_string.
; Args: 
;     none
; Returns:
;	  none
fill_screen_string:
	; create border around screen
	call push_registers
	call fill_screen_border
	call pop_registers

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

			; char ">" rendering
			.if_selector_x:
			mov cx, [SELECTION]
			add cx, 2
			cmp ax, cx
			jne .endif_selector
			; if (y == SELECTION + 2)
				.if_selector_y:
				cmp bx, 2
				jne .endif_selector
				; if (x == 2)
					mov byte [di], 0x3E ; >
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
						mov cx, SCREEN_WIDTH
						sub cl, [si + 1]
						cmp bl, cl
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
							mov cx, bx ; cx = x
							sub cl, [si] ; cx = x - paddings[0]
							add di, cx ; bp = GAMES[y - 2] + (x - paddings[0])
	
							; derefernce using si instead of bp, as bp uses
							; ss instead of ds 
							mov cl, [di] ; cl = GAMES[y - 2][x - paddings[0]]
							pop di	

							; char at (x, y) = GAMES[y - 2][x - paddings[0]]
							mov [di], cl
			.end_text_if:
			
			; next char
			inc di

		; for(int x = 0; x < SCREEN_WIDTH; <<<x++)>>>
		inc bx
		jmp .start_loop_x
		.end_loop_x:

		; x == SCREEN_WIDTH	

		; compensate for \r\n
		add di, 2
		
		; increment padding array to next padding pair
		; iff currently on a title row
		.if_text_y_gt_2:
			cmp ax, 1
			jle .endif_text_2
			; y > 1
				.if_text_y_lt_2:
				cmp ax, NUM_TITLES + 1
				jg .endif_text_2
				; y < GAMES_COUNT
					add si, 2
		.endif_text_2:
		

	; for(int y = 0; y < SCREEN_HEIGHT; <<<y++)>>>
	inc ax
	jmp .start_loop_y
	.end_loop_y:

	; y == SCREEN_HEIGHT
	ret

