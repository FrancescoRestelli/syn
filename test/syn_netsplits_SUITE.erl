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
-module(syn_netsplits_SUITE).

%% callbacks
-export([all/0]).
-export([init_per_suite/1, end_per_suite/1]).
-export([groups/0, init_per_group/2, end_per_group/2]).
-export([init_per_testcase/2, end_per_testcase/2]).

%% tests
-export([
    two_nodes_netsplit_when_there_are_no_conflicts/1,
    two_nodes_netsplit_kill_resolution_when_there_are_conflicts/1,
    two_nodes_netsplit_message_resolution_when_there_are_conflicts/1
]).

%% include
-include_lib("common_test/include/ct.hrl").


%% ===================================================================
%% Callbacks
%% ===================================================================

%% -------------------------------------------------------------------
%% Function: all() -> GroupsAndTestCases | {skip,Reason}
%% GroupsAndTestCases = [{group,GroupName} | TestCase]
%% GroupName = atom()
%% TestCase = atom()
%% Reason = term()
%% -------------------------------------------------------------------
all() ->
    [
        {group, two_nodes_netsplits}
    ].

%% -------------------------------------------------------------------
%% Function: groups() -> [Group]
%% Group = {GroupName,Properties,GroupsAndTestCases}
%% GroupName = atom()
%% Properties = [parallel | sequence | Shuffle | {RepeatType,N}]
%% GroupsAndTestCases = [Group | {group,GroupName} | TestCase]
%% TestCase = atom()
%% Shuffle = shuffle | {shuffle,{integer(),integer(),integer()}}
%% RepeatType = repeat | repeat_until_all_ok | repeat_until_all_fail |
%%			   repeat_until_any_ok | repeat_until_any_fail
%% N = integer() | forever
%% -------------------------------------------------------------------
groups() ->
    [
        {two_nodes_netsplits, [shuffle], [
            two_nodes_netsplit_when_there_are_no_conflicts,
            two_nodes_netsplit_kill_resolution_when_there_are_conflicts,
            two_nodes_netsplit_message_resolution_when_there_are_conflicts
        ]}
    ].
%% -------------------------------------------------------------------
%% Function: init_per_suite(Config0) ->
%%				Config1 | {skip,Reason} |
%%              {skip_and_save,Reason,Config1}
%% Config0 = Config1 = [tuple()]
%% Reason = term()
%% -------------------------------------------------------------------
init_per_suite(Config) ->
    %% init
    SlaveNodeShortName = syn_slave,
    %% start slave
    {ok, SlaveNodeName} = syn_test_suite_helper:start_slave(SlaveNodeShortName),
    %% config
    [
        {slave_node_short_name, SlaveNodeShortName},
        {slave_node_name, SlaveNodeName}
        | Config
    ].

%% -------------------------------------------------------------------
%% Function: end_per_suite(Config0) -> void() | {save_config,Config1}
%% Config0 = Config1 = [tuple()]
%% -------------------------------------------------------------------
end_per_suite(Config) ->
    %% get slave node name
    SlaveNodeShortName = proplists:get_value(slave_node_short_name, Config),
    %% stop slave
    syn_test_suite_helper:stop_slave(SlaveNodeShortName).

%% -------------------------------------------------------------------
%% Function: init_per_group(GroupName, Config0) ->
%%				Config1 | {skip,Reason} |
%%              {skip_and_save,Reason,Config1}
%% GroupName = atom()
%% Config0 = Config1 = [tuple()]
%% Reason = term()
%% -------------------------------------------------------------------
init_per_group(_GroupName, Config) -> Config.

%% -------------------------------------------------------------------
%% Function: end_per_group(GroupName, Config0) ->
%%				void() | {save_config,Config1}
%% GroupName = atom()
%% Config0 = Config1 = [tuple()]
%% -------------------------------------------------------------------
end_per_group(_GroupName, _Config) -> ok.

