library(googlesheets4)
library(dplyr)
library(tidyr)
library(stringr)

url <- "https://docs.google.com/spreadsheets/d/1xfSQqRQIq6pGkJ5jzzv2QhetmX5boaEZoNECpDwXe5I"

# table metadata
meta_tsv <- tibble(
    entity="meta",
    required="TRUE",
    table=c("analysis", "gsr_file")
)

table_names <- meta_tsv$table
tables <- lapply(table_names, function(x) read_sheet(url, sheet=x, skip=1, col_types="c"))
names(tables) <- table_names

tsv_format <- function(t) {
    tables[[t]] %>%
        filter(!is.na(`Data type`)) %>%
        mutate(entity="Table",
               table=t,
               pk=ifelse(paste0(t, "_id") == Column, TRUE, NA),
               type=ifelse(`Data type` == "enumeration", Column, `Data type`)) %>%
        select(entity, table,
               column=Column, type, required=Required,
               pk, ref=References,
               note=Description) %>%
        mutate(note=gsub('"', "'", note), # replace double with single quote
               note=gsub('\n', ' ', note), # replace newline with space
               ref=ifelse(grepl("omop_concept", ref), NA, ref)) # remove external table reference
}

out <- lapply(table_names, tsv_format) %>%
    bind_rows()

# enumerated values
enum_format <- function(t) {
    tables[[t]] %>%
        filter(!is.na(Enumerations)) %>%
        mutate(entity="enum") %>%
        select(entity,
               table=Column,
               column=Enumerations) %>%
        separate_rows(column, sep="\n") %>%
        mutate(column=str_trim(column))
}

enum_tsv <- lapply(table_names, enum_format) %>%
    bind_rows %>%
    distinct()

out <- bind_rows(out, enum_tsv, meta_tsv)

readr::write_tsv(out, file="PRIMED_GSR_data_model.tsv", na="", escape="none")
