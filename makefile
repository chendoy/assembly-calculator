all: calc

calc: calc.o		
	gcc -m32 -Wall -g calc.o -o calc
	rm -f *.o
	
calc.o: calc.s
	nasm -f elf calc.s -g -o calc.o

.PHONY: clean
clean:
	rm -f *.o calc
	
	
