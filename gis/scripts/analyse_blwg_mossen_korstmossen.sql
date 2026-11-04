-- Korstmossen en mossen in Meijendel: alleen-lezen analyse (MySQL 9).
-- Uitvoeren tegen de lokale database Meijendel. Geen tabellen of bronregels wijzigen.
-- De primaire BLWG-formulieren, provinciale PQ's en secundaire NDFF-regels
-- hebben verschillende teleenheden: uitkomsten NOOIT optellen.
-- Query's 1-9 lezen geen beschermde taxa of exacte plotcoordinaten.
-- Query 10 leest de afgeschermde formuliermatrix maar geeft uitsluitend
-- totalen per meetjaar terug; voer deze alleen lokaal en bevoegd uit.
-- Plot-ID's in query's 1-8 zijn uitsluitend voor intern gebruik.
-- Meetjaar = YEAR(velddatum), NIET rapportagejaar (bij 40/44 formulieren
-- een jaar eerder; bij de vier formulieren uit 2006 gelijk aan veldjaar).
-- Code 0 is een expliciete BLWG-nul, codes 1/2/3/5/6 zijn originele
-- ORDINALE hoeveelheidscodes. Ze mogen niet worden opgeteld of gemiddeld.

-- 1. De korrel van de primaire BLWG-reeks: bronformulieren versus plotjaren.
SELECT
  f.formulierstatus,
  YEAR(f.velddatum) AS meetjaar,
  COUNT(DISTINCT f.bron_plot_id) AS plots,
  COUNT(*) AS formulieren,
  COUNT(DISTINCT CONCAT(f.bron_plot_id, ':', YEAR(f.velddatum))) AS plotjaren
FROM Meijendel.korstmossen_bron_formulier AS f
GROUP BY f.formulierstatus, YEAR(f.velddatum)
ORDER BY f.formulierstatus, meetjaar;

-- 2. Een regel per plotjaar van de VIER VASTE plots. Meerdere formulieren
-- tellen als een meetronde. Aanwezig als ten minste een waarnemer de soort
-- meldde; alleen nul als alle formulieren voor dat taxon nul zijn. Onenigheid
-- over aanwezigheid en over codes wordt apart geteld.
WITH per_taxon AS (
  SELECT
    f.bron_plot_id, YEAR(f.velddatum) AS meetjaar,
    t.taxon_bronkoppeling_id,
    COUNT(*) AS formulieren,
    SUM(t.waarnemingsstatus = 'waargenomen') AS positieve_formulieren,
    SUM(t.waarnemingsstatus = 'echte_nul') AS nulformulieren,
    COUNT(DISTINCT IF(t.waarnemingsstatus = 'waargenomen',
                      t.hoeveelheidscode, NULL)) AS verschillende_positieve_codes
  FROM Meijendel.korstmossen_bron_formulier AS f
  JOIN Meijendel.korstmossen_bron_formulier_taxon AS t
    ON t.bronbestand_sha256 = f.bronbestand_sha256 AND t.kopid = f.kopid
  WHERE f.formulierstatus = 'vast_plot_volledige_lijst'
  GROUP BY f.bron_plot_id, YEAR(f.velddatum), t.taxon_bronkoppeling_id
)
SELECT
  bron_plot_id, meetjaar, MAX(formulieren) AS formulieren_per_meetronde,
  COUNT(*) AS onderzochte_openbare_taxa,
  SUM(positieve_formulieren > 0) AS soortenrijkdom_aanwezig,
  SUM(positieve_formulieren = 0 AND nulformulieren = formulieren) AS echte_nullen,
  SUM(positieve_formulieren > 0 AND nulformulieren > 0)
    AS aanwezigheid_waarnemersverschil,
  SUM(verschillende_positieve_codes > 1) AS hoeveelheidscode_verschil
FROM per_taxon
GROUP BY bron_plot_id, meetjaar
ORDER BY bron_plot_id, meetjaar;

