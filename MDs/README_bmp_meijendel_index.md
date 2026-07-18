# Handleiding index.html

Dit bestand is een korte gebruiksaanwijzing voor [bmp\_meijendel\_index.html][1].

De HTML is bedoeld om gegevens uit de database Meijendel zichtbaar en begrijpelijk te maken, ook voor gebruikers zonder veel statistische kennis.

De algemene werkwijze voor Shiny + HTML samen staat in:

- `/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/EINDHANDLEIDING_html_en_shiny.md`

De HTML is vooral een kijk- en controlebestand, niet de plek waar nieuwe TRIM-berekeningen worden gemaakt.

## Tab BMP-Soorten

In `BMP-Soorten` zijn er drie keuzes.

### 1. Territoria

Dit laat de ruwe aantallen territoria per soort of per groep zien.
Bron:
rechtstreeks uit `meijendel.sql`

### 2. Dichtheid (per km²)

Dit laat aantallen per oppervlakte zien.
De HTML gebruikt hiervoor nu het werkelijke oppervlak uit `plot_jaar_oppervlak`.
Als `plot_jaar_teller` aanwezig is, wordt alleen het bemeten oppervlak meegenomen.
Bron:
`meijendel.sql`, plus oppervlak uit `plot_jaar_oppervlak` en telling uit `plot_jaar_teller`

### 3. TRIM-index

Dit is de beste keuze als je de langjarige trend van een soort wilt bekijken, vooral bij:

- ontbrekende tellingen
- verschillen in meetinspanning
- de methodebreuk rond 1984

Praktisch:

1. Open de tab `Trend`
2. Kies `TRIM-index`
3. Kies daarna een soort

Dan zie je:

- de TRIM-grafiek
- een korte uitleg zoals `matige afname`, `lichte toename` of `stabiel`

Bron:

- `soortindices_bruikbare_tijdreeks.csv`
- `soorten_trendoverzicht_bruikbare_tijdreeks.csv`
- aanvullend `soortindices_per_jaar.csv` en `soorten_trendoverzicht.csv` voor soorten met `alleen_post_bruikbaar`

Soorten met `alleen_post_bruikbaar` hebben geen bruikbare reeks voor de periode voor 1984.
Het dashboard toont voor die soorten wel de Meijendel-TRIM vanaf het eerste bruikbare post-1984 jaar.
Voor soorten die al in `soortindices_bruikbare_tijdreeks.csv` staan, blijft die volledige reeks leidend.

## Tab Groepen

In `Groepen` zijn er twee keuzes.

### 1. Dichtheid per km2

Dit is de bestaande benadering op basis van dichtheid en GAM-trendlijnen.
Bron:

- `gam_voorspellingen_per_groep.csv`
- `gam_interpretatie_per_groep.csv`

### 2. TRIM

Dit is de groepsindex op basis van TRIM-soortindices.
Gebruik deze keuze als je de ontwikkeling van ecologische vogelgroepen wilt bekijken met dezelfde trendlogica als bij TRIM per soort.
Trendlabels zijn eigen trendduidingen op basis van de TRIM-index; het zijn geen officiële TRIM-classificaties.
Index 100 betekent per soort het eerste analysejaar vanaf het eerste positieve jaar; soorten kunnen dus verschillende basisjaren hebben.

Je ziet:

- een eerste TRIM-MSI grafiek met `Volledige MSI` en `Robuuste MSI`
- een tweede grafiek waarin de volledige Meijendel-TRIM-MSI als GAM met 95%-band wordt vergeleken met een landelijke GAM-lijn zonder band
- een korte uitleg per groep

Bron:

- `msi_per_groep_per_jaar.csv`
- `trendoverzicht_msi_groepen.csv`
- eventueel ook `gam_voorspellingen_msi_groepen.csv`
- eventueel ook `gam_interpretatie_msi_groepen.csv`

