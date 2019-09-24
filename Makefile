# dummy
ls:
	ls

test:
	ruby ./pettycc.rb tests.c > tmp.s
	gcc -static -no-pie -o tmp tmp.s
	./tmp

clean:
	rm -f tmp*

.PHONY: test clean
