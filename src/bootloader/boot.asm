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

start:
    ; Initializing data segments
    mov  ax, 0                          ; We can't mov vals into ds/es directly, so we use ax as an intermediary
    mov  ds, ax
    mov  es, ax

    ; Setup the stack
    mov  ss, ax
    mov  sp, 0x7C00                     ; Since the stack moves downward, we set it to the start of the bootloader code to not overlap

    ; BIOS may start at 0000:7C00 instead of 7C00:0000, this fixes that
    push es
    push word .after
    retf

.after:
    ; Begin read from floppy disk

    ; BIOS will set drive number, which we will set DL to
    mov  [ebr_drive_number], dl

    ; Show loading message

    mov  si, msg_loading
    call puts

    ; Read drive parameters rather than relying on the disk

    push es
    mov  ah, 0x08
    int  0x13
    jc   floppy_error
    pop  es

    and  cl, 0x3F                       ; Clear top two bits
    xor  ch, ch
    mov  [bdb_sectors_per_track], cx

    ; Compute LBA of root directory = reserved + FAT sectors * sector_per_fat

    mov  ax, [bdb_sectors_per_fat]
    mov  bl, [bdb_fat_count]
    xor  bh, bh
    mul  bx                             ; ax = (fats * sectors_per_fat)
    add  ax, [bdb_reserved_sectors]     ; ax = LBA of root directory
    push ax

    ; compute size of root directory = (32 * number_of_entries) / bytes_per_sector

    mov  ax, [bdb_dir_entries_count]
    shl  ax, 5
    xor  dx, dx
    div  word [bdb_bytes_per_sector]

    test dx, dx
    jz   .root_dir_after
    inc  ax

.root_dir_after:

    ;Start reading from root directory
    mov cl, al                     ; number os sectors / size of root dir
    pop ax                          ; LBA of root dir
    mov dl, [ebr_drive_number]      ; dl is the drive number
    mov bx, buffer                  ; es:bx = buffer
    call disk_read

    ;search for kernal.bin
    xor bx, bx
    mov di, buffer


.search_kernel:
    mov si, file_kernel_bin
    mov cx, 11                      ; compare up to 11 char
    push di
    repe cmpsb
    pop di
    je .found_kernel

    add di, 32
    inc bx
    cmp bx, [bdb_dir_entries_count]
    jl .search_kernel

    ;in case of kernel not found
    jmp kernel_not_found_error

.found_kernel:
    ;di should have the address
    mov ax, [di +26]                ;first logical cluster field
    mov [kernel_cluster], ax

    ;load FAT from disk to mem
    mov ax, [bdb_reserved_sectors]
    mov bx, buffer
    mov cl, [bdb_sectors_per_fat]
    mov dl, [ebr_drive_number]
    call disk_read

    ;read and process FAT chain
    mov bx, KERNEL_LOAD_SEGMENT
    mov es, bx
    mov bx, KERNEL_LOAD_OFFSET

.load_kernel_loop:

    ;read next cluster
    mov ax, [kernel_cluster]

    ;temp hardcoded val :^(
    add ax, 31

    mov  cl, 1
    mov  dl, [ebr_drive_number]
    call disk_read

    add bx, [bdb_bytes_per_sector]

    ;computer location of next cluster
    mov ax, [kernel_cluster]
    mov cx, 3
    mul cx
    mov cx, 2
    div cx                         ;index of entry in FAT

    mov si, buffer
    add si, ax
    mov ax, [ds:si]                 ;read from FAT table at index ax

    or dx, dx
    jz .even

.odd:
    shr ax,4
    jmp .next_cluster_after

.even:
    and ax, 0x0FFF

.next_cluster_after:
    cmp ax, 0xFF8
    jae .read_finish

    mov [kernel_cluster], ax
    jmp .load_kernel_loop

.read_finish:
    ; BEEG jump to the kernel
    mov dl, [ebr_drive_number]

    mov ax, KERNEL_LOAD_SEGMENT
    mov ds, ax
    mov es, ax

    jmp KERNEL_LOAD_SEGMENT:KERNEL_LOAD_OFFSET

    jmp wait_key_and_reboot

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
    push bx

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
    pop bx
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
; Notifies user that kernel
; was not found
;

kernel_not_found_error:
    mov  si, msg_kernel_not_found
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

.halt:
    cli
    hlt

;
; DATA
;

msg_loading:            DB "Loading...", 0xD, 0xA, 0x0
msg_read_failed:        DB "Read from disk failed!", 0xD 0xA, 0x0
msg_kernel_not_found:   DB "KERNEL.BIN file not found!", 0xD 0xA, 0x0
file_kernel_bin:        DB 'KERNEL  BIN'
kernel_cluster:         DW 0

KERNEL_LOAD_SEGMENT equ 0x2000
KERNEL_LOAD_OFFSET  equ 0

;
; BOOTLOADER SIGNATURE
;

TIMES 510-($-$$) DB 0                   ; Fill the rest of the file (up to 510 bytes) with 0s
DW    0xAA55                            ; APPEND BOOTLOADER SIGNATURE TO BINARY

buffer: