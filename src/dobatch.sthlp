{smcl}
{hi:help dobatch}
{hline}
{title:Title}

{p 4 4 2}{cmd:dobatch} {hline 2} Run a do-file in batch mode in the background.


{title:Syntax}

{p 8 14 2}{cmd:dobatch} {it:filename} [{it:arguments}] [, {bf:nostop}]

{p 4 4 2}where

{p 8 14 2}{it: filename} is a standard text file. {cmd:dobatch} follows the same syntax as {help do:do}.


{title:Description}

{p 4 4 2}{cmd:dobatch} runs {it:filename} in batch mode in the background, allowing multiple do-files to execute in parallel.
It requires Stata MP and a Unix-based system.
Before execution, {cmd:dobatch} monitors system resources to ensure sufficient CPU availability and to prevent an excessive number of active Stata processes.
Specifically, {cmd:dobatch} waits to run the do-file until there are enough free CPU cores and no more than a certain number of active Stata jobs.
If the system is busy, {cmd:dobatch} waits for 5 minutes and then checks the system resources again.
The default requirements for system resources are calculated as follows:

{p 8 14 2}{it:MIN_CPUS_AVAILABLE} = max(c(processors_lic) - 1, 1)

{p 8 14 2}{it:MAX_STATA_JOBS} = c(processors_mach) / c(processors_lic) + 1

{p 4 4 2}For example, suppose you are running Stata MP 8 on a server with 64 processors. 
{cmd:dobatch} will not run the do-file until there are at least 7 available cores and fewer than 9 active Stata MP processes.


{title:Options}

{p 4 4 2}{bf:nostop} allows the do-file to continue executing even if an error occurs.
Normally, Stata stops executing the do-file when it detects an error (nonzero return code).

{p 4 4 2}The following global macros can be used to adjust the default settings:

{p 8 14 2} DOBATCH_MIN_CPUS_AVAILABLE: minimum number of CPUs that must be free before the do-file starts

{p 8 14 2} DOBATCH_MAX_STATA_JOBS: maximum number of active Stata MP jobs allowed

{p 8 14 2} DOBATCH_WAIT_TIME_MINS: time interval (in minutes) before checking CPU availability and active Stata jobs again

{p 8 14 2} DOBATCH_DISABLE: if set equal to 1, causes {cmd:dobatch} to act like {cmd:do}


{title:Author}

{p 4 4 2}Julian Reif, University of Illinois

{p 4 4 2}jreif@illinois.edu


{title:Also see}

{p 4 4 2}{help rscript:rscript} (if installed)

