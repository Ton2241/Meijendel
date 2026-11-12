-- Registreer vijf door Ton op 12 november 2026 vastgestelde, gereconstrueerde
-- kernvlakken van de in 2015 voltooide Meijendelse kerven MEY1-MEY5.
-- De vijf vlakken zijn ieder 30 x 30 m (900 m2). Zij vervangen niet het in de
-- uitvoeringsbron genoemde gezamenlijke afgegraven oppervlak van 109.434 m2.

USE Meijendel;

CREATE TEMPORARY TABLE _kerven_bestaande_feiten_guard (
  ok TINYINT NOT NULL,
  CHECK (ok=1)
) ENGINE=InnoDB;

INSERT INTO _kerven_bestaande_feiten_guard (ok)
SELECT IF(
  (SELECT COUNT(*)
   FROM maatregel_uitvoering
   WHERE uitvoering_code='zeereep_vijf_kerven_2014_2015'
     AND datum_vanaf='2013-12-01'
     AND datum_tot='2015-03-31'
     AND gerealiseerde_hoeveelheid=10.9434
     AND hoeveelheid_eenheid='ha')=1
  AND
  (SELECT COUNT(*)
   FROM maatregel_uitvoering_jaar j
   JOIN maatregel_uitvoering u USING (uitvoering_id)
   WHERE u.uitvoering_code='zeereep_vijf_kerven_2014_2015'
     AND j.jaarstatus='uitgevoerd'
     AND j.jaar IN (2014,2015))=2
  AND
  (SELECT COUNT(*)
   FROM maatregel_uitvoering_jaar j
   JOIN maatregel_uitvoering u USING (uitvoering_id)
   WHERE u.uitvoering_code='zeereep_vijf_kerven_2014_2015')=2
  AND
  (SELECT COUNT(*)
   FROM maatregel_plot_koppeling k
   JOIN maatregel_uitvoering u USING (uitvoering_id)
   JOIN plots p USING (plot_id)
   WHERE u.uitvoering_code='zeereep_vijf_kerven_2014_2015'
     AND p.plot_naam IN ('Meijendel k 15','Meijendel k 16','Meijendel k 17a')
     AND k.verificatiestatus='geverifieerd'
     AND k.doorsnijding_pct IS NULL)=3
  AND
  (SELECT COUNT(*)
   FROM maatregel_plot_koppeling k
   JOIN maatregel_uitvoering u USING (uitvoering_id)
   WHERE u.uitvoering_code='zeereep_vijf_kerven_2014_2015')=3,
  1, 0
);

DROP TEMPORARY TABLE _kerven_bestaande_feiten_guard;

