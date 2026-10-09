# Analyse op hoofdlijnen en uitkomsten

**Stand:** 9 oktober 2026

**Status:** stappen 1 en 2 uitgevoerd: reproduceerbare analysematrix en
tellergevoeligheidsanalyse; voorspellend ecologisch model en formele
poweranalyse nog niet uitgevoerd

**Beoogd eindproduct:** artikel voor *Holland's Duinen*

## Doel

De lange broedvogelreeks laat zien hoe aantallen en soortensamenstelling in
Meijendel zijn veranderd. Deze analyse stelt een volgende vraag: in hoeverre
hangen die veranderingen samen met vegetatie en andere biotische en abiotische
omstandigheden, hoeveel daarvan wordt beïnvloed door verschillen tussen
tellers en hoe gevoelig is de meetopzet voor zulke relaties en veranderingen?

Het doel is niet zoveel mogelijk variabelen in één model te plaatsen. We bouwen
een controleerbare reeks modellen. Eerst het waarnemingsproces. Daarna de
ecologische verklaringen. Vervolgens toetsen we of deze buiten de gebruikte
gegevens blijven voorspellen. Pas daarna volgt de poweranalyse.

Een statistische samenhang is niet automatisch een een-op-een-oorzaak-gevolg-
relatie. Vegetatie, voedsel, water, bodem, weer, beheer, begrazing, predatie,
verstuiving en rust kunnen tegelijk werken en elkaar versterken of verzwakken.

## Onderzoeksvragen

1. Hoe verandert de broedvogelgemeenschap door de tijd en tussen plots?
2. Hoeveel van die verschillen hangt samen met de gemeten PQ-vegetatie?
3. Voegt PQ-vegetatie voorspellende informatie toe boven tijd, plot,
   oppervlakte, methode, telinspanning, teller en weer?
4. Reageren functionele, habitatgebonden en andere ecologische vogelgroepen
   verschillend?
5. Verandert de functionele samenstelling van de gemeenschap, bijvoorbeeld het
   aandeel grondbroeders, holenbroeders, insecteneters of
   langeafstandstrekkers?
6. Hoeveel extra voorspellende informatie leveren stikstof, landgebruik en
   ruimtelijke kenmerken?
7. Welke relaties of veranderingen konden de historische gegevens aantonen en
   hoeveel toekomstige meetjaren zijn nodig om vooraf gekozen veranderingen
   betrouwbaar te detecteren?

## Gegevensbasis bij aanvang

De stand hieronder is een startmoment, geen vast eindtotaal. Iedere formele
modeluitvoering herhaalt de tellingen uit de levende database en legt de
uitkomst in een uitvoermanifest vast.

### Broedvogels

De standaard Natura 2000-selectie uit `territoria` bevat op 9 oktober 2026
151.583 bronregels in 52 plots en 2.107 getelde plotjaren uit 1958–2025. Binnen
deze selectie zijn 156 soorten ten minste eenmaal met een positief territorium
vastgesteld. M66 en M91 blijven buiten deze selectie.

De analyse gebruikt de centrale territoriumpoort. Letterlijke SOVON-nullen uit
1984–2025 blijven nul; lege SOVON-cellen blijven `NA`; formeel afgekeurde
SOVON-plotjaren leveren geen SOVON-analysewaarde. Voor geldige
jaarverslag-plotjaren geldt de afzonderlijk vastgelegde regel voor afgeleide
jaarverslagnullen. De bron en nulstatus blijven per analysewaarde herleidbaar.

### PQ-vegetatie

De provinciale PQ-verzameling omvat 254 PQ's, 2.007 vegetatieopnamen en 53.122
taxonregels uit 1981–2025. Na koppeling aan de standaard vogelplots zijn 501
PQ-plotjaren in 35 plots beschikbaar. De bruto overlap met getelde
vogelplotjaren bedraagt 407 combinaties in hetzelfde jaar, 392 bij één jaar
vertraging, 372 bij twee jaar en 350 bij drie jaar.

