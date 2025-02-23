{smcl}
{hi:help dobatch_wait}
{hline}
{title:Title}

{p 4 4 2}{cmd:dobatch_wait} {hline 2} Wait for do-file batch processes to complete.


{title:Syntax}

{p 8 14 2}{cmd:dobatch_wait} [, {cmd:PID(}{help numlist:numlist}{cmd:)}]


{title:Description}

{p 4 4 2}{cmd:dobatch_wait} pauses the current Stata session and operates in one of two modes.

{p 8 8 2}- By default, it waits until all other Stata MP processes have completed.

{p 8 8 2}- If the user specifies {cmd:PID(}{help numlist:numlist}{cmd:)}, it instead waits until all specified PIDs have terminated.

{p 4 4 2}It requires a Unix-based system.


{title:Options}

{p 4 4 2}{cmd:PID(}{help numlist:numlist}{cmd:)} specifies one or more process identifiers (PIDs), which are unique numbers assigned by the operating system to each process.
When this option is used, {cmd:dobatch_wait} pauses Stata until all specified PIDs have terminated.
Note: The stored result {cmd:r(PID)} from {help dobatch:dobatch} contains the PID of do-files launched with that command.

{p 4 4 2}The following global macros can be used to adjust the default settings:

{p 8 14 2} DOBATCH_WAIT_TIME_MINS: time interval (in minutes) before checking for running processes again

{p 8 14 2} DOBATCH_DISABLE: if set equal to 1, {cmd:dobatch_wait} does nothing


{title:Stored results}

{p 4 4 2}{cmd:dobatch_wait} stores the following in {cmd: r()}:

{p 4 4 2}Scalars

{p 8 8 2}{cmd:r(WAIT_TIME_MINS)}     {space 5} WAIT_TIME_MINS parameter value


{title:Author}

{p 4 4 2}Julian Reif, University of Illinois

{p 4 4 2}jreif@illinois.edu