-- 3. Een regel per plotjaar en BRONtaxon, voor controle van aanwezigheid,
-- echte nul en oorspronkelijke code(s). Beschermde taxa staan niet in deze
-- openbare bronmatrix. De bronkoppeling blijft zichtbaar: voeg een taxon
-- alleen met een andere bron samen na een bevestigde conceptuele koppeling.
SELECT
  f.bron_plot_id, YEAR(f.velddatum) AS meetjaar,
  b.bron_wetenschappelijke_naam AS bronnaam,
  t.taxon_bronkoppeling_id, b.taxon_id,
  COUNT(*) AS formulieren,
  SUM(t.waarnemingsstatus = 'waargenomen') AS positieve_formulieren,
  SUM(t.waarnemingsstatus = 'echte_nul') AS nulformulieren,
  CASE
    WHEN SUM(t.waarnemingsstatus = 'waargenomen') > 0 THEN 'aanwezig'
    WHEN f.formulierstatus = 'vast_plot_volledige_lijst'
         AND SUM(t.waarnemingsstatus = 'echte_nul') = COUNT(*)
      THEN 'echte_nul'
    ELSE 'geen_nul_afleidbaar'
  END AS plotjaar_status,
  GROUP_CONCAT(DISTINCT IF(t.waarnemingsstatus = 'waargenomen',
                           t.hoeveelheidscode, NULL)
               ORDER BY t.hoeveelheidscode SEPARATOR ',') AS positieve_codes
FROM Meijendel.korstmossen_bron_formulier AS f
JOIN Meijendel.korstmossen_bron_formulier_taxon AS t
  ON t.bronbestand_sha256 = f.bronbestand_sha256 AND t.kopid = f.kopid
JOIN Meijendel.taxa_bronkoppeling AS b
  ON b.koppeling_id = t.taxon_bronkoppeling_id
GROUP BY f.bron_plot_id, YEAR(f.velddatum), f.formulierstatus,
         b.bron_wetenschappelijke_naam, t.taxon_bronkoppeling_id, b.taxon_id
ORDER BY f.bron_plot_id, meetjaar, bronnaam;

-- 4. Verdeling van de originele BLWG-codes per plotjaar, op taxonkorrel.
-- Bij verschillende positieve codes van twee waarnemers: aparte klasse
-- 'verschillende_codes', dus geen willekeurige maximum- of gemiddelde code.
WITH per_taxon AS (
  SELECT
    f.bron_plot_id, YEAR(f.velddatum) AS meetjaar,
    t.taxon_bronkoppeling_id,
    SUM(t.waarnemingsstatus = 'waargenomen') AS positief,
    MIN(IF(t.waarnemingsstatus = 'waargenomen',
           t.hoeveelheidscode, NULL)) AS min_code,
    MAX(IF(t.waarnemingsstatus = 'waargenomen',
           t.hoeveelheidscode, NULL)) AS max_code
  FROM Meijendel.korstmossen_bron_formulier AS f
  JOIN Meijendel.korstmossen_bron_formulier_taxon AS t
    ON t.bronbestand_sha256 = f.bronbestand_sha256 AND t.kopid = f.kopid
  WHERE f.formulierstatus = 'vast_plot_volledige_lijst'
  GROUP BY f.bron_plot_id, YEAR(f.velddatum), t.taxon_bronkoppeling_id
)
SELECT bron_plot_id, meetjaar,
       CASE WHEN positief = 0 THEN '0_echte_nul'
            WHEN min_code <> max_code THEN 'verschillende_codes'
            ELSE CAST(min_code AS CHAR) END AS oorspronkelijke_code_klasse,
       COUNT(*) AS taxa
FROM per_taxon
GROUP BY bron_plot_id, meetjaar, oorspronkelijke_code_klasse
ORDER BY bron_plot_id, meetjaar, oorspronkelijke_code_klasse;

