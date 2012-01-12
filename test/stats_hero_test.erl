-module(stats_hero_test).

-include_lib("eunit/include/eunit.hrl").

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

stats_hero_integration_test_() ->
    {setup,
     fun() ->
             meck:new(net_adm, [passthrough, unstick]),
             meck:expect(net_adm, localhost, fun() -> "test-host" end),
             application:start(stats_hero),
             capture_udp:start_link(0),
              {ok, Port} = capture_udp:what_port(),
              ReqId = <<"req_id_123">>,
              Config = [{estatsd_host, "localhost"},
                        {estatsd_port, Port},
                        {request_label, <<"nodes">>},
                        {request_action, <<"PUT">>},
                        {upstream_prefixes, ?UPSTREAMS},
                        {my_app, <<"test_hero">>},
                        {org_name, <<"orginc">>},
                        {request_id, ReqId}],
              stats_hero_worker_sup:new_worker(Config),
              
              %% Each call is {Label, NumCalls, {time, X} | {sleep, X}}
              Calls = [{<<"rdbms.nodes.fetch">>, 1, {sleep, 100}},
                       {<<"rdbms.nodes.fetch">>, 9, {time, 100}},
                       {<<"rdbms.nodes.put">>, 1, {time, 200}},
                       {<<"authz.nodes.read">>, 1, {time, 100}}],

              [ ?REPEAT(stats_hero:ctime(ReqId, Label, call_for_type(Type)), N)
                || {Label, N, Type} <- Calls ],

             stats_hero:alog(ReqId, <<"my_log">>, <<"hello, ">>),
             stats_hero:alog(ReqId, <<"my_log">>, <<"world.">>),

             stats_hero:report_metrics(ReqId, 200),

             {ReqId, Config, Calls}
     end,
     fun(_X) ->
             meck:unload(),
             application:stop(stats_hero)
     end,
     fun({ReqId, Config, Calls}) ->
              [
               {"stats_hero_monitor keeps track of workers",
                fun() ->
                        ?assertEqual(1, stats_hero_monitor:registered_count()),
                        {ok, Port} = capture_udp:what_port(),
                        %% This is a bit gross, but we don't want this
                        %% test to pollute our UDP capture so we guess
                        %% the the adjacent port is unused. Since we
                        %% are just blindly sending data to the port
                        %% over UDP, it hopefully won't matter.
                        Config1 = lists:keyreplace(estatsd_port, 1,
                                                   lists:keyreplace(request_id, 1,
                                                                    Config, {request_id, <<"temp1">>}),
                                                   {estatsd_port, Port - 1}),
                        stats_hero_worker_sup:new_worker(Config1),
                        ?assertEqual(2, stats_hero_monitor:registered_count()),
                        %% calling stop worker is async, so we sleep
                        %% to wait for the monitor to receive and
                        %% process the DOWN message. This is lame.
                        stats_hero:stop_worker(<<"temp1">>),
                        timer:sleep(100),       % LAME
                        ?assertEqual(1, stats_hero_monitor:registered_count())
                end},
               {"stats_hero functions give not_found or [] for a bad request id",
                fun() ->
                        ?assertEqual(not_found,
                                     stats_hero:ctime(<<"unknown">>, <<"a_label">>,
                                                      {100, ms})),

                        ?assertEqual(not_found, stats_hero:stop_worker(<<"unknown">>)),

                        APid = spawn(fun() -> ok end),
                        ?assertEqual(not_found, stats_hero:clean_worker_data(APid)),

                        ?assertEqual(not_found, stats_hero:alog(<<"unknown">>,
                                                                <<"a_label">>, <<"msg">>)),
                        
                        ?assertEqual([], stats_hero:snapshot(<<"unknown">>, all)),

                        ?assertEqual(not_found,
                                     stats_hero:report_metrics(<<"unknown">>, 404))
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
                              GotKeys = lists:sort(proplists:get_keys(Got)),
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
               {"upd is captured",
                fun() ->
                        {MsgCount, Msg} = capture_udp:read(),
                        ?assertEqual(2, MsgCount),
                        [GotStart, GotEnd] = [ parse_shp(M) || M <- Msg ],
                        ExpectStart = 
                            [{<<"test_hero.application.byOrgName.orginc">>,<<"1">>,<<"m">>},
                             {<<"test_hero.application.allRequests">>,<<"1">>,<<"m">>},
                             {<<"test_hero.test-host.allRequests">>,<<"1">>,<<"m">>},
                             {<<"test_hero.application.byRequestType.nodes.PUT">>,<<"1">>,<<"m">>}],
                        ?assertEqual(GotStart, ExpectStart),
                        %% For the end metrics, we can't rely on the
                        %% actual timing data, but can verify labels
                        %% and types.
                        ExpectEnd = 
                            [{<<"test_hero.application.byStatusCode.200">>,<<"1">>,<<"m">>},
                             {<<"test_hero.test-host.byStatusCode.200">>,<<"1">>,<<"m">>},
                             {<<"test_hero.application.byOrgName.orginc">>,<<"109">>,<<"h">>},
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
                end}
              ]
      end
     }.


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
            
