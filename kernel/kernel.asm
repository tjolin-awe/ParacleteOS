[BITS 16]
[ORG 0x8000]

jmp start

%include "kernel/disk.asm"
%include "kernel/shell.asm"

; Constants
DELAY_2S_CX  equ 0x001E     ; High word of 2 second delay
DELAY_2S_DX  equ 0x8480     ; Low word of 2 second delay

; ─────────────────────────────────────────
; Kernel Entry Point
; ─────────────────────────────────────────
start:
    cli                       ; disables interrupts so nothing can interfere
    mov [saved_drive], dl     ; writes the value in dl to the address of [saved_drive]. Booting drive set in boot loader
    xor ax, ax                ; 0 out the accumulator high & low bytes
    mov ds, ax                ; sets ds to 0 can only be done throught the accumulator
    mov es, ax                ; sets es to 0 ...
    mov ss, ax                ; sets ss to 0 ...
    mov sp, 0x7000            ; sets the stack pointer to 0x7000
    sti                       ; re-enables interrupts

    
    
    ; Set cx & dx parameters to create 
    ; a 2 second delay (2,000,000 microseconds)
    mov cx, DELAY_2S_CX
    mov dx, DELAY_2S_DX

    call delay                ; jumps to the delay routine. calls write the return address to the stack, so ret knows where to return to
    call cls                  ; jumps to clear screen routine

    mov cx, DELAY_2S_CX
    mov dx, DELAY_2S_DX
    call delay 
   
    ; Setup msg banner
    mov si, msg_banner        ; loads the si register with the starting address of the first byte of the banner data
    call print_string
    call print_bios_info
    mov si, msg_divider
    call print_string

    jmp shell_start

; ── Library Functions ──

; TODO: Break this into parts for seperation of concerns
;       Method to Read the data. Method to print it
print_bios_info:
    ; preserve register values
    push ax             
    push bx
    push cx
    push dx

    mov si, msg_base_mem            ; load si with the location of the start byte
    call print_string               ; print the string
    int 0x12                        ; interrupt 0x12 loads ax with amount of conventional memory
    call print_dec
    mov si, msg_kb
    call print_string
    mov si, msg_ext_mem
    call print_string
    mov ah, 0x88
    int 0x15
    call print_dec
    mov si, msg_kb
    call print_string
    int 0x11
    push ax
    mov si, msg_floppies
    call print_string
    pop ax
    push ax
    test al, 0x01
    jz .no_floppy
    push ax
    shr ax, 6
    and ax, 0x03
    inc ax
    call print_dec
    pop ax
    jmp .floppy_done
.no_floppy:
    mov si, msg_none
    call print_string
.floppy_done:
    mov si, msg_newline
    call print_string
    pop ax
    push ax
    mov si, msg_video
    call print_string
    push ax
    shr ax, 4
    and ax, 0x03
    cmp ax, 0
    je .vid_vga
    cmp ax, 1
    je .vid_cga40
    cmp ax, 2
    je .vid_cga80
    cmp ax, 3
    je .vid_mono
.vid_vga:
    mov si, msg_vid_vga
    call print_string
    jmp .vid_done
.vid_cga40:
    mov si, msg_vid_cga40
    call print_string
    jmp .vid_done
.vid_cga80:
    mov si, msg_vid_cga80
    call print_string
    jmp .vid_done
.vid_mono:
    mov si, msg_vid_mono
    call print_string
.vid_done:
    pop ax
    pop ax
    mov si, msg_boot_drive
    call print_string
    mov al, [saved_drive]
    cmp al, 0x00
    je .floppy_boot
    cmp al, 0x80
    je .hdd_boot
    mov si, msg_unknown_drive
    call print_string
    jmp .drive_done
.floppy_boot:
    mov si, msg_floppy_drive
    call print_string
    jmp .drive_done
.hdd_boot:
    mov si, msg_hdd_drive
    call print_string
.drive_done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

print_dec:
    ; preserve registers
    push ax
    push bx
    push cx
    push dx
    mov bx, 10
    mov cx, 0
.pd_divide:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .pd_divide
.pd_print:
    pop dx
    mov al, dl
    add al, '0'
    mov ah, 0x0E
    int 0x10
    loop .pd_print
    pop dx
    pop cx
    pop bx
    pop ax
    ret

read_line:
    mov di, input_buffer
    mov cx, 128
    xor al, al
    rep stosb
    mov cx, 0
    mov si, 0
.loop:
    mov ah, 0x00
    int 0x16
    cmp al, 0
    jne .normal_key
    cmp ah, 0x4B
    je .left
    cmp ah, 0x4D
    je .right
    jmp .loop
.normal_key:
    cmp al, 0x0D
    je .done
    cmp al, 0x08
    je .backspace
    cmp cx, 126
    jge .loop
    push bx
    mov bx, cx
.shift_right:
    cmp bx, si
    jle .shift_done
    mov dl, [input_buffer + bx - 1]
    mov [input_buffer + bx], dl
    dec bx
    jmp .shift_right
.shift_done:
    mov [input_buffer + si], al
    pop bx
    inc si
    inc cx
    call redraw_line
    jmp .loop
.left:
    cmp si, 0
    je .loop
    dec si
    mov ah, 0x0E
    mov al, 0x08
    int 0x10
    jmp .loop
.right:
    cmp si, cx
    jge .loop
    push bx
    mov bx, si
    mov al, [input_buffer + bx]
    mov ah, 0x0E
    int 0x10
    pop bx
    inc si
    jmp .loop
