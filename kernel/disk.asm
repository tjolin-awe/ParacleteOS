; ─────────────────────────────────────────
; disk.asm - Disk routines
; ─────────────────────────────────────────

; dir_read
; Reads 1 sector into dir_buffer from current_dir_sector
; Uses same registers/values as original inline code
dir_read:
    mov ax, 0x0201      ; AH = 02h (Read Sectors), AL = 01h (Number of sectors to read)
    mov bx, dir_buffer  ; ES:BX = Memory address where the disk data will be stored
    mov cx, [current_dir_sector] ; CH = Track/Cylinder, CL = Sector number (1-63)
    mov dx, 0x0000      ; DH = Head number, DL = Drive number (0 = Floppy A:)
    int 0x13            ; Call BIOS Disk Service
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