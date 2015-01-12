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

-module(capture_udp).

-behaviour(gen_server).
-define(SERVER, ?MODULE).

-define(to_int(Value), list_to_integer(binary_to_list(Value))).

-export([peek/0,
         read/0,
         read_at_least/1,
         start_link/1,
         stop/0,
         what_port/0]).

%% ------------------------------------------------------------------
%% gen_server Function Exports
%% ------------------------------------------------------------------

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2,
         code_change/3]).

-record(state, {port          :: non_neg_integer(),
                socket        :: inet:socket(),
                msg_count = 0 :: non_neg_integer(),
                buffer = []   :: iolist()
               }).

%% ------------------------------------------------------------------
%% API Function Definitions
%% ------------------------------------------------------------------

-spec start_link(non_neg_integer()) -> {ok, pid()} | {error, any()}.
%% @doc Start a UDP capture server listening on `Port'. If `Port' is
%% `0', the system will assign a usable port which you can later
%% discover using {@link capture_udp:what_port/0}.
start_link(Port) ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, Port, []).

stop() ->
    gen_server:call(?SERVER, stop).

-spec what_port() -> {ok, non_neg_integer()}.
%% @doc Return the port this server is listening on.
what_port() ->
    gen_server:call(?SERVER, what_port).

-spec peek() -> {non_neg_integer(), iolist()}.
%% @doc Return the count and collected message iolist for the server.
%% The server state is not modified.
%% @see capture_udp:read/0
peek() ->
    gen_server:call(?SERVER, peek).

-spec read() -> {non_neg_integer(), iolist()}.
%% @doc Return the message count and collected message iolist for the server.
%% Calling this function resets the message buffer and message counter.
%% @see capture_udp:peek/0
read() ->
    gen_server:call(?SERVER, read).

-spec read_at_least(non_neg_integer()) -> {non_neg_integer(), iolist()}.
read_at_least(Num) ->
    {Count, List} = read(),
    case Count of
        N when N < Num ->
            {NCount, NList} = read_at_least(Num - N),
            {Count + NCount, lists:append(List, NList)};
        _ ->
            {Count, List}
    end.



%% ------------------------------------------------------------------
%% gen_server Function Definitions
%% ------------------------------------------------------------------

init(Port) ->
    RecBuf = 524288,
    error_logger:info_msg("echo_udp listening on ~p with recbuf ~p~n", [Port, RecBuf]),
    {ok, Socket} = gen_udp:open(Port, [binary, {active, once},
                                       {recbuf, RecBuf}]),
    {ok, #state{port = Port, socket = Socket}}.

handle_call(peek, _From, #state{msg_count = Count, buffer = Buffer}=State) ->
    {reply, {Count, lists:reverse(Buffer)}, State};
handle_call(read, _From, #state{msg_count = Count, buffer = Buffer}=State) ->
    {reply, {Count, lists:reverse(Buffer)}, State#state{msg_count = 0, buffer = []}};
handle_call(what_port, _From, #state{socket = Sock}=State) ->
    {reply, inet:port(Sock), State};
handle_call(stop, _From, State) ->
    {stop, normal, ok, State};
handle_call(_Request, _From, State) ->
    {noreply, ok, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({udp, Socket, _Host, _Port, Bin},
            #state{buffer = Buffer, msg_count = Count}=State) ->
    inet:setopts(Socket, [{active, once}]),
    {noreply, State#state{msg_count = Count + 1, buffer = [Bin|Buffer]}};
handle_info(_Msg, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
