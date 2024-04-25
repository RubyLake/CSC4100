ORG  0x0
BITS 16

start:
    ; print hello world to screen
    mov  si, msg_hello
    call puts

.halt:
    cli
    hlt

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

msg_hello DB "Hello, World! - From the Kernel :) <3", 0xD, 0xA, 0x0