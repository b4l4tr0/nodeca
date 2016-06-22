PATH          := ./node_modules/.bin:${PATH}

NPM_PACKAGE   := $(shell node -e 'process.stdout.write(require("./package.json").name)')
NPM_VERSION   := $(shell node -e 'process.stdout.write(require("./package.json").version)')

GITHUB_PROJ   := nodeca/${NPM_PACKAGE}

APPLICATIONS   = nodeca.core nodeca.users nodeca.forum nodeca.blogs
NODE_MODULES   = $(foreach app,$(APPLICATIONS),node_modules/$(app))
CONFIG_FILES   = $(basename $(wildcard ./config/*.yml.example))

INSTALL_DEPS  := $(shell test -d ./node_modules ; echo $$?)


help:
	echo "make help       - Print this help"
	echo "make lint       - Lint sources with JSHint"
	echo "make test       - Lint sources and run all tests"
	echo "make publish    - Set new version tag and publish npm package"
	echo "make todo       - Find and list all TODOs"
	echo "make pull       - Updates all sub-apps"
	echo "make pull-ro    - Updates all sub-apps in read-only mode"


lint:
	@if test -z "$(NODECA_APP_PATH)"; then \
		eslint . ; \
		else \
		cd $(NODECA_APP_PATH) ; \
		eslint . ; \
		fi


$(CONFIG_FILES):
	test -f $@.example && ( test -f $@ || cp $@.example $@ )


test: lint $(CONFIG_FILES)
	mongo nodeca-test --eval "printjson(db.dropDatabase())"
	redis-cli -n 2 flushdb
	DEBUG=navit* NODECA_ENV=test node nodeca.js migrate --all
	DEBUG=navit* NODECA_ENV=test NODECA_NOMINIFY=1 ./nodeca.js test $(NODECA_APP)


repl:
	rlwrap socat ./repl.sock stdin


# used from Travis-CI, to not repeat all deps install steps for all apps
deps-ci:
	# don't know why, but it fails to install with all other packages on travis
	# force separate install.
	npm install cldr-data

dev-server:
	if test ! `which inotifywait` ; then \
		echo "You need 'inotifywait' installed in order to run dev-server." >&2 ; \
		echo "   sudo apt-get install inotify-tools" >&2 ; \
		exit 128 ; \
		fi
	./support/forever.sh


publish:
	@if test 0 -ne `git status --porcelain | wc -l` ; then \
		echo "Unclean working tree. Commit or stash changes first." >&2 ; \
		exit 128 ; \
		fi
	@if test 0 -ne `git tag -l ${NPM_VERSION} | wc -l` ; then \
		echo "Tag ${NPM_VERSION} exists. Update package.json" >&2 ; \
		exit 128 ; \
		fi
	git tag ${NPM_VERSION} && git push origin ${NPM_VERSION}
	npm publish https://github.com/${GITHUB_PROJ}/tarball/${NPM_VERSION}


todo:
	grep 'TODO' -n -r --exclude-dir=public --exclude-dir=\.cache --exclude-dir=\.git --exclude-dir=node_modules --exclude=Makefile . 2>/dev/null || test true


node_modules/nodeca.core:     REPO_RW=git@github.com:nodeca/nodeca.core.git
node_modules/nodeca.users:    REPO_RW=git@github.com:nodeca/nodeca.users.git
node_modules/nodeca.forum:    REPO_RW=git@github.com:nodeca/nodeca.forum.git
node_modules/nodeca.blogs:    REPO_RW=git@github.com:nodeca/nodeca.blogs.git


node_modules/nodeca.core:     REPO_RO=git://github.com/nodeca/nodeca.core.git
node_modules/nodeca.users:    REPO_RO=git://github.com/nodeca/nodeca.users.git
node_modules/nodeca.forum:    REPO_RO=git://github.com/nodeca/nodeca.forum.git
node_modules/nodeca.blogs:    REPO_RO=git://github.com/nodeca/nodeca.blogs.git


$(NODE_MODULES):
	mkdir -p node_modules
	echo "*** $@"
	if test ! -d $@/.git && test -d $@ ; then \
		echo "Module already exists. Remove it first." >&2 ; \
		exit 128 ; \
		fi
	if test ! -d $@/.git ; then \
		rm -rf $@ && \
		git clone $($(shell echo ${REPO})) $@ && \
		cd $@ && \
		npm install ; \
		fi
	cd $@ && git pull


pull-ro: REPO="REPO_RO"
pull-ro: $(NODE_MODULES)
	git pull
	@if test $(INSTALL_DEPS) -ne 0 ; then \
		npm install ; \
		fi


pull: REPO="REPO_RW"
pull: $(NODE_MODULES)
	git pull
	@if test $(INSTALL_DEPS) -ne 0 ; then \
		npm install ; \
		fi


.PHONY: $(NODE_MODULES) publish lint test todo
.SILENT: $(NODE_MODULES) help lint test todo
