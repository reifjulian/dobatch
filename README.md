# DOBATCH: Run Stata do-files in parallel

- Current dobatch version: `1.0 23feb2025`
- Jump to:  [`overview`](#overview) [`quickstart`](#quickstart) [`examples`](#examples) [`advanced`](#advanced)  [`faq`](#faq) [`author`](#author)

-----------

## Overview

`dobatch` runs do-files in batch mode in the background, allowing multiple do-files to execute in parallel. It requires Stata MP and a Unix-based system. Before execution, `dobatch` checks server usage to ensure sufficient CPU availability and to prevent an excessive number of active Stata processes.

This command is currently being beta tested.

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

## Example

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
dobatch mydofile.do 1 25
dobatch mydofile.do 26 50
dobatch mydofile.do 51 75
dobatch mydofile.do 76 100
```

To log the output of each job, include a `log` command in the do-file:
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

Before execution, `dobatch` monitors system resources to ensure sufficient CPU availability and prevent an excessive number of active Stata processes. Specifically, it delays execution until enough CPUs are free and the number of active Stata jobs remains within a set limit. If the system is busy, `dobatch` waits 5 minutes before rechecking the system resources. The default threshold are:

```stata
MIN_CPUS_AVAILABLE = max(c(processors_lic) - 1, 1)

MAX_STATA_JOBS = max(floor(c(processors_mach) / c(processors_lic)) + 1, 2)
```

For example, on a server with 64 processors running Stata MP 8, `dobatch` will not launch the do-file until at least 7 processors are available and the total number of active Stata MP jobs, *including the session calling `dobatch`*, is fewer than 9. If no other processes are running on the server, this allows up to 8 do-files to run in parallel in the background.

The following global macros can be used to adjust the default settings:

- `DOBATCH_MIN_CPUS_AVAILABLE`: Minimum number of CPUs that must be free before the do-file starts.
- `DOBATCH_MAX_STATA_JOBS`: Maximum number of active Stata MP jobs allowed.
- `DOBATCH_WAIT_TIME_MINS`: Time interval (in minutes) before checking CPU availability and active Stata jobs again. If the wait time is set to 0 minutes or less, `dobatch` does not monitor system resources.
- `DOBATCH_DISABLE`: If set to `1`, `dobatch` runs do-files like `do`

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

## FAQ

**Will `dobatch` overload my server?**

No, `dobatch` monitors CPU usage and the number of active Stata MP processes to prevent overloading. The default settings are conservative, but note that `dobatch` does not monitor memory usage&#8212;users are responsible for ensuring sufficient system memory.

**How can I run more Stata jobs in parallel?**

Increase parallelization by setting the global variables `DOBATCH_MIN_CPUS_AVAILABLE` to a negative value and `DOBATCH_MAX_STATA_JOBS` to a larger value. See Example 1 for details.

**`dobatch` is great! But sometimes I need to run my scripts on a Windows machine, and manually changing all the `dobatch` commands back to `do` again is a pain. Yes, I'm lazy.**

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
