
* * * * * * * * * * * * * * * * * * * * * * * * * * * 
* Author: Kate Lewis, kate.lewis.14@ucl.ac.uk
* Based on R code by Matthew Jay, matthew.jay@ucl.ac.uk
* Code list: srp_blackburn_v1
* Tested in Stata version 16.1+
* * * * * * * * * * * * * * * * * * * * * * * * * * * 


* In this example, we do not attempt to create mutually exclusive (or
* overlapping) groups of SRPs. This mirrors Blackburn et al's original paper
* where SRPs were counted as one group. There are different ways of grouping
* these presentations. See, for example, the SRP list by Ní Chobhthaigh et al,
* also available through the ECHILD Phenotype Code List Repository, which 
* contains alternative and more up-to-date groupings.


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
log using "srp_blackburn_$S_DATE.log", replace*/



* load data and codelist --------------------------------------------------

* we use frames in Stata to have data from different files simultaneously open
frame create hes_2019
frame change hes_2019
clear
odbc load, exec(`"SELECT TOP 100000 * from dbo.FILE0184861_HES_APC_2019"') connectionstring("[omitted]") 

foreach var of varlist _all { //change varnames to lowercase
	capture rename `var', lower
	}
	
frame create blackburn
frame change blackburn
clear
import delimited "$codelists/srp_blackburn_v1.csv", varnames(1)

* Remove the dot from the code list file so we can link to HES
replace code = substr(code, 1, 3) + substr(code, 5, 1) if (strlen(code) == 5 & substr(code, 4, 1) == ".")

*creating a 3- and 4-digit variable to match length of the ICD-10 code
*putting these into seperate frames
forvalues k = 3/4 {
	capture frame drop blackburn_`k'
	capture drop code_`k'_digit
	gen code_`k'_digit = substr(code, 1, `k') if strlen(code) == `k'
	frame put * if code_`k'_digit != "", into(blackburn_`k')
	frame change blackburn_`k'
	bysort code: keep if _n==1 // just keeping one of each code
	// it doesn't matter which one as the duplicates have the same flags
	// and we are not defining subgroups
	frame change blackburn
}


* convert to long format --------------------------------------------------

* It is significantly easier to work with the diagnostic data in long format.
* This is especially so when working across NPD and HES, or when adopting a 
* spine-based approach as we do in the "How To?" guides. But even here,
* working with just one year of HES data, it is quicker and easier to identify
* relevant episodes in long format and then specify flags in the wide format data.

* We also need only emergency admissions, and so we use the emergency admissions
* code list to identify and retain only these in our long-format data.

frame change hes_2019
frame put token_person_id epikey startage admidate epistart admimeth diag_*, into(diagnoses)  // first put relevant variables in another frame
frame change diagnoses
rename diag_0* diag_* //need to take out the "0" of these label here
reshape long diag_, i(token_person_id epikey epistart admimeth) j(diag_n) 
rename diag_ code 

* There are some codes in HES with 5 or 6 characters, some of which which relate
* to the asterisk and dagger system (see the primer for details). As these are not
* relevant, we truncate all codes to the first 4 characters only.
replace code = substr(code, 1, 4)

* We can drop empty rows (i.e. where no diagnosis was recorded in a given position)
* as these are now redundant.
drop if code == ""

* Retain only emergency admissions
frame create em_adm
frame change em_adm
import delimited "$codelists/emergency_admissions_v1.csv", varnames(1)
rename code admimeth

frame change diagnoses
frlink m:1 admimeth,frame(em_adm)
drop if em_adm==.
drop em_adm

*creating a 3 and 4 digit version of each code to match the relevant code list
gen code_3_digit = substr(code, 1, 3) //we do not need to specify that the string needs to be 3 digits here
// this allows us to match overarching code lists that only require 3 digit codes
gen code_4_digit = substr(code, 1, 4) if strlen(code) == 4


* create a binary flag ----------------------------------------------------

* Create a binary flag that indicates whether an episode contains a relevant code.
gen srp=0

* Most codes are only counted if they are in the first diagnostic position. We
* therefore also need to create a variable that contains the diag number. We
* will use the existing diag_n variable 


* identify episodes with relevant codes -----------------------------------

* Here we look for both codes and set the new binary
* indicator to TRUE where a relevant code is found.
* (If we had not converted to long format, we would have to apply this operation
* across several columns, which is difficult to code and may take a very significant
* amount of time, especially when using a for loop or the apply() functions.)

* We start with the codes only valid in the first diagnostic position.
forvalues k = 3/4{
	frlink m:1 code_`k'_digit, frame(blackburn_`k') 
	replace srp=1 if blackburn_`k'!=. & frval(blackburn_`k',diag_position)=="first" & ///
	diag_n==1
	}


