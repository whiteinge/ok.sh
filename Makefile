# Install ok.sh; build the website/README; run the tests.

PROGRAM ?= ok.sh
DESTDIR ?= $(HOME)
DESTDIRB ?= /
VERSION	:=

.PHONY: test
test :
	make -C tests all

.PHONY: docker
docker : .image
	docker run -it --rm -v $$PWD:/oksh oksh

# Remove this file to trigger a rebuild.
.image :
	docker build -t oksh .
	touch $@

.PHONY: busybox
busybox : .busybox
	env -i -- PATH=$$PWD/.busybox SHELL=sh $$PWD/.busybox/sh

.busybox :
	mkdir -p $$PWD/.busybox
	busybox --install -s $$PWD/.busybox
	ln -s $$(which curl) $$PWD/.busybox/curl
	ln -s $$(which jq) $$PWD/.busybox/jq
	ln -s $$(which make) $$PWD/.busybox/make
	ln -s $$(which socat) $$PWD/.busybox/socat

clean :
	rm -f .image

install : $(PROGRAM)
	cp $(PROGRAM) "$(DESTDIR)/bin/"
	chmod 755 "$(DESTDIR)/bin/$(PROGRAM)"
	cp $(PROGRAM) "$(DESTDIRB)bin/"
	chmod 777 "$(DESTDIRB)bin/$(PROGRAM)"

.PHONY: version
version : readme
	sed -i -e "s/VERSION=.*/VERSION='$(VERSION)'/g" $(PROGRAM)
	git add $(PROGRAM) README.md
	git commit -m 'Update version to $(VERSION)'
	git tag -a $(VERSION) -s

.PHONY: shellcheck
shellcheck :
	make -C tests shellcheck

readme : $(PROGRAM)
	@ printf '<!---\nThis README file is generated. Changes will be overwritten.\n-->\n' > README.md
	@ printf '[![Build Status](https://travis-ci.org/whiteinge/ok.sh.svg?branch=master)](https://travis-ci.org/whiteinge/ok.sh)\n\n' >> README.md
	OK_SH_MARKDOWN=1 ./$(PROGRAM) help >> README.md

.PHONY: preview
preview :
	@ pandoc -f gfm < README.md > README.html

.PHONY: posixdocs
posixdocs:
	wget -np --mirror https://pubs.opengroup.org/onlinepubs/9699919799/
