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

-module(stats_hero_sender_sup).

-behaviour(supervisor).


%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).


start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

init([]) ->
    SenderCount = envy:get(stats_hero, udp_socket_pool_size, pos_integer),
    error_logger:info_msg("starting stats_hero_sender_sup with ~B senders~n", [SenderCount]),

    Host = envy:get(stats_hero, estatsd_host, string),
    Port = envy:get(stats_hero, estatsd_port, pos_integer),
    Config = [{estatsd_host, Host}, {estatsd_port, Port}, {group_name, stats_hero_sender_pool}],
    StartUp = {stats_hero_sender, start_link, [Config]},
    Children = [ {make_id(I), StartUp, permanent, brutal_kill, worker, [stats_hero_sender]}
                 || I <- lists:seq(1, SenderCount) ],
    {ok, {{one_for_one, 60, 10}, Children}}.

make_id(I) ->
    "stats_hero_sender_" ++ integer_to_list(I).
