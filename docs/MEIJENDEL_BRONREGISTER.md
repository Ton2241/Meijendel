# Bronregister ecologische gegevens Meijendel

## Doel

Dit register geeft in gewone taal antwoord op vier vragen:

1. Welke ecologische gegevens over Meijendel zijn bekend?
2. Waar staan zij nu?
3. Wie beheert de oorspronkelijke bron?
4. Waarvoor kunnen de gegevens statistisch wel en niet worden gebruikt?

Het register beschrijft meet- en waarnemingsbronnen en de belangrijkste
verklarende omgevingslagen, geen afzonderlijke soorten. Taxonomische
referentietabellen, berekende analyse-uitkomsten en technische hulptabellen
vallen buiten dit overzicht. Details over tabellen, imports en protocolcodes
staan in de achterliggende projectdocumentatie. De stand is
**25 september 2026**.

## Hoe de statussen moeten worden gelezen

- **Analyseklaar**: de meetlocaties, bezoeken, methode en uitkomsten zijn
  voldoende bekend voor de genoemde analyses. Rekening houden met veranderingen
  in methode en dekking blijft nodig.
- **Voorwaardelijk bruikbaar**: positieve waarnemingen zijn bruikbaar, maar voor
  trends ontbreekt nog een deel van de oorspronkelijke meetstructuur.
- **Context**: de bron is inhoudelijk relevant, maar mag niet in de gewone
  Meijendel-analyses worden gebruikt omdat de locatie per waarneming ontbreekt.
- **Kandidaatbron**: de bron is gevonden, maar nog niet volledig gecontroleerd
  op locatie, overlap, rechten en statistische betekenis.

Een statistisch bruikbare reeks bewijst niet vanzelf dat een verandering door
beheer is veroorzaakt. Daarvoor moeten ook andere factoren, zoals vegetatie,
water, weer, begrazing, predatie en onderzoeksinspanning, worden meegewogen.

In één oogopslag:

- de vogelreeks, provinciale PQ-reeks, bevestigde SOVON-zoogdierbezoeken en
  historische vangblikreeks zijn nu de sterkste statistische bronnen;
- de NDFF-laag is omvangrijk, maar ondersteunt zonder aanvullende
  meetstructuur vooral verspreidingsonderzoek;
- `Meijendel_bronnen` bevat drie contextdatasets en 522
  literatuurverwijzingen die niet ongemerkt in analyses terecht mogen komen;
- de gevonden externe datasets zijn nog kandidaten en worden pas na een
  afzonderlijke toelatingscontrole geïmporteerd.

Met **beheerder** wordt hieronder de primaire bronorganisatie of uitgever
bedoeld voor zover die nu bekend is. Het is geen afzonderlijke uitspraak over
juridisch eigendom of auteursrecht.

## 1. Bronnen in de analytische database `Meijendel`

### Vogelgegevens van Vogelwerkgroep Meijendel en SOVON

**Omvang en periode.** De database bevat 1.063.936 vogelwaarnemingen uit
1958–2025. De oorspronkelijke telgebieden, bezoeken, protocollen en aantallen
zijn beschikbaar.

**Beheerder.** Vogelwerkgroep Meijendel en SOVON.

**Gebruik.** Dit is de meest complete langjarige reeks. Trends,
verspreidingsveranderingen, fenologie en relaties met vegetatie, weer en beheer
kunnen verantwoord worden onderzocht, mits veranderingen in methode en dekking
expliciet worden verwerkt. De gegevens zijn niet zonder aanvullend ontwerp een
bewijs voor een causaal beheereffect.

**Status.** Analyseklaar en primaire bron.

### Provinciale permanente kwadraten

**Omvang en periode.** De primaire levering van Provincie Zuid-Holland bevat
254 permanente kwadraten, 2.007 vegetatieopnamen en 53.122 taxonregels uit
1981–2025.

**Beheerder.** Provincie Zuid-Holland.

**Gebruik.** De reeks ondersteunt analyses van vegetatiesamenstelling,
bedekking, successie en verandering per permanent kwadraat. De provinciale
gegevens blijven leidend; overeenkomende NDFF-regels worden niet als een tweede
waarneming geteld.

**Status.** Analyseklaar en primaire bron.

### Zoogdieren tijdens SOVON- en VWG-bezoeken

