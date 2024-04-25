BITS 16

section _TEXT class=CODE

; Create symbol to be accessed from C
global _x86_Video_WriteCharTeletype

;
; PRINTS A SINGLE CHARACTER TO SCREEN IN
; TELETYPE MODE
;
; ARGS:
; - CHARACTER: [bp + 4]
; - PAGE NO:   [bp + 6]
;
_x86_Video_WriteCharTeletype:
    push bp
    mov  bp, sp

    push bx

    ; Call BIOS interrupt for writing char
    mov  ah, 0x0E
    mov  al, [bp + 4]
    mov  bh, [bp + 6]
    int  0x10

    pop bx

    leave
    ret
