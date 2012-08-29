-module(capture_udp).

-behaviour(gen_server).
-define(SERVER, ?MODULE).

-define(to_int(Value), list_to_integer(binary_to_list(Value))).

-export([peek/0,
         read/0,
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
