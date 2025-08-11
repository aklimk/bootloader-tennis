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
; Setup stack for pushing/popping and function calling.
setup_stack:
	; Set up stack space by setting stack segment register and stack pointer register.
	mov ax, STACK_BOTTOM
	mov ss, ax
	mov sp, STACK_SIZE


main:
	; ~~~~~ INITILIZE PADDLE SCORES ~~~~~
	xor cx, cx ; one byte register clear

	after_score_init:	
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
	; Left paddle vertical position : dl 
	; Right paddle vertical position : dh
	; Ball velocity x : bl
	; Ball velocity y : bh
	; Ball position x : si
	; Ball position y : di 
	; Left paddle score : cl
	; Right paddle score : ch
	; Leaves ax (al, ah), bp free



	; ~~~~~ INITILIZE GAME VARIABLES ~~~~~

	; ~~~~~ INITILIZE BALL VELOCITY ~~~~~~
	; Use the gen rand velocity function to generate a random velocity for both ball x and y.
	; gen_rand_velocity generates to the dl register.
	; Do stack stuff to increase randomness.
	pusha
	popa
	call gen_rand_velocity
	mov bl, ah
	call gen_rand_velocity
	mov bh, ah

	; ~~~~~ INITILIZE PADDLES ~~~~~
	; Both paddles start at 1, at the top, just after the border.
	mov dx, 0x0101

	; ~~~~~ INITILIZE BALL POSITION ~~~~~	
	; Ball position starts at the center.
	mov si, BALL_START_X
	mov di, BALL_START_Y



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
		mov ah, 0x01
		int 0x16

		jz SHORT .endif
			; If key detected, redo with blocking input. As non-blocking seems to miss keys.
			xor ah, ah
			int 0x16

			; Test if 0x48 (up) scancode detected.
			cmp ah, 0x48
			jne SHORT .if_down
				; Block movment if paddle is too high.
				cmp dl, 4
				jbe SHORT .if_down
					sub dl, 4
			; Test if 0x50 (down) scancode detected.
			.if_down:
			cmp ah, 0x50
			jne SHORT .endif
				; Block movement if paddle is too low.
				cmp dl, 199 - PLAYER_PADDLE_HEIGHT - 4
				jae SHORT .endif
					add dl, 4
		.endif:


		
		; ~~~~~ GAME PHYSICS LOGIC ~~~~~

		; ~~~~~ BALL POSITION UPDATE ~~~~~
		; Need to upgrade 8 bit register to 16 bit in order to add together.
		; movsx is a sign-preserving mov.
		; X component.
		xor ax, ax
		movsx ax, bl
		add si, ax
		; Y component.
		xor ax, ax 
		movsx ax, bh
		add di, ax

		; ~~~~~ BALL COLLISION DETECTION ~~~~~

		; ~~~~~ PLAYER SCORING ZONE ~~~~~
		; Detect if the right side of the ball is to the left of the left edge of the left paddle.
		; This indicates the enemy has scored.
		cmp si, PLAYER_PADDLE_OFFSET - BALL_DIM
		jae SHORT .end_if_left_wall
			; Enemy has scored.
			inc ch
			jmp show_score
		.end_if_left_wall:

		; ~~~~~ ENEMY SCORING ZONE ~~~~~
		; Detect if the left side of the ball is to the right of the right edge of the right paddle.
		cmp si, 319 - PLAYER_PADDLE_OFFSET - PLAYER_PADDLE_WIDTH
		jbe SHORT .end_if_right_wall
			; Player has scored.
			inc cl
			jmp show_score
		.end_if_right_wall:

		; ~~~~~ LEFT PADDLE ~~~~~
		xor ax, ax 
		mov al, dl
		mov bp, ax

		; Check if the left edge of the ball is left of the right edge of the left paddle.
		; if ballposx > OFFSET + WIDTH then no hit.
		cmp si, PLAYER_PADDLE_OFFSET + PLAYER_PADDLE_WIDTH 
		ja SHORT .endif_left_paddle_x
			call paddle_vertical_hit_detection
		.endif_left_paddle_x:

		; ~~~~~ RIGHT PADDLE ~~~~~
		xor ax, ax 
		mov al, dh
		mov bp, ax

		; Check if the right edge of the ball is left of the left edge of the right paddle.
		; if ballposx + BALLSIZEX < 319 - OFFSET - WIDTH then no hit.
		; if ballposx < 319 - OFFSET - WIDTH - BALLSIZEX then no hit.
		cmp si, 319 - PLAYER_PADDLE_OFFSET - PLAYER_PADDLE_WIDTH - BALL_DIM
		jb SHORT .endif_right_paddle_x
			call paddle_vertical_hit_detection
		.endif_right_paddle_x:

		; ~~~~~ ROOF ~~~~~
		cmp di, 1
		jae SHORT .end_if_roof
			; Flip y velocity.
			neg bh
		.end_if_roof:

		; ~~~~~ FLOOR ~~~~~
		cmp di, 199 - BALL_DIM
		jbe SHORT .end_if_floor
			; Flip y velocity.
			neg bh
		.end_if_floor:



		; ~~~~~ AI PLAYER MOVEMENT ~~~~~
		; If ball is higher than paddle, go up. Otherwise go down.
		xor ax, ax
		mov al, dh
		add ax, PLAYER_PADDLE_HEIGHT / 2
		; Jump if paddle has a lower or equal value (is higher up) than the ball.
		cmp ax, di
		jbe SHORT .endif_move_up	
			; Jump if enemy paddle is at 3 or below (can't move up).
			cmp dh, 4
			jb SHORT .endif_move_up
				sub dh, 3
		.endif_move_up:

		xor ax, ax
		mov al, dh
		add ax, PLAYER_PADDLE_HEIGHT / 2
		; Jump if paddle has a higher or equal value (is lower down) than the ball.
		cmp ax, di
		jae SHORT .endif_move_down
			; Jump if enemy paddle is at 197 or above (Can't move down).
			cmp dh, 198 - PLAYER_PADDLE_HEIGHT - 3
			ja SHORT .endif_move_down
				sub dh, 3
		.endif_move_down:


		
		; ~~~~~ RENDERING LOGIC ~~~~~
		; Frames are rendered to a temporary memory area (0x4000), and then copied
		; graphical memory area for 13h mode (0xA000). 
		; This prevents tearing effects due to video updates on partially completed
		; renders.

		; Ds does not support direct mov, use a general register first.
		; ES holds the memory segment for rendering to, direct it to a temporary
		; area.
		mov ax, 0x4000
		mov es, ax


		; Render elements by using two for loops and jmp conditions.
		; This is slower than rendering each element individually but saves bytes.
		; BX, CX and DX are used as they are not needed in the rendering code.
		push bx
		push cx
		mov bx, 320

		.x_render_loop:
		; For x < 320
		js .endif_x_render_loop
			mov cx, 200
			.y_render_loop:
			; For y < 200
			js .endif_y_render_loop
				; Main render loop.
				; Assume pixel is being drawn unless found otherwise.
				; Avoids a few mov instructions.
				mov al, 0x0F

				cmp bx, 0
				ja SHORT .endif_left_segment
					; Left segment.
					jmp SHORT .endif_blank_area
				.endif_left_segment:

				cmp cx, 0
				ja SHORT .endif_top_segment
					; Top segment.
					jmp SHORT .endif_blank_area
				.endif_top_segment:

				cmp bx, 319
				jb SHORT .endif_right_segment
					; Right segment.
					jmp SHORT .endif_blank_area
				.endif_right_segment:

				cmp cx, 199
				jb SHORT .endif_bottom_segment 
					; Bottom segment.
					jmp SHORT .endif_blank_area
				.endif_bottom_segment:

				; Left paddle.
				; Pixel x >= Paddle x
				cmp bx, PLAYER_PADDLE_OFFSET
				jb SHORT .endif_lpaddle_x
					; Pixel x <= Paddle x + Paddle width
					cmp bx, PLAYER_PADDLE_OFFSET + PLAYER_PADDLE_WIDTH
					ja SHORT .endif_lpaddle_x2
						; Pixel y >= paddle y
						cmp cl, dl
						jb SHORT .endif_lpaddle_y1
							; Pixel y <= paddle y + paddle height
							push dx
							add dl, PLAYER_PADDLE_HEIGHT
							cmp cl, dl
							pop dx
							ja SHORT .endif_lpaddle_y2
								jmp SHORT .endif_blank_area
							.endif_lpaddle_y2:
						.endif_lpaddle_y1:
					.endif_lpaddle_x2:
				.endif_lpaddle_x:

				; Right paddle.
				; Pixel x >= Paddle x
				cmp bx, 319 - PLAYER_PADDLE_OFFSET - PLAYER_PADDLE_WIDTH
				jb SHORT .endif_rpaddle_x
					; Pixel x <= Paddle x + Paddle width
					cmp bx, 319 - PLAYER_PADDLE_OFFSET
					ja SHORT .endif_rpaddle_x2
						; Pixel y >= paddle y
						cmp cl, dh
						jb SHORT .endif_rpaddle_y1
							; Pixel y <= paddle y + paddle height
							push dx
							add dh, PLAYER_PADDLE_HEIGHT
							cmp cl, dh
							pop dx
							ja SHORT .endif_rpaddle_y2
								jmp SHORT .endif_blank_area
							.endif_rpaddle_y2:
						.endif_rpaddle_y1:
					.endif_rpaddle_x2:
				.endif_rpaddle_x:

				

				; Ball rendering.
				; Pixel x >= ballx
				cmp bx, si
				jb SHORT .endif_ball_x1
					; Pixel x <= ballx + ball width
					push si
					add si, BALL_DIM
					cmp bx, si
					pop si
					ja SHORT .endif_ball_x2
						; Pixel y >= ball y
						cmp cx, di
						jb SHORT .endif_ball_y1
							; Pixel y <= ball y + ball height
							push di
							add di, BALL_DIM
							cmp cx, di
							pop di
							ja SHORT .endif_ball_y2
								jmp SHORT .endif_blank_area
							.endif_ball_y2:
						.endif_ball_y1:
					.endif_ball_x2:
				.endif_ball_x1:

				; ELSE
				; Otherwise draw blank pixel.
				xor al, al

				.endif_blank_area:

				; Draw calculated pixel to rendering area.
				push si 
				mov si, cx
				imul si, SCREEN_WIDTH
				add si, bx
				mov BYTE [es:si], al
				pop si

				dec cx
				jmp .y_render_loop 

			.endif_y_render_loop:

			dec bx
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
		xor cx, cx
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
	xor ax, ax
	mov ax, bp
	sub ax, BALL_DIM
	cmp di, ax
	jbe SHORT .endif_paddle_y1
		; Check if the ball is above the bottom edge of the paddle.
		xor ax, ax
		mov ax, bp
		add ax, PLAYER_PADDLE_HEIGHT
		cmp di, ax
		jae SHORT .endif_paddle_y2
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
	push cx

	; Cheap clear screen
	mov ax, 0x13
	int 0x10

	mov si, 10 
	mov di, 12
	call show_score_single

	mov si, 27
	mov di, 12
	mov cl, ch
	call show_score_single

	; Give screen 3 seconds.
	mov cx, 3000000 >> 16 
	mov dx, 0xFFFF
	mov ah, 0x86
	int 0x15

	pop cx

	jmp after_score_init
