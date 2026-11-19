# TRIM-bootstrap na ontvangst van broedseizoen 2026

Stand: 2 november 2026. Dit draaiboek bereidt de berekening voor; het verleent
geen toestemming voor een nieuwe dump, een 2.000-run of VPS-publicatie.

**Actuele aanvulling voor de afzonderlijke 2025-analyse:** het besluit en de
beoordeling van de vaste begin/eindmaat staan onderaan bij 3 november 2026
en in trim/bootstrap/species_2025_2000_20261103. Die analyse wacht niet op
2026. Het oudere stappenplan hieronder geldt voor de 2026-productieroute.

De [presentatiematrix voor de 2026-release](TRIM_RELEASE_2026_PRESENTATIE.md) legt per websiteonderdeel, dashboardgrafiek en Shiny-weergave vast wat lokaal moet worden voorbereid.

## Lokale aansluiting op 4 november 2026

De [aansluitnotitie](TRIM_RELEASE_2026_AANSLUITING.md) beschrijft de uitgevoerde koppeling van de bestaande diagnostische 2025-uitvoer aan website, dashboard en Shiny, met resterende bron- en uploadblokkades. De oude jaarlijkse gecombineerde trend en 95%-geldigheidsregel hieronder zijn geen vrijgavecontract voor de nieuwe netto begin/eindmaat of puntgewijze jaarbanden. Die vragen schattergebonden vrijgave vóór formele productieactivering. De diagnostische preview kan geen formele uitvoer activeren.

## Statistisch contract

- Primair: formele TRIM-trends 1958–1983 en 1984–2026 via
  `rtrim::overall(which = "imputed")`.
- Aanvullend: formele gecombineerde trend 1958–2026 via een gestratificeerde
  clusterbootstrap van volledige plotgeschiedenissen.
- Primaire brug: gemeenschappelijke plots, 1981–1983 naar 1986–1988.
- Overgangsjaren 1984–1985: wel in het tweede TRIM-model, niet in de primaire
  brugkalibratie.
- Gevoeligheid: 1987–1989, 1988–1990, strikte zesjaarsset, 1984–1986 als
  historische comparator en een vaste historische-kernvariant.
- Groepen: vaste robuuste soortpopulatie primair; volledige wisselende
  samenstelling uitsluitend als gevoeligheidsvariant.
- De gevoeligheidsenvelop is geen 95%-betrouwbaarheidsinterval.

## Harde volgorde

1. Importeer en valideer eerst alle cijfers over broedseizoen 2026 in de
   levende lokale MySQL-database. Controleer bronstatus, echte nullen, lege
   cellen, formele afkeuringen, plotdekking en soortidentiteit.
2. Vraag afzonderlijk akkoord voor een verse dump en cache uit die levende
   database. Gebruik geen bestaande dump of productieback-up als bron.
3. Draai bron-/uitvoercontract, clusterlineage en brugvensteraudit opnieuw.
   Leg aantallen voor 1958–2026 vast; neem de 2025-aantallen niet over.
4. Bouw vanaf een schone, gereviewde commit één hashgebonden runbundle:

   ```bash
   Rscript R/build_trim_bootstrap_bundle.R \
     --sql /absoluut/pad/meijendel.sql \
     --bundle /absoluut/pad/run/input_bundle \
     --end-year 2026 \
     --planned-replicates 2000 \
     --run-id trim-2026-YYYYMMDDTHHMMSS \
     --run-seed 20260920
   ```

5. Draai eerst twee replicaties en vergelijk ze met dezelfde IDs uit een tweede
   run. Draai daarna met één lokale worker eerst 50 replicaties en vat de
   geldigheid samen. Start 500 alleen als iedere beoogde formele schatter
   minimaal 95% geldig is. Start 2.000 pas als ook de 500-validatie groen is:

   ```bash
   scripts/run_trim_bootstrap_local.sh \
     --replicates 50 --batch-size 5 \
     --sql /absoluut/pad/meijendel.sql \
     --run-root /absoluut/pad/run
   ```

6. Gebruik NAS of productie-VPS alleen na een afzonderlijke read-only
   capaciteitsproef en expliciete toestemming. De voorbeeldconfiguratie houdt
   beide uitgeschakeld. Eén worker maximaal; normale NAS-taken, MySQL, Shiny en
   websitehealth hebben altijd voorrang. Een production lock stopt de VPS-worker
   vóór de volgende replicatie.
7. Merge alleen complete, niet-overlappende batches met gelijke bron-, code-,
   configuratie- en softwarehashes. Voer clusterjackknife, BCa-samenvatting en
   alle structurele gevoeligheidsvergelijkingen uit.
   Leg vóór de intervalberekening ook iedere geldige en ongeldige schatter vast:

   ```bash
   Rscript R/summarise_trim_bootstrap_pilot.R \
     /absoluut/pad/run/pilotdiagnostiek 50 \
     /absoluut/pad/run/batches/batch-??????-??????.rds
   ```

   De vier diagnostiekbestanden rapporteren runtijd, geheugen, batchfouten en
   per soort- en groepsvariant het geldige percentage en de voornaamste
   uitvalreden. Gebruik bij 500 of 2.000 het werkelijk verwachte aantal in
   plaats van `50`. Ze zijn controle-uitvoer en nooit een publicatieproduct.
8. Publiceer een schatter alleen bij minimaal 95% geldige replicaties. Verhoog
   van 2.000 naar maximaal 5.000 alleen wanneer beide intervalgrenzen tussen
   opeenvolgende controles nog minstens 0,10 procentpunt per jaar of 5% van de
   actuele intervalbreedte veranderen.
9. Schrijf de canonieke CSV's atomisch en activeer ze alleen bij eindjaar 2026,
   minimaal 2.000 geplande replicaties en status `publiceerbaar`.
10. Draai alle schema-, dashboard-, website-, Shiny-, bronregister- en
    deploypreflights. Vraag daarna afzonderlijk akkoord voor VPS-publicatie.

## Ontwikkelmeting 1958–2025

De gevalideerde broncache bevat 156 soorten in de statuslaag, 135 soorten met
minimaal één indexreeks, 93 soorten met beide modelperioden en 52 ooit getelde
plots. Daarvan liggen 17 plots in de historische kern, 35 in het latere
netwerk, 33 in de primaire brugset en 20 in de strikte zesjaarsset. Van de 93
soorten met twee perioden hebben 68 een geldige nieuwe formele primaire brug;
33 voldoen daarnaast aan de volledige-jaarvoorwaarde voor de vaste
groepspopulatie.

