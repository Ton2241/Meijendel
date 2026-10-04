# Ontwerp: SOVON-BMP jaarontvangst en gecontroleerde verrijking

**Datum:** 2 oktober 2026  
**Status:** goedgekeurd; uitgewerkt na ontvangst van alle jaarwerkboeken  
**Reikwijdte:** SOVON-gegevens 1984–2025; gegevens uit VWG-jaarverslagen blijven buiten deze verwerking

## Doel

De nieuwe SOVON-jaarleveringen worden per jaar vergeleken met de levende lokale
database. De database krijgt eerst een brongetrouwe ontvangstlaag. Pas daarna
wordt per jaar besloten welke goedgekeurde gegevens de bestaande
`dagbezoeken_bmp`, `dagwaarnemingen_bmp` en `territoria` aanvullen of corrigeren.

De ontvangstlaag bewaart ook gegevens die niet tot de gewone analyse worden
toegelaten: formeel afgekeurde tellingen, lege matrixcellen, bronconflicten en
onbesliste plotjaren. Een ontbrekende bronregel is nooit een verwijderingsopdracht.

## Vastgestelde bronstructuur

Voor ieder jaar 1984–2025 staan op de T7 twee nieuwe officiële werkboeken:

- een territoriummatrix met 5.306 plot-soortregels, verdeeld over 56 plots en
  253 SOVON-soortcodes;
- een werkboek met totalen per bezoek en soort.

De territoriummatrix kent drie verschillende bronwaarden:

1. positief territoriumaantal;
2. expliciete nul;
3. lege cel.

Een lege cel is geen nul. Over 1984–2025 varieert het aantal expliciete nullen
van 860 tot 2.890 per jaar. Het aantal positieve regels varieert van 568 tot
1.657. De bezoektotalen bevatten per jaar 16–49 plotsecties en 111–482 bezoeken.

De standaardexport `resultaten.xlsx` bevat uitsluitend positieve resultaten en
is vóór 2007 leeg. Vanaf 2007 is hij bovendien niet gelijk aan de matrix. Voor
bekende formeel afgekeurde plotjaren kunnen bezoeken en positieve resultaten in
de standaardexport staan terwijl alle matrixcellen leeg zijn. Dat patroon is
een controlesignaal, maar geen zelfstandig bewijs van formele afkeuring: ook
onvolledige of andersoortige tellingen kunnen zo verschijnen.

De levende database bevat voor 1984–2025 14.455 BMP-bezoeken, voor 2007–2025
600.959 dagwaarnemingen en 52.350 SOVON-territoriumregels. De bestaande
`territoria`-tabel bevat slechts zestien nulregels, uit 1993–2006. De nieuwe
matrix voegt dus een substantiële expliciete nulstructuur toe. Diverse positieve
jaartotalen verschillen eveneens. Zo bevat de matrix voor 1984 568 positieve
plot-soortregels met samen 7.811 territoria; de levende SOVON-laag bevat 562
regels met samen 6.915 territoria. Bronwaarden mogen daarom niet rechtstreeks
over bestaande waarden worden geschreven.

## Gegevensmodel

De ontvangstlaag gebruikt herkenbare SOVON-BMP-tabellen en blijft gekoppeld aan
het centrale taxonregister.

### `sovon_bmp_jaarlevering`

Eén versieerbare levering per jaar, met bestandsnamen, SHA-256, ontvangstdatum,
regelversie, aantallen en status. Een nieuwe download overschrijft een eerdere
levering niet.

### `sovon_bmp_soortenlijstversie` en `sovon_bmp_soortenlijst_taxon`

De toepasselijke officiële BMP-soortenlijst wordt als protocolcontext
geregistreerd, niet als zelfstandige taxoncatalogus. Iedere lijstregel verwijst
naar `soorten` én naar de bijbehorende centrale `taxa_bronkoppeling`. De
letterlijke SOVON-naam en Euring-code blijven bewaard. Historische naam- of
conceptgelijkheid wordt niet uit een naamovereenkomst afgeleid.

### `sovon_bmp_plotjaar`

Per plot en jaar worden de voorwaarden voor de nulregel afzonderlijk bewaard:

- BMP-type;
- standaard alle soorten of expliciete uitzondering;
- volledig geteld: ja, nee of nog te beoordelen;
- beoordelingsstatus: goedgekeurd, formeel afgekeurd of nog te beoordelen;
- toepasselijke officiële soortenlijstversie.

Daarnaast worden matrixstatus, aantal bronbezoeken, bronopmerkingen,
controlebesluit en regelversie vastgelegd. De standaard van de data-eigenaar is
`BMP-A` en `alle soorten`; een afwijking vereist een expliciete bron of een
vastgelegd jaarbesluit.

### `sovon_bmp_plotjaar_tellercode`

SOVON-tellercodes worden letterlijk en meervoudig bewaard. Een code vervangt
`plot_jaar_teller` nooit automatisch. De jaarcontrole registreert per code of
zij overeenkomt, onderdeel van een team is, strijdig is of onbeslist blijft.

### `sovon_bmp_bezoek` en `sovon_bmp_bezoek_taxon`

Bezoeken, tijden, bezoektype, opmerkingen en de per bezoek getoonde
soorttotalen worden brongetrouw genormaliseerd. Tracks worden niet opgeslagen;
het kavel geldt als getelde meeteenheid. Een bezoek kan worden gekoppeld aan
`dagbezoeken_bmp`, maar die koppeling bewijst geen goedkeuring en geen
individuele tellerdeelname.

