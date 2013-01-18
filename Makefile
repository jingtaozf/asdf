system	 	:= "asdf"
webhome_private := common-lisp.net:/project/asdf/public_html/
webhome_public	:= "http://common-lisp.net/project/asdf/"
clnet_home      := "/project/asdf/public_html/"
sourceDirectory := $(shell pwd)

#### Common Lisp implementations available for testing.
## export ASDF_TEST_LISPS to override the default list of such implementations,
## or specify a lisps= argument at the make command-line
ifdef ASDF_TEST_LISPS
lisps ?= ${ASDF_TEST_LISPS}
else
lisps ?= ccl clisp sbcl ecl ecl_bytecodes cmucl abcl scl allegro lispworks allegromodern xcl gcl
endif
## NOT SUPPORTED BY OUR AUTOMATED TESTS:
##	cormancl genera lispworks-personal-edition mkcl rmcl
## Some are manually tested once in a while.
## MAJOR FAIL: gclcvs -- Compiler bug fixed upstream, but gcl fails to compile on modern Linuxen.
## grep for #+/#- features in the test/ directory to see plenty of disabled tests.

lisp ?= sbcl

ABCL ?= abcl
ALLEGRO ?= alisp
ALLEGROMODERN ?= mlisp
CCL ?= ccl
CLISP ?= clisp
CMUCL ?= cmucl
ECL ?= ecl
GCL ?= gcl
LISPWORKS ?= lispworks
MKCL ?= mkcl
SBCL ?= sbcl
SCL ?= scl
XCL ?= xcl

# website, tag, install

header_lisp := header.lisp
driver_lisp := package.lisp compatibility.lisp utility.lisp pathname.lisp stream.lisp os.lisp image.lisp run-program.lisp lisp-build.lisp configuration.lisp backward-driver.lisp driver.lisp
asdf_lisp := upgrade.lisp component.lisp system.lisp find-system.lisp find-component.lisp operation.lisp action.lisp lisp-action.lisp plan.lisp operate.lisp output-translations.lisp source-registry.lisp backward-internals.lisp defsystem.lisp bundle.lisp concatenate-source.lisp backward-interface.lisp interface.lisp footer.lisp

# Making ASDF itself should be our first, default, target:
build/asdf.lisp: $(wildcard *.lisp)
	mkdir -p build
	cat $(header_lisp) $(driver_lisp) $(asdf_lisp) > $@

# This quickly locates such mistakes as unbalanced parentheses:
load: build/asdf.lisp
	rlwrap sbcl \
	`for i in $(driver_lisp) $(asdf_lisp) ; do echo --load $$i ; done` \
	--eval '(in-package :asdf)'

install: archive-copy

bump-version: build/asdf.lisp
	./bin/bump-version

archive: build/asdf.lisp
	#${SBCL} --userinit /dev/null --sysinit /dev/null --load bin/make-helper.lisp \
	#	--eval "(rewrite-license)" --eval "(quit)"
	./bin/make-tarball

archive-copy: archive build/asdf.lisp
	git checkout release
	bin/rsync-cp build/asdf*.tar.gz $(webhome_private)/archives
	bin/link-tarball $(clnet_home)
	bin/rsync-cp build/asdf.lisp $(webhome_private)
	${MAKE} push
	git checkout master

### Count lines separately for asdf-driver and asdf itself:
wc:
	@wc $(driver_lisp) | sort -n ; echo ; \
	wc $(header_lisp) $(asdf_lisp) | sort -n ; \
	echo ; \
	wc $(driver_lisp) $(asdf_lisp) | tail -n 1

push:
	git status
	git push --tags cl.net release master
	git fetch
	git status

doc:
	${MAKE} -C doc

website:
	${MAKE} -C doc website

clean_dirs = $(sourceDirectory)
clean_extensions = fasl dfsl cfsl fasl fas lib dx32fsl lx64fsl lx32fsl ufasl o bak x86f vbin amd64f sparcf sparc64f hpf hp64f

