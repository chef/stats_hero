%% -*- erlang-indent-level: 4;indent-tabs-mode: nil;fill-column: 92 -*-
%% ex: ts=4 sw=4 et
%% @author Seth Falcon <seth@opscode.com>
%% @author Kevin Smith <kevin@opscode.com>
%% Copyright 2012 Opscode, Inc. All Rights Reserved.
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

-module(stats_hero_worker_sup).

-behaviour(supervisor).

%% API
-export([start_link/0,
         new_worker/1]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%% @doc Start a new `stats_hero' worker.  `Config' is a proplist with keys: request_label,
%% request_action, estatsd_host, estatsd_port, upstream_prefixes, my_app, org_name, and
%% request_id.
%% @see stats_hero:start_link/1
new_worker(Config) ->
    supervisor:start_child(?SERVER, [Config]).

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

init([]) ->
    %% Note we could initialize the estatsd parameters here and not have to do that on each
    %% request. But since there is already other per-request config, for now going to leave
    %% all config in one place.
   {ok, {{simple_one_for_one, 1, 10},
          [{stats_hero, {stats_hero, start_link, []}, temporary, brutal_kill,
            worker, [stats_hero]}]}}.
