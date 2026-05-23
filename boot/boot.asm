; ═══════════════════════════════════════════════════════════════════
; ParacleteOS Bootloader
; Target : x86 Real Mode (16-bit)
; Format : FAT32 / DOS 7.1 BPB Layout
;
; Timeline of BPB evolution:
;   DOS 2.0  (1983) — Original BPB, floppy disk support
;   DOS 3.0  (1984) — Added disk geometry fields
;   DOS 3.31 (1987) — Expanded to support disks larger than 32MB
;   DOS 4.0  (1988) — Added Extended Boot Record (EBR)
;   DOS 7.1  (1996) — Added FAT32 Extended BPB (Windows 95 OSR2)
;
; Memory Layout
;
;   Address	    Content	           
;   -------     -------
;   0x7DFF	    End of Bootloader	
;   0x7C5A	    start: routine
;   0x7C03	    Your BPB Data	
;   0x7C00	    Start of Bootloader	
;   0x7BFF  	Stack Start (SP)	<-- STACK GROWS DOWN NOT UP!!! 
;   0x7BFE	    First byte of a PUSH	
;   0x0500	    Bottom of safe RAM
;
;
; ═══════════════════════════════════════════════════════════════════

[BITS 16]       ; Generate 16-bit machine code.
                ; Every x86 CPU boots in Real Mode (16-bit).
                ; This is true even on modern 64-bit processors.

[ORG 0x7C00]    ; All labels and addresses are relative to 0x7C00.
                ; The BIOS always loads the boot sector here.
                ; This has been true since the IBM PC in 1981.

; ═══════════════════════════════════════════════════════════════════
; SECTION 1 — Jump Header
; Introduced : DOS 2.0 (1983)
; Offset     : 0x00
; Size       : 3 bytes
;
; The very first thing in every FAT boot sector since DOS 2.0.
; A 3-byte jump that skips over the BPB data to the boot code.
; FAT32 requires this to be exactly 3 bytes — no more, no less.
; ═══════════════════════════════════════════════════════════════════

jmp short start ; 2-byte short jump to "start:" label below.
                ; Skips all BPB data so the CPU does not try
                ; to execute the BPB fields as instructions.

nop             ; 1-byte No Operation. Pads the jump to exactly
                ; 3 bytes so the OEM name lands at offset 0x03.
                ; Required by the FAT32 specification.

; ═══════════════════════════════════════════════════════════════════
; SECTION 2 — OEM Name
; Introduced : DOS 2.0 (1983)
; Offset     : 0x03
; Size       : 8 bytes
;
; Identifies the software that formatted this volume.
; Must be exactly 8 ASCII bytes, space-padded if shorter.
; The BIOS and OS do not enforce the value but some BIOSes
; behave better when this reads "MSDOS5.0".
; ═══════════════════════════════════════════════════════════════════

bpb_oem_name            db "PCleteOS"
                        ; MUST be exactly 8 bytes.
                        ; This is your OS identity stamp.

; ═══════════════════════════════════════════════════════════════════
; SECTION 3 — Core BPB Fields
; Introduced : DOS 2.0 (1983)
; Offset     : 0x0B
; Size       : 13 bytes
;
; The original BIOS Parameter Block from 1983.
; Describes the physical geometry of the disk.
; Present and required in FAT12, FAT16, and FAT32.
; These fields have not changed since DOS 2.0.
; ═══════════════════════════════════════════════════════════════════

bpb_bytes_per_sector    dw 512
                        ; [DOS 2.0 — offset 0x0B — 2 bytes]
                        ; Number of bytes in one disk sector.
                        ; 512 is the universal standard for
                        ; floppies and most hard drives / USB drives.
                        ; Modern NVMe drives use 4096 but 512 is
                        ; required for maximum BIOS compatibility.

