section .rodata
    format_string_hex : db "%#04X",0
    format_string_s : db "%s",0
    arrow_symbol : db " -> ",0
    end_str: db "END",10, 0
    fullStack_error : db "Operand Stack Overflow ",10,0
    emptyStack_error: db "Insufficent Number of Arguments on Stack",10,0
    input_length equ 81
    LINK_SIZE equ 5
    prompt: db "calc: ",0


section .bss
    buff: resb 81                  ; input buffer
    buff_backup: resb 81           ; backup for odd buffer length
    op_stack: resb 20              ; operand stack
    len: equ $ - op_stack
    op_top: resd 1                 ; pointer to the op_stack pointer
    buff_len: resd 1               ; length of the buffer (used in buff_to_list)
    struc link
        data: resb 1               ; data byte
        next: resb 4               ; pointer to next link
    endstruc
    head: resd 1                   ; head of created linked list
    firstFlag: resb 1
    prev: resd 1
    curr: resd 1
    
section .data
  counter: dd 0                ; op_stack elements counter, initialized to zero
  
%macro print_and_flush 2
    push %1
    push %2
    call printf               ; arg0 - content, arg1 - format
    add esp,8
    
    push dword [stdout]       ; flushes stdout (in case no '\n' is used)
    call fflush
    add esp,4
%endmacro

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
    mov byte [firstFlag], 1      ; initializes the flag to 'true'
    mov eax, op_stack
    mov dword [op_top], eax     ; initially op_top points to op_stack
    call myCalc
    mov     eax,1
    mov     ebx,0
    int     0x80
    

myCalc:
    push ebp              ; save caller state
    mov ebp,esp           ; save caller state
    pushad                ; save caller state
    
get_input:
    
    print_and_flush prompt, format_string_s
    
    call getInput         ; fill buff variable with user input
    
    cmp byte [buff], "q"  
    jz .exit
    
    cmp byte [buff], "+"
    jz .addition
    
    cmp byte [buff], "p"
    jz .pop_and_print
    
    cmp byte [buff], "d"
    jz .duplicate
    
    cmp byte [buff], "^"
    jz .mul_and_exp
    
    cmp byte [buff], "v"
    jz .mul_and_exp_oppo
    
    cmp byte [buff], "n"
    jz .number_of_1_bits
    
    cmp word [buff], "sr"
    jz .square_root
    
    jmp .push_operand      ; default case, probable a number - push it to operand stack
    
    
    call buff_to_list
    add esp,4
    
    
.addition:

    jmp get_input

.pop_and_print:

    jmp get_input

.duplicate:

    jmp get_input

.mul_and_exp:

    jmp get_input

.mul_and_exp_oppo:

    jmp get_input

.number_of_1_bits:   

    jmp get_input

.square_root:

    jmp get_input
    
.push_operand:           ; pushes the operand stored in buff onto the operand stack
    
    push buff
    call buff_to_list
    add esp,4
    push eax
    call push_op
    add esp,4
    jmp get_input

    
 
.exit:
    
    popad                   ; Restore caller state
    mov esp, ebp            ; Restore caller state
    pop ebp                 ; Restore caller state
    ret
    
    
print_list:
    push ebp
    mov ebp,esp
    mov ebx, [ebp+8]
    pushad
        
    printing_loop:
    
    pushad
    
    movzx edx, byte [ebx]
    print_and_flush edx, format_string_hex         ; prints the link data
    print_and_flush arrow_symbol, format_string_s  ; prints ->

    popad

debug2:
    
    cmp dword [ebx+next], 0
    jz done
    mov ebx,dword [ebx+next]              ; makes ebx points to next link
    jmp printing_loop
    
    done:
    
    push end_str
    push format_string_s
    call printf
    add esp,8
    
    push dword [stdout]
    call fflush
    add esp,4
    
    popad
    mov esp, ebp              ; Restore caller state
    pop ebp                   ; Restore caller state
    ret
    
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
        
        
to_numeric:                   ; gets a string buffer and returns the numeric representation of the buffer
    push ebp
    mov ebp,esp
    sub esp, 4                ; Leave space for local var on stack
    pushad
    
    mov esi,[ebp+8]
    mov ecx, 2                ; string length is always 2
    xor ebx,ebx               ; clear ebx
    next_digit:
    
    movzx eax,byte[esi]
    inc esi

    push eax                      ; backup al
    sub eax, 'A'
    cmp eax, 'F'
    ja not_a_character
    add eax, 'A'
    sub eax, 7
    add esp,4                     ; just "pops" eax without storing it
    jmp do_not_restore
    
