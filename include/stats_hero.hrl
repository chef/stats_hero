%% -*- erlang-indent-level: 4;indent-tabs-mode: nil; fill-column: 92 -*-
%% ex: ts=4 sw=4 et
%% @author Seth Falcon <seth@opscode.com>
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

-define(SH_TIME(ReqId, Mod, Fun, Args),
        stats_hero:ctime(ReqId, {Mod, Fun},
                         fun() -> Mod:Fun Args end)).

