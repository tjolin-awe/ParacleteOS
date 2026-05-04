; ─────────────────────────────────────────
; shell.asm - Command Line Interface
; ─────────────────────────────────────────

shell_start:
    mov si, msg_prompt
    call print_string
    call read_line
    call process_command
    jmp shell_start

process_command:
    cmp byte [input_buffer], 0
    je .done

    mov si, input_buffer
    mov di, cmd_help
    call str_compare
    je .do_help

    mov si, input_buffer
    mov di, cmd_cls
    call str_compare
    je .do_cls

    mov si, input_buffer
    mov di, cmd_ver
    call str_compare
    je .do_ver

    mov si, input_buffer
    mov di, cmd_dir
    call str_compare
    je .do_dir

    mov si, input_buffer
    mov di, cmd_cd
    call str_compare_prefix
    je .do_cd

    mov si, input_buffer
    mov di, cmd_print
    call str_compare_prefix
    je .do_print

    mov si, input_buffer
    mov di, cmd_mkdir
    call str_compare_prefix
    je .do_mkdir

    mov si, input_buffer
    mov di, cmd_reboot
    call str_compare
    je .do_reboot

    mov si, msg_unknown
    call print_string
    jmp .done

.do_help:
    mov si, msg_help
    call print_string
    jmp .done

.do_cls:
    call cls
    jmp .done

.do_ver:
    mov si, msg_ver
    call print_string
    jmp .done

.do_reboot:
    jmp 0xFFFF:0x0000

.do_dir:
    mov si, msg_dir_header
    call print_string
    call dir_read
    jc .dir_error
    mov bx, 0
.dir_loop:
    cmp bx, 512
    jge .done
    mov al, [dir_buffer + bx]
    test al, al
    jz .done
    cmp al, 0xE5
    je .dir_skip
    push bx
    lea si, [dir_buffer + bx]
    mov cx, 8
.n_loop:
    mov al, [si]
    call putc
    inc si
    loop .n_loop
    mov al, '.'
    call putc
    mov cx, 3
.e_loop:
    mov al, [si]
    call putc
    inc si
    loop .e_loop
    pop bx
    mov al, [dir_buffer + bx + 11]
    test al, 0x10
    jz .is_file
    mov si, msg_dir_tag
    call print_string
    jmp .dir_skip
.is_file:
    mov si, msg_newline
    call print_string
.dir_skip:
    add bx, 32
    jmp .dir_loop
.dir_error:
    mov si, msg_disk_error
    call print_string
    jmp .done

.do_cd:
    mov si, input_buffer
    add si, 3
    cmp byte [si], '.'
    jne .cd_search
    cmp byte [si+1], '.'
    jne .cd_search
    mov word [current_dir_sector], 6
    mov si, msg_cd_root
    call print_string
    jmp .done
.cd_search:
    mov [cd_name_ptr], si
    call dir_read
    jc .dir_error
    mov bx, 0
.cd_loop:
    cmp bx, 512
    jge .cd_not_found
    mov al, [dir_buffer + bx]
    test al, al
    jz .cd_not_found
    cmp al, 0xE5
    je .cd_next
    mov al, [dir_buffer + bx + 11]
    test al, 0x10
    jz .cd_next
    push bx
    mov si, [cd_name_ptr]
    lea di, [dir_buffer + bx]
    mov cx, 8
.cd_cmp_loop:
    mov al, [si]
    test al, al
    jz .cd_check_padding
    call to_upper
    cmp al, [di]
    jne .cd_no_match
    inc si
    inc di
    dec cx
    jnz .cd_cmp_loop
    jmp .cd_match
.cd_check_padding:
    cmp cx, 0
    je .cd_match
    cmp byte [di], ' '
    jne .cd_no_match
    inc di
    dec cx
    jmp .cd_check_padding
.cd_match:
    pop bx
    xor ax, ax
    mov ax, [dir_buffer + bx + 26]
    cmp ax, 2
    jl .cd_use_root
    sub ax, 2
    add ax, 6
    mov [current_dir_sector], ax
    jmp .cd_done
.cd_use_root:
    mov word [current_dir_sector], 6
.cd_done:
    mov si, msg_cd_ok
    call print_string
    jmp .done
.cd_no_match:
    pop bx
.cd_next:
    add bx, 32
    jmp .cd_loop
