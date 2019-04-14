section .rodata
    format_string : db "%d", 10, 0
    input_length equ 80

section .bss
    buff: resb 80           ; input buffer
    op_stack: resb 20       ; operand stack
    len: equ $ - op_stack
    counter: resd 1         ; op_stack elements counter, initialized to zero
    op_top: resd 1          ; pointer to the op_stack pointer
    buff_len: resd 1        ; length of the buffer (used in buff_to_list)
    two_rightmost: resb 2
    ;link:
    ;    db: 0               ; data byte
    ;    dd: 0               ; pointer to next link

    


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
    cmp byte [buff], "q"
    jnz main_loop
    
    popad                   ; Restore caller state
    mov esp, ebp            ; Restore caller state
    pop ebp                 ; Restore caller state
    ret
    
main_loop:
    push buff
    call buff_to_list
    add esp,4
    push eax

    jmp myCalc
    
get_length:
    push ebp
    mov ebp,esp
    mov ebx, [ebp+8]              ; get first argument (pointer to buff)
    mov eax,0                     ; holds the string get_length
    cmp byte [ebx], 10
    jnz .loop
    mov esp, ebp                  ; Restore caller state
    pop ebp                       ; Restore caller state
    ret
    .loop:
        inc eax
        inc ebx
    
    cmp byte [ebx], 10
        jnz .loop
        mov esp, ebp              ; Restore caller state
        po    push eax
    push format_string
    call printf
    add esp,8
    pop ebp                   ; Restore caller state
    ret
        
        
to_numeric:                       ; gets a string buffer and returns the numeric representation of the buffer
    push ebp
    mov ebp,esp
    mov esi,[esp+8]
    mov ecx, 2                    ; string length is 1 or 2, default 2
    xor ebx,ebx                   ; clear ebx
    .next_digit:
    movzx eax,byte[esi]
    inc esi
    sub al,'0'                    ; convert from ASCII to number
    imul ebx,16
    add ebx,eax                   ; ebx = ebx*16 + eax
    loop .next_digit              ; while (--ecx)
    mov eax,ebx
    mov esp, ebp                  ; Restore caller state
    pop ebp                       ; Restore caller state
    ret
        
        
buff_to_list:                     ; gets a pointer to string and
    push ebp                      ; returns a pointer to linked list
    mov ebp,esp                   ; as suggested in class
    mov ebx, dword [ebp+8]
    push ebx                      ; ebx holds pointer to input buffer
    call get_length
    add esp,4
    mov ecx,eax                   ; ecx = length of buffer
    .loop:
        mov edx, dword [ebx]
        mov dword [two_rightmost],edx
        push two_rightmost
        call to_numeric
        add esp,4
        
        
        push eax
        push format_string
        call printf
        add esp,8
        
        
        add ebx, 2
        dec ecx                   ; decrement ecx in addition to the loop decremantation
        loop .loop, ecx