* Code R10 has a med_surg flag, meaning it should not be counted where one of
* the exclusion codes is present.

* Note that this list includes diagnosis and procedure codes.

frame create med_surg
frame change med_surg
import delimited "$codelists/srp_blackburn_v1_medical.csv", varnames(1)
rename *code code
replace code = substr(code, 1, 3) + substr(code, 5, 1) if (strlen(code) == 5 & substr(code, 4, 1) == ".")
gen code_4_digit = substr(code, 1, 4) // there's only 4 digit codes here

frame change diagnoses
gen med_surg_diag=0
frlink m:1 code_4_digit, frame(med_surg) 
replace med_surg_diag=1 if med_surg!=. & frval(med_surg,code_type)=="icd10"
bysort token_person_id epistart: egen med_surg_diag_any=max(med_surg_diag) // add this label to all rows within the same episode
drop med_surg med_surg_diag

* add in a flag for operation codes
*convet operations data to long format
frame change hes_2019
frame put token_person_id epikey epistart opertn_*, into(operations)  // first put relevant variables in another frame
frame change operations
rename opertn_0* opertn_* //need to take out the "0" of these label here
reshape long opertn_, i(token_person_id epikey epistart) j(opertn_n) 
rename opertn_ code 
drop if code == "" | code == "-"
gen code_4_digit = substr(code, 1, 4) // there's only 4 digit codes here

gen med_surg_opertn=0
frlink m:1 code_4_digit, frame(med_surg) 
replace med_surg_opertn=1 if med_surg!=. & frval(med_surg,code_type)=="opcs4"
bysort token_person_id epistart: egen med_surg_opertn_any=max(med_surg_opertn) // add this label to all rows within the same episode
drop med_surg med_surg_opertn

keep if med_surg_opertn_any==1
keep token_person_id epistart med_surg_opertn_any
duplicates drop

frame change diagnoses
frlink m:1 token_person_id epistart, frame(operations)
frget med_surg_opertn_any,from(operations)
drop operations

* Now set to FALSE where the code is R10 and the episode is medical or surgical.
replace srp=0 if substr(code,1,3)=="R10" & (med_surg_diag==1 | med_surg_opertn==1)
drop med_surg_diag med_surg_opertn

* And now we can get the codes in any diagnostic position.
forvalues k = 3/4{
	replace srp=1 if blackburn_`k'!=. & frval(blackburn_`k',diag_position)=="any" 
	}

* Now aggregate to episode level. We do this by taking the max() of our
* binary SRP variable by token_person_id and epistart. This aggregates
* to episode level beacause the max() of c(TRUE, FALSE) is TRUE.

* We will order the dataset first so it's easier to inspect should you wish to 
* do so.
sort token_person_id epistart
bysort token_person_id epistart:egen srp_episode=max(srp)


* Now we can drop all the episodes that are not SRP episodes (for the sake
* of saving memory).
drop if srp_episode==0


* Deal with flags ---------------------------------------------------------

* We do not need to worry about the remaining two flags: selfharm_xz_code and
* pers_hist. The latter is only relevant when creating mutually exclusive groups.
* The former indicates that certain codes (T36-T50 and certain codes from the
* S block) are only valid if they are in the first diagnostic position AND
* there is an X or Z block self-harm code in any position. However, the latter
* are always counted as SRPs and so such episodes are always counted.


* Create spine and flag ---------------------------------------------------

* We will here create a data table that contains one row per patient and then
* create flags to indicate whether a patient ever had a relevant SRP code.
* In real world settings, you might be doing this using a spine of study
* participants created elsewhere and using information only over certain time
* periods. See the ECHILD How To guides for more information and examples.

frame put token_person_id,into(srp_flag)
frame change srp_flag
keep token_person_id
duplicates drop

frame change hes_2019
frame put token_person_id,into(spine)
frame change spine 
duplicates drop
frlink 1:1 token_person_id, frame(srp_flag)

gen ever_srp_blackburn=0
replace ever_srp_blackburn=1 if srp_flag!=.
drop srp_flag

* Remove the temporary data from memory
frame dir

local variables "srp_flag diagnoses blackburn blackburn_3 blackburn_4 hes_2019"
foreach var of local variables{
	frames drop `var'
	}

local variables "em_adm med_surg operations"
foreach var of local variables{
	frames drop `var'
	}

* We now have some binary flags that indicate the presence of a code in this year.
tab ever_srp_blackburn