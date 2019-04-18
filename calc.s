section .rodata
    format_string_hex : db "%02X",0
    format_string_hex_no_leading : db "%01X",0
    format_string_s : db "%s",0
    format_string_d: db "%d",0
    arrow_symbol : db " -> ",0             ; DELETE BEFORE SUBMMISION
    end_str: db "END",10, 0
    newline: db 10,0
    fullStack_error : db "Error: Operand Stack Overflow",10,0
    emptyStack_error: db "Error: Insufficient Number of Arguments on Stack",10,0
    prompt: db "calc: ",0
    input_length equ 81
    LINK_SIZE equ 5
    


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

    pushad
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
    
    jmp .push_operand      ; default case

    
.addition:

    call pop_op
    push eax
    call pop_op
    push eax
    call addLists
    add esp,8
    push eax
    call push_op
    add esp,4
    
    jmp get_input

.pop_and_print:

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
    jmp get_input

.duplicate:

    jmp get_input

.mul_and_exp:

    jmp get_input

.mul_and_exp_oppo:

    jmp get_input

.number_of_1_bits:   

    call pop_op
    push eax
    call countSetBitsInLink
    add esp,4
    push eax
    call push_op
    add esp,4
    
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
    
    
print_list:                 ; DELETE THIS FUNCTION BEFORE SUBMMISION
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
    
    cmp dword [ebx+next], 0
    jz done
    mov ebx,dword [ebx+next]      ; makes ebx points to next link
    jmp printing_loop
    
    done:
    
    print_and_flush end_str, format_string_s
    
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
    popad                  ; Restore caller state
    mov esp,ebp            ; Restore caller state
    pop ebp                ; Restore caller state
    ret                    ; Restore caller state
    
    .notFull:
    mov eax,dword[counter]         
    mov edx,4
    imul edx
    add eax,op_stack           ;eax=opstack+(4*counter) eax points to the next avilable spot in the stack
    
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
    
    mov eax,[eax] ;eax holds now the pointer to linkedlist of the top element at the stack
    mov [ebp-4],eax ;local variable holds now the pointer to linkedlist of the top element at the stack
    
    dec dword[counter]             ;counter decrease by 1    
    popad                     ; Restore caller state
    mov eax,[ebp-4] ; store the popped element pointer (to linkedlist) in eax 
    mov esp, ebp              ; Restore caller state
    pop ebp                   ; Restore caller state
    ret
    
; frees the memory occupied by the list given as parameter, using recursion
free_list:

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
    call free_list
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
    
    
linkToNumber: ; converting the linked list to number (decimal). the number will be restored in eax
    push ebp
    mov ebp,esp
    sub esp,4                     ; space for local variable -> the accumulated number .
    pushad
    mov ebx, [ebp+8]              ; get first argument (pointer to head of the linkedList)
    mov edx,1                      ;edx will be the multipler value. starting from 1 and increase *256 each iteration
    mov dword[ebp-4],0                  ;accumulated variable initialized to 0

    .loop:

    movzx eax,byte[ebx]             ; eax holds now the number stored in the first 8 bits (the first byte) of the link
    push edx
    imul edx                      ; now eax= eax*edx
    pop edx
    add dword [ebp-4],dword eax           ;add the result to accumulated
   
    
    cmp dword[ebx+1],0            ; checks if it is the last link in the linkedlist
    jz .finish 
    ;if not then
    mov ebx,dword [ebx+1]         ;ebx points now to the next element in the list
    mov eax,256
    imul edx 
    mov edx,eax                  ;edx holds now the next multiplier
    jmp .loop                    ;move to the next link
    
    .finish:
    
    popad                     ; Restore caller state
    mov eax,[ebp-4]           ;store the accumulated number in eax 
    mov esp, ebp              ; Restore caller state
    pop ebp                   ; Restore caller state
    ret
    

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
    pushad
    
    
    popad
    mov esp,ebp
    pop ebp
    ret

; auxillary function for countSetBits from above
; [IN]: a pointer to a single link
; [OUT]: a pointer to a reslt list with the value of number of set bits in input list
countSetBitsInLink:
    push ebp
    mov ebp,esp
    sub esp,4                     ; Leave space for local var on stack
    pushad
    mov ebx, [ebp+8]
    
    movzx eax, byte [ebx]
    mov ecx,0              ;is the counter register
    xor edx,edx            ;is done to make edx 0, you can also do mov edx,0
    .notDoneWithNumber:
    cmp eax,0
    je .done
    mov edx,eax            ;edx is here a compare register, not nice, but it works
    shr eax,1              ;we push all the bits one place to the right, bits at position 1 will be "pushed out of the byteword"
    and edx,1h             ;make sure we only get, wether the last bit is set or not(thats called bitmaking) 
    cmp edx,0h
    jz .notDoneWithNumber   ;if the found value is a zero we can skip the inc of the count register
    inc ecx
    jmp .notDoneWithNumber
    
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