SET @object_code_bestaand=(
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema=DATABASE()
    AND table_name='maatregel_geometrie'
    AND column_name='object_code'
);
SET @sql=IF(
  @object_code_bestaand=0,
  CONCAT(
    'ALTER TABLE maatregel_geometrie ',
    'ADD COLUMN object_code VARCHAR(32) CHARACTER SET ascii ',
    'NOT NULL DEFAULT ''geheel'' AFTER geometrie_id'
  ),
  'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @uq_bestaand=(
  SELECT COUNT(*)
  FROM information_schema.statistics
  WHERE table_schema=DATABASE()
    AND table_name='maatregel_geometrie'
    AND index_name='uq_maatregel_geometrie'
);
SET @uq_kolommen=(
  SELECT GROUP_CONCAT(column_name ORDER BY seq_in_index SEPARATOR ',')
  FROM information_schema.statistics
  WHERE table_schema=DATABASE()
    AND table_name='maatregel_geometrie'
    AND index_name='uq_maatregel_geometrie'
);
SET @sql=IF(
  @uq_kolommen='uitvoering_id,geometrie_type,geometrie_jaar,object_code',
  'SELECT 1',
  CONCAT(
    'ALTER TABLE maatregel_geometrie ',
    'ADD UNIQUE KEY uq_maatregel_geometrie_object ',
    '(uitvoering_id, geometrie_type, geometrie_jaar, object_code)'
  )
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql=IF(
  @uq_bestaand>0
    AND @uq_kolommen<>'uitvoering_id,geometrie_type,geometrie_jaar,object_code',
  'ALTER TABLE maatregel_geometrie DROP INDEX uq_maatregel_geometrie',
  'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @uq_object_bestaand=(
  SELECT COUNT(*)
  FROM information_schema.statistics
  WHERE table_schema=DATABASE()
    AND table_name='maatregel_geometrie'
    AND index_name='uq_maatregel_geometrie_object'
);
SET @sql=IF(
  @uq_object_bestaand>0,
  'ALTER TABLE maatregel_geometrie RENAME INDEX uq_maatregel_geometrie_object TO uq_maatregel_geometrie',
  'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

INSERT INTO maatregel_bron
  (bron_code,brontype_code,titel,bron_datum,zotero_item_key,url,
   raadpleegdatum,bronstatus,opmerking)
VALUES
  ('handmatige_kerven_kernvlakken_20261112','handmatige_registratie',
   'Gereconstrueerde kernvlakken van de vijf Meijendelse kerven',
   '2026-11-12',NULL,NULL,'2026-11-12','door gebruiker vastgesteld',
   CONCAT(
     'Ton positioneerde MEY1-MEY5 visueel op de witte kerfdelen in de PDOK-luchtfoto 2025. ',
     'Elk vlak is een vast 30 x 30 m kernvlak in EPSG:28992. ',
     'Bronwerkbestand: kerven-kandidaatpolygonen-2025-v4-handmatig-polygon.gpkg; ',
     'SHA-256 0682038ab1b6bc031ec63a6e0b2a173176f00a91640cce22b63ca9312dd66784. ',
     'Het betreft gereconstrueerde kerfkernen, niet het volledige afgegraven terrein van 109.434 m2.'
   ))
ON DUPLICATE KEY UPDATE
  titel=VALUES(titel),
  bron_datum=VALUES(bron_datum),
  raadpleegdatum=VALUES(raadpleegdatum),
  bronstatus=VALUES(bronstatus),
  opmerking=VALUES(opmerking);

INSERT INTO maatregel_uitvoering_bron
  (uitvoering_id,bron_id,bronrol,pagina_of_paragraaf,bewijsnotitie)
SELECT u.uitvoering_id,b.bron_id,'bevestiging',NULL,
       'Handmatige ruimtelijke reconstructie van de vijf afzonderlijke kerfkernen MEY1-MEY5. De vlakken lokaliseren de kerfkernen, maar verdelen of vervangen niet het gezamenlijke afgegraven oppervlak van 109.434 m2.'
FROM maatregel_uitvoering u
JOIN maatregel_bron b
  ON b.bron_code='handmatige_kerven_kernvlakken_20261112'
WHERE u.uitvoering_code='zeereep_vijf_kerven_2014_2015'
ON DUPLICATE KEY UPDATE
  bewijsnotitie=VALUES(bewijsnotitie);

INSERT INTO maatregel_geometrie
  (object_code,uitvoering_id,geometrie_type,geometrie,geometrie_jaar,bron_id,
   geometrie_opmerking)
SELECT 'MEY1',u.uitvoering_id,'TG03_uitvoeringsgebied',
       ST_GeomFromText('MULTIPOLYGON (((82813.4294649653 462918.441782623,82831.8937458587 462942.086450755,82808.2490777263 462960.550731649,82789.7847968329 462936.906063516,82813.4294649653 462918.441782623)))',28992),
       2015,b.bron_id,
       'MEY1; gereconstrueerd kernvlak 30 x 30 m; 900 m2; handmatig vastgesteld op PDOK-luchtfoto 2025; geen volledige ontgravingsvoetafdruk.'
FROM maatregel_uitvoering u
JOIN maatregel_bron b ON b.bron_code='handmatige_kerven_kernvlakken_20261112'
WHERE u.uitvoering_code='zeereep_vijf_kerven_2014_2015'
ON DUPLICATE KEY UPDATE geometrie=VALUES(geometrie),bron_id=VALUES(bron_id),geometrie_opmerking=VALUES(geometrie_opmerking);

INSERT INTO maatregel_geometrie
  (object_code,uitvoering_id,geometrie_type,geometrie,geometrie_jaar,bron_id,
   geometrie_opmerking)
SELECT 'MEY2',u.uitvoering_id,'TG03_uitvoeringsgebied',
       ST_GeomFromText('MULTIPOLYGON (((82721.2737760264 462788.195273945,82739.7380569198 462811.839942078,82716.0933887875 462830.304222971,82697.629107894 462806.659554839,82721.2737760264 462788.195273945)))',28992),
       2015,b.bron_id,
       'MEY2; gereconstrueerd kernvlak 30 x 30 m; 900 m2; handmatig vastgesteld op PDOK-luchtfoto 2025; geen volledige ontgravingsvoetafdruk.'
FROM maatregel_uitvoering u
JOIN maatregel_bron b ON b.bron_code='handmatige_kerven_kernvlakken_20261112'
WHERE u.uitvoering_code='zeereep_vijf_kerven_2014_2015'
ON DUPLICATE KEY UPDATE geometrie=VALUES(geometrie),bron_id=VALUES(bron_id),geometrie_opmerking=VALUES(geometrie_opmerking);

INSERT INTO maatregel_geometrie
  (object_code,uitvoering_id,geometrie_type,geometrie,geometrie_jaar,bron_id,
   geometrie_opmerking)
SELECT 'MEY3',u.uitvoering_id,'TG03_uitvoeringsgebied',
       ST_GeomFromText('MULTIPOLYGON (((82609.5377110315 462642.870632273,82628.0019919249 462666.515300405,82604.3573237926 462684.979581298,82585.8930428992 462661.334913166,82609.5377110315 462642.870632273)))',28992),
       2015,b.bron_id,
       'MEY3; gereconstrueerd kernvlak 30 x 30 m; 900 m2; handmatig vastgesteld op PDOK-luchtfoto 2025; geen volledige ontgravingsvoetafdruk.'
FROM maatregel_uitvoering u
JOIN maatregel_bron b ON b.bron_code='handmatige_kerven_kernvlakken_20261112'
WHERE u.uitvoering_code='zeereep_vijf_kerven_2014_2015'
ON DUPLICATE KEY UPDATE geometrie=VALUES(geometrie),bron_id=VALUES(bron_id),geometrie_opmerking=VALUES(geometrie_opmerking);

INSERT INTO maatregel_geometrie
  (object_code,uitvoering_id,geometrie_type,geometrie,geometrie_jaar,bron_id,
   geometrie_opmerking)
SELECT 'MEY4',u.uitvoering_id,'TG03_uitvoeringsgebied',
       ST_GeomFromText('MULTIPOLYGON (((82473.8402991803 462464.137525166,82492.3045800737 462487.782193298,82468.6599119413 462506.246474191,82450.1956310479 462482.601806059,82473.8402991803 462464.137525166)))',28992),
       2015,b.bron_id,
       'MEY4; gereconstrueerd kernvlak 30 x 30 m; 900 m2; handmatig vastgesteld op PDOK-luchtfoto 2025; geen volledige ontgravingsvoetafdruk.'
FROM maatregel_uitvoering u
JOIN maatregel_bron b ON b.bron_code='handmatige_kerven_kernvlakken_20261112'
WHERE u.uitvoering_code='zeereep_vijf_kerven_2014_2015'
ON DUPLICATE KEY UPDATE geometrie=VALUES(geometrie),bron_id=VALUES(bron_id),geometrie_opmerking=VALUES(geometrie_opmerking);

INSERT INTO maatregel_geometrie
  (object_code,uitvoering_id,geometrie_type,geometrie,geometrie_jaar,bron_id,
   geometrie_opmerking)
SELECT 'MEY5',u.uitvoering_id,'TG03_uitvoeringsgebied',
       ST_GeomFromText('MULTIPOLYGON (((82397.6486211641 462346.401293912,82416.1129020575 462370.045962044,82392.4682339252 462388.510242937,82374.0039530318 462364.865574805,82397.6486211641 462346.401293912)))',28992),
       2015,b.bron_id,
       'MEY5; gereconstrueerd kernvlak 30 x 30 m; 900 m2; handmatig vastgesteld op PDOK-luchtfoto 2025; geen volledige ontgravingsvoetafdruk.'
FROM maatregel_uitvoering u
JOIN maatregel_bron b ON b.bron_code='handmatige_kerven_kernvlakken_20261112'
WHERE u.uitvoering_code='zeereep_vijf_kerven_2014_2015'
ON DUPLICATE KEY UPDATE geometrie=VALUES(geometrie),bron_id=VALUES(bron_id),geometrie_opmerking=VALUES(geometrie_opmerking);

SELECT object_code,geometrie_type,geometrie_jaar,
       ROUND(ST_Area(geometrie),3) AS oppervlakte_m2,
       ST_IsValid(geometrie) AS geldig
FROM maatregel_geometrie g
JOIN maatregel_uitvoering u USING (uitvoering_id)
WHERE u.uitvoering_code='zeereep_vijf_kerven_2014_2015'
ORDER BY object_code;
