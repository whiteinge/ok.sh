# Install ok.sh; build the website/README; run the tests.

PROGRAM = ok.sh
DESTDIR = $(HOME)
DESTDIRB = /

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
	@ printf '[![Build Status](https://travis-ci.org/whiteinge/ok.sh.svg?branch=master)](https://travis-ci.org/whiteinge/ok.sh)\n' >> README.md
	@ $(PROGRAM) help >> README.md
	@ printf '\n## Table of Contents\n' >> README.md
	@ $(PROGRAM) _all_funcs pretty=0 | xargs -n1 -I@ sh -c '[ @ = _main ] && exit; printf "* [@](#@)\n"' >> README.md
	@ printf '\n' >> README.md
	@ $(PROGRAM) _all_funcs pretty=0 | xargs -n1 -I@ sh -c '[ @ = _main ] && exit; $(PROGRAM) help @; printf "\n"' >> README.md

preview:
	@ pandoc -f markdown_github < README.md > README.html
