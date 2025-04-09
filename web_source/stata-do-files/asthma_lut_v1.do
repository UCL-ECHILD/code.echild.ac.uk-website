
* * * * * * * * * * * * * * * * * * * * * * * * * * * 
* Author: Kate Lewis, kate.lewis.14@ucl.ac.uk
* Based on R code by Matthew Jay, matthew.jay@ucl.ac.uk
* Code list: asthma_lut_v1
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
log using "Asthma_lut_$S_DATE.log", replace*/

* load data and codelist --------------------------------------------------

* we use frames in Stata to have data from different files simultaneously open
frame create hes_2019
frame change hes_2019
clear
odbc load, exec(`"SELECT TOP 100000 * from dbo.FILE0184861_HES_APC_2019"') connectionstring("[omitted]") 

foreach var of varlist _all { //change varnames to lowercase
	capture rename `var', lower
	}
	
frame create lut
frame change lut
clear
import delimited "$codelists/asthma_lut_v1.csv", varnames(1)

*creating a 3- and 4-digit variable to match length of the ICD-10 code
*putting these into seperate frames
forvalues k = 3/4 {
	capture frame drop lut_`k'
	capture drop code_`k'_digit
	gen code_`k'_digit = substr(code, 1, `k') if strlen(code) == `k'
	frame put * if code_`k'_digit != "", into(lut_`k')
	frame change lut
}


* convert to long format --------------------------------------------------


* It is significantly easier to work with the diagnostic data in long format.
* This is especially so when working across NPD and HES, or when adopting a 
* spine-based approach as we do in the "How To?" guides. But even here,
* working with just one year of HES data, it is quicker and easier to identify
* relevant episodes in long format and then specify flags in the wide format data.
frame change hes_2019
frame put token_person_id epikey epistart diag_*, into(diagnoses)  // first put relevant variables in another frame
frame change diagnoses
rename diag_0* diag_* //need to take out the "0" of these label here
reshape long diag_, i(token_person_id epikey epistart) j(diag_n) 
rename diag_ code 

* There are some codes in HES with 5 or 6 characters, some of which which relate
* to the asterisk and dagger system (see the primer for details). As these are not
* relevant, we truncate all codes to the first 4 characters only.
replace code = substr(code, 1, 4)

* We can drop empty rows (i.e. where no diagnosis was recorded in a given position)
* as these are now redundant.
drop if code == ""

*creating a 3 and 4 digit version of each code to match the relevant code list
gen code_3_digit = substr(code, 1, 3) //we do not need to specify that the string needs to be 3 digits here
// this allows us to match overarching code lists that only require 3 digit codes
gen code_4_digit = substr(code, 1, 4) if strlen(code) == 4

* create a binary flag ----------------------------------------------------

* Create a binary flag that indicates whether an episode contains a relevant code.

* The plans is:
* 1. This variable is FALSE for all episodes to begin with.
* 2. Where we find a code that is in the code list, we set the variable to TRUE.
* 3. We then aggregate to episode level so we can later check whether one of
* the exclusion codes is present on the same episode.

gen asthma = 0 

* identify episodes with relevant codes -----------------------------------

* Here we look for both codes and set the new binary
* indicator to TRUE where a relevant code is found.
* (If we had not converted to long format, we would have to apply this operation
* across several columns, which is difficult to code and may take a very significant
* amount of time, especially when using a for loop or the apply() functions.)

forvalue k = 3/4 {
	capture drop lut_`k'
	frlink m:1 code_`k'_digit, frame(lut_`k') //matching on 3 and 4 digits as per the specific code list
	replace asthma=1 if lut_`k' != .
	drop lut_`k' //drop linkage vars
}


* Now aggregate to episode level. We do this by taking the max() of our
* binary asthma variable by token_person_id and epistart. This aggregates
* to episode level beacause the max() of c(TRUE, FALSE) is TRUE.

* We will order the dataset first so it's easier to inspect should you wish to 
* do so.
order token_person_id epistart
bysort token_person_id epistart: egen asthma_episode = max(asthma)

* Now we can drop all the episodes that are not asthma episodes (for the sake
* of saving memory).
drop if asthma_episode != 1


* deal with flags ---------------------------------------------------------

* Now we need to repeate the above process but for the exclusion codes.
* Where an asthma episode has an exclusion code, we will drop it as the asthma
* codes should not be counted.
frame create lut_exclusion
frame change lut_exclusion
clear
import delimited "$codelists/asthma_lut_v1_exclusions.csv", varnames(1)

rename *code code

* Remove the dot from the code list file so we can link to HES
replace code = substr(code, 1, 3) + substr(code, 5, 1) if (strlen(code) == 5 & substr(code, 4, 1) == ".")

* Define exclusion variables: 3-character and 4-character codes into seperate frames
forvalues k = 3/4 {
	capture frame drop codelist_`k'_excl
	capture drop code_`k'_digit_excl
	gen code_`k'_digit_excl = substr(code, 1, `k') if strlen(code) == `k'
	frame put * if  code_`k'_digit_excl != "", into(codelist_`k'_excl)
	frame change lut_exclusion
}

*open main dataset
frame change diagnoses

*relabel our 3 and 4 digit codes as exclusion criteria
rename code_3_digit code_3_digit_excl
rename code_4_digit code_4_digit_excl

* Define exclusion variable
gen asthma_excl = 0

* Here we have 3-character and 4-character codes to deal with.
forvalue k = 3/4 {
	capture drop codelist_`k'_excl
	frlink m:1 code_`k'_digit_excl, frame(codelist_`k'_excl) //matching on 3 and 4 digits as per the specific code list
	replace asthma_excl = 1 if codelist_`k'_excl != .
	drop codelist_`k'_excl //drop linkage vars
}

* Aggregate to episode level
bysort token_person_id epistart: egen asthma_episode_excl = max(asthma_excl)

* Now drop the asthma episodes where exclude_episode is TRUE.
drop if asthma_episode_excl == 1

* Clean up the dataset to save memory. We do not actually need to retain any
* of the new flags as they are now all valid asthma episodes. (This step is not
* really necessary in this example as the dataset is so small, but you may wish
* to consider it in real-world analyses.)
keep token_person_id epikey epistart
duplicates drop


* Create spine and flag ---------------------------------------------------

* We will here create a data table that contains one row per patient and then
* create flags to indicate whether a patient ever had a relevant asthma code.
* In real world settings, you might be doing this using a spine of study
* participants created elsewhere and using information only over certain time
* periods. See the ECHILD How To guides for more information and examples.

frame put token_person_id,into(asthma_flag)
frame change asthma_flag
keep token_person_id
duplicates drop

frame change hes_2019
frame put token_person_id,into(spine)
frame change spine 
duplicates drop
gen ever_asthma=0
frlink 1:1 token_person_id, frame(asthma_flag)
replace ever_asthma=1 if asthma_flag!=.
drop asthma_flag

* Remove the temporary data from memory (apart from current frame)
frame dir
frame drop asthma_flag
frame drop diagnoses
frame drop hes_2019
frame drop lut
frame drop lut_3
frame drop lut_4
frame drop codelist_3_excl
frame drop codelist_4_excl
frame drop lut_exclusion

* We now have some binary flags that indicate the presence of a code in this year.
tab ever_asthma