De provinciale `pq_*`-reeks is leidend. NDFF-PQ is uitsluitend een secundaire
controlebron en telt niet zelfstandig mee. De velden voor milieu-indicatie en
afwijkende bodemcodes worden pas gebruikt nadat hun betekenis en kwaliteit uit
de bronmetadata zijn vastgesteld.

### Overige verklarende lagen

- `weer` bevat 24.837 dagrecords uit 1953–2026. Het lopende jaar 2026 is
  onvolledig en wordt niet als volledig analysejaar behandeld.
- `plot_jaar_stikstof` bevat 1.027 plotjaren in 55 plots uit 2005–2023.
- `plot_jaar_landgebruik` bevat 918 klasseregels voor 275 plotjaren in 55
  plots uit 1996–2022. Dit zijn kaartmomenten, geen jaarlijkse metingen.
- `plot_jaar_habitat` bevat 384 habitatregels voor 55 plots, uitsluitend voor
  2014.
- `plot_jaar_ahn_dtm` bevat 55 plotregels voor 2025.
- `plot_jaar_infra` bevat 220 waarden voor 55 plots, uitsluitend voor 2024.
- `plot_jaar_toegankelijkheid` bevat 55 plotregels voor 2024.
- `plot_jaar_maatregel` bevat 144 registraties in 16 plots uit 1991–1999,
  uitsluitend begrazing. Dit is geen gebiedsdekkende beheerreeks.

Deze aantallen beschrijven de volledige brontabellen. Bij modelbouw wordt
opnieuw de standaard Natura 2000-scope toegepast, zodat records voor M66 en
M91 niet stilzwijgend in de analyse terechtkomen.

Habitat, hoogte, infrastructuur en toegankelijkheid kunnen voorlopig alleen
blijvende ruimtelijke verschillen tussen plots helpen verklaren. Met één
peiljaar kunnen zij geen verandering binnen een plot verklaren.

De aantallen en bronbeperkingen in deze startstand zijn ontleend aan de levende
database op 9 oktober 2026 en getoetst aan
[`docs/MEIJENDEL_BRONREGISTER.md`](../../docs/MEIJENDEL_BRONREGISTER.md),
[`DECISIONS.md`](../../DECISIONS.md) en de selectie- en nulregels in
[`R/meijendel_cache_contract.R`](../../R/meijendel_cache_contract.R).

## Uitkomsten die worden onderzocht

### Soorten

De primaire respons is het territoriumaantal per soort, plot en jaar. Soorten
delen in een hiërarchisch model informatie, maar mogen verschillend reageren.
Soortspecifieke uitkomsten worden alleen afzonderlijk gepubliceerd wanneer de
gegevens daarvoor voldoende zijn.

### Gehele gemeenschap

We onderzoeken ten minste soortensamenstelling, soortenrijkdom en totale
territoriumdichtheid. Een multivariate gemeenschapsuitkomst en een opgetelde
dichtheid beantwoorden verschillende vragen en blijven daarom gescheiden.

### Functionele groepen

De levende database bevat zes goedgekeurde functionele groepen. Binnen de 156
positief vastgestelde soorten uit de standaardscope zijn bij aanvang gekoppeld:

| Groep | Primair | Secundair | Geselecteerd | Gewogen omvang |
|---|---:|---:|---:|---:|
| Bodemfoeragerende insecteneters | 35 | 40 | 75 | 55,0 |
| Grondbroeders | 62 | 7 | 69 | 65,5 |
| Holenbroeders | 38 | 1 | 39 | 38,5 |
| Langeafstandstrekkers | 42 | 4 | 46 | 44,0 |
| Luchtfoerageerders | 8 | 7 | 15 | 11,5 |
| Zaadeters | 28 | 33 | 61 | 44,5 |

We rapporteren een strikte variant met primaire leden en een inclusieve of
gewogen variant met secundaire leden. Vooral de kleinere groep
luchtfoerageerders vraagt een gevoeligheidsanalyse.

### Habitat- en ecologische groepen

