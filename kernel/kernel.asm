[BITS 16]
[ORG 0x8000]

jmp start

%include "kernel/disk.asm"
%include "kernel/shell.asm"

; ─────────────────────────────────────────
; Kernel Entry Point
; ─────────────────────────────────────────
start:
    cli
    mov [saved_drive], dl
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7000
    sti

    call delay
    call cls

    mov si, msg_banner
    call print_string
    call print_bios_info
    mov si, msg_divider
    call print_string

    jmp shell_start

; ── Library Functions ──
print_bios_info:
    push ax
    push bx
    push cx
    push dx
    mov si, msg_base_mem
    call print_string
    int 0x12
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

print_string:
    mov ah, 0x0E
    mov bh, 0x00
.ps_loop:
    lodsb
    test al, al
    jz .ps_done
    int 0x10
    jmp .ps_loop
.ps_done:
    ret

putc:
    mov ah, 0x0E
    mov bh, 0x00
    int 0x10
    ret

cls:
    mov ah, 0x00
    mov al, 0x03
    int 0x10
    ret

delay:
    mov ah, 0x86
    mov cx, 0x001E
    mov dx, 0x8480
    int 0x15
    ret

; ── Kernel Data ──
saved_drive         db 0
current_dir_sector  dw 6
cd_name_ptr         dw 0

msg_banner          db "==============================", 0x0D, 0x0A
                    db "   ParacleteOS v0.1  Shell    ", 0x0D, 0x0A
                    db "   Type HELP for commands     ", 0x0D, 0x0A
                    db "==============================", 0x0D, 0x0A
                    db 0x0D, 0x0A, 0

msg_divider         db "------------------------------", 0x0D, 0x0A
                    db 0x0D, 0x0A, 0

msg_newline         db 0x0D, 0x0A, 0
msg_disk_error      db "Disk error!", 0x0D, 0x0A, 0
msg_base_mem        db "Base Memory   : ", 0
msg_ext_mem         db "Ext Memory    : ", 0
msg_kb              db " KB", 0x0D, 0x0A, 0
msg_floppies        db "Floppy Drives : ", 0
msg_video           db "Video Mode    : ", 0
msg_boot_drive      db "Boot Drive    : ", 0
msg_none            db "None", 0
msg_vid_vga         db "VGA/EGA", 0x0D, 0x0A, 0
msg_vid_cga40       db "CGA 40col", 0x0D, 0x0A, 0
msg_vid_cga80       db "CGA 80col", 0x0D, 0x0A, 0
msg_vid_mono        db "Monochrome", 0x0D, 0x0A, 0
msg_floppy_drive    db "Floppy (A:)", 0x0D, 0x0A, 0
msg_hdd_drive       db "Hard Disk (C:)", 0x0D, 0x0A, 0
msg_unknown_drive   db "Unknown", 0x0D, 0x0A, 0

; ── Shared Buffers ──
input_buffer        times 128 db 0
dir_buffer          times 512 db 0

times 4096 - ($ - $$) db 0