% ----------------------------------------------------------------------------------------------------------
% Function: init_per_testcase(TestCase, Config0) ->
%				Config1 | {skip,Reason} | {skip_and_save,Reason,Config1}
% TestCase = atom()
% Config0 = Config1 = [tuple()]
% Reason = term()
% ----------------------------------------------------------------------------------------------------------
init_per_testcase(_TestCase, Config) ->
    %% get slave
    SlaveNodeName = proplists:get_value(slave_node_name, Config),
    %% set schema location
    application:set_env(mnesia, schema_location, ram),
    rpc:call(SlaveNodeName, mnesia, schema_location, [ram]),
    %% start syn
    ok = syn:start(),
    ok = rpc:call(SlaveNodeName, syn, start, []),
    timer:sleep(100),
    Config.

% ----------------------------------------------------------------------------------------------------------
% Function: end_per_testcase(TestCase, Config0) ->
%				void() | {save_config,Config1} | {fail,Reason}
% TestCase = atom()
% Config0 = Config1 = [tuple()]
% Reason = term()
% ----------------------------------------------------------------------------------------------------------
end_per_testcase(_TestCase, Config) ->
    %% get slave
    SlaveNodeName = proplists:get_value(slave_node_name, Config),
    syn_test_suite_helper:clean_after_test(SlaveNodeName).

%% ===================================================================
%% Tests
%% ===================================================================
two_nodes_netsplit_when_there_are_no_conflicts(Config) ->
    %% get slave
    SlaveNodeName = proplists:get_value(slave_node_name, Config),
    CurrentNode = node(),

    %% start processes
    LocalPid = syn_test_suite_helper:start_process(),
    SlavePidLocal = syn_test_suite_helper:start_process(SlaveNodeName),
    SlavePidSlave = syn_test_suite_helper:start_process(SlaveNodeName),

    %% register
    ok = syn:register(local_pid, LocalPid),
    ok = syn:register(slave_pid_local, SlavePidLocal),    %% slave registered on local node
    ok = rpc:call(SlaveNodeName, syn, register, [slave_pid_slave, SlavePidSlave]),    %% slave registered on slave node
    timer:sleep(100),

    %% check tables
    3 = mnesia:table_info(syn_processes_table, size),
    3 = rpc:call(SlaveNodeName, mnesia, table_info, [syn_processes_table, size]),

    LocalActiveReplicas = mnesia:table_info(syn_processes_table, active_replicas),
    2 = length(LocalActiveReplicas),
    true = lists:member(SlaveNodeName, LocalActiveReplicas),
    true = lists:member(CurrentNode, LocalActiveReplicas),

    SlaveActiveReplicas = rpc:call(SlaveNodeName, mnesia, table_info, [syn_processes_table, active_replicas]),
    2 = length(SlaveActiveReplicas),
    true = lists:member(SlaveNodeName, SlaveActiveReplicas),
    true = lists:member(CurrentNode, SlaveActiveReplicas),

    %% simulate net split
    syn_test_suite_helper:disconnect_node(SlaveNodeName),
    timer:sleep(1000),

    %% check tables
    1 = mnesia:table_info(syn_processes_table, size),
    [CurrentNode] = mnesia:table_info(syn_processes_table, active_replicas),

    %% reconnect
    syn_test_suite_helper:connect_node(SlaveNodeName),
    timer:sleep(1000),

    %% check tables
    3 = mnesia:table_info(syn_processes_table, size),
    3 = rpc:call(SlaveNodeName, mnesia, table_info, [syn_processes_table, size]),

    LocalActiveReplicas2 = mnesia:table_info(syn_processes_table, active_replicas),
    2 = length(LocalActiveReplicas2),
    true = lists:member(SlaveNodeName, LocalActiveReplicas2),
    true = lists:member(CurrentNode, LocalActiveReplicas2),

    SlaveActiveReplicas2 = rpc:call(SlaveNodeName, mnesia, table_info, [syn_processes_table, active_replicas]),
    2 = length(SlaveActiveReplicas2),
    true = lists:member(SlaveNodeName, SlaveActiveReplicas2),
    true = lists:member(CurrentNode, SlaveActiveReplicas2),

    %% check processes
    LocalPid = syn:find_by_key(local_pid),
    SlavePidLocal = syn:find_by_key(slave_pid_local),
    SlavePidSlave = syn:find_by_key(slave_pid_slave),

    LocalPid = rpc:call(SlaveNodeName, syn, find_by_key, [local_pid]),
    SlavePidLocal = rpc:call(SlaveNodeName, syn, find_by_key, [slave_pid_local]),
    SlavePidSlave = rpc:call(SlaveNodeName, syn, find_by_key, [slave_pid_slave]),

    %% kill processes
    syn_test_suite_helper:kill_process(LocalPid),
    syn_test_suite_helper:kill_process(SlavePidLocal),
    syn_test_suite_helper:kill_process(SlavePidSlave).

