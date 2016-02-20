find = $(foreach dir,$(1),$(foreach d,$(wildcard $(dir)/*),$(call find,$(d),$(2))) $(wildcard $(dir)/$(strip $(2))))

FLEX_HOME?=/usr/local/apache-flex-sdk

all: bin/Flash-Socket.IO.swc
sample: sample/client.swf

bin/Flash-Socket.IO.swc: $(call find, src, *.as)
	@mkdir -p bin
	$(FLEX_HOME)/bin/compc \
		--source-path=./src \
		--source-path=./libs/AS3WebSocket/AS3WebSocket/src \
		--library-path=./libs \
		--include-classes=com.pnwrain.flashsocket.FlashSocket \
		--debug=true \
		--output=$@

sample/client.swf: sample/client.as bin/Flash-Socket.IO.swc
	$(FLEX_HOME)/bin/mxmlc \
		--library-path=bin/Flash-Socket.IO.swc \
		--debug=true \
		--output=$@ \
		sample/client.as