-- 5. Beschrijvende verandering per vast plot tussen opeenvolgende
-- meetronden. Een nul is hier alleen de BLWG-formuliernul; geen NDFF-nul.
WITH per_taxon AS (
  SELECT f.bron_plot_id, YEAR(f.velddatum) AS meetjaar,
         t.taxon_bronkoppeling_id,
         MAX(t.waarnemingsstatus = 'waargenomen') AS aanwezig
  FROM Meijendel.korstmossen_bron_formulier AS f
  JOIN Meijendel.korstmossen_bron_formulier_taxon AS t
    ON t.bronbestand_sha256 = f.bronbestand_sha256 AND t.kopid = f.kopid
  WHERE f.formulierstatus = 'vast_plot_volledige_lijst'
  GROUP BY f.bron_plot_id, YEAR(f.velddatum), t.taxon_bronkoppeling_id
), met_vorige AS (
  SELECT bron_plot_id, meetjaar, taxon_bronkoppeling_id, aanwezig,
         LAG(meetjaar) OVER
           (PARTITION BY bron_plot_id, taxon_bronkoppeling_id
            ORDER BY meetjaar) AS vorig_meetjaar,
         LAG(aanwezig) OVER
           (PARTITION BY bron_plot_id, taxon_bronkoppeling_id
            ORDER BY meetjaar) AS eerder_aanwezig
  FROM per_taxon
)
SELECT bron_plot_id, vorig_meetjaar, meetjaar,
       SUM(eerder_aanwezig = 0 AND aanwezig = 1) AS nieuw_gemeld,
       SUM(eerder_aanwezig = 1 AND aanwezig = 0) AS niet_teruggevonden,
       SUM(eerder_aanwezig = 1 AND aanwezig = 1) AS beide_ronden_aanwezig,
       SUM(eerder_aanwezig = 0 AND aanwezig = 0) AS beide_ronden_nul
FROM met_vorige
WHERE vorig_meetjaar IS NOT NULL
GROUP BY bron_plot_id, vorig_meetjaar, meetjaar
ORDER BY bron_plot_id, meetjaar;

-- 6. Provinciale PQ's: aparte PRIMAIRE vegetatiereeks, geen BLWG-formulieren.
-- Soortenrijkdom is het aantal positief genoteerde centraal gekoppelde taxa
-- per origineel PQ-plotjaar. Een 0 in deze uitvoer is GEEN expliciete nul.
SELECT
  o.pq_nummer AS pq_plot, o.jaar AS meetjaar,
  COUNT(DISTINCT CASE WHEN g.groep_code = 'mossen'
                      THEN b.taxon_id END) AS mossen_positief,
  COUNT(DISTINCT CASE WHEN g.groep_code = 'korstmossen'
                      THEN b.taxon_id END) AS korstmossen_positief,
  0 AS expliciete_nulregistraties_in_deze_tabel
FROM Meijendel.pq_vegetatie_opname AS o
LEFT JOIN Meijendel.pq_vegetatie_waarneming AS w
  ON w.opname_id = o.opname_id
LEFT JOIN Meijendel.taxa_bronkoppeling AS b
  ON b.koppeling_id = w.taxon_bronkoppeling_id
LEFT JOIN Meijendel.taxa AS tx ON tx.taxon_id = b.taxon_id
LEFT JOIN Meijendel.taxon_groepen AS g ON g.groep_id = tx.groep_id
GROUP BY o.pq_nummer, o.jaar
ORDER BY o.pq_nummer, o.jaar;

-- 7. De PQ-bedekkingscode heeft een ANDERE schaal dan BLWG-Kwantiteit.
-- Toon de originele PQ-codes dus apart; vergelijk ze niet numeriek met 1-6.
SELECT o.pq_nummer AS pq_plot, o.jaar AS meetjaar,
       g.groep_code, w.abundantie_code, COUNT(*) AS positieve_taxonregels
FROM Meijendel.pq_vegetatie_opname AS o
JOIN Meijendel.pq_vegetatie_waarneming AS w
  ON w.opname_id = o.opname_id
