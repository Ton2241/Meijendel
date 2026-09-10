# Ontvangst beveiligde NDFF-data - ticket 58679

## Doel en status

De levering voor ticket 58679 is op 10 september 2026 ontvangen als één
GeoPackage met alle aanwezige en gevalideerde records van de aangeleverde lijst
van 191 soorten binnen het organisatie-werkgebied en de periode 1950-2025. De
ontvangst en eerste kwaliteitsanalyse zijn groen afgerond. Er is nog niets in de
life-database geïmporteerd en VPS en Shiny zijn niet gewijzigd.

De verplichte citatie is:

> Nationale Databank Flora en Fauna/NDFF. https://ndff.nl/citation/mwl/58679
> (geraadpleegd 9-9-2026)

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

1. Plaats de gedownloade levering zonder hernoemen of inhoudelijke wijziging in
   `secure/ticket_58679/original`.
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

Het validatiescript wijzigt de bronbestanden niet. Het ondersteunt zowel de
eerder verwachte combinatie ZIP/Excel als het daadwerkelijk geleverde
GeoPackage. Het controleert SHA-256, laag- en recordaantallen, EPSG:28992,
lege/ongeldige geometrieën, identiteit en aansluiting op de aangevraagde
doelsoorten.

## Ontvangstresultaat 10 september 2026

- origineel: `ndff_mwl_z58679_Meijendel.gpkg`;
- SHA-256: `bc33f14ae413169873adbb396cbcf3ac9708a02dccbeb7902e9685d0e9b8cc73`;
- één polygonenlaag in EPSG:28992 met 14.573 records;
- 14.573 unieke `obs_uri`-waarden, geen lege of ongeldige geometrieën;
- 158 taxa met records; 33 van de 191 aangevraagde taxa zonder record;
- alle records hebben NDFF-kwaliteit `betrouwbaar` en leveringswaarde
  `onvervaagd`.

`Onvervaagd` betekent uitsluitend dat de privacyvervaging is opgeheven. Het is
geen garantie voor puntnauwkeurigheid: 3.456 brongeometrieën zijn minstens
1 km².

## Vervolg na een groene ontvangst

1. Koppel `obs_uri` aan de open staging met
   `Identiteit = SHA-256(obs_uri)`.
2. Bewaar exacte geometrie naast, en nooit in plaats van, de openbare
   brongeometrie.
3. Koppel lokaal aan de geversioneerde laag
   `sovon_plots_meijendel_2025` met 55 plots in EPSG:28992.
4. Bewaar alle ruimtelijke matches. Classificeer als:
   - `single`: exact één plot;
   - `multiple`: meer dan één plot, dus ruimtelijk ambigu;
   - `outside`: geen plot, dus buiten de database-inname.
5. Beoordeel daarna vervaging, PQ-overlap en protocolkwaliteit per analysetype.

Deze stappen zijn uitgevoerd met regelversie `ndff-secure-58679-v1`:

- 14.420 records (98,95%) koppelen exact aan de open staging; 10.271 daarvan
  waren openbaar vervaagd op 1, 5 of 10 km;
- 9.157 records raken één plot, 4.590 meerdere plots en 826 geen plot;
- van de enkelvoudige matches liggen 8.777 geometrieën volledig binnen het
  plot en 380 slechts gedeeltelijk;
- na ruimtelijke en PQ-controle blijven 8.494 voorlopige kandidaten voor
  uitsluitend verspreidingscontext;
- 162 records matchen exact met een bestaande PQ-soortwaarneming en 163
  PQ-risicorecords blijven `niet_beoordeelbaar`;
- 1.931 records horen bij een doelgericht meetnet of gebiedsmonitoring, maar
  slechts 1.274 liggen volledig in één plot zonder PQ-blokkade;
- nul records zijn met de geleverde positieve recordstructuur direct geschikt
  voor trendanalyse;
- de 158 taxa overlappen niet met de 275 taxa van de afzonderlijke
  GBIF-vangblikreeks 1953-1960.

Geen NDFF-record wordt voor analyse vrijgegeven zonder expliciete PQ-status.
Alleen `onafhankelijk` en `niet_van_toepassing` mogen zelfstandig meetellen;
de overige statussen blijven geblokkeerd als extra evidentie naast de bestaande
PQ-opnamen. Iedere analyse-uitvoer bevat aantallen per status en de gebruikte
beslisregelversie.

De 77 bekende overlappende plotparen verhinderen dat een geometrische
intersectie automatisch aan één plot wordt toegewezen.

## Database- en analysegate

`gis/database/ndff_secure_schema.sql` is aangepast aan het werkelijke
GeoPackage-schema, maar blijft uitsluitend een voorbereid ontwerp. Uitvoering
volgt pas na de inhoudelijke toelatingsbeslissing per soortgroep en analysetype.
Daarbij blijven gelden:

- `ndff_soorten` in plaats van de bestaande vogelgerichte `soorten`;
- één fysieke `ndff_<soortgroep>`-tabel per oorspronkelijke FFV-soortgroep;
- geen rechten voor `meijendel_read`;
- geen opname in de gewone `Meijendel.sql`;
- geen trendclaim op basis van positieve waarnemingen zonder volledige
  bezoeken, inspanning, protocolversies en afleidbare nullen;
- bestaande volledige PQ-opnamen blijven leidend.

De surveystructuur wordt niet opnieuw bij NDFF opgevraagd: NDFF heeft gemeld
dat zij naast de geleverde waarnemingsinformatie geen aanvullende
surveystructuur kan leveren. Voor de 1.274 geschikte vervolgkandidaten is het
bedoelde meetontwerp gereconstrueerd uit de officiële protocollen. De
feitelijke telobjecten, alle bezoeken, inspanning, doelsoorten, nulresultaten,
protocolversies en kwaliteitsmetadata worden rechtstreeks bij de
meetnetbeheerder opgevraagd: Zoogdiervereniging, Dunea/FLORON, RAVON, ANEMOON,
BLWG, De Vlinderstichting en Staatsbosbeheer/opdrachtgever.

De oorspronkelijke meeteenheid blijft behouden. Een losse waarneming binnen
één SOVON-plot is onvoldoende om een route, water, proefvlak, kilometerhok of
karteringsgebied aan dat plot toe te wijzen. Eerst wordt de native survey
gereconstrueerd; pas daarna volgt een geversioneerde plotrelatie. Het
definitieve databaseschema voor surveys wordt daarom pas vastgesteld na
ontvangst van minstens één representatieve bronlevering.

De aan het werkelijke GeoPackage aangepaste ontwerpversie is op 10 september
2026 syntactisch uitgevoerd in een uitsluitend voor deze test aangemaakte lokale
MySQL 9.7.1-database. Daarbij ontstonden 37 tabellen, waaronder alle 26
soortgroeptabellen, 36 foreign keys en één onderzoeksview. De tijdelijke
testdatabase is daarna verwijderd; het echte schema `Meijendel_ndff_secure` is
niet aanwezig. De life-database is ongewijzigd gebleven.

## Beëindiging

De ondertekende voorwaarden noemen geen vaste einddatum. Zij beperken het
gebruik tot project 58679, verbieden delen of publiceren van de beveiligde data
en verplichten vernietiging na gebruik. Leg daarom per levering de
gebruiksstatus en, zodra het projectgebruik eindigt, de vastgestelde
vernietigingsdatum vast. Vernietiging omvat originele bestanden, afgeleide
beveiligde bestanden, databasekopieën, tijdelijke extracties en back-ups die de
beveiligde data bevatten. Het ontvangstmanifest en een niet-inhoudelijk
vernietigingsbewijs kunnen behouden blijven.
