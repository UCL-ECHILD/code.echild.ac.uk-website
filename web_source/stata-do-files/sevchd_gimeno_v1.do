
* * * * * * * * * * * * * * * * * * * * * * * * * * * 
* Author: Kate Lewis, kate.lewis.14@ucl.ac.uk
* Based on R code by Matthew Jay, matthew.jay@ucl.ac.uk
* Code list: sevchd_gimeno_v1
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
log using "sevchd_gimeno_$S_DATE.log", replace*/


* load data and codelist --------------------------------------------------

* we use frames in Stata to have data from different files simultaneously open
frame create hes_2019
frame change hes_2019
clear
odbc load, exec(`"SELECT * from dbo.FILE0184861_HES_APC_2019"') connectionstring("[omitted]") 

foreach var of varlist _all { //change varnames to lowercase
	capture rename `var', lower
	}
	
frame create gimeno
frame change gimeno
clear
import delimited "$codelists/sevchd_gimeno_v1.csv", varnames(1)

* Remove the dot from the code list file so we can link to HES
replace code = substr(code, 1, 3) + substr(code, 5, 1) if (strlen(code) == 5 & substr(code, 4, 1) == ".")

*creating a 4-digit variable to match length of the ICD-10 and opcs4 code
*putting these into seperate frames
gen code_4_digit = substr(code, 1, 4) //only 4 digits codes


* convert to long format --------------------------------------------------

* It is significantly easier to work with the diagnostic data in long format.
* This is especially so when working across NPD and HES, or when adopting a 
* spine-based approach as we do in the "How To?" guides. But even here,
* working with just one year of HES data, it is quicker and easier to identify
* relevant episodes in long format and then specify flags in the wide format data.

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

*creating a 4 digit version of each code to match the relevant code list
gen code_4_digit = substr(code, 1, 4) if strlen(code) == 4


* Now do the same for operations. However, all the OPCS-4 codes are only valid
* where the patient is aged less than 5. We therefore need startage in order to
* drop records aged 5+.

* We also need birthweight and gestational age to deal with the bwt_2500_ga_37 flag.
* In reality, this should be cleaned using mother-baby linkage where possible.
* We will take a simple approach here and just use birweit_1 and gestat_1

frame change hes_2019
frame put token_person_id epikey startage opertn_* birweit_1 gestat_1, into(operations)  

frame change operations

rename opertn_0* opertn_* //need to take out the "0" of these label here
reshape long opertn_, i(token_person_id epikey startage birweit_1 gestat_1) j(opertn_n) 
rename opertn_ code 
drop if code == "" | code == "-"
gen code_4_digit = substr(code, 1, 4) // there's only 4 digit codes here
destring startage, replace
drop if (startage>=5 & startage<7000) | startage==.


* create a binary flag ----------------------------------------------------

* Create a binary flag that indicates whether an episode contains a relevant code.
* The plans is:
* 1. This variable is FALSE for all episodes to begin with.
* 2. Where we find a code that is in the code list, we set the variable to TRUE.
* 3. We then deal with special flags, dropping rows from our temporary long format
* dataset where the special conditions are not met.
gen sevchd=0
frame change diagnoses
gen sevchd=0


* identify episodes with relevant codes -----------------------------------

* Here we look for both the 3 and 4 character codes and set the new binary
* indicator to TRUE where a relevant code is found.
* (If we had not converted to long format, we would have to apply this operation
* across several columns, which is difficult to code and may take a very significant
* amount of time, especially when using a for loop or the apply() functions.)

frlink m:1 code_4_digit, frame(gimeno_4) 
replace sevchd=1 if gimeno_4!=. & frval(gimeno_4,code_type)=="icd10"
drop gimeno_4
	
frame change operations	
frlink m:1 code_4_digit, frame(gimeno_4) 
replace sevchd=1 if gimeno_4!=. & frval(gimeno_4,code_type)=="opcs4"
frget flag2, from(gimeno_4) // left join the flag into operations (there are no flags for diagnoses) 
drop gimeno_4
	
* Now we can drop all the rows that are not in the code list as well as the now-
* redundant indicator variable.
frame change diagnoses
keep if sevchd==1

frame change operations
keep if sevchd==1


* deal with flags ---------------------------------------------------------

* We have already dealt with flag1 (operation codes only counted where age is
* less than 5). We now need to deal with the few operation codes with flag2 ==
* bwt_2500_ga_37 (birthweight > 2500 and gestational age >= 37).
* We start by creating a variable for rows to drop (FALSE for all to begin with).
gen to_drop=0

* And then we set it to TRUE where a flag exists and the condition is not met.
* As noted above, we have adopted a very crude approach here. Ideally, you would
* be working with cleaned gestational age and birthweight data.
destring birweit_1 gestat_1,replace
replace to_drop=1 if flag2=="bwt_2500_ga_37" & (birweit_1<=2500 | gestat_1<37)

* Now drop the rows where the conditions are violated, leaving us with a dataset
* of episodes containing codes that are validly in the target list.
drop if to_drop==1
drop to_drop

* Create spine and flag ---------------------------------------------------

* We will here create a data table that contains one row per patient and then
* create flags to indicate whether a patient ever had a relevant SEVCHD code.
* In real world settings, you might be doing this using a spine of study
* participants created elsewhere and using information only over certain time
* periods. See the ECHILD How To guides for more information and examples.

frame put token_person_id,into(sevchd_flag)
frame change diagnoses
frame put token_person_id,into(sevchd_flag2)

frame change sevchd_flag
sysdir set PLUS "[omitted]\Stata\Stata ado\frameappend" //to read in frameappend Stata package
frameappend sevchd_flag2 // append the flags from diagnoses and operations
duplicates drop
frame drop sevchd_flag2

frame change hes_2019
frame put token_person_id,into(spine)
frame change spine 
duplicates drop
frlink 1:1 token_person_id, frame(sevchd_flag)

gen sevchd=0
replace sevchd=1 if sevchd_flag!=.
drop sevchd_flag

* Remove the temporary data from memory
frame dir

local variables "sevchd_flag diagnoses operations gimeno gimeno_3 gimeno_4 hes_2019"
foreach var of local variables{
	frames drop `var'
	}

* We now have some binary flags that indicate the presence of a code in this year.
tab sevchd