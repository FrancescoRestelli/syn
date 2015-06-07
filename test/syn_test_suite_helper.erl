%% ==========================================================================================================
%% Syn - A global process registry.
%%
%% Copyright (C) 2015, Roberto Ostinelli <roberto@ostinelli.net>.
%% All rights reserved.
%%
%% The MIT License (MIT)
%%
%% Copyright (c) 2015 Roberto Ostinelli
%%
%% Permission is hereby granted, free of charge, to any person obtaining a copy
%% of this software and associated documentation files (the "Software"), to deal
%% in the Software without restriction, including without limitation the rights
%% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
%% copies of the Software, and to permit persons to whom the Software is
%% furnished to do so, subject to the following conditions:
%%
%% The above copyright notice and this permission notice shall be included in
%% all copies or substantial portions of the Software.
%%
%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
%% THE SOFTWARE.
%% ==========================================================================================================
-module(syn_test_suite_helper).

%% API
-export([start_slave/1, stop_slave/1]).
-export([connect_node/1, disconnect_node/1]).
-export([clean_after_test/0, clean_after_test/1]).
-export([start_process/0, start_process/1, kill_process/1, process_main/0]).


%% ===================================================================
%% API
%% ===================================================================
start_slave(NodeShortName) ->
    EbinFilePath = filename:join([filename:dirname(code:lib_dir(syn, ebin)), "ebin"]),
    TestFilePath = filename:join([filename:dirname(code:lib_dir(syn, ebin)), "test"]),
    %% start slave
    {ok, NodeName} = ct_slave:start(NodeShortName, [
        {boot_timeout, 10},
        {erl_flags, lists:concat(["-pa ", EbinFilePath, " ", TestFilePath])}
    ]),
    {ok, NodeName}.

stop_slave(NodeShortName) ->
    {ok, _} = ct_slave:stop(NodeShortName).

connect_node(NodeName) ->
    net_kernel:connect_node(NodeName).

disconnect_node(NodeName) ->
    erlang:disconnect_node(NodeName).

clean_after_test() ->
    %% delete table
    {atomic, ok} = mnesia:delete_table(syn_processes_table),
    %% stop mnesia
    mnesia:stop(),
    %% delete schema
    mnesia:delete_schema([node()]),
    %% stop syn
    syn:stop().

clean_after_test(undefined) ->
    clean_after_test();
clean_after_test(NodeName) ->
    %% delete table
    {atomic, ok} = mnesia:delete_table(syn_processes_table),
    %% stop mnesia
    mnesia:stop(),
    rpc:call(NodeName, mnesia, stop, []),
    %% delete schema
    mnesia:delete_schema([node(), NodeName]),
    %% stop syn
    syn:stop(),
    rpc:call(NodeName, syn, stop, []).

start_process() ->
    Pid = spawn(?MODULE, process_main, []),
    Pid.

start_process(NodeName) ->
%%     Pid = rpc:call(NodeName, erlang, spawn, [?MODULE, process_main, []]),
    Pid = spawn(NodeName, ?MODULE, process_main, []),
    Pid.

kill_process(Pid) ->
    exit(Pid, kill).

process_main() ->
    receive
        {From, shutdown} -> From ! {self(), terminated}
    end.
