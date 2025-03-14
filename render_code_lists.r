
# load source data
code_lists <- read.csv("page_template/page_template.csv")

# Write index file
index_filename <- "code_list_index.qmd"
index_fileConn <- paste0("web_source/", index_filename)
write("", index_fileConn) # overwrite any existing file and start again
write("# Code lists {.unnumbered}\n", index_fileConn, append = T)
write("| Code list name (version and link) | Target phenotype | Ref |", index_fileConn, append = T)
write("|---|---|---|", index_fileConn, append = T)

# Modify _quarto.yml
quarto_fileConn <- "web_source/_quarto.yml"

write("\n", quarto_fileConn, append = T)
write(paste0("    - part: ", index_filename), quarto_fileConn, append = T)
write("      chapters:", quarto_fileConn, append = T)

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
  fileConn <- paste0("web_source/", qmd_filename)
  
  # Add content
  # Header
  write(paste0("# ", name, " {.unnumbered}\n"), fileConn, append = T)
  
  # Repository details
  write(paste0("## Repository details\n"), fileConn, append = T)
  write("| | |", fileConn, append = T)
  write("|---|---|", fileConn, append = T)
  write(paste0("| **Name** | ", name, " |"), fileConn, append = T)
  write(paste0("| **Version** | ", version, " |"), fileConn, append = T)
  write(paste0("| **id** | ", id, " |"), fileConn, append = T)
  if (!is.na(prev_vers)) {
    write(paste0("| **Previous version** | [", prev_vers, "](", prev_vers, ".qmd) |"), fileConn, append = T)
  } else {
    write(paste0("| **Previous version** | NA |"), fileConn, append = T)
  }
  write(paste0("| **Number of files** | ", n_files, " |"), fileConn, append = T)
  write(paste0("| **Code list file** | [", id, ".csv](", codelist_file, ") |"), fileConn, append = T)
  if (!is.na(restrictions_file)) {
    restrictions_filename <- paste0(id, "_restrictions.csv")
    write(paste0("| **Restrictions file** | [", restrictions_filename, "](", restrictions_file, ") |"), fileConn, append = T)
  } else {
    write(paste0("| **Restrictions file** | NA |"), fileConn, append = T)
  }
  if (!is.na(truncations_file)) {
    truncations_filename <- paste0(id, "_trunactions.csv")
    write(paste0("| **Truncations file** | [", truncations_filename, "](", truncations_file, ") |"), fileConn, append = T)
  } else {
    write(paste0("| **Truncations file** | NA |"), fileConn, append = T)
  }
  if (!is.na(removals_file)) {
    removals_filename <- paste0(id, "_removals.csv")
    write(paste0("| **Removals file** | [", removals_filename, "](", removals_file, ") |"), fileConn, append = T)
  } else {
    write(paste0("| **Removals file** | NA |"), fileConn, append = T)
  }
  
  if (!is.na(r_script)) {
    r_script_filename <- paste0(id, ".r")
    write(paste0("| **R script** | [", r_script_filename, "](", r_script, ") |"), fileConn, append = T)
  } else {
    write(paste0("| **R script** | Not yet available |"), fileConn, append = T)
  }
  if (!is.na(stata_script)) {
    stata_script_filename <- paste0(id, ".do")
    write(paste0("| **Stata do file** | [", stata_script_filename, "](", stata_script, ") |"), fileConn, append = T)
  } else {
    write(paste0("| **Stata do file** | Not yet available |"), fileConn, append = T)
  }
  write(paste0("| **Prepared for repo by** | ", prepared_by_for_repo, " |"), fileConn, append = T)
  write(paste0("| **First check** | ", first_check, " |"), fileConn, append = T)
  write(paste0("| **Second check** | ", second_check, " |"), fileConn, append = T)
  write(paste0("| **Date added** | ", date_added, " |\n"), fileConn, append = T)
  
  # Codelist background
  write("## Background information\n", fileConn, append = T)
  write("| | |", fileConn, append = T)
  write("|---|---|", fileConn, append = T)
  write(paste0("| **Authors** | ", authors, " |"), fileConn, append = T)
  write(paste0("| **Year** | ", year, " |"), fileConn, append = T)
  write(paste0("| **Reference** | [", ref, "](", ref_url, "){target=\"_blank\"} |"), fileConn, append = T)
  write(paste0("| **Target phenotype** | ", target_phenotype, " |"), fileConn, append = T)
  write(paste0("| **Dataset ** | ", dataset, " |"), fileConn, append = T)
  write(paste0("| **Datafields ** | ", datafields, " |"), fileConn, append = T)
  write(paste0("| **Summary** | ", summary, " |"), fileConn, append = T)
  write(paste0("| **Validation** | ", dev_val, " |"), fileConn, append = T)
  write(paste0("| **Original purpose** | ", original_purpose, " |"), fileConn, append = T)
  write(paste0("| **Groups** | ", groups, " |"), fileConn, append = T)
  write(paste0("| **Flags** | ", flags, " |"), fileConn, append = T)
  write(paste0("| **Other details** | ", other_details, " |"), fileConn, append = T)
  write(paste0("| **Changes from original** | ", adaptations_from_original, " |"), fileConn, append = T)
  write(paste0("| **Changes since first version in repo** | ", changes_since_first_version, " |"), fileConn, append = T)
  write(paste0("| **Number of codes** | ", n_codes, " |"), fileConn, append = T)
  write(paste0("| **Codes removed** | ", n_codes_removed, " |"), fileConn, append = T)
  write(paste0("| **Codes truncated** | ", n_codes_truncated, " |"), fileConn, append = T)
  
  # Preview
  write("\n", fileConn, append = T)
  write("## Preview\n", fileConn, append = T)
  write(":::{.scrolling}\n", fileConn, append = T)
  write("```{r}", fileConn, append = T)
  write("#| echo: false", fileConn, append = T)
  write("library(knitr)", fileConn, append = T)
  write(paste0("dt <- read.csv(\"", codelist_file, "\")"), fileConn, append = T)
  write("kable(dt)", fileConn, append = T)
  write("```\n", fileConn, append = T)
  write(":::", fileConn, append = T)
  
  ## Add to index file
  write(paste0("| ",
               "[", name, " (", version, ")](", qmd_filename, ") | ",
               target_phenotype, " | ",
               "[", ref, "](", ref_url, "){target=\"_blank\"} | "),
        index_fileConn, append = T)
  
  ## Add to _quarto.yml
  write(paste0("      - ", qmd_filename), quarto_fileConn, append = T)
  
}
