NAME=noms-client
VERSION=1.6
RELEASE=1
SOURCE=$(NAME)-$(VERSION).tar.gz
# Your executable files, e.g. frobisher or bin/frobisher - will be installed in .../bin
EXES=bin/noms
# Your library files, e.g. lib/EN/Ops/Froblib.pm or lib/en/frobber.rb - will be installed in .../lib
LIBS=lib/noms/cmdb.rb lib/noms/httpclient.rb lib/pcm/client.rb lib/ppinventory.rb

# Your default configuration files, e.g. frob.conf or etc/frob.conf - will be installed in .../etc
CONFS=etc/noms.conf
# Your just other files, e.g. frob-application-stuff/game-maps - will be installed in FILE_DEST
FILES=
# If set FILE_DEST will be where your FILES will show up under the install prefix
# FILE_DEST=
ARCH=noarch
CLEAN_TARGETS=$(SPEC) $(NAME)-$(VERSION) $(SOURCE) # for in-house package

include $(shell starter)/rules.mk