De lokale 50-pilot met R 4.5.3 en `rtrim` 2.3.1 gebruikte één iMac-worker,
duurde gemeten 2.460,4 seconden en gebruikte maximaal 357,0 MB R-geheugen.
Alle 50 replicaties voltooiden zonder batchfout; swap was nog niet gemeten.
Replicaties 1 en 2 waren bij herhaling exact gelijk. De pilot gebruikte de
voorlopige vaste set van 35 soorten: 5 van 21 primaire vaste groepen haalden
95% geldigheid, tegenover 21 van 21 volledige gevoeligheidsgroepen. Na
correctie naar 33 vaste soorten waren in één rookreplicatie 7 van 21 vaste
groepen geldig. Start de 500-validatie daarom pas na een expliciet methodisch
besluit en een nieuwe groene 50-pilot. Geen validatierun mag canonieke
publicatiebestanden activeren.


## 2 november 2026 — nuljaartotalen en experimentele vensterkalibratie

De nulcorrectie is uitgevoerd en met regressietests gecontroleerd. Een nul
blijft in het venstergemiddelde; een ontbrekende of negatieve jaarwaarde
blokkeert de brug. `yearly_trim` blijft standaard. `window_poisson` is een
expliciete experimentele variant die een vast soortselectiebestand vereist.
De selectie blijft exact de eerder vastgestelde 33 soorten.

De kalibratievergelijking gebruikt de historische cache 1958–2025 en de 50
bestaande trekkingen. Bij het venstermodel slagen 32 soorten 50/50; Witte
Kwikstaart 47/50 wegens drie volledig nulvensters. De oorspronkelijke
brugfactor verandert bij Veldleeuwerik −51% en bij Witte Kwikstaart +33%. Er
zijn geen richtingwisselingen in de 33 oorspronkelijke soorttrends. De
venstermethode is daarom niet als primaire vervanging vrijgegeven. Dit is
geen volledige bootstrap en er zijn geen nieuwe intervallen berekend.

Een volledige nieuwe 50-pilot is niet gestart: voor groepen met Witte
Kwikstaart is de 95%-grens onder deze kalibratie al onhaalbaar in deze
50 trekkingen. Een methodisch vervolg moet de nulvensters en de omvangrijke
brugverschillen beoordelen; soorten worden niet automatisch geschrapt.
Kalibratiebewijs: `trim/bootstrap/bridge_zero_20261102/README.md`. Geen
500-run, databasewijziging, nieuwe dump/cache of VPS-publicatie.


### Afgeronde verdieping op 2 november 2026

De uitvoerafronding in `rtrim::totals()` beïnvloedt de brug; de modelinvoer
wordt niet afgerond. Bij Witte Kwikstaart resteert met ongeronde totalen
8,21% modelverschil; bij Veldleeuwerik blijven sterke imputatie- en
plotgevoeligheid. De exacte kans op verlies van alle positieve
navensterplots voor Witte Kwikstaart is 4,3182%. De 47/50 toont niet aan
dat een grotere run onder 95% blijft, maar de nulrand kan niet worden
weggelaten uit de onzekerheidsverdeling. De 95%-geldigheidsgrens alleen
is daarom geen voldoende publicatiecriterium. Geen productiefunctie of
selectie gewijzigd. Vervolg: ongeronde totalen met een regressietest
aansluiten en een expliciete brug-/intervalpoort voor onvoldoende
kalibratie-informatie uitwerken; incidentele soorten zichtbaar behouden.
Bewijs: `trim/bootstrap/bridge_zero_20261102/sensitivity/README.md`.


## 2 november 2026 — besluiten over brugbaarheid en incidentele soorten

Ton heeft de volgende drie adviezen uit deze chat overgenomen:

1. Dwing geen brug af. Een soort met onvoldoende ankerinformatie krijgt
   de status `brug_niet_betrouwbaar_schatbaar`. Gebruik geen factor 1,
   pseudotelling of overgenomen factor van een andere soort als reparatie.
2. Behoud iedere soort zichtbaar. Gebruik afzonderlijke periodetrends waar
   de gegevens die dragen; toon anders waarnemingen, aantallen en teldekking.
   Beoordeel incidenteel voorkomen over de relevante reeks, niet uitsluitend
   op afwezigheid in de brugjaren. Een onbekende cel blijft onbekend en een
   geldige getelde afwezigheid blijft nul.
3. Behoud de ecologische groepsdefinitie. Laat een onschatbare soort niet
   ongemerkt uit de MSI verdwijnen. Een onvoldoende onderbouwde langjarige
   groepsindicator krijgt geen geforceerd formeel interval en blijft
   beschrijvend.

De 33 soorten zijn een vaste statistische selectie voor 1958–2025, geen
ecologische groep: bruikbare modellen voor beide perioden, een primaire
brug 1981–1983 naar 1986–1988, en een positieve eindige modelindex in alle
68 jaren van de oorspronkelijke fit. Die modelindices bewijzen niet dat
de soort ieder jaar is waargenomen. De pilot toonde dat de oorspronkelijke
selectie niet voldoende is om bootstrapstabiliteit te garanderen.

Onderzoeksvraag, nog geen selectiebesluit: kan een kleinere vaste rekenkundige
selectie van goed meetbare soorten een formele indicator dragen? Benoem
zo'n subset expliciet en vergelijk haar met de volledige ecologische groep;
zij mag zeldzame, verdwenen of nieuw verschenen soorten niet onzichtbaar
maken. Beoordeel dekking, uitval en gevoeligheid vóór een definitieve run;
controleer ook de gezamenlijke groepsuitval.

De twee afzonderlijke TRIM-perioden blijven primair. De historische
50-pilot, de aangescherpte 33-soortselectie, de uitgevoerde nulcorrectie,
de experimentele vensterkalibratie, de uitvoerafronding in rtrim,
imputatie-/plotgevoeligheid en de exacte nulvensterkansen blijven
herleidbaar in `docs/TRIM_BOOTSTRAP_2026_RUNBOOK.md` en
`trim/bootstrap/bridge_zero_20261102/`. Geen definitieve bootstrap,
databasewijziging, nieuwe dump/cache of publicatie is hiermee toegestaan.

Opdracht: onderzoek langere brugvensters als gezamenlijke gevoeligheidsproef.
Vóór de berekening vastgelegd: 3 jaar (1981–1983/1986–1988), 5 jaar
(1979–1983/1986–1990), 7 jaar (1977–1983/1986–1992) en 10 jaar
(1974–1983/1986–1995; brede stresstest). Dezelfde vensters gelden voor
alle 33 soorten. De overgangsjaren 1984–1985 blijven uitgesloten van
kalibratie. Vergelijk een vaste plotpool met een per venster veranderende
gemeenschappelijke plotpool, zodat vensterlengte en netwerkuitbreiding
onderscheiden blijven. Gebruik ongeronde jaarlijkse totalen naast de
expliciete venstermethode; wijzig de primaire productiemethode niet.


## 2 november 2026 — afgeronde venstervergelijking en reikwijdte

De 33 zijn de onderzochte vogelsoorten, geen 33 probleemsoorten. Het woord
"vast" beschreef alleen dat dezelfde soorten binnen een vergelijking
worden gebruikt; het is geen definitieve selectie voor altijd. De
groeps-MSI in de bootstrapontwikkelproef betrof alleen de soorten uit
deze statistische selectie die tot de betreffende ecologische groep behoren. Zij
vertegenwoordigt dus niet de volledige vogelgemeenschap. Een kleinere
rekenkundige subset is een besproken optie, geen genomen selectiebesluit.

