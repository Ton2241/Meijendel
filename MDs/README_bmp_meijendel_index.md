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

### Uitvoering fase B — 18 juli 2026

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
| Nederlands Soortenregister, vogelsoortteksten | Nederland/NW-Europa, soorttekst en ecologie | `0fe8d4db25768178bf0be6319383aadfd37a953462d1eae0dcb79bcfd0531bb0` | 95 soortrecords; bewijsbron |
| Vogelbescherming Nederland, online vogelgids | Nederland/NW-Europa, voedsel, broeden en trek | `0fe8d4db25768178bf0be6319383aadfd37a953462d1eae0dcb79bcfd0531bb0` | 95 soortpagina's; bewijsbron |
| `TR1_DERIVATION_RULES_V1` | vaste bronhiërarchie en omzettingsklassen | intern, versie 1 | bewijsbron |

De bronmetadata bevat versie, DOI/URL, licentie, raadpleegdatum, bestands-SHA en
importregel. Voor elke externe dataset zijn alle 95 brontaxa expliciet aan een
Meijendel-soort gekoppeld. Daarbij worden synoniemen zichtbaar bewaard. Voor de
European bird life-history data gebruikt de import de oorspronkelijke velden
`Genus` en `Species`; het meegeleverde veld `scientificNameStd` bevat ten minste
de foutieve omzetting `Muscicapa striata` naar `Muscicapa atrata`.

De inhoudelijke bronhiërarchie is Nederland > Europa > mondiaal. Voor alle 95
soorten zijn daarom eerst de Nederlandse soortteksten beoordeeld. Europese data
is fallback; mondiale data wordt alleen gebruikt wanneer Nederlandse en Europese
informatie het gevraagde detail niet leveren, of als controle. Tegenstrijdige
mondiale coderingen worden niet gemiddeld met de Nederlandse bron. Zo is de
Nederlandse beschrijving van zwaluwen als luchtjagers leidend boven een afwijkend
mondiaal grondfoerageerpercentage. De codering behandelt ontkenningen zoals
`niet-vliegende insecten` expliciet en rekent drijvende vegetatiematten en
oevernesten conform de fase-A-definitie tot broeden op grond-/waterniveau.

Kwalitatieve termen zijn met een vaste rubric omgezet naar categorieën en de
semikwantitatieve waarden `0`, `0,25`, `0,5`, `0,75` of `1`. Dit zijn
analyseproxies en geen gemeten lokale populatieaandelen. De onzekerheid is per
waarde vastgelegd in `confidence_score` en `evidence_note`; de omzettingsregel is
als aparte bron geregistreerd. Iedere eindwaarde heeft minimaal twee
bronkoppelingen met een soortpagina-, API-record- of datasetlocator. Van de
Vogelbescherming-pagina's zijn alleen feiten gecodeerd, geen bronteksten
gekopieerd.

Het eindbatch `TR1FINAL_20260718` bevat 1.505 goedgekeurde waarden voor 1.330
verplichte soort-traitcellen. Het verschil ontstaat door de toegestane meerdere
categorieën bij substraat, methode, holtetype/-oorsprong en winterregio. De vijf
eerder volledig ontbrekende soorten — Torenvalk, Tortelduif, Boerenzwaluw,
Barmsijs en Goudvink — hebben nu elk alle 14 verplichte traits. De eindcontrole:

| Controle | Uitkomst |
|---|---:|
| verplichte gapcellen `gereed` | 1.330 / 1.330 |
| geprefereerde waarden `unknown` | 0 |
| soorten met niet exact 14 verplichte traits | 0 |
| eindwaarden met minder dan twee bronkoppelingen | 0 |
| gegenereerde groepslidmaatschappen | 0 |

Fase B is hiermee inhoudelijk en technisch afgerond. Fase C genereert pas daarna
de groepslijsten en voert vanwege de proxies verplicht een gevoeligheidsanalyse
rond de selectiedrempels uit. Dashboard, Shiny en website zijn nog niet naar de
nieuwe traitlaag omgeschakeld.

### Uitvoering fase C — 18 juli 2026

De vijf goedgekeurde definities zijn toegepast op uitsluitend de `approved`,
geprefereerde TR1-doelwaarden binnen `TRIM_BRUIKBAAR_V1`. Naast de numerieke
drempels worden de verplichte contextgates gebruikt: methode en substraat bij
foerageergroepen, nesthoogte en holtetype bij broedgroepen en winterregio bij
langeafstandstrek. Dit voorkomt dat bijvoorbeeld een zoekvlucht zonder actieve
luchtvangst of een luchtjager zonder bodemfoerageermethode op alleen twee
proxypercentages wordt geselecteerd.

`functional_group_membership` bevat 475 rijen: iedere soort heeft binnen iedere
groep exact één classificatie `primary`, `secondary`, `excluded` of `unknown`,
een binaire waarde en gewicht `1`, `0,5`, `0` of `NULL`. De rationale bevat per
beslissing de gebruikte traitwaarde-id's, confidence, bronlocators, reden en de
uitkomst onder inclusieve en strikte drempels. Er zijn geen onbekende
classificaties. `generation_commit` is voor alle rijen
`bcdf9052e9a6ad6d8a3bf6a48b325467fbc23f14`, de Git-toestand met de
goedgekeurde fase-B-input.

