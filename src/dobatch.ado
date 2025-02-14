*! dobatch 1.0 12feb2025 by Julian Reif

* TO DO: add test case with an argument. Requires that we have space between `args' and what follows
* e.g., must be "`args' `stop'`suffix'" not "`args'`stop'`suffix'"

program define dobatch, rclass

* Optional params for dobatch are specified in the following globals:
*   DOBATCH_DISABLE
*   DOBATCH_MIN_CPUS_AVAILABLE
*   DOBATCH_MAX_STATA_JOBS
*   DOBATCH_WAIT_TIME_MINS

	* If dobatch is disabled, just run the dofile as normal
	if `"$DOBATCH_DISABLE"'=="1" {
		do `0'
		exit
	}
	
	* First argument must be dofilename, followed by optional arguments
	syntax anything [, nostop]
	gettoken dofile args : anything
	cap confirm file "`dofile'"
	if _rc cap confirm file "`dofile'.do"
	if _rc confirm file "`dofile'"
	
	cap assert c(os)=="Unix"
	if _rc {
		noi di as error "dobatch requires Unix"
		exit 198
	}
	
	cap assert c(MP)==1
	if _rc {
		noi di as error "dobatch requires Stata MP"
		exit 198
	}
	
	* Set default values for how many CPUs need to be available for max number of active Stata jobs
	*  (1) MIN_CPUS_AVAILABLE = (# cores) - 1
	*  (2) MAX_STATA_JOBS = (# cores) / (# Stata-MP license cores) + 1
	*  Note: c(processors_mach) evaluates to missing when running non-MP Stata.
	local num_cpus_machine = c(processors_mach)
	local num_cpus_statamp = c(processors_lic)
	local default_min_cpus_available = max(`num_cpus_statamp' - 1,1)
	local default_max_stata_jobs = floor(`num_cpus_machine' / `num_cpus_statamp') + 1

	local MIN_CPUS_AVAILABLE = `default_min_cpus_available'
	local MAX_STATA_JOBS = `default_max_stata_jobs'
	
	* Default wait time is 5 minutes
	local WAIT_TIME_MINS = 5
	
	* The default values above can be overriden by user-defined global macros
	foreach param in MIN_CPUS_AVAILABLE MAX_STATA_JOBS WAIT_TIME_MINS {
		if !mi(`"${DOBATCH_`param'}"') {
			cap confirm number ${DOBATCH_`param'}
			if _rc {
				noi di as error _n "Error parsing the global variable DOBATCH_`param'"
				confirm number ${DOBATCH_`param'}
			}		
			local `param' = ${DOBATCH_`param'}
			
			if "`param'"=="WAIT_TIME_MINS" noi di as text "Wait time set to " as result "`WAIT_TIME_MINS'" as text " minutes"
		}		
	}
	noi di as text _n "Minimum required available CPUs: " as result `MIN_CPUS_AVAILABLE'
	noi di as text "Maximum number of active Stata jobs allowed: " as result `MAX_STATA_JOBS'
	
	************************************************
	* Detect shell version
	************************************************	
	* Syntax for the -shell- call depends on which version of the shell is running:
	*	Unix csh:  /bin/csh
	*	Unix tcsh: /usr/local/bin/tcsh (default on NBER server)
	*	Unix bash: /bin/bash
	*	Windows
	tempname shellfh
	tempfile shellfile
	
	qui shell echo "$0" > `shellfile'
	
	file open `shellfh' using `"`shellfile'"', read
	file read `shellfh' shell
	file close `shellfh'
	local shell = trim(`"`shell'"')
		
	* If check_cpus=1, wait until there are (1) at least MIN_CPUS_AVAILABLE cpu's available; and (2) less than MAX_STATA_JOBS active Stata processes
	*   - If wait time is non-positive, skip this code (ie, set check_cpus = 0)
	local check_cpus 1
	if `WAIT_TIME_MINS'<=0 local check_cpus = 0
	tempfile t
	tempname fh
	while (`check_cpus'==1) {

		* Alternative, which should work on all shells
		* awk 'BEGIN {print '"$(nproc)"' - '"$(uptime | sed 's/.*load average: //' | cut -d',' -f1)"'}' > `t'
		* awk -v c=$(nproc) '{print c - $1}' <(uptime | awk -F'load average: ' '{print $2}' | awk '{print $1}' | tr -d ',') > `t'
		* env sh -c 'awk "BEGIN {print $(nproc) - $(uptime | sed \"s/.*load average: //\" | cut -d\",\" -f1)}"'
		
		* Check available procs using the most recent 1 minute of data from uptime. aws -k works well for bash, but not other shells. Second option fails because of backticks.
		* SO FAR: aws -v... and sh -c... are confirmed to work on finance server
		*shell awk -v c=$(nproc) '{print c - $1}' <(uptime | awk -F'load average: ' '{print $2}' | awk '{print $1}' | tr -d ',') > `t'
		*shell awk 'BEGIN {print '"$(nproc)"' - '"$(uptime | sed 's/.*load average: //' | cut -d',' -f1)"'}' > `t'
		*qui shell sh -c 'awk "BEGIN {print ARGV[1] - ARGV[2]}" $(nproc) $(uptime | sed "s/.*load average: //" | cut -d"," -f1)' > `t'
		*   shell rm -f `t' && sh -c 'awk "BEGIN {print ARGV[1] - ARGV[2]}" $(getconf _NPROCESSORS_ONLN) $(uptime | sed "s/.*load average: //" | cut -d"," -f1)' > `t'
		qui shell rm -f `t' && sh -c 'awk "BEGIN {print ARGV[1] - ARGV[2]}" $(nproc) $(uptime | sed "s/.*load average: //" | cut -d"," -f1)' > `t'

		file open `fh' using `t', read
		file read `fh' line
		file close `fh'
		local free_cpus = trim("`line'")
		noi di _n "Available CPUs at $S_TIME: `free_cpus'"
		
		* Check number of running stata-mp processes
		*qui shell pgrep -c stata-mp > `t'
		* qui shell rm -f `t' && ps aux | grep -w stata-mp | grep -v grep | wc -l > `t'
		qui shell rm -f `t' && pgrep -c stata-mp > `t'
		file open `fh' using `t', read
		file read `fh' line
		file close `fh'
		local num_stata_jobs = trim("`line'")
		noi di "Active Stata MP jobs at $S_TIME: `num_stata_jobs'"
		
		* If server is busy, wait a few minutes and try again
		if `free_cpus' < `MIN_CPUS_AVAILABLE' | `num_stata_jobs' >= `MAX_STATA_JOBS' {
			noi di "Waiting for at least `MIN_CPUS_AVAILABLE' available CPUs and fewer than `MAX_STATA_JOBS' active Stata MP jobs..."
			sleep `=1000*60*`WAIT_TIME_MINS''
		}
		else local check_cpus = 0
	}
		
	* Run Stata MP in Unix batch mode
	local prefix "nohup stata-mp -b do"
	*local suffix "> /dev/null 2>&1 &"
	*local suffix "> /dev/null 2>&1 < /dev/null &"
	* local suffix ">& /dev/null </dev/null &"
	local suffix ">/dev/null 2>&1 </dev/null &"

	if !mi("`stop'") local stop ", `stop' "
	
	noi di _n `"sh -c '`prefix' \"`dofile'\" `args' `stop'`suffix''"'
	shell sh -c '`prefix' \"`dofile'\" `args' `stop'`suffix''
	
	* Return parameter values
	return local shell "`shell'"
	return scalar MIN_CPUS_AVAILABLE = `MIN_CPUS_AVAILABLE'
	return scalar MAX_STATA_JOBS = `MAX_STATA_JOBS'
	return scalar WAIT_TIME_MINS = `WAIT_TIME_MINS'
end

** EOF
