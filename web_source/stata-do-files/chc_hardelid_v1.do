
* * * * * * * * * * * * * * * * * * * * * * * * * * * 
* Author: Kate Lewis, kate.lewis.14@ucl.ac.uk
* Based on R code by Matthew Jay, matthew.jay@ucl.ac.uk
* Code list: chc_hardelid_v1
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
log using "ccc_hardelid_$S_DATE.log", replace*/



* load data and codelist --------------------------------------------------

* we use frames in Stata to have data from different files simultaneously open
frame create hes_2019
frame change hes_2019
clear
odbc load, exec(`"SELECT TOP 100000 * from dbo.FILE0184861_HES_APC_2019"') connectionstring("[omitted]") 

foreach var of varlist _all { //change varnames to lowercase
	capture rename `var', lower
	}
	
frame create hardelid
frame change hardelid
clear
import delimited "$codelists/chc_hardelid_v1.csv", varnames(1)

* Remove the dot from the code list file so we can link to HES
replace code = substr(code, 1, 3) + substr(code, 5, 1) if (strlen(code) == 5 & substr(code, 4, 1) == ".")

* trim group names to help the below code to run
gen group2=substr(group,1,5)

* creating a 3- and 4-digit variable to match length of the ICD-10 code
*putting these into seperate frames with other relevant information

*any matching code
forvalues k = 3/4 {
	capture frame drop hardelid_`k'
	capture drop code_`k'_digit
	gen code_`k'_digit = substr(code, 1, `k') if strlen(code) == `k'
	frame put code_`k'_digit if code_`k'_digit != "", into(hardelid_`k')
}

*each group
levelsof group2, local(list)
foreach var of local list{
forvalues k = 3/4 {
	capture frame drop hardelid_`var'_`k'
	frame put code_`k'_digit flag group subgroup if code_`k'_digit != "" & group2=="`var'", into(hardelid_`var'_`k')
	}
	}


* convert to long format --------------------------------------------------

* It is significantly easier to work with the diagnostic data in long format.
* This is especially so when working across NPD and HES, or when adopting a 
* spine-based approach as we do in the "How To?" guides. But even here,
* working with just one year of HES data, it is quicker and easier to identify
* relevant episodes in long format and then specify flags in the wide format data.

frame change hes_2019
frame put token_person_id epikey startage admidate disdate epiend diag_*, into(diagnoses)  // first put relevant variables in another frame
frame change diagnoses
rename diag_0* diag_* //need to take out the "0" of these label here
reshape long diag_, i(token_person_id epikey startage admidate disdate epiend) j(diag_n) 
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
gen chc_hardelid = 0 

*also creating variables to fill in additional information from code list
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
	frlink m:1 code_`k'_digit, frame(hardelid_`k') //matching on 3 and 4 digits as per the specific code list
	replace chc_hardelid=1 if hardelid_`k'!=.
	drop hardelid_`k' //drop linkage vars
	}

*each group
local variables "cance cardi chron codes menta metab muscu neuro respi"
foreach var of local variables{
forvalues k = 3/4 {
	frlink m:1 code_`k'_digit, frame(hardelid_`var'_`k') //matching on 3 and 4 digits as per the specific code list
	capture gen ccc_hardelid_`var'=0
	replace ccc_hardelid_`var'=1 if hardelid_`var'_`k'!=.
	
	frget flag group subgroup, from(hardelid_`var'_`k') suffix(_`var'_`k')
	foreach var2 of varlist flag group subgroup {
		replace `var2' = `var2'_`var'_`k' if `var2'==""
		} 

	drop hardelid_* flag_* group_* subgroup_* //drop linkage and other additional vars
	}
	}

* Now we can drop all the rows that are not in the code list as well as the now-
* redundant indicator variable.
drop if chc_hardelid!=1
drop chc_hardelid


* deal with flags ---------------------------------------------------------


* We now have a long format data table that contains codes in the target code list.
* However, some may violate specific conditions. We therefore want to remove these
* from the data table as they are not valid. We start by creating a flag for rows
* to drop (FALSE for all to begin with).
gen to_drop=0

* And then we set it to TRUE where a flag exists and the condition is not met.
* For chc_hardelid_v1, these are flags where a child must be greater than 10
* years old (AGE10) or where the length of admission is 3 nights or longer (LOS3).

* Age episodes can be dropped using startage (remembering that startages of 7001
* or higher are for children aged less than one year).
destring startage,replace
replace to_drop=1 if flag=="age10" & (startage < 10 | startage >= 7001)

* For LOS3, we need to define the admission length, not episode length.
* In real-world analyses, you will need to clean episode and admission dates
* Here, we just use admidate and disdate. We also set missing disdates to epiend.
* Otherwise, we take these variables at face value.
* This approach alone may not be sufficient in real-world settings.
foreach var of varlist admidate disdate epiend{ // changing dates to Stata format
		gen `var'2=date(`var', "YMD")
		drop `var'
		rename `var'2 `var'
		format `var' %td
		}
replace disdate=epiend if disdate==. | year(disdate) <1802		
gen admi_los_nights=disdate-admidate
replace to_drop=1 if flag == "los3" & admi_los_nights<3

* Now drop the rows where the conditions are violated, leaving us with a dataset
* of episodes containing codes that are validly in the target list.
drop if to_drop==1
drop to_drop 


* Create spine and flag ---------------------------------------------------

* We will here create a data table that contains one row per patient and then
* create flags to indicate whether a patient ever had a relevant CHC code.
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
gen chc_hardelid_any=0
replace chc_hardelid_any=1 if ccc_flag!=.
drop ccc_flag

* We will just create flags for just some groups for the sake of example.
local variables "cance neuro respi"
foreach var of local variables{
		frame change diagnoses
		capture frame drop flag
		frame put token_person_id if ccc_hardelid_`var'==1,into(flag)
		frame change flag
		duplicates drop
		frame change spine 
		frlink 1:1 token_person_id,frame(flag)
		gen chc_hardelid_`var'=0
		replace chc_hardelid_`var'=1 if flag!=.
		drop flag
		}

* Remove the temporary data from memory
frame dir

local variables "ccc_flag diagnoses hardelid hardelid_3 hardelid_4 flag hes_2019"
foreach var of local variables{
	frames drop `var'
	}

local variables "cance cardi chron codes menta metab muscu neuro respi"
foreach var of local variables{
forvalues k = 3/4 {
	frames drop hardelid_`var'_`k'
	}
	}

* We now have some binary flags that indicate the presence of a code in this year.
tab chc_hardelid_any
tab chc_hardelid_respi
tab chc_hardelid_neuro
tab chc_hardelid_cance