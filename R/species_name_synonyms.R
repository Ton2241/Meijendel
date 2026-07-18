# Canonieke publieke soortnamen voor uitwisseling tussen Meijendel, Dashboard,
# Shiny en de VWG-M-website. Interne analyses blijven op soort_id draaien.
SPECIES_NAME_SYNONYMS <- c(
  "Baardmannetje" = "Baardman",
  "Eidereend" = "Eider",
  "Barmsijs" = "Kleine Barmsijs",
  "Europese Kraanvogel" = "Kraanvogel",
  "Europese Oehoe" = "Oehoe",
  "Europese Zeearend" = "Zeearend",
  "Gewone Alk" = "Alk",
  "Gewone Fazant" = "Fazant",
  "Grote Toppereend" = "Topper",
  "Kanoetstrandloper" = "Kanoet",
  "Sprinkhaanrietzanger" = "Sprinkhaanzanger",
  "Tortelduif" = "Zomertortel"
)

clean_species_name <- function(value) {
  trimws(gsub("[[:space:]]+", " ", as.character(value)))
}

canonical_species_name <- function(value) {
  cleaned <- clean_species_name(value)
  match_index <- match(tolower(cleaned), tolower(names(SPECIES_NAME_SYNONYMS)))
  replace <- !is.na(match_index)
  cleaned[replace] <- unname(SPECIES_NAME_SYNONYMS[match_index[replace]])
  cleaned
}

find_species_name_matches <- function(species_names, requested_name) {
  cleaned_names <- clean_species_name(species_names)
  cleaned_requested <- clean_species_name(requested_name)[[1]]

  exact <- which(cleaned_names == cleaned_requested)
  if (length(exact)) return(exact)

  case_insensitive <- which(tolower(cleaned_names) == tolower(cleaned_requested))
  if (length(case_insensitive)) return(case_insensitive)

  canonical_requested <- canonical_species_name(cleaned_requested)[[1]]
  which(tolower(canonical_species_name(cleaned_names)) == tolower(canonical_requested))
}