bpb_sectors_per_cluster db 1
                        ; [DOS 2.0 — offset 0x0D — 1 byte]
                        ; Number of sectors grouped into one cluster.
                        ; A cluster is the smallest unit of file
                        ; allocation. 1 = 512 bytes per cluster.
                        ; Larger values reduce FAT size but waste
                        ; space on small files.

bpb_reserved_sectors    dw 6
                        ; [DOS 2.0 — offset 0x0E — 2 bytes]
                        ; Number of sectors reserved at the start
                        ; of the disk before the FAT tables begin.
                        ; Sector 0 = this bootloader.
                        ; Sectors 1-5 = available for extra boot
                        ; stages or a second-stage loader.
                        ; Must be at least 1. We use 6 to match
                        ; the backup boot sector location below.

bpb_num_fats            db 2
                        ; [DOS 2.0 — offset 0x10 — 1 byte]
                        ; Number of File Allocation Tables on disk.
                        ; Always 2 for FAT32 — one primary, one
                        ; backup. If the primary FAT is corrupted
                        ; the OS uses the backup to recover.

bpb_root_entry_count    dw 0
                        ; [DOS 2.0 — offset 0x11 — 2 bytes]
                        ; Number of 32-byte entries in the root
                        ; directory for FAT12/FAT16.
                        ; MUST be 0 for FAT32 because FAT32 stores
                        ; the root directory as a normal cluster
                        ; chain pointed to by bpb_root_cluster.

bpb_total_sectors_16    dw 0
                        ; [DOS 2.0 — offset 0x13 — 2 bytes]
                        ; Total sector count as a 16-bit number.
                        ; Maximum value = 65535 sectors (~32MB).
                        ; MUST be 0 for FAT32. Use the 32-bit
                        ; bpb_total_sectors_32 field instead.

bpb_media_type          db 0xF8
                        ; [DOS 2.0 — offset 0x15 — 1 byte]
                        ; Legacy byte describing the physical media.
                        ; 0xF8 = Fixed (non-removable) hard disk.
                        ; 0xF0 = 3.5 inch high-density floppy.
                        ; 0xF9 = 3.5 inch double-density floppy.
                        ; Modern OSes ignore this field entirely
                        ; but it must be present and non-zero.

bpb_fat_size_16         dw 0
                        ; [DOS 2.0 — offset 0x16 — 2 bytes]
                        ; Size of each FAT in sectors as 16-bit.
                        ; MUST be 0 for FAT32. Use the 32-bit
                        ; bpb_fat_size_32 field in Section 6.

; ═══════════════════════════════════════════════════════════════════
; SECTION 4 — Disk Geometry Fields
; Introduced : DOS 3.0 (1984)
; Offset     : 0x18
; Size       : 4 bytes
;
; Added in DOS 3.0 to support hard disks alongside floppies.
; Describes the physical CHS (Cylinder-Head-Sector) geometry.
; Used by BIOS INT 13h disk read/write functions.
; Still required in FAT32 even though LBA addressing is preferred.
; ═══════════════════════════════════════════════════════════════════

bpb_sectors_per_track   dw 18
                        ; [DOS 3.0 — offset 0x18 — 2 bytes]
                        ; Number of sectors per track (CHS geometry).
                        ; 18 = standard 3.5 inch HD floppy geometry.
                        ; For a USB drive or hard disk this value
                        ; is largely ignored by modern BIOSes but
                        ; must be present and non-zero.

bpb_num_heads           dw 2
                        ; [DOS 3.0 — offset 0x1A — 2 bytes]
                        ; Number of read/write heads (CHS geometry).
                        ; 2 = standard double-sided floppy disk.
                        ; Like sectors_per_track, modern BIOSes
                        ; largely ignore this for hard disks.

; ═══════════════════════════════════════════════════════════════════
; SECTION 5 — Large Disk Support Fields
; Introduced : DOS 3.31 (1987)
; Offset     : 0x1C
; Size       : 6 bytes
;
; DOS 3.31 was the first version to support disks larger than 32MB.
; It expanded hidden_sectors from 16-bit to 32-bit and added
; total_sectors_32 to handle sector counts beyond 65535.
; These two changes are what define the "DOS 3.31 BPB" label
; you will see throughout OS development documentation.
; ═══════════════════════════════════════════════════════════════════

