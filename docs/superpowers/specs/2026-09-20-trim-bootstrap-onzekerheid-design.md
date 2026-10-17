# Ontwerp: formele onzekerheid voor TRIM-trends en MSI-groepen

**Datum:** 17 oktober 2026

**Status:** geactualiseerd ontwerp ter inhoudelijke review

**Leidende repository:** `Meijendel`

**Rekenpakket:** `rtrim` 2.3.1

## 1. Doel en besluit

De actuele Meijendel-broedvogelreeks bevat waarnemingen over 1958–2025. De bestaande
analyse past per soort afzonderlijke TRIM-modellen voor 1958–1983 en 1984–2025,
verbindt beide indexreeksen met een geschatte brugfactor en berekent daarna
soort- en groepstrends. De jaarindices bevatten standaardfouten, maar de huidige
samengevatte trends gebruiken een gewone regressie op geschatte indices en
propageren de model-, brug- en groepsonzekerheid niet volledig.

Het vastgestelde besluit is:

- de afzonderlijke TRIM-perioden 1958–1983 en 1984–2025 blijven de primaire
  soortresultaten;
- deze soorttrends worden berekend met `rtrim::overall(..., which = "imputed")`
  en krijgen trendschatting, standaardfout, 95%-betrouwbaarheidsinterval en
  p-waarde uit de volledige TRIM-variantie-covariantiematrix;
- de gebrugde soorttrend 1958–2025 wordt als aanvullende formele trend
  gepubliceerd, met onzekerheid uit een volledige gestratificeerde
  clusterbootstrap;
- ecologische en functionele MSI-groepen krijgen bootstraponzekerheid uit
  dezelfde plottrekkingen als de soorten;
- de eerste productierun gebruikt minimaal 2.000 replicaties;
- de berekening wordt vooraf uitgevoerd en niet interactief in website,
  dashboard of Shiny;
- ontwikkeling, tests en de pilot gebruiken de bronset 1958–2025; de eerste
  definitieve productierun wacht op de complete en gevalideerde cijfers van
  broedseizoen 2026 en bestrijkt dan 1958–2026;
- de berekening wordt normaal jaarlijks herhaald en daarnaast na relevante
  bron-, selectie-, methode-, code- of packagewijzigingen.

## 2. Gegevensbasis en reikwijdte

De op 7 oktober 2026 herberekende gevolgde uitvoer op de lokale bronset
1958–2025 omvat:

- 53 plots met oppervlaktejaren in de analysebasis, waarvan 52 in 1958–2025
  ten minste eenmaal als geteld voorkomen;
- 3.053 plot-jaarregels in de analysebasis;
- 156 soorten met ten minste één geaccepteerd positief territorium binnen de
  analysescope;
- 135 soorten met ten minste één bruikbare TRIM-indexreeks;
- 93 soorten met een brugbare tijdreeks in beide modelperioden;
- 18 ecologische groepstrendregels: negen groepen maal `volledig` en `robuust`;
- 24 functionele groepstrendregels: zes groepen maal `binair` en `gewogen`,
  telkens voor `volledig` en `robuust`.

De 93 soorten met een brugbare tijdreeks vormen de kandidaatpopulatie voor
formele trends over 1958–2025 en voor de primaire robuuste groeps-MSI's.
Een soort krijgt alleen een formele gecombineerde trend wanneer ook de
gemeenschappelijke-plotbrug voor die soort geldig kan worden geschat.
De bestaande volledige groepsvarianten blijven beschikbaar als
gevoeligheidsanalyse; daarin kan de soortensamenstelling per jaar wisselen.
Na opname van 2026 worden deze aantallen en de vaste primaire populatie opnieuw
bepaald voordat de productierun start.

De Sandra-reeks omvat 110 geselecteerde soorten over 1997–2022. Deze reeks
heeft geen breuk in 1984 en gebruikt voor soorttrends rechtstreeks
`rtrim::overall()`. Groepsonzekerheid in deze reeks wordt wel met een
clusterbootstrap berekend.

