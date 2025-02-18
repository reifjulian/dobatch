* This script runs a series of tests on the -dobatch- package
* Author: Julian Reif

clear
adopath ++"../src"
set more off
tempfile t results
version 18
program drop _all

cap rm test1.log
cap rm test1_myarg.log
cap rm test2.log

global DOBATCH_MIN_CPUS_AVAILABLE
global DOBATCH_MAX_STATA_JOBS
global DOBATCH_WAIT_TIME_MINS

if c(os)=="Windows" {
	
	global DOBATCH_DISABLE = 0
	rcof noi dobatch dofile1.do
	assert _rc==198
	
	global DOBATCH_DISABLE = 1
	dobatch dofile1.do
}

else {
	global DOBATCH_WAIT_TIME_MINS = 0.1
	dobatch dofile1.do
	dobatch dofile1.do
	dobatch dofile1.do
	dobatch dofile1.do
	dobatch dofile1.do
	dobatch dofile1.do
	dobatch dofile1.do

	global DOBATCH_MAX_STATA_JOBS = 8
	dobatch dofile1.do
	dobatch dofile1.do
	
	sleep 1000
	confirm file test1.log
	
	dobatch dofile1.do "myarg"
	sleep 7000
	confirm file test1_myarg.log

	* Add error handling for options such as , nostop
	dobatch dofile2.do
	sleep 1000
	cap confirm file test2.log
	assert _rc==601

	dobatch dofile2.do, nostop
	sleep 1000
	confirm file test2.log
	
	assert r(MAX_STATA_JOBS)==8
}
** EOF

