-module(test_util).

-export([do_work/1, label/1]).

do_work(T) ->
    timer:sleep(T),
    ok.
%% @doc Generate a stats hero metric label for upstream `Prefix' and function name `Fun'.
%% An error is thrown if `Prefix' is unknown.
%% This is where we encode the mapping of module to upstream label.
label({Mod, Fun}) ->
    label(Mod, Fun).

label(test_util, Fun) ->
    label(stats_hero_testing, Fun);
label(Prefix, Fun) when Prefix =:= stats_hero_testing ->
    PrefixBin = erlang:atom_to_binary(Prefix, utf8),
    FunBin = erlang:atom_to_binary(Fun, utf8),
    <<PrefixBin/binary, ".", FunBin/binary>>;
label(BadPrefix, Fun) ->
    erlang:error({bad_prefix, {BadPrefix, Fun}}).

