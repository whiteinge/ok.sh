# Install ok.sh; build the website/README; run the tests.

PROGRAM ?= ok.sh
DESTDIR ?= $(HOME)
DESTDIRB ?= /

install : $(PROGRAM)
	cp $(PROGRAM) "$(DESTDIR)/bin/"
	chmod 755 "$(DESTDIR)/bin/$(PROGRAM)"
	cp $(PROGRAM) "$(DESTDIRB)bin/"
	chmod 777 "$(DESTDIRB)bin/$(PROGRAM)"

test:
	make -C tests all

shellcheck:
	make -C tests shellcheck

readme:
	@ printf '<!---\nThis README file is generated. Changes will be overwritten.\n-->\n' > README.md
	@ printf '[![Build Status](https://travis-ci.org/whiteinge/ok.sh.svg?branch=master)](https://travis-ci.org/whiteinge/ok.sh)\n\n' >> README.md
	@ OK_SH_MARKDOWN=1 $(PROGRAM) help >> README.md

preview:
	@ pandoc -f markdown_github < README.md > README.html
