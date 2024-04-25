BITS 16

;
; Expose ASM C entry point to the linker
;

section _ENTRY class=CODE

extern _cstart_
global entry

;
; Prep for entry into C code
;

entry:
    cli                                     ; Disable interrupts

    ; Setup the stack
    mov   ax, ds                            ; DS should be setup to point to the stack from STAGE1
    mov   ss, ax
    mov   sp, 0
    mov   bp, sp

    sti                                     ; Reenable interrupts now that stack is ready

    ; DL has the boot drive from 
    ; STAGE1 so just push it for C to use

    xor  dh, dh
    push dx
    call _cstart_                           ; Transfer control to C for the rest of STAGE2

    ; If contol is ever returned, stop
    ; responding to interrupts and halt

    cli
    hlt