bpb_hidden_sectors      dd 0
                        ; [DOS 3.31 — offset 0x1C — 4 bytes]
                        ; Number of sectors before this partition.
                        ; Expanded from 16-bit (DOS 3.0) to 32-bit
                        ; (DOS 3.31) to support larger disks.
                        ; 0 = this partition starts at the very
                        ; beginning of the disk with no MBR in front.

bpb_total_sectors_32    dd 20480
                        ; [DOS 3.31 — offset 0x20 — 4 bytes]
                        ; Total sector count as a 32-bit number.
                        ; NEW in DOS 3.31 — did not exist before.
                        ; 20480 sectors x 512 bytes = 10MB disk image.
                        ; Used when bpb_total_sectors_16 is 0,
                        ; which it always is for FAT32.

; ═══════════════════════════════════════════════════════════════════
; SECTION 6 — FAT32 Extended BPB
; Introduced : DOS 7.1 / Windows 95 OSR2 (1996)
; Offset     : 0x24
; Size       : 28 bytes
;
; THIS is the section that makes a volume FAT32.
; It did not exist before 1996. If this section is absent
; the volume is FAT12 or FAT16, not FAT32.
; Microsoft defined this in the DOS 7.1 / Windows 95 OSR2
; release to support disks larger than 2GB (FAT16 limit).
; ═══════════════════════════════════════════════════════════════════

bpb_fat_size_32         dd 32 ; double word 32bit
                        ; [DOS 7.1 — offset 0x24 — 4 bytes]
                        ; Size of EACH FAT table in sectors (32-bit).
                        ; Replaces bpb_fat_size_16 which is 0 above.
                        ; 32 sectors x 512 bytes = 16384 bytes per FAT.
                        ; With 2 FATs = 64 sectors total for FAT tables.

bpb_ext_flags           dw 0  ; word 16 bit
                        ; [DOS 7.1 — offset 0x28 — 2 bytes]
                        ; Controls FAT mirroring behavior.
                        ; 0x0000 = all FATs kept in sync (mirrored).
                        ; Bit 7 set = only one active FAT, bits 0-3
                        ; identify which FAT is active.
                        ; 0 is the safe default — always mirror.

bpb_fs_version          dw 0
                        ; [DOS 7.1 — offset 0x2A — 2 bytes]
                        ; FAT32 filesystem version number.
                        ; High byte = major version.
                        ; Low byte  = minor version.
                        ; 0x0000 = version 0.0.
                        ; Microsoft never released a version 1.0.
                        ; Must be 0x0000 or another OS may refuse
                        ; to mount the volume.

bpb_root_cluster        dd 2
                        ; [DOS 7.1 — offset 0x2C — 4 bytes]
                        ; Cluster number where the root directory
                        ; chain begins. Almost always 2.
                        ; Clusters 0 and 1 are reserved by the spec.
                        ; This is a fundamental FAT32 difference from
                        ; FAT16 — the root directory is a normal
                        ; cluster chain, not a fixed reserved area.

bpb_fs_info             dw 1
                        ; [DOS 7.1 — offset 0x30 — 2 bytes]
                        ; Sector number of the FSInfo structure.
                        ; FSInfo stores two performance hints:
                        ;   1. Number of free clusters on the volume.
                        ;   2. The next likely free cluster number.
                        ; The OS uses these to avoid scanning the
                        ; entire FAT when allocating new files.
                        ; Sector 1 is the standard location.

bpb_backup_boot         dw 6
                        ; [DOS 7.1 — offset 0x32 — 2 bytes]
                        ; Sector number of the backup boot sector.
                        ; If sector 0 is corrupted or unreadable,
                        ; the BIOS can load the backup from here.
                        ; Must match bpb_reserved_sectors (6) above
                        ; so the backup lives within reserved space.