Bij beide keuzes gebruikt het groepsmenu vier hoofdkeuzes: `Alles`, `Lijsten`, `Habitattypen` en `Ecologische Vogelgroepen`.
`Alles` gebruikt alle soorten.
Onder `Lijsten` staan `Rode Lijst`, `Oranje Lijst`, `Rode en Oranjelijst` en `Vogelrichtlijn`.
De `Oranje Lijst` wordt afgeleid uit `soort_richtlijn` met `richtlijn_id = 6`.
De `Vogelrichtlijn` wordt afgeleid uit `soort_richtlijn` met `richtlijn_id = 7`.
Onder `Habitattypen` staan de Natura 2000-habitattypen `2110`, `2120`, `2130`, `2160`, `2180`, `2190`, `3140` en `6430`.
De habitatgroepen worden afgeleid uit `soorten_habitattypen`; soorten met koppelingsterkte `sterk`, `matig` of `zwak` worden samengenomen per habitatcode.
Bij elke groep toont het dashboard ook een tekstvak met de vogelsoorten die in de gekozen groep zitten.
Bij `Groepen` > `Dichtheid per km2` worden geen MSI-waarden meer gebruikt. Per jaar worden de werkelijke territoria van alle soorten in de gekozen groep opgeteld en gedeeld door het beschikbare oppervlak van Meijendel in dat jaar.
Bij `Groepen` > `TRIM` toont het dashboard naast de directe volledige/robuuste MSI ook twee GAM-vergelijkingen: eerst de robuuste MSI en daarna de volledige MSI. Beide GAM-grafieken worden gevolgd door een eigen TRIM-uitlegblok. De soortenbox splitst de gebruikte soorten uit in `Robuuste MSI` en `Volledige MSI`.

De standaardperiode voor de groepengrafieken is `1990-2025`. De gebruiker kan deze periode in het dashboard blijven aanpassen.

## Functionele vogelgroepen — fase A

Status: vastgesteld op 18 juli 2026. Deze fase beschrijft scope, nulmeting,
traitwoordenboek, doelmodel en migratie. Er zijn nog geen functionele groepen aan
het dashboard toegevoegd en er zijn geen databasewaarden gewijzigd.

### Versie 1 en algemene beslisregels

De eerste versie bevat vijf aanvullende groepen:

| Groep-ID | Titel | Primair | Secundair | Belangrijkste uitsluiting |
|---|---|---|---|---|
| `fg_v1_bodem_insect` | Bodemfoeragerende insecteneters | minimaal 50% terrestrische ongewervelden én minimaal 50% bodem/strooisel/lage vegetatie | beide minimaal 25% of ordinaal minimaal substantieel | aquatische prooien, incidenteel bodemgebruik of overwegend ander voedsel |
| `fg_v1_lucht` | Luchtfoerageerders | minimaal 50% vliegende prooien én minimaal 50% actieve luchtvangst | minimaal 25% ecologisch belangrijke luchtvangst | prooi van blad, bodem of water nemen; alleen zoekvlucht |
| `fg_v1_grondbroed` | Grondbroeders | dominante nestplaats op/direct aan bodem of in vegetatie tot circa 25 cm | substantieel grondnestgebruik in Nederland/Meijendel | ondergrondse holen, struik-, boom- of constructienest als dominante strategie |
| `fg_v1_holenbroed` | Holenbroeders | omsloten holte is normale/dominante nestplaats | regelmatig maar niet dominant holtegebruik | halfopen nis, richel of incidenteel holtegebruik |
| `fg_v1_lange_trek` | Langeafstandstrekkers | meer dan 50% Nederlandse broedpopulatie intercontinentaal of bezuiden Sahara | 25–50% of onderbouwde gedeeltelijke langeafstandstrek | stand-, korte- en middellangeafstandstrek |

Soorten mogen in meerdere groepen en subgroepen voorkomen. Primair krijgt in de
gewogen gevoeligheidsanalyse `1,0`, secundair `0,5`; daarnaast wordt altijd een
binaire analyse uitgevoerd. Incidenteel gebruik telt niet mee. `NULL` betekent
onbekend en mag nooit naar `0` worden omgezet.

Publicatiestatus op basis van soorten met een bruikbare trend:

| Aantal | Status |
|---:|---|
| minder dan 5 | geen groepsindicator |
| 5–9 | uitsluitend exploratief |
| 10–19 | bruikbaar met nadrukkelijke onzekerheidsanalyse |
| 20 of meer | in beginsel geschikt als robuuste hoofdgroep |

### Minimaal traitwoordenboek `TR1`

