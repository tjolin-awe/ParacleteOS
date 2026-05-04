; ─────────────────────────────────────────
; disk.asm - Disk routines
; ─────────────────────────────────────────

; dir_read
; Reads 1 sector into dir_buffer from current_dir_sector
; Uses same registers/values as original inline code
dir_read:
    mov ax, 0x0201
    mov bx, dir_buffer
    mov cx, [current_dir_sector]
    mov dx, 0x0000
    int 0x13
    ret

; dir_write
; Writes dir_buffer back to current_dir_sector
dir_write:
    mov ax, 0x0301
    mov bx, dir_buffer
    mov cx, [current_dir_sector]
    mov dx, 0x0000
    int 0x13
    ret