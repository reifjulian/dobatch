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
Before execution, {cmd:dobatch} checks server usage to ensure sufficient CPU availability and to prevent an excessive number of active Stata processes.
Specifically, {cmd:dobatch} waits to run the do-file until there are a minimum number of CPUs available and no more than a certain number of active Stata jobs.
The default values for these two requirements are set equal to:

{p 8 14 2} MIN_CPUS_AVAILABLE = max(c(processors_lic) - 1, 1)

{p 8 14 2} MAX_STATA_JOBS = c(processors_mach) / c(processors_lic) + 1


{title:Option}

{p 4 4 2}{bf:nostop} allows the do-file to continue executing even if an error occurs.
Normally, Stata stops executing the do-file when it detects an error (nonzero return code).


{title:Author}

{p 4 4 2}Julian Reif, University of Illinois

{p 4 4 2}jreif@illinois.edu


{title:Also see}

{p 4 4 2}{help rscript:rscript} (if installed)