Nieuwe codes gebruiken `TR1_*`. Zij vervangen of hernoemen bestaande `F`, `J`,
`K`, `M`, `N` of `V` niet.

| Traitcode | Datatype | Eenheid/categorie | Context | Gebruik |
|---|---|---|---|---|
| `TR1_DIET_TERRESTRIAL_INVERT_SHARE` | decimal | 0–1 | adult, broedseizoen, NL/NW-Europa | verplicht bodem-insect |
| `TR1_DIET_FLYING_PREY_SHARE` | decimal | 0–1 | adult, broedseizoen, NL/NW-Europa | verplicht lucht |
| `TR1_FORAGE_GROUND_LOW_SHARE` | decimal | 0–1 | broedseizoen | verplicht bodem-insect |
| `TR1_FORAGE_AERIAL_CAPTURE_SHARE` | decimal | 0–1 | broedseizoen | verplicht lucht |
| `TR1_FORAGE_SUBSTRATE` | multi-category | bodem, strooisel, lage vegetatie, struik, boom, water, lucht | broedseizoen | onderbouwing voedselgroepen |
| `TR1_FORAGE_METHOD` | multi-category | grondpikken, strooiselzoeken, sonderen, uitvaljacht, continue luchtjacht, overige | broedseizoen | onderbouwing voedselgroepen |
| `TR1_NEST_GROUND_SHARE` | decimal | 0–1 | Nederlandse broedpopulatie | verplicht grondbroed |
| `TR1_NEST_HEIGHT_M` | decimal | meter | Nederlandse broedpopulatie | grenscontrole grondbroed |
| `TR1_NEST_CAVITY_SHARE` | decimal | 0–1 | Nederlandse broedpopulatie | verplicht holenbroed |
| `TR1_NEST_CAVITY_TYPE` | multi-category | boom, bodem/konijn, nestkast, gebouw/constructie | Nederlandse broedpopulatie | subgroepen holenbroed |
| `TR1_NEST_CAVITY_ORIGIN` | multi-category | zelf uitgehakt, natuurlijk, bestaand spechtenhol, kunstmatig | Nederlandse broedpopulatie | subgroepen holenbroed |
| `TR1_MIG_LONG_DISTANCE_SHARE` | decimal | 0–1 | Nederlandse/NW-Europese broedpopulatie | verplicht lange trek |
| `TR1_MIG_WINTER_REGION` | multi-category | Europa, Noord-Afrika/Middellandse Zee, Sahel, Afrika bezuiden Sahara, overig | populatiegebonden | onderbouwing lange trek |
| `TR1_MIG_STRATEGY` | category | stand, gedeeltelijk, kort/middel, lang, onbekend | populatiegebonden | controle lange trek |

Wanneer een bron alleen `dominant`, `substantieel` of `incidenteel` levert, wordt
geen kunstmatig percentage ingevuld. De ordinale bronwaarde wordt apart bewaard;
groepsafleiding gebruikt dan de in de definitieversie vastgelegde ordinale regel.

### Audit van de bestaande kenmerken

De nulmeting gebruikt `meijendel.sql`, de bestaande parser in
`shiny_meijendel/helpers.R` en
`trim/soorten/soorten_bruikbare_tijdreeks_selectie.csv`.

| Controle | Uitkomst |
|---|---:|
| kenmerkrelaties | 2.437 |
| soorten met minimaal één kenmerk | 159 |
| gebruikte codes | 546 |
| primaire waarden (`1`) | 2.091 |
| secundaire waarden (`2`) | 346 |
| incidentele waarden (`3`) | 0 |
| actieve dictionarycodes | 545 |
| ongebruikte dictionarycodes | 14 |
| dubbele soort/categorie/code-sleutels | 0 |
| ontbrekende Nederlandse dictionarylabels | 0 |
| ongeldige parentcodes | 0 |
| verweesde codes | 1: `F-Mud` |

De denormaliseerde kolom `soortnaam` wijkt bij zeven soorten af van de actuele
stamnaam: Europese Oehoe, Sprinkhaanrietzanger, Baardmannetje, Eidereend,
Europese Zeearend, Gewone Fazant en Europese Kraanvogel. Dit raakt 86 rijen; de
`soort_id`-koppeling blijft leidend. Orpheusspotvogel en Braamsluiper hebben exact
dezelfde vogeltypering, wat inhoudelijk moet worden herbeoordeeld.

