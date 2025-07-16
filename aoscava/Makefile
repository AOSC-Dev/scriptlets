DESTDIR ?=
PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

.PHONY: install
install: $(BINDIR)/aoscava

$(BINDIR)/aoscava: aoscava
	install -Dvm755 $< $@

.PHONY: dev
dev:
	ln -svf $$(pwd)/aoscava $(BINDIR)/aoscava
