

# Module stats_hero_worker_sup #
* [Function Index](#index)
* [Function Details](#functions)

__Behaviours:__ [`supervisor`](supervisor.md).

__Authors:__ Seth Falcon ([`seth@opscode.com`](mailto:seth@opscode.com)), Kevin Smith ([`kevin@opscode.com`](mailto:kevin@opscode.com)), Oliver Ferrigni ([`oliver@opscode.com`](mailto:oliver@opscode.com)).
<a name="index"></a>

## Function Index ##


<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#init-1">init/1</a></td><td></td></tr><tr><td valign="top"><a href="#new_worker-1">new_worker/1</a></td><td>Start a new <code>stats_hero</code> worker.</td></tr><tr><td valign="top"><a href="#start_link-0">start_link/0</a></td><td></td></tr></table>


<a name="functions"></a>

## Function Details ##

<a name="init-1"></a>

### init/1 ###

`init(X1) -> any()`


<a name="new_worker-1"></a>

### new_worker/1 ###

`new_worker(InputConfig) -> any()`

Start a new `stats_hero` worker.`Config` is a proplist with keys: request_label,
request_action, estatsd_host, estatsd_port, upstream_prefixes, my_app, and
request_id.  {parent, self()} added to Config as this function is called from the
caller's process space.  The stats_hero worker will monitor the caller to avoid
possible process leaks if the caller crashes before cleaning up the worker.

__See also:__ [stats_hero:start_link/1](stats_hero.md#start_link-1).
<a name="start_link-0"></a>

### start_link/0 ###

`start_link() -> any()`


