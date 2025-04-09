
* * * * * * * * * * * * * * * * * * * * * * * * * * * 
* Author: Kate Lewis, kate.lewis.14@ucl.ac.uk
* Based on R code by Matthew Jay, matthew.jay@ucl.ac.uk
* Code list: llc_fraser_v1
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
log using "llc_fraser_$S_DATE.log", replace*/


* load data and codelist --------------------------------------------------

* we use frames in Stata to have data from different files simultaneously open
frame create hes_2019
frame change hes_2019
clear
odbc load, exec(`"SELECT TOP 100000 * from dbo.FILE0184861_HES_APC_2019"') connectionstring("[omitted]") 

foreach var of varlist _all { //change varnames to lowercase
	capture rename `var', lower
	}
	
frame create fraser
frame change fraser
clear
import delimited "$codelists/llc_fraser_v1.csv", varnames(1)

* Remove the dot from the code list file so we can link to HES
replace code = substr(code, 1, 3) + substr(code, 5, 1) if (strlen(code) == 5 & substr(code, 4, 1) == ".")

* creating a 3- and 4-digit variable to match length of the ICD-10 code

forvalues k = 3/4 {
	capture frame drop fraser_`k'
	capture drop code_`k'_digit
	gen code_`k'_digit = substr(code, 1, `k') if strlen(code) == `k'
	frame put code_`k'_digit if code_`k'_digit != "", into(fraser_`k')
	}


* convert to long format --------------------------------------------------

* It is significantly easier to work with the diagnostic data in long format.
* This is especially so when working across NPD and HES, or when adopting a 
* spine-based approach as we do in the "How To?" guides. But even here,
* working with just one year of HES data, it is quicker and easier to identify
* relevant episodes in long format and then specify flags in the wide format data.

frame change hes_2019
frame put token_person_id epikey startage admidate disdate diag_*, into(diagnoses)  // first put relevant variables in another frame
frame change diagnoses
rename diag_0* diag_* //need to take out the "0" of these label here
reshape long diag_, i(token_person_id epikey startage admidate disdate) j(diag_n) 
rename diag_ code 	   

* There are some codes in HES with 5 or 6 characters, some of which which relate
* to the asterisk and dagger system (see the primer for details). As these are not
* relevant, we truncate all codes to the first 4 characters only.
replace code = substr(code, 1, 4)

* We can drop empty rows (i.e. where no diagnosis was recorded in a given position)
* as these are now redundant.
drop if code == ""

* create a binary flag ----------------------------------------------------

* Create a binary flag that indicates whether an episode contains a relevant code.
* The plans is:
* 1. This variable is FALSE for all episodes to begin with.
* 2. Where we find a code that is in the code list, we set the variable to TRUE.
* 3. We then deal with special flags, dropping rows from our temporary long format
* dataset where the special conditions are not met.
gen llc_fraser = 0

* identify episodes with relevant codes -----------------------------------

* Here we look for both the 3 and 4 character codes and set the new binary
* indicator to TRUE where a relevant code is found.
* (If we had not converted to long format, we would have to apply this operation
* across several columns, which is difficult to code and may take a very significant
* amount of time, especially when using a for loop or the apply() functions.)

*creating a 3 and 4 digit version of each code to match the relevant code list
gen code_3_digit = substr(code, 1, 3) //we do not need to specify that the string needs to be 3 digits here
// this allows us to match overarching code lists that only require 3 digit codes
gen code_4_digit = substr(code, 1, 4) if strlen(code) == 4

*any matching code 
forvalue k = 3/4{
	frlink m:1 code_`k'_digit, frame(fraser_`k') //matching on 3 and 4 digits as per the specific code list
	replace llc_fraser=1 if fraser!=.
	drop fraser //drop linkage vars
	}

* Now we can drop all the rows that are not in the code list as well as the now-
* redundant indicator variable.
drop if llc_fraser!=1
drop llc_fraser


* deal with flags ---------------------------------------------------------

* There are no flags in the Fraser et al code list.


* Create spine and flag ---------------------------------------------------

* We will here create a data table that contains one row per patient and then
* create flags to indicate whether a patient ever had a relevant CHC code.
* In real world settings, you might be doing this using a spine of study
* participants created elsewhere and using information only over certain time
* periods. See the ECHILD How To guides for more information and examples.

frame put token_person_id,into(llc_flag)
frame change llc_flag
keep token_person_id
duplicates drop

frame change hes_2019
frame put token_person_id,into(spine)
frame change spine 
duplicates drop
frlink 1:1 token_person_id, frame(llc_flag)

gen llc_fraser=0
replace llc_fraser=1 if llc_flag!=.
drop llc_flag


* Remove the temporary data from memory
frames dir

local variables "diagnoses fraser fraser_3 fraser_4 llc_flag hes_2019"
foreach var of local variables{
	frames drop `var'
	}

* We now have a binary flag that indicates the presence of a code in this year.
tab llc_fraser