De hoofddoelstelling blijft onzekerheid per vogelsoort voor het volledige
soortenbestand. De 33 zijn geen algemene beperking voor de soortbootstrap.
De deelperioden hebben al formele TRIM-onzekerheid; de aanvullende
bootstrap betreft vooral de samengestelde lange trend inclusief brug en
de eventuele groepsindicatoren. Het oorspronkelijke invoerbestand bevat
156 soorten; de nieuwe definitieve bron kan een ander aantal bevatten.

De gezamenlijke vergelijking van 3-, 5-, 7- en 10-jaarsvensters is afgerond.
Bij gelijke oorspronkelijke kalibratieplots hebben de jaarlijkse
hulpmodellen respectievelijk 33, 33, 30 en 30 schatbare uitgangsbruggen
voor 33 soorten. Het venstermodel heeft bij alle vier lengten 33. Dit
zijn geen bootstrapgeldigheidspercentages. Bij Witte Kwikstaart daalt
de berekende kans op verlies van een volledig venster bij vijf jaar
van 4,318% naar 1,519%. Veldleeuwerik blijft sterk afhankelijk van
imputatie en afzonderlijke plots. Zeven/tien jaar veroorzaken nieuwe
nuljaren in het jaarlijkse hulpmodel en vermengen meer echte verandering.

Advies, nog geen nieuwe productiestandaard: gebruik 1979–1983 en
1986–1990 als kandidaat voor de volgende proef, met de driejaarsbrug als
referentie. Werk eerst de ongeronde uitlezing, expliciete vensterconfiguratie
en behandeling van nulrand/uitval af. Beoordeel vervolgens het volledige
soortenbestand per soort en resultaatstype. De afgesproken definitieve
2026-run vraagt gevalideerde 2026-brondata en een verse gevalideerde
bronbasis; de kleine proef en pilot gaan vooraf aan 500/2.000 replicaties.
Er is geen nieuwe selectie, primaire methode, databasebewerking of
publicatie uitgevoerd. De drie door Ton overgenomen afspraken over
geen afgedwongen brug, zichtbaar houden en behouden van ecologische
groepsdefinities blijven gelden. Volledig bewijs en startvoorwaarden:
`trim/bootstrap/bridge_zero_20261102/long_windows/README.md`.


Aanvullende conclusie bij de venstervergelijking: de verlaging van de kans op een volledig nulvenster geldt voor de expliciete venstermethode. Het huidige jaarlijkse hulpmodel vereist positieve informatie in ieder afzonderlijk jaar. Voor Witte Kwikstaart blijft in 1986 één dragende bronplot over; bij het vijfjaarsvenster heeft Veldleeuwerik hetzelfde probleem in 1989. De uitvalkans van het jaarlijkse hulpmodel is voor beide soorten daardoor minstens 36,256% onder het bestaande trekkingsontwerp. Alleen langere vensters instellen is dus geen oplossing voor die jaarmodellen. De aanbevolen volgende proef is de afzonderlijke venstermethode met vijf jaar, niet het zonder meer vervangen van drie door vijf in de huidige standaard.


Verduidelijking van de reikwijdte: de 33 horen bij de groepsberekening
in de bootstrapontwikkelproef en bij deze gevoeligheidsvergelijking.
De bestaande beschrijvende groepsroute gebruikt ruimere selecties: in
de historische run 135 soorten met minstens één bruikbare indexreeks
voor de volledige variant en 93 met beide modelperioden voor de robuuste
variant. Niet alle soorten dragen in ieder jaar bij. De uitspraak over
33 soorten geldt dus niet voor die bestaande beschrijvende route.
Binnen één groepsbootstrap blijft de gekozen samenstelling gelijk;
dat maakt haar geen selectie voor altijd.


## 2 november 2026 — soortenpilot met gegevens tot en met 2025 afgerond

De ontwikkelpilot met de historische cache 1958–2025 is afgerond voor alle 156 soorten, met 50 gezamenlijke gestratificeerde trekkingen van 52 kavelgeschiedenissen en één lokale worker. De experimentele vijfjaarsbrug 1979–1983/1986–1990 is vergeleken met de driejaarsbrug 1981–1983/1986–1988. Van de 70 soorten met een oorspronkelijke lange trend hebben er 48 een berekenbare uitkomst in alle 50 herhalingen, 4 in 48 of 49 en 18 in minder dan 48. De overige 86 soorten blijven zichtbaar met afzonderlijke modelperioden en uitvalredenen. Veldleeuwerik haalt 31/50 bij vijf jaar en 31/50 bij drie jaar; Witte Kwikstaart 49/50 en 48/50. Een berekenbare brug voorkomt niet dat een nuljaar in de hoofdindex de gekozen logaritmische lange trend blokkeert. Vijftig herhalingen en spreiding over alleen eindige uitkomsten leveren geen formele 95%-marge. Er is geen groepsselectie of nieuwe productiestandaard vastgesteld. De resultaten en beperkingen per soort staan in trim/bootstrap/pilot_2025_50_20261102/README.md, PER_SOORT.md en per_soort.csv. Geen 500/2.000-run of publicatie; de definitieve 2026-route blijft afhankelijk van gevalideerde 2026-gegevens.


## 2 november 2026 — nuljaren in de soortindex beoordeeld

In de historische ontwikkelbron 1958–2025 bevatten 45 van de 228 geslaagde periodemodellen echte nuljaartotalen: 21 vóór 1984 en 24 vanaf 1984, verdeeld over veertig soorten. De gebruikte rtrim-versie 2.3.1 behandelt zulke totalen in overall() bij de logberekening feitelijk als één; de huidige contractfunctie geeft deze 45 overall-trenduitkomsten toch het etiket formeel. Een gecontroleerde schaalproef bevestigt dat de berekende relatieve helling daardoor van de rekeneenheid kan afhangen. Deze 45 trenduitkomsten vragen herbeoordeling; de tellingen, periodemodellen en jaarindices zijn daarmee niet automatisch ongeldig. Echte nullen blijven behouden en ontbrekende waarden blijven apart. Een nulvriendelijke, verkennende samenvatting van dezelfde 50 trekkingen maakt binnen de 70 oorspronkelijke lange trends meer soorten volledig berekenbaar (60 in plaats van 48), maar verandert de trendmaat; dit is geen gekozen vervanger. Advies: eerst de nulbehandeling bij de 45 overall-uitkomsten beveiligen, daarna een gerichte inhoudelijke vergelijking van een passend telmodel en een nulvriendelijke samenvatting uitvoeren. Geen model-, gegevens-, uitvoerstatus- of publicatiewijziging is hiermee uitgevoerd. Details en controles: trim/bootstrap/pilot_2025_50_20261102/main_index_zeros/README.md.


