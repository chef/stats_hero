%% -*- erlang-indent-level: 4;indent-tabs-mode: nil; fill-column: 92 -*-
%% ex: ts=4 sw=4 et
%% @author Seth Falcon <seth@opscode.com>
%% @copyright 2012 Opscode, Inc.
%% @end
-module(stats_hero_sender_sup).

-behaviour(supervisor).


%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).
-include("stats_hero_sender.hrl").

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

init([]) ->
    {ok, SenderCount} = application:get_env(stats_hero, udp_socket_pool_size),
    error_logger:info_msg("starting stats_hero_sender_sup with ~B senders~n", [SenderCount]),
    ok = pg2:create(?SH_SENDER_POOL),
    {ok, Host} = application:get_env(stats_hero, estatsd_host),
    {ok, Port} = application:get_env(stats_hero, estatsd_port),
    Config = [{estatsd_host, Host}, {estatsd_port, Port}, {group_name, stats_hero_sender_pool}],
    StartUp = {stats_hero_sender, start_link, [Config]},
    Children = [ {make_id(I), StartUp, permanent, brutal_kill, worker, [stats_hero_sender]}
                 || I <- lists:seq(1, SenderCount) ],
    {ok, {{one_for_one, 60, 10}, Children}}.

make_id(I) ->
    "stats_hero_sender_" ++ integer_to_list(I).