bpb_reserved            times 12 db 0
                        ; [DOS 7.1 — offset 0x34 — 12 bytes]
                        ; Reserved for future Microsoft use.
                        ; Must be all zeros per the FAT32 spec.
                        ; Has never been used in any released OS.

; ═══════════════════════════════════════════════════════════════════
; SECTION 7 — Extended Boot Record (EBR)
; Introduced : DOS 4.0 (1988)
; Offset     : 0x40
; Size       : 26 bytes
;
; Originally defined in DOS 4.0 for FAT12 and FAT16 volumes.
; Carried forward unchanged into FAT32 / DOS 7.1.
; Contains the drive number, volume serial number, label,
; and filesystem type string.
; ═══════════════════════════════════════════════════════════════════

ebr_drive_number        db 0x80
                        ; [DOS 4.0 — offset 0x40 — 1 byte]
                        ; BIOS drive number for this disk.
                        ; 0x80 = first hard disk or USB drive.
                        ; 0x00 = first floppy drive.
                        ; 0x81 = second hard disk.
                        ; The BIOS passes the actual boot drive
                        ; number in DL when it jumps to us.
                        ; We overwrite this at runtime in start:.

ebr_reserved            db 0
                        ; [DOS 4.0 — offset 0x41 — 1 byte]
                        ; Reserved. Must be 0.
                        ; Windows NT used this as a dirty volume
                        ; flag but the FAT32 spec requires zero.

ebr_signature           db 0x29
                        ; [DOS 4.0 — offset 0x42 — 1 byte]
                        ; Magic number signalling that the next
                        ; three fields are valid and present.
                        ; 0x29 is the only valid value.
                        ; Without this some OSes will ignore the
                        ; volume ID, label, and filesystem type.

ebr_volume_id           dd 0xAFAFAFAFAF
                        ; [DOS 4.0 — offset 0x43 — 4 bytes]
                        ; 32-bit pseudo-random volume serial number.
                        ; Generated at format time.
                        ; Windows uses this to track which drive
                        ; letter belongs to which volume.
                        ; value when you format your disk image.

ebr_volume_label        db "PCLETEOS   "
                        ; [DOS 4.0 — offset 0x47 — 11 bytes]
                        ; Human-readable volume name.
                        ; Shown in Windows Explorer and Linux
                        ; file managers as the disk label.
                        ; Must be EXACTLY 11 bytes, space-padded.

ebr_fs_type             db "FAT32   "
                        ; [DOS 4.0 — offset 0x52 — 8 bytes]
                        ; Informational filesystem type string.
                        ; Must be EXACTLY 8 bytes, space-padded.
                        ; NOTE: The OS specification says this
                        ; field must NOT be used to detect the
                        ; filesystem type. Use the BPB fields
                        ; instead. Some bootloaders check it anyway.

; ═══════════════════════════════════════════════════════════════════
; SECTION 8 — Boot Code
; Offset : 0x5A
; Space  : 510 - 90 = 420 bytes available for boot code
;
; Everything above was data. The CPU jumps here from the
; "jmp short start" at the very top of the file.
; ═══════════════════════════════════════════════════════════════════

