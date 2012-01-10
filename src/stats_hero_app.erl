%% -*- erlang-indent-level: 4;indent-tabs-mode: nil; fill-column: 92 -*-
%% ex: ts=4 sw=4 et
%% @author Seth Falcon <seth@opscode.com>
%% @copyright 2012 Opscode, Inc.
%% @end

-module(stats_hero_app).

-behaviour(application).

-include_lib("eunit/include/eunit.hrl").

%% Application callbacks
-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    stats_hero_sup:start_link().

stop(_State) ->
    ok.