## 3 november 2026 — nuljarenbeleid uitgevoerd vóór invoer van 2026

Voor de historische ontwikkelbron 1958–2025 is de gedeelde overall-berekening beveiligd tegen de impliciete nul→één-vervanging. Van de 228 geslaagde periodemodellen behouden 183 formele inferentie; 45 perioden voor 40 soorten krijgen nuljaartotaal_herbeoordelen zonder helling, interval, p-waarde of trendklasse. Dezelfde correctie is aangebracht in de twee historische hoofdtrendtabellen. Tellingen, beide jaarindexbestanden, modelkeuzen, brugfactoren en soortselecties zijn behouden. Veldleeuwerik, Torenvalk, Tapuit en Koolmees zijn vergeleken met dezelfde 50 trekkingen en directe telmodellen met lineaire tijd en een beperkte tijdsspline. De lineaire telmodellen leveren respectievelijk 50, 49, 50 en 50 berekenbare uitkomsten; de spline 50, 49, 48 en 50. Twee niet volledig geoptimaliseerde Tapuit-berekeningen zijn afgekeurd. De trendpercentages verschillen per rekenwijze en de toets met achtergehouden jaarblokken heeft in geen van de acht soort-perioden volledige dekking. Er is daarom geen algemene vervanger of geforceerde positieve jaarindex ingesteld. De 2026-cijfers, MySQL, dump/cache, dashboard en VPS zijn niet gewijzigd. Een algemene 500/2.000-run is niet gestart; de methodische vraag wordt niet door meer herhalingen opgelost. Uitvoering, controles en figuren staan in trim/bootstrap/zero_policy_20261103/README.md.


## 3 november 2026 — vier-soortenproef met gedeelde kavelinformatie

Voor de bewaarde Meijendel-ontwikkelbron 1958–2025 zijn Veldleeuwerik, Torenvalk, Tapuit en Koolmees onderzocht met 52 kavelclusters en exact dezelfde 50 gestratificeerde trekkingen. De criteria zijn vóór de modelberekeningen afzonderlijk vastgelegd in commit c3fc5dfb. Een quasi-Poisson-model met tijdsspline en willekeurige kaveleffecten behoudt alle getelde nullen en levert voor alle vier soorten een volledige toets met achtergehouden jaarblokken. Berekenbare lange trends: respectievelijk 50/50, 49/50, 45/50 en 50/50. Alleen Koolmees haalt alle criteria voor berekenbaarheid, testdekking, voorspelkwaliteit en gevoeligheid. Veldleeuwerik en Torenvalk falen op voorspelkwaliteit en tijdsvorm/dekking; Tapuit op berekenbaarheid en kaveldekking. De driejaarsbrug blijft bij alle vier binnen de gekozen marge. Vijftig trekkingen leveren geen formele 95%-intervallen; onbekende kaveljaren blijven modelverwachtingen. Dit is geen vrijgave voor alle 156 soorten of vervanging van de hoofdindex. De bronstatussen voor Meijendel, Meijendel_bronnen en overige kandidaatbronnen veranderen niet. Geen 2026-invoer, database-, cache- of productiewijziging. Uitwerking: trim/bootstrap/random_kavel_20261103/README.md.


## 3 november 2026 — nulvriendelijke helling en begin/eindverandering vergeleken

Voor vier soorten uit de bewaarde Meijendel-ontwikkelbron 1958–2025 zijn de bestaande nulvriendelijke indexhelling en begin/eindverandering vergeleken met exact dezelfde 50 trekkingen van 52 kavelclusters. De criteria en vaste vensters 1958–1962/2021–2025 zijn vooraf gecommit als 58a093ba. Veldleeuwerik, Torenvalk, Tapuit en Koolmees leveren respectievelijk 50/50, 49/50, 50/50 en 50/50 berekenbare uitkomsten. De nulvriendelijke uitgangshellingen zijn −4,57%, −2,75%, −4,13% en +2,29% per jaar; de netto begin/eindveranderingen −93,02%, −90,72%, −99,65% en +710,67%. Vooral Tapuit en Koolmees laten zien dat de twee maten verschillende grootheden samenvatten. Bij Veldleeuwerik geeft trekking 11 een tegengestelde richting tussen beide maten; Torenvalk-trekking 28 blijft zonder schatbare brug. Drie- en zevenjaarsvensters geven dezelfde uitgangsrichting, met variatie in omvang. De vergelijking tussen 17 historische kavels en het volledige netwerk verandert de kavelpopulatie en is daarom geen zelfstandige afkeurtest. Advies: beschrijf de lange verandering met vaste begin/eindvensters naast de volledige jaarreeks en afzonderlijke perioden; geen nieuwe algemene methode ingesteld. Vijftig trekkingen leveren geen formele 95%-marges. Geen vogeltelmodel opnieuw geschat en geen wijziging van brondata, database, 2026, cache of productie. De overige bronstatussen in Meijendel, Meijendel_bronnen en kandidaatbronnen blijven gelijk. Bewijs: trim/bootstrap/index_summary_20261103/README.md.


## 3 november 2026 — alle 156 soorten beoordeeld voor de begin/eindmaat

De gekozen begin/eindmaat vergelijkt de gemiddelde index van 1958–1962 met 2021–2025 in de bewaarde Meijendel-ontwikkelbron 1958–2025. Alle 156 soorten en dezelfde 50 trekkingen van 52 kavelgeschiedenissen zijn verwerkt. Criteria en poorten zijn vooraf gecommit als b2d45c6a. Er zijn 37 schatbare uitgangsveranderingen: 33 soorten halen 50/50 geldige uitkomsten en zijn kandidaat voor een 500-intervalvalidatie; Torenvalk en Witte Kwikstaart halen 49/50 en krijgen alleen uitvalonderzoek; Wintertaling 35/50 en Ransuil 34/50 blijven geblokkeerd door bruguitval. Bij 45 andere soorten ontbreken beginindexjaren in de bestaande modeljaarselectie, bij 11 een schatbare brug; bij 63 zijn niet beide benodigde perioden schatbaar (42 hebben één periode, 21 geen). Dit betekent geen verwijdering van soorten of ontbrekende brontellingen. Vijf kandidaten hebben hoogstens één positieve eindvensterkavel; bij zes soorten wisselt de richting tussen drie-, vijf- en zevenjaarsvensters. De aparte 2025-intervalroute weigert banden uit alleen eindige subsets en schijnzekere constante verdelingen. Alle formele 95%-kolommen blijven leeg; een 500-validatie is nog niet uitgevoerd en bewijst geen intervaldekking. Jaarindices, afzonderlijke perioden, bronstatussen van overige gegevens in Meijendel/Meijendel_bronnen en kandidaatbronnen blijven behouden. Geen nieuwe modellen, bruggen, database-, cache-, 2026- of productiewijziging. Alle soortresultaten en beperkingen staan in trim/bootstrap/endpoint_all_2025_50_20261103/README.md en PER_SOORT.md.


