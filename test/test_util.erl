-module(test_util).

-export([label/1]).

%% @doc Generate a stats hero metric label for upstream `Prefix' and function name `Fun'.
%% An error is thrown if `Prefix' is unknown.
%% This is where we encode the mapping of module to upstream label.
label({Mod, Fun}) ->
    label(Mod, Fun).

label(chef_otto, Fun) ->
    label(couchdb, Fun);
label(chef_sql, Fun) ->
    label(rdbms, Fun);
label(chef_authz, Fun) ->
    label(authz, Fun);
label(chef_solr, Fun) ->
    label(solr, Fun);
label(Prefix, Fun) when Prefix =:= rdbms;
                        Prefix =:= couchdb;
                        Prefix =:= authz;
                        Prefix =:= solr ->
    PrefixBin = erlang:atom_to_binary(Prefix, utf8),
    FunBin = erlang:atom_to_binary(Fun, utf8),
    <<PrefixBin/binary, ".", FunBin/binary>>;
label(BadPrefix, Fun) ->
    erlang:error({bad_prefix, {BadPrefix, Fun}}).