### 2.1 Audit van de brugperiode

De levende lokale MySQL-database is op 17 oktober 2026 uitsluitend-lezen
gecontroleerd met dezelfde Natura 2000-, oppervlakte- en geteld-poort als de
TRIM-analyse. Voor 1978–1990 zijn per jaar de volgende aantallen getelde plots,
unieke tellers, BMP-bezoeken en soorten met een positieve territoriumwaarde
vastgesteld:

| Jaar | Getelde plots | Tellers | BMP-bezoeken | Positieve soorten |
|---:|---:|---:|---:|---:|
| 1978 | 38 | 32 | 0 | 85 |
| 1979 | 38 | 30 | 0 | 84 |
| 1980 | 38 | 30 | 0 | 81 |
| 1981 | 43 | 34 | 0 | 81 |
| 1982 | 39 | 32 | 0 | 80 |
| 1983 | 40 | 33 | 0 | 93 |
| 1984 | 23 | 13 | 230 | 91 |
| 1985 | 29 | 15 | 312 | 86 |
| 1986 | 30 | 18 | 290 | 88 |
| 1987 | 35 | 22 | 317 | 86 |
| 1988 | 24 | 21 | 246 | 90 |
| 1989 | 25 | 20 | 268 | 89 |
| 1990 | 32 | 24 | 285 | 98 |

Het venster 1981–1983 bevat 43 unieke getelde plots en 39 plots die in alle
drie jaren zijn geteld. Het kandidaatvenster 1986–1988 bevat 37 unieke getelde
plots en 21 plots die in alle drie jaren zijn geteld. Tussen beide vensters
komen 33 plots in ten minste één jaar van ieder venster voor; 20 plots zijn in
alle zes ankerjaren geteld.

De telling over 1981–1983 had dus een brede gebiedsdekking, maar niet ieder
jaar exact dezelfde huidige analyseplots. De jaren 1984 en 1985 zijn feitelijke
overgangsjaren naar de nieuwe methodiek met een sterk gereduceerd tellerbestand.
Zij zijn daarom niet geschikt als primaire kalibratiejaren. Aansluitende
kalenderjaren zijn geen eis; een stabiele methode en een vergelijkbare
ruimtelijke doelpopulatie wegen zwaarder.

Drie routes zijn beoordeeld. De bestaande aansluitende continuiteitsbrug
1981–1983 naar 1984–1986 valt af als hoofdroute omdat twee van de drie
postjaren overgangsjaren zijn. Een niet-aansluitende continuiteitsbrug naar
1986–1988 valt af als hoofdroute omdat zij opnieuw zonder gegevens aanneemt dat
het gemiddelde populatieniveau gelijk bleef. De gekozen route gebruikt daarom
1986–1988 én schat de niveauverandering empirisch op een gemeenschappelijke
plotdoelset. Zij is nog steeds conditioneel op de niet-parallelle methoden,
maar legt geen kunstmatige continuïteit op.

## 3. Te schatten grootheden

### 3.1 Afzonderlijke soortperioden

Per soort en periode wordt de multiplicatieve helling uit
`rtrim::overall(fit, which = "imputed")` gebruikt. De publicatie-eenheid is
procent verandering per jaar:

`100 * (multiplicatieve_helling - 1)`.

De standaardfout wordt met de delta-transformatie naar dezelfde eenheid
omgezet. Het 95%-interval en de p-waarde volgen de door `overall()` gebruikte
TRIM-covariantiematrix. De oorspronkelijke-datafit blijft altijd de
puntschatting; een bootstrapgemiddelde vervangt die niet.

### 3.2 Gecombineerde soorttrend 1958–2025

Deze grootheid wordt alleen berekend voor soorten met een geslaagd model in
beide perioden en een geldige gemeenschappelijke-plotbrug. De huidige
brugdefinitie stelt het gemiddelde niveau 1984–1986 impliciet gelijk aan het
gemiddelde niveau 1981–1983. Daarmee wordt werkelijke populatieverandering
rond de methodebreuk zonder empirische onderbouwing weggekalibreerd. Deze
definitie vervalt voor de formele gecombineerde trend.

