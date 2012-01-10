%% -*- erlang-indent-level: 4;indent-tabs-mode: nil; fill-column: 92 -*-
%% ex: ts=4 sw=4 et
%% @author Seth Falcon <seth@opscode.com>
%% @copyright 2012 Opscode Inc.
%% @doc The stats_hero_monitor monitors stats_hero worker processes
%%
%% Its Goal in life is to make sure the stats_hero worker processes don't leave any cruft
%% behind in the ETS table that keeps track of the `request_id <=> pid' mapping.  @end
%% @end
-module(stats_hero_monitor).
-behaviour(gen_server).

%% API
-export([register/1,
         registered_count/0,
         start_link/0]).

%% gen_server callbacks
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

-define(SERVER, ?MODULE).

-record(state, { count = 0 :: non_neg_integer() }).

-spec register(pid()) -> ok.
%% @doc Register `Pid' as a stats_hero worker process that needs monitoring.  When the
%% process associated with `Pid' exists, the `stats_hero_monitor' with receive a `DOWN'
%% message and will call {@link stats_hero:clean_worker_data/1} to remove the worker's
%% entries from the shared ETS table.
%%
register(Pid) ->
    gen_server:call(?SERVER, {register, Pid}).

-spec registered_count() -> non_neg_integer().
%% @doc Return the number of stats_hero worker processes currently registered
%%
registered_count() ->
    gen_server:call(?SERVER, registered_count).

%% @doc Start the stats_hero_monitor process.
%%
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%%
%% callbacks
%%

init([]) ->
    State = #state{count = 0},
    {ok, State}.

handle_call({register, Pid}, _From, #state{count = Count}=State) ->
    erlang:monitor(process, Pid),
    %% The pid <=> reqid mapping should be 1:1. It is possible, thourgh misuse, for a given
    %% request id to be mapped to more than one pid and in this case there will be the
    %% possibility of data getting orphaned in the ETS table.
    {reply, ok, State#state{count = Count + 1}};
handle_call(registered_count, _From, #state{count = Count}=State) ->
    {reply, Count, State};
handle_call(_, _From, State) ->
    {reply, unhandled, State}.

handle_cast(_Request, State) ->
    {noreply, State}.

handle_info({'DOWN', _MonRef, process, Pid, _Info}, #state{count = Count}=State) ->
    stats_hero:clean_worker_data(Pid),
    {noreply, State#state{count = Count - 1}};
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