De database bevat 51 deels geneste EVG-landschapsgroepen. De hoofdanalyse
begint met acht brede groepen: water-, riet-, pionier-, open-heide-, weide-,
struweel-, bosrand- en bosvogels. Kleinere groepen worden alleen vooraf en op
ecologische gronden gekozen. We zoeken dus niet achteraf tussen 51 uitkomsten
naar toevallige significantie.

Daarnaast zijn 72 van de 156 positief vastgestelde soorten aan acht Natura
2000-habitattypen gekoppeld. Hiervoor worden twee vooraf vastgelegde varianten
gebruikt: alleen sterke bindingen en sterke plus matige bindingen.

Soorten kunnen in verschillende groepen voorkomen. Groepsuitkomsten zijn dus
niet onafhankelijk en worden niet behandeld als 51 losse, onderling
vergelijkbare toetsen.

### Continue functionele kenmerken

De database bevat 23 goedgekeurde vogelkenmerken. Zestien daarvan zijn bij
aanvang voor alle 156 positief vastgestelde soorten gevuld. Naast vaste groepen
berekenen we daarom per plotjaar onder meer het gewogen aandeel
grondbroeders, holenbroeders, insecteneters, zaadeters en
langeafstandstrekkers en, waar verantwoord, de gemiddelde nesthoogte en wijze
van foerageren.

Deze continue kenmerken benutten verschillen tussen soorten zonder voor ieder
kenmerk een harde groepsgrens te moeten kiezen.

## Modelopbouw

### 1. Reproduceerbare analysematrix

De soort–plot–jaar-matrix wordt rechtstreeks uit de levende database gebouwd.
De analyse neemt de centrale Natura 2000-scope, bronstatus, nulregels en
formele afkeur over. Iedere waarde behoudt bron en nulstatus. Een groepswaarde
wordt alleen berekend wanneer voor alle samenstellende soorten een geldige
analysewaarde beschikbaar is; een gedeeltelijke som blijft `NA`.

Deze stap is op 9 oktober 2026 uitgevoerd. De standaardmatrix bevat 328.692
soort–plot–jaarcellen: 156 soorten maal 2.107 werkelijk in `territoria`
aanwezige plotjaren in 52 Natura 2000-plots, over 1958–2025. De 123
plotjaarcombinaties die alleen in `plot_jaar_teller` staan, creëren nadrukkelijk
geen analysejaar.

Van de 328.692 cellen hebben 68.504 een positief territoriumaantal. Er zijn
142.802 geldige nullen: 76.686 letterlijk door de bron geleverde nullen en
66.116 volgens de vastgelegde jaarverslagregel afgeleide nullen. Voor 117.120
cellen ontbreekt een soortregel en 266 cellen behouden de status
`formeel_afgekeurd`; deze 117.386 cellen krijgen geen modelwaarde. De vijf
M35-plotjaren met een afgekeurde SOVON-status bevatten daarnaast zelfstandige
geldige jaarverslag- of meeuwenliteratuurwaarden. Die blijven volgens de
brongebonden regel bruikbaar en herkenbaar.

Voor 2.007 van de 2.107 territorium-plotjaren is minstens één teller
geregistreerd; voor 100 niet. M62/2016, de afzonderlijke roofvogeltelling, is
voor de algemene vogelmatrix als bronwaarde behouden. Bij de volgende stap,
de analyse van teller en tellerervaring, wordt deze combinatie overeenkomstig
het bestaande besluit uitgesloten. Dan resteren 99 plotjaren zonder
tellerregistratie.

De volledige matrix staat lokaal, buiten Git, in de uitvoermap
`resultaten/runs/`. De compacte actuele samenvatting en het controlemanifest
staan in `resultaten/analysematrix_laatste_samenvatting.csv` en
`resultaten/analysematrix_laatste_manifest.json`.

### 2. Waarnemingsmodel

