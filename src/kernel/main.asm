ORG  0x7C00
BITS 16

;
; FAT12 HEADER
;

; These declarations are just to pad the
; top of the floppy with the FAT12 header
; bytes, so just skip past it using a jmp

jmp short start
nop

bdb_oem                     DB "MSWIN4.1"
bdb_bytes_per_sector        DW 512
bdb_sectors_per_cluster     DB 1
bdb_reserved_sectors        DW 1
bdb_fat_count               DB 2
bdb_dir_entries_count       DW 0x0E0
dbd_total_sectors           DW 2880
bdb_media_descriptor_type   DB 0x0F0
bdb_sectors_per_fat         DW 9
bdb_sectors_per_track       DW 18
bdb_heads                   DW 2
bdb_hidden_sectors          DD 0
bdb_large_sector_count      DD 0

;
; EXTENDED BOOT RECORD
;

; A master boot record often is followed by
; several EBR or extended boot records, which
; describe the logical partitions of the system

ebr_drive_number        DB 0
                        DB 0
ebr_signature           DB 0x29
ebr_volume_id           DB 0x62, 0x20, 0x04, 0x29
ebr_volume_label        DB "SLAY OS    "
ebr_system_id           DB "FABULOUS"

;
; MAIN CODE
;

; This label delineates all code that
; will run BEFORE the main bootloader

start:
    jmp main

; This label delineates all code that
; runs FOR the duration of the bootloader

main:
    ; Initializing data segments
    mov  ax, 0                      ; We can't mov vals into ds/es directly, so we use ax as an intermediary
    mov  ds, ax
    mov  es, ax

    ; Setup the stack
    mov  ss, ax
    mov  sp, 0x7C00                 ; Since the stack moves downward, we set it to the start of the bootloader code to not overlap

    mov  [ebr_drive_number], dl     ; The BIOS sets DL to the EBR_DRIVE_NUMBER for us

    mov  ax, 0x1                    ; LBA address
    mov  cl, 0x1                    ; Number of sectors read
    mov  bx, 0x7E00                 ; Where the information read will be stored
    call disk_read

    mov  si, msg_hello              ; Prep our hello world message to be printed
    call puts                       ; Print it

    cli                             ; Disable interrupts
    hlt                             ; Stop execution

.halt:
    cli
    hlt

;
; HELPER FUNCTIONS
;

;
; Prints a string to the screen using
; BIOS TTY mode
;
; PARAMS:
; - si: Address of string
; RETURNS:
; - VOID
;

puts:
    ; Save registers that will be modified
    push si
    push ax

.loop:
    lodsb                       ; Load next character from si into al
    or   al, al                 ; Check for 0x0 character
    jz   .done                  ; If al == 0x0, then jump to the end of the function

    mov  ah, 0x0E               ; Set AH to the WRITE TO TTY interrupt number (0x0E)
    mov  bh, 0x0                ; Set BH to the first page number (0x0)
    int  0x10                   ; Call BIOS interrupt

    jmp  .loop                   ; Loop until printing is complete

.done:
    ; Pop the registers back off the stack
    pop ax
    pop si

    ret

;
; Converts an LBA address to a CHS address
;
; PARAMS:
; - ax: LBA address
; RETURNS:
; - cx [bits 0-5]:  sector number
; - cx [bits 6-15]: cylinder
; - dh:             head number
;

lba_to_chs:
    ; Save registers that will be modified
    push ax
    push dx

    xor dx, dx                          ; Clear DX for division operation
    div word [bdb_sectors_per_track]    ; AX = LBA / SPT
                                        ; DX = LBA % SPT

    inc dx                              ; S = (LBA % SPT) + 1
    mov cx, dx                          ; Move sector number into CL

    xor dx, dx                          ; Clear DX for another division
    div word [bdb_heads]                ; AX = LBA / (SPT * HPC)
                                        ; DX = (LBA / SPT) % HPC

    mov dh, dl                          ; Move head into DH
    mov ch, al                          ; Move lower 8 bits of cylinder into CH
    shl ah, 6                           ; Align the last bit of cylinder to the far end of ah
    or cl, al                           ; Append the last cylinder bit into the register

    pop ax                              ; We cannot pop into 16 bit registers, so pop DX into AX
    mov dl, al                          ; Restore DL, which shouldn't be modified
    pop ax                              ; Restore AX
    ret

;
; Reads sectors from a disk
;
; PARAMS:
; - ax:    LBA address
; - cl:    number of sectors to read (up to 128)
; - dl:    drive number
; - es:bx: memory address where to store read data
;

disk_read:
    pusha

    push cx                             ; Save the sectors to be read
    call lba_to_chs
    pop  ax                             ; Restore sectors to be read

    mov  ah, 0x02                       ; Set AH to disk read BIOS interrupt
    mov  di, 3                          ; Set number of attempts to 3

.retry:
    pusha                               ; Save our registers on each attempt
    stc                                 ; Set carry flag to check success
    int  0x13                           ; Call BIOS to read disk
    jnc  .done                          ; If carry flag was still set, read failed

    ; Read has failed
    popa                                ; Restore registers to pre-attempt
    call disk_reset

    dec  di                             ; Mark one attempt complete
    test di, di                         ; Check if 3 attempts have completed
    jnz  .retry                         ; If not, try again

.fail:
    ; After all attempt, full fail
    jmp floppy_error

.done:
    popa                                ; Restore to preattempt register state
    popa                                ; Restore to pre-call register state

    ret

;
; Resets the disk reader
;

disk_reset:
    pusha
    mov ah, 0x0
    stc
    int 0x13

    jc floppy_error
    popa
    ret


;
; Restarts the system
;

floppy_error:
    mov  si, msg_read_failed
    call puts
    jmp  wait_key_and_reboot

;
; Waits for key press and then
; reboots
;

wait_key_and_reboot:
    mov ah, 0
    int 0x16
    jmp 0x0FFFF:0
    hlt

;
; DATA
;

msg_hello       DB "Hello, World", 0xD, 0xA, 0x0
msg_read_failed DB "Read from disk failed!", 0xD 0xA, 0x0

;
; BOOTLOADER SIGNATURE
;

TIMES 510-($-$$) DB 0                   ; Fill the rest of the file (up to 510 bytes) with 0s
DW    0xAA55                            ; APPEND BOOTLOADER SIGNATURE TO BINARY
