*! dobatch 1.0 4mar2025 by Julian Reif

program define dobatch, rclass

* Optional params for dobatch are specified in the following globals:
*   DOBATCH_DISABLE
*   DOBATCH_MIN_CPUS_AVAILABLE
*   DOBATCH_MAX_STATA_JOBS
*   DOBATCH_WAIT_TIME_MINS

	version 13.0

	* If dobatch is disabled, just run the dofile as normal
	if `"$DOBATCH_DISABLE"'=="1" {
		do `0'
		exit
	}
	
	* dobatch requires unix-based systems and Stata MP
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
	
	* First argument must be dofilename, followed by optional arguments to the dofile
	syntax anything [, nostop]
	gettoken dofile args : anything
	cap confirm file "`dofile'"
	if _rc cap confirm file "`dofile'.do"
	if _rc confirm file "`dofile'"	
	
	* Set default values for how many CPUs need to be available and for max number of active Stata jobs
	*  (1) MIN_CPUS_AVAILABLE = (# Stata-MP license cores) - 1
	*  (2) MAX_STATA_JOBS = (# cores) / (# Stata-MP license cores). If <2, set to 2.
	*  Note: c(processors_mach) evaluates to missing when running non-MP Stata.
	local num_cpus_machine = c(processors_mach)
	local num_cpus_statamp = c(processors_lic)
	local default_min_cpus_available = max(`num_cpus_statamp' - 1,1)
	local default_max_stata_jobs = max(floor(`num_cpus_machine' / `num_cpus_statamp'), 2)

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
	if `MAX_STATA_JOBS' < 1 {
		noi di as error "DOBATCH_MAX_STATA_JOBS must be at least 1"
		exit 198
	}
	noi di as text _n "Minimum required available CPUs: " as result `MIN_CPUS_AVAILABLE'
	noi di as text "Maximum number of background Stata jobs allowed: " as result `MAX_STATA_JOBS'
	
	tempname fh
	tempfile tmp


	************************************************
	* Confirm that stata-mp is an installed application
	************************************************
	cap rm `tmp'
	qui shell sh -c 'command -v stata-mp >/dev/null && touch `tmp''
	
	cap confirm file `tmp'
	if _rc {
		di as error "stata-mp not found. Ensure Stata is installed and accessible from your system's PATH."
		di as error "Try running 'which stata-mp' or 'echo \$PATH' in the terminal to debug."
		exit 601
	}

	
	************************************************
	* Check server usage
	************************************************
		
	* If check_cpus=1, wait until there are (1) at least MIN_CPUS_AVAILABLE CPUs available; and (2) less than MAX_STATA_JOBS active Stata processes
	*   - If wait time is non-positive, skip this code (ie, set check_cpus = 0)
	local check_cpus 1
	if `WAIT_TIME_MINS'<=0 local check_cpus = 0
	while (`check_cpus'==1) {

		cap rm `tmp'
		qui shell sh -c 'LANG=C uptime | sed -E "s/.*load average[s]?: //" | tr -s " ," "," | cut -d"," -f1' > `tmp'
		file open `fh' using `tmp', read
		file read `fh' line
		file close `fh'
		local one_min_load_avg = trim("`line'")
		cap confirm number `one_min_load_avg'
		if _rc {
			di as error "Error parsing the load average:"
			di as error `"shell sh -c 'LANG=C uptime | sed -E "s/.*load average[s]?: //" | tr -s " ," "," | cut -d"," -f1'"'
			confirm number `one_min_load_avg'
		}		
		local free_cpus = `num_cpus_machine' - `one_min_load_avg'
		noi di _n "Available CPUs at $S_TIME: `free_cpus'"
		
		* Count number of background stata-mp processes. Subtract one to exclude the parent process (this script).
		cap rm `tmp'
		qui shell ps aux | grep '[s]tata-mp' | wc -l > `tmp'
		file open `fh' using `tmp', read
		file read `fh' line
		file close `fh'
		local num_stata_jobs = trim("`line'")
		cap confirm integer number `num_stata_jobs'
		if _rc {
			di as error "Error counting the number of background Stata processes:"
			di as error `"shell ps aux | grep '[s]tata-mp' | wc -l"'
			confirm integer number `num_stata_jobs'
		}
		local num_stata_jobs = `num_stata_jobs'-1
		noi di "Background Stata MP jobs at $S_TIME: `num_stata_jobs'"
		
		* If server is busy, wait a few minutes and try again
		if `free_cpus' < `MIN_CPUS_AVAILABLE' | `num_stata_jobs' >= `MAX_STATA_JOBS' {
			noi di "Waiting for at least `MIN_CPUS_AVAILABLE' available CPUs and fewer than `MAX_STATA_JOBS' background Stata MP jobs..."
			sleep `=1000*60*`WAIT_TIME_MINS''
		}
		else local check_cpus = 0
	}
	
	************************************************
	* Run Stata MP in Unix batch mode
	************************************************
	tempname stata_pid_fh
	tempfile stata_pid_file	
	local prefix "nohup stata-mp -b do"
	local suffix "</dev/null >/dev/null 2>&1 & echo $! > `stata_pid_file'"

	if !mi("`stop'") local stop ", `stop' "
	
	noi di _n `"sh -c '`prefix' \"`dofile'\" `args' `stop'`suffix''"'
	shell sh -c '`prefix' \"`dofile'\" `args' `stop'`suffix''
	
	* Store the process ID number
	file open `stata_pid_fh' using `"`stata_pid_file'"', read
	file read `stata_pid_fh' stata_pid
	file close `stata_pid_fh'
	local stata_pid = trim(`"`stata_pid'"')
	cap confirm number `stata_pid'
	if _rc local stata_pid = .
	if !mi(`stata_pid') global DOBATCH_STATA_PID "$DOBATCH_STATA_PID `stata_pid'"
	global DOBATCH_STATA_PID = trim("$DOBATCH_STATA_PID")

	* Return parameter values
	return scalar PID = `stata_pid'
	return scalar MIN_CPUS_AVAILABLE = `MIN_CPUS_AVAILABLE'
	return scalar MAX_STATA_JOBS = `MAX_STATA_JOBS'
	return scalar WAIT_TIME_MINS = `WAIT_TIME_MINS'
end

** EOF