De nieuwe primaire brug gebruikt:

- 1981–1983 als laatste driejarige venster van de oorspronkelijke methodiek;
- 1986–1988 als eerste driejarige venster na de overgangsjaren 1984 en 1985;
- een vaste gemeenschappelijke doelset van de 33 plots die in ten minste één
  jaar van ieder ankervenster als geteld voorkomen;
- een hulp-TRIM over de zes ankerjaren op deze gemeenschappelijke doelset, met
  imputed jaartotalen en zonder seriële-correlatiecorrectie over het kalendergat;
- een empirische niveauverhouding `R`: gemiddeld hulp-TRIM-totaal 1986–1988
  gedeeld door gemiddeld hulp-TRIM-totaal 1981–1983;
- een brugfactor `B = gemiddelde(pre_index_1981_1983) * R /
  gemiddelde(post_index_1986_1988)`;
- vermenigvuldiging van de volledige reeks vanaf 1984 met `B`;
- over de gecombineerde positieve jaarindices wordt de loglineaire helling
  berekend en omgerekend naar procent verandering per jaar.

Een hulp-TRIM gebruikt alleen de plot-jaarcellen die volgens de bestaande
observatiepoort voor de betreffende soort geldig zijn. Wanneer het model, een
ankervenster of de niveauverhouding niet geldig is, volgt geen formele
gecombineerde trend en ook geen stilzwijgende brugfactor `1`.

De jaren 1984 en 1985 blijven in het afzonderlijke TRIM-model 1984–eindjaar
wanneer hun tellingen volgens de bestaande bron- en kwaliteitsregels geldig
zijn. Zij bepalen niet langer de brugfactor.

De bootstrap levert voor deze samengestelde schatter de standaardfout, het
95%-interval en een tweezijdige empirische p-waarde. De uitkomst wordt
gepubliceerd als `gecombineerde trend via brugfactor`, niet als één doorlopend
TRIM-model.

De brug blijft structureel conditioneel: de oude en nieuwe methode zijn niet
in hetzelfde kalenderjaar parallel toegepast. Daardoor kan de empirische
niveauverhouding werkelijke populatieverandering en methodeverschil niet
volledig scheiden. De bootstrap kwantificeert de steekproef- en
modelonzekerheid binnen deze brugdefinitie, maar verwijdert dit structurele
identificatieprobleem niet.

### 3.2.1 Verplichte bruggevoeligheid

Naast de primaire brug worden uit dezelfde soortfits en bootstrapreplicaties
berekend:

- dezelfde gemeenschappelijke-plotbrug met 1987–1989 als postvenster;
- dezelfde gemeenschappelijke-plotbrug met 1988–1990 als postvenster;
- een strikte kalibratie op de 20 plots die in alle zes primaire ankerjaren
  zijn geteld;
- de huidige continuiteitsbrug 1981–1983 naar 1984–1986 uitsluitend als
  historische comparator.

Per soort en groep worden de puntschatting, intervalgrenzen en richting van
deze varianten bewaard. De primaire bootstrapuitkomst blijft een formeel
95%-interval onder de vastgelegde primaire brug. De totale minimum- en
maximumgrens over de gevoeligheidsvarianten heet uitdrukkelijk
`gevoeligheidsenvelop` en niet `betrouwbaarheidsinterval`. Wanneer de richting
of de conclusie dat het interval nul wel of niet omvat tussen verdedigbare
varianten verschilt, krijgt de publicatie status `bruggevoelig` en geen
ongekwalificeerde trendklasse.

### 3.3 Groeps-MSI's

Per replicatie worden de soortindices opnieuw geschat en daarna opnieuw tot
MSI geaggregeerd. De ecologische MSI blijft het geometrische gemiddelde van de
geldige soortindices. De functionele MSI blijft binair of met de bestaande
lidmaatschapsgewichten gewogen.