Het eerste model bevat tijd, plot, plotoppervlakte, methodeperiode en, voor
zover werkelijk beschikbaar, telinspanning. Daarna worden teller of tellerteam
en tellerervaring toegevoegd. Ervaring wordt als doorlopende variabele
behandeld: eerdere teljaren in totaal en eerdere teljaren in de betreffende
plot. Het eerste geregistreerde jaar hoeft niet het werkelijke eerste teljaar
van de teller te zijn; die begrenzing blijft zichtbaar.

De vergelijking zonder en met teller bepaalt niet of tellerinformatie mag
worden weggeselecteerd. Zij laat zien hoeveel teller en ervaring veranderen aan
de geschatte relaties, onzekerheid en resterende variatie.

De opzet van deze stap is op 9 oktober 2026 vastgesteld in
[`ONTWERP_TELLER_EN_ERVARINGSMODEL.md`](ONTWERP_TELLER_EN_ERVARINGSMODEL.md).
Het hoofdmodel wordt hiërarchisch en negatief-binomiaal; GEE dient als
controle. Ervaring wordt zonder vaste grens afgeleid uit eerdere geregistreerde
teljaren in dezelfde plot en eerdere geregistreerde teljaren elders. De
formele uitvoering van 9 oktober 2026 gebruikt 203.628 soort–plot–jaarrijen uit
2.007 plotjaren met bekende teller over 1958–2025. Alle achttien gezamenlijke
M0–M2-fits slaagden met een positieve Hessiaan en zonder
convergentiewaarschuwing; per vergelijking was de responsrijhash gelijk.

In de primaire lange reeks bedroeg de geschatte standaardafwijking tussen
tellerteams op logschaal 0,382, ofwel een factor 1,47 per standaardafwijking.
Dit is spreiding die na correctie voor de modelstructuur met tellerteam
samenhangt. Zij is geen ranglijst van tellers en bewijst niet dat vogels zijn
gemist.

De gezamenlijke coëfficiënt voor eerdere geregistreerde ervaring in dezelfde
plot was 0,008 per gestandaardiseerde eenheid (standaardfout 0,018); deze
uitkomst onderscheidt zich niet duidelijk van nul. Voor geregistreerde
ervaring elders was de coëfficiënt 0,066 (standaardfout 0,017). Omgerekend
komt dit laatste verband neer op verwachte telverhoudingen van 1,042, 1,086 en
1,112 bij respectievelijk één, drie en vijf eerdere geregistreerde teljaren
elders ten opzichte van nul. Minimum- en maximumervaring binnen tellerteams
gaven vrijwel hetzelfde patroon. Ook de analyse van uitsluitend 1.804
één-teller-plotjaren hield dit patroon in stand.

De telinspanninganalyse gebruikt 120.731 soort–plot–jaarrijen over 1984–2025.
Met zowel totale bezoekduur als aantal bezoeken bleef het verband met ervaring
elders positief. In deze kortere populatie was ook het verband met ervaring in
dezelfde plot positief. Dat verschil met de lange reeks kan zowel door
telinspanning als door periode en gegevenssamenstelling ontstaan en wordt niet
als afzonderlijk leereffect uitgelegd. De één-telleranalyse leverde 117
bruikbare soortuitkomsten uit 118 kandidaten; de analyses met bezoekduur en
aantal bezoeken respectievelijk 109 uit 111 en 108 uit 111. De zes overige
soortmodellen blijven als modeluitval zichtbaar.

Voor de 121 vooraf toegelaten soorten leverde de lange analyse 121 bruikbare
uitkomsten: 90 met negatief-binomiale M2 en 31 met de vooraf toegestane,
expliciet gelabelde Poisson-terugval na NB-uitval. De mediane verandering van
de geschatte jaartrend tussen M0 en M2 was −0,033 procentpunt per jaar; de
mediane absolute verandering 0,545 procentpunt. Bij 67 soorten was de absolute
verschuiving groter dan 0,5 procentpunt en bij 31 groter dan 1 procentpunt per
jaar. Deze grenzen zijn beschrijvend, geen significantieselectie. De mediane
intervalbreedte nam met factor 1,11 toe.

