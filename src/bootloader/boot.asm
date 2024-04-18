ORG 0x7C00
BITS 16

%define ENDL 0x0D, 0x0A

; FAT12 HEADER

jmp short start
nop

bdb_oem                         db 'MSWIN4.1'
bdb_bytes_per_sector            dw 512
bdb_sectors_per_cluster         db 1
bdb_reserved_sectors            dw 1
bdb_fat_count                   db 2
bdb_dir_entries_count           dw 0E0h
bdb_total_sectors               dw 2880
bdb_media_descriptor_type       db 0F0h
bdb_sector_per_fat              dw 9
bdb_sectors_per_track           dw 18
bdb_heads                       dw 2
bdb_hidden_sectors              dd 0
bdb_large_sector_count          dd 0

; EXTENDED BOOT SECTOR

ebr_drive_number        db 0
                        db 0
ebr_signature           db 29h
ebr_volume_id           db 12h, 34h, 56h, 78h
ebr_volume_label        db 'SLAY       '
ebr_system_id           db 'FAT12   '

; CODE SEGMENT NOT SEGMENT

start:
    jmp main

main:
    ; Initializing data segments
    mov ax, 0                           ; We can not write to sd/es directly
    mov ds, ax
    mov es, ax

    ; Set up stack
    mov ss, ax
    mov sp, 0x7C00                      ; Stack goes downward from where we are in memory

    mov [ebr_drive_number], dl

    mov ax, 1
    mov cl, 1
    mov bx, 0x7E00
    call disk_read

    mov si, msg_hello
    call puts

    hlt

; ERROR HANDLERS
floppy_error:
    mov  si, msg_read_failed
    call puts
    jmp  wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0
    int 16h
    jmp 0FFFFh:0
    hlt

.halt:
    cli
    hlt

; FUNCTIONS

;
; PRINTING TO SCREEN
;

;
; PARAMS:
;   - si: Address of string
; RETURNS:
;   VOID
;
puts:
    ;Saving the registers that we will modify
    push si
    push ax

.loop:
    lodsb                               ; Loads next char in al
    or al, al                           ; verify is the next character null
    jz .done

    mov ah, 0x0E
    mov bh, 0
    int 10h

    jmp .loop

.done:
    pop ax
    pop si
    ret


;
; DISK ROUTINES
;

;
; CONVERTS AN LBA ADDRESS TO CHS ADDRESS
; PARAMS:
;   - ax: LBA address
; RETURNS:
;   - cx: [bits 0-5]: sector number
;   - cx: [bits 6-15]: cylinder
;   - dh: head
;

lba_to_chs:
    push ax
    push dx

    xor dx, dx
    div word [bdb_sectors_per_track]

    inc dx
    mov cx, dx

    xor dx, dx
    div word [bdb_heads]

    mov dh, dl
    mov ch, al
    shl ah, 6
    or  cl, al

    pop ax
    mov dl, al
    pop ax
    ret

;
; Reads sectors from a disk
; Parameters:
; - ax: LBA address
; - cl: number of sectors to read (up to 128)
; - dl: drive number
; - es:bx: memory address where to store read data
;
disk_read:
    push ax
    push bx
    push cx
    push dx
    push di

    push cx                             ; Numbers of sectors to read
    call lba_to_chs
    pop ax

    mov ah, 02h
    mov di, 3

.retry:
    pusha
    stc
    int 13h
    jnc .done

    ; read failed
    popa
    call disk_reset

    dec di
    test di, di
    jnz .retry

.fail:
    ; after all attempts fail
    jmp floppy_error

.done:
    popa

    pop di
    pop dx
    pop cx
    pop bx
    pop ax

disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h
    jc floppy_error
    popa
    ret

msg_hello:      DB 'Hello World', ENDL, 0
msg_read_failed DB 'Read from disk failed!', ENDL, 0

;TIMES 510-($-$$) DB 0                   ; Fill with 0's to let last two bytes be signatues.
;DW 0xAA55
