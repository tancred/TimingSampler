CC = clang
CFLAGS = -Wall -fobjc-arc
PROGS = timing

default: $(PROGS)
	./timing

timing: timing.o
	$(CC) -o $@ $^ -framework Foundation

timing.o: timing.m

%.o: %.m
	$(CC) -c $(CFLAGS) $<

clean:
	rm -f $(PROGS)
	rm -f *.o