Voor de robuuste hoofdvariant liggen soortselectie en groepslidmaatschap vast
op basis van de oorspronkelijke-datafit. Een afzonderlijke
gevoeligheidsanalyse laat modeluitval en de volledige, wisselende
soortensamenstelling doorwerken. Zo blijven onzekerheid van de schatter en
onzekerheid van de indicatorafbakening van elkaar te onderscheiden.

In de robuuste hoofdvariant wordt een groepsreplicatie ongeldig wanneer een
vast geselecteerde groepssoort niet de voor die trend benodigde indexreeks
oplevert. De soort wordt dus niet stilzwijgend uit het geometrische gemiddelde
weggelaten. In de volledige gevoeligheidsvariant mag de samenstelling volgens
de bestaande regels per jaar en replicatie wisselen; het werkelijk gebruikte
aantal soorten wordt daarbij opgeslagen.

### 3.4 Gevoeligheid voor de historische gebiedsdekking

De analyse gebruikt in 1958–1972 alleen de historische kernplots en vanaf 1973
het bredere netwerk. De bootstrap behandelt deze vastgelegde scopekeuze als
gegeven en kan mogelijke structurele invloed van die uitbreiding daarom niet
zelf oplossen.

Naast de hoofdanalyse wordt de gecombineerde trend opnieuw berekend op een
vaste historische-kernvariant: alleen plots die tot de historische kern horen,
voor alle beschikbare jaren. Deze variant krijgt dezelfde primaire brug- en
bootstrapmethode. Het resultaat wordt als gevoeligheidsanalyse gepubliceerd,
niet als vervanging van de hoofdanalyse. Een verschil in richting of in de
conclusie of het interval nul omvat, leidt eveneens tot status
`gebiedsdekkinggevoelig` en het vervallen van een ongekwalificeerde
langetermijnklasse.

## 4. Bootstrapontwerp

### 4.1 Steekproefeenheid

De primaire cluster is de volledige geschiedenis van één onafhankelijk plot.
Voor implementatie wordt gecontroleerd of `plot_id` door 1958–2025 en, zodra
beschikbaar, 2026 heen een stabiele steekproefeenheid is. Splitsingen,
samenvoegingen of hernummeringen
worden zo nodig vastgelegd in een `bootstrap_cluster_id`. Zonder afgeronde
lineagecontrole start geen productierun.

### 4.2 Stratificatie

Clusters worden met teruglegging getrokken binnen ten minste twee vaste strata:

1. historische kernplots;
2. plots die pas in het latere volledige netwerk deelnemen.

Per stratum wordt steeds hetzelfde aantal clusters getrokken als in de
oorspronkelijke analyse. Van ieder getrokken cluster gaan alle beschikbare
jaren mee. Een cluster dat meermaals wordt getrokken krijgt per kopie een uniek
synthetisch TRIM-site-ID; anders zou TRIM de kopieën ten onrechte samenvoegen.

Als de lineagecontrole aanvullende structurele strata aantoont, worden die vóór
de pilot expliciet vastgelegd. Er worden geen jaren, jaarindices of soorten
afzonderlijk gebootstrapt.

### 4.3 Gemeenschappelijke trekking

Iedere bootstrapreplicatie gebruikt één gemeenschappelijke trekking voor alle
soorten. Daardoor blijven correlaties tussen soorten, gedeelde ontbrekende
plot-jaren en gedeelde gebiedseffecten behouden. Onafhankelijke
soortbootstraps zijn voor groeps-MSI's niet toegestaan.

De vaste primaire kalibratieset van 33 plots en de strikte set van 20 plots
worden uit de oorspronkelijke-datafit bepaald en veranderen niet per
replicatie. Hun multipliciteiten volgen wel exact de gemeenschappelijke
clustertrekking van die replicatie. Een meermalen getrokken kalibratieplot
krijgt dus dezelfde synthetische kopieën in hoofdmodel, hulp-TRIM, soorttrend
en groeps-MSI. Er komt geen afzonderlijke trekking voor de brugfactor.