.cd_not_found:
    mov si, msg_cd_fail
    call print_string
    jmp .done

.do_print:
    mov si, input_buffer
.skip_p:
    lodsb
    cmp al, ' '
    jne .skip_p
    call dir_read
    jc .dir_error
    mov si, dir_buffer
    call print_string
    mov si, msg_newline
    call print_string
    jmp .done

.do_mkdir:
    mov si, input_buffer
.skip_md:
    lodsb
    cmp al, ' '
    jne .skip_md
    push si
    call dir_read
    jc .dir_error
    pop si
    mov bx, 0
.find_empty:
    cmp bx, 512
    jge .disk_full
    cmp byte [dir_buffer + bx], 0x00
    je .found_slot
    add bx, 32
    jmp .find_empty
.found_slot:
    push bx
    mov di, dir_buffer
    add di, bx
    mov cx, 32
    xor al, al
    rep stosb
    pop bx
    mov di, dir_buffer
    add di, bx
    mov cx, 8
.copy_name:
    lodsb
    test al, al
    jz .pad_name
    cmp al, '.'
    je .pad_name
    cmp al, 'a'
    jl .no_up
    cmp al, 'z'
    jg .no_up
    sub al, 0x20
.no_up:
    stosb
    loop .copy_name
    jmp .set_attr
.pad_name:
    mov al, ' '
    stosb
    loop .pad_name
.set_attr:
    mov byte [dir_buffer + bx + 11], 0x10
    call dir_write
    jc .dir_error
    mov si, msg_mkdir_ok
    call print_string
    jmp .done
.disk_full:
    mov si, msg_full
    call print_string
.done:
    ret

; ── String Utilities ──
str_compare:
    push si
    push di
.sc_loop:
    mov al, [si]
    call to_upper_al
    mov bl, [di]
    cmp al, bl
    jne .sc_ne
    test al, al
    jz .sc_eq
    inc si
    inc di
    jmp .sc_loop
.sc_eq:
    pop di
    pop si
    xor ax, ax
    ret
.sc_ne:
    pop di
    pop si
    mov al, 1
    test al, al
    ret

str_compare_prefix:
    push si
    push di
.scp_loop:
    mov al, [di]
    test al, al
    jz .scp_check_end
    mov bl, [si]
    call to_upper_bl
    cmp bl, al
    jne .scp_ne
    inc si
    inc di
    jmp .scp_loop
.scp_check_end:
    mov al, [si]
    cmp al, ' '
    je .scp_eq
    cmp al, 0
    je .scp_eq
    jmp .scp_ne
.scp_eq:
    pop di
    pop si
    xor ax, ax
    ret
.scp_ne:
    pop di
    pop si
    mov al, 1
    test al, al
    ret

to_upper_al:
    cmp al, 'a'
    jl .ret
    cmp al, 'z'
    jg .ret
    sub al, 0x20
.ret:
    ret

to_upper_bl:
    cmp bl, 'a'
    jl .ret
    cmp bl, 'z'
    jg .ret
    sub bl, 0x20
.ret:
    ret

to_upper:
    call to_upper_al
    ret

; ── Shell Data ──
cmd_help    db "HELP", 0
cmd_cls     db "CLS", 0
cmd_ver     db "VER", 0
cmd_dir     db "DIR", 0
cmd_cd      db "CD", 0
cmd_print   db "PRINT", 0
cmd_mkdir   db "MKDIR", 0
cmd_reboot  db "REBOOT", 0

msg_help    db "Commands: HELP CLS VER DIR CD MKDIR PRINT REBOOT", 0x0D, 0x0A, 0
msg_ver     db "ParacleteOS v0.1 (x86 Real Mode)", 0x0D, 0x0A, 0
msg_prompt  db "C:\> ", 0
msg_unknown db "Bad command or file name.", 0x0D, 0x0A, 0
msg_dir_header db "Directory of C:\", 0x0D, 0x0A, 0
msg_dir_tag    db "  <DIR>", 0x0D, 0x0A, 0
msg_mkdir_ok   db "Directory created.", 0x0D, 0x0A, 0
msg_full       db "Error: Directory full.", 0x0D, 0x0A, 0
msg_cd_ok      db "Directory changed.", 0x0D, 0x0A, 0
msg_cd_fail    db "Directory not found.", 0x0D, 0x0A, 0
msg_cd_root    db "Back to root.", 0x0D, 0x0A, 0