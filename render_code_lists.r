
# load source data
code_lists <- read.csv("page_template/page_template.csv",
                       fileEncoding = "UTF-8",
                       encoding = "UTF-8")

# Write index file
index_filename <- "code_list_index.qmd"
index_filepath <- paste0("web_source/", index_filename)

# Delete any existing file and start again
if(file.exists(index_filepath)) file.remove(index_filepath)
file.create(index_filepath)

index_fileConn <- file(index_filepath, 
                       open = "at",
                       encoding = "UTF-8")
                       
write("# Code lists {.unnumbered}\n", index_fileConn)
write("| Code list name (version and link) | Target phenotype | Ref |", index_fileConn)
write("|---|---|---|", index_fileConn)

# Append to _quarto.yml
quarto_fileConn <- file("web_source/_quarto.yml", 
                          open = "at",
                          encoding = "UTF-8")

write("\n", quarto_fileConn)
write(paste0("    - part: ", index_filename), quarto_fileConn)
write("      chapters:", quarto_fileConn)

for (i in 1:nrow(code_lists)) {
  
  ## Create one .qmd file per code list
  # Extract each element as an object
  name <- code_lists[i, ]$name
  version <- code_lists[i, ]$version
  id <- code_lists[i, ]$id
  prev_vers <- code_lists[i, ]$prev_vers
  n_files <- code_lists[i, ]$n_files
  codelist_file <- code_lists[i, ]$codelist_file
  restrictions_file <- code_lists[i, ]$restrictions_file
  removals_file <- code_lists[i, ]$removals_file
  truncations_file <- code_lists[i, ]$truncations_file
  prev_vers_link <- code_lists[i, ]$prev_vers_link
  r_script <- code_lists[i, ]$r_script
  stata_script <- code_lists[i, ]$stata_script
  prepared_by_for_repo <- code_lists[i, ]$prepared_by_for_repo
  first_check <- code_lists[i, ]$first_check
  second_check <- code_lists[i, ]$second_check
  date_added <- code_lists[i, ]$date_added
  date_added <- as.Date(date_added, format = "%d/%m/%Y")
  
  authors <- code_lists[i, ]$authors
  year <- code_lists[i, ]$year
  ref <- code_lists[i, ]$ref
  ref_url <- code_lists[i, ]$ref_url
  target_phenotype <- code_lists[i, ]$target_phenotype
  dataset <- code_lists[i, ]$dataset
  datafields <- code_lists[i, ]$datafields
  summary <- code_lists[i, ]$summary
  dev_val <- code_lists[i, ]$dev_val
  original_purpose <- code_lists[i, ]$original_purpose
  groups <- code_lists[i, ]$groups
  flags <- code_lists[i, ]$flags
  other_details <- code_lists[i, ]$other_details
  adaptations_from_original <- code_lists[i, ]$adaptations_from_original
  changes_since_first_version <- code_lists[i, ]$changes_since_first_version
  n_codes <- code_lists[i, ]$n_codes
  n_codes_removed <- code_lists[i, ]$n_codes_removed
  n_codes_truncated <- code_lists[i, ]$n_codes_truncated
  
  # Write file and connect to it
  qmd_filename <- paste0(id, ".qmd")
  qmd_filepath <- paste0("web_source/", qmd_filename)
  
  file.create(qmd_filepath)
  fileConn <- file(qmd_filepath, 
                   open = "at",
                   encoding = "UTF-8")
  
  # Add content
  # Header
  write(paste0("# ", name, " {.unnumbered}\n"), fileConn)
  
  # Repository details
  write(paste0("## Repository details\n"), fileConn)
  write("| | |", fileConn)
  write("|---|---|", fileConn)
  write(paste0("| **Name** | ", name, " |"), fileConn)
  write(paste0("| **Version** | ", version, " |"), fileConn)
  write(paste0("| **id** | ", id, " |"), fileConn)
  if (!is.na(prev_vers)) {
    write(paste0("| **Previous version** | [", prev_vers, "](", prev_vers, ".qmd) |"), fileConn)
  } else {
    write(paste0("| **Previous version** | NA |"), fileConn)
  }
  write(paste0("| **Number of files** | ", n_files, " |"), fileConn)
  write(paste0("| **Code list file** | [", id, ".csv](", codelist_file, ") |"), fileConn)
  if (!is.na(restrictions_file)) {
    restrictions_filename <- paste0(id, "_restrictions.csv")
    write(paste0("| **Restrictions file** | [", restrictions_filename, "](", restrictions_file, ") |"), fileConn)
  } else {
    write(paste0("| **Restrictions file** | NA |"), fileConn)
  }
  if (!is.na(truncations_file)) {
    truncations_filename <- paste0(id, "_trunactions.csv")
    write(paste0("| **Truncations file** | [", truncations_filename, "](", truncations_file, ") |"), fileConn)
  } else {
    write(paste0("| **Truncations file** | NA |"), fileConn)
  }
  if (!is.na(removals_file)) {
    removals_filename <- paste0(id, "_removals.csv")
    write(paste0("| **Removals file** | [", removals_filename, "](", removals_file, ") |"), fileConn)
  } else {
    write(paste0("| **Removals file** | NA |"), fileConn)
  }
  
  if (!is.na(r_script)) {
    r_script_filename <- paste0(id, ".r")
    write(paste0("| **R script** | [", r_script_filename, "](", r_script, ") |"), fileConn)
  } else {
    write(paste0("| **R script** | Not yet available |"), fileConn)
  }
  if (!is.na(stata_script)) {
    stata_script_filename <- paste0(id, ".do")
    write(paste0("| **Stata do file** | [", stata_script_filename, "](", stata_script, ") |"), fileConn)
  } else {
    write(paste0("| **Stata do file** | Not yet available |"), fileConn)
  }
  write(paste0("| **Prepared for repo by** | ", prepared_by_for_repo, " |"), fileConn)
  write(paste0("| **First check** | ", first_check, " |"), fileConn)
  write(paste0("| **Second check** | ", second_check, " |"), fileConn)
  write(paste0("| **Date added** | ", date_added, " |\n"), fileConn)
  
  # Codelist background
  write("## Background information\n", fileConn)
  write("| | |", fileConn)
  write("|---|---|", fileConn)
  write(paste0("| **Authors** | ", authors, " |"), fileConn)
  write(paste0("| **Year** | ", year, " |"), fileConn)
  write(paste0("| **Reference** | [", ref, "](", ref_url, "){target=\"_blank\"} |"), fileConn)
  write(paste0("| **Target phenotype** | ", target_phenotype, " |"), fileConn)
  write(paste0("| **Dataset ** | ", dataset, " |"), fileConn)
  write(paste0("| **Datafields ** | ", datafields, " |"), fileConn)
  write(paste0("| **Summary** | ", summary, " |"), fileConn)
  write(paste0("| **Validation** | ", dev_val, " |"), fileConn)
  write(paste0("| **Original purpose** | ", original_purpose, " |"), fileConn)
  write(paste0("| **Groups** | ", groups, " |"), fileConn)
  write(paste0("| **Flags** | ", flags, " |"), fileConn)
  write(paste0("| **Other details** | ", other_details, " |"), fileConn)
  write(paste0("| **Changes from original** | ", adaptations_from_original, " |"), fileConn)
  write(paste0("| **Changes since first version in repo** | ", changes_since_first_version, " |"), fileConn)
  write(paste0("| **Number of codes** | ", n_codes, " |"), fileConn)
  write(paste0("| **Codes removed** | ", n_codes_removed, " |"), fileConn)
  write(paste0("| **Codes truncated** | ", n_codes_truncated, " |"), fileConn)
  
  # Preview
  write("\n", fileConn)
  write("## Preview\n", fileConn)
  write(":::{.scrolling}\n", fileConn)
  write("```{r}", fileConn)
  write("#| echo: false", fileConn)
  write("library(knitr)", fileConn)
  write(paste0("dt <- read.csv(\"", codelist_file, "\")"), fileConn)
  write("kable(dt)", fileConn)
  write("```\n", fileConn)
  write(":::", fileConn)
  
  close(fileConn)
  
  ## Add to index file
  write(paste0("| ",
               "[", name, " (", version, ")](", qmd_filename, ") | ",
               target_phenotype, " | ",
               "[", ref, "](", ref_url, "){target=\"_blank\"} | "),
        index_fileConn)
  
  ## Add to _quarto.yml
  write(paste0("      - ", qmd_filename), quarto_fileConn)
}

close(index_fileConn)
close(quarto_fileConn)