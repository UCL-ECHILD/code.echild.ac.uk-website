
* * * * * * * * * * * * * * * * * * * * * * * * * * * 
* Author: Kate Lewis, kate.lewis.14@ucl.ac.uk
* Based on R code by Matthew Jay, matthew.jay@ucl.ac.uk
* Code list: srp_nichobhthaigh_v2
* Tested in Stata version 16.1+
* * * * * * * * * * * * * * * * * * * * * * * * * * * 

* In this script, we adopt a very basic approach to categorising the codes into
* potentially psychosomatic, interanlising, externalising, thought disorders
* and self-harm. The potentially pyschosomatic, internalising and thought
* disorder codes are relatively straight forward. Some of the externalising
* codes, however, are only valid if an X or Z block self-harm code is also
* present in a secondary diagnostic position. There are also some codes in the
* self-harm group where the same is true.

* In this script, where a self-harm code is recorded any any diagnostic position,
* we count the episode as a self-harm episode. As such, the above externalising
* and self-harm codes will always be superceded by the self-harm codes and we
* essentially ignore them. You may wish to adopt a different approach, especially
* if you are interested in multimorbidity.


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
log using "srp_nichobhthaigh_$S_DATE.log", replace*/


* load data and codelist --------------------------------------------------

frame create hes_2019
frame change hes_2019
clear
odbc load, exec(`"SELECT TOP 100000 * from dbo.FILE0184861_HES_APC_2019"') connectionstring("[omitted]") 

foreach var of varlist _all { //change varnames to lowercase
	capture rename `var', lower
	}
	
frame create nichobhthaigh
frame change nichobhthaigh
clear
import delimited "$codelists/srp_nichobhthaigh_v2.csv", varnames(1)

* Remove the dot from the code list file so we can link to HES
replace code = substr(code, 1, 3) + substr(code, 5, 1) if (strlen(code) == 5 & substr(code, 4, 1) == ".")

* trim group names to help the below code to run
gen group2=substr(group,1,5)

* creating a 3- and 4-digit variable to match length of the ICD-10 code
* putting these codes into seperate files, one overall and one for each group 
* we do this because some codes appear more than once in the list 
* which causes problems with merging

forvalues k = 3/4 {
	gen code_`k'_digit = substr(code, 1, `k') if strlen(code) == `k'
}
	
*each group
levelsof group2, local(list)
foreach var of local list{
forvalues k = 3/4 {
	capture frame drop nichobhthaigh_`var'_`k'
	frame put code_`k'_digit flag1 flag2 group subgroup diag_position if code_`k'_digit != "" & group2=="`var'", into(nichobhthaigh_`var'_`k')
	}
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
frame put token_person_id epikey epistart admimeth diag_*, into(diagnoses)  // first put relevant variables in another frame
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

* Create binary flags that indicate whether an episode contains a relevant code.
* We will create different flags for different categories for SRP.
gen poten=0 // Potentially psychosomatic
gen inter=0  // Internalising
gen exter=0  // Externalising
gen thoug=0  // Thought disorders
gen selfh=0  // Self-harm

* Most codes are only counted if they are in the first diagnostic position. We
* therefore also need to create a variable that contains the diag number. We
* will use the existing diag_n variable 


* identify episodes with relevant codes -----------------------------------

* Here we look for both codes and set the new binary
* indicator to TRUE where a relevant code is found.
* (If we had not converted to long format, we would have to apply this operation
* across several columns, which is difficult to code and may take a very significant
* amount of time, especially when using a for loop or the apply() functions.)

* Potentially psychosomatic
forvalue k = 3/4{
	frlink m:1 code_`k'_digit, frame(nichobhthaigh_poten_`k') //matching on 3 and 4 digits as per the specific code list
	replace poten=1 if nichobhthaigh_poten_`k'!=. & frval(nichobhthaigh_poten_`k',diag_position)=="first" & ///
	diag_n==1
	drop nichobhthaigh_poten_`k' //drop linkage vars
	}

* These codes have a med_surg flag, meaning it should not be counted where one of
* the exclusion codes is present.

* Note that this list includes diagnosis and procedure codes.

frame create med_surg
frame change med_surg
import delimited "$codelists/srp_nichobhthaigh_v2_medical.csv", varnames(1)
rename *code code
replace code = substr(code, 1, 3) + substr(code, 5, 1) if (strlen(code) == 5 & substr(code, 4, 1) == ".")

forvalues k = 3/4 {
	gen code_`k'_digit = substr(code, 1, `k') if strlen(code) == `k'
	capture frame drop code_`k'
	frame put code_`k'_digit code_type if code_`k'_digit != "", into(code_`k')
	}
	