#### Hiaten bij soorten met bruikbare trend

| Domein | Gevuld | Ontbrekend |
|---|---:|---:|
| functionele habitat en foerageerwijze | 90/95 | 5 |
| voedsel volwassenen | 87/95 | 8 |
| nestplaats en nestbouw | 88/95 | 7 |
| migratie | 76/95 | 19 |
| voedsel jongen | 66/95 | 29 |
| gedrag, ecologie en levenswijze | 60/95 | 35 |

Soorten zonder enig functioneel habitat/foerageerkenmerk zijn Torenvalk,
Tortelduif, Boerenzwaluw, Barmsijs en Goudvink. Dezelfde vijf missen alle
legacytraits. De hiaten in de voor versie 1 direct relevante legacydomeinen zijn:

- foerageerhabitat/-methode (`F`): Torenvalk, Tortelduif, Boerenzwaluw,
  Barmsijs en Goudvink;
- voedsel volwassen vogels (`V`): dezelfde vijf, plus Stormmeeuw, Ransuil en
  Kuifmees;
- nestplaats (`N`): dezelfde vijf, plus Turkse Tortel en Koekoek;
- trek (`M`): Torenvalk, Houtsnip, Stormmeeuw, Holenduif, Tortelduif,
  Ransuil, Kleine Bonte Specht, Boomleeuwerik, Boerenzwaluw, Boompieper,
  Paapje, Tapuit, Grauwe Vliegenvanger, Bonte Vliegenvanger, Kuifmees,
  Zwarte Mees, Wielewaal, Barmsijs en Goudvink.

Dit is alleen een domeindekkingscontrole. Eén bestaande code binnen een domein
bewijst nog niet dat alle benodigde `TR1_*`-traits voor die soort zijn
beoordeeld. Fase B maakt daarom eerst een volledige soort-traitmatrix: elke cel
krijgt een onderbouwde waarde of blijft expliciet `NULL` (onbekend). Een
ontbrekende rij of `NULL` mag nooit als afwezig of nul worden geïnterpreteerd.
De lijsten worden bij de verse fase-B-audit opnieuw uit de levende database
gegenereerd.

De fase-A-codes leveren slechts een indicatie van haalbaarheid: direct herkenbare
legacycodes geven 54 bruikbare kandidaten voor bodemfoerageren, 6 voor
luchtfoerageren, 34 voor grondbroeden, 32 voor holenbroeden en 24 voor
langeafstandstrek. Dit zijn geen goedgekeurde groepslijsten, omdat proporties,
context en echte onbekenden nog ontbreken.

### Gecontroleerde migratie naar de nieuwe traitlaag

1. Maak aan het begin van fase B een verse dump van de levende lokale
   Meijendel-database en herhaal de nulmeting.
2. Maak de nieuwe trait-, bron-, import- en groepstabellen naast legacy; wijzig
   bestaande tabellen nog niet.
3. Registreer alle `TR1`-definities, categorieën en bronmetadata met versie.
4. Vertaal legacycodes alleen via `legacy_trait_mapping`. Niet-eenduidige codes
   krijgen `needs_review`; `F-Mud` en naamafwijkingen worden niet stilzwijgend
   gecorrigeerd.
5. Migreer legacywaarden als `legacy_unvalidated`, zonder ze als voorkeurswaarde
   voor publicatie te markeren.
6. Importeer externe basisdata reproduceerbaar en bewaar originele waarde,
   taxonomie, omzettingsregel, licentie en bestands-SHA.
7. Vul ontbrekende verplichte traits aan en laat conflicten/lokale afwijkingen
   inhoudelijk beoordelen.
8. Ken per soort/trait/context exact één goedgekeurde voorkeurswaarde toe of leg
   expliciet `unknown` vast.
9. Genereer de vijf groepslijsten uitsluitend uit de vastgelegde regels en voer
   binaire, gewogen en leave-one-species-outcontroles uit.
10. Schakel dashboard en Shiny pas om na inhoudelijke goedkeuring en groene
    pariteit; verwijder legacy niet in dezelfde release.