.backspace:
    cmp si, 0
    je .loop
    push bx
    mov bx, si
    dec bx
.shift_left:
    mov dl, [input_buffer + bx + 1]
    mov [input_buffer + bx], dl
    inc bx
    cmp bx, cx
    jl .shift_left
    mov byte [input_buffer + bx], 0
    pop bx
    dec si
    dec cx
    call redraw_line
    jmp .loop
.done:
    push bx
    mov bx, cx
    mov byte [input_buffer + bx], 0
    pop bx
    mov si, msg_newline
    call print_string
    ret

redraw_line:
    push ax
    push bx
    push cx
    push dx
    push si
    mov ah, 0x0E
    mov al, 0x0D
    int 0x10
    mov si, msg_prompt
    call print_string
    mov bx, 0
.print_loop:
    cmp bx, cx
    jge .print_done
    mov al, [input_buffer + bx]
    mov ah, 0x0E
    int 0x10
    inc bx
    jmp .print_loop
.print_done:
    mov ah, 0x0E
    mov al, ' '
    int 0x10
    mov al, ' '
    int 0x10
    mov ah, 0x03
    mov bh, 0x00
    int 0x10
    pop si
    push si
    mov dl, 5
    push ax
    mov ax, si
    add dl, al
    pop ax
    mov ah, 0x02
    mov bh, 0x00
    int 0x10
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Prints a string to the screen one character at a time
; Routine expects the location of the the starting byte of a null terminated string 
; is loaded into the si register. e.g: mov si, {label}
print_string:
    push ax
    push bx
    push si
    mov ah, 0x0E            ; sets teletype mode
    mov bh, 0x00            ; sets screen page to visible screen display
.ps_loop:
    lodsb                   ; loads the next byte onto the low byte of ax register and increments the si register moving to the next char
    test al, al             ; similiar to cmp but faster. Checks if al = 0, a.k.a checks for the the null terminated string char 
    jz .ps_done             ; Jz checks the ZF (zero byte flag) to see if the test was 0. If so it knows it reached the end of the string and calls done
    int 0x10                ; calls interrupt to print character
    jmp .ps_loop            ; loops to next character because we haven't reached the null terminated char of the string
.ps_done:
    pop ax
    pop bx
    pop si
    ret

putc:
    mov ah, 0x0E
    mov bh, 0x00
    int 0x10
    ret


; Adjusts the video mode 
; Assumes that al low byte has already been set
set_video_mode:
    mov ah, 0x00        ; change video mode
    int 0x10            ; call interrupt
    ret 


; Clear the screen by setting the ax register to 0x0003 word 
; High Byte: 00 - means change video mode
; Low  Byte: 03 - 80x25 color text mode which clears the screen 
; Clobbers: ax
cls:
    mov al, 0x03           ; set the word (high & low byte function code) into the accumulator
    call set_video_mode
    ret

; Delays execution for 2 seconds using BIOS INT 15h, AH=86h (Wait function)
; Set the xc & dx 16-bit words to set the seconds 

delay:
    push ax                 ; saves ax contents
    mov ah, 0x86            ; BIOS wait function (134)
    int 0x15                ; interrupt 15 to jump to BIOS function specified in ah (high byte of accumulator)
    pop ax                  ; restores ax
    ret                     ; returns to the calling line

; ── Kernel Data ──
section .data

    ; --- Runtime variables ---
    saved_drive:        db 0
    current_dir_sector: dw 6
    cd_name_ptr:        dw 0

    ; --- OS Init Strings ---
    msg_banner:         db "==============================", 0x0D, 0x0A
                        db "   ParacleteOS v0.1  Shell    ", 0x0D, 0x0A
                        db "   Type HELP for commands     ", 0x0D, 0x0A
                        db "==============================", 0x0D, 0x0A
                        db 0x0D, 0x0A, 0

    msg_divider:        db "------------------------------", 0x0D, 0x0A
                        db 0x0D, 0x0A, 0

    ; --- Error Messages ---
    msg_newline:        db 0x0D, 0x0A, 0
    msg_disk_error:     db "Disk error!", 0x0D, 0x0A, 0


    ; --- System Info Labels ---
    msg_base_mem:       db "Base Memory   : ", 0
    msg_ext_mem:        db "Ext Memory    : ", 0
    msg_kb:             db " KB", 0x0D, 0x0A, 0
    msg_floppies:       db "Floppy Drives : ", 0
    msg_video:          db "Video Mode    : ", 0
    msg_boot_drive:     db "Boot Drive    : ", 0
    msg_none:           db "None", 0

    ; --- Video Mode Strings ---
    msg_vid_vga:        db "VGA/EGA", 0x0D, 0x0A, 0
    msg_vid_cga40:      db "CGA 40col", 0x0D, 0x0A, 0
    msg_vid_cga80:      db "CGA 80col", 0x0D, 0x0A, 0
    msg_vid_mono:       db "Monochrome", 0x0D, 0x0A, 0

    ; --- Drive Strings ---
    msg_floppy_drive:   db "Floppy (A:)", 0x0D, 0x0A, 0
    msg_hdd_drive:      db "Hard Disk (C:)", 0x0D, 0x0A, 0
    msg_unknown_drive:  db "Unknown", 0x0D, 0x0A, 0

; ── Shared Buffers ──
input_buffer:       times 128 db 0
dir_buffer:         times 512 db 0

times 4096 - ($ - $$) db 0