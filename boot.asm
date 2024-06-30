[bits 16]
[org 0x7C00]

SCREEN_WIDTH equ 20
SCREEN_HEIGHT equ 20
GAMES_COUNT equ 3

; Assumed 0x7C00 - 0x7FFF
; .text
; .data
; .bss

; Assumed 0x8000 - 0xFFFF
; heap 0x8000 (incl) upwards
; stack 0xFFFF (incl) downwards
section .text
main:
	; Set up stack
	mov di, 0xAAAA
	mov ss, di
	mov sp, 0xFFFF

	; Padding Loop
	; bx = i
	mov bx, 0
	start_padding_loop:
	cmp bx, GAMES_COUNT
	je end_padding_loop
		; get string length of game text (ax)
		; ax = strlen(GAMES[bx])
		push bx
		shl bx, 1	
		mov di, [GAMES + bx]
		call strlen
		pop bx
		
		; calculate total padding (cx)
		; cx = SCREEN_WIDTH - ax
		mov cx, SCREEN_WIDTH
		sub cx, ax
		
		; calculate left padding (GAME_PADDINGS[2*bx]), 
		; GAME_PADDINGS[2*bx] = cx
		mov si, bx
		shl si, 1
		add si, GAME_PADDINGS
		mov [si], cx
		shr byte [si], 1
		
		; calculate right padding (GAME_PADDINGS[2*bx + 1])
		; GAME_PADDINGS[2*bx + 1] = cx ; 2 + ((cx / 2) % 2)
		; cx
		inc si
		mov [si], cx
		shr byte [si], 1
		; ax = dividend
		; bl = divisor
		; al = quotient, ah = remainder
		push bx
		mov ax, [si]
		mov bl, 2
		div bl
		; + (cx / 2) % 2)
		add [si], ah
		pop bx
	inc bx
	jmp start_padding_loop
	end_padding_loop:

	mov cx, 0 ; selection
	mov dx, GAME_PADDINGS
	call clear_screen
	start_game_loop:
		call clear_screen
		call fill_screen_string
		mov di, SCREEN_STRING
		call print_string
	jmp start_game_loop
	stop_game_loop:

; int strlen(string)
; Get the length of a string 
; without the null terminator.
; Args:
;     di: string to get the length of
; Returns:
;     ax: length of string
; Modifies: di, ax, bx
strlen:
	mov bx, 0
	start_null_test_loop:
	cmp byte [di + bx], 0
	je end_null_test_loop
		inc bx
	jmp start_null_test_loop
	end_null_test_loop:
	mov ax, bx
	ret

; void clear_screen()
; Clears the terminal screen.
clear_screen:
	mov ah, 0x07
	mov al, 0x00
	push bx
	push cx
	push dx
		mov bh, 0x07
		mov cx, 0x00
		mov dx, 0x184F
		int 0x10
		mov ah, 0x02
		mov bh, 0
		mov dh, 0
		mov dl, 0
		int 0x10
	pop dx
	pop cx
	pop bx
	ret

; void print_string(char* string)
; Prints the screen string to terminal.
; Args: 
;     none
; Returns:
;     void
print_string:
	mov bx, 0
	mov ah, 0x0E ; function teletype of video services
	print_char:
		mov al, [SCREEN_STRING + bx]
		int 0x10
	inc bx
	cmp byte [SCREEN_STRING + bx], 0
	jne print_char
	ret

