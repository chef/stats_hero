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

-module(stats_hero_test).

-include_lib("eunit/include/eunit.hrl").
-include_lib("stats_hero/include/stats_hero.hrl").

-define(UPSTREAMS, [<<"rdbms">>, <<"couchdb">>, <<"authz">>]).

-define(REPEAT(Expr, N), do_repeat(fun() -> Expr end, N)).

do_repeat(_Fun, 0) ->
    ok;
do_repeat(Fun, N) ->
    Fun(),
    do_repeat(Fun, N - 1).

call_for_type({sleep, X}) ->    
    fun() -> timer:sleep(X) end;
call_for_type({time, X}) -> 
    {X, ms}.

expand_label(K) ->
    [<<K/binary, "_time">>, <<K/binary, "_count">>].

setup_stats_hero_env(Port) ->
    application:set_env(stats_hero, estatsd_host, "localhost"),
    application:set_env(stats_hero, estatsd_port, Port),
    application:set_env(stats_hero, udp_socket_pool_size, 5).

setup_stats_hero(Config) ->
    meck:new(net_adm, [passthrough, unstick]),
    meck:expect(net_adm, localhost, fun() -> "test-host" end),
    error_logger:tty(false),
    capture_udp:start_link(0),
    {ok, Port} = capture_udp:what_port(),
    setup_stats_hero_env(Port),
    application:start(stats_hero),
    error_logger:tty(true),

    {ok, _} = stats_hero_worker_sup:new_worker(Config),

    %% Each call is {Label, NumCalls, {time, X} | {sleep, X}}
    Calls = [{<<"rdbms.nodes.fetch">>, 1, {sleep, 100}},
             {<<"rdbms.nodes.fetch">>, 9, {time, 100}},
             {<<"rdbms.nodes.put">>, 1, {time, 200}},
             {<<"authz.nodes.read">>, 1, {time, 100}},
             %% add a call that won't be matched to exercise that edge case
             {<<"no-such-prefix.who.what.where">>, 1, {time, 100}}],

    ReqId = proplists:get_value(request_id, Config),
    [ ?REPEAT(stats_hero:ctime(ReqId, Label, call_for_type(Type)), N)
      || {Label, N, Type} <- Calls ],

    stats_hero:alog(ReqId, <<"my_log">>, <<"hello, ">>),
    stats_hero:alog(ReqId, <<"my_log">>, <<"world.">>),

    stats_hero:report_metrics(ReqId, 200),

    {ReqId, Config, Calls}.

cleanup_stats_hero() ->
    meck:unload(),
    error_logger:tty(false),
    application:stop(stats_hero),
    capture_udp:stop(),
    error_logger:tty(true).

stats_hero_missing_required_config_test_() ->
    %% Ensure that we get readable error messages if Config proplist
    %% is missing a required key.
    {setup,
     fun() ->
             Port = 3888,
             setup_stats_hero_env(Port),
             error_logger:tty(false),
             application:start(stats_hero),
             error_logger:tty(true),
             %% pass a complete config to the tests, we'll delete keys from it for testing.
             [{request_label, <<"nodes">>},
              {request_action, <<"PUT">>},
              {upstream_prefixes, ?UPSTREAMS},
              {my_app, <<"test_hero">>},
              %% again purposeful use of string to test conversion
              {org_name, "orginc"},
              {label_fun, {test_util, label}},
              {request_id, <<"req_id_123">>}]
     end,
     fun(_) ->
             error_logger:tty(false),
             application:stop(stats_hero),
             error_logger:tty(true)
     end,
     fun(FullConfig) ->
             %% These are the required keys.
             Keys = [my_app, request_label, request_action, org_name, request_id,
                     upstream_prefixes],
             [ {"missing " ++ atom_to_list(Key),
                fun() ->
                        NoKey = proplists:delete(Key, FullConfig),
                       ?assertMatch({error, {{required_key_missing, Key, _}, _}},
                                    stats_hero_worker_sup:new_worker(NoKey))
                end} || Key <- Keys ]
     end}.

