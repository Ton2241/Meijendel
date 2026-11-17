-- Eenmalige lokale naamcorrectie na gecontroleerde T7-herstelkopie.
-- Bronnaam, routecode, kaartgeometrie en tellingen blijven ongewijzigd.
-- Vooraf: controleer dat code 638 precies eenmaal de bronnaam Hertenkamp
-- heeft en dat routefamilie 4 precies eenmaal nummer 205 draagt.
USE Meijendel;

ALTER TABLE vlinders_dag_telobject
  ADD COLUMN weergavenaam_override VARCHAR(160) NULL AFTER bronnaam,
  ALGORITHM=INSTANT,
  LOCK=DEFAULT;

START TRANSACTION;
UPDATE vlinders_dag_telobject
SET weergavenaam_override = 'Bierlap – dagvlinderroute 638'
WHERE bron_code = 638
  AND bronnaam = 'Hertenkamp (Meijendel)'
  AND weergavenaam_override IS NULL;
SELECT ROW_COUNT() AS gewijzigde_telobjecten; -- verwacht: 1

UPDATE ndff_vlinder_route_identificatie
SET bewijsgrond = 'Historische route 205 heet Hertenkamp, maar Toves kaart en de NDFF-geometrie liggen in Kijfhoek/Bierlap (M12a/M64/M65), niet in Hertenkamp M105. De routenaam bewijst geen gebiedstoewijzing.'
WHERE reconstructieversie = 'ndff-vlinderroute-v2'
  AND routefamilie_id = 4
  AND officieel_routenummer = 205
  AND officiele_routenaam = 'Hertenkamp'
  AND bewijsgrond = 'Startjaar 1991, ligging en gebruiksperiode passen bij Hertenkamp.';
SELECT ROW_COUNT() AS gewijzigde_route_identificaties; -- verwacht: 1
COMMIT;

SELECT bron_code, bronnaam, weergavenaam_override
FROM vlinders_dag_telobject WHERE bron_code = 638;
SELECT reconstructieversie, routefamilie_id, officieel_routenummer,
       officiele_routenaam, bewijsgrond
FROM ndff_vlinder_route_identificatie
WHERE reconstructieversie = 'ndff-vlinderroute-v2' AND routefamilie_id = 4;
