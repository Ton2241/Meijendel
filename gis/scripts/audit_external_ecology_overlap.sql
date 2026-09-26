USE Meijendel;

START TRANSACTION;

DELETE FROM externe_ecologie_overlap
WHERE doelsysteem='provinciale_pq';

INSERT INTO externe_ecologie_overlap (
  resultaat_id,doelsysteem,doelrecord_sleutel,koppelmethode,zekerheid,toelichting
)
SELECT DISTINCT
  r.resultaat_id,
  'provinciale_pq',
  CONCAT('pq:',p.opname_id,':',w.waarneming_id),
  'datum_taxon_afstand',
  CASE
    WHEN e.datum_precisie='exact'
     AND ST_Distance(
       p.geom,
       ST_Transform(ST_SRID(Point(e.longitude,e.latitude),4326),28992)
     ) <= 5
    THEN 'exact'
    ELSE 'waarschijnlijk'
  END,
  CONCAT('Zelfde taxon; provinciale opname ',p.opname_id,
         '; afstand in meter: ',ROUND(ST_Distance(
           p.geom,
           ST_Transform(ST_SRID(Point(e.longitude,e.latitude),4326),28992)
         ),1))
FROM externe_ecologie_resultaat r
JOIN externe_ecologie_event e USING(event_id)
JOIN externe_ecologie_dataset d USING(dataset_id)
JOIN pq_vegetatie_opname p
  ON p.opname_datum BETWEEN e.event_datum AND e.event_datum_tot
 AND ST_Distance(
       p.geom,
       ST_Transform(ST_SRID(Point(e.longitude,e.latitude),4326),28992)
     ) <= GREATEST(COALESCE(e.coordinate_uncertainty_m,0),5)
JOIN pq_vegetatie_waarneming w ON w.opname_id=p.opname_id
JOIN pq_vegetatie_taxon t
  ON t.taxon_id=w.taxon_id
 AND (
      t.wetenschappelijke_naam_officieel=r.wetenschappelijke_naam
      OR t.latijnse_naam_bron=r.wetenschappelijke_naam
 )
WHERE d.dataset_sleutel='lvd-meijendel-v1-6';

DELETE FROM externe_ecologie_overlap
WHERE doelsysteem='ndff';

CREATE TEMPORARY TABLE tmp_external_ndff (
  resultaat_id BIGINT UNSIGNED NOT NULL,
  soort_key CHAR(64) CHARACTER SET ascii NOT NULL,
  datum_van DATE NOT NULL,
  datum_tot DATE NOT NULL,
  punt_rd POINT NOT NULL SRID 28992,
  PRIMARY KEY (resultaat_id,soort_key),
  KEY ix_tmp_external_ndff_taxon_datum (soort_key,datum_van,datum_tot),
  SPATIAL KEY sx_tmp_external_ndff_punt (punt_rd)
) ENGINE=InnoDB;

INSERT INTO tmp_external_ndff (resultaat_id,soort_key,datum_van,datum_tot,punt_rd)
SELECT DISTINCT
  r.resultaat_id,s.soort_key,e.event_datum,e.event_datum_tot,
  ST_Transform(ST_SRID(Point(e.longitude,e.latitude),4326),28992)
FROM externe_ecologie_resultaat r
JOIN externe_ecologie_event e USING(event_id)
JOIN ndff_soorten s ON s.wetenschappelijke_naam=r.wetenschappelijke_naam
WHERE e.event_datum IS NOT NULL
  AND e.event_datum_tot IS NOT NULL
  AND e.latitude IS NOT NULL
  AND e.longitude IS NOT NULL;

INSERT INTO externe_ecologie_overlap (
  resultaat_id,doelsysteem,doelrecord_sleutel,koppelmethode,zekerheid,toelichting
)
SELECT
  x.resultaat_id,
  'ndff',
  CONCAT('ndff:',n.waarneming_id),
  'taxon_datum_in_onzekerheidspolygoon',
  'mogelijk',
  'Zelfde taxon en datum; het externe punt valt in de NDFF-onzekerheidspolygoon. Zonder gedeelde bron-ID is dit geen bewezen dubbel.'
FROM tmp_external_ndff x
JOIN ndff_open_waarneming n FORCE INDEX (ix_ndff_open_soort_datum)
  ON n.soort_key=x.soort_key
 AND n.periode_start >= x.datum_van
 AND n.periode_start < DATE_ADD(x.datum_tot,INTERVAL 1 DAY)
 AND MBRIntersects(n.openbare_geometrie,x.punt_rd)
 AND ST_Intersects(n.openbare_geometrie,x.punt_rd)
WHERE n.analyse_status <> 'uitgesloten';

COMMIT;
