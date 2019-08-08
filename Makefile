# dummy
ls:
	ls

test:
	ruby ./pettycc.rb
	./test.sh

clean:
	rm -f tmp*

.PHONY: test clean
