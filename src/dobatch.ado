*! dobatch 1.0 5feb2025 by Julian Reif

program define dobatch

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
	assert !mi(`"`0'"')
	gettoken dofile 0 : 0
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
	
	* The default values above can be overriden by pre-specified globals
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
	noi di as text _n "Required minimum available CPUs: " as result `MIN_CPUS_AVAILABLE'
	noi di as text "Maximum concurrent Stata jobs: " as result `MAX_STATA_JOBS'
		
	* If check_cpus=1, wait until there are (1) at least MIN_CPUS_AVAILABLE cpu's available; and (2) less than MAX_STATA_JOBS active Stata processes
	*   - If wait time is non-positive, skip this code (ie, set check_cpus = 0)
	local check_cpus 1
	if `WAIT_TIME_MINS'<=0 local check_cpus = 0
	tempfile t
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
		qui shell rm -f `t' && sh -c 'awk "BEGIN {print ARGV[1] - ARGV[2]}" $(nproc) $(uptime | sed "s/.*load average: //" | cut -d"," -f1)' > `t'

		file open myfile using `t', read
		file read myfile line
		file close myfile
		local free_cpus = trim("`line'")
		noi di _n "Available CPUs at $S_TIME: `free_cpus'"
		
		* Check number of running stata-mp processes
		*qui shell pgrep -c stata-mp > `t'
		qui shell rm -f `t' && pgrep -c stata-mp > `t'
		file open myfile using `t', read
		file read myfile line
		file close myfile
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
	local prefix "shell nohup stata-mp -b do"
	*local suffix "> /dev/null 2>&1 &"
	local suffix ">& /dev/null </dev/null &"
	
	noi di _n `"`prefix' \"`dofile'\" `0' `suffix'"'
	`prefix' \"`dofile'\" `0' `suffix'
end

** EOF
