all:
	cc -fPIC -c machine.c
	ld -lm -shared machine.o -o machine.so
	sbcl	--eval "(require 'generator)" \
		--eval "(waterfall::save-waterfall)" \
		--eval "(forest::save-forest)" \
		--eval "(save-swamp)" \
		--eval "(sb-ext:quit)"
	cp *procedural.lua *edit.lua ../lariad/script/

clean:
	rm -f machine.so machine.o *.fasl *procedural.lua *edit.lua
