* This script runs a series of tests on the -dobatch- package
* Author: Julian Reif

clear
adopath ++"../src"
set more off
tempfile t results
version 18
program drop _all

global DOBATCH_MAX_STATA_JOBS
global DOBATCH_WAIT_TIME_MINS

if c(os)=="Windows" {
	
	global DOBATCH_DISABLE = 0
	rcof noi dobatch dofile1.do
	assert _rc==198
	
	global DOBATCH_DISABLE = 1
	dobatch dofile1.do
}

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

* Add error handling for options such as , nostop

** EOF