start:
    cli                         ; Disable hardware interrupts.
                                ; We are about to configure the stack.
                                ; An interrupt firing mid-setup would
                                ; push data to a garbage address and
                                ; corrupt memory. Disable until safe.

    xor ax, ax                  ; Set AX = 0.
                                ; XOR of any value with itself = 0.
                                ; Faster and smaller than "mov ax, 0".
                                ; We need zero to initialise segments.

    mov ds, ax                  ; Data Segment = 0.
                                ; Real Mode address = (Segment x 16)
                                ; + Offset. DS=0 means our data
                                ; addresses are used as-is.

    mov es, ax                  ; Extra Segment = 0.
                                ; Used by string instructions like
                                ; LODSB. Keep it in the same flat
                                ; segment as DS and CS.

    mov ss, ax                  ; Stack Segment = 0.
                                ; The stack lives at SS:SP.
                                ; SS=0 puts the stack in the same
                                ; segment as our code and data.

    mov sp, 0x7BFF              ; Stack Pointer = 0x7BFF.
                                ; The stack grows DOWNWARD in x86.
                                ; PUSH decreases SP by 2.
                                ; POP increases SP by 2.
                                ; 0x7BFF is just below our bootloader
                                ; at 0x7C00 so the stack grows away
                                ; from our code into lower memory.

    sti                         ; Re-enable hardware interrupts.
                                ; Stack is now safely configured.
                                ; The CPU can respond to keyboard,
                                ; timer, and disk events again.

    mov [ebr_drive_number], dl  ; Save the BIOS boot drive number.
                                ; The BIOS puts the drive number in
                                ; DL before jumping to our bootloader.
                                ; We store it in our EBR variable so
                                ; we can use it for disk reads below.
                                ; Square brackets = write to memory
                                ; at that address (like *ptr in C).

    mov si, msg_booting         ; Point SI at the booting message.
                                ; SI = Source Index register.
                                ; print_string reads bytes from SI.

    call print_string           ; Print "ParacleteOS Booting..."
                                ; CALL pushes return address to stack
                                ; and jumps to print_string.
                                ; RET inside print_string jumps back.

    ; ── Load Kernel from Disk ───────────────────────────────────
    ; Use BIOS INT 13h to read 8 sectors from disk into RAM.
    ; INT 13h uses CHS (Cylinder-Head-Sector) addressing.
    ; This is the original IBM PC disk interface from 1981.

    mov ah, 0x02                ; INT 13h function 0x02 = Read Sectors.
                                ; AH = function number.
                                ; Other functions: 0x00=reset, 0x03=write.

    mov al, 8                   ; Read 8 sectors.
                                ; 8 x 512 = 4096 bytes = 4KB of kernel.
                                ; Increase this if your kernel is larger.

    mov ch, 0                   ; Cylinder number = 0.
                                ; The first (and only) cylinder.
                                ; On a floppy this is the first track.

    mov cl, 2                   ; Starting sector number = 2.
                                ; Sectors are numbered from 1 not 0.
                                ; Sector 1 = this bootloader.
                                ; Sector 2 = start of our kernel.

    mov dh, 0                   ; Head number = 0.
                                ; Head 0 = first read/write head.

    mov dl, [ebr_drive_number]  ; Drive number from our saved EBR value.
                                ; 0x80 = first hard disk / USB drive.

    mov bx, 0x8000              ; Destination offset in memory.
                                ; ES:BX = 0x0000:0x8000 = address 0x8000.
                                ; The kernel will be loaded here.
                                ; Safely above our bootloader at 0x7C00.

    int 0x13                    ; Call BIOS disk service.
                                ; Reads AL sectors from CHS location
                                ; into memory at ES:BX.
                                ; On return:
                                ;   CF = 0 → success
                                ;   CF = 1 → error (AH = error code)

    jc disk_error               ; Jump if Carry Flag is set = disk error.
                                ; JC is a conditional jump.
                                ; Only jumps if CF = 1.
                                ; If CF = 0 (success) falls through.

    jmp 0x0000:0x8000           ; Far jump to the loaded kernel.
                                ; Sets CS = 0x0000, IP = 0x8000.
                                ; Physical address = 0x8000.
                                ; CPU now executes your kernel code.
                                ; We never return from this jump.

; ── Disk Error Handler ──────────────────────────────────────────
disk_error:
    mov si, msg_disk_err        ; Point SI at the error message.

    call print_string           ; Print "Disk Error!" to screen.

    hlt                         ; Halt the CPU.
                                ; Stops execution completely.
                                ; Machine is effectively frozen.
                                ; A hardware interrupt could wake it
                                ; but there is nothing left to do.

