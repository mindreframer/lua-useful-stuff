CC = gcc
CFLAGS = -W -Wall -pedantic -O2 #-g

# Linux
INCFLAGS = -I/usr/include/lua5.1
LIBFLAGS = -fPIC -shared
# MacOSX
#INCFLAGS = -I/sw/include
#LIBFLAGS = -bundle -undefined dynamic_lookup

RM = rm -f

LIBS = rng.so cdf.so binomial.so queue.so stack.so

all : $(LIBS)

rng.so : ranlib.c mt.c rng.c
	$(CC) $(CFLAGS) $(LIBFLAGS) $(INCFLAGS) -o $@ $^

cdf.so : dcdflib.c ipmpar.c cdf.c
	$(CC) $(CFLAGS) $(LIBFLAGS) $(INCFLAGS) -o $@ $^

binomial.so : binomial.c
	$(CC) $(CFLAGS) $(LIBFLAGS) $(INCFLAGS) -o $@ $^

queue.so : queue.c
	$(CC) $(CFLAGS) $(LIBFLAGS) $(INCFLAGS) -o $@ $^

stack.so : stack.c
	$(CC) $(CFLAGS) $(LIBFLAGS) $(INCFLAGS) -o $@ $^

clean :
	$(RM) $(LIBS)
