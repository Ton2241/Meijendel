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
**26 september 2026**.

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

## Beheerregel

Dit is een levend register. Iedere ontdekking, levering, import, verplaatsing,
uitsluiting of nieuwe beoordeling van een Meijendel-gegevensbron wordt meteen
in dit document verwerkt. Dat geldt ook wanneer eigenaar, omvang, periode,
locatiekwaliteit, rechten, overlap, validatiestatus of statistische
bruikbaarheid verandert. Daarbij worden steeds de analytische database
`Meijendel`, de contextdatabase `Meijendel_bronnen` en de kandidaatbronnen
gezamenlijk gecontroleerd. Deze Markdown-versie is leidend; de Wordversie wordt
in dezelfde wijziging inhoudelijk gelijkgetrokken, gerenderd en gecontroleerd.

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
| Duinvalleivegetatie | Openbare onderzoeksdataset, [Zenodo](https://doi.org/10.5281/zenodo.21796880) | 488 opnamen en 101.504 bedekkingsregels; 2001, 2008 en 2018. Van de 186 vaste `Site`-codes zijn er 116 driemaal en 70 tweemaal onderzocht. Negen bodemvariabelen zijn voor 45 plots in 2001 en 2018 beschikbaar; bodemvocht alleen voor deze 45 plots in 2018. | De volledige matrix van 208 taxa bevat echte nullen en maakt vergelijking tussen de drie jaren mogelijk. De locatiecodes zijn nog niet betrouwbaar aan geometrieën gekoppeld. Opname `18I01` blijft uitgesloten: daarin zijn 159 taxa geregistreerd, tegenover maximaal 40 in alle overige opnamen. Deze reeks blijft afzonderlijk van de provinciale PQ-reeks. |
| Vogelstand 1924 | Vogelwerkgroep Meijendel | 204 regels uit 1924 | Historische vogelcontext. Zonder locatie per regel geen kavel- of ruimtelijke analyse. |
| Jachtspinnen | Van der Aart en Smeenk-Enserink | 3.337 exemplaren, 12 soorten, 28 locaties en zes milieuvariabelen; 1969–1970 | De samengevoegde vangstmatrix ondersteunt een soorten-milieuanalyse, maar geen ontwikkeling door de tijd. Datums en vangrondes ontbreken. De 28 locatienummers zijn bovendien nog niet naar werkelijke plaatsen te vertalen en mogen daarom niet als Meijendelwaarnemingen worden geanalyseerd. |
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
| [Aquatische macrofauna](https://repository.naturalis.nl/pub/643552/Nieukerken_Doctoraalverslag_Meijendel_1978.pdf) | Rijksuniversiteit Leiden; publicaties en collecties via Naturalis | Zeven vaste monsterpunten, vrijwel maandelijks onderzocht van juni 1974 tot juli 1975. Aanvullende publicaties bevatten gedateerde waarnemingen van waterwantsen uit 1920–1930, 1953–1961 en 1970–1977, waterkevers uit 1969–1977 en libellen uit 1849–1976, deels gekoppeld aan benoemde of gecodeerde wateren. | Historische reeks van waterorganismen, vegetatie en fysisch-chemische waterkenmerken | Eerst de tabellen, watercodes en collectieregistraties samenbrengen. Daarna per monster vaststellen welke locatie, datum, methode en volledige soortenlijst beschikbaar zijn en overlap met NDFF verwijderen. |
| Erosiepinnen in een stuifkuilcomplex | Jungerius en Van der Meulen | 48 erosiepinnen in 12 eenheden, vrijwel wekelijks gemeten gedurende één jaar | Gedetailleerde processtudie van erosie, sedimentatie en vegetatie, maar geen langjarige trend | Oorspronkelijke metingen en pinlocaties vinden en op waarnemingsniveau aan Meijendel koppelen |
| Langjarige droge-duinvegetatieplots | Historische Meijendel-onderzoekers; later ontsloten via Wageningen University & Research | 41 vaste vegetatieplots, aangelegd in 1952–1953 en gemiddeld ongeveer iedere vier jaar herhaald | Potentieel zeer waardevolle langjarige vegetatiereeks voor successie, begrazing en verandering van grijs duin | Oorspronkelijke plotcodes, opnamen en locaties vinden; overlap met provinciale PQ, NDFF en de Landelijke Vegetatie Databank vaststellen |

### Historische museum- en publicatiereeksen

Deze bronnen waren nog niet in het register opgenomen. De aantallen hieronder
zijn ruimtelijke treffers uit de huidige openbare bron. Zij zijn nog niet
ontdubbeld tegen NDFF, andere collecties of onderling.

| Bron | Eigenaar of uitgever | Omvang en periode | Mogelijke meerwaarde | Belangrijkste controle vóór opname |
|---|---|---:|---|---|
| [Historische vlinder- en motwaarnemingen](https://doi.org/10.15468/czfn9y) | Natuurhistorisch Museum Rotterdam | 5.219 GBIF-records binnen de projectgrens; 1955–2019. Ten minste 4.744 records betreffen de intensieve vangsten van J.A.W. Lucas uit 1955–1956 bij de Bierlap. | Een vrijwel onbenutte historische referentie voor vlinders en nachtvlinders, ruim vóór de huidige meetnetten | Vangnachten en vangmethode reconstrueren, locaties en onzekerheid toetsen en ontdubbelen tegen NDFF en museumobjecten. Zonder inspanningsgegevens zijn dit aanwezigheidsgegevens, geen populatietrend. |
| [Naturalis Botany](https://doi.org/10.15468/ib5ypt) | Naturalis Biodiversity Center | 6.227 ruimtelijke GBIF-treffers binnen de projectgrens. De expliciet als Meijendel beschreven deelverzameling bevat 138 herbariumspecimens uit 1919–1998. | Gedateerde historische plantenvondsten en controleerbaar collectiemateriaal | Etiketplaats, oorspronkelijke datum en coördinaatonzekerheid per specimen controleren. Veel punten kunnen een later toegekende gebiedscoördinaat zijn; overlap met LVD, NDFF en provinciale PQ verwijderen. |
| [Naturalis Coleoptera](https://doi.org/10.15468/jrjojf) | Naturalis Biodiversity Center | 1.905 ruimtelijke GBIF-treffers binnen de projectgrens. Daarvan zijn 995 exemplaren uit 1859–1983 expliciet als Meijendel beschreven. | Lange historische context voor kevers, met bewaard bewijsmateriaal | De collectie waarschuwt zelf voor nog niet volledig opgeschoonde datums en locaties. Daarom de oorspronkelijke etiketvelden gebruiken, onzekerheid toetsen en dubbelen met NDFF en andere collecties verwijderen. |
| Overige museum- en DNA-collecties | Natuurhistorisch Museum Rotterdam, Naturalis, iBOL en gespecialiseerde collecties | Huidige ruimtelijke zoekactie: 474 NMR-specimens, 328 slankpootvliegregels en 1.477 iBOL-records. Expliciet als Meijendel beschreven zijn onder meer 23 slankpootvliegspecimens uit 1920–1968 en 61 iBOL-records uit 1962–2022. | Aanvullende historische en moleculair bevestigde vondsten uit verschillende soortgroepen | Geen totalen optellen voordat dubbelen zijn vastgesteld. Alleen records toelaten waarvan etiket of bronlocatie Meijendel bevestigt; een punt binnen de kaartgrens is onvoldoende. |
| [Neuropteren van Meijendel](https://repository.naturalis.nl/pub/317242) | Naturalis; onderzoek van D.C. Geijskes | Gepubliceerde waarnemingen uit de jaren twintig, lichtvangsten uit 1957–1963, gerichte bezoeken in 1967–1970 en vrijwel wekelijkse excursies van 15 april tot 21 oktober 1971; 38 soorten | Historische reeks van gaasvliegen en verwanten met beschreven verzamelperioden | De specimen- en soortenlijsten uit de publicatie digitaliseren, datum en plaats per record vaststellen en vergelijken met Naturalis-collecties en NDFF. |
| [Zweefvliegen van Meijendel](https://repository.naturalis.nl/pub/317221) | Naturalis; onderzoek van G. Delfos | Regelmatige verzamelingen in 1969 en 1970, met gedateerde exemplaren uit onder meer Kijfhoek en Bierlap | Historische referentie voor zweefvliegen in herkenbare deelgebieden | De volledige specimenlijst digitaliseren en per exemplaar datum en locatie vastleggen; daarna ontdubbelen tegen museumcollecties en NDFF. |

### Afgebakende onderzoeksdatasets

| Bron | Eigenaar of uitgever | Omvang en periode | Statistische betekenis en beperking |
|---|---|---:|---|
| TERRA-Dunes plant- en bodemmicrobiomen | Onderzoeksteam TERRA-Dunes, [Figshare](https://doi.org/10.6084/m9.figshare.25425601.v1) | 94 proefvlakken; planten 2018–2021 en bacteriën/schimmels 2018–2020 | Geschikt voor samenhang tussen vegetatie en microbiomen. Niet toelaten voordat de proefvlakken geografisch zijn gereconstrueerd. |
| Rups- en bodemmicrobiomen | Onderzoeksteam, [Dryad](https://doi.org/10.5061/dryad.8cz8w9gnc) | 56 Meijendelse monsters in 2020: 29 rupsen en 27 bodemmonsters; 29 exacte GPS-locaties | Eenmalige genetische en microbiële momentopname. Geen populatietrend, wel lokale ecologische vergelijking na controle van alle monsterlocaties. |
| Schimmels bij kruipwilg | Onderzoeksteam, [PLOS ONE/ENA](https://doi.org/10.1371/journal.pone.0099852) | Twee proefvlakken, ieder samengesteld uit 20 bodemkernen; maart 2010 | Bruikbaar als lokale microbiële referentie, niet als tijdreeks of gebiedsdekkende inventarisatie. |
| Plantengroei, bodemvocht en weer | Wageningen University & Research, [DANS](https://doi.org/10.17026/DANS-28X-UT8Q) | 10 bodemvochtloggers op vier diepten en één weerstation, metingen per vijf minuten van juli tot december 2020; daarnaast groei- en biomassametingen aan duinvormende grassen | Gedetailleerde processtudie van de reactie van duingrassen op neerslag en droogte. Eerst locaties en meetkwaliteit controleren; één halfjaar geeft geen langjarige ontwikkeling. |
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
- **[Landbedekking in vogelplots](https://doi.org/10.1007/s10531-025-03175-x):** een openbare studie uit 2025 bevat voor 25
  BMP-plots de verdeling van zeven landbedekkingsklassen in 2001 en 2022. De
  vogelgegevens overlappen met de bestaande VWG/SOVON-reeks; de afgeleide
  landbedekking kan wel een nieuwe verklarende laag vormen. Eerst moet worden
  vastgesteld of de geclassificeerde bronrasters zelf beschikbaar zijn of
  alleen de samenvatting per plot.
- **KWR-onderzoek:** rapporten wijzen op aanvullende vegetatie-, bodem- en
  hydrologische gegevens. Een afzonderlijke digitale gegevenslevering is nog
  niet gevonden.
- **Langjarige stuifkuil- en vegetatiemetingen:** publicaties noemen 32–35
  stuifkuilen die vanaf 1983 tweemaal per jaar zijn gemeten, 19 permanente
  vegetatieplots en vergelijkingen van luchtfoto's en orthofoto's. De
  oorspronkelijke tabellen, plot-ID's en digitale kaartlagen zijn nog niet
  voldoende geïdentificeerd om deze als afzonderlijke gegevensbron toe te
  laten.

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
bij Tjiftjaf. De voedselwebstudie noemt toestemming voor veldwerk in Meijendel,
maar de gepubliceerde waarnemingstabel betreft uitsluitend Nationaal Park
Zuid-Kennemerland. Zij worden daarom niet als kandidaatbron beschouwd.

Een openbare GBIF-dataset met mondiale bodemorganismen gaf 1.995 ruimtelijke
treffers binnen de projectgrens. De oorspronkelijke plaatsaanduiding van al
deze monsters is echter Terschelling. Dit is een georeferentiefout en geen
Meijendelbron.

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

## 7. Actieplan

Het doel is niet zoveel mogelijk regels importeren, maar per bron de kortste
route naar betrouwbare, niet-dubbele en geografisch toegelaten gegevens te
volgen. De ruwe bestanden blijven onveranderd bewaard; `Meijendel` bevat alleen
waarnemingen die aan de ruimtelijke toelatingsregel voldoen.

### Fase 1 — openbare, direct toetsbare bronnen

1. **STOWA Limnodata en ENDURE volledig beoordelen.** Controleer locaties,
   sleutels, rechten, overlap en analyseeenheid. ENDURE kan na deze controle als
   gestandaardiseerde referentiemeting naar `Meijendel`; STOWA alleen per
   bemonstering en eenheid, zonder niet-gemelde soorten als nul te behandelen.
2. **De historische museumreeksen downloaden en vastzetten.** Maak afzonderlijke
   bronselecties voor de 5.219 NMR-waarnemingen, 6.227 Naturalis-plantenrecords
   en 1.905 Naturalis-keverrecords. Bewaar `occurrenceID`, oorspronkelijke
   etiketplaats, datum, coördinaten, onzekerheid, licentie en download-DOI.
   Alleen geografisch bevestigde, unieke records gaan naar `Meijendel`; overige
   records blijven kandidaat of gaan als context naar `Meijendel_bronnen`.
3. **De Landelijke Vegetatie Databank opnieuw selecteren.** De huidige openbare
   bron geeft meer ruimtelijke treffers dan de eerder vastgelegde selectie van
   119.006 taxonregels. Leg daarom eerst bronversie, selectiegrens en verschil
   tussen opname- en taxonregels vast. Ontdubbel daarna tegen provinciale PQ,
   NDFF en duinvalleivegetatie.

### Fase 2 — reeksen met grote historische of trendwaarde

4. **Ringgegevens koppelen aan vangplaats en inspanning.** Bevestig welke
   locatiecodes VRS Meijendel betreffen en welke vanguren, netten en bezoeken
   beschikbaar zijn. Pas daarna kunnen fenologie en biometrie worden
   geanalyseerd; overeenkomstige vogelrecords worden niet dubbel ingevoerd.
5. **Bijenmonitoring reconstrueren.** Digitaliseer de 18 proefvlakken en 162
   bezoeken uit 2019, 2021 en 2023. Alleen complete bezoeken en betrouwbare
   proefvlaklocaties maken vergelijking tussen gebieden en jaren mogelijk.
6. **Aquatische en historische insectenreeksen digitaliseren.** Begin met de
   zeven waterpunten uit 1974–1975 en de bijbehorende watercodekaart. Voeg
   daarna waterwantsen, waterkevers, libellen, neuropteren en zweefvliegen toe,
   maar alleen wanneer datum en locatie per waarneming zijn vastgesteld.
7. **De 41 droge-duinvegetatieplots lokaliseren.** Zoek eerst de oorspronkelijke
   plotkaart en tabellen. Zonder die koppeling blijft de reeks kandidaat; met
   vaste locaties en herhaalde opnamen kan zij een belangrijke historische
   vegetatiereeks worden.

### Fase 3 — reeds bekende bronhouders en contextdatasets

8. **Ontvangen meetnetleveringen vergelijken, niet blind importeren.** De
   verwachte gegevens van De Vlinderstichting en eventuele latere leveringen
   worden eerst vergeleken met NDFF op populatie, bezoeken, sleutels, nullen en
   overlap. Alleen aantoonbare aanvullingen of betere primaire versies vervangen
   de voorlopige reconstructies.
9. **Contextdatasets alleen promoveren na georeferentie.** Duinvalleiplots,
   jachtspinnen, TERRA-Dunes en andere genummerde locaties blijven in
   `Meijendel_bronnen` totdat per waarneming een betrouwbare ligging in
   Meijendel is vastgesteld.
10. **Verklarende lagen afzonderlijk opbouwen.** Voeg de Habitatkaart T1, de
    landbedekking van 2001 en 2022 en eventueel gevonden remote-sensingrasters
    toe als omgevingslagen. Zij mogen ecologische veranderingen helpen
    verklaren, maar worden niet als soortenwaarnemingen behandeld.

### Vaste werkwijze per bron

Iedere bron doorloopt dezelfde vijf stappen: een onveranderde bronkopie met
checksum bewaren; gegevenswoordenboek en rechten vastleggen; locaties en
analyseeenheid controleren; overlap en dubbelen bepalen; pas daarna een
reproduceerbare import en analyseview maken. Na iedere statuswijziging worden
dit register en de Wordversie meteen bijgewerkt.

### Dekking van de internetcontrole

De controle van 26 september 2026 omvatte GBIF, DataCite, Zenodo, Dryad,
Figshare, Europe PMC, Naturalis Repository, Wageningen Research e-depot en de
repositories van Universiteit Leiden en TU Delft. Algemene aggregators zijn
niet als zelfstandige bron opgenomen wanneer zij waarschijnlijk dezelfde
waarnemingen als NDFF of primaire collecties bevatten. Een openbare zoekronde
kan nooit bewijzen dat geen ongepubliceerde of slecht geïndexeerde bron bestaat;
dit register legt daarom ook de zoekdatum en toelatingsreden vast.

## Achterliggende verantwoording

- [NDFF-staging en bronvergelijking](NDFF_STAGINGDATASET.md)
- [NDFF-protocolaudit](NDFF_PROTOCOLAUDIT.md)
- [Scheiding tussen Meijendel en Meijendel_bronnen](MEIJENDEL_BRONNEN.md)
- [Ruimtelijke audit van contextbronnen](MEIJENDEL_BRONNEN_AUDIT.md)
