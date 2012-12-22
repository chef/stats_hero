

#Module stats_hero_sender#
* [Description](#description)
* [Function Index](#index)
* [Function Details](#functions)


stats_hero_sender gen_server to send metrics over UDP.

__Behaviours:__ [`gen_server`](gen_server.md).

__Authors:__ Seth Falcon ([`seth@opscode.com`](mailto:seth@opscode.com)).<a name="index"></a>

##Function Index##


<table width="100%" border="1" cellspacing="0" cellpadding="2" summary="function index"><tr><td valign="top"><a href="#code_change-3">code_change/3</a></td><td></td></tr><tr><td valign="top"><a href="#handle_call-3">handle_call/3</a></td><td></td></tr><tr><td valign="top"><a href="#handle_cast-2">handle_cast/2</a></td><td></td></tr><tr><td valign="top"><a href="#handle_info-2">handle_info/2</a></td><td></td></tr><tr><td valign="top"><a href="#init-1">init/1</a></td><td></td></tr><tr><td valign="top"><a href="#send-1">send/1</a></td><td>Send <code>Payload</code> as in <code>send/2</code> but uses the pg2 group to find a sender.</td></tr><tr><td valign="top"><a href="#send-2">send/2</a></td><td>Send <code>Payload</code> as a Stats Hero Protocol (SHP) version 1 UDP packet to the estatsd
server configured for this sender.</td></tr><tr><td valign="top"><a href="#start_link-1">start_link/1</a></td><td>Start your personalized stats_hero process.</td></tr><tr><td valign="top"><a href="#terminate-2">terminate/2</a></td><td></td></tr></table>


<a name="functions"></a>

##Function Details##

<a name="code_change-3"></a>

###code_change/3##


`code_change(OldVsn, State, Extra) -> any()`

<a name="handle_call-3"></a>

###handle_call/3##


`handle_call(X1, From, State) -> any()`

<a name="handle_cast-2"></a>

###handle_cast/2##


`handle_cast(Request, State) -> any()`

<a name="handle_info-2"></a>

###handle_info/2##


`handle_info(Info, State) -> any()`

<a name="init-1"></a>

###init/1##


`init(Config) -> any()`

<a name="send-1"></a>

###send/1##


<pre>send(Payload::iolist()) -&gt; ok | {error, term()}</pre>
<br></br>


Send `Payload` as in `send/2` but uses the pg2 group to find a sender.<a name="send-2"></a>

###send/2##


<pre>send(Pid::pid(), Payload::iolist()) -&gt; ok | {error, term()}</pre>
<br></br>


Send `Payload` as a Stats Hero Protocol (SHP) version 1 UDP packet to the estatsd
server configured for this sender. The input Should be the bare metrics without SHP
header. This function will compute the length and add the SHP version and length header
to the payload.<a name="start_link-1"></a>

###start_link/1##


`start_link(Config) -> any()`



Start your personalized stats_hero process.

`Config` is a proplist with keys: estatsd_host and estatsd_port.
<a name="terminate-2"></a>

###terminate/2##


`terminate(Reason, State) -> any()`

