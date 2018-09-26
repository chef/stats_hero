REBAR=$(shell which rebar3 || echo ./rebar3)

all: compile eunit dialyzer

clean: $(REBAR)
	$(REBAR) as dev clean
	$(REBAR) as test clean

compile: $(REBAR)
	$(REBAR) as dev compile

dialyzer:
	$(REBAR) dialyzer

doc: $(REBAR)
	$(REBAR) doc skip_deps=true

eunit: $(REBAR) compile
	$(REBAR) eunit --dir=test 

test: $(REBAR) eunit

tags: $(REBAR) TAGS

TAGS:
	mkdir -p deps;find src _build -name "*.[he]rl" -print | etags -

.PHONY: tags doc

REBAR_URL = https://s3.amazonaws.com/rebar3/rebar3

./rebar3:
	@echo "Fetching rebar3 from $(REBAR_URL)"
	@erl -noinput -noshell -s inets -s ssl  -eval '{ok, _} = httpc:request(get, {"${REBAR_URL}", []}, [], [{stream, "${REBAR}"}])' -s init stop
	chmod +x ${REBAR}
