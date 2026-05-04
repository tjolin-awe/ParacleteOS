[BITS 16]
[ORG 0x7C00]

; ─────────────────────────────────────────
; FAT32 BPB — Must be at offset 0x03
; ─────────────────────────────────────────
jmp short start
nop

; ── OEM Name (8 bytes) ──────────────────
bpb_oem_name            db "BibleOS "

; ── DOS 3.31 BPB ────────────────────────
bpb_bytes_per_sector    dw 512
bpb_sectors_per_cluster db 1
bpb_reserved_sectors    dw 6
bpb_num_fats            db 2
bpb_root_entry_count    dw 0
bpb_total_sectors_16    dw 0
bpb_media_type          db 0xF8
bpb_fat_size_16         dw 0
bpb_sectors_per_track   dw 18
bpb_num_heads           dw 2
bpb_hidden_sectors      dd 0
bpb_total_sectors_32    dd 20480

; ── FAT32 Extended BPB ──────────────────
bpb_fat_size_32         dd 32
bpb_ext_flags           dw 0
bpb_fs_version          dw 0
bpb_root_cluster        dd 2
bpb_fs_info             dw 1
bpb_backup_boot         dw 6
bpb_reserved            times 12 db 0

; ── Extended Boot Record ────────────────
ebr_drive_number        db 0x80
ebr_reserved            db 0
ebr_signature           db 0x29
ebr_volume_id           dd 0xDEADBEEF
ebr_volume_label        db "BIBLEOS    "
ebr_fs_type             db "FAT32   "

; ─────────────────────────────────────────
; Boot Code Start
; ─────────────────────────────────────────
start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7BFF
    sti

    mov [ebr_drive_number], dl

    mov si, msg_booting
    call print_string

    ; Load kernel (8 sectors) from sector 2 into 0x8000
    mov ah, 0x02
    mov al, 8
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, [ebr_drive_number]
    mov bx, 0x8000
    int 0x13
    jc disk_error

    jmp 0x0000:0x8000

disk_error:
    mov si, msg_disk_err
    call print_string
    hlt

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

msg_booting     db "ParacleteOS Booting...", 0x0D, 0x0A, 0
msg_disk_err    db "Disk Error!", 0x0D, 0x0A, 0

times 510 - ($ - $$) db 0
dw 0xAA55