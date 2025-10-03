
# # # # # # # # # # # # # # # # # # # # # # # # # # # 
# Author: Ania Zylbersztejn, ania.zylbersztejn@ucl.ac.uk, with thanks to Matthew Jay
# Code list: neuro_zylbersztejn_v1
# # # # # # # # # # # # # # # # # # # # # # # # # # # 


# set-up ------------------------------------------------------------------

# Clear workspace
rm(list=ls())

# Set global settings, such as your working directory, load libraries and specify
# the ODBC connection string.

setwd("[omitted]")
assign(".lib.loc", c(.libPaths(), "[omitted]"), envir = environment(.libPaths))
library(data.table)
library(RODBC)

conn_str <- odbcDriverConnect("[omitted]")


# load data and codelist --------------------------------------------------

hes_2019 <- data.table(sqlQuery(conn_str, "select top 100000 * from FILE0184861_HES_APC_2019"))
setnames(hes_2019, names(hes_2019), tolower(names(hes_2019)))
neuro <- fread("codelists/neuro_zylbersztejn_v1.csv", stringsAsFactors = F)
rm(conn_str)

# Remove the dot from the code list file so we can link to HES
neuro[, code := gsub("\\.", "", code)]

# Save 4 sets of code lists: separate for diagnoses and procedures and those with additional age restriction:
neuro_diag_any <- neuro[field=="diag" & age_criteria==0, ]
neuro_diag_28days <- neuro[field=="diag" & age_criteria==1, ]
neuro_opertn_any <- neuro[field=="opertn" & age_criteria==0, ]
neuro_opertn_28days <- neuro[field=="opertn" & age_criteria==1, ]

# Start with diagnostic codes --------------------------------------------------

## convert diagnoses to long format --------------------------------------------------

# It is significantly easier to work with the diagnostic data in long format.
# This is especially so when working across NPD and HES, or when adopting a 
# spine-based approach as we do in the "How To?" guides. But even here,
# working with just one year of HES data, it is quicker and easier to identify
# relevant episodes in long format and then specify flags in the wide format data.

diag_cols <-
  names(hes_2019)[grepl("^diag", names(hes_2019))]

diagnoses <-
  melt(hes_2019[, c("token_person_id",
                    "epikey",
                    "startage",
                    "admidate",
                    "disdate",
                    "epiend",
                    diag_cols),
                with = F],
       id.vars = c("token_person_id",
                   "epikey",
                   "startage",
                   "admidate",
                   "disdate",
                   "epiend"),
       variable.name = "diag_n",
       value.name = "code")

# There are some codes in HES with 5 or 6 characters, some of which which relate
# to the asterisk and dagger system (see the primer for details). As these are not
# relevant, we truncate all codes to the first 4 characters only.
diagnoses[, code := substr(code, 1, 4)]

# We can drop empty rows (i.e. where no diagnosis was recorded in a given position)
# as these are now redundant.
diagnoses <- diagnoses[code != ""]


## create a binary flag ----------------------------------------------------

# Create a binary flag that indicates whether an episode contains a relevant code.
# This variable is FALSE for all episodes to begin with.
# Where we find a code that is in the code list, we set the variable to TRUE.
diagnoses[,neuro_flag := F]

## identify episodes with relevant codes -----------------------------------

# Here we look for both the 3 and 4 character codes and set the new binary
# indicator to TRUE where a relevant code is found.

# we start with codes that have no additional restrictions
diagnoses[substr(code, 1, 3) %in% neuro_diag_any[nchar(code) == 3]$code, neuro_flag := T]
diagnoses[substr(code, 1, 4) %in% neuro_diag_any[nchar(code) == 4]$code, neuro_flag  := T]

# we repeat for codes where age at start needs to be <28 days by adding an age criterion
# note ages in HES for infants are coded as: 
# 7001 = Less than 1 day
# 7002 = 1 to 6 days
# 7003 = 7 to 28 days 
diagnoses[substr(code, 1, 3) %in% neuro_diag_28days[nchar(code) == 3]$code & startage>7000 & startage<7004, neuro_flag := T]
diagnoses[substr(code, 1, 4) %in% neuro_diag_28days[nchar(code) == 4]$code & startage>7000 & startage<7004, neuro_flag  := T]

