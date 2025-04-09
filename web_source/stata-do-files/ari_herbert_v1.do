
* * * * * * * * * * * * * * * * * * * * * * * * * * * 
* Author: Kate Lewis, kate.lewis.14@ucl.ac.uk
* Based on R code by Matthew Jay, matthew.jay@ucl.ac.uk
* Code list: ari_herbert_v1
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
log using "ari_herbert_$S_DATE.log", replace*/


* load data and codelist --------------------------------------------------

* we use frames in Stata to have data from different files simultaneously open
frame create hes_2019
frame change hes_2019
clear
odbc load, exec(`"SELECT * from dbo.FILE0184861_HES_APC_2019"') connectionstring("[omitted]") 

foreach var of varlist _all { //change varnames to lowercase
	capture rename `var', lower
	}
	
frame create herbert
frame change herbert
clear
import delimited "$codelists/ari_herbert_v1.csv", varnames(1)

* Remove the dot from the code list file so we can link to HES
replace code = substr(code, 1, 3) + substr(code, 5, 1) if (strlen(code) == 5 & substr(code, 4, 1) == ".")


* smoking code ------------------------------------------------------------

* As per the documentation, you may want to consider whether to include code F17.1
* (tobacco - harmful use). If you want to exclude F17.1 but not the other F17
* subcodes, you will need to run the following.

sort code
set obs `=_N+9'
replace code= "F170" if code[_n-1]=="Z915"
replace code= "F172" if code[_n-1]=="F170"
forvalues k= 3/9{
    local l = `k'-1
    replace code= "F17`k'" if code[_n-1]=="F17`l'"	
}

sort code
replace description = "smoking_codes" if substr(code,1,3)=="F17"
foreach var of varlist dataset field code_type group subgroup flag1 {
	replace `var'=`var'[_n-1] if substr(code,1,3)=="F17"
	}
	
*removing the general F17 flag
drop if substr(code,1,3)=="F17" & strlen(code) == 3

* trim group names to help the below code to run
gen group2=substr(group,1,4)

*creating a 3- and 4-digit variable to match length of the ICD-10 code
*putting these into seperate frames
forvalues k = 3/4 {
	capture frame drop herbert_`k'
	capture drop code_`k'_digit
	gen code_`k'_digit = substr(code, 1, `k') if strlen(code) == `k'
	frame put * if code_`k'_digit != "", into(herbert_`k')
	frame change herbert
}

*each group
levelsof group2, local(list)
foreach var of local list{
forvalues k = 3/4 {
	capture frame drop herbert_`var'_`k'
	frame put code_`k'_digit flag1 flag2 group subgroup if code_`k'_digit != "" & group2=="`var'", into(herbert_`var'_`k')
	}
	}


* convert to long format --------------------------------------------------

* It is significantly easier to work with the diagnostic data in long format.
* This is especially so when working across NPD and HES, or when adopting a 
* spine-based approach as we do in the "How To?" guides. But even here,
* working with just one year of HES data, it is quicker and easier to identify
* relevant episodes in long format and then specify flags in the wide format data.

* Note that here we need admidate and epistart, as an admission is only
* counted as an injury admission if the injury codes are recorded in the first
* episode of each admission.

* In real world applications, we would, following our usual methodology, and that
* employed by Herbert et al, clean admission and episode dates and join admissions
* together where a 2nd admission begins within a day of a previous (i.e. treat
* them as the same admission). In this example, we omit this step for the sake
* of demonstrating use of the code list.

* We also need only emergency admissions, and so we use the emergency admissions
* code list to identify and retain only these in our long-format data.

frame change hes_2019
frame put token_person_id epikey startage admidate epistart admimeth diag_*, into(diagnoses)  // first put relevant variables in another frame
frame change diagnoses
rename diag_0* diag_* //need to take out the "0" of these label here
reshape long diag_, i(token_person_id epikey startage admidate epistart admimeth) j(diag_n) 
rename diag_ code 

* There are some codes in HES with 5 or 6 characters, some of which which relate
* to the asterisk and dagger system (see the primer for details). As these are not
* relevant, we truncate all codes to the first 4 characters only.
replace code = substr(code, 1, 4)

* We can drop empty rows (i.e. where no diagnosis was recorded in a given position)
* as these are now redundant.
drop if code == ""

* Identify whether an episode is the first in admission or not. Here, we take
* a simple approach and say that an episode is the first if admidate and epistart
* are equal, though, again, you will need to ensure dates are cleaned in your
* applications.
gen first_episode=admidate==epistart

* Retain only emergency admissions
frame create em_adm
frame change em_adm
import delimited "$codelists/emergency_admissions_v1.csv", varnames(1)
rename code admimeth

frame change diagnoses
frlink m:1 admimeth,frame(em_adm)
drop if em_adm==.

