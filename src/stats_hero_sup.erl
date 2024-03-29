%% -*- erlang-indent-level: 4;indent-tabs-mode: nil; fill-column: 92 -*-
%% ex: ts=4 sw=4 et
%% @author Seth Falcon <seth@chef.io>
%% @end
%% Copyright 2014-2016 Chef Software, Inc. All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%

-module(stats_hero_sup).

-behaviour(supervisor).

-define(CHILD_TYPES, [stats_hero_monitor, stats_hero_worker_sup, stats_hero_sender_sup, pg]).

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
new_child(stats_hero_worker_sup, Children) ->
    HeroSup = {stats_hero_worker_sup, {stats_hero_worker_sup, start_link, []}, permanent,
               brutal_kill, supervisor, [stats_hero_worker_sup]},
    [HeroSup | Children ];
new_child(stats_hero_sender_sup, Children) ->
    SenderSup = {stats_hero_sender_sup, {stats_hero_sender_sup, start_link, []}, permanent,
                 brutal_kill, supervisor, [stats_hero_sender_sup]},
    [SenderSup | Children ];
new_child(pg, Children) ->
    PG = {pg, {pg, start_link, []}, permanent,
               brutal_kill, worker, [pg]},
    [PG | Children ].
