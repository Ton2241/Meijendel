# Ontwikkelpilot bootstrap per vogelsoort tot en met 2025

**Uitvoering 3 november 2026:** de 45 betrokken periodetrends zijn inmiddels beveiligd en de gerichte modelvergelijking is uitgevoerd. Zie [uitvoering en resultaten](../zero_policy_20261103/README.md). De onderstaande tekst bewaart de eerdere pilot/beoordeling.

Opdracht van Ton op 2 november 2026: voer de voorgestelde proef uit met de
gegevens tot en met 2025, rapporteer per soort en bewaar resultaten en
beperkingen. De cijfers over 2026 zijn nog niet gevalideerd en vallen buiten
deze proef. De 33 soorten uit het eerdere brugonderzoek zijn geen filter.

## Uitkomst van de 50 herhalingen

De bron bevat 156 soorten uit 1958–2025. Bij beide vensters hebben 70 soorten
in de oorspronkelijke berekening een lange trend; bij de overige 86 is
die oorspronkelijke lange trend niet beschikbaar. Binnen de 70 met een
oorspronkelijke lange trend is de vijfjaarsuitkomst:

| Uitkomst | Soorten |
|---|---:|
| Alle 50 herhalingen berekenbaar | 48 |
| 48 of 49 van de 50 berekenbaar | 4 |
| Minder dan 48 van de 50 berekenbaar | 18 |

Deze indeling is geen definitieve selectie of vrijgave voor formele
onzekerheidsmarges. De overige 86 soorten blijven in het soortenoverzicht
staan met hun afzonderlijke modelperioden en concrete beperkingen.

Veldleeuwerik heeft 31/50 berekenbare lange trends bij vijf jaar en 31/50
bij drie jaar. Witte Kwikstaart heeft respectievelijk 49/50 en 48/50.
Bij Veldleeuwerik mislukt de logaritmische indexhelling vanaf 1984 in
19 herhalingen ondanks een numeriek geslaagd periodemodel.
Een concrete controle: replicatie 1 heeft een geldige vijfjaarsbrug maar een
nulindex in 2017; replicatie 2 heeft bij een geldige brug nulindices in
2015–2019 en 2021. Dit zijn ongeronde indexwaarden, geen afronding van
presentatietotalen. Een langer brugvenster lost die jaren buiten de brug
niet op. De nulvenstertellingen en andere uitvalredenen staan per soort in
de CSV; zij mogen niet bij de primaire uitvalredenen worden opgeteld.

De 50 herhalingen voltooiden in 13 batches met nul batchfouten.
De twee eerste herhalingen waren bij een afzonderlijke herhaling exact
gelijk. De geregistreerde rekentijd van de 50 herhalingen is
1065.7 seconden (17.8 minuten); baselineopbouw,
reproduceerbaarheidsherhaling en rapportage vallen daarbuiten. De hoogste
bestaande R-geheugenmeetwaarde is 350.2 MB;
dit is de bestaande gc-diagnostiek, geen volledige proces-RSS-meting.
De gemeten maximale groei van de systeemswap per batch is
0 bytes; dit is een systeemmaat, geen exclusief
R-geheugengebruik.

Advies na deze proef, nader beoordeeld: de afzonderlijke perioden blijven
het uitgangspunt, maar 45 overall-trenduitkomsten voor 40 soorten bevatten
nuljaartotalen en vragen herbeoordeling. Zie de [beoordeling van nuljaren](main_index_zeros/README.md).
Beoordeel eerst hoe de lange trend met werkelijke nuljaren in de hoofdindex
kan worden beschreven, zonder nullen weg te laten of pseudotellingen toe
te voegen. Beoordeel daarnaast de bruguitval per soort. De vijfjaarsvariant
is hiermee getest als kandidaat, maar wordt geen algemene standaard.
Start nu geen algemene 500/2.000-run: deze proef heeft de resterende
model- en randproblemen concreet gemaakt, niet opgelost. Voor een latere
run blijft per soort en resultaatstype zichtbaar wat verantwoord te
schatten is; de invoerpopulatie wordt niet tot de succesvolle soorten
teruggebracht. De definitieve 2026-route wacht bovendien op gevalideerde
2026-gegevens en een bijpassende nieuwe bronbasis.

## Uitvoering

Alle 156 soorten uit de historische, gevalideerde analysecache 1958–2025
blijven in de uitvoer staan. De oorspronkelijke periodemodellen slagen voor
93 soorten in beide perioden, voor 35 alleen vanaf 1984, voor zeven alleen
vóór 1984 en voor 21 in geen van beide perioden. Dat is een beschrijving van
deze ontwikkelbron, geen nieuwe inventarisatie van de levende database.

