
* * * * * * * * * * * * * * * * * * * * * * * * * * * 
* Author: Kate Lewis, kate.lewis.14@ucl.ac.uk
* Based on R code by Matthew Jay, matthew.jay@ucl.ac.uk
* Code list: emergency_admissions_v1
* Tested in Stata version 16.1+
* * * * * * * * * * * * * * * * * * * * * * * * * * * 

* set-up ------------------------------------------------------------------

* Clear workspace
clear all

* Other housekeeping
capture log close
capture macro drop _all
frames reset

* Set global settings, such as your working directory
cd "[omitted]"
global codelists "[omitted]"

* direct Stata to packages in the SRS
sysdir set PERSONAL "[omitted]/Stata/Stata ado" 

/* log output
capture log close
log using "emer_adm_$S_DATE.log", replace*/

* load data and codelist --------------------------------------------------

* we use frames in Stata to have data from different files simultaneously open
frame create hes_2019
frame change hes_2019
clear
odbc load, exec(`"SELECT TOP 100000 * from dbo.FILE0184861_HES_APC_2019"') connectionstring("[omitted]") 

foreach var of varlist _all { //change varnames to lowercase
	capture rename `var', lower
	}
	
frame create em_adm
frame change em_adm
clear
import delimited "$codelists/emergency_admissions_v1.csv", varnames(1)

*create variable with same name as in HES data
gen admimeth=code


* identify emergency admissions -------------------------------------------

* This is a very simple code list that simply uses admimeth values.
* It is used directly in other code lists (see, e.g., the scripts for
* ari_herbert_v1 (adversity-related injuries) and the stress-related presentations
* of Ni Chobhthaigh et al (srp_nichobhthaigh_v2) and Blackburn et al (srp_blackburn_v1)).

frame change hes_2019
frlink m:1 admimeth,frame(em_adm)
gen emergency_admission=0 // create flag
replace emergency_admission=1 if em_adm!=.

* Excluding code 2B (transfer of an admitted patient from another hospital
* provider in an emergency)
replace emergency_admission=0 if admimeth=="2B"