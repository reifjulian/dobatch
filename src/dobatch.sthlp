{smcl}
{hi:help dobatch}
{hline}
{title:Title}

{p 4 4 2}{cmd:dobatch} {hline 2} Launch a do-file as a background batch process.


{title:Syntax}

{p 8 14 2}{cmd:dobatch} {it:filename} [{it:arguments}] [, {cmd:nostop}]

{p 4 4 2}where

{p 8 14 2}{it: filename} is a standard text file. {cmd:dobatch} follows the same syntax as {help do:do}.


{title:Description}

{p 4 4 2}{cmd:dobatch} runs {it:filename} as a background batch process, allowing multiple do-files to execute in parallel.
It requires Stata MP and a Unix-based system.
Before execution, {cmd:dobatch} checks system resources to ensure sufficient CPU availability and to limit the number of active Stata processes.
If the system is busy, {cmd:dobatch} waits for 5 minutes before checking again.
By default, the resource thresholds are defined as:

{p 8 14 2}{it:MIN_CPUS_AVAILABLE} = max(c(processors_lic) - 1, 1)

{p 8 14 2}{it:MAX_STATA_JOBS} = max( floor[c(processors_mach) / c(processors_lic)], 2)

{p 4 4 2}For example, on a server with 64 processors running Stata MP 8, {cmd:dobatch} will wait until at least 7 CPUs are free and fewer than 8 Stata MP processes are running.


{title:Options}

{p 4 4 2}{cmd:nostop} allows the do-file to continue executing even if an error occurs.
Normally, Stata stops executing the do-file when it detects an error (nonzero return code).

{p 4 4 2}The following global macros can be used to adjust the default settings:

{p 8 14 2} DOBATCH_MIN_CPUS_AVAILABLE: minimum number of CPUs that must be free before the do-file starts

{p 8 14 2} DOBATCH_MAX_STATA_JOBS: maximum number of active Stata MP jobs allowed

{p 8 14 2} DOBATCH_WAIT_TIME_MINS: time interval (in minutes) before checking CPU availability and background Stata jobs again. If the wait time is set to 0 minutes or less, {cmd:dobatch} does not monitor system resources.

{p 8 14 2} DOBATCH_DISABLE: if set equal to 1, {cmd:dobatch} behaves exactly like {help do:do} and runs the do-file in the foreground


{title:Stored results}

{p 4 4 2}{cmd:dobatch} stores the following in {cmd: r()}:

{p 4 4 2}Scalars

{p 8 8 2}{cmd:r(MIN_CPUS_AVAILABLE)} {space 1} {it:MIN_CPUS_AVAILABLE} threshold value

{p 8 8 2}{cmd:r(MAX_STATA_JOBS)}     {space 5} {it:MAX_STATA_JOBS} threshold value

{p 8 8 2}{cmd:r(WAIT_TIME_MINS)}     {space 5} number of minutes to wait between system resource checks

{p 8 8 2}{cmd:r(PID)}                {space 16} process identifier (PID) assigned by the operating system to the newly launched background job

{p 4 4 2}In addition, the PID is appended to the contents of the global macro DOBATCH_STATA_PID.


{title:Author}

{p 4 4 2}Julian Reif, University of Illinois

{p 4 4 2}jreif@illinois.edu


{title:Also see}

{p 4 4 2}{help dobatch_wait:dobatch_wait}

{p 4 4 2}{help rscript:rscript} (if installed)

