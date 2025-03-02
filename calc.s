section .rodata
    format_string_hex : db "%02X",0
    format_string_hex_no_leading : db "%01X",0
    format_string_s : db "%s",0
    format_string_d: db "%d",0
    newline: db 10,0
    fullStack_error : db "Error: Operand Stack Overflow",10,0
    emptyStack_error: db "Error: Insufficient Number of Arguments on Stack",10,0
    Y_exceed200_error: db "wrong Y value",10,0
    prompt: db "calc: ",0
    debug_str: db "-d",0
    input_length equ 82
    LINK_SIZE equ 5
    debug_result_pushed: db "DEBUG: RESULT PUSHED ",0
    debug_input_read: db "DEBUG: NUMBER READ %s",0
    


section .bss
    buff: resb 82                  ; input buffer
    buff_backup: resb 82           ; backup for odd buffer length
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
    debug_mode: resb 1
    
    
section .data
  counter: dd 0                ; op_stack elements counter, initialized to zero
   operation_counter: dd 0  
   listHolder_1 : dd 0       ;list holder helper to free memory	
   listHolder_2:dd 0         ;list holder helper to free memory
  
%macro print_and_flush 2
    
    push %1
    push %2
    call printf               ; arg0 - content, arg1 - format
    add esp,8
    
    push dword [stdout]       ; flushes stdout (in case no '\n' is used)
    call fflush
    add esp,4
    
%endmacro

%macro print_newline 0
    pushad
    push newline
    push format_string_s
    call printf
    add esp,8
    popad
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
    add esp,12              ; clean stack after function call
    
    popad                   ; Restore caller state
    mov esp, ebp            ; Restore caller state
    pop ebp                 ; Restore caller state
    ret
    
  
main:
    mov byte [debug_mode], 0     ; debug mode is off by default
    mov byte [firstFlag], 1      ; initializes the flag to 'true'
    mov eax, op_stack
    mov dword [op_top], eax      ; initially op_top points to op_stack
    
    ; infering debug mode
    
    mov ecx, [esp+4]
    mov edx, [esp+8]
    
    cmp ecx,2
    jge .look_for_debug_flag
    jmp .no_debug_flag
    
    .look_for_debug_flag:
    
    add edx,4 ; place for first argument
    mov edx, [edx]
    mov edx, [edx]
    mov ebx, [debug_str]
    cmp dx, bx
    jnz .no_debug_flag
    mov byte [debug_mode], 1
    
    .no_debug_flag:
    
    call myCalc
    
    .now:
    
    push eax
    call printNumOfOp
    add esp,4
    print_newline
    call clearstack    ;free memorty
    
    mov     eax,1
    mov     ebx,0
    int     0x80
    

myCalc:
    push ebp              ; save caller state
    mov ebp,esp           ; save caller state
    pushad                ; save caller state
    
get_input:

    pushad
    print_and_flush prompt, format_string_s
    
    call getInput         ; fill buff variable with user input
    
    cmp byte [buff], 10   ; empty input handler
    jz get_input
    
    cmp byte [buff], "q" 
    jz .exit
    
    cmp byte [buff], "+"   ; debug mode - [V]
    jz .addition
    
    cmp byte [buff], "p"  
    jz .pop_and_print
    
    cmp byte [buff], "d"   ; debug mode - [V]
    jz .duplicate
    
    cmp byte [buff], "^"   ; debug mode - [V]
    jz .mul_and_exp
    
    cmp byte [buff], "v"   ; debug mode - [V]
    jz .mul_and_exp_oppo
    
    cmp byte [buff], "n"   ; debug mode - [V]
    jz .number_of_1_bits
    
    cmp word [buff], "sr"  ; debug mode - [V]
    jz .square_root
    
    jmp .push_operand      ; debug mode - [V]

    
.addition:

    inc dword [operation_counter]
    cmp dword[counter],2 ;check op stack has enough elements to perform addition
    jge .continue_addition
    pushad
    push emptyStack_error
    call printf
    add esp,4
    popad
    jmp .done_addition
    
    
.continue_addition:
    call pop_op
    push eax
    mov dword[listHolder_1],eax   ;it will hold pointer to list in order to free it
    call pop_op
    push eax
    mov dword[listHolder_2],eax  ;it will hold pointer to list in order to free it
    call addLists
    add esp,8
    
    
    cmp byte [debug_mode],1
    jnz .no_debug_addition
    pushad
    mov esi,0
    print_and_flush esi,debug_result_pushed
    popad
    push eax
    call print_op
    add esp,4
    print_newline
    
    .no_debug_addition:
    
    add esp,4
    
    push eax
    call push_op
    add esp,4
    
    ;push dword[listHolder_1]     ;free memory after sucessfull add
    ;call free_lst
    ;add esp,4
    ;push dword[listHolder_2]
    ;call free_lst
    ;add esp,4
    
    .done_addition:
    
    jmp get_input

.pop_and_print:

    inc dword [operation_counter]
    cmp dword[counter],1 ;check op stack has enough elements to perform pop
    jge .continue_pop
    pushad
    push emptyStack_error
    call printf
    add esp,4
    popad
    jmp .done_pop
    
    
    .continue_pop:
    mov dword[listHolder_1],eax  ;in order free list later
    call pop_op
    mov ebx,eax   ; ebx - pointer to list
    add esp,4
    push ebx
    call getListLen  ; eax - length of list
    add esp,4
    push eax
    push ebx
    call print_op
    add esp,8
    print_newline
    ;push dword [listHolder_1]
    ;call free_lst
    
    add esp,4 
    
    .done_pop:
    jmp get_input