stats_hero_integration_test_() ->
    {setup,
     fun() ->
             Config = [{request_label, <<"nodes">>},
                       {request_action, <<"PUT">>},
                       {upstream_prefixes, ?UPSTREAMS},
                       %% specify a config entry as a string to
                       %% exercise conversion to binary.
                       {my_app, "test_hero"},
                       {org_name, <<"orginc">>},
                       {label_fun, {test_util, label}},
                       {request_id, <<"req_id_123">>}],
             setup_stats_hero(Config)
     end,
     fun(_X) -> cleanup_stats_hero() end,
     fun({ReqId, Config, Calls}) ->
             [
              {"stats_hero functions give not_found or [] for a bad request id", generator,
               fun() ->
                       [
                        ?_assertEqual(not_found,
                                      stats_hero:ctime(<<"unknown">>, <<"a_label">>, {100, ms})),

                        ?_assertEqual(not_found, stats_hero:stop_worker(<<"unknown">>)),

                        ?_assertEqual(not_found, stats_hero:clean_worker_data(spawn(fun() -> ok end))),

                        ?_assertEqual(not_found, stats_hero:alog(<<"unknown">>,
                                                                 <<"a_label">>, <<"msg">>)),

                        ?_assertEqual([], stats_hero:snapshot(<<"unknown">>, all)),

                        ?_assertEqual(not_found,
                                      stats_hero:report_metrics(<<"unknown">>, 404)),

                        ?_assertEqual(not_found,
                                      stats_hero:read_alog(<<"unknown">>, <<"my_log">>))
                       ]
               end},

              {"read_alog retrieves a log message",
               fun() ->
                       ?assertEqual([<<"hello, ">>,<<"world.">>],
                                    stats_hero:read_alog(ReqId, <<"my_log">>))
               end},

               {"snapshot returns the right set of keys", generator,
                fun() ->
                        BuildKeys = fun(K, Acc) -> expand_label(K) ++ Acc end,
                        CallLabels = lists:usort([ Label || {Label, _, _} <- Calls ]),
                        ExpectedAllKeys = [<<"req_time">> |
                                           lists:foldl(BuildKeys, [],
                                                       [<<"rdbms">>, <<"authz">>] ++ CallLabels)],
                        ExpectedAggKeys = [<<"req_time">> |
                                           lists:foldl(BuildKeys, [], [<<"rdbms">>, <<"authz">>])],
                        
                        ExpectedNoAggKeys = [<<"req_time">> |
                                             lists:foldl(BuildKeys, [], CallLabels)],
                        
                        Tests = [{all, ExpectedAllKeys},
                                 {agg, ExpectedAggKeys},
                                 {no_agg, ExpectedNoAggKeys}],
                        [ begin
                              Got = stats_hero:snapshot(ReqId, Type),
                              GotKeys = lists:sort([K || {K, _} <- Got ]),
                              ?_assertEqual({Type, GotKeys}, {Type, lists:sort(Expected)})
                          end || {Type, Expected} <- Tests ]
                end},

               {"snapshot returns the right call counts", generator,
                fun() ->
                        Snapshot = stats_hero:snapshot(ReqId, all),
                        CallCounts = lists:foldl(fun({Key, T}, Dict) ->
                                                         CountKey = <<Key/binary, "_count">>,
                                                         dict:update_counter(CountKey, T, Dict) end,
                                                 dict:new(),
                                                 [ {Key, T} || {Key, T, _} <- Calls ]),
                        [ ?_assertEqual({Key, Count}, {Key, proplists:get_value(Key, Snapshot)})
                          || {Key, Count} <- dict:to_list(CallCounts) ]
                end},

              {"snapshot after report_metrics always returns same req_time",
               fun() ->
                       S1 = stats_hero:snapshot(ReqId, agg),
                       ReqTime = proplists:get_value(<<"req_time">>, S1),
                       timer:sleep(100),
                       [S2, S3] = [ stats_hero:snapshot(ReqId, all) || _I <- [1, 2] ],
                       ?assertEqual(ReqTime, proplists:get_value(<<"req_time">>, S2)),
                       ?assertEqual(ReqTime, proplists:get_value(<<"req_time">>, S3))
               end},

               {"udp is captured",
                fun() ->
                        {_MsgCount, Msg} = capture_udp:read(),
                        [GotStart, GotEnd] = [ parse_shp(M) || M <- Msg ],
                        ExpectStart =
                            [{<<"test_hero.application.allRequests">>,<<"1">>,<<"m">>},
                             {<<"test_hero.test-host.allRequests">>,<<"1">>,<<"m">>},
                             {<<"test_hero.application.byRequestType.nodes.PUT">>,<<"1">>,<<"m">>}],
                        ?assertEqual(GotStart, ExpectStart),
                        %% For the end metrics, we can't rely on the
                        %% actual timing data, but can verify labels
                        %% and types.
                        ExpectEnd =
                            [{<<"test_hero.application.byStatusCode.200">>,<<"1">>,<<"m">>},
                             {<<"test_hero.test-host.byStatusCode.200">>,<<"1">>,<<"m">>},
                             {<<"test_hero.application.allRequests">>,<<"109">>,<<"h">>},
                             {<<"test_hero.test-host.allRequests">>,<<"109">>,<<"h">>},
                             {<<"test_hero.application.byRequestType.nodes.PUT">>,<<"109">>,<<"h">>},
                             {<<"test_hero.upstreamRequests.rdbms">>,<<"1200">>,<<"h">>},
                             {<<"test_hero.upstreamRequests.authz">>,<<"100">>,<<"h">>},
                             {<<"test_hero.upstreamRequests.rdbms.nodes.put">>,<<"200">>,<<"h">>},
                             {<<"test_hero.upstreamRequests.rdbms.nodes.fetch">>,<<"1000">>,<<"h">>},
                             {<<"test_hero.upstreamRequests.authz.nodes.read">>,<<"100">>,<<"h">>},
                             {<<"test_hero.application.byRequestType.nodes.PUT.upstreamRequests.rdbms">>,
                              <<"1200">>,<<"h">>},
                             {<<"test_hero.application.byRequestType.nodes.PUT.upstreamRequests.authz">>,
                              <<"100">>,<<"h">>}],

                        [ begin
                              ?assertEqual(ELabel, GLabel),
                              ?assertEqual(EType, GType)
                          end || {{ELabel, _, EType}, {GLabel, _, GType}} <- lists:zip(ExpectEnd, GotEnd) ]
                end},
               %% put this test last because we don't want to include
               %% the startup msg in UDP verification
               {"stats_hero_monitor keeps track of workers",
                fun() ->
                        ?assertEqual(1, stats_hero_monitor:registered_count()),
                        Config1 = lists:keyreplace(request_id, 1, Config,
                                                   {request_id, <<"temp1">>}),
                        {ok, WorkerPid} =  stats_hero_worker_sup:new_worker(Config1),
                        WorkerPid ! test_info_msg_handled,
                        ?assertEqual(2, stats_hero_monitor:registered_count()),
                        %% calling stop worker is async, so we sleep
                        %% to wait for the monitor to receive and
                        %% process the DOWN message. This is lame.
                        stats_hero:stop_worker(<<"temp1">>),
                        timer:sleep(200),       % LAME
                        ?assertEqual(1, stats_hero_monitor:registered_count())
                end}
              ]
     end
    }.

