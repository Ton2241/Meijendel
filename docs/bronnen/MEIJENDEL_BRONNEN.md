# Meijendel_bronnen

## Hoofdregel

Meijendel is strikt analytisch. Niet-geolokaliseerbare Meijendelgegevens en het
Meijendel-literatuuroverzicht uit Zotero worden beheerd in Meijendel_bronnen en
mogen niet zonder afzonderlijk promotiebesluit in analyses uit Meijendel worden
gebruikt.

## Inhoud per 24 september 2026

- duinvalleivegetatie: 488 opnamen uit 2001, 2008 en 2018 op 186 stabiele
  locatiecodes, maar zonder geometrie per opname;
- vogelstand 1924: 204 historische soort- en tekstregels zonder
  waarnemingslocatie per regel;
- jachtspinnen 1969–1970: 3.337 exemplaren van 12 soorten op 28 genummerde,
  geografisch nog niet herleidbare locaties;
- literatuur: 522 actuele bibliografische items uit de Zotero-collectie
  `Meijendel`, weergegeven in Chicago-stijl.

De Zotero-sync neemt geen pdf's, bijlagen, notities, annotaties, blobs of lokale
paden over. Zotero op de NAS blijft de bron voor de documenten zelf.

## Toegang

Het Analysecentrum gebruikt uitsluitend:

- `v_bron_catalogus`;
- `v_literatuur_overzicht`;
- `v_contextdataset_overzicht`.

De websitegebruiker heeft geen recht op de onderliggende tabellen. Shiny heeft
geen recht op deze database. `meijendel_bronnen.sql` staat op de VPS alleen in
`/srv/vwgm/data`, met bestandsmodus `0600`, en wordt niet naar een webpad
gesymlinkt.

## Synchronisatie en herstel

1. Voer de tests en de migratieguards uit.
2. Synchroniseer Zotero via de lokale API met
   `gis/scripts/sync_zotero_meijendel_bronnen.py --execute --login-path
   meijendel_root`.
3. Maak `meijendel.sql` en `meijendel_bronnen.sql` afzonderlijk.
4. Herstel beide dumps in vooraf als afwezig gecontroleerde tijdelijke
   databases en vergelijk tabellen, objecten, aantallen, hashes en foreign
   keys.
5. Verwijder brondata pas uit `Meijendel` wanneer het migratiemanifest
   `counts_match`, `hashes_match`, `foreign_keys_ok` en `restore_ok` alle vier
   als waar registreert.

De lokale migratie van 24 september 2026 voldeed aan alle vier voorwaarden.
Vóór de verwijdering zijn beide databases uit een dump hersteld; na de
verwijdering zijn de definitieve dumps opnieuw hersteld en zijn de objectlijsten
en rijtellingen tabel voor tabel gelijk bevonden. De definitieve lokale hashes
zijn:

- `meijendel.sql`:
  `c26e0adb7a68c1dbd1e050337b70ed2da7a33e9cd518e96f8e1604ea91dca666`;
- `meijendel_bronnen.sql`:
  `b245d2e0b1d8519dd929e26c50d6f7e4ae3b25ccc4c76ece3e804d4595c3c0ff`.

## Promotie

Promotie naar `Meijendel` is geen gewone import. Zij vereist een afzonderlijk
besluit. Per waarneming moet vaststaan dat zij daadwerkelijk in Meijendel is
gedaan en moet de locatie beschikbaar of betrouwbaar herleidbaar zijn. Leg ook
de bron, gebruiksvoorwaarden, beoogde analysetypen en een reproduceerbaar
auditmanifest vast. Zonder dat bewijs blijft de dataset context.

## Ledenarchief

De oude literatuurtegel is vervallen. Bestaande archiefdocumenten mogen alleen
worden verwijderd nadat ieder bestand exact aan een Zotero-item is gekoppeld,
de SHA-256 tussen dry-run en uitvoering gelijk blijft en vooraf een
PostgreSQL-back-up is gemaakt. Een onvolledig manifest blokkeert de
verwijdering.
