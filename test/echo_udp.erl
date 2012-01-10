-module(echo_udp).

-behaviour(gen_server).
-define(SERVER, ?MODULE).

-define(to_int(Value), list_to_integer(binary_to_list(Value))).

-export([start_link/1]).

%% ------------------------------------------------------------------
%% gen_server Function Exports
%% ------------------------------------------------------------------

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2,
         code_change/3]).

%% ------------------------------------------------------------------
%% API Function Definitions
%% ------------------------------------------------------------------

start_link(Port) ->
    gen_server:start_link(?MODULE, Port, []).

%% ------------------------------------------------------------------
%% gen_server Function Definitions
%% ------------------------------------------------------------------
-record(state, {port          :: non_neg_integer(),
                socket        :: inet:socket()
               }).

init(Port) ->
    RecBuf = 524288,
    error_logger:info_msg("echo_udp listening on ~p with recbuf ~p~n", [Port, RecBuf]),
    {ok, Socket} = gen_udp:open(Port, [binary, {active, once},
                                       {recbuf, RecBuf}]),
    {ok, #state{port = Port, socket = Socket}}.

handle_call(_Request, _From, State) ->
    {noreply, ok, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.


handle_info({udp, Socket, _Host, _Port, Bin}, State) ->
    inet:setopts(Socket, [{active, once}]),
    io:format("~s~n", [Bin]),
    {noreply, State};
handle_info(_Msg, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
