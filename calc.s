section .rodata
    format_string : db "%d", 10, 0
    input_length equ 81
    LINK_SIZE equ 5


section .bss
    buff: resb 81                  ; input buffer
    buff_backup: resb 81           ; backup for odd buffer length
    op_stack: resb 20              ; operand stack
    len: equ $ - op_stack
    counter: resd 1                ; op_stack elements counter, initialized to zero
    op_top: resd 1                 ; pointer to the op_stack pointer
    buff_len: resd 1               ; length of the buffer (used in buff_to_list)
    struc link
        data: resb 1               ; data byte
        next: resb 4               ; pointer to next link
    endstruc
    head: resd 1                   ; head of created linked list
    firstFlag: resb 1
    prev: resd 1
    


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
    mov byte [firstFlag], 1      ; initializes the flag to 'true'
    call buff_to_list
    add esp,4
    push eax

    jmp myCalc
    
get_length:
    push ebp
    mov ebp,esp
    sub esp,4                     ; Leave space for local var on stack
    pushad
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
    mov [ebp-4],eax
    popad
    mov eax,[ebp-4]
    mov esp, ebp              ; Restore caller state
    pop ebp                   ; Restore caller state
    ret
        
        
to_numeric:             ; gets a string buffer and returns the numeric representation of the buffer
    push ebp
    mov ebp,esp
    sub esp, 4          ; Leave space for local var on stack
    pushad
    
    mov esi,[ebp+8]
    mov ecx, 2                    ; string length is always 2
    xor ebx,ebx                   ; clear ebx
    next_digit:
    
    mov al,byte[esi]
    inc esi

deubg:
    push eax                      ; backup al
    sub eax, 'A'
    cmp eax, 'F'
    ja not_a_character
    add eax, 'A'
    sub eax, 7
    add esp,4                     ; just "pops" eax without storing it
    jmp do_not_restore
    
not_a_character:

    pop eax                        ; restore al
    
do_not_restore:

    sub eax,'0'                    ; convert from ASCII to number
    imul ebx,16
    add ebx,eax                   ; ebx = ebx*16 + eax
    loop next_digit              ; while (--ecx)
    mov [ebp-4], ebx
    popad
    mov eax, [ebp-4]
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
    
    test eax, 1                   ; checks if the number is odd or even
    jz buffer_isEven
    
    ; if reached here, buffer is not even, needs to pad with '0' at the beginning
    
    pushad
    cld
    mov esi, buff
    mov edi, buff_backup
    mov ecx, input_length
    rep movsb
    popad
    
    mov byte [buff], '0'
    
    pushad
    cld
    mov esi, buff_backup
    mov edi, buff+1
    mov ecx, input_length
    rep movsb
    popad
    
buffer_isEven:

    push ebx                      ; ebx holds pointer to input buffer
    call get_length
    add esp,4
    
    mov ecx,eax                   ; ecx = length of buffer
    
   
    
    add ebx,ecx
    .loop:
        
        sub ebx,2
        push ebx
        call to_numeric
        add esp,4
        
        mov edx, eax                      ; backup numeric value in another register before memory allocation
        
        ; at this point EAX holds the numeric representation of the rightmost two digits of the buffer
        
        push 1                            ; 1 byte * 5 (num of link elements) = 5 bytes
        push LINK_SIZE
        call calloc
        add esp, 8                        ; clean stack after calloc call
        mov [eax], dl                     ; take the lower byte of edx and store it in the data of the link
        mov  dword [eax+data], 0          ; for now the next pointer is NULL
        
        mov  dword [prev+data], eax              ; connect prev and current
        
        cmp byte [firstFlag], 1
        jnz .not_first
        mov [head], eax
        mov byte [firstFlag], 0                ; we've created the first link already, turns off the flag

        .not_first:
        
        mov [prev], eax                   ; prepares prev for the next link assignment
        
        dec ecx                   ; decrement ecx in addition to the loop decremantation
        loop .loop, ecx