Er zijn 50 gemeenschappelijke trekkingen met teruglegging van volledige
kavelgeschiedenissen, binnen de bestaande twee strata: 17 historische
kernkavels en 35 kavels van het latere netwerk. Alle soorten gebruiken
binnen één herhaling dezelfde trekking. Eén lokale worker. De kavel-,
oppervlakte- en observatiestatuscorrecties uit de bestaande analyse blijven
van toepassing. Een ontbrekende broncel blijft ontbrekend; echte nullen en
de vastgelegde afgeleide jaarverslagnullen blijven onderscheiden.

De hoofdvariant gebruikt de experimentele venstermethode met 1979–1983 en
1986–1990. De referentie gebruikt dezelfde methode met 1981–1983 en
1986–1988. De gemeenschappelijke kalibratiepool telt respectievelijk 33 en
32 kavels; deze vergelijking verandert dus vensterlengte én kalibratiedekking.
Het eerdere vensteronderzoek heeft die twee effecten ook afzonderlijk
onderzocht. De ruimere plotjaarbasis telt 35 respectievelijk 33 potentiële
brugkavels; de werkelijk vastgelegde pilotconfiguratie is echter bepaald
op de toegelaten getelde cellen van de soortenmatrix en telt 33 en 32.
Per soort kan het aantal gepaarde, informatieve kavels verder kleiner zijn. De overgangsjaren 1984–1985 staan in het tweede hoofdmodel,
maar kalibreren geen brug.

De periodevoorbereiding en modelvolgorde zijn gedeeld met de bestaande
soortenroute. De modelvolgorde is model 3 met overdispersie, dezelfde variant
met seriële correlatie, model 3 zonder beide en daarna model 2 zonder beide.
De eerste geslaagde variant wordt gebruikt. Tijdens de herhalingen blijven
de oorspronkelijke modeljaren per soort gelijk. Een verloren vroege
waarneming verschuift dus niet ongemerkt de onderzochte periode.
Bij een oorspronkelijk onschatbare periode wordt geen ander doelbereik
gezocht; de uitkomst blijft uitdrukkelijk onbeschikbaar.

De brugkalibratie is een geprofileerd Poisson-model met een kaveleffect en
een venstereffect. Per kavel telt het werkelijk aantal onderzochte jaren mee.
De berekening gebeurt als conditionele logistische schatting op beide
venstersommen; de quasi-binomiale variant accepteert de bestaande
oppervlaktegecorrigeerde, niet noodzakelijk gehele tellingen. Kavelparen
zonder enige positieve telling informeren de verhouding niet. Een volledig
nulvenster, ontbrekende ankerjaren of niet-positieve ankerindex leveren geen
brug. Er wordt geen factor 1, pseudotelling of factor van een andere soort
gebruikt. De kalibratie gebruikt de complete unie van ankerjaren op de
gepaarde kavels; volledige waarneming van ieder jaar op ieder kavel is niet
vereist. Dit model veronderstelt één gemeenschappelijke vensterverhouding;
het kan echte ecologische verandering tussen de vensters niet van een
methode-effect scheiden.

De lange trend en de aanvullende afzonderlijke indexhellingen zijn
beschrijvende OLS-regressies van log(index) op kalenderjaar, uitgedrukt als
100 × (exp(helling) − 1). Dit zijn geen vervangingen van de bestaande
formele periodetrends uit `rtrim::overall()`. Iedere vereiste indexwaarde
moet eindig en positief zijn. Een nul of ontbrekend jaar wordt niet
stilzwijgend overgeslagen om alsnog een helling te kunnen leveren.

Ook de jaarlijkse hulproute leest nu ongeronde modeltotalen. De absolute
interne rtrim-vector `tt_imp` wordt bij iedere uitlezing gecontroleerd tegen
de publieke, genormaliseerde `rtrim::index()`-uitvoer. Bij een afwijkend
pakketcontract stopt die brug. De afgeronde presentatietabel van
`rtrim::totals()` wordt niet meer gebruikt voor verhoudingen.

## Bestanden en leeshulp

- `PER_SOORT.md`: leesbaar overzicht van alle 156 soorten, met de eigen
  modeljaren, oorspronkelijke vijfjaarstrend, geslaagde herhalingen voor
  beide brugvensters, spreiding en concrete beperkingen.
- `per_soort.csv`: dezelfde soorten, met daarnaast afzonderlijke
  periode-uitkomsten, modelkeuzen, exacte modeljaren, nulvensteraantallen,
  uitvalredenen en minimum, maximum, mediaan en standaardafwijking.
- `oorspronkelijke_berekening.csv`: twee regels per soort, vóór herhaling,
  inclusief brugfactor, niveauverhouding en anker-/modelstatus.
- `pilot_species_validity.csv`: aantallen per soort en brugvariant. De
  rekenkundige 95%-controle is uitsluitend een diagnose, geen vrijgave.
- `pilot_model_frequencies.csv` en `pilot_run.csv`: modellen en uitvoering.
- `manifest.json`: bron-, configuratie-, engine- en batchhashes.

