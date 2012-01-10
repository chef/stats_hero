%% -*- erlang-indent-level: 4;indent-tabs-mode: nil; fill-column: 92 -*-
%% ex: ts=4 sw=4 et
%% @author Seth Falcon <seth@opscode.com>
%% @copyright 2012 Opscode Inc.

%% @doc Send timing data for Mod:Fun(Args) to the stats_hero worker
%% processes associated with `ReqId'.
%%
%% See documentation for stats_hero:ctimer/3 for details.
%% @end
%%
%% NB: we require a space between Mod:Fun and Args since we are
%% abusing the text replacement and expect Args to be of the form
%% '(arg1, arg2, ..., argN)'.
%% @end
-define(SH_TIME(ReqId, Mod, Fun, Args),
        stats_hero:ctime(ReqId, stats_hero:label(Mod, Fun),
                         fun() -> Mod:Fun Args end)).