### 4.4 Volledige replicatieketen

Binnen iedere replicatie worden achtereenvolgens opnieuw uitgevoerd:

1. opbouw van getelde en niet-getelde plot-jaarcellen;
2. oppervlaktecorrectie;
3. toepassing van de vooraf vastgelegde primaire soortselectie en de
   afzonderlijke volledige gevoeligheidsselectie;
4. TRIM 1958–1983;
5. TRIM 1984–actueel eindjaar;
6. de bestaande modelvoorkeurhiërarchie en eventuele fallback;
7. jaarindices en modelstatus;
8. hulp-TRIM en empirische gemeenschappelijke-plotbrug 1981–1983 naar
   1986–1988;
9. de drie bruggevoeligheidsvarianten en de historische comparator;
10. gecombineerde soorttrend 1958–actueel eindjaar;
11. ecologische MSI's;
12. functionele binaire en gewogen MSI's;
13. trends per periode en voor de gecombineerde reeks;
14. vaste historische-kerngevoeligheid;
15. opslag van schattingen, modelkeuze, waarschuwingen en foutstatus.

Onveranderlijke bronparsing, groepsdefinities en oorspronkelijke selecties
worden buiten de replicatielus voorbereid. Binnen de modelhiërarchie stopt de
productieberekening na het eerste geslaagde voorkeursmodel. Een afzonderlijke
diagnostische proef mag alle configuraties vergelijken, maar dat is geen
onderdeel van iedere productiereplicatie.

## 5. Intervallen, geldigheid en stabiliteit

De oorspronkelijke-datafit is de gepubliceerde puntschatting. Uit alle geldige
bootstrapreplicaties worden berekend:

- bootstrapstandaardfout: standaardafwijking van de replicatieschattingen;
- percentile-interval: 2,5e en 97,5e percentiel;
- BCa-interval, met clusterjackknife voor de acceleratie;
- tweezijdige empirische p-waarde ten opzichte van nul procent per jaar;
- aantal geldige en mislukte replicaties;
- verdeling van gekozen modelconfiguraties en fallbacks.

Het BCa-interval is primair wanneer alle benodigde jackknifeschattingen en
BCa-correcties eindig en stabiel zijn. Anders wordt het percentile-interval
gepubliceerd met de methodecode `percentile_fallback` en een diagnostische
reden.

De tweezijdige empirische p-waarde gebruikt de eindige-steekproefcorrectie
`2 * min((1 + aantal schattingen <= 0) / (B_geldig + 1),
(1 + aantal schattingen >= 0) / (B_geldig + 1))`, begrensd op 1.

Een formeel interval wordt alleen gepubliceerd wanneer ten minste 95% van de
geplande replicaties voor die specifieke schatter geldig is. Bij minder dan
95% krijgt de uitkomst status `onvoldoende_bootstrap` en wordt geen formele
onzekerheidsclaim gedaan.

De eerste productierun omvat minimaal 2.000 replicaties. Na iedere volgende
batch van 500 wordt de stabiliteit beoordeeld. De run stopt bij minimaal 2.000
replicaties wanneer beide intervalgrenzen ten opzichte van de vorige cumulatieve
batch minder veranderen dan zowel 0,10 procentpunt per jaar als 5% van de
intervalbreedte. Zo niet, dan wordt doorgegaan tot maximaal 5.000 replicaties.
Het bereiken van 5.000 zonder stabiliteit levert status
`interval_niet_gestabiliseerd` op.

## 6. Reproduceerbaarheid en uitvoering

Iedere run heeft een onveranderlijk run-ID en legt minimaal vast:

- SHA-256 van de gebruikte `meijendel.sql`;
- Git-commit;
- R-versie;
- `rtrim`-versie;
- bootstrapseed;
- aantal geplande, uitgevoerde en geldige replicaties;
- strata en aantallen clusters;
- analyseperiode en brugvensters;
- vaste soort- en groepsselecties;
- start- en eindtijd;
- seconden per replicatie;
- piekgeheugen en waargenomen swap;
- uitvoerchecksums.

