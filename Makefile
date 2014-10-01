NAME=noms-client
VERSION=1.7.5
RELEASE=2
SOURCE=$(NAME)-$(VERSION).tar.gz
EXES=bin/noms bin/ansible-cmdb
LIBS=lib/noms/cmdb.rb lib/noms/httpclient.rb lib/noms/nagui.rb lib/pcm/client.rb
CONFS=etc/noms.conf
ARCH=noarch
CLEAN_TARGETS=$(SPEC) $(NAME)-$(VERSION) $(SOURCE) # for in-house package

include $(shell starter)/rules.mk