; void fill_screen_string(char* screen_string, int selection, int* paddings)
; Renders the current menu state to screen_string.
; Args:
; Returns: void
fill_screen_string:
	push ax
	push bx
	push cx
	push si
	call fill_screen_border
	pop si
	pop cx
	pop bx
	pop ax

	mov ax, 0
	mov di, GAME_PADDINGS
	mov si, SCREEN_STRING
	loop_y_start_2:
	cmp ax, SCREEN_HEIGHT
	je loop_y_end_2
		mov bx, 0
		loop_x_start_2:
		cmp bx, SCREEN_WIDTH
		je loop_x_end_2
			; > rendering
			if_selector_x:
			push dx
			mov dx, cx
			add dx, 2
			cmp ax, dx
			jne endif_selector
				if_selector_y:
				cmp bx, 2
				jne endif_selector
					mov byte [si], 0x3E ; >
			endif_selector:
			pop dx
			
			; text rendering
			if_text_y_1:
			cmp ax, 1
			jle end_text_if
				if_text_y_2:
				cmp ax, GAMES_COUNT + 1
				jg end_text_if
					if_text_x_1:
					cmp bl, [di]
					jb end_text_if
						if_text_x_2:
						mov dx, SCREEN_WIDTH
						sub dx, [di + 1]
						push ax
						mov ax, dx
						cmp bl, al
						pop ax
						jae end_text_if
							; render text
							push ax
							sub al, 2 ; dx = y - 2
							mov ah, 0
							mov bp, ax
							pop ax
						
							mov dx, [GAMES] ; dx = GAMES[y - 2]
							push ax
							mov bp, dx
							mov al, [bp]
							mov [si], al
							mov bp, [GAMES]
							mov al, [bp]
							mov [si], al
							pop ax

							push ax
							mov ax, bx ; ax = x, bx = x
							sub bl, [di] ; bx = x - paddings[0]
							add bx, dx ; bx = GAMES[y - 2] + (x - paddings[0])
							mov bl, [bx] ; bx = GAMES[y - 2][x - paddings[0]]
							mov bx, ax ; restore bx to x
							pop ax
			end_text_if:
			inc si
		inc bx
		jmp loop_x_start_2
		loop_x_end_2:
		
		; should increment padding array?
		if_text_y_1_2:
			cmp ax, 1
			jle endif_text_2
				if_text_y_2_2:
				cmp ax, GAMES_COUNT + 1
				jg endif_text_2
					add di, 2
		endif_text_2:
		
		; \r\n
		add si, 2
	inc ax
	jmp loop_y_start_2
	loop_y_end_2:
	ret
	

; void fill_screen_border(char* screen_string)
; Renders a border in screen_string.
; Args:
;     di: char array to create a border in
; Returns: void
fill_screen_border:
	mov ax, 0
	mov si, 0
	loop_y_start:
	cmp ax, SCREEN_HEIGHT
	je loop_y_end
		mov bx, 0
		loop_x_start:
		cmp bx, SCREEN_WIDTH
		je loop_x_end
			mov cx, 0x20 ; Space
			if_top_boundry:
			cmp ax, 0
			jne if_bottom_boundry
				mov cx, 0x23 ; hash
			if_bottom_boundry:
			cmp ax, SCREEN_HEIGHT - 1
			jne if_left_boundry
				mov cx, 0x23 ; hash
			if_left_boundry:
			cmp bx, 0
			jne if_right_boundry
				mov cx, 0x23 ; hash
			if_right_boundry:
			cmp bx, SCREEN_WIDTH - 1
			jne end_boundry_if
				mov cx, 0x23 ; hash
			end_boundry_if:
			push bx	
			mov bx, di
			mov [bx + si], cx
			pop bx
			inc si
		inc bx
		jmp loop_x_start
		loop_x_end:
		push bx
		mov bx, di
		mov byte [bx + si], 0x0A
		inc si
		mov byte [bx + si], 0x0D
		pop bx
		inc si
	inc ax
	jmp loop_y_start
	loop_y_end:
	ret

section .data
	GAME_ONE db "PONG", 0
	GAME_TWO db "DEMO", 0
	GAME_THREE db "PLACEHOLDER", 0
	GAMES dw GAME_ONE, GAME_TWO, GAME_THREE

section .bss
	SCREEN_STRING resb SCREEN_WIDTH * SCREEN_HEIGHT + (SCREEN_HEIGHT * 2)
	GAME_PADDINGS resb GAMES_COUNT * 2
	SELECTION resb 1