## 3 november 2026 — 500-validatie van de vaste begin/eindmaat

Alle 156 soorten uit de bewaarde Meijendel-ontwikkelbron 1958–2025 zijn verwerkt met 500 gestratificeerde trekkingen van 52 kavelgeschiedenissen. De primaire maat blijft de indexverandering tussen gemiddeld 1958–1962 en 2021–2025, met dezelfde experimentele vijfjaarsbrug. De criteria zijn vooraf vastgelegd in commit 936915e9. Er zijn 28 soorten met 500/500 geldige uitkomsten, negen met een schatbare baseline en uitval, en 119 zonder schatbare baseline voor deze vaste lange maat. Alle soorten blijven zichtbaar. Vijf van de eerdere 33 complete kandidaten tonen nu uitval. Negen soort-trekkinggevallen missen twaalf modelindexjaren 1984/1985 doordat na het filteren van volledig nulgetelde kavels geen modelcellen voor die jaren overblijven; de getelde nullen staan wel in de bron. Deze jaren liggen buiten doel- en brugvensters, maar de afgesproken volledigheidspoort blijft toegepast. Bij 375→500 voldoen drie soorten aan de grensstabiliteitsregel; bij beide opeenvolgende controles geen. Een 2.000-vervolgvalidatie is volgens de rekenpoort mogelijk voor 28 soorten, maar vóór een algemene run wordt een afzonderlijke beoordeling van de 1984/1985-volledigheidseis geadviseerd. Nulgrens, schaarse bronsteun en venstergevoeligheid blijven beperkingen. Geen formele 95%-marges vrijgegeven en geen 2.000-run gestart. De batchtijd was circa 3 uur en 6 minuten, met nul batchfouten en één lokale worker. Geen database-, export/cache-, 2026- of productiewijziging. Overige bronstatussen in Meijendel, Meijendel_bronnen en kandidaatbronnen blijven gelijk. Bewijs: trim/bootstrap/endpoint_2025_500_20261103/README.md en PER_SOORT.md.


## 3 november 2026 — 500 herbeoordeeld op gebruikte vensterjaren

Voor de bewaarde Meijendel-ontwikkelbron 1958–2025 zijn alle 156 soorten herbeoordeeld met dezelfde 500 trekkingen van 52 kavelgeschiedenissen. Criteria vooraf gecommit: f238f144. De controle vereist complete, eindige niet-negatieve indices in begin-, eind- en vijfjaarsbrugvensters, plus twee bruikbare periodemodellen en een positieve brug. Overige indexjaarproblemen blijven afzonderlijk zichtbaar en blokkeren deze maat niet. Negen soort-trekkinggevallen met twaalf ontbrekende indexjaren 1984/1985 worden zo bruikbaar zonder indices aan te vullen. Er zijn nu 32 soorten met 500/500 geldige niet-constante uitkomsten (voorheen 28), vijf met een schatbare baseline en uitval, en 119 zonder schatbare baseline voor de vaste lange maat. Dodaars, Slobeend, Kuifeend en Rietgors worden kandidaat; Veldleeuwerik haalt 497/500, Wintertaling 333/500 en houdt samen met Torenvalk, Ransuil en Witte Kwikstaart uitval. Alle eerder geldige waarden, baselines en drawhashes blijven gelijk. Bij 375→500 voldoen 3 van de 32 kandidaten aan de grensstabiliteitsregel, bij beide opeenvolgende controles 0. Advies: een afgebakende 2.000-validatie kan voor deze 32 soorten; voor de overige 124 lost meer trekken de blokkade niet op. Nulgrens, beperkte bronsteun, venstergevoeligheid, model-/brugaannamen en onbekende 95%-dekking blijven beperkingen. Geen formele marges of jaarlijkse/periode-intervallen vrijgegeven. Geen nieuwe modelfits, trekkingen, 2026-invoer, database-, export/cache- of productiewijziging. Overige bronnen in Meijendel, Meijendel_bronnen en kandidaatbronnen zijn opnieuw op wijziging getoetst; hun toelating en status blijven gelijk. Bewijs: trim/bootstrap/endpoint_2025_500_window_check_20261103/README.md, PER_SOORT.md en vergelijkingstabellen.


## 3 november 2026 — 2.000-validatie en eigen periode- en jaarindexbeoordeling

Voor alle 156 soorten uit de bewaarde Meijendel-ontwikkelbron 1958–2025 is de onzekerheidsbeoordeling vastgelegd. Criteria vooraf:e7f68940. Voor 32 soorten zijn de bestaande 500 trekkingen met 1500 uitgebreid tot 2000, met dezelfde 52 kavelclusters; 29 hebben 2000/2000 geldige niet-constante uitkomsten, 4 halen beide grensstabiliteitscontroles en 3 hebben uitval zonder band. Voor de overige 124 blijft de lange beoordeling op 500 staan: vijf met uitval en 119 zonder lange baseline. Alle 156 hebben daarnaast een zelfstandige beoordeling met 500 trekkingen voor 312 afzonderlijke perioden en 10608 kalenderposities. Binnen de 119 hebben 56 soorten twee,42 één en 21 geen bruikbaar baselinemodel; 149 eigen periodeveranderingen zijn schatbaar; 73 daarvan en 2420 jaarindices krijgen een volledige diagnostische band. Jaarindices gebruiken een vast referentiejaar per eigen modelperiode; ontbrekend of nul referentiejaar blijft ongedefinieerd, vaste 100 en constante verdelingen krijgen geen schijnmarge. 22670 succesvolle postperiodemodellen zijn alleen hersteld omdat bruguitval hun zelfstandige index in de opgeslagen uitvoer had gewist; dezelfde trekkingen/modeljaren/configuraties en periodehellingen zijn gecontroleerd. Eerste 500 en beschermde bronuitvoer blijven behouden. Eigen periodeveranderingen zijn netto tussen eerste/laatste vijf bevroren modeljaren, geen jaarlijkse overall-trend. Jaarbanden zijn puntgewijs. Alle banden blijven diagnostisch; geen formele 95%-vrijgave. Beperkte bronsteun, vensterkeuze, model-/brugaannamen en onbekende dekking blijven per soort vermeld. Geen 2026-invoer, database-, dump/cache- of productiewijziging; overige bronnen in Meijendel,Meijendel_bronnen en kandidaatbronnen behouden hun status. Bewijs:trim/bootstrap/species_2025_2000_20261103/README.md,PER_SOORT.md en soort-/periode-/jaarCSV’s.


## 4 november 2026 — zelfstandige perioden en jaarindices uitgebreid

