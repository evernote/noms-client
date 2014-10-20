NAME=noms-client
VERSION=1.8.1
RELEASE=1
SOURCE=$(NAME)-$(VERSION).tar.gz
EXES=bin/noms bin/ansible-cmdb
LIBS=lib/noms/cmdb.rb lib/noms/httpclient.rb lib/noms/nagui.rb lib/ncc/client.rb
CONFS=etc/noms.conf
ARCH=noarch
CLEAN_TARGETS=$(SPEC) $(NAME)-$(VERSION) $(SOURCE) # for in-house package

include $(shell starter)/rules.mk