| Groep | Primair | Secundair | Binair totaal | Gewogen omvang | Inclusief −0,10 | Strikt +0,10 | Baseline/strikte status |
|---|---:|---:|---:|---:|---:|---:|---|
| Bodemfoeragerende insecteneters | 16 | 27 | 43 | 29,5 | 44 | 16 | robuust / bruikbaar met onzekerheidsanalyse |
| Luchtfoerageerders | 5 | 2 | 7 | 6,0 | 7 | 5 | exploratief / exploratief |
| Grondbroeders | 34 | 6 | 40 | 37,0 | 40 | 34 | robuust / robuust |
| Holenbroeders | 28 | 0 | 28 | 28,0 | 28 | 28 | robuust / robuust |
| Langeafstandstrekkers | 25 | 2 | 27 | 26,0 | 27 | 25 | robuust / robuust |

Bij leave-one-species-out blijft de minimumstatus van alle vijf groepen gelijk.
De twee nieuwe controleviews zijn:

- `v_functional_group_membership_v1`: soortlijst, classificatie, gewicht,
  confidence, reden en gevoeligheidsclassificaties;
- `v_functional_group_summary_v1`: groepsomvang, gewogen omvang,
  gevoeligheidsaantallen, publicatiestatus en leave-one-species-out-minimumstatus.

### Uitbreiding naar alle broedvogels — 20 juli 2026

De eerdere fasering koppelde de traitverrijking ten onrechte aan de vooraf
geselecteerde 95 lange TRIM-reeksen. Dat is gecorrigeerd: gegevensverzameling
gaat voortaan vooraf aan de beoordeling van modelleerbaarheid.

- `BROEDVOGELS_MEIJENDEL_V1` bevat alle 159 soorten met sinds 1958 ten minste
  één positief territorium; de scope is afgeleid uit `territoria` en heeft SHA-256
  `a428a569770b17958b56b6e671b343342420abd0d6dc1da193d74e4bf9b06350`.
- `TRIM_BRUIKBAAR_V1` blijft ongewijzigd bestaan als aparte model- en
  robuustheidsscope van 95 soorten.
- De 64 aanvullende soorten zijn volgens dezelfde bronhiërarchie, vaste
  klasseproxy's en V1-regels verrijkt. De nieuwe bronbestanden zijn geregistreerd
  met SHA-256: EltonTraits `97216eb…d321`, European bird life history
  `d9ea735c…bba5`, Global Nest Traits v2 `f267ed32…66ec`, Naturalis NSR
  `69126024…62ab` en Vogelbescherming sitemap `f29ce40a…9aa8`.
- Exoten en gedomesticeerde vormen zijn zichtbaar aan de stamsoort gekoppeld en
  hebben lagere confidence. Bonte Kraai en Kleine Barmsijs missen in meerdere
  mondiale datasets; hun Nederlandse soortbronnen en de afleidingsregels zijn
  daarom leidend.
- De doelmatrix bevat 2.226/2.226 gereed-cellen (159 × 14), nul geprefereerde
  `unknown`-waarden en nul eindwaarden met minder dan twee bronnen.
- De vijf functionele groepen bevatten ieder 159 classificaties: 795 totaal,
  zonder `unknown`. Deze uitbreiding verandert de gegevensbeschikbaarheid; pas
  de daaropvolgende analyse bepaalt welke soortindices bruikbaar zijn.

De Appelvink is een expliciete regressiecontrole: 14 verplichte traits, 16
doelwaarderegels door meervoudige substraten, en vijf afgeleide
groepsclassificaties. Percentages op de publieke soortpagina zijn als
`klasseproxy` gelabeld en zijn geen lokaal gemeten populatiepercentages.

## Functionele vogelgroepen — fase D

Na inhoudelijke accordering maakt `R/trim_soorten_en_msi_evg.R` naast de
bestaande ecologische output vier functionele MSI-varianten per groep:
`binair`/`gewogen` × `volledig`/`robuust`. Gewogen MSI gebruikt gewicht `1,0`
voor primair en `0,5` voor secundair lidmaatschap. Alle varianten gebruiken het
gewogen geometrische gemiddelde van dezelfde gebrugde TRIM-soortindices.

Nieuwe uitvoer in `trim_msi_evg`:

- `functionele_groepssamenstelling.csv`;
- `functionele_msi_per_groep_per_jaar.csv`;
- `functionele_trendoverzicht_msi_groepen.csv`;
- `functionele_loso_trendgevoeligheid.csv`.

De dashboardcategorie `Functionele Vogelgroepen` en de Shiny-tab `Functionele
groepen` tonen dezelfde vijf groepen en een binair/gewogen schakelaar. Er wordt
geen landelijke lijn getoond, omdat geen landelijke bron met exact dezelfde
traitdefinities en gewichten beschikbaar is. De website-output gebruikt tien
vaste chart-id's: per groep één binaire en één gewogen reeks.

De lokale paritychecks zijn groen over 1958-2025. Luchtfoerageerders blijven
uitsluitend exploratief; bij bodem-insecteneters blijft de drempelwaarschuwing
verplicht. Productie is met deze fase niet automatisch gedeployd.

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

De tab heeft twee afzonderlijke modi.

### Gestandaardiseerde index

Deze modus leest de gevalideerde uitvoer uit `wintertellingen/` en toont voor de
pilotsoorten met status `betrouwbaar` of `indicatief`:

- de winterindex 2000/01–2024/25 met 95%-onzekerheidsinterval;
- het maandpatroon september–maart;
- het aantal geldige bezoeken per winter;
- de twaalf best gedekte plots met de hoogste waarnemingsfrequentie;
- het kwaliteitslabel en de methodologische beperking.

Index 100 is de gemiddelde modelwaarde over 2000/01–2004/05. De index is geen
populatiegrootte of absolute dichtheid. Details staan in
`MDs/wintertellingen_pilot.md`.

### Ruwe tellingen

De bestaande wintergrafiek blijft beschikbaar en toont per gekozen vogel een
lijn met één punt per winterperiode. Deze som is uitsluitend beschrijvend en is
geen gestandaardiseerde trend of dichtheid.

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