Alle 156 soorten uit de bewaarde ontwikkelbron 1958–2025 blijven zichtbaar: 312 perioden en 10.608 kalenderposities. Van 89 soorten zijn 141 zelfstandige perioden van 500 tot 2.000 trekkingen uitgebreid; de overige 171 perioden van alle soorten behouden de oorspronkelijke 500-beoordeling. Na uitbreiding hebben 134 van de 141 perioden een volledige niet-constante diagnostische band, waarvan 14 beide stabiliteitscontroles halen. Bij de jaarindices zijn 4365 diagnostische banden beschikbaar, waarvan 222 beide controles halen. Er gingen 258 eerdere periode-/jaarbanden verloren door uitval of een niet bruikbare verdeling; deze worden niet met succesvolle subsets gerepareerd. Er kwamen 0 diagnostische jaar-/periodebanden bij.

Voorafcriteria: `32123615`. De oorspronkelijke 500 matrices zijn exact behouden; 300 nieuwe batches met IDs 501–2000 zijn gecontroleerd. Alle bandgrenzen en stabiliteitsvlaggen zijn onafhankelijk nagerekend. Geen formele 95%-vrijgave, gelijktijdige jaarband of nieuwe lange-trendmarge. Bronsteun, referentiejaarproblemen, modelaanvulling en uitval blijven per soort vermeld. Zie `trim/bootstrap/periods_2025_2000_20261104/README.md`, `PER_SOORT.md` en de volledige CSV’s.

De nieuwe uitvoer is aangesloten op hetzelfde lokale bootstrapblok voor website, dashboard en Shiny. De kandidaat bindt component-runidentiteiten, broncontext en checksums van invoer en consumenten. Tons vaste afspraak over integrale voorbereiding voor één latere 2026-actualisering is in beide repo-AGENTS en geheugen vastgelegd. Officiële 2026-validatie, verse bronproducten, schattergebonden intervalvrijgave, gezamenlijke releasecontroles en expliciet publicatieakkoord blijven poorten. Geen database-, export/cache-, groeps- of VPS-wijziging.


## Gezamenlijke releasecontrole

De presentatieroute leest de werkelijke gegevensgrens en component-run uit het bronmanifest. Voor eindjaar 2026 wordt het laatste vijfjaarsvenster 2022–2026; de historische brugvensters wijzigen daardoor niet. Een bron zonder territoriumregels voor eindjaar 2026 blokkeert de pariteitscontrole, voordat modellen worden berekend. De gewone generatie/deployscripts vragen een expliciet eindjaar of release-manifest. Gebruik nooit een 2025-kandidaat met alleen een aangepast jaartal.

Voeg SQL/cache, website/CMS/media, dashboard/figuren, Shiny en dezelfde bootstrap samen in één pakket. De lokale bouw/verificatie en native herstelproef staan in `TRIM_INTEGRALE_RELEASE_HERSTELPROEF_20261104.md`. Die notitie benoemt ook de nog te verbinden Linux/gatewayroute en scheidt deze technische restpost van de officiële 2026-levering en inhoudelijke intervalvrijgave. Geen los HTML-bestand publiceren buiten deze gezamenlijke controle.

## Officiële Avimap-kavelgrenzen en jaaroppervlakten van 18 november 2026

Gebruik voor de integrale actualisering de 55 Avimap-plot-ID’s van project 252 en de op acht decimalen afgeronde km²-oppervlakten uit de levende tabel `plot_jaar_oppervlak`. De 3.960 regels voor 1984–2055 behoren tot deze oppervlakteversie, met 55 kavels per jaar. Daaronder vallen de 29 aangevulde regels voor M84s in 2027–2055 van elk 0,42940063 km². De GeoJSON voor beide websitekaarten heeft SHA-256 `43d8065465963871527b8c3c77e88c584c2cbee22f0276b8400444e92ceb733a`.

Bouw bij vrijgave van de 2026-invoer de SQL-export, dichtheidsgrafieken en gedeelde dashboard- en Shiny-uitvoer opnieuw uit dezelfde bronstand. Neem de exporthash en de GeoJSON-hash op in het bewijs, vergelijk de drie afnemers en behoud de soortselectie, uitvalstatus en bestaande intervalpoorten. De geometriekeuze voor ruimtelijke databasekoppelingen vergt afzonderlijke validatie. De 55 officiële RD New-bronpolygonen zijn geldig. Bij de omzetting naar WGS84 kregen M7, M16s, M33, M34, M63, M65, M66 en M85 zelfkruisingen. GEOS MakeValid splitste de kruisende ringen in geldige polygonen voor de webweergave. De 47 overige webcontouren en de 55 bronattributen zijn behouden. Voor de acht herstelde contouren verschilt na terugprojectie samen 44,87 m² van de officiële RD New-vlakken. Het grootste verschil ligt bij M33, met 38,60 m² en een maximale contourafstand van 1,24 m. Gebruik voor ruimtelijke bewerkingen de officiële RD New-laag.