stats_hero_no_org_integration_test_() ->
    {setup,
     fun() ->
             ReqId = <<"req_id_123">>,
              Config = [{request_label, <<"nodes">>},
                        {request_action, <<"PUT">>},
                        {upstream_prefixes, ?UPSTREAMS},
                        {my_app, <<"test_hero">>},
                        {org_name, unset},
                        {label_fun, {test_util, label}},
                        {request_id, ReqId}],
             setup_stats_hero(Config)
     end,
     fun(_X) -> cleanup_stats_hero() end,
     fun({_ReqId, _Config, _Calls}) ->
             [
              {"udp is captured",
               fun() ->
                       {_MsgCount, Msg} = capture_udp:read(),
                       [GotStart] = [ parse_shp(M) || M <- Msg ],
                       ExpectStart =
                           [{<<"test_hero.application.allRequests">>,<<"1">>,<<"m">>},
                            {<<"test_hero.test-host.allRequests">>,<<"1">>,<<"m">>},
                            {<<"test_hero.application.byRequestType.nodes.PUT">>,<<"1">>,<<"m">>}],
                       ?assertEqual(GotStart, ExpectStart)
               end}
             ]
     end}.

stats_hero_label_fun_test_() ->
    {setup,
     fun() ->
             ReqId = <<"req_id_456">>,
             Config = [{request_label, <<"nodes">>},
                       {request_action, <<"PUT">>},
                       {upstream_prefixes, [<<"stats_hero_testing">>]},
                       {my_app, <<"test_hero">>},
                       {org_name, unset},
                       {label_fun, {test_util, label}},
                       {request_id, ReqId}],
             meck:new(net_adm, [passthrough, unstick]),
             meck:expect(net_adm, localhost, fun() -> "test-host" end),
             error_logger:tty(false),
             capture_udp:start_link(0),
             {ok, Port} = capture_udp:what_port(),
             setup_stats_hero_env(Port),
             application:start(stats_hero),
             error_logger:tty(true),
             {ok, WorkerPid} = stats_hero_worker_sup:new_worker(Config),
             {ReqId, Config, WorkerPid}
     end,
     fun(_) -> cleanup_stats_hero() end,
     fun({ReqId, _Config, WorkerPid}) ->
             [{"calls can be made using label fun style",
               fun() ->
                       ?SH_TIME(ReqId, test_util, do_work, (100)),
                       ?SH_TIME(ReqId, test_util, do_work, (100))
               end},

              {"snapshot gives running req_time",
               fun() ->
                       S1 = stats_hero:snapshot(ReqId, all),
                       timer:sleep(50),
                       S2 = stats_hero:snapshot(ReqId, all),
                       timer:sleep(50),
                       S3 = stats_hero:snapshot(ReqId, all),
                       ReqTimes = [ proplists:get_value(<<"req_time">>, PL)
                                    || PL <- [S1, S2, S3] ],
                       %% no dups and in time of call order
                       ?assertEqual(ReqTimes, lists:usort(ReqTimes))
               end},

              {"pedantic message handling tests for coverage",
               fun() ->
                       stats_hero:code_change(a, b, c),
                       %% cast of unknown msg
                       gen_server:cast(WorkerPid, should_be_ignored),
                       ?assertEqual(unhandled, gen_server:call(WorkerPid, should_be_ignored))
               end},

              {"snapshot aggregates using prefix and labels via label fun",
               fun() ->
                       Snap = stats_hero:snapshot(ReqId, agg),
                       ?assert(200 =< proplists:get_value(<<"stats_hero_testing_time">>, Snap)),
                       ?assertEqual(2, proplists:get_value(<<"stats_hero_testing_count">>, Snap))
               end}
             ]
     end}.

%% El-Cheapo Stats Hero Protocol parsing for test verification
parse_shp(Msg) ->
    [Header|MetricsRaw] = [ re:split(X, "\\|") || X <- re:split(Msg, "\n") ],
    %% verify version
    [<<"1">>, _] = Header,
    Metrics = [ begin
                    [Label, Val] = re:split(M, ":"),
                    {Label, Val, Type}
                end || [M, Type] <- MetricsRaw ],
    Metrics.
            