De streng gecontroleerde Poisson-GEE slaagde voor 105 van de 121 soorten.
Acht soorten bereikten de vooraf ingestelde grens van zestig seconden; bij
acht andere soorten meldde `geepack` een numerieke foutcode of geen volledig
eindige coëfficiënten en robuuste standaardfouten. Deze zestien soorten blijven
als modeluitval zichtbaar. Bij de 105 geslaagde controles kwam de richting van
het ervaringseffect in dezelfde plot voor 78,1% en elders voor 80,0% overeen
met het GLMM; beide richtingen tegelijk kwamen voor 62,9% overeen. GEE
bevestigt het algemene patroon dus slechts gedeeltelijk en blijft een controle,
niet het hoofdmodel.

### 3. Vegetatiemodel

PQ-kenmerken worden gesplitst in:

- het gemiddelde verschil tussen plots;
- de afwijking in een bepaald jaar binnen dezelfde plot.

Zo blijft het verschil zichtbaar tussen “bosrijke plots hebben andere vogels”
en “de vogels veranderen nadat de vegetatie binnen dezelfde plot verandert”.
Vertragingen worden vooraf beperkt tot hetzelfde jaar, één jaar en, indien
ecologisch verdedigbaar, twee of drie jaar.

### 4. Aanvullende verklarende blokken

We voegen verklarende informatie in herkenbare blokken toe:

1. weer;
2. stikstof;
3. landgebruik;
4. vaste ruimtelijke context;
5. alleen waar de dekking het toestaat: andere biotische informatie.

Een variabele wordt niet toegevoegd omdat zij toevallig in de database staat.
Koppeling, meeteenheid, periode, ontbrekende waarden en inhoudelijke betekenis
moeten eerst bij de onderzoeksvraag passen.

### 5. Groeps- en traituitkomsten

Het soortmodel is leidend. De voorspelde soortreacties en hun onzekerheid
worden daarna samengebracht voor functionele, ecologische en habitatgroepen.
Een rechtstreeks model van het groepstotaal dient als gevoeligheidsanalyse,
niet als zelfstandig bewijs wanneer het soortmodel een andere uitkomst geeft.

### 6. Voorspellende toets

Modellen worden niet alleen beoordeeld met significantie of AIC. Zij moeten
voorspellen voor gegevens die niet voor schatting zijn gebruikt:

- achtergehouden jaren toetsen voorspelling in de tijd;
- achtergehouden plots toetsen voorspelling op andere plaatsen;
- dezelfde uitsplitsing wordt gebruikt bij vergelijking van het basismodel en
  het model met PQ of andere verklarende blokken.

De toegevoegde waarde van PQ is het verschil in voorspelfout tussen modellen op
exact dezelfde gegevens, niet alleen een significante regressiecoëfficiënt.

### 7. Poweranalyse

De historische trend en de poweranalyse blijven gescheiden. De historische
analyse beschrijft wat de bestaande gegevens laten zien. De poweranalyse
simuleert daarna welke vooraf omschreven toekomstige of hypothetische
verandering met deze meetopzet aantoonbaar is.

De simulatie neemt ten minste de werkelijke plots, perioden, ontbrekende
waarden, nulregels, overdispersie, temporele samenhang en modeluitval over.
Power wordt afzonderlijk bepaald voor relevante soorten, groepen,
gemeenschapskenmerken en relaties met vegetatie. Niet-convergerende modellen
tellen niet als gedetecteerd.

## Drie analysevensters

1. **Lange vogelreeks, 1958–2025.** Beschrijving van verandering en bepaling
   van waarnemingsstructuur. Ecologische verklaringen zijn beperkt tot de
   bronnen die voor het betreffende jaar beschikbaar zijn.
2. **Kernmodel vogels–PQ, 1981–2025.** Dezelfde 35 plots vormen de basis voor
   vergelijking van modellen zonder en met PQ.
3. **Verrijkt model, in beginsel 2005–2023.** Binnen de feitelijke overlap kan
   stikstof worden toegevoegd. Landgebruik en ruimtelijke momentopnamen worden
   alleen overeenkomstig hun werkelijke meetjaren gebruikt.

