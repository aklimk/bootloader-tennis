[bits 16]
[org 0x7C00]

; Compile time constants.

STACK_SIZE equ 0xAAAA
STACK_BOTTOM equ 0x8000

SCREEN_WIDTH equ 320
SCREEN_HEIGHT equ 200
RANGE equ (SCREEN_HEIGHT * SCREEN_WIDTH) / 2

BALL_DIM equ 5
BALL_START_X equ (SCREEN_WIDTH - BALL_DIM) / 2
BALL_START_Y equ (SCREEN_HEIGHT - BALL_DIM) / 2
PLAYER_PADDLE_OFFSET equ 20
ENEMY_PADDLE_OFFSET equ 319 - PLAYER_PADDLE_OFFSET - PLAYER_PADDLE_WIDTH
PLAYER_PADDLE_WIDTH equ 5
PLAYER_PADDLE_HEIGHT equ 50



; ~~~~~ CODE SECTION ~~~~~

section .text


; ~~~~~ SETUP STACK SPACE ~~~~~
setup_stack:
	; Set up stack space by setting stack segment register and stack pointer register.
	mov ax, STACK_BOTTOM
	mov ss, ax
	mov sp, STACK_SIZE


main:
	; ~~~~~ SETUP VIDEO ~~~~~
	; 320x200 8 bit color graphical mode.
	; Memory adressing is done using a segment and offset.
	; Video memory starts at segment 0xA000.
	; Video memory is 1 byte per pixel, column major, index from top left.
	mov ax, 0x13
	int 0x10

	; ~~~~~ 16 BIT REGISTERS AND GAME VARIABLE MAP ~~~~~

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
	; Leaves dx (dl, dh), bp free



	; ~~~~~ INITILIZE GAME VARIABLES ~~~~~

	; ~~~~~ INITILIZE BALL VELOCITY ~~~~~~
	; Use the gen rand velocity function to generate a random velocity for both ball x and y.
	; gen_rand_velocity generates to the dl register.
	call gen_rand_velocity
	mov bl, ah
	call gen_rand_velocity
	mov bh, ah

	; ~~~~~ INITILIZE PADDLES ~~~~~
	; Both paddles start at 1, at the top, just after the border.
	mov ax, 0x0101

	; ~~~~~ INITILIZE BALL POSITION ~~~~~	
	; Ball position starts at the center.
	mov si, BALL_START_X
	mov di, BALL_START_Y

	; ~~~~~ INITILIZE PADDLE SCORES ~~~~~
	xor cx, cx ; one byte register clear



	; ~~~~~ MAIN GAME LOOP ~~~~~
	.game_loop:
		; ~~~~~ BEEPING TEST ~~~~~
		; Beep test.
		; push ax
		; mov ah, 0x0E
		; mov al, 7
		; int 0x10
		; pop ax



		; ~~~~~ GAME INPUT LOGIC ~~~~~
		; Start paddle input, use non-blocking poll of keyboard presses.
		; ah = key scan code, zf = 0 if key presed. al = ascii char, ax = 0 if no key pressed.
		push ax
		mov ah, 0x01
		int 0x16

		jnz SHORT .pop_endif
			pop ax 
		.pop_endif:

		jz SHORT .endif
			; If key detected, redo with blocking input. As non-blocking seems to miss keys.
			xor ah, ah
			int 0x16
			; Move scan code to dh, so ax can be popped from the stack.
			mov dh, ah
			pop ax

			; Test if 0x48 (up) scancode detected.
			cmp dh, 0x48
			jne SHORT .if_down
				; Block movment if paddle is too high.
				cmp al, 4
				jbe SHORT .if_down
					sub al, 4
			; Test if 0x50 (down) scancode detected.
			.if_down:
			cmp dh, 0x50
			jne SHORT .endif
				; Block movement if paddle is too low.
				cmp al, 199 - PLAYER_PADDLE_HEIGHT - 4
				jae SHORT .endif
					add al, 4
		.endif:


		
		; ~~~~~ GAME PHYSICS LOGIC ~~~~~

		; ~~~~~ BALL POSITION UPDATE ~~~~~
		; Need to upgrade 8 bit register to 16 bit in order to add together.
		; movsx is a sign-preserving mov.
		; X component.
		xor dx, dx
		movsx dx, bl
		add si, dx
		; Y component.
		xor dx, dx 
		movsx dx, bh
		add di, dx

		; ~~~~~ BALL COLLISION DETECTION ~~~~~

		; ~~~~~ PLAYER SCORING ZONE ~~~~~
		; Detect if the right side of the ball is to the left of the left edge of the left paddle.
		; This indicates the enemy has scored.
		cmp si, PLAYER_PADDLE_OFFSET - BALL_DIM
		jae .end_if_left_wall
			; Enemy has scored.
			inc ch
			jmp show_score
		.end_if_left_wall:

		; ~~~~~ ENEMY SCORING ZONE ~~~~~
		; Detect if the left side of the ball is to the right of the right edge of the right paddle.
		cmp si, 319 - PLAYER_PADDLE_OFFSET - PLAYER_PADDLE_WIDTH
		jbe .end_if_right_wall
			; Player has scored.
			inc cl
			jmp show_score
		.end_if_right_wall:

		; ~~~~~ LEFT PADDLE ~~~~~
		push ax
		xor ah, ah
		mov bp, ax
		pop ax

		; Check if the left edge of the ball is left of the right edge of the left paddle.
		; if ballposx > OFFSET + WIDTH then no hit.
		cmp si, PLAYER_PADDLE_OFFSET + PLAYER_PADDLE_WIDTH 
		ja SHORT .endif_left_paddle_x
			call paddle_vertical_hit_detection
		.endif_left_paddle_x:

		; ~~~~~ RIGHT PADDLE ~~~~~
		push ax
		mov al, ah
		xor ah, ah
		mov bp, ax
		pop ax

		; Check if the right edge of the ball is left of the left edge of the right paddle.
		; if ballposx + BALLSIZEX < 319 - OFFSET - WIDTH then no hit.
		; if ballposx < 319 - OFFSET - WIDTH - BALLSIZEX then no hit.
		cmp si, 319 - PLAYER_PADDLE_OFFSET - PLAYER_PADDLE_WIDTH - BALL_DIM
		jb SHORT .endif_right_paddle_x
			call paddle_vertical_hit_detection
		.endif_right_paddle_x:

		; ~~~~~ ROOF ~~~~~
		cmp di, 1
		jae .end_if_roof
			; Flip y velocity.
			neg bh
		.end_if_roof:

		; ~~~~~ FLOOR ~~~~~
		cmp di, 199 - BALL_DIM
		jbe .end_if_floor
			; Flip y velocity.
			neg bh
		.end_if_floor:



		; ~~~~~ AI PLAYER MOVEMENT ~~~~~
		; If ball is higher than paddle, go up. Otherwise go down.
		xor dx, dx
		mov dl, ah
		add dx, PLAYER_PADDLE_HEIGHT / 2
		; Jump if paddle has a lower or equal value (is higher up) than the ball.
		cmp dx, di
		jbe .endif_move_up	
			; Jump if enemy paddle is at 1 (can't move up).
			cmp ah, 1
			jbe .endif_move_up
				dec ah
		.endif_move_up:
		xor dx, dx
		mov dl, ah
		add dx, PLAYER_PADDLE_HEIGHT / 2
		; Jump if paddle has a higher or equal value (is lower down) than the ball.
		cmp dx, di
		jae .endif_move_down
			; Jump if enemy paddle is at 197 (Can't move down).
			cmp ah, 198 - PLAYER_PADDLE_HEIGHT
			jae .endif_move_down
				inc ah	
		.endif_move_down:


		
		; ~~~~~ RENDERING LOGIC ~~~~~
		; Frames are rendered to a temporary memory area (0x4000), and then copied
		; graphical memory area for 13h mode (0xA000). 
		; This prevents tearing effects due to video updates on partially completed
		; renders.

		; Ds does not support direct mov, use a general register first.
		; ES holds the memory segment for rendering to, direct it to a temporary
		; area.
		push ax
		mov ax, 0x4000
		mov es, ax
		pop ax


		; Render elements by using two for loops and jmp conditions.
		; This is slower than rendering each element individually but saves bytes.
		; BX, CX and DX are used as they are not needed in the rendering code.
		push bx
		push cx
		xor bx, bx

		.x_render_loop:
		; For x < 320
		cmp bx, 320
		jae .endif_x_render_loop
			xor cx, cx
			.y_render_loop:
			; For y < 200
			cmp cx, 200
			jae .endif_y_render_loop
				; Main render loop.
				; Assume pixel is being drawn unless found otherwise.
				; Avoids a few mov instructions.
				mov dl, 0x0F

				cmp bx, 0
				ja .endif_left_segment
					; Left segment.
					jmp .endif_blank_area
				.endif_left_segment:

				cmp cx, 0
				ja .endif_top_segment
					; Top segment.
					jmp .endif_blank_area
				.endif_top_segment:

				cmp bx, 319
				jb .endif_right_segment
					; Right segment.
					jmp .endif_blank_area
				.endif_right_segment:

				cmp cx, 199
				jb .endif_bottom_segment 
					; Bottom segment.
					jmp .endif_blank_area
				.endif_bottom_segment:

				; Left paddle.
				; Right paddle.
				; Ball.

				; ELSE
				; Otherwise draw blank pixel.
				mov dl, 0x00 

				.endif_blank_area:

				; Draw calculated pixel to rendering area.
				push si 
				push di
				mov si, cx
				mov di, bx
				imul si, SCREEN_WIDTH
				add si, di
				mov BYTE [es:si], dl
				pop di
				pop si

				inc cx
				jmp .y_render_loop 

			.endif_y_render_loop:

			inc bx
			jmp .x_render_loop

		.endif_x_render_loop:

		pop cx
		pop bx


		; Copy render over to actuall video memory area. (flip).
		pusha
		cld
		; Set ds to source memory area
		push es
		pop ds 
		; Set es to destination memory area
		mov ax, 0xA000
		mov es, ax

		; Clear indexes and copy memory over.
		xor si, si
		xor di, di
		mov cx, RANGE
		rep movsw
		popa
		
		; Limit fps to 60 using bios wait interupts.
		pusha
		mov  cx, 0
   		mov  dx, 16667  
    	mov  ah, 86h
    	int  15h
		popa

		jmp .game_loop
	 

; Ball velocity starts at a random number from -3 - 3 (not 0) for both x and y.
; Generates to  register.
gen_rand_velocity:
	; Read byte from timer, psuedo-random byte.
	in al, 0x40

	; Multiply al by 6 and put it into ax.
	; overflow causes ah to be in the range 0-5.	
	mov bl, 6
	mul bl

	; Shift the range 0-5 to -3 to 2. 
	sub ah, 3

	; Flip the cf flag and add it back to ah.
	; cf is 1 for positive results (0, 1, 2),
	; range becomes -3 - -1 and 1 - 3 .
	cmc
	adc ah, 0

	ret



; General hit detection for the vertical portion of a paddle.
; Paddle y position should be stored in bp register as input.
; No output.
paddle_vertical_hit_detection:
	; Check if the ball is below the top edge of the paddle.
	xor dx, dx
	mov dx, bp
	sub dx, BALL_DIM
	cmp di, dx
	jbe .endif_paddle_y1
		; Check if the ball is above the bottom edge of the paddle.
		xor dx, dx
		mov dx, bp
		add dx, PLAYER_PADDLE_HEIGHT
		cmp di, dx
		jae .endif_paddle_y2
			; Ball is hitting the paddle. 
			; Invert y velocity then
			; Increment both vertical and horizontal velocity 
			; in whatever direction its heading.
			or bh, bh
			jns SHORT .endif_left_dec1
				dec bh
			.endif_left_dec1:
			inc bh

			neg bl
			or bl, bl
			jns SHORT .endif_left_dec2
				dec bl
			.endif_left_dec2:
			inc bl
		.endif_paddle_y2:
	.endif_paddle_y1:
	ret



; cl should store score.
; si x position (text rows)
; di y position (text cols)
show_score_single:
	; Move cursor to (si, di) position.
	; Page 0.
	xor bh, bh
	; Bright white palette
	mov bl, 15
	; DH = row, DL = col
	shl di, 8
	mov dx, di
	or dx, si
	; Move cursor opcode.
	mov ah, 0x02
	int 0x10

	xor ax, ax
	mov al, cl
	aam
	xchg al, ah
	add ax, 0x3030

	mov dl, ah
	mov ah, 0x0E
	int 0x10
	mov al, dl
	mov ah, 0x0E
	int 0x10

	ret


show_score:
	pusha 

	; Cheap clear screen
	mov ax, 0x13
	int 0x10

	pusha 
	mov si, 10 
	mov di, 12
	call show_score_single
	popa 

	pusha 
	mov si, 27
	mov di, 12
	mov cl, ch
	call show_score_single
	popa 

	; Give screen 3 seconds.
	mov cx, 3000000 >> 16 
	mov dx, 0xFFFF
	mov ah, 0x86
	int 0x15

	popa

	jmp main
