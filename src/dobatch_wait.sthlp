{smcl}
{hi:help dobatch_wait}
{hline}
{title:Title}

{p 4 4 2}{cmd:dobatch_wait} {hline 2} Wait for do-file batch processes to complete.


{title:Syntax}

{p 8 14 2}{cmd:dobatch_wait} [, {cmd:pid(}{help numlist:numlist}{cmd:)}]


{title:Description}

{p 4 4 2}{cmd:dobatch_wait} temporarily pauses the current Stata session until prior Stata batch processes launched by {help dobatch:dobatch} have finished running. It operates in one of two modes:

{p 8 8 2}- By default, when no {cmd:pid()} option is provided, the command waits for all process identifiers (PIDs) stored in the global macro {it:DOBATCH_STATA_PID} to complete.
This macro contains a list of the PIDs of all do-files launched by {help dobatch:dobatch}.
If {it:DOBATCH_STATA_PID} is undefined, {cmd:dobatch_wait} waits for all other active Stata MP processes to complete.
Once the waiting is over, {cmd:dobatch_wait} clears the contents of {it:DOBATCH_STATA_PID}.

{p 8 8 2}- Otherwise, if the user supplies one or more PIDs via {cmd:pid(}{help numlist:numlist}{cmd:)}, {cmd:dobatch_wait} will pause until each of the specified processes has terminated. These PIDs are not restricted to Stata MP processes.

{p 4 4 2}{cmd:dobatch_wait} requires a Unix-based system.


{title:Options}

{p 4 4 2}{cmd:pid(}{help numlist:numlist}{cmd:)} specifies one or more process identifiers (PIDs), which are unique numbers assigned by the operating system to each process.
When this option is used, {cmd:dobatch_wait} pauses Stata until all specified PIDs have terminated.
Note: the stored result {cmd:r(PID)} from {help dobatch:dobatch} contains the PID of do-files launched with that command.

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

{title:Also see}

{p 4 4 2}{help dobatch:dobatch}

{p 4 4 2}{help rscript:rscript} (if installed)