TDWG-toets op 18 november 2026. In [Darwin Core](https://dwc.tdwg.org/terms/#location) is het kavel een Location, waarvan de ongewijzigde plot-ID aansluit bij locationID. Voor uitwisseling sluiten de grens en het CRS aan bij footprintWKT en footprintSRS, en het oppervlak met eenheid bij measurementType, measurementValue en measurementUnit. Jaaroppervlakten blijven een meting bij een locatie en jaar. [TCS, versie 11 december 2025](https://tcs.tdwg.org/terms/) betreft taxonconcepten, namen en conceptrelaties. Deze wijziging raakt geen taxonidentiteit of taxonkoppeling.

## Sovon-herlevering BMP 2024 en 2025 voor vier kavels

De levende bron voor M71, M72, M16s en M15 bevat de op 18 november 2026 hergeleverde waarden. Neem bij de integrale actualisering de 34 bronbezoeken met code `sovon_bmp_grenscorrectie_kopie` en hun gecorrigeerde punten mee. Shiny en Vandaag in Meijendel weren die broncode uit de zelfstandige bezoekfrequentie, inspanning en detectie. Controleer bij de geplande export-, proefimport- en cachebouw dat de 79 oorspronkelijke veldbezoeken voor de vier kavels in 2024–2025 meetellen en de 34 kopieën beschikbaar zijn als bronspoor. De vier kavels tellen 552 territoria in 2024 en 497 in 2025. Vergelijk ook per soort en kavel met de geaccepteerde herlevering. Verwerk de gewijzigde aantallen in de website-, dashboard- en Shiny-keten met behoud van soortstatus en intervalpoorten. De achttien overige verschillen en de 2026-tellingen hebben hun eigen beoordelingspoort.

## Lokale BMP-bronstand 19 november 2026

De lokale MySQL-invoer bevat 4.570 territoriumregels voor 50 kavels: 8.874
territoria en 2.800 expliciete nullen. De officiële status van M4-5 en M105
Hertenkamp blijft naast Tons voorlopige toelating zichtbaar. Hercontroleer die
status begin januari 2027. M78/79 levert nul territoriumregels. Zijn vier
bezoeken en DAZ blijven beschikbaar.

Controleer bij een afzonderlijk goedgekeurde dump/cachebouw ook de 524
bezoek-ID’s, de 17 bezoekkopieën, de 40.073 vogelstippen en de 811
niet-vogelpunten. De zes gelijktijdige bezoekparen met verschillende tracks
en zonder gedeelde stippen blijven kavelbezoeken. Gebruik voor 2026 de
geaccepteerde DAZ-uitkomsten in de vijf soortgroeptabellen. De voorlopige
Sovon-laag levert geen extra uitkomsten. De gekopieerde bezoeken horen
beschikbaar te blijven als bronspoor en tellen niet zelfstandig mee voor
veldinspanning. Gebruik voor de standaardtrends de Natura 2000-scope, inclusief
uitsluiting van M66 en M91. Broncontrole, formele intervalvrijgave en
publicatie blijven afzonderlijke stappen.

## Lokale TRIM-broncontrole en pilot van 19 november 2026

De SQL-bron voor deze proef heeft SHA-256
`3b590fa1987469e8c0d0d71ba4d0976f256ead9271e17311e81d6ec84777cedc`.
De Natura 2000-selectie voor 2026 bevat 8.472 territoria en 2.694 formele
Sovon-nullen in 48 kavels. Daarvan vallen 203 nullen buiten de
156 vogelcategorieën met een geaccepteerd positief resultaat in 1958–2026.
De soortmatrix gebruikt 2.491 bronnullen voor 2026. M78/79 levert geen
modelwaarde. De voorlopige toelating van M4-5 en M105 blijft zichtbaar.
In 1958–2026 zijn er 53 kavelclusters, waarvan 17 in de historische kern.
M84s treedt in 2026 toe. De primaire brugset bevat 33 kavels, de strikte
zesjaarsset 20.

De runbundel `trim-2026-20261119-lokale-proef` gebruikt R 4.5.3,
rtrim 2.3.1 en de bestaande jaarlijkse TRIM-brug. Trekkingen 1 en 2 zijn
onafhankelijk herhaald en leveren exact gelijke resultaten. Alle 50
trekkingen zijn op één iMac-worker voltooid, zonder batchfouten.
Van de 69 soorten met een formele primaire brug in de uitgangsberekening
halen 57 de vereiste 95% geldige trekkingen. De overige 12 vallen vooral
uit bij jaren zonder positieve tellingen in de getrokken reeks. Geen
van de 31 groepen met vaste soortensamenstelling haalt de drempel.
De beste vaste groep haalt 37/50. Bij uitval ontbreekt een vereiste
soortreeks. Alle 31 groepen met wisselende samenstelling halen 50/50
binnen de gevoeligheidsanalyse.

De gezamenlijke geldigheidspoort voor 500 sluit. Neem vóór een vervolg
een methodisch besluit over de vaste groepssamenstelling en de
soortschatters die onvoldoende geldige trekkingen hebben. Bewaar alle
156 categorieën en hun uitvalstatus. Bundelmanifest, batchchecksums,
validiteit per schatter en bron-/brugcontrole staan in de geregistreerde
T7-proef `trim-bmp-2026-bronproef-20261119`. De 50-pilot levert geen
formele intervalvrijgave of actieve uitvoer voor website, dashboard en
Shiny.

## Afzonderlijke TRIM-perioden voor twaalf soorten

De op 19 november 2026 vastgelegde 1958–2026-bron is voor de twaalf
uitvallende lange soorttrends opnieuw gebruikt. Voor 1958–1983 en
1984–2026 zijn de modellen afzonderlijk berekend. Elke soort-periode
behoudt haar modeljaren uit de uitgangsfit. De 500 gezamenlijke trekkingen
gebruiken 53 kavelgeschiedenissen, dezelfde seed als de 2026-pilot en één
iMac-worker. De eerste 50 kavelsteekproeven sluiten exact aan op de
eerdere pilot. De uitkomsten van de eerste twee trekkingen zijn exact
gereproduceerd. Alle 12.000 periode-uitkomsten en 50 batchchecksums zijn
onafhankelijk gecontroleerd.

Elf van de 24 afzonderlijke jaarlijkse TRIM-trends halen de lokale
drempel van minimaal 475 van 500 geldige trekkingen. Vijf liggen in
1958–1983 en zes in 1984–2026. Bij elf van de dertien perioden onder de
drempel is een nuljaartotaal de voornaamste uitvalreden of blokkeert het
de uitgangsfit. Bij de andere twee gaat het om te weinig actieve
kavels of ongeldige jaartotalen. Bij vier van de elf perioden boven de
drempel omvat het TRIM-interval uit de uitgangsfit nul. De jaarlijkse
diagnostische bootstrapband is alleen voor Dodaars 1958–1983 en Vink
1984–2026 op beide vergelijkingsstappen numeriek stabiel. Voor de aparte
nettoverandering tussen vijfjaarsvensters geldt dat voor geen van de 24
perioden. Er is geen formele bootstrapintervalvrijgave.

De soortinventaris behoudt alle 156 vogelcategorieën, de bestaande
ecologische groepstoewijzing, territoriumtotalen en teldekking per
periode. De dertien getoetste perioden onder de drempel krijgen een
expliciete status zonder trendwaarde in het soortenoverzicht. De
overige 144 soorten blijven zichtbaar en vallen buiten deze gerichte
validatie. De 500-validatie van de lange trends en vaste groepen blijft
afhankelijk van het eerder vastgelegde methodische besluit.
De 24 perioderegels en de volledige soorteninventaris staan in de
geregistreerde T7-proef `trim-bmp-2026-perioden-12-soorten-20261119`.

## Groepsproef met echte nullen voor 1958–2026

De negen bestaande ecologische hoofdgroepen zijn met dezelfde leden
afzonderlijk getoetst voor 1958–1983 en 1984–2026. De kandidaat is een
Poisson-telindex met een eigen uitgangsniveau per soort-kavelcombinatie,
kaveloppervlakte als offset en één gemeenschappelijke jaarfactor per groep.
Een letterlijke of volgens de bestaande bronregel toegelaten nul blijft nul.
Een ontbrekende soort-kavel-jaarcel levert geen blootstelling aan het model.
De vaste groepsindeling blijft intact. Een soort-kavelreeks zonder positieve
telling of zonder tweede meetjaar levert geen informatie over verandering.
Het soortenoverzicht bevat alle 156 categorieën, waaronder de negen zonder
bestaande EVG-hoofdgroepkoppeling.

De proef bevat 18 groepsperiodes en 621 jaarwaarden. Alle 18 zijn in 50 van
50 gezamenlijke trekkingen volledig berekenbaar. Bij de test op vijf
afzonderlijk achtergehouden kavelsets voorspelt de jaarfactor in vier of vijf
sets beter dan een vlakke jaarfactor voor 12 van de 18 periodes. Bij elf
blijft ook de richting van de vijfjaarsverandering gelijk wanneer de invloed
per soort wordt gelijkgetrokken of de meest getelde soort voor de
gevoeligheidscontrole wegvalt. De richting wisselt bij vogels van
pionierbegroeiingen en open heide in 1958–1983 en bij bosrandvogels en
bosvogels in 1984–2026. De hoofduitkomst blijft gevoelig voor soorten met
veel territoria. De proef ondersteunt deze index als diagnostische
aantalsindicator naast het soortenoverzicht.

In de bron tot en met 2026 zijn er geen groepsjaren waarin de geschatte index
nul is. Een gecontroleerde proef met een volledig nuljaar en een ontbrekend
jaar bevestigt afzonderlijk dat de rekenroute exact nul en ontbrekend kan
onderscheiden. Een tweede proef reproduceert de jaarfactoren van een
Poisson-GLM. Volledige tabel, kavelvalidatie, gewichtsgevoeligheid, 50
trekkingen en 156 soorten staan in de geregistreerde T7-proef
`trim-bmp-2026-groepsindex-nullen-20261119`.

De eerdere 2.000 trekkingen betroffen de diagnostische soortanalyses tot en
met 2025.

### Vergelijking met gelijke invloed per soort

Op dezelfde bron van 1958–2026 zijn de negen bestaande ecologische groepen
per periode vergeleken. Beide indexen delen één jaarfactor per groep, met
een afzonderlijk niveau per soort en kavel. Voor de gelijkgewogen index
telt elke informatieve soort in de schatting even zwaar. Een soort-kavelreeks
draagt bij vanaf twee getelde jaren en minstens één positieve telling.
De normalisering wordt bij iedere kaveltrekking en toets opnieuw berekend.
Getelde nullen blijven in die reeksen staan. Het gemiddelde van de eerste
vijf jaar per periode is 100. De tabel vergelijkt het gemiddelde van de
laatste vijf jaar met dat begin.

| Ecologische groep | Periode | Aantalsindex | Gelijke soortweging |
| --- | --- | ---: | ---: |
| Vogels van pionierbegroeiingen | 1958–1983 | +1.818% | −51% |
| Bosrandvogels | 1984–2026 | −21% | +24% |
| Bosvogels | 1984–2026 | +22% | −20% |

Alle 18 groepsperioden zijn voor beide indexen berekenbaar in alle 50
gepaarde kaveltrekkingen. Op achtergehouden kavels wint de aantalsindex
van een vlakke lijn in minimaal vier van vijf toetsen voor 12 van de 18
groepsperioden, gemeten per territorium. De gelijkgewogen index haalt
die drempel voor 5 van de 18, gemeten per soort. Bij een rechtstreekse
vergelijking per soort wint de gelijkgewogen index in minimaal vier
van vijf toetsen bij 5 groepsperioden, de aantalsindex bij 6. Per
territorium wint de aantalsindex bij 16 van de 18 groepsperioden.

Voor de gelijkgewogen index combineren vijf groepsperioden winst op
achtergehouden kavels, dezelfde richting in minimaal 48 van 50 trekkingen
en dezelfde richting bij iedere afzonderlijke soortweglating. Het gaat om
watervogels en struweelvogels in 1958–1983 en om vogels van
pionierbegroeiingen, weidevogels en struweelvogels in 1984–2026.
De richting voor rietvogels in 1984–2026 blijft in 33 van 50 trekkingen
gelijk en wisselt als Porseleinhoen, Snor of Grote Karekiet afzonderlijk
wordt weggelaten.

Alle 156 soorten staan met hun bestaande indeling en trendstatus in het
soortenbestand. Negen hebben geen toewijzing aan deze ecologische groepen.
Van de 147 toegewezen soorten dragen er 114 in 1958–1983 en 146 in
1984–2026 bij aan minstens één groepsschatting. Dit staat los van de
validatie van hun afzonderlijke soorttrend.

De aantalsindex blijft kandidaat voor ontwikkelingen in territoria.
Gelijke soortweging is als aanvullende ecologische vergelijking getest.
Voor formele opname in de gedeelde uitvoer voor website, dashboard en
Shiny staan selectie en schattergebonden intervalvrijgave open. De 50
trekkingen zijn diagnostisch. Jaarwaarden, vijf kaveltoetsen per
groepsperiode, 376 soortweglatingen, beide indexen en het soortenoverzicht
staan in de geregistreerde T7-proef
`trim-bmp-2026-groepsindex-gelijke-invloed-20261119`.


### Aantalsindex als hoofdindex, validatie met 2.000 kaveltrekkingen

Ton kiest de aantalsindex als hoofdindex voor de bestaande negen ecologische
groepen. De gelijkgewogen variant blijft een gevoeligheidsvergelijking. De
aantalsindex gebruikt dezelfde getelde nullen, kavels en groepstoewijzingen als
de proef met 50 trekkingen. Elke van de 2.000 gezamenlijke trekkingen bevat
17 historische en 36 latere kavelclusters, met teruglegging binnen elk
stratum. Alle 36.000 fits over de 18 groepsperioden zijn volledig. Alle 621
puntschattingen en de eerste 50 eindveranderingen per groepsperiode zijn
gereproduceerd. De 156 soortregels, inclusief trendstatus en de negen soorten
zonder ecologische groep, zijn bytegelijk aan de vorige proef.

De toets voor een ondersteunde richting vraagt minimaal 1.900 volledige
trekkingen, winst tegen een vlakke lijn in minstens vier van vijf tests
op achtergehouden kavels, hetzelfde teken buiten nul in het centrale
95%-bootstrapbereik van zowel de volledige run als beide helften en behoud
van richting bij het weglaten van elke informatieve soort afzonderlijk.
Van de 18 groepsperioden halen er 12 alle criteria, zes per periode.

| Periode | Groep met onvoldoende steun voor de richting | Toets die uitvalt |
| --- | --- | --- |
| 1958–1983 | Watervogels | Kaveltoets en bootstrapbereik |
| 1958–1983 | Vogels van open heide | Kaveltoets, bootstrapbereik en soortweglating |
| 1958–1983 | Vogels van bebouwing/overige | Kaveltoets |
| 1984–2026 | Watervogels | Kaveltoets |
| 1984–2026 | Bosrandvogels | Kaveltoets en soortweglating |
| 1984–2026 | Bosvogels | Kaveltoets en soortweglating |

De geregistreerde proef `trim-bmp-2026-aantalsindex-2000-20261119` bevat
de jaarlijkse hoofdindex, de twee periode-uitkomsten per groep, alle
trekkingen, het soortenoverzicht en het hashgebonden kandidaatmanifest
voor de gezamenlijke 2026-uitvoer. De beginwaarde is per periode het
gemiddelde over de eerste vijf jaar. De eindverandering vergelijkt daarmee
het gemiddelde over de laatste vijf jaar. Jaarpercentielen zijn puntgewijs.
De zes groepsperioden blijven zichtbaar met hun toetsstatus. De gezamenlijke
lokale previewtoets is uitgevoerd. Formele intervalvrijgave en productie
staan open. Zie [Lokale aansluiting bootstrap](TRIM_RELEASE_2026_AANSLUITING.md).
