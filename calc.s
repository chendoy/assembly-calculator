section .rodata
    format_string : db "%d", 10, 0
    input_length equ 80
    debug_msg: db "debug msg", 10,0

section .bss
    buff: resb 80          ; input buffer
    op_stack: resb 20      ; operand stack
    len: equ $ - op_stack
    counter: resd 1        ; op_stack elements counter, initialized to zero
    op_top: resd 1         ; pointer to the op_stack pointer

    


section .text
align 16
global main
extern printf
extern fflush
extern malloc
extern calloc
extern free
extern fgets
extern stdin
extern stdout
extern stderr

getInput:
    push ebp
    mov ebp,esp
    pushad
    push dword [stdin]
    push input_length
    push buff
    call fgets
    add esp,12                     ; clean stack after function call
    popad                   ; Restore caller state
    mov esp, ebp            ; Restore caller state
    pop ebp                 ; Restore caller state
    ret
    
  
main:
    mov eax, op_stack
    mov dword [op_top], eax     ; initially op_top points to op_stack
    call myCalc
    mov     eax,1
    mov     ebx,0
    int     0x80
    

myCalc:
    push ebp
    mov ebp,esp
    pushad
    call getInput
    ;;;;;
    push buff
    call get_length
    push eax
    push format_string
    call printf
    add esp,8
    ;;;;;
    
    cmp byte [buff], "q"
    jnz main_loop
    
    popad                   ; Restore caller state
    mov esp, ebp            ; Restore caller state
    pop ebp                 ; Restore caller state
    ret
    
main_loop:
    nop
    
get_length:
    push ebp
    mov ebp,esp
    pushad
    mov ebx, [ebp+4]              ; get first argument (pointer to buff)
    mov eax,0                   ; holds the string get_length
    cmp dword [ebx], "\n"
    jnz .loop
    add esp,4
    popad
    pop ebp
    ret
    .loop:
        inc eax
        inc ebx
        cmp dword [ebx], "\n"
        jnz .loop
        add esp,4
        popad
        pop ebp
        ret
