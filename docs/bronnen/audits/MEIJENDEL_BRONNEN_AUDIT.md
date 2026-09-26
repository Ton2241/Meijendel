# Audit Meijendel_bronnen

## Doel

Deze audit voorkomt dat niet-geolokaliseerde contextregels ongemerkt in de
analytische database `Meijendel` blijven staan of dat referentietabellen ten
onrechte worden verplaatst.

De audit leest regelversie `meijendel-ruimtelijke-poort-v3` uit
`meijendel_waarneming_ruimtelijke_status`. Alleen waarnemingsfeiten met
`geen_lokalisatie` of `context_alleen` zijn kandidaat voor
`Meijendel_bronnen`. Soorten, protocollen, kenmerken en andere
referentietabellen vallen niet onder deze ruimtelijke toelatingspoort.

## Uitkomst op 24 september 2026

| Brontabel | Records | Periode | Locatie-informatie | Besluit |
|---|---:|---:|---|---|
| `duinvallei_opname` | 488 | 2001, 2008 en 2018 | stabiele locatiecode en benoemd deelgebied, maar geen gekoppelde geometrie per opname | complete bronfamilie verplaatsen |
| `vogelstand_1924` | 204 | 1924 | geen gestructureerde locatie per regel | als historische context verplaatsen |

De live-audit vond geen derde brontabel met deze statussen. De jachtspinmatrix
staat nog niet in `Meijendel` en wordt daarom door de afzonderlijke import in
`Meijendel_bronnen` opgenomen.

Deze tellingen zijn een toelatingsaudit, geen zelfstandige toestemming om
tabellen te verwijderen. Verwijdering mag pas na kopie, relatiecontrole,
rijtelling, hashcontrole en hersteltest van de doeldatabase.

## Uitvoering

```bash
python3 gis/scripts/audit_meijendel_bronnen_candidates.py \
  --mysql-login-path meijendel_root \
  --database Meijendel \
  --output /tmp/meijendel_bronnen_audit.csv
```

Een onbekende waarnemingstabel krijgt `afzonderlijk_besluit_nodig` en laat het
script met een niet-nulstatus stoppen. Daarmee kan een nieuwe bronfamilie nooit
automatisch in de migratie terechtkomen.
