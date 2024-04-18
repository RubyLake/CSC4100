ORG 0x7C00
BITS 16

%define ENDL 0x0D, 0x0A

; CODE SEGMENT NOT SEGMENT

start:
    jmp main


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

main:
    ; Initializing data segments
    mov ax, 0                           ; We can not write to sd/es directly
    mov ds, ax
    mov es, ax

    ; Set up stack
    mov ss, ax
    mov sp, 0x7C00                      ; Stack goes downward from where we are in memory

    mov si, msg_hello
    call puts

    hlt

.halt:
    jmp .halt

; DATA SEGMENT NOT SEGMENT

msg_hello: DB 'Hello World', ENDL, 0

TIMES 510-($-$$) DB 0                   ; Fill with 0's to let last two bytes be signatues.
DW 0xAA55