Replicaties draaien in genummerde, atomair opgeslagen batches en kunnen na een
onderbreking worden hervat. De standaard op de iMac M1 met 8 GB is één worker.
Twee workers worden pas toegestaan wanneer de pilot aantoont dat gezamenlijk
geheugengebruik inclusief macOS ruim onder 8 GB blijft en geen swap optreedt.

De verplichte pilot omvat 50 replicaties. De productierun start pas nadat de
pilot tijd, piekgeheugen, swap, modeluitval en hervatten na onderbreking correct
rapporteert. Een validatierun van 500 replicaties controleert daarna
reproduceerbaarheid, intervalberekening en modeluitval.

### 6.1 Optionele NAS- en VPS-workers

De iMac blijft de coördinator en de lokale 1-workeruitvoering blijft de
referentie. De Synology-NAS en productie-VPS kunnen na een geslaagde
capaciteits- en gelijkheidsproef én afzonderlijk expliciet akkoord als
optionele batchworkers worden ingezet. Zij staan standaard uitgeschakeld. De
volledige productierun moet zonder NAS of VPS lokaal uitvoerbaar blijven. Zij
vormen geen permanent cluster en schrijven nooit rechtstreeks naar de
canonieke publicatie-output. Normaal functioneren van NAS en VPS heeft altijd
voorrang boven verkorting van de rekentijd.

De coördinator maakt per run één onveranderlijk invoerpakket met SQL-hash,
codecommit, configuratiehash, software- of containerimage-ID, seed en vaste
replicatienummers. Een batch heeft een uniek, niet-overlappend bereik van
replicatienummers. De replicatieseed wordt uitsluitend uit run-ID en
replicatienummer afgeleid, zodat uitkomsten niet afhangen van worker,
batchvolgorde of parallelisme.

Iedere worker:

- controleert pakket- en configuratiehash vóór de start;
- werkt in een eigen niet-publieke runmap;
- verwerkt uitsluitend het toegewezen replicatiebereik;
- schrijft eerst een tijdelijk resultaat en hernoemt dat pas na volledige
  afronding atomair;
- levert resultaatchecksum, runtime, piekgeheugen, swap, foutstatus en
  software-identiteit terug;
- kan geen bestaande batch of publicatie-output overschrijven.

De iMac accepteert alleen complete batches met exact hetzelfde run-ID,
bronhash, configuratiehash, codecommit en software-ID. Ontbrekende,
overlappende, dubbele of afwijkende replicatienummers blokkeren de merge.
Een lokale en een externe proefbatch met dezelfde replicatienummers moeten
bitgelijk zijn voor discrete velden en numeriek gelijk binnen `1e-8` voor
drijvende-kommagetallen.

De NAS is primair checkpoint- en archiefopslag. Rekenen op de NAS wordt alleen
geactiveerd wanneer een read-only capaciteitstest bevestigt dat architectuur,
containerondersteuning, vrije opslag, vrij geheugen en actuele systeembelasting
voldoen en de gebruiker daarna afzonderlijk akkoord geeft. De worker gebruikt
maximaal één laaggeprioriteerd rekenproces en pauzeert vóór de volgende
replicatie tijdens back-up, RAID-scrub, SMART-test of andere zware
opslagtaken. Als rekenen niet aantoonbaar zonder invloed kan, blijft de NAS
uitsluitend checkpoint- en archiefopslag.

De productie-VPS gebruikt nooit het actieve Shiny- of MySQL-containerproces.
Een bootstrapbatch draait uitsluitend in een aparte tijdelijke container op
hetzelfde gepinde R/package-image, met read-only invoer, aparte uitvoermap,
CPU-, geheugen-, swap- en proceslimieten en lage CPU/I/O-prioriteit. Voor iedere
batch controleert de worker dat:

