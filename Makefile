# Install ok.sh; build the website/README; run the tests.

PROGRAM ?= ok.sh
DESTDIR ?= $(HOME)
DESTDIRB ?= /

.PHONY: dev
dev : .image
	docker run -it --rm -v $$PWD:/oksh oksh

.image :
	docker build -t oksh .
	touch $@

install : $(PROGRAM)
	cp $(PROGRAM) "$(DESTDIR)/bin/"
	chmod 755 "$(DESTDIR)/bin/$(PROGRAM)"
	cp $(PROGRAM) "$(DESTDIRB)bin/"
	chmod 777 "$(DESTDIRB)bin/$(PROGRAM)"

.PHONY: test
test :
	make -C tests all

.PHONY: shellcheck
shellcheck :
	make -C tests shellcheck

readme : $(PROGRAM)
	@ printf '<!---\nThis README file is generated. Changes will be overwritten.\n-->\n' > README.md
	@ printf '[![Build Status](https://travis-ci.org/whiteinge/ok.sh.svg?branch=master)](https://travis-ci.org/whiteinge/ok.sh)\n\n' >> README.md
	OK_SH_MARKDOWN=1 $(PROGRAM) help >> README.md

.PHONY: preview
preview :
	@ pandoc -f gfm < README.md > README.html

.PHONY: posixdocs
posixdocs:
	wget -np --mirror https://pubs.opengroup.org/onlinepubs/9699919799/