`pre` betekent vóór 1984; `post` betekent vanaf 1984. De feitelijke
modeljaren kunnen per soort later beginnen dan 1958 of 1984 en staan
expliciet in de bestanden. `n` telt eindige, positieve, complete
indexhellingen; `model_gelukt_n` telt alleen of het periodemodel numeriek
slaagde. Een geslaagd model kan dus toch een onbruikbare indexhelling
hebben. Redenen met `baseline_` beschrijven een oorspronkelijk ontbrekend
model, geen door de trekking nieuw veroorzaakte modeluitval.

`nul_totaal_volledig_venster` betekent dat er op de gepaarde getrokken
kavels in minstens één volledig venster geen positieve telling resteert.
Het getelde aantal hiervan is een brugdiagnose en kan samenvallen met een
modelprobleem. `result_reason` geeft één primaire uitvalreden, in de
volgorde eerste periodemodel, tweede periodemodel, brug, complete index.
De brugredenen worden daarnaast afzonderlijk bewaard; tel deze twee
redenentellingen niet bij elkaar op.

## Beperkingen

Vijftig herhalingen zijn een ontwikkelproef. Minimum–maximum en
standaardafwijking beschrijven alleen de berekenbare herhalingen. Zij zijn
geen formeel 95%-interval en beschrijven bij uitval uitsluitend de
voorwaardelijke, eindige uitkomsten. Een volledig nulvenster kan een
ongelimiteerde of niet-identificeerbare grens opleveren; die massa mag niet
worden weggefilterd voor een schijnbaar volledig onzekerheidsinterval.
Ook 50/50 geslaagde herhalingen bewijzen geen correcte dekking van zo'n
interval. De kans op zeldzame uitval en de stabiliteit van de staarten
kunnen hiermee niet nauwkeurig worden beoordeeld.

De proef meet gevoeligheid voor de beschikbare kavels binnen het gekozen
clusterontwerp. Systematische telverschillen, de geldigheid van de
jaarverslagnulaanname, onjuiste bronwaarden, netwerkrepresentativiteit en
niet-gemeten methodeverandering worden niet automatisch door bootstrap
opgelost. Oppervlaktecorrectie lost evenmin iedere grens- of habitatwijziging
op. De bron en alle bestaande aannames zijn tijdens deze proef behouden.

Er zijn geen groepsindicatoren berekend. Uit soortgewijze beschikbaarheid
volgt geen beschikbaarheid van een vaste groepsindicator: daarvoor is de
gezamenlijke uitval bepalend. Er is geen nieuwe soortselectie vastgesteld.
Onschatbare soorten blijven zichtbaar, met afzonderlijke perioden waar
mogelijk; waarnemingen en teldekking blijven de aangewezen presentatie
waar een model ontbreekt.

De historische cache is een bewaarde ontwikkelbron. Zij vervangt geen verse
export uit de levende lokale database voor een latere definitieve run.
Geen 2026-cijfers, 500/2.000-herhalingen, databasewijziging, nieuwe dump of
cache, wijziging van canonieke soort-/MSI-uitvoer of VPS-publicatie.

## Herkomst en herhalen

SQL-bronidentiteit:
`15de9245b0d0fbbd0a65990c6c0d618ff8f0298f712775210fe0b1566a917913`.
Cache-SHA256:
`071e66821f706ae1c0c37b11b3295ddde84a1872b194f9a09f43e595b50252d8`.
Het opbouwscript controleert deze cachehash en de ingebedde SQL-identiteit.
De SQL-export zelf wordt niet opnieuw ingelezen; de gevalideerde cache is
de gebruikte numerieke bron. R 4.5.3, rtrim 2.3.1, seed 20261102.

Opbouw: `R/build_trim_species_pilot_2025.R REPO CACHE RUNMAP`.
Herhalingen: `R/run_trim_bootstrap_batch.R --bundle RUNMAP/input
--replicate-from VAN --replicate-to TOT --output BATCH.rds`.
Rapportage: `R/summarise_trim_species_pilot_2025.R REPO RUNMAP RAPPORTMAP`.
De bestaande batchcontracten controleren engine-identiteit, checksums,
ontbrekende en overlappende herhalingen.

De ruwe, hervatbare batches staan buiten Git in
`/Users/ton/Documents/GitHub/Meijendel/outputs/trim-bootstrap-window-20261102/pilot_2025_50/`.
De compacte beoordelingsresultaten staan hier; er is geen tweede kopie van
de meetgegevens aan de repository toegevoegd. Geraadpleegde projectbronnen:
de bijgevoegde methodedocumenten over statistische analyse en telmethode,
de actuele code en observatiepoort, het bootstrapdraaiboek en de eerdere
nul- en vensteronderzoeken. Historische aantallen uit de bijgevoegde
methodetekst zijn niet gebruikt als actuele selectie; de gecontroleerde
cache bevat de hierboven genoemde 156 soorten.