**Omvang en periode.** De primaire SOVON-levering bevat 19.877
zoogdierwaarnemingen uit 2009–2026. De analysematrix omvat 4.354 bevestigde
bezoeken, 30.478 combinaties van bezoek en doelsoort en 23.619 afgeleide
nulwaarnemingen. De 807 regels uit 2026 behoren tot een nog niet afgerond jaar.

**Beheerder.** SOVON en Vogelwerkgroep Meijendel.

**Gebruik.** Voor de tijdens deze bezoeken gevolgde zoogdieren, waaronder het
konijn, zijn analyses van trefkans, verspreiding en ontwikkeling mogelijk.
Bezoeken zonder enige zoogdierregistratie gelden niet automatisch als een
bezoek waarop systematisch naar zoogdieren is gekeken.

**Status.** Analyseklaar binnen deze afbakening; de primaire SOVON-bron gaat
voor eventuele overeenkomstige NDFF-regels.

### Historisch vangblikonderzoek

**Omvang en periode.** De GBIF-dataset *Meijendel research 1953–1960* bevat
37.770 vangblikevents, 60.560 vangsten, 275 taxa en 99.652 individuen. Per event
zijn vangblik, datum, duur en locatie bekend.

**Beheerder.** De historische reeks is afkomstig uit het onderzoek van Piet den
Boer en is gepubliceerd als [GBIF Sampling Event Dataset](https://doi.org/10.15468/adsbxs).

**Gebruik.** Binnen 1953–1960 zijn analyses mogelijk van soortensamenstelling,
seizoensverloop en ruimtelijke verschillen. De reeks vormt geen doorlopende
trend tot 2025. Lege events zijn niet voor alle taxa een bewezen nul; ook zijn
verplaatsingen van vangblikken en een methodeproef in de kwaliteitsvelden
vastgelegd.

**Status.** Analyseklaar binnen de historische onderzoeksopzet.

### NDFF: één canonieke laag van openbare en beveiligde gegevens

**Omvang en periode.** De openbare levering bevat 810.830 unieke
niet-vogelrecords uit 1950–2025. De beveiligde levering bevat 14.573 records
voor 191 geselecteerde taxa. Daarvan vervangen 14.420 records hun openbare,
vervaagde tegenhanger en zijn 153 records alleen in de beveiligde levering
aanwezig. De gecombineerde laag telt daardoor 810.983 unieke waarnemingen.

**Beheerder.** NDFF is de gegevensbank. De oorspronkelijke gegevens komen van
verschillende meetnetbeheerders, terreinbeheerders en waarnemers.

**Gebruik.** De laag is geschikt voor geregistreerde aanwezigheid,
verspreidingspatronen, soortenlijsten, mogelijke hotspots en kennislacunes. Zij
is als geheel niet geschikt voor populatietrends: NDFF heeft niet van alle
bronorganisaties de vaste codes voor tellocaties, telroutes en bezoeken,
complete soortenlijsten, tellingen waarbij een soort niet werd aangetroffen en
informatie over veranderingen in methode of telinspanning ontvangen.

Alle NDFF-locaties zijn als polygonen met een onzekerheidsbuffer opgeslagen.
Een polygoon die een kavel raakt, bewijst daarom niet dat de soort in die kavel
is waargenomen. De onvervaagde gegevens voor kwetsbare soorten blijven lokaal
afgeschermd.

**Status.** Voorwaardelijk bruikbaar. De afzonderlijke herkenbare meetreeksen
worden hieronder samengevat.

| Herkenbare reeks in de NDFF-laag | Omvang en periode | Wat kan nu? | Wat ontbreekt voor zelfstandige trends? |
|---|---:|---|---|
| Dagvlinders | 82.217 records, 3.126 gereconstrueerde bezoeken, 1990–2025 | Positieve waarnemingen en voorlopige routeanalyses | Oorspronkelijke route- en bezoekcodes, complete bezoeken, gevolgde modules en tellingen zonder waarneming |
| Hommels | 1.535 records, 217 bezoeken, 2018–2025 | Positieve aanwezigheid per bezoek | Bevestiging dat hommels systematisch zijn geteld en op welk determinatieniveau |
| Libellen | 3.280 records, 461 bezoeken, 2007–2021 | Positieve aanwezigheid en voorlopige routevergelijking | Oorspronkelijke route- en bezoekstructuur en volledige doelsoortenlijst |
| Nachtvlinders | 596 records, 2019–2025 | Geregistreerde aanwezigheid per jaar en kilometerhok | Afzonderlijke vangnachten, telpunt, val, lamp, brandduur en lege vangnachten |
| Amfibieën | 2.519 records, 225 gereconstrueerde bezoeken, 2003–2025 | Positieve aanwezigheid per water of gebied, voor zover ruimtelijk herleidbaar | Oorspronkelijke water- en bezoekcodes, zoekmethode en volledige-lijststatus |
| Reptielen | 957 records, 660 gereconstrueerde bezoeken, 1990–2025 | Positieve aanwezigheid; beperkte nullen voor Hazelworm binnen bevestigde bezoeken | Ontbrekende bezoeken en volledige routeadministratie |
| Vissen | 20 protocolrecords in 6 bezoeken, 2014 | Alleen lokale verspreidingsinformatie | Te weinig bezoeken en geen volledige meetstructuur voor een lokale trend |
| Vleermuistransecten | 2.624 records, 44 bezoeken, 2013–2025 | Positieve aanwezigheid langs twee gereconstrueerde reeksen | Oorspronkelijke routes, secties, bezoeken en volledige resultaten |
| Konijnentellingen in de duinen | 5.809 records, 812 bezoeken, 1984–2023 | Aanwezigheids- en aantalscontext | Eerst overlap met de primaire SOVON- en VWG-reeks oplossen |
| Wintertellingen vleermuizen | 3.960 records, 1976–2025 | Positieve aanwezigheid per object en jaar, voor zover herleidbaar | Vaste object- en bezoekcodes en volledige tellingen |
| Het Nieuwe Strepen | 4.569 records, 23 lijstkandidaten, 2012–2024 | Voorlopige vergelijking van inventarisaties | Oorspronkelijke lijstcodes en bevestiging welke tellingen onafhankelijk zijn |
| FLORBASE en andere vaatplantinventarisaties | 21.374 records, 1974–2025 | Verspreiding en floristische context | Oorspronkelijke lijsten, onderzochte gebieden en volledige bezoekstructuur |
| LMF-aandachtssoorten | 5.980 records, 2000–2025 | Positieve aanwezigheid | Oorspronkelijke routes, bezoeken en gevolgde soortenlijst |
| Mossen en korstmossen | 761 records, 2000–2025 | Positieve aanwezigheid en voorlopige proefvlakvergelijking | Oorspronkelijke proefvlak-, lijst- en waarnemersgegevens |
| Bos- en zeereeppaddenstoelen | 4.720 records, 1999–2025 | Positieve aanwezigheid en voorlopige vergelijking van vaste meetpunten | Volledige bezoeken en het per teller gevolgde soortenbereik; geen vruchtlichaam is bovendien niet hetzelfde als geen mycelium |
| Weekdieren | 5.008 records, 1951–2024 | Verspreiding en historische context | Locatie-, monster- en bezoekcodes om systematische tellingen van losse meldingen te scheiden |
| SNL-gebiedsmonitoring | 6.273 records, 2007–2022 | Periodieke informatie over kwalificerende soorten | Beheertype, karteergebied, telronde, protocolversie en volledige uitslag; dit levert niet automatisch een jaarlijkse populatietrend op |

De overige NDFF-regels zijn losse of uitsluitend positieve registraties. Zij
blijven nuttig voor verspreiding, maar ontbreken mag daar nooit als afwezigheid
worden uitgelegd.

### Openstaande ruimtelijke toelatingscontrole

De bronregistraties staan wel in `Meijendel`, maar een deel mag nog niet als
waarneming binnen Meijendel worden gebruikt. De audit met de actuele
projectgrens vond 70.427 openbare NDFF-records uit de downloadselectie
1950–2025, 968 BMP-dagwaarnemingen uit 2009–2025, 644 provinciale PQ-opnamen
uit 1981–2025 en 14 primaire SOVON-bijvangsten uit 2009–2024 die buiten het
basisgebied liggen. Sommige NDFF-records hebben een breed broninterval dat al
vóór 1950 begint; dat maakt hen geen waarneming uit dat eerdere jaar. Daarnaast
raken 146.466 NDFF-polygonen alleen de grens. Bij die polygonen staat niet vast
dat de waarneming binnen Meijendel is gedaan.

Deze records blijven herkenbaar als bronmateriaal, maar worden niet zonder een
afzonderlijk ruimtelijk besluit in Meijendelanalyses gebruikt. Alle 37.770
vangblikevents en alle territoriumplots liggen binnen het basisgebied.

### Verklarende omgevingslagen

Deze gegevens zijn geen soortenwaarnemingen. Zij kunnen wel helpen om
ecologische veranderingen te beschrijven of als mogelijke verklaring te
toetsen.

| Bron | Eigenaar | Omvang en periode in de huidige SQL-dump | Gebruik en grens |
|---|---|---:|---|
| Dagelijks weer | KNMI, stations Valkenburg en Voorschoten | 24.837 dagregels, 1953–2026 | Temperatuur, neerslag, wind, zon en luchtdruk kunnen als covariaten worden gebruikt. Alleen de genormaliseerde analyseview is geldig; 2026 is nog niet compleet. |
| Hoogte | Actueel Hoogtebestand Nederland via PDOK | 55 plots, peiljaar 2025 | Beschrijft hoogte en hoogtevariatie per plot. Eén peiljaar geeft geen ontwikkeling door de tijd. |
| Stikstofdepositie | RIVM | 1.027 plot-jaarregels, 2005–2023 | Geschikt als mogelijke verklarende factor naast soorten- en vegetatiereeksen. Een samenhang bewijst niet dat stikstof de enige oorzaak is. |
| Bodemgebruik | CBS Bestand Bodemgebruik | 918 plot-jaar-klasseregels, 1996–2022 | Laat veranderingen in de ruimtelijke omgeving van plots zien. De meetjaren zijn niet jaarlijks beschikbaar. |
| Natura 2000-habitat | Habitatkartering 2014; bronhouderschap nog in de metadata te bevestigen | 384 plot-habitatregels uit 2014 | Geeft de verdeling van habitattypen binnen plots. Dit is één kaartjaar; de aangekondigde T1-kaart is nodig voor een directe vergelijking door de tijd. |

## 2. Bronnen in `Meijendel_bronnen`

Deze database bevat informatie die inhoudelijk bij Meijendel hoort, maar niet
aan de ruimtelijke toelatingsregel van de analytische database voldoet. Zij is
in het Analysecentrum raadpleegbaar, maar wordt niet automatisch in modellen of
kaarten uit `Meijendel` gebruikt.

| Bron | Beheerder | Omvang en periode | Waarde en beperking |
|---|---|---:|---|
| Duinvalleivegetatie | Openbare onderzoeksdataset, [Zenodo](https://doi.org/10.5281/zenodo.21796880) | 488 opnamen, 101.504 bedekkingsregels en 855 bodemmetingen; 2001, 2008 en 2018 | De volledige soortenmatrix en echte nullen maken vergelijking tussen de drie jaren mogelijk. De 186 locatiecodes zijn nog niet betrouwbaar aan geometrieën gekoppeld; daarom alleen context voor Meijendel als geheel. |
| Vogelstand 1924 | Vogelwerkgroep Meijendel | 204 regels uit 1924 | Historische vogelcontext. Zonder locatie per regel geen kavel- of ruimtelijke analyse. |
| Jachtspinnen | Van der Aart en Smeenk-Enserink | 3.337 exemplaren, 12 soorten en 28 locaties; 1969–1970 | De vangstmatrix kan inhoudelijk worden onderzocht. De 28 locatienummers zijn nog niet naar werkelijke plaatsen te vertalen en mogen daarom niet als Meijendelwaarnemingen worden geanalyseerd. |
| Literatuuroverzicht | Zotero-collectie `Meijendel` | 522 bibliografische verwijzingen op 25 september 2026 | Zoekingang naar onderzoek en historische context. Dit zijn verwijzingen, geen waarnemingsregels; volledige teksten blijven in Zotero en worden niet op de VPS gekopieerd. |

## 3. Geïdentificeerde externe kandidaatbronnen

Deze bronnen zijn gevonden, maar nog niet toegelaten. De genoemde aantallen
hebben betrekking op de al gemaakte Meijendelselectie of op de beschreven
onderzoeksopzet. Voor iedere import volgt eerst controle van locatie per
waarneming, overlap met bestaande bronnen, rechten en statistische betekenis.

### Kandidaten met de grootste verwachte aanvulling

| Bron | Eigenaar of uitgever | Omvang en periode | Mogelijke meerwaarde | Belangrijkste controle vóór opname |
|---|---|---:|---|---|
| [Dutch Vegetation Database](https://doi.org/10.15468/ksqxep) | Wageningen Environmental Research | Meijendelselectie: 5.195 opnamen, 119.006 taxonregels en 1.132 taxa; 1930–2015 | Rijke historische vegetatieopnamen met opnameoppervlak, bedekking en protocol | Overlap met provinciale PQ en NDFF verwijderen; 1.758 opnamen hebben een locatie-onzekerheid groter dan 50 meter |
| STOWA Limnodata | STOWA; gegevens van Hoogheemraadschap van Delfland en Rijnland | 1.036 taxonregels, 44 bemonsteringen en 7 stationcodes op 6 locaties; 1992–2010 | Aquatische flora en fauna op herhaalde locaties | Eenheden en methoden per reeks scheiden; de levering bevat alleen positieve regels en geen bewezen nullen |
| [ENDURE helmduinfauna](https://doi.org/10.15468/xx2gcp) | Universiteit Gent en ENDURE | 15 exacte meetpunten in 2018; 14 complete matrices, 71 positieve en 9.001 negatieve taxonuitkomsten | Gestandaardiseerde momentopname van ongewervelden in witte duinen en een herhaalbare nulmeting | Eén event zonder soortenmatrix apart houden; geen tijdtrend afleiden uit één meetjaar |
| Historische en actuele ringgegevens | Vogeltrekstation/NIOO-KNAW | Biometrie: 100.417 records van 163 soorten, 1963–2023; historische nestjongen: 668 records van 38 soorten, 1928–1957 | Trektijd, conditie, biometrie en vroeg-historische vogelcontext | Vangplaatscodes, locatie-onzekerheid, inspanning en overlap met bestaande vogelgegevens controleren |
| Bijenmonitoring in vier beheergebieden | EIS Kenniscentrum Insecten | 18 proefvlakken, drie bezoeken per onderzoeksjaar; 162 bezoeken in 2019, 2021 en 2023 | Vergelijking van bijengemeenschappen tussen gebieden en jaren | Tabellen uit rapporten digitaliseren, proefvlakken georefereren en nagaan of 2025 beschikbaar is |

### Afgebakende onderzoeksdatasets

| Bron | Eigenaar of uitgever | Omvang en periode | Statistische betekenis en beperking |
|---|---|---:|---|
| TERRA-Dunes plant- en bodemmicrobiomen | Onderzoeksteam TERRA-Dunes, [Figshare](https://doi.org/10.6084/m9.figshare.25425601.v1) | 94 proefvlakken; planten 2018–2021 en bacteriën/schimmels 2018–2020 | Geschikt voor samenhang tussen vegetatie en microbiomen. Niet toelaten voordat de proefvlakken geografisch zijn gereconstrueerd. |
| Rups- en bodemmicrobiomen | Onderzoeksteam, [Dryad](https://doi.org/10.5061/dryad.8cz8w9gnc) | 56 Meijendelse monsters in 2020: 29 rupsen en 27 bodemmonsters; 29 exacte GPS-locaties | Eenmalige genetische en microbiële momentopname. Geen populatietrend, wel lokale ecologische vergelijking na controle van alle monsterlocaties. |
| Schimmels bij kruipwilg | Onderzoeksteam, [PLOS ONE/ENA](https://doi.org/10.1371/journal.pone.0099852) | Twee proefvlakken, ieder samengesteld uit 20 bodemkernen; maart 2010 | Bruikbaar als lokale microbiële referentie, niet als tijdreeks of gebiedsdekkende inventarisatie. |
| Bodemvocht en weer | Wageningen University & Research, [DANS](https://doi.org/10.17026/DANS-28X-UT8Q) | 10 bodemvochtloggers en één weerstation; metingen per vijf minuten van juli tot december 2020 | Gedetailleerde korte tijdreeks voor hydrologische processen. Eerst locaties en meetkwaliteit controleren; één halfjaar geeft geen langjarige ontwikkeling. |
| Genetische datasets amfibieën | Verschillende onderzoeksteams, Figshare | Kamsalamander: 22 monsters op 5 locaties; boomkikker: 18 monsters op benoemde locaties | Bruikbaar voor populatiegenetische context. Jaar, locatie en relatie met bestaande RAVON-waarnemingen moeten eerst worden vastgesteld. |

### Alleen context of nog een onderzoeksaanwijzing

- **Twee-spintmijt:** 573 mijten uit 2015–2017 op 18 genummerde locaties.
  Zonder vertaling van `MEY1–18` naar werkelijke locaties blijft dit een
  kandidaat voor `Meijendel_bronnen`.
- **Bitterzoet-genetica:** 47 Meijendelse monsters, maar geen individuele
  veldlocaties. Alleen context zolang die locaties ontbreken.
- **Sluipwesp *Tetrastichus coeruleus*:** 21 Meijendelse vrouwtjes zonder
  bruikbare locatie- en datuminformatie. Alleen context.
- **Twee losse GBIF-events van Roel van Klink:** 22 voorkomensrecords uit 2011
  en 2023, met 200 meter tot 5 kilometer locatie-onzekerheid. Alleen positieve
  verspreidingscontext en waarschijnlijk beperkte meerwaarde naast NDFF.
- **Remote sensing van vegetatiehoogte en -bedekking:** WUR beschreef kaarten
  voor 2008 en 2014; TU Delft beschreef elf beeldmomenten uit 2019–2021. De
  afgeleide rasterbestanden zijn nog niet als openbare dataset gevonden.
- **KWR-onderzoek:** rapporten wijzen op aanvullende vegetatie-, bodem- en
  hydrologische gegevens. Een afzonderlijke digitale gegevenslevering is nog
  niet gevonden.

## 4. Verwachte aanvullingen

- **Vlindergegevens:** De Vlinderstichting verwacht in de week van
  28 september 2026 aanvullende meetstructuur te kunnen leveren. Die levering
  wordt eerst vergeleken met de 82.217 NDFF-dagvlinderrecords en de bestaande
  routeconstructie.
- **Overige meetnetten:** de overige aangeschreven bronorganisaties hebben op
  25 september 2026 nog niet inhoudelijk gereageerd. Nieuwe leveringen worden
  niet automatisch geïmporteerd, maar eerst gecontroleerd op dekking, sleutels,
  nullen, inspanning en overlap.
- **Habitatkaart T1:** Provincie Zuid-Holland heeft toegezegd de kaart te delen
  zodra zij later in 2026 beschikbaar komt. De kaart kan veranderingen in
  habitat helpen verklaren, maar is zelf geen soortenwaarneming.

## 5. Bronnen die niet verder worden uitgewerkt

Drie eerder gevonden publicaties bleken bij controle geen Meijendelgegevens te
bevatten: een macrofaunastudie uit de Drentsche Aa, een voedselwebstudie aan
Amerikaanse vogelkers in Zuid-Kennemerland en een studie naar vliegtuiggeluid
bij Tjiftjaf. Zij worden niet als kandidaatbron beschouwd.

Algemene verzamelbronnen zoals Observation.org, iNaturalist en eBird worden ook
niet opnieuw als zelfstandige Meijendelbron ingevoerd zolang niet is aangetoond
dat zij waarnemingen bevatten die ontbreken in NDFF of in de primaire
VWG/SOVON-reeksen. Anders zou dezelfde waarneming vooral nogmaals worden
opgeslagen.

## 6. Gebruik van dit register

Dit document is het beslisoverzicht. Een bron gaat pas naar `Meijendel` wanneer
per waarneming vaststaat dat zij in Meijendel is gedaan en de locatie bekend of
betrouwbaar herleidbaar is. Is dat niet zo, dan blijft zij kandidaat of context
in `Meijendel_bronnen`.

Bij iedere nieuwe levering worden achtereenvolgens gecontroleerd:

1. welke waarnemingen en perioden werkelijk nieuw zijn;
2. of locaties en oorspronkelijke sleutels bruikbaar zijn;
3. of bezoeken, soortenlijsten en echte nullen aanwezig zijn;
4. of de bron een bestaande primaire reeks overlapt;
5. welke analyses daardoor verantwoord mogelijk worden.

Pas daarna volgt een afzonderlijk importbesluit.

## Achterliggende verantwoording

- [NDFF-staging en bronvergelijking](NDFF_STAGINGDATASET.md)
- [NDFF-protocolaudit](NDFF_PROTOCOLAUDIT.md)
- [Scheiding tussen Meijendel en Meijendel_bronnen](MEIJENDEL_BRONNEN.md)
- [Ruimtelijke audit van contextbronnen](MEIJENDEL_BRONNEN_AUDIT.md)
