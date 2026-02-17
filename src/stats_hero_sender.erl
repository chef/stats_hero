%% -*- erlang-indent-level: 4;indent-tabs-mode: nil; fill-column: 92 -*-
%% ex: ts=4 sw=4 et
%% @author Seth Falcon <seth@chef.io>
%% @doc stats_hero_sender gen_server to send metrics over UDP
%%
%% @end
%% Copyright (c) 2012-2022 Progress Software Corporation and/or its subsidiaries or affiliates. All Rights Reserved.
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


-module(stats_hero_sender).
-behaviour(gen_server).

%% API
-export([send/1,
         send/2,
         start_link/1]).

%% gen_server callbacks
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

-define(SERVER, ?MODULE).
%% Helper macro for extracting values from proplists; crashes if key not found
-define(gv(Key, PL), element(2, lists:keyfind(Key, 1, PL))).

-include("stats_hero_sender.hrl").

-record(state, {
          host        :: string(),
          port        :: non_neg_integer(),
          send_socket :: inet:socket()
         }).

-spec send(pid(), iolist(), estatsd|statsd) -> ok | {error, term()}.
%% @doc Send `Payload' as a Stats Hero Protocol (SHP) version 1 UDP packet to the estatsd
%% server configured for this sender. The input Should be the bare metrics without SHP
%% header. This function will compute the length and add the SHP version and length header
%% to the payload.
send(Pid, Payload, estatsd) ->
    Length = iolist_size(Payload),
    Packet = io_lib:format("1|~B~n~s", [Length, Payload]),
    gen_server:call(Pid, {send, Packet});
send(Pid, Payload, statsd) ->
    Packet = io_lib:format("~s", [Payload]),
    gen_server:call(Pid, {send, Packet}).

-spec send(iolist(), estatsd|statsd) -> ok | {error, term()}.
%% @doc Send `Payload' as in `send/2' but uses the pg group to find a sender.
send(Payload, Protocol) ->
    case pg:get_local_members(?SH_SENDER_POOL) of
        []        -> {error, "no processes in process group"};
        [Pid | _] -> send(Pid, Payload, Protocol)
    end.

-spec send(iolist()) -> ok | {error, term()}.
send(Payload) ->
    send(Payload, estatsd).

%% @doc Start your personalized stats_hero process.
%%
%% `Config' is a proplist with keys: estatsd_host and estatsd_port.
%%
start_link(Config) ->
    %% this server is intended to be part of a pg pool, so we
    %% avoid registering by name.
    gen_server:start_link(?MODULE, Config, []).

%%
%% callbacks
%%

init(Config) ->
    {ok, Socket} = gen_udp:open(0),
    %% assumes that the sender pool has been created
    ok = pg:join(?SH_SENDER_POOL, self()),
    State = #state{host = ?gv(estatsd_host, Config),
                   port = ?gv(estatsd_port, Config),
                   send_socket = Socket},
    {ok, State}.

handle_call({send, Packet}, _From, #state{host = Host,
                                          port = Port,
                                          send_socket = Socket}=State) ->
    %% If we get an error sending the data, this server stops
    case gen_udp:send(Socket, Host, Port, Packet) of
        ok -> {reply, ok, State};
        Error -> {stop, udp_send_failed, Error, State}
    end;
handle_call(_, _From, State) ->
    {reply, unhandled, State}.

handle_cast(_Request, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
