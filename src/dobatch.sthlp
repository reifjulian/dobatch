{smcl}
{hi:help dobatch}
{hline}
{title:Title}

{p 4 4 2}{cmd:dobatch} {hline 2} Run a dofile in batch mode in the background.


{title:Syntax}

{p 8 14 2}{cmd:dobatch} {it:filename} [{it:arguments}]

{p 4 4 2}where

{p 8 14 2}{it: filename} is a standard text file. If {it: filename} is specified without an extension, {bf:.do} is assumed.


{title:Description}

{p 4 4 2}{cmd:dobatch} runs {it:filename} in batch mode in the background, allowing multiple do-files to execute in parallel.
It requires Stata MP and a Unix-based system.
Before execution, {cmd:dobatch} checks server usage to ensure sufficient CPU availability and to prevent an excessive number of active Stata processes.


{title:Author}

{p 4 4 2}Julian Reif, University of Illinois

{p 4 4 2}jreif@illinois.edu


{title:Also see}

{p 4 4 2}{help rscript:rscript} (if installed)

