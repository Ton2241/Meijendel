source("shiny_meijendel/helpers.R")
dump <- file.path(Sys.getenv("TMPDIR"), "visit-copy-fixture.sql")
writeLines(c(
  "INSERT INTO `bronnen` VALUES (1,'sovon_m',NULL),(11,'sovon_bmp_grenscorrectie_kopie','Herclustering');",
  "INSERT INTO `dagbezoeken_bmp` VALUES (10,3526,2024,'2024-04-10',101,'07:00:00','08:00:00',60,0,NULL,1,NULL,'opmerking, met haakjes (test)',4,5,1,'2026-11-18 20:00:00'),(20,3501,2024,'2024-04-10',101,'07:00:00','08:00:00',60,0,NULL,1,NULL,NULL,2,3,11,'2026-11-18 20:00:00');"
),dump)
out <- read_dagbezoeken_bmp_fast(dump)
stopifnot(identical(out$bezoek_id,"10"),identical(out$bezoekduur_min,"60"))
writeLines("INSERT INTO `dagbezoeken_bmp` VALUES (30,3501,2023,'2023-04-10',100,'07:00:00','08:00:00',60,0,NULL,1,NULL,NULL,4,5,1,'2026-11-18 20:00:00');", dump)
stopifnot(identical(read_dagbezoeken_bmp_fast(dump)$bezoek_id,"30"))
writeLines(paste0(
  "INSERT INTO `dagwaarnemingen_bmp` VALUES ",
  "(1,20,10,3526,23,2024,4,10,101,1,2,'X',NULL,'opmerking, met haakjes (test)',2,100,1,2,0,NULL,0,84400,460000,0x0000,1,'2026-11-18 20:00:00'),",
  "(2,21,20,3501,23,2024,4,10,101,1,2,'X',NULL,NULL,2,100,1,2,1,4,1,84400,460000,0x0000,1,'2026-11-18 20:00:00');"
), dump)
points <- read_dagwaarnemingen_bmp_fast(dump)
stopifnot(identical(points$in_plot, c("0", "1")))
stopifnot(identical(points$cluster_territorium, c("0", "1")))
trial <- Sys.getenv("MEIJENDEL_TEST_BMP_DUMP")
if (nzchar(trial)) {
  visits <- read_dagbezoeken_bmp_fast(trial)
  points <- read_dagwaarnemingen_bmp_fast(trial)
  stopifnot(nrow(visits) == 79L, nrow(points) == 4726L)
  stopifnot(all(c("0", "1") %in% points$in_plot))
}
cat("BMP-bezoekkopieën, binnen-plotstatus en oudere dumps gecontroleerd\n")
