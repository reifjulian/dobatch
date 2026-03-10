# DOBATCH: Run Stata do-files in parallel

- Current dobatch version: `1.2 10mar2026`
- Jump to:  [`overview`](#overview) [`quickstart`](#quickstart) [`examples`](#example-running-scripts-in-parallel)
 [`advanced`](#advanced)  [`faq`](#faq) [`author`](#author)

-----------

## Overview

`dobatch` runs a do-file as a background batch process, allowing multiple do-files to execute in parallel. It supports all Stata editions (MP, SE, IC/BE) on Unix-based systems (macOS, Linux) and Windows. Before execution, `dobatch` checks system resources to ensure sufficient CPU availability and to limit the number of active Stata processes.

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

## Example: running scripts in parallel

Suppose you are running a large number of Stata scripts that are independent of each other:
```stata
do script1.do
do script2.do
do script3.do
…
```

On a linux server, you can execute these scripts in parallel by launching them as separate background jobs from the terminal:
```bash
nohup stata-mp -b do script1.do &
nohup stata-mp -b do script2.do &
nohup stata-mp -b do script3.do &
…
```

This approach allows faster execution by leveraging multiple processors. However, the user must be cautious not to overload the server. Each background process consumes CPU and memory. You can use `dobatch` to manage this safely and efficiently. `dobatch` launches only a limited number of jobs at once and automatically starts new ones as earlier ones finish. All you need to do is replace `do` with `dobatch`:
```stata
dobatch script1.do
dobatch script2.do
dobatch script3.do
…
```


## Example: parallelizing a for loop

Suppose you have the following Stata code:
```stata
* mydofile.do
forval x = 1/100 {
	[...]
}
```
If each iteration of this loop runs independently, meaning it doesn't rely on previous iterations, the loop can be parallelized. To do this, first modify the code as follows:
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

For example, on a server with 64 processors running Stata MP 8, `dobatch` will wait until at least 7 CPUs are free and fewer than 8 Stata processes are running. If no other processes are running on the server, this allows up to 8 do-files to run in parallel in the background.

The following global macros can be used to adjust the default settings:

- `DOBATCH_MIN_CPUS_AVAILABLE`: Minimum number of CPUs that must be free before the do-file starts.
- `DOBATCH_MAX_STATA_JOBS`: Maximum number of active Stata jobs allowed.
- `DOBATCH_WAIT_TIME_MINS`: Time interval (in minutes) before checking CPU availability and active Stata jobs again. If the wait time is set to 0 minutes or less, `dobatch` does not monitor system resources.
- `DOBATCH_DISABLE`: If set to `1`, `dobatch` behaves like the standard `do` command and runs the do-file in the foreground

The `exe()` option lets you specify the Stata executable directly, bypassing auto-detection. This is useful for non-standard installs or when you want to launch a specific edition:
```stata
dobatch mydofile.do, exe("StataSE-64.exe")           // filename, looked up in Stata install dir
dobatch mydofile.do, exe("C:/Stata19/StataMP-64.exe") // full path
```

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

## Windows notes

On Windows, `dobatch` uses PowerShell to manage background processes. The following details are specific to Windows:

- **Executable discovery**: `dobatch` auto-discovers the Stata executable from the Stata installation directory based on the running edition (e.g., `StataMP-64.exe` for MP, `StataSE-64.exe` for SE). No PATH configuration is needed. Use the `exe()` option to override for non-standard installs.
- **Batch mode**: Windows uses the `/e` flag for batch mode execution (equivalent to `-b` on Unix).
- **CPU monitoring**: CPU availability is estimated using the `Win32_Processor.LoadPercentage` metric, which reports load as a percentage (0&#8211;100). Available CPUs are calculated as `total_cpus * (100 - load_pct) / 100`.
- **Process detection**: Background Stata processes are detected using PowerShell's `Get-Process` cmdlet.
- **PowerShell**: All system operations use `powershell -NoProfile` (Windows PowerShell 5.1, available on all supported Windows versions).

## FAQ

**Will `dobatch` overload my server?**

`dobatch` monitors CPU usage and the number of active Stata processes to prevent overloading. The default settings are conservative, but note that `dobatch` does not monitor memory usage&#8212;users remain responsible for ensuring sufficient system memory.

**How can I run more Stata jobs in parallel?**

Increase parallelization by setting the global variable `DOBATCH_MAX_STATA_JOBS` to a higher value and `DOBATCH_MIN_CPUS_AVAILABLE` to a small or negative value. This allows more jobs to launch even when CPU usage is high. See Example 1 above for details.

**Does `dobatch` work on Windows?**

Yes. `dobatch` supports Windows using PowerShell for system operations. It auto-discovers the Stata executable based on the running edition and uses the `/e` batch mode flag. See the [Windows notes](#windows-notes) section for details.

**`dobatch` is not working on my system. What should I do?**

Try setting `global DOBATCH_WAIT_TIME_MINS = 0` to bypass system monitoring while still running jobs in parallel. `dobatch` has been tested on macOS, Unix bash, Unix tcsh, and Windows. If you encounter issues, report them in the [issues section](../../issues). Please include the output of the following code when submitting your issue:
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