# Now we can drop all the rows that are not in the code list as well as the now-
# redundant indicator variable.
diagnoses <- diagnoses[neuro_flag == T]
diagnoses[, neuro_flag := NULL]


# now work with operations -----------------------------------------------------------

## convert operations to long format --------------------------------------------------

# It is significantly easier to work with the opertnnostic data in long format.
# This is especially so when working across NPD and HES, or when adopting a 
# spine-based approach as we do in the "How To?" guides. But even here,
# working with just one year of HES data, it is quicker and easier to identify
# relevant episodes in long format and then specify flags in the wide format data.

opertn_cols <-
  names(hes_2019)[grepl("^opertn", names(hes_2019))]

operations <-
  melt(hes_2019[, c("token_person_id",
                    "epikey",
                    "startage",
                    "admidate",
                    "disdate",
                    "epiend",
                    opertn_cols),
                with = F],
       id.vars = c("token_person_id",
                   "epikey",
                   "startage",
                   "admidate",
                   "disdate",
                   "epiend"),
       variable.name = "opertn_n",
       value.name = "code")

# There are some codes in HES with 5 or 6 characters, some of which which relate
# to the asterisk and dagger system (see the primer for details). As these are not
# relevant, we truncate all codes to the first 4 characters only.
operations[, code := substr(code, 1, 4)]

# We can drop empty rows (i.e. where no opertnnosis was recorded in a given position)
# as these are now redundant.
operations <- operations[code != ""]


# create a binary flag ----------------------------------------------------

# Create a binary flag that indicates whether an episode contains a relevant code.
# This variable is FALSE for all episodes to begin with.
# Where we find a code that is in the code list, we set the variable to TRUE.
operations[, neuro_flag := F]

# identify episodes with relevant codes -----------------------------------

# Here we look for both the 3 and 4 character codes and set the new binary
# indicator to TRUE where a relevant code is found.

# we start with codes that have no additional restrictions
operations[substr(code, 1, 3) %in% neuro_opertn_any[nchar(code) == 3]$code, neuro_flag := T]
operations[substr(code, 1, 4) %in% neuro_opertn_any[nchar(code) == 4]$code, neuro_flag  := T]

# we repeat for codes where age at start needs to be <28 days by adding an age criterion
# note ages in HES for infants are coded as: 
# 7001 = Less than 1 day
# 7002 = 1 to 6 days
# 7003 = 7 to 28 days 
operations[substr(code, 1, 3) %in% neuro_opertn_28days[nchar(code) == 3]$code & startage>7000 & startage<7004, neuro_flag := T]
operations[substr(code, 1, 4) %in% neuro_opertn_28days[nchar(code) == 4]$code & startage>7000 & startage<7004, neuro_flag  := T]

# Now we can drop all the rows that are not in the code list as well as the now-
# redundant indicator variable.
operations <- operations[neuro_flag == T]
operations[, neuro_flag := NULL]


# Create spine and flag ---------------------------------------------------

# We will here create a data table that contains one row per patient and then
# create flags to indicate whether a patient ever had a relevant CHC code.
# In real world settings, you might be doing this using a spine of study
# participants created elsewhere and using information only over certain time
# periods. See the ECHILD How To guides for more information and examples.

spine <-
  data.table(
    token_person_id = unique(hes_2019$token_person_id)
  )

# We will just create flags for just some groups for the sake of example.
spine[, neuro_any := token_person_id %in% diagnoses$token_person_id | token_person_id %in% operations$token_person_id]

# Remove the temporary data from memory
rm(diagnoses, diag_cols, operations, opertn_cols, hardelid, hes_2019)

# We now have some binary flags that indicate the presence of a code in this year.
table(spine$neuro_any , useNA = "always")