; ═══════════════════════════════════════════════════════════════════
; FUNCTION : print_string
; Purpose  : Print a null-terminated ASCII string to the screen
; Input    : SI = pointer to string in memory
; Destroys : AX, BX
; Returns  : Nothing
;
; Uses BIOS INT 10h Teletype function (AH=0x0E).
; This has been available in every PC BIOS since 1981.
; ═══════════════════════════════════════════════════════════════════

print_string:
    mov ah, 0x0E                ; INT 10h function 0x0E = Teletype Output.
                                ; Prints character in AL to screen at
                                ; current cursor position and advances
                                ; the cursor. Like putchar() in C.
                                ; Available since IBM PC BIOS (1981).

    mov bh, 0x00                ; Video page number = 0.
                                ; The BIOS supports multiple video pages.
                                ; Page 0 is the default visible screen.

.ps_loop:
    lodsb                       ; Load byte at DS:SI into AL.
                                ; Automatically increments SI by 1.
                                ; Equivalent to: mov al,[si] / inc si
                                ; but in a single 1-byte instruction.
                                ; Each call reads the next character.

    test al, al                 ; Bitwise AND of AL with AL.
                                ; Does not store result, only sets flags.
                                ; If AL = 0 (null terminator) then
                                ; Zero Flag (ZF) is set to 1.

    jz .ps_done                 ; Jump if Zero Flag = 1.
                                ; AL was 0 = end of string reached.
                                ; Exit the loop and return.

    int 0x10                    ; Call BIOS video service.
                                ; AH=0x0E, AL=character, BH=page 0.
                                ; Prints the character and moves cursor.

    jmp .ps_loop                ; Unconditional jump back to loop start.
                                ; Process the next character.

.ps_done:
    ret                         ; Return to caller.
                                ; Pops return address from stack
                                ; (placed there by CALL) and jumps back.

; ── String Data ─────────────────────────────────────────────────

msg_booting     db "ParacleteOS Booting...", 0x0D, 0x0A, 0
                ; ASCII string + CR (0x0D) + LF (0x0A) + null (0x00).
                ; CR = move cursor to start of line.
                ; LF = move cursor down one line.
                ; CR+LF together = "\r\n" in C = new line.
                ; Null terminator (0) signals end to print_string.

msg_disk_err    db "Disk Error!", 0x0D, 0x0A, 0
                ; Same structure as msg_booting.
                ; Printed when INT 13h sets the Carry Flag.

; ═══════════════════════════════════════════════════════════════════
; SECTION 9 — Boot Sector Padding and Signature
; Introduced : IBM PC BIOS (1981)
; Offset     : 0x1FE (510)
; Size       : 2 bytes
;
; The BIOS reads exactly 512 bytes from sector 0.
; It checks the last 2 bytes for the magic value 0xAA55.
; If found → valid boot sector → jump to 0x7C00.
; If not found → not bootable → try next device.
; This check has existed in every PC BIOS since 1981.
; ═══════════════════════════════════════════════════════════════════

times 510 - ($ - $$) db 0
                ; Pad with zero bytes from current position to
                ; byte 510. Ensures the signature lands at the
                ; correct offset at the end of the sector.
                ; $ = current address.
                ; $$ = start of section (0x7C00).
                ; ($ - $$) = bytes used so far.
                ; 510 - ($ - $$) = bytes remaining to fill.

dw 0xAA55       ; Boot signature — 2 bytes at offset 0x1FE.
                ; The BIOS checks bytes 511 and 512 of the sector.
                ; x86 is Little Endian so 0xAA55 is stored as:
                ;   byte 511 = 0x55
                ;   byte 512 = 0xAA
                ; Together they form the magic value 0xAA55.
                ; Without this the BIOS will not boot this sector.
                ; Has been required since the IBM PC in 1981.