.duplicate:

    inc dword [operation_counter]
    cmp dword[counter],0  ;checks if there are elemnt at stack
    jnz .continue_duplicate 
    
    push emptyStack_error   ;print empty stack error
    call printf
    add esp,4
    jmp .done_duplicate
    
    .continue_duplicate:
    push ebx
    mov ebx,dword[op_top]
    push dword[ebx]
    call duplicate
    add esp,4
    pop ebx
    
    cmp byte [debug_mode],1
    jnz .no_debug_addition
    pushad
    mov esi,0
    print_and_flush esi,debug_result_pushed
    popad
    push eax
    call print_op
    add esp,4
    print_newline
    
    .no_debug_duplicate:
    
    push eax       ;pushing the duplicated list to operand stack
    call push_op
    add esp,4
    
    .done_duplicate:
    jmp get_input


.mul_and_exp:

    inc dword [operation_counter]
    cmp dword [counter],2  ;checks if there are elemnt at stack
    jge .continue_mul_and_exp 
    jmp .InsufficientelementsErr
    
    .continue_mul_and_exp: ;checks now the second operand is less equal 200
    mov ebx,dword [op_top]
    mov ebx,dword [ebx-4]        ;ebx holds second element at stack
    
    push ebx
    call checkYle200       ;checks if Y<=200
    add esp,4
    cmp eax,0
    jnz .y_over200    ;we dont act in case of  y greater then 200
    jmp .multiplication_code
    
    .y_over200:
    pushad
    print_and_flush Y_exceed200_error, format_string_s
    popad
    jmp .contTonextInput
    
    ;<multiplication code starts here, at this point Y<=200 >
    .multiplication_code:
    call pop_op ; X
    push eax
    mov dword [listHolder_1],eax  ;list holder to free at the end;list holder to free at the end
    call pop_op ; Y
    push eax
    mov dword[listHolder_2],eax  ;list holder to free at the end
    call mul_and_exp
    add esp,8
    
    cmp byte [debug_mode],1
    jnz .no_debug_mul_and_exp
    pushad
    mov esi,0
    print_and_flush esi,debug_result_pushed
    popad
    push eax
    call print_op
    add esp,4
    print_newline
    
    .no_debug_mul_and_exp:
    
    push eax
    call push_op
    add esp,4
    
    ;<free poped list at the end of the code>
    ;push dword[listHolder_1]     ;free memory after sucessfull add
    ;call free_lst
    ;add esp,4
    ;push dword[listHolder_2]
    ;call free_lst
    ;add esp,4
    ;<done free popped list at the end of the code>
    
    jmp .contTonextInput   ;<multiplication code ends here>
  
    
  ;<<this code prints insufficent error>>
  .InsufficientelementsErr:
    pushad
    push emptyStack_error
    call printf
    add esp,4
    popad
    jmp .contTonextInput
   ;<<end of insufficent error>>
    
    .contTonextInput:    
    jmp get_input


.mul_and_exp_oppo:

    inc dword [operation_counter]
    cmp dword [counter],2  ;checks if there are elemnt at stack
    jge .continue_mul_and_exp_oppo 
    jmp .InsufficientelementsErr_2
    
    
    .continue_mul_and_exp_oppo:  ;<the division code>
    
    mov ebx,dword [op_top]
    mov ebx,dword [ebx-4]        ;ebx holds second element at stack
    
    push ebx
    call checkYle200       ;checks if Y<=200
    add esp,4
    cmp eax,0
    jnz .y_over200_oppo    ;we dont act in case of  y greater then 200
    jmp .multiplication_code_oppo
    
    .y_over200_oppo:
    pushad
    print_and_flush Y_exceed200_error, format_string_s
    popad
    jmp .contTonextInput
    
    .multiplication_code_oppo:
    
    call pop_op ; X
    push eax 
    mov dword [listHolder_1],eax  ;list holder to free at the end;list holder to free at the end
    call pop_op ; Y
    push eax
    mov dword [listHolder_2],eax  ;list holder to free at the end
    
    call mul_and_exp_oppo
    add esp,8
    
    cmp byte [debug_mode],1
    jnz .no_debug_mul_and_exp_oppo
    pushad
    mov esi,0
    print_and_flush esi,debug_result_pushed
    popad
    push eax
    call print_op
    add esp,4
    print_newline
    
    .no_debug_mul_and_exp_oppo:
    
    push eax
    call push_op
    add esp,4
    
    
    ;<free poped list at the end of the code>
    ;push dword[listHolder_1]  
    ;call free_lst
    ;add esp,4
    ;push dword[listHolder_2]
    ;call free_lst
    ;add esp,4 ;<done free lists>
    
    
     jmp .contNext
    ;<end division code>
    
    ;<<this code prints insufficent error>>
    .InsufficientelementsErr_2:
    pushad
    push emptyStack_error
    call printf
    add esp,4
    popad
    jmp .contNext
    ;<<end of insufficent error>>
    
    .contNext: 
    jmp get_input

.number_of_1_bits:  

    inc dword [operation_counter]
    cmp dword[counter],0
    jz .not_enough_elements_err

    call pop_op
    mov dword[listHolder_1],eax  ;list holder to free memory
    push eax
    call countSetBits
    add esp,4
    
    cmp byte [debug_mode],1
    jnz .done_num_1_bits
    pushad
    mov esi,0
    print_and_flush esi,debug_result_pushed
    popad
    push eax
    call print_op
    add esp,4
    print_newline
    
    .done_num_1_bits:
    
    push eax
    call push_op
    add esp,4
    
    ;push dword[listHolder_1]   ;free popped list
    ;call free_lst
    ;add esp,4
   
    jmp .done_1_bits
   
    .not_enough_elements_err:
    pushad
    push emptyStack_error
    call printf
    add esp,4
    popad
   
   .done_1_bits:
    
    jmp get_input
    
.push_operand:           ; pushes the operand stored in buff onto the operand stack
    
    cmp byte [debug_mode],1
    jnz .no_debug
    pushad
    print_and_flush buff,debug_input_read
    popad
    add esp,4
    
    .no_debug:
    
    push buff
    call buff_to_list
    add esp,4
    push eax
    call push_op
    add esp,4
    
    jmp get_input
    