Fase B is daarmee de fase waarin ontbrekende broedvogelkenmerken technisch worden
gematerialiseerd en vervolgens inhoudelijk worden aangevuld. Fase A maakt de
hiaten zichtbaar en bepaalt wat als voldoende, onvoldoende of onbekend geldt.

### Uitvoering technische fase B — 18 juli 2026

De levende lokale MySQL-database is eerst vergeleken met de repositorydump. De
relevante legacytabellen waren inhoudelijk rij voor rij gelijk; alleen de
weergave van timestamps verschilde door de tijdzone. Voor de migratie is een
volledige tijdelijke back-up gemaakt.

Naast legacy zijn twaalf genormaliseerde tabellen en de view `v_trait_gap_v1`
gebouwd. `TR1` bevat 22 definities: 14 verplichte doeltraits en acht
ondersteunende brontraits. De analysescope `TRIM_BRUIKBAAR_V1` bevat exact 95
soorten. De vijf groepsdefinities zijn geregistreerd, maar
`functional_group_membership` is bewust nog leeg.

Geïmporteerde bronnen:

| Bron | Context | Bestand-SHA-256 | Waarden voor scope |
|---|---|---|---:|
| legacy `soorten_kenmerken` | lokaal, context grotendeels onbekend; `legacy_unvalidated` | databasebatch | 1.027 |
| EltonTraits 1.0, DOI `10.6084/m9.figshare.3559887.v1` | mondiaal, semikwantitatief dieet en foerageerstratum | `97216eb1797da077169ebb1ebea275db293b09fc62f8bb8911f9beb98c50d321` | 285 |
| European bird life-history data, DOI `10.5061/dryad.n6k3n` | Europees, soortniveau migratie | `d9ea735c3dba886fe2bc0a9cdaf00662232efcb19a7fb717a02864047357bba5` | 190 |
| Global Nest Traits v2, DOI `10.5281/zenodo.10128906` | mondiaal, binaire nestkenmerken | `f267ed323fa55abac78a380e0efd581a7d6c5f917c06ae9049aeaac037566ec7` | 456 |

De bronmetadata bevat versie, DOI/URL, licentie, raadpleegdatum, bestands-SHA en
importregel. Voor elke externe dataset zijn alle 95 brontaxa expliciet aan een
Meijendel-soort gekoppeld. Daarbij worden synoniemen zichtbaar bewaard. Voor de
European bird life-history data gebruikt de import de oorspronkelijke velden
`Genus` en `Species`; het meegeleverde veld `scientificNameStd` bevat ten minste
de foutieve omzetting `Muscicapa striata` naar `Muscicapa atrata`.

Globale en Europese soortwaarden zijn niet als lokale populatiewaarde gebruikt.
Voor alle 95 × 14 verplichte Nederlandse/NW-Europese doelcontexten is daarom een
expliciete voorkeurswaarde met status `unknown` vastgelegd. De gapview verdeelt
de 1.330 cellen als volgt:

| Vervolgstatus | Aantal |
|---|---:|
| `bron_ontbreekt` | 897 |
| `inhoudelijke_review` | 273 |
| `contextreview` | 160 |

De technische fase B is hiermee reproduceerbaar afgerond. De inhoudelijke fase B
blijft open: broninformatie moet per Nederlandse/NW-Europese broedpopulatie
worden beoordeeld, waar nodig aangevuld en vervolgens als `approved` of bewust
`unknown` worden vastgelegd. Tot die beoordeling gereed is, start fase C niet en
worden geen functionele groepslijsten gepubliceerd.

## Relatie met publieke soortpagina's

Status 2026-06-30:

- De publieke FastAPI/Jinja-soortpagina's op `app.vwg-m.nl` gebruiken bestaande Meijendel-kenmerkdata als read-only bron voor een aanvullend blok `Vogelkenmerken`.
- Dat blok is compacter dan de dashboardtab `Soort-kenmerken`: eerst lijsten, daarna hoofdgroepkenmerken als doorlopende tekst.
- De dashboardweergave in `bmp_meijendel_index.html` blijft de controleweergave voor de volledige kenmerkenstructuur; de publieke site toont alleen een leesbare samenvatting per soort.

