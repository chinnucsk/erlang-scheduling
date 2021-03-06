%% Author: emilio
%% Created: 2 oct. 2012
%% Description: TODO: Add description to trace_writer
-module(prof2paje).

%%
%% Include files
%%

%%
%% Exported Functions
%%
-export([convert/1, convert/2]).

-import(utils, [to_int/1, to_string/1]).

%%
%% API Functions
%%

convert ([InputFileName, OutputFileName]) ->
	convert (to_string(InputFileName), to_string(OutputFileName)).

convert (InputFileName, OutputFileName) ->
	{ok, InFile} = file:open(InputFileName, [read]),
	{ok, OutFile} = file:open(OutputFileName, [read, write]),
	MaxScheduler = find_max_scheduler(InFile),
	writeHeader(OutFile, MaxScheduler),
	file:position(InFile, bof),
	process_file(InFile, OutFile),
	file:close(InFile),
	file:close(OutFile).
	
%%
%% Local Functions
%%
find_max_scheduler(File) ->
	find_max_scheduler(File, -1).

find_max_scheduler (File, MaxScheduler) ->
	case file:read_line(File) of
		{ok, Line} ->
			Event = string:tokens(Line, "\t "),
			NMaxScheduler = max (MaxScheduler, 
				case Event of
					["A", S, _] -> utils:to_int(S);
					["I", S, _] -> utils:to_int(S);
					["CB", S, _] -> utils:to_int(S);
					["WS", S, _] -> utils:to_int(S);
					["M", _, SFrom, Sto, _] -> max (utils:to_int(SFrom), utils:to_int(Sto));
					_ -> -1
				end),						
			find_max_scheduler(File, NMaxScheduler);
		 eof -> 
			MaxScheduler
	end.

process_file(InFile, OutFile) ->
	process_file(InFile, OutFile, 1).

process_file(InFile, OutFile, Cont) ->
	case file:read_line(InFile) of
		{ok, Line} ->
			Event = string:tokens(Line, "\t "),
			NCont = writeEvent(OutFile, Event, Cont),						
			process_file(InFile, OutFile, NCont);
		 eof -> 
			ok
	end.


writeHeader (File, MaxScheduler) when is_integer(MaxScheduler) ->
	H1 = [		
		"%EventDef PajeDefineContainerType 1",
		"% Alias string", 
		"% ContainerType string", 
		"% Name string", 
		"%EndEventDef", 
		"%EventDef PajeDefineStateType 2",
		"% Alias string", 
		"% ContainerType string", 
		"% Name string", 
		"%EndEventDef", 
		"%EventDef PajeDefineEntityValue 3",
		"% Alias string",  
		"% EntityType string",  
		"% Name string",  
		"% Color color", 
		"%EndEventDef",  
		"%EventDef PajeCreateContainer 4",
		"% Time date",  
		"% Alias string",  
		"% Type string",  
		"% Container string",  
		"% Name string",  
		"%EndEventDef",  
		"%EventDef PajeSetState 10",
		"% Time date",  
		"% Type string",  
		"% Container string",  
		"% Value string",  
		"%EndEventDef",
		
		"%EventDef PajeDefineEventType		20",
		"% 	  Alias 	string",            
		"% 	  ContainerType string",            
		"% 	  Name 		string",            
		"%EndEventDef",     
		"%EventDef PajeNewEvent			21",
		"% 	  Time          date",              
		"% 	  Type 		string",            
		"% 	  Container 	string",            
		"% 	  Value         string",            
		"%EndEventDef", 
		
		"%EventDef PajeDefineLinkType		41",
		"% 	  Alias               string",      
		"% 	  Name 		      string",      
		"% 	  ContainerType	      string",      
		"% 	  SourceContainerType string",      
		"% 	  DestContainerType   string",      
		"%EndEventDef",
		"%EventDef PajeStartLink	       	42",
		"%	  Time 		  date",            
		"%	  Type 		  string",          
		"%	  Container 	  string",          
		"%	  SourceContainer string",          
		"%	  Value 	  string",          
		"%	  Key 		  string",          
		"%EndEventDef",                             
		"%EventDef PajeEndLink			43",
		"% 	  Time          date",              
		"% 	  Type 		string",            
		"% 	  Container 	string",            
		"% 	  DestContainer string",            
		"% 	  Value 	string",            
		"% 	  Key 		string",            
		"%EndEventDef", 
	
		"1 VM 0 'Erlang VM'",
		"1 S VM 'Scheduler'",
		"2 SS S 'Scheduler State'",
		"3 A SS 'Active'    '1.0 0.5 0.5'",
		"3 I SS 'Inactive'  '0.5 0.5 0.5'",
		"4 0.000000 VM VM 0 'Erlang VM'",
		"20 CB VM 'Check-Balance'", 
		"20 WS S 'Work-Stealing'",
		"20 IPS VM 'Initial Placement Strategy Change'", 
		"20 CBS VM 'Check Balance Strategy Change'",
		"20 WSS VM 'Work Stealing Strategy Change'",
		"41 Mig Migration VM S S"
	],
	
	[io:fwrite(File, "~s~n", [Line]) || Line <- H1],
	[io:fwrite(File, "4 0.000000 S~p S VM 'Scheduler ~p'~n", [Sched, Sched]) || Sched <- lists:seq(1, MaxScheduler)],
	
	H2 = [		
		"4 0.000000 CB S VM 'Check Balance'",
		"4 0.000000 SC S VM 'Strategy Changes'"],
	[io:fwrite(File, "~s~n", [Line]) || Line <- H2],
	ok. 


%Check-Balance
writeEvent(File, ["CB", Scheduler, When], Cont) ->
	io:fwrite(File, "21 ~p CB CB ~p~n", [to_int(When)/1000000000, Scheduler]),
	Cont;
%Work-Stealing
writeEvent(File, ["WS", Scheduler, When], Cont) ->
	io:fwrite(File, "21 ~p WS S~s ~p~n", [to_int(When)/1000000000, Scheduler, 0]),
	Cont;
%IPS
writeEvent(File, ["IPS", Strategy, When], Cont) ->
	io:fwrite(File, "21 ~p IPS SC ~p~n", [to_int(When)/1000000000, Strategy]),
	Cont;
%CBS
writeEvent(File, ["CBS", Strategy, When], Cont) ->
	io:fwrite(File, "21 ~p CBS SC ~p~n", [to_int(When)/1000000000, Strategy]),
	Cont;
%WSS
writeEvent(File, ["WSS", Strategy, When], Cont) ->
	io:fwrite(File, "21 ~p WSS SC ~p~n", [to_int(When)/1000000000, Strategy]),
	Cont;
%Spawn
writeEvent(_File, ["S", _Process, _When], Cont) ->
	%Ignore spawns for the time being
	Cont;
%Scheduler Active/Inactive
writeEvent(File, [State, Scheduler, When], Cont) -> %State = A or I
	io:fwrite(File, "10 ~p SS S~s ~s~n", [to_int(When)/1000000000, Scheduler, State]),
	Cont;
%Process Migration
writeEvent(File, ["M", _, From, To, When], Cont) ->
	NWhen = to_int(When) / 1000000000,
	Bit = 0.0000000001,
	io:fwrite(File, "42 ~p Mig VM S~s ~p ~p~n", [NWhen, From, Cont, Cont]),
	io:fwrite(File, "43 ~p Mig VM S~s ~p ~p~n", [NWhen + Bit, To, Cont, Cont]),
	Cont + 1.