Samengestelde AVIMAP-waarden blijven raw bewaard en worden daarnaast gesplitst:
het getal vóór haakjes is `aantal_waarnemingen` binnen het telgebied; het getal
tussen haakjes is `aantal_buiten_plot`. Een bronwaarde als ` (1)` betekent dus
nul binnen en één buiten het telgebied en is nadrukkelijk geen echte nul.

Zoogdieren en andere niet-vogels zijn gelegenheidswaarnemingen tijdens het
vogelbezoek. Daarvoor geldt geen afzonderlijk telprotocol of volledige
soortenlijst. Alleen positieve bronregels worden bewaard; een lege of
ontbrekende niet-vogelregel is nooit een echte nul. Positieve niet-vogelregels
worden bij de jaarcontrole vergeleken met de primaire `sovon_avimap_*`-laag en
niet als tweede waarneming geteld.

### `sovon_bmp_waarneming` en `sovon_bmp_territoriumpunt`

De jaargebonden puntlagen `bezoekstippen` en `territoria` worden eveneens
brongetrouw opgenomen. De waarnemingslaag bewaart onder meer bron-ID,
bezoek-ID, broedcode, `inplot` en RD-coördinaat; broedcode 0 blijft een
positieve waarneming. De territoriumpunten krijgen naast het bronrijnummer een
inhoudelijke SHA-256, omdat de shapefile geen zelfstandige territorium-ID
levert. Tracks en gebiedspolygonen blijven buiten scope.

### `sovon_bmp_plotjaar_taxon`

Iedere matrixrij wordt bewaard, inclusief lege cellen. Kernvelden zijn de
letterlijke bronnaam en Euring-code, de centrale taxonkoppeling, de
matrixcelstatus (`positief`, `expliciete_nul`, `leeg`), het eventuele
territoriumaantal en de bronvergelijking met standaardexport en levende
database.

Een expliciete nul krijgt alleen analytische status `notDetected` wanneer alle
vijf plotjaarvoorwaarden positief zijn. Anders blijft zij een bronmatige nul
zonder analysetoelating. Een positieve waarde krijgt `detected`. Broedcode 0 is
altijd een positieve waarneming; zij mag nooit naar afwezigheid worden vertaald.

## Goedkeuring en afgekeurde gegevens

`formeel_afgekeurd` is een expliciete kwaliteitsstatus, geen synoniem voor een
lege matrix, een onvolledige telling of een ontbrekend resultaat. De elf reeds
door de data-eigenaar vastgestelde afgekeurde plotjaren worden als zodanig
overgenomen. Andere kandidaten worden per jaar beoordeeld.

Afgekeurde bezoeken, waarnemingen en positieve resultaten blijven in de
SOVON-ontvangstlaag zichtbaar. Zij worden niet aan de gewone territoriumanalyse
toegevoegd. De bestaande betekenis van `territoria` blijft: formele territoria
uit goedgekeurde tellingen. Analyseviews sluiten `formeel_afgekeurd`,
`niet_volledig` en `te_beoordelen` standaard uit.

## Jaarwerkwijze

Voor ieder jaar, beginnend met 1984:

1. valideer beide nieuwe werkboeken en de bestaande standaardexport;
2. vergelijk plotten, bezoeken, tellercodes, positieve resultaten, nullen,
   lege cellen en bronopmerkingen;
3. bepaal per plotjaar BMP-type, soortenbereik, volledigheid, goedkeuring en
   soortenlijstversie;
4. presenteer alle verschillen met de levende database, zonder voor dat jaar
   al gegevens naar de levende database te schrijven en zonder VWG-bronregels
   als SOVON-correctie te behandelen;
5. laat Ton besluiten of en hoe de verschillen van dat jaar worden verwerkt;
6. leg pas na dat besluit de goedgekeurde brongegevens vast en verrijk alleen
   de uitdrukkelijk goedgekeurde, volledig onderbouwde canonieke tabellen;
7. controleer centrale taxonbereikbaarheid, referentiële integriteit,
   uniciteit, afnemers en herhaalbaarheid.

De volgende jaarcontrole begint pas nadat het vorige jaar inhoudelijk is
afgerond.

## Darwin Core en TDWG TCS

Een plotjaar is een Darwin Core `Survey` Event; bezoeken zijn onderliggende
`siteVisit` Events. Plotjaar-soortresultaten zijn Occurrences met
`occurrenceStatus=detected` of, uitsluitend na de nulpoort,
`occurrenceStatus=notDetected`. Territoria worden als `organismQuantity`
opgeslagen met een expliciet `organismQuantityType`; zij zijn geen aantallen
individuen. Formele afkeuring blijft een afzonderlijke lokale kwaliteitsstatus.

De SOVON-naam en Euring-code zijn bronidentificaties. De centrale koppeling aan
`taxa` en `taxa_bronkoppeling` maakt de waarneming bereikbaar, maar bewijst geen
historische taxonconceptgelijkheid. Dat volgt de scheiding tussen Taxon Name,
Taxon Concept en naamgebruik uit TDWG TCS.

## Niet in deze verwerking

- gegevens die uitsluitend uit VWG-jaarverslagen stammen;
- tracks of looproutes;
- actuele, niet-geversioneerde SOVON-gebiedspolygonen;
- automatische vervanging van `plot_jaar_teller` door een AVIMAP-code;
- jaar 2026;
- VPS-publicatie.