Een korter model is geen vervanging van de lange vogelreeks. Het beantwoordt
een rijkere vraag over een kortere periode.

## Reproduceerbaarheid per uitvoering

Iedere formele uitvoering krijgt een eigen identificatie en legt vast:

- uitvoerdatum en Git-commit;
- databaseschema en controleerbare databasevingerafdruk;
- gebruikte tabellen, views, perioden en filters;
- aantallen regels, soorten, plots en plotjaren na iedere selectie;
- bron-, nul- en afkeurstatussen;
- groepsdefinities en traitversies;
- modelformules, pakketversies en toevalszaad;
- trainings- en validatiesplitsingen;
- convergentiewaarschuwingen en mislukte modellen;
- geproduceerde tabellen en figuren;
- gevolgen voor de conclusies en het artikel.

Een andere onderzoeker moet daarmee de analyse op hoofdlijnen kunnen herhalen
zonder afhankelijk te zijn van mondelinge toelichting. Toegang tot de levende
brondata blijft vanzelfsprekend nodig om de getallen exact te reproduceren.

## Stand van de uitkomsten

| Onderdeel | Status | Vastgestelde uitkomst |
|---|---|---|
| Bronnen en Natura 2000-scope | Vastgesteld | M66 en M91 vallen standaard buiten de plotgebonden analyse. |
| Bronafhankelijke nulregels | Geïmplementeerd | Letterlijke SOVON-nul, lege cel, afgeleide jaarverslagnul en formele afkeur blijven onderscheiden. |
| Functionele groepen | Beschikbaar | Zes goedgekeurde groepen met primaire, secundaire en gewogen koppeling. |
| Ecologische groepen | Beschikbaar | 51 EVG-groepen; hoofdanalyse begint met acht brede groepen. |
| Habitatgroepen | Beschikbaar | Acht habitattypen; analysevarianten sterk en sterk plus matig. |
| Continue vogelkenmerken | Beschikbaar | 23 goedgekeurde kenmerken; zestien gevuld voor alle 156 positieve soorten. |
| Teller- en ervaringsmodel | Uitgevoerd | Zes gezamenlijke M0–M2-vergelijkingen groen; primaire soortanalyse 121/121 bruikbaar, waarvan 31 met gelabelde Poisson-terugval; GEE 105/121 bruikbaar. Tellerteam en geregistreerde ervaring hangen samen met verschillen in geschatte uitkomsten, maar bewijzen geen gemiste vogels. |
| Voorspellend vogelmodel | Nog uit te voeren | Geen voorspellende kracht of meerwaarde van PQ vastgesteld. |
| Relaties met weer, stikstof en landgebruik | Nog uit te voeren | Beschikbaarheid is vastgesteld; effecten zijn niet geschat. |
| Poweranalyse | Nog uit te voeren | Er bestaat nog geen formeel powergetal of detectiegrens. |
| Artikel | Nog te schrijven | Alleen doel, structuur en vereiste bewijsroute zijn vastgesteld. |

## Betekenis voor het latere artikel

Het artikel wordt pas inhoudelijk afgerond nadat de ruimtelijk en temporeel
geblokkeerde validatie en de poweranalyse zijn uitgevoerd. Het moet niet alleen
melden welke relaties zijn gevonden, maar ook:

- hoeveel beter het model buiten de schattingsgegevens voorspelt;
- of een relatie vooral verschillen tussen plots of veranderingen binnen
  plots betreft;
- welke soorten of groepen een vergelijkbaar dan wel afwijkend patroon tonen;
- welke veranderingen de meetopzet niet betrouwbaar kon detecteren;
- welke gegevensbeperkingen de interpretatie begrenzen.

Bij het schrijven worden het dan geldende Natuurbeheerplan Zuid-Holland, het
Natura 2000-beheerplan Meijendel & Berkheide en de actuele beheerinvulling van
Dunea opnieuw geraadpleegd. Vastgesteld beleid, beheerambitie, feitelijke
maatregel en ecologische interpretatie blijven onderscheiden.