.square_root:
    
    inc dword [operation_counter]
    cmp dword [counter],0
    jz .not_enough_elements_err

    call pop_op
    mov dword [listHolder_1],eax  ;list holder to free memory
    push eax
    call square_root
    add esp,4
    
    cmp byte [debug_mode],1
    jnz .done_sr
    pushad
    mov esi,0
    print_and_flush esi,debug_result_pushed
    popad
    push eax
    call print_op
    add esp,4
    print_newline
    
    .done_sr:
    
    push eax
    call push_op
    add esp,4
   
    jmp .done_square_root
   
    .not_enough_elements_err_sr:
    pushad
    push emptyStack_error
    call printf
    add esp,4
    popad
   
   .done_square_root:
    
    jmp get_input



.exit:
    
    popad                   ; Restore caller state
    mov eax,dword[operation_counter]
    mov esp, ebp            ; Restore caller state
    pop ebp                 ; Restore caller state
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

    pop eax                      ; restore eax
    
do_not_restore:

    sub eax,'0'                  ; convert from ASCII to number
    imul ebx,16
    add ebx,eax                  ; ebx = ebx*16 + eax
    loop next_digit              ; while (--ecx)
    mov [ebp-4], ebx
    popad
    mov eax, [ebp-4]
    mov esp, ebp                ; Restore caller state
    pop ebp                    ; Restore caller state
    ret
        
        
buff_to_list:                  ; gets a pointer to string and

    push ebp                   ; returns a pointer to linked list
    mov ebp,esp                ; as suggested in class
    mov ebx, dword [ebp+8]
    pushad
    push ebx                   ; ebx holds pointer to input buffer
    call get_length
    add esp,4
    
    test eax, 1                ; checks if the number is odd or even
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

    push ebx                   ; ebx holds pointer to input buffer
    call get_length
    add esp,4
    
    mov ecx,eax                ; ecx = length of buffer
    
   
    
    add ebx,ecx
    .loop:
        
        sub ebx,2
        push ebx
        call to_numeric
        add esp,4
        
        mov edx, eax                  ; backup numeric value in another register before memory allocation
        
        ; at this point EAX holds the numeric representation of the rightmost two digits of the buffer
        
        pushad                        ; back up all general purpose registers
        push 1                        ; 1 byte * 5 (num of link elements) = 5 bytes
        push LINK_SIZE
        call calloc
        add esp, 8                    ; clean stack after calloc call
        mov [curr], eax               ; sets the curr pointer to calloc's return value
        popad
        
        mov eax, [curr]
        
        mov [eax], dl                     ; take the lower byte of edx and store it in the data of the link
        mov  dword [eax+next], 0          ; for now the next pointer is NULL
        
        
        cmp byte [firstFlag], 1
        jz .first

        mov esi, [prev]
        mov  dword [esi+next], eax           ; connect prev and current
        jmp .loop.continue_buff_to_list
        
        .first:
        
        mov [head], eax
        mov byte [firstFlag], 0   ; we've created the first link already, turns off the flag
        
.loop.continue_buff_to_list:
        
        mov [prev], eax          ; prepares prev for the next link assignment
        
        dec ecx                  ; decrement ecx in addition to the loop decremantation
        loop .loop, ecx
        
    ; returning from buff_to_list function
    
    popad
    mov eax,[head]
    push eax
    call trim_leading_zeros
    add esp,4
    mov esp, ebp                 ; Restore caller state
    pop ebp                      ; Restore caller state
    mov byte [firstFlag], 1      ; initializes the flag to 'true'
    ret
    
    

push_op:                         ; if the stack is full an error will be printed, otherwise the head will be added
    push ebp
    mov ebp,esp                    
    pushad
    mov ebx, [ebp+8]             ; get first argument (pointer to head of the linkedList)
    
    .checkNotFull:               ; checks if the OperandStack is full, if it is full an error will be printed
    cmp dword[counter],5         ;comparing between the stacksize (len) to counter.
    jnz .notFull
    pushad
    push fullStack_error
    call printf
    add esp,4
    ;push ebx               ;free list's memory
    ;call free_lst
    ;add esp,4
    popad                  ; Restore caller state
    mov esp,ebp            ; Restore caller state
    pop ebp                ; Restore caller state
    ret                    ; Restore caller state
    
    .notFull:
    mov eax,dword[counter]         
    mov edx,4
    imul edx
    add eax,op_stack           ;eax=opstack+(4*counter) eax points to the next avilable spot in the stack
    mov [op_top],eax         ;updating stack's top pointer
    mov dword [eax],dword ebx  ;placing the head of the list in the stack
    inc dword[counter]         ;counter now increase by 1
    popad                      ; Restore caller state
    mov esp, ebp               ; Restore caller state
    pop ebp                    ; Restore caller state
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
    popad
    popad                 ; Restore caller state
    mov esp,ebp           ; Restore caller state
    pop ebp               ; Restore caller state
    ret                            ; Restore caller state
    
    .notEmpty:       ;the stack is not empty, we will remove the first element and store it in eax
    mov eax,dword[counter]
    sub eax,1
    mov edx,4
    imul edx
    add eax,op_stack     ;eax = opstack+(4*(counter-1)). eax point to the top element at the stack 
    mov [op_top],eax         ;updating stack's top pointer
    mov eax,[eax] ;eax holds now the pointer to linkedlist of the top element at the stack
    mov [ebp-4],eax ;local variable holds now the pointer to linkedlist of the top element at the stack
    
    dec dword[counter]             ;counter decrease by 1    
    popad                     ; Restore caller state
    mov eax,[ebp-4] ; store the popped element pointer (to linkedlist) in eax 
    mov esp, ebp              ; Restore caller state
    pop ebp                   ; Restore caller state
    ret
    
