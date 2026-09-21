CC ?= cc
CFLAGS ?= -std=c89 -pedantic -Wall -Wextra -Werror -O2
PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
MANDIR ?= $(PREFIX)/share/man/man1

.PHONY: all clean test install uninstall

all: pathcheck

pathcheck: pathcheck.c
	$(CC) $(CFLAGS) -o $@ pathcheck.c

test: pathcheck
	sh tests/test.sh ./pathcheck

install: pathcheck
	mkdir -p $(DESTDIR)$(BINDIR) $(DESTDIR)$(MANDIR)
	cp pathcheck $(DESTDIR)$(BINDIR)/pathcheck
	cp man/pathcheck.1 $(DESTDIR)$(MANDIR)/pathcheck.1

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/pathcheck
	rm -f $(DESTDIR)$(MANDIR)/pathcheck.1

clean:
	rm -f pathcheck
