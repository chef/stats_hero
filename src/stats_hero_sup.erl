%% -*- erlang-indent-level: 4;indent-tabs-mode: nil; fill-column: 92 -*-
%% ex: ts=4 sw=4 et
%% @author Seth Falcon <seth@opscode.com>
%% @copyright 2012 Opscode, Inc.
%% @end
-module(stats_hero_sup).

-behaviour(supervisor).

-define(CHILD_TYPES, [stats_hero_monitor, stats_hero_sup]).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

init([]) ->
    error_logger:info_msg("starting stats_hero_sup~n"),
    %% We want the top-level supervisor to own the stats_hero ETS table to ensure it is
    %% always available.
    stats_hero:init_storage(),
    Children = lists:foldl(fun new_child/2, [], ?CHILD_TYPES),
    {ok, {{one_for_one, 60, 10}, Children}}.

new_child(stats_hero_monitor, Children) ->
    HeroMon = {stats_hero_monitor, {stats_hero_monitor, start_link, []}, permanent,
               brutal_kill, worker, [stats_hero_monitor]},
    [HeroMon | Children ];
new_child(stats_hero_sup, Children) ->
    HeroSup = {stats_hero_sup, {stats_hero_sup, start_link, []}, permanent,
               brutal_kill, supervisor, [stats_hero_sup]},
    [HeroSup | Children ].


