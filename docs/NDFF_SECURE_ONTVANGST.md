# Ontvangst beveiligde NDFF-data - ticket 58679

## Doel en status

Dit runbook bereidt de ontvangst voor van de door NDFF toegezegde gezipte
shapefile, Excel en standaardcitatie met onvervaagde gegevens voor 1950-2025.
Het maakt nog geen import in de life-database en verandert de VPS of Shiny niet.

De Samsung T7 is door de eigenaar aangemerkt als fysiek beveiligde opslag achter
de iMac. Daarom wordt geen aanvullende versleutelde ontvangstzone gebruikt.

## Vaste opslag

```text
/Volumes/T7 Data/Home_Ton/Meijendel data/NDFF/
├── open_ffv/
│   ├── raw/
│   ├── staging/
│   └── reports/
├── correspondentie/
└── secure/ticket_58679/
    ├── original/
    ├── manifests/
    └── derived/
```

- `original` bevat uitsluitend de ongewijzigde NDFF-levering.
- `manifests` bevat hashes, controles en de standaardcitatie.
- `derived` bevat uitsluitend lokale afgeleide beveiligde bestanden.
- Niets onder `secure` gaat naar Git, iCloud, de gewone `Meijendel.sql`, de
  algemene Shiny-app, de VPS of een webpad.

De vooraf bekende scope en hashes van doelsoortenlijst, SOVON-plotlaag en
getekende voorwaarden staan in `manifests/expected_scope.json`.

## Ontvangstprocedure

1. Download ZIP en Excel tijdelijk en verplaats ze direct, zonder hernoemen of
   openen, naar `secure/ticket_58679/original`.
2. Bewaar de meegeleverde standaardcitatie als apart bestand onder `manifests`
   of als correspondentie bij ticket 58679.
3. Maak het ontvangstmanifest:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 gis/scripts/validate_ndff_secure_delivery.py \
  --delivery-dir '/Volumes/T7 Data/Home_Ton/Meijendel data/NDFF/secure/ticket_58679/original' \
  --manifest '/Volumes/T7 Data/Home_Ton/Meijendel data/NDFF/secure/ticket_58679/manifests/receipt_manifest.json' \
  --expected-species-xlsx '/Volumes/T7 Data/Home_Ton/Meijendel data/NDFF/correspondentie/bijlagen_antwoord_58679/ndff_doelsoorten_meijendel_ticket_58679.xlsx' \
  --citation-file '/Volumes/T7 Data/Home_Ton/Meijendel data/NDFF/secure/ticket_58679/manifests/standaardcitatie.txt'
```

4. Ga alleen verder als het manifest `status: PASS` meldt. Waarschuwingen
   worden inhoudelijk beoordeeld en vastgelegd; fouten blokkeren verwerking.
5. Verwijder tijdelijke downloadkopieën en eventuele e-mailbijlagen pas nadat
   hashes, aantallen en leesbaarheid zijn gecontroleerd. Bewaar de inhoudelijke
   correspondentie zonder dubbele databijlage.

Het validatiescript wijzigt en pakt de bronbestanden niet uit. Het controleert
SHA-256, ZIP-veiligheid en shapefile-onderdelen, laag- en recordaantallen,
EPSG:28992, lege/ongeldige geometrieën, identiteit, Excelstructuur en - waar de
kolommen dit toelaten - aansluiting op de aangevraagde doelsoorten.

## Vervolg na een groene ontvangst

1. Koppel de geleverde `Identiteit` aan de open, ontdubbelde FFV-staging.
2. Bewaar exacte geometrie naast, en nooit in plaats van, de openbare
   brongeometrie.
3. Koppel lokaal aan de geversioneerde laag
   `sovon_plots_meijendel_2025` met 55 plots in EPSG:28992.
4. Bewaar alle ruimtelijke matches. Classificeer als:
   - `single`: exact één plot;
   - `multiple`: meer dan één plot, dus ruimtelijk ambigu;
   - `outside`: geen plot, dus buiten de database-inname.
5. Beoordeel daarna vervaging, PQ-overlap en protocolkwaliteit per analysetype.

De 77 bekende overlappende plotparen verhinderen dat een geometrische
intersectie automatisch aan één plot wordt toegewezen.

## Database- en analysegate

`gis/database/ndff_secure_schema.sql` is uitsluitend een voorbereid ontwerp.
Uitvoering volgt pas nadat het werkelijke leveringsschema is gevalideerd en de
kolomkoppeling is beoordeeld. Daarbij blijven gelden:

- `ndff_soorten` in plaats van de bestaande vogelgerichte `soorten`;
- één fysieke `ndff_<soortgroep>`-tabel per oorspronkelijke FFV-soortgroep;
- geen rechten voor `meijendel_read`;
- geen opname in de gewone `Meijendel.sql`;
- geen trendclaim op basis van positieve waarnemingen zonder volledige
  bezoeken, inspanning, protocolversies en afleidbare nullen;
- bestaande volledige PQ-opnamen blijven leidend.

Het ontwerp is op 2 september 2026 syntactisch uitgevoerd in een uitsluitend
voor deze test aangemaakte lokale MySQL 9.7.1-database. Daarbij ontstonden 36
basistabellen, waaronder alle 26 soortgroeptabellen, 36 foreign keys en één
onderzoeksview. De tijdelijke testdatabase is daarna verwijderd; het echte
schema `Meijendel_ndff_secure` is niet aangemaakt.

## Beëindiging

Leg per levering de gebruiksstatus, laatste toegestane gebruiksdatum en
uiteindelijke vernietigingsdatum vast. Vernietiging omvat originele bestanden,
afgeleide beveiligde bestanden, databasekopieën, tijdelijke extracties en
back-ups die de beveiligde data bevatten. Het ontvangstmanifest en een
niet-inhoudelijk vernietigingsbewijs kunnen behouden blijven.
