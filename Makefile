find = $(foreach dir,$(1),$(foreach d,$(wildcard $(dir)/*),$(call find,$(d),$(2))) $(wildcard $(dir)/$(strip $(2))))

FLEX_HOME?=/usr/local/apache-flex-sdk

all: bin/Flash-Socket.IO.swc

bin/Flash-Socket.IO.swc: $(call find, ., *.as)
	@mkdir -p bin
	$(FLEX_HOME)/bin/compc \
		--source-path=./src \
		--source-path=./libs/AS3WebSocket/AS3WebSocket/src \
		--library-path=./libs \
		--include-classes=com.pnwrain.flashsocket.FlashSocket \
		--debug=true \
		--output=$@