Gewijzigde bestanden voor deze website-ronde: geen in de Meijendel-HTML zelf; in de website-repo zijn `app/queries.py`, `app/templates/species_detail.html`, `app/static/site.css` en `handleiding_beheer.md` aangepast.

Resterende risico's: de dashboardtab en publieke samenvatting gebruiken dezelfde brontabellen, maar er is nog geen automatische vergelijkingstest die controleert dat alle publiek getoonde kenmerken uit de dashboardbron komen.

Aanbevolen volgende stap: voeg een kleine controle toe voor enkele voorbeeldsoorten, waarbij dashboardkenmerken en publieke soortpagina-samenvatting op aanwezigheid van dezelfde hoofdgroepen worden vergeleken.

## Tab Plots-soorten

Deze tab toont per gekozen plot welke vogels daar ooit met een positief aantal territoria als broedvogel zijn geregistreerd.

De gebruiker kiest:

- één plot;
- een periode vanaf 1958 tot en met het laatste beschikbare jaar;
- alfabetische volgorde of volgorde op EURING-code.

De tabel toont aantallen territoria per jaar. Er staan maximaal tien jaren tegelijk in beeld, van oud naar nieuw. De knoppen `Vorige 10 jaar` en `Volgende 10 jaar` bladeren binnen de gekozen periode. Een streepje betekent dat voor die soort en dat jaar geen waarde is geregistreerd.

De eerdere tab `Kenmerken` heet nu `Soort-kenmerken`. De eerdere tab `Plots` heet nu `Plots-kenmerken`.

In `Plots-kenmerken` staat ook het blok `Vegetatiemeetnet (PQ)`. Het gekozen jaar toont aantal PQ's/opnamen, taxa, gemiddelde soortenrijkdom per PQ, gemiddelde bedekkingssom, Shannon-index en dekkingskwaliteit. Daaronder staat de volledige beschikbare historische meetreeks voor dat plot. Ontbrekende meetjaren blijven ontbrekend; er vindt geen interpolatie plaats.

## Tab Wintertellingen

De wintergrafiek toont per gekozen vogel een lijn met één punt per winterperiode.

### Periode

Een winterperiode loopt van september tot en met maart.
De labels in de grafiek gebruiken de laatste twee cijfers van de betrokken jaren:

- `00/01`
- `01/02`
- `02/03`

April tot en met augustus worden voor deze grafiek niet meegenomen.

### Berekening per punt

Per vogel en per periode wordt als volgt gerekend:

1. Selecteer alle `dagwaarnemingen_wv` voor september t/m maart.
2. Koppel elke waarneming aan het juiste seizoen via maand en jaar.
3. Sommeer eerst per combinatie `soort + datum + plot`.
4. Zoek het plotoppervlak op in `plot_jaar_oppervlak` voor hetzelfde `plot_id + jaar`.
5. Deel het dag-plottotaal door `oppervlakte_km2`.
6. Sommeer deze oppervlakgecorrigeerde dag-plotwaarden per seizoen.

De y-as is daardoor:

`gesommeerde aantallen per km2`

Deze aanpak voorkomt dat meerdere records op dezelfde dag en in hetzelfde plot eerst los door het oppervlak worden gedeeld. Eerst wordt binnen datum en plot opgeteld, daarna pas gecorrigeerd voor oppervlak.

## Tab Tellers

De HTML gebruikt dan onder andere:

- `tellers`
- `plot_jaar_teller`
- `plots`

## Belangrijk om te onthouden

`Territoria`, `Dichtheid`, `TRIM-index`, `Dichtheid per km2`, `TRIM` en de wintertellinggrafiek zijn niet precies hetzelfde.

Ze beantwoorden verschillende vragen:

- ruwe aantallen
- aantallen per oppervlakte
- trend per soort
- vloeiende groepslijn
- TRIM-gebaseerde groepsindicator
- winteraantallen gecorrigeerd per plotoppervlak en samengevat per september-maartseizoen

Daarom is het goed dat ze in de HTML apart zichtbaar blijven.

Voor een vaste controleset kun je ook kijken in:

- `/Users/ton/Documents/GitHub/Meijendel/shiny_meijendel/CONTROLESET_html_shiny.md`

[1]:	/Users/ton/Documents/GitHub/Meijendel/bmp_meijendel_index.html
