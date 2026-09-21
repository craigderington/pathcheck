# SPDX-License-Identifier: GPL-3.0-or-later
CC ?= cc
CFLAGS ?= -std=c89 -pedantic -Wall -Wextra -Werror -O2
VERSION = 0.3.0
PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
MANDIR ?= $(PREFIX)/share/man/man1

.PHONY: all clean test install uninstall dist

all: pathcheck

pathcheck: pathcheck.c
	$(CC) $(CFLAGS) -o $@ pathcheck.c

test: pathcheck
	sh tests/test.sh ./pathcheck

install: pathcheck
	mkdir -p "$(DESTDIR)$(BINDIR)" "$(DESTDIR)$(MANDIR)"
	install -m 755 pathcheck "$(DESTDIR)$(BINDIR)/pathcheck"
	install -m 644 man/pathcheck.1 "$(DESTDIR)$(MANDIR)/pathcheck.1"

uninstall:
	rm -f "$(DESTDIR)$(BINDIR)/pathcheck"
	rm -f "$(DESTDIR)$(MANDIR)/pathcheck.1"

clean:
	rm -f pathcheck

dist:
	python3 scripts/dist.py $(VERSION)