; frees the memory occupied by the list given as parameter, using recursion
free_lst:

    push ebp
    mov ebp, esp
    pushad
    mov ebx, [ebp+8]
    
    cmp dword [ebx+next],0  ; base case - single link linked list
    jnz .not_a_single_link
    push ebx
    call free
    add esp,4
    jmp .done
    
    .not_a_single_link:     ; complex case
    push dword [ebx+next]
    call free_lst
    add esp,4
    push ebx
    call free
    add esp,4
    jmp .done
    
    .done:
    popad
    mov esp, ebp              ; Restore caller state
    pop ebp                   ; Restore caller state
    ret                       ; return
    

; [IN]: 2 linked list pinter representing numbers
; [OUT]: linked list representing the addition, stored in EAX
addLists:
    push ebp
    mov ebp,esp
    sub esp,4             ; local variable
    pushad
    mov ebx, [ebp+8]      ; EBX - pointer to 1'st list
    mov ecx, [ebp+12]     ; ECX - pointer to 2'nd list
    push ebx
    call getListLen
    add esp,4
    mov esi,eax           ; ESI holds the length of first list
    push ecx
    call getListLen
    add esp,4
    mov edi, eax          ; EDI holds the length of second list
    cmp esi, edi
    jle .edi_is_bigger_equal
    jmp .max_known
    .edi_is_bigger_equal:
    mov esi,edi
    
    .max_known:     ; at this point, ESI = MAX(list1.length, list2.length)
    
    ; prepares dummy link [0:0000]->NULL
    pushad
    push 1
    push LINK_SIZE
    call calloc
    ; mov [listHolder_1],eax  ;save pointer in order to free it
    add esp,8
    mov [ebp-4],eax
    popad
    mov edx,[ebp-4]         ; EDX -dummy link
    
    mov edi,0           ; EDI - carry value
    
    .loop:
    
    push edi     ; carry value
    push ebx     ; first list
    push ecx     ; second list
    call addLinks
    add esp,12   ; clean stack
    
    
    mov edi,[eax+next]
    movzx edi, byte [edi]     ; now edi hold the returend carry from 'addLinks'
    mov dword [eax+next],0
    
    cmp byte [firstFlag], 1
    jz .first

    jmp .loop.continue_add_lists
        
    .first:
    
    mov [head], eax
    mov byte [firstFlag], 0   ; we've created the first link already, turns off the flag
    mov dword [prev], eax
    jmp .not_first
        
    .loop.continue_add_lists:
    
    push edx
    mov edx,[prev]
    mov [edx+next], eax
    pop edx
    mov dword [prev], eax
    
    .not_first:
    
    cmp dword [ebx+next],0    ; list 1 has ended
    jz .list1_ended
    
    mov ebx,[ebx+next]        ; advance list1
    jmp .list1_not_ended
    
    .list1_ended:
    mov ebx,edx
    
    .list1_not_ended:
    
    cmp dword [ecx+next],0    ; list 2 has ended
    jz .list2_ended

    mov ecx,[ecx+next]        ; advance list2
    jmp .list2_not_ended
    
    
    .list2_ended:
    mov ecx,edx
    
    .list2_not_ended:
    
    dec esi
    cmp esi,0
    jnz .loop
    
    cmp edi,0
    jz .done
    
    ; creating new link for (non empty) carry outside loop
    
    push 1
    push LINK_SIZE
    call calloc
    mov [listHolder_2],eax
    add esp,8
    mov edx, edi
    mov byte [eax], dl
    mov esi,[prev]
    mov [esi+next], eax
    
    .done:
    
    popad
    mov esp,ebp
    pop ebp
    mov eax,[head]
    ;push dword[listHolder_1]      ;free memory
    ;call free_lst
    ;add esp,4
    ;push dword[listHolder_2]
    ;call free_lst
    ;add esp,4
    mov byte [firstFlag], 1
    ret
    
    