- geen globale productiedeploylock actief is;
- Shiny en MySQL gezond zijn;
- voldoende geheugen bovenop de productie-reserve beschikbaar is;
- geen swapgroei, hoge load of onvoldoende schijfruimte aanwezig is.

De geheugenlimiet is minimaal 125% van het gemeten workerpiekgebruik; daarnaast
blijft op NAS ten minste 1 GB en op de VPS ten minste 2 GB vrij voor bestaande
diensten. CPU-gebruik van een externe worker is standaard begrensd op maximaal
0,5 CPU en krijgt lage CPU- en I/O-prioriteit. Vóór iedere replicatie worden
load, vrij geheugen, swap, schijfruimte en relevante servicestatus opnieuw
gecontroleerd. Na iedere replicatie wordt op swapgroei en verslechterde
servicehealth gecontroleerd. Zodra een grens wordt overschreden, start geen
nieuwe replicatie. De VPS-bootstraplock is gescheiden van de deploylock; hij
staat onder `/srv/vwgm/bootstrap`, niet in de productiestaatmap, en voorkomt
dubbele bootstrapworkers zonder een deploy te blokkeren. De worker leest de
bestaande productiedeploylock uitsluitend en wijzigt geen deployscript of
productieguard. Een deploy heeft altijd voorrang en verhindert de start van de
volgende replicatie.

Activering van een externe worker vereist een afzonderlijke read-only
capaciteitsrapportage met nulmeting en proefreplicatie. Zonder expliciet akkoord
op die rapportage blijft `enabled = false`. Veiligheidsgrenzen mogen niet worden
versoepeld om de productierun sneller af te ronden.

Workerhosts, paden en activering staan in een lokaal, niet-versiebeheerd
workerconfiguratiebestand. Sleutels, wachtwoorden en NAS- of VPS-credentials
komen niet in Git, runmanifesten of logbestanden.

## 7. Opslag en database

De bestaande MySQL-brontabellen worden niet aangepast voor berekeningsoutput.
Alleen wanneer `plot_id` geen stabiele onafhankelijke geschiedenis blijkt,
wordt een expliciete en auditeerbare plotlineagetabel of
`bootstrap_cluster_id` toegevoegd.

Ruwe replicaties worden gecomprimeerd buiten de publieke webroot opgeslagen en
niet als miljoenen MySQL-rijen of losse CSV-bestanden opgenomen. Git bevat de
compacte publicatieproducten, het runmanifest en de noodzakelijke diagnostiek,
niet de volledige tijdelijke rekenstaat.

Nieuwe compacte uitvoercontracten zijn:

- `trim/soorten/soorten_trends_met_onzekerheid.csv`;
- `trim/soorten/soorten_brugfactoren_met_onzekerheid.csv`;
- `trim/soorten/brugvenstergevoeligheid.csv`;
- `trim/soorten/historische_kerngevoeligheid.csv`;
- `trim_msi_evg/groepstrends_met_onzekerheid.csv`;
- `trim_msi_evg/functionele_groepstrends_met_onzekerheid.csv`;
- overeenkomstige bestanden onder `trim/sandra/`;
- `trim/bootstrap/run_manifest.json`;
- `trim/bootstrap/diagnostiek.csv`.

Trendbestanden bevatten minimaal:

- entiteitstype en entiteit-ID;
- periode;
- methode;
- puntschatting in procent per jaar;
- standaardfout;
- onder- en bovengrens 95%;
- p-waarde;
- intervalmethode;
- geplande en geldige replicaties;
- geldig percentage;
- publicatiestatus;
- run-ID.

De bestaande uitvoerbestanden blijven gedurende de migratie beschikbaar. De
nieuwe kolommen of bestanden worden pas leidend nadat alle consumenten en
pariteitstests zijn aangepast.

## 8. Website, dashboard en Shiny

### Website en dashboard

Per soort worden in deze volgorde getoond:

1. primaire trend 1958–1983 met TRIM-standaardfout en 95%-interval;
2. primaire trend 1984–actueel eindjaar met TRIM-standaardfout en 95%-interval;
3. aanvullende gecombineerde trend 1958–actueel eindjaar met bootstrapinterval.

