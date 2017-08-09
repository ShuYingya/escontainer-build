GITREV = $$(git describe --always --tags)
GITREV_FOR_PKG = $(shell echo "$(GITREV)" | sed -e 's,-,\.,g' -e 's,^v,,')

srcdir=$(shell pwd)
PACKAGE=escontos-buildscripts

PKG_VER = $(PACKAGE)-$(GITREV_FOR_PKG)

show-pkgver:	##@package check the new package version
	@echo $(PKG_VER)

dist-snapshot:	##@package create current code snapshot (tar.xz)
	set -x; \
	echo "PACKAGE=$(PACKAGE)"; \
	TARFILE_TMP=$(PKG_VER).tar.tmp; \
	echo "Archiving $(PACKAGE) at $(GITREV)"; \
	(cd $(srcdir); git archive --format=tar --prefix=$(PKG_VER)/ $(GITREV)) > $${TARFILE_TMP}; \
	(cd $$(git rev-parse --show-toplevel); git submodule status) | while read line; do \
	  rev=$$(echo $$line | cut -f 1 -d ' '); path=$$(echo $$line | cut -f 2 -d ' '); \
	  echo "Archiving $${path} at $${rev}"; \
	  (cd $(srcdir)/$$path; git archive --format=tar --prefix=$(PKG_VER)/$$path/ $${rev}) > submodule.tar; \
	  tar -A -f $${TARFILE_TMP} submodule.tar; \
	  rm submodule.tar; \
	done; \
	mv $(PKG_VER).tar{.tmp,}; \
	rm -f $(PKG_VER).tar.xz; \
	xz $(PKG_VER).tar

srpm: dist-snapshot  ##@package create source rpm
	(cd $(srcdir)/packaging; \
	 cp ../$(PKG_VER).tar.xz . ; \
	 sed -e "s,^Version:.*,Version: $(GITREV_FOR_PKG)," $(PACKAGE).spec.in > $(PACKAGE).spec; \
	 ./rpmbuild-cwd -bs $(PACKAGE).spec)

rpm: srpm  ##@package create binary rpm
	$(srcdir)/packaging/rpmbuild-cwd --rebuild packaging/$(PKG_VER)*.src.rpm

buildinstall: rpm  ##@package build and install in local machine
	sudo yum localinstall $(PKG_VER)*.src.rpm
