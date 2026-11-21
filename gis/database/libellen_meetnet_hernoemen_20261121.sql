-- Lokale migratie op MySQL 9.7.4. Eén atomaire naamswijziging.
-- Zie docs/database/LIBELLEN_MIGRATIE_20261121.md voor controles en herstel.
RENAME TABLE
  Meijendel.ndff_libel_routefamilie TO Meijendel.libellen_routefamilie,
  Meijendel.ndff_libel_routegeometrie TO Meijendel.libellen_routegeometrie,
  Meijendel.ndff_libel_bezoek TO Meijendel.libellen_bezoek,
  Meijendel.ndff_libel_bezoek_taxon TO Meijendel.libellen_bezoek_taxon;
