
* * * * * * * * * * * * * * * * * * * * * * * * * * * 
* Author: Kate Lewis, kate.lewis.14@ucl.ac.uk
* Based on R code by Matthew Jay, matthew.jay@ucl.ac.uk
* Code list: ccc_feudtner_v1
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
log using "ccc_feudtner_$S_DATE.log", replace*/


* load data and codelist --------------------------------------------------

* we use frames in Stata to have data from different files simultaneously open
frame create hes_2019
frame change hes_2019
clear
odbc load, exec(`"SELECT TOP 100000 * from dbo.FILE0184861_HES_APC_2019"') connectionstring("[omitted]") 

foreach var of varlist _all { //change varnames to lowercase
	capture rename `var', lower
	}
	
frame create feudtner
frame change feudtner
clear
import delimited "$codelists/ccc_feudtner_v1.csv", varnames(1)

* Remove the dot from the code list file so we can link to HES
replace code = substr(code, 1, 3) + substr(code, 5, 1) if (strlen(code) == 5 & substr(code, 4, 1) == ".")

* creating a 3- and 4-digit variable to match length of the ICD-10 code
* putting these codes into seperate files, one overall and one for each group 
* we do this because some codes appear more than once in the list 
* which causes problems with merging

*any matching code
forvalues k = 3/4 {
	capture frame drop feudtner_`k'
	capture drop code_`k'_digit
	gen code_`k'_digit = substr(code, 1, `k') if strlen(code) == `k'
	frame put code_`k'_digit if code_`k'_digit != "", into(feudtner_`k')
	frame change feudtner_`k'
	duplicates drop // keeping only one of each code
	frame change feudtner
	}

*each group
levelsof group, local(list)
foreach var of local list{
forvalues k = 3/4 {
	capture frame drop feudtner_`var'_`k'
	frame put code_`k'_digit flag group subgroup if code_`k'_digit != "" & group=="`var'", into(feudtner_`var'_`k')
	capture frame create feudtner_`var'_`k' // create blank frame for those with no codes
	frame change feudtner_`var'_`k'
	bysort code_`k'_digit: keep if _n==1
	frame change feudtner
	}
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
gen ccc_feudtner = 0

*creating variables to fill in additional information from code list
local variables "flag group subgroup"
foreach var of local variables {
	gen `var' = ""
} 

* We also need a variable that enables us to link the code description and groups.
* (This is because the code used in HES might be a 4 character code that is included
* because its 3 character parent code is in the code list. However, if we tried
* to link the code description and groups using the 4 character code, it would fail
* as the 4 character verision is recorded explicitly in the code list.)

*creating a 3 and 4 digit version of each code to match the relevant code list
gen code_3_digit = substr(code, 1, 3) //we do not need to specify that the string needs to be 3 digits here
// this allows us to match overarching code lists that only require 3 digit codes
gen code_4_digit = substr(code, 1, 4) if strlen(code) == 4


* identify episodes with relevant codes -----------------------------------

* Here we look for both the 3 and 4 character codes and set the new binary
* indicator to TRUE where a relevant code is found.
* (If we had not converted to long format, we would have to apply this operation
* across several columns, which is difficult to code and may take a very significant
* amount of time, especially when using a for loop or the apply() functions.)

*any matching code 
forvalue k = 3/4{
	frlink m:1 code_`k'_digit, frame(feudtner_`k') //matching on 3 and 4 digits as per the specific code list
	replace ccc_feudtner=1 if feudtner_`k'!=.
	drop feudtner_`k' //drop linkage vars
	}

*each group
local variables "cardio gastro malignancy metab misc neuro other_congen prem_neonatal renal_urol resp"
foreach var of local variables{
forvalues k = 3/4 {
	frlink m:1 code_`k'_digit, frame(feudtner_`var'_`k') //matching on 3 and 4 digits as per the specific code list
	capture gen ccc_feudtner_`var'=0
	replace ccc_feudtner_`var'=1 if feudtner_`var'_`k'!=.
	
	frget flag group subgroup, from(feudtner_`var'_`k') suffix(_`var'_`k')
	foreach var2 of varlist flag group subgroup {
		replace `var2' = `var2'_`var'_`k' if `var2'==""
		} 

	drop feudtner_* flag_* group_* subgroup_* //drop linkage and other additional vars
	}
	}


* Now we can drop all the rows that are not in the code list as well as the now-
* redundant indicator variable.
drop if ccc_feudtner!=1
drop ccc_feudtner


* deal with flags ---------------------------------------------------------

* In the case of the Feudtner et al code list, the only flag is one to indicate
* that some ICD-10-CA codes have been truncated. We will ignore these here.


* Create spine and flag ---------------------------------------------------

* We will here create a data table that contains one row per patient and then
* create flags to indicate whether a patient ever had a relevant CCC code.
* In real world settings, you might be doing this using a spine of study
* participants created elsewhere and using information only over certain time
* periods. See the ECHILD How To guides for more information and examples.

frame put token_person_id,into(ccc_flag)
frame change ccc_flag
keep token_person_id
duplicates drop

frame change hes_2019
frame put token_person_id,into(spine)
frame change spine 
duplicates drop
frlink 1:1 token_person_id, frame(ccc_flag)

gen ccc_feudtner_any=0
replace ccc_feudtner_any=1 if ccc_flag!=.
drop ccc_flag

* We will just create flags for just some groups for the sake of example.
local variables "cardio gastro malignancy"
foreach var of local variables{
		frame change diagnoses
		capture frame drop flag
		frame put token_person_id if ccc_feudtner_`var'==1,into(flag)
		frame change flag
		duplicates drop
		frame change spine 
		frlink 1:1 token_person_id,frame(flag)
		gen ccc_feudtner_`var'=0
		replace ccc_feudtner_`var'=1 if flag!=.
		drop flag
		}

* Remove the temporary data from memory
frames dir

local variables "ccc_flag diagnoses feudtner feudtner_3 feudtner_4 flag hes_2019"
foreach var of local variables{
	frames drop `var'
	}

local variables "cardio gastro malignancy metab misc neuro other_congen prem_neonatal renal_urol resp"
foreach var of local variables{
forvalues k = 3/4 {
	frames drop feudtner_`var'_`k'
	}
	}

* We now have some binary flags that indicate the presence of a code in this year.
tab ccc_feudtner_any
tab ccc_feudtner_cardio
tab ccc_feudtner_gastro
tab ccc_feudtner_malignancy