clean:
	@for dir in $(clean_dirs); do \
	     if test -d $$dir; then \
	     	 echo Cleaning $$dir; \
		 for ext in $(clean_extensions); do \
		     find $$dir \( -name "*.$$ext" \) \
	     	    -and -not -path \""*/.git/*"\" \
		     	  -and -not -path \""*/_darcs/*"\" \
	     		  -and -not -path \""*/tags/*"\" -print -delete; \
		done; \
	     fi; \
	done
	rm -rf build/ LICENSE test/try-reloading-dependency.asd
	${MAKE} -C doc clean

mrproper: clean
	rm -rf .pc/ build-stamp debian/patches/ debian/debhelper.log debian/cl-asdf/ # debian crap

test-upgrade: build/asdf.lisp
	./test/run-tests.sh -u ${lisp}

test-clean-load: build/asdf.lisp
	./test/run-tests.sh -c ${lisp}

test-lisp: build/asdf.lisp
	@cd test; ${MAKE} clean;./run-tests.sh ${lisp} ${test-glob}

test: test-lisp test-clean-load doc

test-all-lisps:
	@for lisp in ${lisps} ; do \
		${MAKE} test-lisp test-upgrade lisp=$$lisp || exit 1 ; \
	done

# test upgrade is a very long run... This does just the regression tests
test-all-noupgrade:
	@for lisp in ${lisps} ; do \
		${MAKE} test-lisp lisp=$$lisp || exit 1 ; \
	done

test-all-upgrade:
	@for lisp in ${lisps} ; do \
		${MAKE} test-upgrade lisp=$$lisp || exit 1 ; \
	done

test-all: test-forward-references doc test-all-lisps

# Note that the debian git at git://git.debian.org/git/pkg-common-lisp/cl-asdf.git is stale,
# as we currently build directly from upstream at git://common-lisp.net/projects/asdf/asdf.git
debian-package: mrproper
	: $${RELEASE:="$$(git tag -l '2.[0-9][0-9]' | tail -n 1)"} ; \
	git-buildpackage --git-debian-branch=release --git-upstream-branch=$$RELEASE --git-tag --git-retag --git-ignore-branch

# Replace SBCL's ASDF with the current one. -- NOT recommended now that SBCL has ASDF2.
# for casual users, just use (asdf:load-system :asdf)
replace-sbcl-asdf: build/asdf.lisp
	${SBCL} --eval '(compile-file "$<" :output-file (format nil "~Aasdf/asdf.fasl" (sb-int:sbcl-homedir-pathname)))' --eval '(quit)'

# Replace CCL's ASDF with the current one. -- NOT recommended now that CCL has ASDF2.
# for casual users, just use (asdf:load-system :asdf)
replace-ccl-asdf: build/asdf.lisp
	${CCL} --eval '(progn(compile-file "$<" :output-file (compile-file-pathname (format nil "~Atools/asdf.lisp" (ccl::ccl-directory))))(quit))'

WRONGFUL_TAGS := 1.37 1.1720 README RELEASE STABLE
# Delete wrongful tags from local repository
fix-local-git-tags:
	for i in ${WRONGFUL_TAGS} ; do git tag -d $$i ; done
	git tag 1.37 c7738c62 # restore the *correct* 1.37 tag.

# Delete wrongful tags from remote repository
fix-remote-git-tags:
	for i in ${WRONGFUL_TAGS} ; do git push $${REMOTE:-cl.net} :refs/tags/$$i ; done

release-push:
	git checkout master
	git merge release
	git checkout release
	git merge master
	git checkout master

TODO:
	exit 2

release: TODO test-all test-on-other-machines-too debian-changelog debian-package send-mail-to-mailing-lists

.PHONY: install archive archive-copy push doc website clean mrproper \
	test-forward-references test test-lisp test-upgrade test-forward-references \
	test-all test-all-lisps test-all-noupgrade \
	debian-package release \
	replace-sbcl-asdf replace-ccl-asdf \
	fix-local-git-tags fix-remote-git-tags wc wc-driver wc-asdf

# RELEASE checklist:
# make test-all
# ./bin/bump-version 2.27
# edit debian/changelog
# make release-push archive-copy website debian-package
# dput mentors ../*.changes
# send debian mentors request
# send announcement to asdf-announce, asdf-devel, etc.