JOIN Meijendel.taxa_bronkoppeling AS b
  ON b.koppeling_id = w.taxon_bronkoppeling_id
JOIN Meijendel.taxa AS tx ON tx.taxon_id = b.taxon_id
JOIN Meijendel.taxon_groepen AS g ON g.groep_id = tx.groep_id
WHERE g.groep_code IN ('mossen','korstmossen')
GROUP BY o.pq_nummer, o.jaar, g.groep_code, w.abundantie_code
ORDER BY pq_plot, meetjaar, g.groep_code, w.abundantie_code;

-- 8. NDFF-mosreconstructie 02.204: kilometerhok/inventarisatie, NIET
-- hetzelfde als een BLWG- of PQ-plot. Geen echte nul. Een inventarisatie
-- overspant 2010-2011; wijs die niet kunstmatig aan een enkel jaar toe.
SELECT i.hoknummer, i.eerste_jaar, i.laatste_jaar, i.jaarstatus,
       COUNT(*) AS positief_geregistreerde_taxa,
       0 AS echte_nullen,
       i.lijststatus, i.inspanningstatus
FROM Meijendel.mossen_inventarisatie AS i
JOIN Meijendel.mossen_inventarisatie_taxon AS t
  ON t.reconstructieversie = i.reconstructieversie
 AND t.inventarisatie_sleutel = i.inventarisatie_sleutel
WHERE i.reconstructieversie = 'ndff-mos-v2'
GROUP BY i.reconstructieversie, i.inventarisatie_sleutel,
         i.hoknummer, i.eerste_jaar, i.laatste_jaar, i.jaarstatus,
         i.lijststatus, i.inspanningstatus
ORDER BY i.hoknummer, i.eerste_jaar;

-- 9. Overige NDFF-mos/korstmosrecords: controle op omvang en tijdsbereik,
-- alleen verspreidingscontext. Polygonen zijn geen bewezen plot/route.
-- Deze bronregels omvatten tevens de NDFF-weergave van BLWG/PQ-opnamen:
-- dus niet bij 2, 6 of 8 optellen.
SELECT 'mossen' AS groep, COUNT(*) AS openbare_ndff_regels,
       MIN(jaar) AS eerste_jaar, MAX(jaar) AS laatste_jaar
FROM Meijendel.mossen_waarneming
UNION ALL
SELECT 'korstmossen', COUNT(*), MIN(jaar), MAX(jaar)
FROM Meijendel.korstmossen_waarneming;

-- 10. Afgeschermde aanvulling op BLWG: alleen lokaal voor bevoegde
-- onderzoekers. Geen soortnaam, plot-ID, coordinaten of NDFF-identiteit in
-- de uitvoer. Niet automatisch publiceren: kleine jaartotalen kunnen ook
-- gevoelige informatie prijsgeven. De onderliggende 28 formulier-taxonregels
-- (20 positief, 8 nul) worden per plotjaar ontdubbeld zoals in query 2.
WITH per_plotjaar AS (
  SELECT YEAR(f.velddatum) AS meetjaar, f.bron_plot_id,
         MAX(t.waarnemingsstatus = 'waargenomen') AS aanwezig
  FROM Meijendel.korstmossen_bron_formulier AS f
  JOIN Meijendel_ndff_secure.blwg_korstmossen_formulier_taxon AS t
    ON t.bronbestand_sha256 = f.bronbestand_sha256 AND t.kopid = f.kopid
  WHERE f.formulierstatus = 'vast_plot_volledige_lijst'
  GROUP BY YEAR(f.velddatum), f.bron_plot_id
)
SELECT meetjaar, COUNT(*) AS vaste_plots,
       SUM(aanwezig) AS plots_met_aanwezigheid,
       SUM(aanwezig = 0) AS plots_met_echte_nul
FROM per_plotjaar
GROUP BY meetjaar
ORDER BY meetjaar;