frame change diagnoses
gen med_surg_diag=0
forvalue k = 3/4{
	frlink m:1 code_`k'_digit, frame(code_`k') //matching on 3 and 4 digits as per the specific code list
	replace med_surg_diag=1 if code_`k'!=. &  frval(code_`k',code_type)=="icd10"
	drop code_`k' //drop linkage vars
	}
bysort token_person_id epistart: egen med_surg_diag_any=max(med_surg_diag) // add this label to all rows within the same episode
drop med_surg_diag

* add in a flag for operation codes
*convert operations data to long format
frame change hes_2019
frame put token_person_id epikey epistart opertn_*, into(operations)  // first put relevant variables in another frame
frame change operations
rename opertn_0* opertn_* //need to take out the "0" of these label here
reshape long opertn_, i(token_person_id epikey epistart) j(opertn_n) 
rename opertn_ code 
drop if code == "" | code == "-"
gen code_4_digit = substr(code, 1, 4) // there's only 4 digit codes here

gen med_surg_opertn=0
frlink m:1 code_4_digit, frame(code_4) 
replace med_surg_opertn=1 if code_4!=. & frval(code_4,code_type)=="opcs4"
bysort token_person_id epistart: egen med_surg_opertn_any=max(med_surg_opertn) // add this label to all rows within the same episode

keep if med_surg_opertn_any==1
keep token_person_id epistart med_surg_opertn_any
duplicates drop

frame change diagnoses
frlink m:1 token_person_id epistart, frame(operations)
frget med_surg_opertn_any,from(operations)
drop operations

* Now set to FALSE where the episode is medical or surgical.
replace poten=0 if poten==1 & (med_surg_diag==1 | med_surg_opertn==1)
drop med_surg_diag med_surg_opertn


* Internalising
forvalue k = 3/4{
	frlink m:1 code_`k'_digit, frame(nichobhthaigh_inter_`k') //matching on 3 and 4 digits as per the specific code list
	replace inter=1 if nichobhthaigh_inter_`k'!=. & diag_n==1 //All first diagnostic position only
	drop nichobhthaigh_inter_`k' //drop linkage vars
	}
	

* Externalising
* There are some externalising codes that are only counted if an X or Y block
* self-harm code is present in a secondary position. However, these will always
* be counted as self-harm codes and so we ignore them here.
forvalue k = 3/4{
	frlink m:1 code_`k'_digit, frame(nichobhthaigh_exter_`k') //matching on 3 and 4 digits as per the specific code list
	replace exter=1 if nichobhthaigh_exter_`k'!=. & frval(nichobhthaigh_exter_`k',flag2)!="selfharm_xz_codes" & diag_n==1 //All first diagnostic position only
	drop nichobhthaigh_exter_`k' //drop linkage vars
	}


* Thought disorder
forvalue k = 3/4{
	frlink m:1 code_`k'_digit, frame(nichobhthaigh_thoug_`k') //matching on 3 and 4 digits as per the specific code list
	replace thoug=1 if nichobhthaigh_thoug_`k'!=. & diag_n==1 //All first diagnostic position only
	drop nichobhthaigh_thoug_`k' //drop linkage vars
	}



* Self-harm
* There are some self-harm codes that are only counted if an X or Y block
* self-harm code is present in a secondary position. However, these will always
* be counted as self-harm codes and so we ignore them here.
forvalue k = 3/4{
	frlink m:1 code_`k'_digit, frame(nichobhthaigh_selfh_`k') //matching on 3 and 4 digits as per the specific code list
	replace selfh=1 if nichobhthaigh_selfh_`k'!=. & frval(nichobhthaigh_selfh_`k',flag2)!="selfharm_xz_codes" 
	drop nichobhthaigh_selfh_`k' //drop linkage vars
	}


* Now aggregate to episode level. We do this by taking the max() of our
* binary SRP variable by token_person_id and epistart. This aggregates
* to episode level beacause the max() of c(TRUE, FALSE) is TRUE.

* We will order the dataset first so it's easier to inspect should you wish to 
* do so.
sort token_person_id epistart
bysort token_person_id epistart:egen psych_episode=max(poten)
bysort token_person_id epistart:egen internalising_episode=max(inter)
bysort token_person_id epistart:egen externalising_episode=max(exter)
bysort token_person_id epistart:egen thought_dis_episode=max(thoug)
bysort token_person_id epistart:egen selfharm_episode=max(selfh)

* Create variable to identify any SRP
gen any_srp=1 if psych_episode==1 | internalising_episode==1 | ///
	externalising_episode==1 | thought_dis_episode==1 | selfharm_episode==1

* Now we can drop all the episodes that are not SRP episodes (for the sake
* of saving memory).
drop if any_srp!=1


* Deal with flags ---------------------------------------------------------

* We do not need to worry about the remaining selfharm_xz_code flag.
* This indicates that certain codes are only valid if they are in the first
* diagnostic position AND there is an X or Y block self-harm code in any
* position. However, the latter are always counted as SRPs and so such episodes
* are always counted.


* Create spine and flag ---------------------------------------------------

* We will here create a data table that contains one row per patient and then
* create flags to indicate whether a patient ever had a relevant SRP code.
* In real world settings, you might be doing this using a spine of study
* participants created elsewhere and using information only over certain time
* periods. See the ECHILD How To guides for more information and examples.
frame put token_person_id *episode,into(srp_flag)
frame change srp_flag
local variables "psych thought_dis selfharm internalising externalising"
foreach var of local variables{
	bysort token_person_id:egen ever_`var'=max(`var'_episode)
	drop `var'_episode
	}
duplicates drop

frame change hes_2019
frame put token_person_id,into(spine)
frame change spine 
duplicates drop
frlink 1:1 token_person_id, frame(srp_flag)
frget *,from(srp_flag)
gen ever_any_srp=1 if srp_flag!=.
foreach var of varlist ever_any_srp ever_psych ever_thought_dis ever_selfharm ///
	ever_internalising ever_externalising {
	replace `var' = 0 if `var'==.
	}
drop srp_flag 

* Remove the temporary data from memory
frame dir

local variables "srp_flag diagnoses nichobhthaigh code_3 code_4 hes_2019 em_adm med_surg operations"
foreach var of local variables{
	frames drop `var'
	}

local variables "poten exter inter selfh thoug"
foreach var of local variables{
	frames drop nichobhthaigh_`var'_3 
	frames drop nichobhthaigh_`var'_4
	}


* We now have some binary flags that indicate the presence of a code in this year.
tab ever_any_srp
tab ever_psych
tab ever_internalising
tab ever_externalising
tab ever_thought_dis
tab ever_selfharm