Bij de gecombineerde trend staat steeds: `Gecombineerde trend via een geschatte
gemeenschappelijke-plotbrug van 1981–1983 naar 1986–1988; geen enkel doorlopend
TRIM-model.` De presentatie toont daarnaast intervalmethode, aantal geldige
replicaties, rekendatum en eventuele status `bruggevoelig` of
`gebiedsdekkinggevoelig`. Groeps-MSI's tonen de robuuste variant primair en de
volledige variant als gevoeligheidsanalyse.

### Shiny

De standaardanalyse leest dezelfde vooraf berekende publicatieproducten als het
dashboard. Een door de gebruiker gewijzigde selectie van plots, jaren of
soorten krijgt geen interval uit de standaardrun en wordt aangeduid als
`verkennende selectie; geen formeel bootstrapinterval`.

De eerste implementatiefase bevat geen wachtrij voor maatwerkbootstraps. De
volledige bootstrap wordt nooit binnen een interactieve Shiny-request gestart.

## 9. Actualisatiebeleid

Een nieuwe productierun is vereist:

- na toevoeging van een nieuw definitief broedseizoen;
- na correctie van territoria, getelde/niet-getelde status of oppervlakte;
- na wijziging van plotlineages of strata;
- na wijziging van soortselectie of groepslidmaatschap;
- na wijziging van modelhiërarchie, brugvenster of trendschatter;
- na relevante wijziging van R, `rtrim` of analysecode.

De eerstvolgende definitieve productierun wordt pas gestart nadat de cijfers
over broedseizoen 2026 compleet zijn opgenomen, de bron- en kwaliteitscontroles
zijn geslaagd en de vaste soort- en groepsselecties opnieuw zijn vastgelegd.
Voor die run worden periodelabels 1958–1983, 1984–2026 en 1958–2026 gebruikt.

Bij identieke bronhash, code, configuratie en softwareversies wordt de bestaande
run hergebruikt. Er is geen continue of kalendergestuurde herberekening zonder
gewijzigde invoer.

## 10. Verificatie en acceptatie

Voor vrijgave moeten minimaal slagen:

- unit-tests voor gestratificeerde trekking, synthetische site-ID's,
  reproduceerbare seed, brugfactor en intervalberekening;
- een kleine synthetische dataset waarvan richting en orde van de trend bekend
  zijn;
- test dat alle soorten binnen een replicatie dezelfde clustertrekking gebruiken;
- test dat de vaste robuuste soort- en groepsselectie niet per replicatie wijzigt;
- test van foutregistratie bij onvoldoende positieve jaren of actieve plots;
- hervattest na een bewust onderbroken batch;
- vergelijking van 1-workerresultaten met een eventueel toegestane 2-workerrun;
- schema- en inhoudscontroles van alle uitvoerbestanden;
- Shiny/dashboard- en dashboard/website-pariteit;
- projectpreflight vóór en na de wijziging.

De levende lokale MySQL-database is de canonieke schrijfbron. Een dump en alle
TRIM-, dashboard- en Shiny-uitvoer moeten aantoonbaar uit dezelfde vastgelegde
bronstand komen. De op 7 oktober 2026 gevolgde uitvoer over 1958–2025 vormt de
ontwikkelbaseline voor schema en bestaande resultaten. Voor de definitieve
productierun na opname van 2026 worden dump en alle afgeleide producten opnieuw
uit de gevalideerde levende database opgebouwd; hergebruik van een oudere dump
is niet toegestaan.

## 11. Niet in deze eerste implementatie

- interactieve bootstrapberekeningen in Shiny;
- een permanent cluster of automatische activering van NAS/VPS zonder groene
  capaciteitstest en expliciete workerconfiguratie;
- opslag van iedere replicatie in MySQL;
- causale interpretatie van trends;
- gelijktijdige onzekerheidsbanden over alle jaren van iedere indexgrafiek.
