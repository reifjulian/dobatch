# DOBATCH: Run Stata do-files in parallel

- Current dobatch version: `1.0 4mar2025`
- Jump to:  [`overview`](#overview) [`quickstart`](#quickstart) [`examples`](#example-parallelizing-a-for-loop)
 [`advanced`](#advanced)  [`faq`](#faq) [`author`](#author)

-----------

## Overview

`dobatch` runs a do-file as a background batch process, allowing multiple do-files to execute in parallel. It requires Stata MP and a Unix-based system, such as macOS or Linux. Before execution, `dobatch` checks system resources to ensure sufficient CPU availability and to limit the number of active Stata processes.

## Quickstart

Install the most recent version of `dobatch`:
```stata
net install dobatch, from("https://raw.githubusercontent.com/reifjulian/dobatch/master") replace
```

Use `dobatch` instead of `do` to run do-files in the background. For example:
```stata
dobatch file1.do
dobatch file2.do
dobatch file3.do
```

For more details on usage and options, refer to the Stata help file.

## Example: parallelizing a for loop

Suppose you have the following code:
```stata
* mydofile.do
forval x = 1/100 {
	[...]
}
```
If each iteration of this loop runs independently, meaning it doesn’t rely on previous iterations, the loop can be parallelized. To do this, first modify the code as follows:
```stata
* mydofile.do
local lower `1'
local upper `2'
forval x = `lower'/`upper' {
	[...]
}
```
Then, create a master script that uses `dobatch` to run the modified do-file multiple times, distributing the workload across parallel jobs. The example below splits the loop into four Stata jobs, each handling one-quarter of the iterations:
```stata
* master.do
dobatch mydofile.do 1 25
dobatch mydofile.do 26 50
dobatch mydofile.do 51 75
dobatch mydofile.do 76 100
```

In this example, `dobatch mydofile.do 1 25` passes the values `1` and `25` as arguments to `mydofile.do`, which stores them in the local macros `lower` and `upper`, respectively. To log the output of each job, include a `log` command in the do-file:
```stata
* mydofile.do
log query
if mi("`r(name)'") log using "mydofile_`1'_`2'.log", text replace
local lower `1'
local upper `2'
forval x = `lower'/`upper' {
	[...]
}
```

## Advanced

Before execution, `dobatch` checks system resources to ensure sufficient CPU availability and to limit the number of active Stata processes. Specifically, it delays execution until enough CPUs are free and the number of background Stata jobs falls below a set threshold. If these conditions are not met, `dobatch` waits 5 minutes before checking again. The default thresholds are:

```stata
MIN_CPUS_AVAILABLE = max(c(processors_lic) - 1, 1)

MAX_STATA_JOBS = max(floor(c(processors_mach) / c(processors_lic)), 2)
```

For example, on a server with 64 processors running Stata MP 8, `dobatch` will wait until at least 7 CPUs are free and fewer than 8 Stata MP processes are running. If no other processes are running on the server, this allows up to 8 do-files to run in parallel in the background.

The following global macros can be used to adjust the default settings:

- `DOBATCH_MIN_CPUS_AVAILABLE`: Minimum number of CPUs that must be free before the do-file starts.
- `DOBATCH_MAX_STATA_JOBS`: Maximum number of active Stata MP jobs allowed.
- `DOBATCH_WAIT_TIME_MINS`: Time interval (in minutes) before checking CPU availability and active Stata jobs again. If the wait time is set to 0 minutes or less, `dobatch` does not monitor system resources.
- `DOBATCH_DISABLE`: If set to `1`, `dobatch` behaves like the standard `do` command and runs the do-file in the foreground

**Example 1. Allowing more Stata jobs**

```stata

* Allow up to 10 Stata jobs, even if CPU usage exceeds the number of physical CPUs by 5
global DOBATCH_MAX_STATA_JOBS = 10
global DOBATCH_MIN_CPUS_AVAILABLE = -5

dobatch mydofile.do 1 25
dobatch mydofile.do 26 50
dobatch mydofile.do 51 75
dobatch mydofile.do 76 100
...
```

**Example 2. Waiting for prior jobs to complete**

The `dobatch` package includes a helper command, `dobatch_wait`, which pauses Stata until all previously launched `dobatch` jobs have finished. For example, if you are running four do-files in parallel and want to wait until they complete before starting the next do-file, you can use `dobatch_wait`:

```stata
* Run 4 do-files in parallel, wait until they complete, then run the next script
dobatch mydofile.do 1 25
dobatch mydofile.do 26 50
dobatch mydofile.do 51 75
dobatch mydofile.do 76 100

dobatch_wait
do nextdofile.do
```
For more details, type `help dobatch_wait` in Stata.

## FAQ

**Will `dobatch` overload my server?**

`dobatch` monitors CPU usage and the number of active Stata MP processes to prevent overloading. The default settings are conservative, but note that `dobatch` does not monitor memory usage&#8212;users remain responsible for ensuring sufficient system memory.

**How can I run more Stata jobs in parallel?**

Increase parallelization by setting the global variable `DOBATCH_MAX_STATA_JOBS` to a higher value and `DOBATCH_MIN_CPUS_AVAILABLE` to a small or negative value. This allows more jobs to launch even when CPU usage is high. See Example 1 above for details.

**`dobatch` is great! But sometimes I need to run my scripts on a Windows machine, and manually changing all the `dobatch` commands back to `do` is annoying. Yes, I'm lazy.**

Nothing wrong with being lazy! Instead of editing every `dobatch` call, just add `global DOBATCH_DISABLE = 1` to your script&#8212;or better yet, to your [Stata profile](https://julianreif.com/guide/#stata-profile) on Windows&#8212;so `dobatch` automatically behaves like `do`.

**Do you have any plans to add Windows support for `dobatch`?**

No.

**`dobatch` is not working on my system. What should I do?**

Try setting `global DOBATCH_WAIT_TIME_MINS = 0` to bypass system monitoring while still running jobs in parallel. `dobatch` has been tested on Mac OS, Unix bash, and Unix tcsh. If you encounter issues, report them in the [issues section](../../issues). Please include the output of the following code when submitting your issue:
```stata
cap program drop _print_timestamp 
program define _print_timestamp 
	di "{hline `=min(79, c(linesize))'}"

	di "Date and time: $S_DATE $S_TIME"
	di "Stata version: `c(stata_version)'"
	di "Updated as of: `c(born_date)'"
	di "Variant:       `=cond( c(MP),"MP",cond(c(SE),"SE",c(flavor)) )'"
	di "Processors:    `c(processors)'"
	di "OS:            `c(os)' `c(osdtl)'"
	di "Machine type:  `c(machine_type)'"
	local hostname : env HOSTNAME
	local shell : env SHELL
	if !mi("`hostname'") di "Hostname:      `hostname'"
	if !mi("`shell'") di "Shell:         `shell'"
	
	di "{hline `=min(79, c(linesize))'}"
end
noi _print_timestamp
```

## Author

[Julian Reif](http://www.julianreif.com)
<br>University of Illinois
<br>jreif@illinois.edu
