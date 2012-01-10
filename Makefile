DEPS = deps/fast_log

all: compile eunit

clean:
	@rebar skip_deps=true clean

allclean:
	@rebar clean

distclean:
	@rebar skip_deps=true clean
	@rm -rf deps

compile: $(DEPS)
	@rebar compile
	@dialyzer -Wrace_conditions -Wunderspecs -r ebin

dialyzer:
	@dialyzer -Wrace_conditions -Wunderspecs -r ebin

$(DEPS):
	@rebar get-deps

doc:
	@rebar doc skip_deps=true

eunit: compile
	@rebar skip_deps=true eunit

test: eunit

tags: TAGS

TAGS:
	mkdir -p deps;find src deps -name "*.[he]rl" -print | etags -

.PHONY: tags doc