*creating a 3 and 4 digit version of each code to match the relevant code list
gen code_3_digit = substr(code, 1, 3) //we do not need to specify that the string needs to be 3 digits here
// this allows us to match overarching code lists that only require 3 digit codes
gen code_4_digit = substr(code, 1, 4) if strlen(code) == 4


* create a binary flag ----------------------------------------------------

* Create binary flags that indicate whether an episode contains a relevant code.
* The plans is:
* 1. These variables are FALSE for all episodes to begin with.
* 2. Where we find a code that is in the code list, we set the variable to TRUE.
* 3. We identify separately: (1) injuries; (2) adversity-related episodes; (3) accidents.
* 4. We then aggregate up to admission level and identify accident-related injuries
* and adversity-related injuries.

gen injury_episode=0
gen adversity_episode=0
gen accident_episode=0


* identify episodes with relevant codes -----------------------------------

* Here we look for both the 3 and 4 character codes and set the new binary
* indicator to TRUE where a relevant code is found.
* (If we had not converted to long format, we would have to apply this operation
* across several columns, which is difficult to code and may take a very significant
* amount of time, especially when using a for loop or the apply() functions.)

* First, we identify injury episodes, all of which are three character codes.
frame change diagnoses
frlink m:1 code_3_digit, frame(herbert_inju_3) 
replace injury_episode=1 if herbert_inju_3!=.

* And set these to FALSE where it is not the first episode
replace injury_episode=0 if first_episode!=1
drop herbert_inju_3

* Second, identify adversity episodes
* this includes drugs, self-harm and violence
local variables "drug self viol"
foreach var of local variables{
forvalues k=3/4{
    frlink m:1 code_`k'_digit, frame(herbert_`var'_`k') 
	replace adversity_episode=1 if herbert_`var'_`k'!=. 
	drop herbert_`var'_`k'
	}
	}
	
* Third, identify accident episodes (all three character codes)
frlink m:1 code_3_digit, frame(herbert_acci_3) 
replace accident_episode=1 if herbert_acci_3!=.
drop herbert_acci_3

* Now we can drop all the rows that are not in the code list
drop if injury_episode==0 & adversity_episode==0 & accident_episode==0 

* Aggregate to admission-level
* Here, we just take the max() of each of the above flags by token_person_id
* and admidate. In other words, where an admission has any episode that has 
* injury == TRUE (TRUE being the max() of c(TRUE, FALSE)), then
* our new injury_admission variable will be set to TRUE for all rows
* belonging to the same admission of the same child. Otherwise,
* if all episodes in an admission are FALSE for injury_admission, then the max()
* of these is still FALSE.
order token_person_id admidate
local variable "injury adversity accident"
foreach var of local variable{
    bysort token_person_id admidate: egen `var'_admission = max(`var'_episode)
}

* And now identify adversity-related injuries and accident-related injuries
gen adversity_injury_admission=0
replace adversity_injury_admission=1 if adversity_admission==1 & injury_admission==1 

gen accident_injury_admission=0
replace accident_injury_admission=1 if accident_admission==1 & injury_admission==1 & adversity_admission!=1

* Drop rows that do not contain any of these (for the sake of memory)
drop if accident_injury_admission==0 & adversity_injury_admission==0 & adversity_admission==0 

* Create spine and flag ---------------------------------------------------

* We will here create a data table that contains one row per patient and then
* create flags to indicate whether a patient ever had a relevant CHC code.
* In real world settings, you might be doing this using a spine of study
* participants created elsewhere and using information only over certain time
* periods. See the ECHILD How To guides for more information and examples.

frame put token_person_id adversity_injury_admission accident_injury_admission ///
adversity_admission,into(ari_flag)
frame change ari_flag
duplicates drop

*put all flags on to one row
foreach var of varlist adversity_injury_admission accident_injury_admission ///
adversity_admission{
    bysort token_person_id: egen `var'_max=max(`var')
	drop `var'
	rename `var'_max `var'
}
duplicates drop

frame change hes_2019
frame put token_person_id,into(spine)
frame change spine 
duplicates drop
frlink 1:1 token_person_id, frame(ari_flag)
frget *,from(ari_flag)
drop ari_flag

foreach var of varlist adversity_injury_admission accident_injury_admission adversity_admission{
    replace `var'=0 if `var'==.
}

* Remove the temporary data from memory
frame dir

local variables "ari_flag diagnoses em_adm herbert herbert_3 herbert_4 hes_2019"
foreach var of local variables{
	frames drop `var'
	}

local variables "acci drug inju self viol"
foreach var of local variables{
forvalues k = 3/4 {
	frames drop herbert_`var'_`k'
	}
	}
	

* We now have some binary flags that indicate the presence of a code in this year.
tab adversity_injury_admission
tab accident_injury_admission
tab adversity_admission