two_nodes_netsplit_kill_resolution_when_there_are_conflicts(Config) ->
    %% get slave
    SlaveNodeName = proplists:get_value(slave_node_name, Config),
    CurrentNode = node(),

    %% start processes
    LocalPid = syn_test_suite_helper:start_process(),
    SlavePid = syn_test_suite_helper:start_process(SlaveNodeName),

    %% register
    ok = syn:register(conflicting_key, SlavePid),
    timer:sleep(100),

    %% check tables
    1 = mnesia:table_info(syn_processes_table, size),
    1 = rpc:call(SlaveNodeName, mnesia, table_info, [syn_processes_table, size]),

    %% check process
    SlavePid = syn:find_by_key(conflicting_key),

    %% simulate net split
    syn_test_suite_helper:disconnect_node(SlaveNodeName),
    timer:sleep(1000),

    %% check tables
    0 = mnesia:table_info(syn_processes_table, size),
    [CurrentNode] = mnesia:table_info(syn_processes_table, active_replicas),

    %% now register the local pid with the same key
    ok = syn:register(conflicting_key, LocalPid),

    %% check process
    LocalPid = syn:find_by_key(conflicting_key),

    %% reconnect
    syn_test_suite_helper:connect_node(SlaveNodeName),
    timer:sleep(1000),

    %% check tables
    1 = mnesia:table_info(syn_processes_table, size),
    1 = rpc:call(SlaveNodeName, mnesia, table_info, [syn_processes_table, size]),

    %% check process
    FoundPid = syn:find_by_key(conflicting_key),
    true = lists:member(FoundPid, [LocalPid, SlavePid]),

    %% kill processes
    syn_test_suite_helper:kill_process(LocalPid),
    syn_test_suite_helper:kill_process(SlavePid).

two_nodes_netsplit_message_resolution_when_there_are_conflicts(Config) ->
    %% get slave
    SlaveNodeName = proplists:get_value(slave_node_name, Config),
    CurrentNode = node(),

    %% set resolution by message shutdown
    syn:options([{netsplit_conflicting_mode, {send_message, {self(), shutdown}}}]),

    %% start processes
    LocalPid = syn_test_suite_helper:start_process(),
    SlavePid = syn_test_suite_helper:start_process(SlaveNodeName),

    %% register
    ok = syn:register(conflicting_key, SlavePid),
    timer:sleep(100),

    %% check tables
    1 = mnesia:table_info(syn_processes_table, size),
    1 = rpc:call(SlaveNodeName, mnesia, table_info, [syn_processes_table, size]),

    %% check process
    SlavePid = syn:find_by_key(conflicting_key),

    %% simulate net split
    syn_test_suite_helper:disconnect_node(SlaveNodeName),
    timer:sleep(1000),

    %% check tables
    0 = mnesia:table_info(syn_processes_table, size),
    [CurrentNode] = mnesia:table_info(syn_processes_table, active_replicas),

    %% now register the local pid with the same key
    ok = syn:register(conflicting_key, LocalPid),

    %% check process
    LocalPid = syn:find_by_key(conflicting_key),

    %% reconnect
    syn_test_suite_helper:connect_node(SlaveNodeName),
    timer:sleep(1000),

    %% check tables
    1 = mnesia:table_info(syn_processes_table, size),
    1 = rpc:call(SlaveNodeName, mnesia, table_info, [syn_processes_table, size]),

    %% check process
    FoundPid = syn:find_by_key(conflicting_key),
    true = lists:member(FoundPid, [LocalPid, SlavePid]),

    %% check message received from killed pid
    KilledPid = lists:nth(1, lists:delete(FoundPid, [LocalPid, SlavePid])),
    receive
        {KilledPid, terminated} -> ok;
        Other -> ct:pal("WUT?? ~p", [Other])
    after 5 ->
        ok = not_received
    end,

    %% kill processes
    syn_test_suite_helper:kill_process(LocalPid),
    syn_test_suite_helper:kill_process(SlavePid).
