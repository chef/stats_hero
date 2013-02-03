

# Module stats_hero_monitor #
* [Description](#description)
* [Function Index](#index)
* [Function Details](#functions)


The stats_hero_monitor monitors stats_hero worker processes.
__Behaviours:__ [`gen_server`](gen_server.md).

__Authors:__ Seth Falcon ([`seth@opscode.com`](mailto:seth@opscode.com)).
<a name="description"></a>

## Description ##


Its Goal in life is to make sure the stats_hero worker processes don't leave any cruft
behind in the ETS table that keeps track of the `request_id <=> pid` mapping.  @end<a name="index"></a>

## Function Index ##


<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#code_change-3">code_change/3</a></td><td></td></tr><tr><td valign="top"><a href="#handle_call-3">handle_call/3</a></td><td></td></tr><tr><td valign="top"><a href="#handle_cast-2">handle_cast/2</a></td><td></td></tr><tr><td valign="top"><a href="#handle_info-2">handle_info/2</a></td><td></td></tr><tr><td valign="top"><a href="#init-1">init/1</a></td><td></td></tr><tr><td valign="top"><a href="#register-1">register/1</a></td><td>Register <code>Pid</code> as a stats_hero worker process that needs monitoring.</td></tr><tr><td valign="top"><a href="#registered_count-0">registered_count/0</a></td><td>Return the number of stats_hero worker processes currently registered.</td></tr><tr><td valign="top"><a href="#start_link-0">start_link/0</a></td><td>Start the stats_hero_monitor process.</td></tr><tr><td valign="top"><a href="#terminate-2">terminate/2</a></td><td></td></tr></table>


<a name="functions"></a>

## Function Details ##

<a name="code_change-3"></a>

### code_change/3 ###

`code_change(OldVsn, State, Extra) -> any()`


<a name="handle_call-3"></a>

### handle_call/3 ###

`handle_call(X1, From, State) -> any()`


<a name="handle_cast-2"></a>

### handle_cast/2 ###

`handle_cast(Request, State) -> any()`


<a name="handle_info-2"></a>

### handle_info/2 ###

`handle_info(Info, State) -> any()`


<a name="init-1"></a>

### init/1 ###

`init(X1) -> any()`


<a name="register-1"></a>

### register/1 ###


```
register(Pid::pid()) -&gt; ok
```

<br></br>


Register `Pid` as a stats_hero worker process that needs monitoring.  When the
process associated with `Pid` exists, the `stats_hero_monitor` with receive a `DOWN`
message and will call [`stats_hero:clean_worker_data/1`](stats_hero.md#clean_worker_data-1) to remove the worker's
entries from the shared ETS table.

<a name="registered_count-0"></a>

### registered_count/0 ###


```
registered_count() -&gt; non_neg_integer()
```

<br></br>


Return the number of stats_hero worker processes currently registered

<a name="start_link-0"></a>

### start_link/0 ###

`start_link() -> any()`

Start the stats_hero_monitor process.

<a name="terminate-2"></a>

### terminate/2 ###

`terminate(Reason, State) -> any()`


