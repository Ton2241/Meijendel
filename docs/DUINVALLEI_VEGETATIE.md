# Duinvalleivegetatie 2001-2018

## Bron en opslag

De openbare Zenodo-dataset *21 years of restoration of dune slack communities
after 42 years of river water infiltration in Meijendel, the Netherlands* is
opgenomen onder DOI `10.5281/zenodo.21796880`.

De ongewijzigde bronbestanden staan op de T7 in:

`/Volumes/T7 Data/Home_Ton/Meijendel data/Vegetatie/duinvalleien_2001_2018/bron`

De import controleert de drie bronbestanden met SHA-256. Een volledige
voorafgaande MySQL-back-up staat in de naastgelegen map `backups`.

## Omvang

- 488 vegetatieopnamen: 186 in 2001, 116 in 2008 en 186 in 2018;
- 186 stabiele proefstroken, geïdentificeerd met het bronveld `Site`;
- 208 taxa en een volledige matrix van 101.504 opname-taxoncombinaties;
- 10.989 positieve registraties en 90.515 expliciete nullen in de bronmatrix;
- 855 bodemmetingen.

De bronregel `18I01` blijft volledig bewaard, maar wordt niet door de
analyseviews aangeboden. Deze regel bevat 159 positieve taxa; alle overige
opnamen bevatten maximaal 40. Na deze uitsluiting blijven 487 opnamen en
101.296 opname-taxoncombinaties over, waarvan 10.830 positief en 90.466 nul.

## Datamodel

De reeks staat als zelfstandige, openbare bron in `Meijendel`:

- `duinvallei_import_batch` bewaart herkomst, hashes en importversie;
- `duinvallei_plot` bewaart de 186 stabiele proefstroken;
- `duinvallei_opname` bewaart de afzonderlijke opnamen en hun analysestatus;
- `duinvallei_taxon` bewaart de 208 bronlabels;
- `duinvallei_bedekkingscode` documenteert de aangeleverde codes;
- `duinvallei_bedekking` bewaart de volledige matrix, inclusief nullen;
- `duinvallei_bodemparameter` en `duinvallei_bodemmeting` bewaren de bodemdata.

Gebruik voor analyses uitsluitend `v_duinvallei_analyse_opname` en
`v_duinvallei_analyse_bedekking`. Deze views sluiten `18I01` uit.

## Gebruik en grenzen

Dit is een herhaalde vegetatiereeks met echte nullen binnen de aangeleverde
lijst van 208 taxa. Zij kan daarom zelfstandig worden gebruikt voor verandering
in aanwezigheid, soortenrijkdom en bedekkingsklasse tussen 2001, 2008 en 2018.
De bodemgegevens zijn alleen voor 45 proefstroken in 2001 en 2018 gepaard
beschikbaar; bodemvocht is alleen voor die 45 proefstroken in 2018 gevuld.

De reeks is geen onderdeel van het provinciale PQ-meetnet. De bron gebruikt
eigen stroken van 0,5 x 4 meter en bevat geen ruimtelijke sleutel waarmee een
exacte koppeling aan de provinciale PQ-opnamen kan worden bewezen. Meng beide
reeksen daarom niet en gebruik de nieuwe gegevens niet om provinciale
PQ-opnamen aan te vullen. De locatie en de behandeling zijn in het
onderzoeksontwerp bovendien niet onafhankelijk; een verschil is daarom zonder
aanvullende onderbouwing geen causaal effect van de behandeling.

## Reproduceerbaarheid

Controle zonder databasewijziging:

```bash
python3 gis/scripts/import_duinvallei_vegetatie.py --dry-run \
  --source-dir '/Volumes/T7 Data/Home_Ton/Meijendel data/Vegetatie/duinvalleien_2001_2018/bron'
```

Controle van de reeds geïmporteerde database:

```bash
python3 gis/scripts/import_duinvallei_vegetatie.py --audit-live
```

Eerste import of idempotente herhaling:

```bash
python3 gis/scripts/import_duinvallei_vegetatie.py --execute \
  --source-dir '/Volumes/T7 Data/Home_Ton/Meijendel data/Vegetatie/duinvalleien_2001_2018/bron'
```