; auxillary function to addLists
; [IN]: 2 signle links and a carry stored as a value
; [OUT]: linked list with 2 links (sum link and a carry link)
addLinks:
    push ebp
    mov ebp,esp
    sub esp,4 
    pushad
    mov dword [curr],0
    xor eax,eax              ; clear eax
    mov eax, [ebp+8]         ; load first argument (pointer to 1'st link)
    mov ebx, [ebp+12]        ; load second argument (pointer to 2'nd link)
    mov ecx, [ebp+16]        ; load third argument (value of carry)
                   ; make place for local variable (pointer to result list)
    movzx eax, byte [eax]    ; dereference first pointer
    movzx ebx, byte [ebx]    ; dereference second pointer
    add eax, ebx             ; eax = eax+ebx
    add eax, ecx             ; eax = eax+ecx (carry)
    mov edx, eax             ; backup eax before calloc call
    pushad
    push 1
    push LINK_SIZE
    call calloc
    add esp,8
    mov [curr], eax               ; sets the curr pointer to calloc's return value
    popad
    mov eax, [curr]
    mov byte [eax], dl       ; store sum value in first link
    push edx
    mov esi, eax             ; backup first link pointer
    push 1
    push LINK_SIZE
    call calloc              ; eax gets another pointer to allocated memory
    add esp,8
    pop edx
    mov byte [eax], dh
    mov dword [esi+next], eax
    mov [ebp-4], esi
    popad
    mov eax, [ebp-4]
    mov esp, ebp
    pop ebp
    ret
    
; [IN]: a pointer to a linked list
; [OUT]: length of the list
getListLen:
    push ebp
    mov ebp, esp
    sub esp,4
    pushad
    mov ebx, [ebp+8]
    xor ecx,ecx
    
    cmp dword [ebx+next], 0
    jnz .not_a_signle_link
    add ecx,1
    jmp .done
    
    .not_a_signle_link:
    add ecx,1
    mov edx, [ebx+next]
    push edx
    call getListLen
    add esp,4
    add ecx,eax
    jmp .done
    
    .done:
    mov [ebp-4],ecx
    popad
    mov eax, [ebp-4]
    mov esp, ebp            ; Restore caller state
    pop ebp                 ; Restore caller state
    ret     
    
print_op:
    push ebp
    mov ebp, esp
    pushad
    mov ebx, [ebp+8]   ; ebx - pointer to list


    
    cmp dword [ebx+next], 0
    jnz .not_a_signle_link
    
    .single_link:
    
    movzx ebx, byte [ebx]
    print_and_flush ebx, format_string_hex_no_leading
    jmp .done
    
    .not_a_signle_link:
    mov edx, [ebx+next]  ; edx point to the rest of the list
    push edx
    call print_op
    add esp,4
    pushad
    movzx edx, byte [ebx]
    print_and_flush edx, format_string_hex
    popad
    jmp .done
    
    .done:
    
    popad
    mov esp,ebp
    pop ebp
    ret

; [IN]: a pointer to a operand linked list
; [OUT]: a pointer to a result list with the value of number of set bits in input list
countSetBits:
    push ebp
    mov ebp,esp
    sub esp,4
    pushad
    mov ebx, [ebp+8]    ; Leave space for local var on stack
    
    cmp dword [ebx+next], 0
    jnz .not_a_signle_link
    
    .single_link:
    
    push ebx
    call countSetBitsInLink
    add esp,4
    mov [ebp-4],eax
    jmp .done
    
    .not_a_signle_link:
    
    push ebx
    call countSetBitsInLink
    add esp,4            
    mov ecx, eax         ; ecx is list1 result
    mov edx, [ebx+next]  ; edx point to the rest of the list
    push edx
    call countSetBits
    add esp,4            ; eax is list2 result
    push ecx
    push eax
    call addLists
    add esp,8
    mov [ebp-4],eax
    
    .done:
    
    popad
    mov eax, [ebp-4]
    mov esp,ebp
    pop ebp
    ret

; auxillary function for countSetBits from above
; [IN]: a pointer to a single link
; [OUT]: a pointer to a reslt list with the value of number of set bits in input list
countSetBitsInLink:
    push ebp
    mov ebp,esp
    sub esp,4             ; Leave space for local var on stack
    pushad
    mov ebx, [ebp+8]
    
    movzx eax, byte [ebx]
    mov ecx,0              
    xor edx,edx            ; zero edx
    
    .not_done_yet:
    cmp eax,0
    je .done
    mov edx,eax            
    shr eax,1              
    and edx,1h             
    cmp edx,0h
    jz .not_done_yet  
    
    inc ecx
    jmp .not_done_yet
    
    .done:                      ;register ecx will now hold hamming weight
        
    ; creating the result link
    push ecx
    push 1
    push LINK_SIZE
    call calloc              ; eax gets another pointer to allocated memory
    add esp,8
    pop ecx
    mov byte [eax], cl
    mov [ebp-4], eax
    
    popad
    mov eax, [ebp-4]
    mov esp,ebp
    pop ebp
    ret
    
;gets top's stack link as arg ( we dont handle errors here)
duplicate:
    push ebp
    mov ebp,esp
    sub esp,8             ; local variable
    pushad
    mov ebx, [ebp+8]      ; EBX - pointer to top stack list
    push ebx
    call getListLen
    add esp,4
    mov ecx,eax           ; Ecx holds the length of first list
    
    pushad
    push 1                 ;preparing the first link of the new linked list
    push LINK_SIZE
    call calloc
    add esp,8
    mov [ebp-4],eax        ; the local variable holds now the "head" of the new list
    mov [prev],eax         ; the "prev" label points now to the new list's first element
    popad
    
    mov dl,byte[ebx]       ;copy original's list value at the current link
    mov edi,dword[ebp-4]
    mov byte[edi],dl
    mov dword[edi+next],0   ;next link point to zero right now
    
    mov ebx,dword[ebx+next]   ; forward ebx to point the next original link 
    

    sub ecx,1              ; because we handled the first link
    
    .loop:
    cmp ecx,0
    jz .done
    dec ecx ;if not done dec ecx 
     
    pushad
    push 1
    push LINK_SIZE
    call calloc
    add esp,8
    mov [ebp-8],eax           ;local var holds eax. 
    popad
    mov eax,[ebp-8]           ;restore eax
    
    mov dl,byte[ebx]        ;copy original's list value to the current link
    mov byte[eax],dl
    
    mov esi,[prev]         ;linking the prev link to current link
    mov dword[esi+next],dword eax
    
    mov ebx,dword[ebx+next]   ; forward ebx to be the next original link 
  
    mov [prev],eax         ; the "prev" label points now to the new list's first element
 
    jmp .loop
    
    .done:
    mov eax,[prev]
    mov dword[eax+next],0       ;updating the last link to point to null
    popad
    mov eax,[ebp-4]
    mov esp,ebp
    pop ebp
    ret

mulLinks:
    push ebp
    mov ebp,esp
    pushad
    mov eax, [ebp+8] ; arg0 - first link
    mov ebx, [ebp+12] ; arg1 - second link
    movzx eax, byte [eax]
    movzx ebx, byte [ebx]
    imul ebx         ; edx = eax * ebx
    mov edx, eax
    
    ; creating first link
    
    pushad
    push 1
    push LINK_SIZE
    push edx
    call calloc      ; eax - pointer to first result link
    pop edx
    add esp,8
    mov dword [head], eax
    mov byte [eax], dl
    popad
    
    ; creating second link
    
    pushad
    push 1
    push LINK_SIZE
    push edx
    call calloc
    pop edx
    add esp,8
    mov byte [eax], dh
    
    
    mov ecx, [head]
    mov [ecx+next], eax
    popad
    
    
    popad
    mov eax,[head]
    push eax
    call trim_leading_zeros
    add esp,4
    mov esp,ebp
    pop ebp
    ret
    
; [IN]: link (arg0) , list(arg1)
; [OUT]: link * list
mulLinkByList:
    push ebp
    mov ebp, esp
    sub esp,4
    pushad
    
    mov ebx, [ebp+8]    ; ebx - pointer to list
    mov ecx, [ebp+12]   ; ecx - pointer to link
    
    
    cmp dword [ebx+next], 0
    jnz .not_a_signle_link
    
    .single_link:
    
    push ecx
    push ebx
    call mulLinks
    add esp,8
    mov [head] ,eax
    jmp .done
    
    .not_a_signle_link:
    
    push ecx
    push ebx
    call mulLinks
    add esp,8
    mov edx, eax        ; edx -pointer to [first(list) * link]
    
    mov ebx, [ebx+next]
    push ecx
    push ebx
    call mulLinkByList
    add esp,8           
    mov esi, eax        ; esi - rest(list)*link
    
    ; creating empty link [00..0] to truncate to result list
    
    pushad
    push 1
    push LINK_SIZE
    call calloc
    add esp,8
    mov [ebp-4], eax
    popad
    mov eax, [ebp-4]
    mov [eax+next],esi
    mov byte [eax], 0
    
    push eax
    push edx
    call addLists
    add esp,8
    mov [head],eax
    
    .done:
    
    popad
    mov eax, [head]
    mov esp, ebp
    pop ebp
    ret
 
; [IN]: 2 pointers to lists
; [OUT]: a pointer to a list of their multiplication
mulListByList:
    push ebp
    mov ebp,esp
    sub esp,4
    pushad
    
    mov ebx, [ebp+8]    ; ebx - pointer to 1'st list
    mov ecx, [ebp+12]   ; ecx - pointer to 2'nd list
    
    
    cmp dword [ebx+next], 0   ; base case - 1'st list is a link
    jnz .1st_list_is_not_a_link
    
    .1st_list_is_a_link:      ; we will use the function from above
    
    push ebx
    push ecx
    call mulLinkByList
    add esp,8
    mov [head] ,eax
    jmp .done
    
    .1st_list_is_not_a_link:  ; complex case
    
    push ebx
    push ecx
    call mulLinkByList
    add esp,8
    mov edx, eax        ; edx -pointer to [first(list1) * list2]
    
    mov ebx, [ebx+next]
    push ecx
    push ebx
    call mulListByList
    add esp,8           
    mov esi, eax        ; esi - rest(list2)*list2
    
    ; creating empty link [00..0] to truncate to result list
    
    pushad
    push 1
    push LINK_SIZE
    call calloc
    add esp,8
    mov [ebp-4], eax
    popad
    mov eax, [ebp-4]
    mov [eax+next],esi
    mov byte [eax], 0
    
    push eax
    push edx
    call addLists
    add esp,8
    mov [head],eax
    
    .done:
    
    popad
    mov eax,[head]
    mov esp,ebp
    pop ebp
    ret
 
; [IN]: a pointer to a link
; [OUT]: 2^link
two_power_link:
    push ebp
    mov ebp,esp
    sub esp,4
    pushad
    
    mov ebx, [ebp+8]    
    movzx ecx, byte [ebx]  ; ecx - the data in the arg link
          
    cmp ecx,1    ; if the exponent is 1 then we're done
    jnz .cont
    mov byte [ebx], 2
    mov edi, [ebp+8]
    mov [head], edi
    jz .done
    
    .cont:
    
    mov ebx, [ebp+8]    

    cmp ecx,0 ; if the exponent is 0 then we return 1
    jnz .regular_case
    mov byte [ebx],1
    mov [head], ebx
    jz .done
    
    .regular_case:
    
    mov ebx,2    ; 2^1
    
    pushad
    push 1
    push LINK_SIZE
    call calloc
    add esp,8
    mov [ebp-4], eax
    popad
    mov eax, [ebp-4]
    mov dword [eax+next],0
    mov byte [eax], bl
    mov dword [head], eax
    
    dec ecx
    
    .loop:
    mov ebx,2    ; 2^1,  like doing shl one time
    
    pushad
    push 1
    push LINK_SIZE
    call calloc
    add esp,8
    mov [ebp-4], eax
    popad
    mov eax, [ebp-4]
    mov dword [eax+next],0
    mov byte [eax], bl
    
    mov esi, [head]
    push esi
    push eax
    call mulListByList
    add esp,8
    mov dword [head],eax
    
    loop .loop,ecx
    
    .done:
    
    popad
    mov eax, [head]
    mov esp,ebp
    pop ebp
    ret


; [IN]: a pointer to a list
; [OUT]: 2^list
two_power:
    push ebp
    mov ebp,esp
    pushad
    
    mov ebx, [ebp+8]
    
    cmp dword [ebx+next], 0
    jnz .not_a_signle_link
    
    .single_link:
    
    push ebx
    call two_power_link
    add esp,4
    mov [head] ,eax
    jmp .done
    
    .not_a_signle_link:
    
    push ebx
    call two_power_link
    add esp,4
    mov edx, eax        ; edx -pointer to 2^first(list)
    
    mov ebx, [ebx+next]  ; advance list
    push ebx
    call two_power
    add esp,4         
    mov esi, eax        ; esi - 2^rest(list)
    
    push esi
    push edx
    call mulListByList
    add esp,8
    mov [head],eax
    
    .done:
    
    popad
    mov eax, [head]
    mov esp,ebp
    pop ebp
    ret
    
; [IN]: a pointer to a input list
; [OUT]: if Y<=200 then eax=0 otherwise eax ==1
checkYle200:
    push ebp
    mov ebp,esp
    sub esp,4             ;local var will hold the result
    pushad
    mov ebx,[ebp+8]    ;ebx holds pointer to Y list

    ; creating a link with data value of C8 hex (200 dec) for comparison
    
    pushad
    push 1
    push LINK_SIZE
    call calloc
    add esp,8
    mov [ebp-4], eax
    popad
    mov eax, dword [ebp-4]
    mov dword [eax+next],0
    mov byte [eax], 0xC8    ; eax - link [C8:0000]
    
    push eax
    push ebx  
    call cmpLists ; will return 1 iff ebx list > eax list
    add esp,8
    cmp eax,1
    jz .above_200
    mov dword [ebp-4],0
    jmp .done
    
    .above_200:
    mov dword [ebp-4],1
    jmp .done
    
    .done:
    
    popad
    mov eax,dword [ebp-4]
    mov esp,ebp
    pop ebp
    ret
    
; [IN]: X, Y (2 pointers to lists)
; [OUT]: a pointer to a list with value: X*2^Y
mul_and_exp:
    push ebp
    mov ebp,esp
    sub esp,4
    pushad
    
    mov ebx, [ebp+8]  ; Y
    mov ecx, [ebp+12] ; X
    
    push ebx
    call two_power  ; eax = 2^Y
    add esp,4      
    push ecx
    push eax
    call mulListByList ; eax = X*2^Y
    add esp,8
    mov [ebp-4], eax
    
    popad
    mov eax,[ebp-4]
    push eax
    call trim_leading_zeros
    add esp,4
    mov esp,ebp
    pop ebp
    ret
  
; [IN]: 2 pointers to lists
; [OUT]: 1 - list1>list2 , -1 - list2>list1 , 0 - list1=list2

; [IN]: a pointer to a list
; [OUT]: a pointer to the reversed list
reverseList: 
    push ebp
    mov ebp,esp
    pushad
    
    mov ebx, [ebp+8]
    
    cmp dword [ebx+next], 0
    jnz .not_a_signle_link
    
    .single_link: ; signle link list is already reversed
    mov [head], ebx
    jmp .done
    
    .not_a_signle_link:
    
    mov edx, [ebx+next] ; edx - pointer to the rest of the list
    mov dword [ebx+next],0  ; disconnects this link from the list
    push edx
    call reverseList    ; eax - the rest of the list, reversed
    add esp,4
    mov [head],eax
    push eax
    call getListLen
    add esp,4
    mov ecx, eax        ; ecx is rest(list).length
    
    dec ecx
    cmp ecx,0
    jz .after_loop  ; in case of single link
    
    mov edx, [head]
    .loop:
    mov edx, [edx+next] ; advances to the eds of the reversed list
    loop .loop, ecx
    
    .after_loop:
    
    ; now edx is a pointer to the last link of the rest of the reversed list
    
    mov [edx+next], ebx
    
    .done:
    
    popad
    mov eax, [head]
    mov esp,ebp
    pop ebp
    ret
    
 ;the function gets an link pointer and trim his leading zeros
trim_leading_zeros:
    push ebp
    mov ebp,esp
    pushad
    mov ebx,dword[ebp+8]         ;ebx holds link cur pointer

    ;<reverse list>
    push 0
    push ebx
    call reverseList
    add esp,8
    mov ebx,eax          ;ebx holds now the reversed list head
    mov edx,ebx
    mov [head],ebx        ;head is the reversed list head
    ;<done reverseList>
    
    ;<trim>
    push ebx
    call getListLen
    add esp,4
    mov ecx,eax       ;eax holds list length
    
    .loop:
    cmp ecx,0
    jz .re_reverselist
    
    cmp byte[ebx],0
    jz .cont_next
    
    cmp edx,ebx      ;check if prev is cur
    jz .re_reverselist
    
    mov dword[edx+next],0
    ;push dword[head]
    ;call free_lst
    ;add esp,4
    mov [head],ebx
    jmp .re_reverselist
    
    .cont_next:
    dec ecx
    mov edx,ebx   ;the prevlink
    mov dword[head],edx
    mov ebx,[ebx+next]
    jmp .loop
    ;<done trim>
    
    .re_reverselist:
    ;<re-reverse the list>
    push 0
    push dword[head]
    call reverseList
    add esp,8
    mov [head],eax
    ;<done re-reverse>
    popad
    mov eax,[head]
    mov esp,ebp
    pop ebp
    ret   
    
printNumOfOp:
 
    push ebp
    mov ebp,esp
    pushad
    
    mov ebx, dword [ebp+8]
    print_and_flush ebx, format_string_hex_no_leading
    
    popad
    mov esp,ebp
    pop ebp
    ret
    
clearstack:
    
    push ebp
    mov ebp,esp
    pushad
    
    .loop:
    cmp dword[counter],0
    jz .finish_cleaning
    
    mov eax,[op_top]
    ;push dword[eax]
    ;call free_lst
    ;add esp,4
    sub dword[op_top],4
    dec dword [counter]
    jmp .loop
    
    .finish_cleaning:
    popad
    mov esp,ebp
    pop ebp
    ret 

; [IN]: 2 pointer to lists, list1 (secondly pushed) and list2 (firstly pushed)
; [OUT]: 1 if list1>list2, -1 if list2>list1 and 0 if equal
cmpLists:
    push ebp
    mov ebp,esp
    sub esp,4   ; make room for 2 local variables
    pushad
    
    ; first, clone the lists because we will change them
    
    mov esi, [ebp+8]   ; esi - list1
    push esi
    call duplicate
    add esp,4
    mov esi,eax
    
    mov edi, [ebp+12]  ; edi - list2
    push edi
    call duplicate
    add esp,4
    mov edi,eax
    
    
    push esi
    call getListLen
    add esp,4
    mov [ebp-4], eax  ; [ebp-4] - list1.length
    push edi
    call getListLen ; eax - list2.length
    mov ecx,eax
    add esp,4
    
    cmp eax, [ebp-4]
    ja .list2_is_bigger
    jl .list1_is_bigger
    
    ; if reached here so lists are of same LENGTH.
    ; will now get the reversed lists
    
    .lists_same_length:
    
    push esi
    call reverseList
    add esp,4
    mov esi,eax
    push edi
    call reverseList
    add esp,4
    mov edi,eax
    
    xor ebx,ebx
    xor edx,edx
    
    .loop:
    
    movzx ebx, byte [esi] ; ebx = current list1 byte
    movzx edx,  byte [edi] ; edx = current list2 byte
    
    cmp  ebx, edx
    ja .list1_is_bigger
    jl .list2_is_bigger
    
    mov esi, [esi+next]   ; advance list1
    mov edi, [edi+next]   ; advance list2
    
    loop .loop,ecx
    
    ; if reached here so lists are EQUAL
    mov dword [ebp-4],0
    jmp .done
    
    .list1_is_bigger:
    mov dword [ebp-4],1
    jmp .done
    
    .list2_is_bigger:
    mov dword [ebp-4],-1
    jmp .done
    
    .done:
    
    
    popad
    mov eax,[ebp-4]
    mov esp,ebp
    pop ebp
    ret

; [IN]: a pointer to a list
; [OUT]: a pointer to the right-shifted list
shiftRightList:
    push ebp
    mov ebp,esp
    sub esp,4   ; room for local var
    pushad
    
    mov ebx, [ebp+8]  ; ebx = pointer to list
    mov [ebp-4],ebx   ; saving the pointer in the local var
    push ebx
    call getListLen
    add esp,4
    
    mov ecx, eax    ; ecx = length of list
    
    ; cloning list
    
    push ebx
    call duplicate
    add esp,4
    mov ebx,eax     
    
    push ebx
    call reverseList
    add esp,4
    mov ebx,eax     ; now ebx is a pointer to the cloned reversed list
    mov [ebp-4],ebx
    
    
    mov esi,0       ; esi is the remainder indicator. ecx=1 -> add remainder
    
    .loop:
    
    xor eax,eax
    movzx eax,byte [ebx]  ; backup of old link data
    
    movzx edx, byte [ebx]
    shr edx,1
    mov byte [ebx],dl
    
    cmp esi,1
    jnz .dont_turn_on_msb
    add edx,0x80 ; turning on the msb by adding 0x80=128
    mov byte [ebx],dl
    movzx edx, byte [ebx]
    
    .dont_turn_on_msb:
    
    movzx edi,al
    test edi,1 ;checks if the link's data is odd or even
    
    jz .set_esi_to_0
    mov esi,1 ; data is odd then set esi accordingly
    jmp .esi_already_set
    
    .set_esi_to_0:
    mov esi,0 ; turn off the flag
    
    .esi_already_set:
    
    mov ebx, [ebx+next] ; advances list pointer
    loop .loop, ecx
    
    .done:
    
    push dword [ebp-4]
    call reverseList
    add esp,4
    mov [ebp-4],eax
    
    popad
    mov eax, [ebp-4]
    push eax
    call trim_leading_zeros
    add esp,4
    mov esp,ebp
    pop ebp
    ret

; [IN]: 2 pointers to 2 lists, X and Y
; [OUT]: a pointer to the list X/(2^Y)
mul_and_exp_oppo:
    push ebp
    mov ebp,esp
    sub esp,12   ; room for 3 local vars
    pushad
    
    mov esi, [ebp+8]   ; esi - Y
    mov edi, [ebp+12]  ; edi - X
    
    mov dword [ebp-8],edi
    
    cmp byte [esi],0 ; if it's 2^0 (do not shift at all)
    jz .done
    
     ; creating signle link [1:0000] - the incrementing list [ebp-4]
    
    pushad
    push 1
    push LINK_SIZE
    call calloc
    add esp,8
    mov [ebp-4], eax
    popad
    mov eax, dword [ebp-4]
    mov dword [eax+next],0
    mov byte [eax], 0
    
    ; 1 incrementor link [ebp-12]
    
    pushad
    push 1
    push LINK_SIZE
    call calloc
    add esp,8
    mov [ebp-12], eax
    popad
    mov eax, dword [ebp-12]
    mov dword [eax+next],0
    mov byte [eax], 1
    
    .loop:
    
    push edi
    call shiftRightList
    add esp,4
    mov edi,eax
    mov dword [ebp-8], edi
    
    push dword [ebp-12] ; pushes incrementor
    push dword [ebp-4]  ; pushes incrementing
    call addLists
    add esp,8
    mov dword [ebp-4],eax ; updating incrementing
    
    push dword [ebp-4] ; pushes incrementing list
    push esi           ; pushes Y
    call cmpLists      ; and comparing them
    add esp,8
    cmp eax,0
    jnz .loop
    
    .done:

    popad
    mov eax, [ebp-8]
    mov esp,ebp
    pop ebp
    ret
    
; [IN]: a pointer to a list X
; [OUT]: a pointer to the square root list of X
square_root:
    push ebp
    mov ebp,esp
    sub esp,12   ; room for 3 local vars
    pushad
    
    mov esi, [ebp+8]   ; esi - X
        
    ; [ebp-4] - signle link [0:0000] - the factor link 
    
    pushad
    push 1
    push LINK_SIZE
    call calloc
    add esp,8
    mov [ebp-4], eax
    popad
    mov eax, [ebp-4]
    mov dword [eax+next],0
    mov byte [eax], 0
    
    ; [ebp-12] - 1 incrementor link 
    
    pushad
    push 1
    push LINK_SIZE
    call calloc
    add esp,8
    mov [ebp-12], eax
    popad
    mov eax, [ebp-12]
    mov dword [eax+next],0
    mov byte [eax], 1

    
    .loop:
    
    push dword [ebp-4]
    push dword [ebp-4]
    call mulListByList
    add esp,8
    push esi
    push eax
    call cmpLists
    add esp,8
    cmp eax,1
    jz .dec_and_done  ; decrement and done
    cmp eax,0
    jz .done  ; completely done
    
    ; esle
    push dword [ebp-12]
    push dword [ebp-4]
    call addLists
    add esp,8
    mov [ebp-4],eax
    
    jmp .loop
    
    .dec_and_done:
    
    ; decrementing the factor link data byte by one
    
    mov edx, dword [ebp-4]
    movzx ecx, byte [edx]
    dec ecx
    mov byte [edx],cl
    
    .done:
    
    popad
    mov eax,[ebp-4]
    mov esp,ebp
    pop ebp
    ret