not_a_character:

    pop eax                        ; restore eax
    
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
    pushad
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
        
        sub ebx,'0'
        push ebx
        call to_numeric
        add esp,4
        
        mov edx, eax                      ; backup numeric value in another register before memory allocation
        
        ; at this point EAX holds the numeric representation of the rightmost two digits of the buffer
        
        pushad                            ; back up all general purpose registers
        push 1                            ; 1 byte * 5 (num of link elements) = 5 bytes
        push LINK_SIZE
        call calloc
        add esp, 8                        ; clean stack after calloc call
        mov [curr], eax                   ; sets the curr pointer to calloc's return value
        popad
        
        mov eax, [curr]
        
        mov [eax], dl                     ; take the lower byte of edx and store it in the data of the link
        mov  dword [eax+next], 0          ; for now the next pointer is NULL
        
        
        cmp byte [firstFlag], 1
        jz .first

        mov esi, [prev]
        mov  dword [esi+next], eax              ; connect prev and current
        jmp .loop.continue_buff_to_list
        
        .first:
        
        mov [head], eax
        mov byte [firstFlag], 0                ; we've created the first link already, turns off the flag
        
.loop.continue_buff_to_list:
        
        mov [prev], eax                   ; prepares prev for the next link assignment
        
        dec ecx                   ; decrement ecx in addition to the loop decremantation
        loop .loop, ecx
        
    ; returning from buff_to_list function
    
    popad
    mov eax,[head]
    mov esp, ebp              ; Restore caller state
    pop ebp                   ; Restore caller state
    mov byte [firstFlag], 1      ; initializes the flag to 'true'
    ret
    
    

push_op:                            ; if the stack is full an error will be printed, otherwise the head will be added
    push ebp
    mov ebp,esp                    
    pushad
    mov ebx, [ebp+8]              ; get first argument (pointer to head of the linkedList)
    
    .checkNotFull:                ; checks if the OperandStack is full, if it is full an error will be printed
    cmp dword[counter],len         ;comparing between the stacksize (len) to counter.
    jnz .notFull
    pushad
    push fullStack_error
    call printf
    add esp,4
    popad                           ; Restore caller state
    mov esp,ebp                     ; Restore caller state
    pop ebp                         ; Restore caller state
    ret                             ; Restore caller state
    
    .notFull:
    mov eax,dword[counter]         
    mov edx,4
    imul edx
    add eax,op_stack            ;eax=opstack+(4*counter) eax points to the next avilable spot in the stack
    
    mov dword [eax],dword ebx      ;placing the head of the list in the stack
    inc dword[counter]             ;counter now increase by 1
    popad                     ; Restore caller state
    mov esp, ebp              ; Restore caller state
    pop ebp                   ; Restore caller state
    ret

;if the stack is empty an error will be printed, otherwise top element will be retrived (via eax register)
pop_op: 

    push ebp       ;init
    mov ebp,esp    ;init
    sub esp,4      ; Leave space for local var on stack
    pushad         ;init
    
    .checkNotEMpty:        ; checks if the OperandStack is empty. if it is, error will be printed.
    cmp dword[counter],0
    jnz .notEmpty
    pushad
    push emptyStack_error
    call printf
    add esp,4
    popad                           ; Restore caller state
    mov esp,ebp                     ; Restore caller state
    pop ebp                         ; Restore caller state
    ret                             ; Restore caller state
    
    .notEmpty:       ;the stack is not empty, we will remove the first element and store it in eax
    mov eax,dword[counter]
    sub eax,1
    mov edx,4
    imul edx
    add eax,op_stack     ;eax = opstack+(4*(counter-1)). eax point to the top element at the stack 
    
    mov eax,[eax] ;eax holds now the pointer to linkedlist of the top element at the stack
    mov [ebp-4],eax ;local variable holds now the pointer to linkedlist of the top element at the stack
    
    dec dword[counter]             ;counter decrease by 1    
    popad                     ; Restore caller state
    mov eax,[ebp-4] ; store the popped element pointer (to linkedlist) in eax 
    mov esp, ebp              ; Restore caller state
    pop ebp                   ; Restore caller state
    ret

    
linkToNumber: ; converting the linked list to number (decimal). the number will be restored in eax

