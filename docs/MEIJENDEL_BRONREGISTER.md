# Bronregister ecologische gegevens Meijendel

**Stand: 26 september 2026.**

Dit register bevat informatie over:

- ecologische gegevens van Meijendel;

- waar die gegevens staan in GitHub;

- wie de oorspronkelijke bron beheert; en

- waarvoor de gegevens statistisch al dan niet kunnen worden gebruikt.

Het register beschrijft meet- en waarnemingsbronnen en de belangrijkste verklarende omgevingslagen, geen afzonderlijke soorten. Taxonomische referentietabellen, berekende analyse-uitkomsten en technische hulptabellen vallen buiten dit overzicht. Details over tabellen, imports en protocolcodes staan in de achterliggende projectdocumentatie.

## De statussen

- **Analyseklaar**: de meetlocaties, bezoeken, methode en uitkomsten zijn voldoende bekend voor de genoemde analyses. Rekening houden met veranderingen in methode en dekking blijft nodig.

- **Voorwaardelijk bruikbaar**: positieve waarnemingen zijn bruikbaar, maar voor trends ontbreekt nog een deel van de oorspronkelijke meetstructuur.

- **Context**: de bron is inhoudelijk relevant, maar mag niet in de gewone Meijendel-analyses worden gebruikt omdat de locatie per waarneming ontbreekt.

- **Kandidaatbron**: de bron is gevonden, maar nog niet volledig gecontroleerd op locatie, overlap, rechten en statistische betekenis.

In één oogopslag:

- de vogelreeks, provinciale PQ-reeks, bevestigde SOVON-zoogdierbezoeken en historische vangblikreeks zijn nu de sterkste statistische bronnen;

- de NDFF-laag is omvangrijk, maar ondersteunt zonder aanvullende meetstructuur vooral verspreidingsonderzoek;

- op de VPS staan in het Analysecentrum drie contextdatasets en 522 literatuurverwijzingen die niet ongemerkt in analyses terecht mogen komen; de hieronder beschreven nieuwe fase-2-context staat vooralsnog alleen in de lokale canonieke database;
- zes openbare externe bronnen zijn na ruimtelijke toelatings- en overlapcontrole in `Meijendel` opgenomen; hun verschillende analysemogelijkheden blijven per record zichtbaar.

Met **beheerder** wordt hieronder de primaire bronorganisatie of uitgever bedoeld voor zover die nu bekend is. Het is geen afzonderlijke uitspraak over juridisch eigendom of auteursrecht.

## Beheerregel

Iedere ontdekking, levering, import, verplaatsing, uitsluiting of nieuwe beoordeling van een Meijendel-gegevensbron wordt in dit document verwerkt. Dat geldt ook wanneer eigenaar, omvang, periode, locatiekwaliteit, rechten, overlap, validatiestatus of statistische bruikbaarheid verandert. Daarbij worden steeds de analytische database MySQL Meijendel, de MySQL contextdatabase Meijendel_bronnen en de kandidaatbronnen gezamenlijk gecontroleerd. De Markdown-versie is leidend; de Wordversie wordt in dezelfde wijziging inhoudelijk gelijkgetrokken, gerenderd en gecontroleerd.

## 1. Bronnen in MySQL-database `Meijendel`

### 1.1. Vogelgegevens van Vogelwerkgroep Meijendel en SOVON

**Omvang en periode.** De database bevat 1.063.936 vogelwaarnemingen uit 1958–2025. De oorspronkelijke telgebieden, bezoeken, protocollen en aantallen zijn beschikbaar. Het betreft territoriumgegevens vanaf 1958, bezoekwaarnemingen van wintertellingen vanaf seizoen 2000/2001 en bezoekwaarnemingen van BMP-tellingen vanaf 2009.

**Beheerder.** Vogelwerkgroep Meijendel en SOVON.

**Gebruik.** Trends, verspreidingsveranderingen, fenologie en relaties met vegetatie, weer en beheer kunnen verantwoord worden onderzocht, mits veranderingen in methode en dekking expliciet worden verwerkt.

**Status.** Analyseklaar en primaire bron.

### 1.2. Provinciale permanente kwadraten

**Omvang en periode.** De levering van Provincie Zuid-Holland bevat 254 permanente kwadraten, 2.007 vegetatieopnamen en 53.122 taxonregels uit 1981–2025.

**Beheerder.** Provincie Zuid-Holland.

**Gebruik.** De reeks ondersteunt analyses van vegetatiesamenstelling, bedekking, successie en verandering per permanent kwadraat. Overeenkomende NDFF-regels (zie verder) worden niet als een tweede waarneming geteld.

**Status.** Analyseklaar en primaire bron.

### 1.3. Zoogdieren tijdens SOVON- en VWG-bezoeken

**Omvang en periode.** De SOVON-levering bevat 19.877 zoogdierwaarnemingen uit 2009–2026. De analysematrix omvat 4.354 bevestigde bezoeken, 30.478 combinaties van bezoek en doelsoort en 23.619 afgeleide nulwaarnemingen. De 807 regels uit 2026 behoren tot een nog niet afgerond jaar.

**Beheerder.** SOVON en Vogelwerkgroep Meijendel.

**Gebruik.** Voor de tijdens deze bezoeken gevolgde zoogdieren, waaronder het konijn, zijn analyses van trefkans, verspreiding en ontwikkeling mogelijk. Bezoeken zonder enige zoogdierregistratie gelden niet automatisch als een bezoek waarop systematisch naar zoogdieren is gekeken.

**Status.** Analyseklaar binnen deze afbakening; de primaire SOVON-bron gaat voor eventuele overeenkomstige NDFF-regels.

### 1.4. Historisch vangblikonderzoek

**Omvang en periode.** De GBIF-dataset *Meijendel research 1953–1960* bevat 37.770 vangblikevents, 60.560 vangsten, 275 taxa en 99.652 individuen. Per event zijn vangblik, datum, duur en locatie bekend.

**Beheerder.** De historische reeks is afkomstig uit het onderzoek van Piet den Boer en is gepubliceerd als [GBIF Sampling Event Dataset](https://doi.org/10.15468/adsbxs).

**Gebruik.** Binnen 1953–1960 zijn analyses mogelijk van soortensamenstelling, seizoensverloop en ruimtelijke verschillen. Lege events zijn niet voor alle taxa een bewezen nul; verplaatsingen van vangblikken en een methodeproef in de kwaliteitsvelden zijn vastgelegd.

**Status.** Analyseklaar binnen de historische onderzoeksopzet.

### 1.5. NDFF: één canonieke laag van openbare en beveiligde gegevens

**Omvang en periode.** De levering bevat 810.830 unieke niet-vogelrecords uit 1950–2025. De beveiligde levering bevat 14.573 records voor 191 geselecteerde taxa. Daarvan vervangen 14.420 records hun openbare, vervaagde tegenhanger en zijn 153 records alleen in de beveiligde levering aanwezig. De gecombineerde laag telt daardoor 810.983 unieke waarnemingen.

**Beheerder.** NDFF is de gegevensbank. De oorspronkelijke gegevens komen van verschillende meetnetbeheerders, terreinbeheerders en waarnemers.

**Gebruik.** De laag is geschikt voor geregistreerde aanwezigheid, verspreidingspatronen, soortenlijsten, mogelijke hotspots en kennislacunes. Zij is als geheel niet geschikt voor populatietrends: de vaste codes voor tellocaties, telroutes en bezoeken, complete soortenlijsten, tellingen waarbij een soort niet werd aangetroffen en informatie over veranderingen in methode of telinspanning ontbreken. Bovendien zijn alle NDFF-locaties als polygonen met een onzekerheidsbuffer opgeslagen. Een polygoon die een kavel raakt, bewijst daarom niet dat de soort in die kavel is waargenomen. De onvervaagde gegevens voor kwetsbare soorten blijven lokaal afgeschermd.

**Status.** Voorwaardelijk bruikbaar. De bronorganisaties zijn aangeschreven met het verzoek de aanvullende metadata te leveren.

#### 1.5.1. Dagvlinders

**Omvang en periode.** 82.217 records, 3.126 gereconstrueerde bezoeken, 1990–2025

**Wat kan nu?** Positieve waarnemingen en voorlopige routeanalyses

**Wat ontbreekt voor zelfstandige trends?** Oorspronkelijke route- en bezoekcodes, complete bezoeken, gevolgde modules en tellingen zonder waarneming

#### 1.5.2. Hommels

**Omvang en periode.** 1.535 records, 217 bezoeken, 2018–2025

**Wat kan nu?** Positieve aanwezigheid per bezoek

**Wat ontbreekt voor zelfstandige trends?** Bevestiging dat hommels systematisch zijn geteld en op welk determinatieniveau

#### 1.5.3. Libellen

**Omvang en periode.** 3.280 records, 461 bezoeken, 2007–2021

**Wat kan nu?** Positieve aanwezigheid en voorlopige routevergelijking

**Wat ontbreekt voor zelfstandige trends?** Oorspronkelijke route- en bezoekstructuur en volledige doelsoortenlijst

#### 1.5.4. Nachtvlinders

**Omvang en periode.** 596 records, 2019–2025

**Wat kan nu?** Geregistreerde aanwezigheid per jaar en kilometerhok

**Wat ontbreekt voor zelfstandige trends?** Afzonderlijke vangnachten, telpunt, val, lamp, brandduur en lege vangnachten

#### 1.5.5. Amfibieën

**Omvang en periode.** 2.519 records, 225 gereconstrueerde bezoeken, 2003–2025

**Wat kan nu?** Positieve aanwezigheid per water of gebied, voor zover ruimtelijk herleidbaar

**Wat ontbreekt voor zelfstandige trends?** Oorspronkelijke water- en bezoekcodes, zoekmethode en volledige-lijststatus

#### 1.5.6. Reptielen

**Omvang en periode.** 957 records, 660 gereconstrueerde bezoeken, 1990–2025

**Wat kan nu?** Positieve aanwezigheid; beperkte nullen voor Hazelworm binnen bevestigde bezoeken

**Wat ontbreekt voor zelfstandige trends?** Ontbrekende bezoeken en volledige routeadministratie

#### 1.5.7. Vissen

**Omvang en periode.** 20 protocolrecords in 6 bezoeken, 2014

**Wat kan nu?** Alleen lokale verspreidingsinformatie

**Wat ontbreekt voor zelfstandige trends?** Te weinig bezoeken en geen volledige meetstructuur voor een lokale trend

#### 1.5.8. Vleermuistransecten

**Omvang en periode.** 2.624 records, 44 bezoeken, 2013–2025

**Wat kan nu?** Positieve aanwezigheid langs twee gereconstrueerde reeksen

**Wat ontbreekt voor zelfstandige trends?** Oorspronkelijke routes, secties, bezoeken en volledige resultaten

#### 1.5.9. Konijnentellingen in de duinen

**Omvang en periode.** 5.809 records, 812 bezoeken, 1984–2023

**Wat kan nu?** Aanwezigheids- en aantalscontext

**Wat ontbreekt voor zelfstandige trends?** Eerst overlap met de primaire SOVON- en VWG-reeks oplossen

#### 1.5.10. Wintertellingen vleermuizen

**Omvang en periode.** 3.960 records, 1976–2025

**Wat kan nu?** Positieve aanwezigheid per object en jaar, voor zover herleidbaar

**Wat ontbreekt voor zelfstandige trends?** Vaste object- en bezoekcodes en volledige tellingen

#### 1.5.11. Het Nieuwe Strepen

**Omvang en periode.** 4.569 records, 23 lijstkandidaten, 2012–2024

**Wat kan nu?** Voorlopige vergelijking van inventarisaties

**Wat ontbreekt voor zelfstandige trends?** Oorspronkelijke lijstcodes en bevestiging welke tellingen onafhankelijk zijn

#### 1.5.12. FLORBASE en andere vaatplantinventarisaties

**Omvang en periode.** 21.374 records, 1974–2025

**Wat kan nu?** Verspreiding en floristische context

**Wat ontbreekt voor zelfstandige trends?** Oorspronkelijke lijsten, onderzochte gebieden en volledige bezoekstructuur

#### 1.5.13. LMF-aandachtssoorten

**Omvang en periode.** 5.980 records, 2000–2025

**Wat kan nu?** Positieve aanwezigheid

**Wat ontbreekt voor zelfstandige trends?** Oorspronkelijke routes, bezoeken en gevolgde soortenlijst

#### 1.5.14. Mossen en korstmossen

**Omvang en periode.** 761 records, 2000–2025

**Wat kan nu?** Positieve aanwezigheid en voorlopige proefvlakvergelijking

**Wat ontbreekt voor zelfstandige trends?** Oorspronkelijke proefvlak-, lijst- en waarnemersgegevens

#### 1.5.15. Bos- en zeereeppaddenstoelen

**Omvang en periode.** 4.720 records, 1999–2025

**Wat kan nu?** Positieve aanwezigheid en voorlopige vergelijking van vaste meetpunten

**Wat ontbreekt voor zelfstandige trends?** Volledige bezoeken en het per teller gevolgde soortenbereik; geen vruchtlichaam is bovendien niet hetzelfde als geen mycelium

#### 1.5.16. Weekdieren

**Omvang en periode.** 5.008 records, 1951–2024

**Wat kan nu?** Verspreiding en historische context

**Wat ontbreekt voor zelfstandige trends?** Locatie-, monster- en bezoekcodes om systematische tellingen van losse meldingen te scheiden

#### 1.5.17. SNL-gebiedsmonitoring

**Omvang en periode.** 6.273 records, 2007–2022

**Wat kan nu?** Periodieke informatie over kwalificerende soorten

**Wat ontbreekt voor zelfstandige trends?** Beheertype, karteergebied, telronde, protocolversie en volledige uitslag; dit levert niet automatisch een jaarlijkse populatietrend op

De overige NDFF-regels zijn losse of uitsluitend positieve registraties. Zij blijven nuttig voor verspreiding, maar ontbreken mag daar nooit als afwezigheid worden uitgelegd.

### 1.6. Openbare externe ecologiebronnen

Op 26 september 2026 zijn zes openbare bronnen reproduceerbaar geselecteerd en in drie generieke tabellen opgenomen: dataset, meet- of collectie-event en resultaat. De oorspronkelijke bron-ID, bronnaam, datum of datuminterval, coördinaten, locatie-onzekerheid, protocol, hoeveelheid, licentie en volledige bronmetadata blijven behouden. Een afzonderlijke overlaptabel voorkomt dat bekende dubbelen ongemerkt als zelfstandige waarnemingen worden gebruikt.

De import is tweemaal uitgevoerd en leverde beide keren exact 10.994 events en 98.916 resultaten op. De hashes, bronselecties, totalen en overlapuitkomsten staan in het [auditmanifest fase 1 en 2](../gis/audit/externe_ecologie_fase1_2_manifest.json). De onveranderde bronbestanden en hun `SHA256SUMS.txt` worden duurzaam bewaard op de T7 onder `Meijendel data/Externe ecologiebronnen/fase_1_2_2026-09-26`.

#### 1.6.1. STOWA Limnodata

**Beheerder.** STOWA; gegevens van Hoogheemraadschap van Delfland en Rijnland

**Omvang en periode.** 44 bemonsteringen op zeven stationcodes en zes locaties, met 1.036 positieve taxonresultaten van 439 taxa uit 1992–2010.

**Gebruik.** Herhaalde metingen van aquatische flora en fauna kunnen per locatie, datum, methode en meeteenheid worden onderzocht. De gebruikte eenheden blijven gescheiden: 426 resultaten zijn uitgedrukt als `aantal/ml`, 358 als `aantal/5m`, 196 als Braun-Blanquetklasse en 56 zonder eenheid. Niet gemelde soorten zijn geen nulwaarneming.

#### 1.6.2. ENDURE helmduinfauna

**Beheerder.** Universiteit Gent en ENDURE

**Omvang en periode.** Vijftien meetpunten op 19 september 2018. Veertien meetpunten hebben een complete matrix met 71 aanwezigheden en 9.001 expliciete afwezigheden voor 626 taxa; bij één meetpunt ontbreekt de resultatenmatrix.

**Gebruik.** Dit is een gestandaardiseerde en herhaalbare referentiemeting voor ongewervelden in witte duinen. De expliciete afwezigheden zijn bruikbaar binnen de veertien complete matrices. Eén meetjaar levert geen ontwikkeling door de tijd op.

#### 1.6.3. Landelijke Vegetatie Databank

**Beheerder.** Wageningen Environmental Research

**Omvang en periode.** De gepubliceerde bronversie 1.6 bevat binnen het basisgebied 5.195 opnamen en 119.006 taxonregels uit 1930–2015. Toegelaten zijn 3.437 opnamen met een gepubliceerde locatie-onzekerheid van maximaal 50 meter en 81.310 taxonresultaten uit 1959–2015. De overige 1.758 opnamen blijven buiten de analytische selectie vanwege een onzekerheid van 100, 1.000 of 5.000 meter.

**Overlap en gebruik.** De controle op datum, taxon en afstand markeert 8.006 resultaten als exacte en 5.163 als waarschijnlijke overlap met de primaire provinciale PQ-reeks. Deze 13.169 resultaten tellen niet als onafhankelijke tweede waarneming. Daarnaast hebben 51.078 LVD-resultaten een mogelijke overeenkomst met een NDFF-regel op taxon, datum en onzekerheidspolygoon. Omdat NDFF geen gedeelde bron-ID levert en de polygonen ruimtelijke onzekerheid weergeven, wordt die mogelijke overlap niet automatisch als dubbel verwijderd. De resterende opnamecontext is bruikbaar voor historische vegetatiesamenstelling en verspreiding; vergelijking door de tijd vereist controle van opnametype, oppervlak en herhaling.

#### 1.6.4. Historische vlinder- en motcollectie

**Beheerder.** Natuurhistorisch Museum Rotterdam

**Omvang en periode.** Van 5.219 ruimtelijke treffers binnen de projectgrens zijn 4.748 gedateerde, unieke collectierecords met een expliciete etiketplaats Meijendel of Bierlap toegelaten; 247 taxa uit 1955–2015. Van deze resultaten hebben 4.646 een mogelijke overeenkomst met NDFF op taxon, datum en onzekerheidspolygoon.

**Gebruik.** De collectie geeft controleerbare historische aanwezigheid, vooral door de intensieve vangsten van J.A.W. Lucas in 1955–1956. Zonder vanginspanning en lege vangnachten is dit geen populatietrend. De mogelijke NDFF-overlap blijft gemarkeerd en wordt niet automatisch samengevoegd.

#### 1.6.5. Naturalis Botany

**Beheerder.** Naturalis Biodiversity Center

**Omvang en periode.** Van 7.585 ruimtelijke treffers binnen de projectgrens zijn 1.881 gedateerde, unieke specimens met een expliciete Meijendel-etiketplaats toegelaten; 785 taxa uit 1875–2025. Daarvan hebben 641 specimens een mogelijke overeenkomst met NDFF. Nog 33 expliciet als Meijendel beschreven specimens zonder bruikbare datum blijven buiten de analytische selectie.

**Gebruik.** Gedateerde historische plantenvondsten met bewaard bewijsmateriaal. De records tonen aanwezigheid, geen gestandaardiseerde telinspanning of afwezigheid.

#### 1.6.6. Naturalis Coleoptera

**Beheerder.** Naturalis Biodiversity Center

**Omvang en periode.** Van 2.372 ruimtelijke treffers binnen de projectgrens zijn 869 gedateerde, unieke specimens met een expliciete Meijendel-etiketplaats toegelaten; 78 taxa uit 1906–2023. Nog 210 expliciete Meijendel-specimens zonder bruikbare datum blijven buiten de analytische selectie.

**Gebruik.** Historische aanwezigheid van kevers met bewaard collectiemateriaal. De bron ondersteunt geen populatietrend zonder gestandaardiseerde vanginspanning. De oorspronkelijke etiketplaats en de gepubliceerde locatie-onzekerheid blijven per specimen beschikbaar.

### 1.7. Openstaande ruimtelijke toelatingscontrole

De bronregistraties staan wel in `Meijendel`, maar een deel mag nog niet als waarneming binnen Meijendel worden gebruikt. De audit met de actuele projectgrens vond 70.427 openbare NDFF-records uit de downloadselectie 1950–2025, 968 BMP-dagwaarnemingen uit 2009–2025, 644 provinciale PQ-opnamen uit 1981–2025 en 14 primaire SOVON-bijvangsten uit 2009–2024 die buiten het basisgebied liggen. Sommige NDFF-records hebben een breed broninterval dat al vóór 1950 begint; dat maakt hen geen waarneming uit dat eerdere jaar. Daarnaast raken 146.466 NDFF-polygonen alleen de grens. Bij die polygonen staat niet vast dat de waarneming binnen Meijendel is gedaan.

Deze records blijven herkenbaar als bronmateriaal, maar worden niet zonder een afzonderlijk ruimtelijk besluit in Meijendelanalyses gebruikt. Alle 37.770 vangblikevents en alle territoriumplots liggen binnen het basisgebied.

### 1.8. Verklarende omgevingslagen

Deze gegevens zijn geen soortenwaarnemingen. Zij kunnen wel helpen om ecologische veranderingen te beschrijven of als mogelijke verklaring te toetsen.

#### 1.8.1. Dagelijks weer

**Eigenaar.** KNMI, stations Valkenburg en Voorschoten

**Omvang en periode in de huidige SQL-dump.** 24.837 dagregels, 1953–2026

**Gebruik en grens.** Temperatuur, neerslag, wind, zon en luchtdruk kunnen als covariaten worden gebruikt. Alleen de genormaliseerde analyseview is geldig; 2026 is nog niet compleet.

#### 1.8.2. Hoogte

**Eigenaar.** Actueel Hoogtebestand Nederland via PDOK

**Omvang en periode in de huidige SQL-dump.** 55 plots, peiljaar 2025

**Gebruik en grens.** Beschrijft hoogte en hoogtevariatie per plot. Eén peiljaar geeft geen ontwikkeling door de tijd.

#### 1.8.3. Stikstofdepositie

**Eigenaar.** RIVM

**Omvang en periode in de huidige SQL-dump.** 1.027 plot-jaarregels, 2005–2023

**Gebruik en grens.** Geschikt als mogelijke verklarende factor naast soorten- en vegetatiereeksen. Een samenhang bewijst niet dat stikstof de enige oorzaak is.

#### 1.8.4. Bodemgebruik

**Eigenaar.** CBS Bestand Bodemgebruik

**Omvang en periode in de huidige SQL-dump.** 918 plot-jaar-klasseregels, 1996–2022

**Gebruik en grens.** Laat veranderingen in de ruimtelijke omgeving van plots zien. De meetjaren zijn niet jaarlijks beschikbaar.

#### 1.8.5. Natura 2000-habitat

**Eigenaar.** Habitatkartering 2014; bronhouderschap nog in de metadata te bevestigen

**Omvang en periode in de huidige SQL-dump.** 384 plot-habitatregels uit 2014

**Gebruik en grens.** Geeft de verdeling van habitattypen binnen plots. Dit is één kaartjaar; de aangekondigde T1-kaart is nodig voor een directe vergelijking door de tijd.

## 2. Bronnen in MySQL-database `Meijendel_bronnen`

Deze database bevat informatie die niet aan de ruimtelijke toelatingsregel van de analytische database voldoet. De reeds gepubliceerde versie is in het Analysecentrum raadpleegbaar, maar wordt niet automatisch in modellen of kaarten uit `Meijendel` gebruikt. De nieuwe bijen- en aquatische context uit fase 2 staat op 26 september 2026 alleen in de lokale canonieke database en is nog niet naar de VPS gepubliceerd.

### 2.1. Duinvalleivegetatie

**Beheerder.** Openbare onderzoeksdataset, [Zenodo](https://doi.org/10.5281/zenodo.21796880)

**Omvang en periode.** 488 opnamen en 101.504 bedekkingsregels; 2001, 2008 en 2018. Van de 186 vaste Site-codes zijn er 116 driemaal en 70 tweemaal onderzocht. Negen bodemvariabelen zijn voor 45 plots in 2001 en 2018 beschikbaar; bodemvocht alleen voor deze 45 plots in 2018.

**Waarde en beperking.** De volledige matrix van 208 taxa bevat echte nullen en maakt vergelijking tussen de drie jaren mogelijk. De locatiecodes zijn nog niet betrouwbaar aan geometrieën gekoppeld. Opname 18I01 blijft uitgesloten: daarin zijn 159 taxa geregistreerd, tegenover maximaal 40 in alle overige opnamen. Deze reeks blijft afzonderlijk van de provinciale PQ-reeks.

### 2.2. Vogelstand 1924

**Beheerder.** Vogelwerkgroep Meijendel

**Omvang en periode.** 204 regels uit 1924

**Waarde en beperking.** Historische vogelcontext. Zonder locatie per regel geen kavel- of ruimtelijke analyse.

### 2.3. Jachtspinnen

**Beheerder.** Van der Aart en Smeenk-Enserink

**Omvang en periode.** 3.337 exemplaren, 12 soorten, 28 locaties en zes milieuvariabelen; 1969–1970

**Waarde en beperking.** De samengevoegde vangstmatrix ondersteunt een soorten-milieuanalyse, maar geen ontwikkeling door de tijd. Datums en vangrondes ontbreken. De 28 locatienummers zijn bovendien nog niet naar werkelijke plaatsen te vertalen en mogen daarom niet als Meijendelwaarnemingen worden geanalyseerd.

### 2.4. Literatuuroverzicht

**Beheerder.** Zotero-collectie Meijendel

**Omvang en periode.** 522 bibliografische verwijzingen op 25 september 2026

**Waarde en beperking.** Zoekingang naar onderzoek en historische context. Dit zijn verwijzingen, geen waarnemingsregels; volledige teksten blijven in Zotero en worden niet op de VPS gekopieerd.

### 2.5. Bijenmonitoring in vier beheergebieden

**Beheerder.** EIS Kenniscentrum Insecten

**Omvang en periode.** Achttien vaste proefvlakken van één hectare, verdeeld over Vallei Meijendel, De Loopert, Buitenduinen en Binnenduinen. Uit de officiële rapporten zijn alle 162 bezoeken gereconstrueerd: drie bezoeken per proefvlak in 2019, 2021 en 2023, telkens 45 minuten.

**Waarde en beperking.** De vaste opzet ondersteunt in beginsel vergelijking van bijengemeenschappen tussen proefvlakken en onderzoeksjaren. De rapporten tonen de proefvlakgrenzen alleen als kaartfiguren. Zolang deze grenzen niet betrouwbaar digitaal zijn vastgelegd en de soortenmatrices niet gecontroleerd zijn gedigitaliseerd, blijven de proefvlak- en bezoekgegevens context in `Meijendel_bronnen`. Drie onderzoeksjaren zijn bovendien een reeks van gestandaardiseerde herhalingen, geen robuuste langjarige trend.

### 2.6. Aquatische macrofauna 1974–1975

**Beheerder.** Rijksuniversiteit Leiden; ontsloten via Naturalis

**Omvang en periode.** Zeven vaste monsterpunten in Pan 17.1, Pan 26.1.1, Kwelplas K10, G15 en G21, vrijwel maandelijks onderzocht van juni 1974 tot juli 1975. De database legt de zeven watercodes en negentien methodeperioden of afwijkingen vast. Vanaf augustus 1974 werd doorgaans 2,5 meter oever en 0,75 m² bemonsterd; voor punt 7 was dit 2 meter en 0,60 m². De pilot in juni 1974, de kortere bemonstering van punt 2 in november 1974 en de gedeeltelijke ronde van juli 1975 blijven afzonderlijk herkenbaar.

**Waarde en beperking.** De reeks is waardevolle historische context voor waterorganismen en watermilieu. De watercodes zijn bekend, maar betrouwbare digitale grenzen of punten en een foutgecontroleerde volledige soortenmatrix ontbreken nog. Daarom zijn nog geen waarnemingsregels naar `Meijendel` overgebracht.

## 3. Geïdentificeerde externe kandidaatbronnen

Deze bronnen zijn gevonden, maar nog niet toegelaten. De genoemde aantallen hebben betrekking op de al gemaakte Meijendelselectie of op de beschreven onderzoeksopzet. Voor iedere import volgt eerst controle van locatie per waarneming, overlap met bestaande bronnen, rechten en statistische betekenis.

### Kandidaten met de grootste verwachte aanvulling

#### 3.1. Historische en actuele ringgegevens

**Eigenaar of uitgever.** Vogeltrekstation/NIOO-KNAW

**Omvang en periode.** De ruimtelijke selectie uit de biometrische GBIF-bron bevat 100.417 records van 163 soorten uit 1963–2023. Historische nestjongen omvatten daarnaast 668 records van 38 soorten uit 1928–1957.

**Mogelijke meerwaarde.** Trektijd, conditie, biometrie en vroeg-historische vogelcontext

**Belangrijkste controle vóór opname.** De code `NL19` blijkt in de officiële EURING-codebeschrijving de provincie Zuid-Holland aan te duiden en niet VRS Meijendel. Trektellen-site 403 is wel VRS Meijendel en bevat inspanningsinformatie, maar er is nog geen recordsleutel tussen beide bronnen gevonden. De 100.417 ruimtelijke treffers zijn daarom niet als VRS-Meijendelvangsten geïmporteerd.

#### 3.2. Erosiepinnen in een stuifkuilcomplex

**Eigenaar of uitgever.** Jungerius en Van der Meulen

**Omvang en periode.** 48 erosiepinnen in 12 eenheden, vrijwel wekelijks gemeten gedurende één jaar

**Mogelijke meerwaarde.** Gedetailleerde processtudie van erosie, sedimentatie en vegetatie, maar geen langjarige trend

**Belangrijkste controle vóór opname.** Oorspronkelijke metingen en pinlocaties vinden en op waarnemingsniveau aan Meijendel koppelen

#### 3.3. Langjarige droge-duinvegetatieplots

**Eigenaar of uitgever.** Historische Meijendel-onderzoekers; later ontsloten via Wageningen University & Research

**Omvang en periode.** 41 vaste vegetatieplots, aangelegd in 1952–1953 en gemiddeld ongeveer iedere vier jaar herhaald

**Mogelijke meerwaarde.** Potentieel zeer waardevolle langjarige vegetatiereeks voor successie, begrazing en verandering van grijs duin

**Belangrijkste controle vóór opname.** De publicatiekaart toont de 41 punten in Helmduinen, Kijfhoek en Bierlap, maar zonder koppelbare plotcodes. De toegelaten LVD-opnamen leverden geen betrouwbare vertaling op naar deze 41 plots. Oorspronkelijke plotcodes, opnamen en locaties blijven daarom noodzakelijk.

#### 3.4. [Neuropteren van Meijendel](https://repository.naturalis.nl/pub/317242)

**Eigenaar of uitgever.** Naturalis; onderzoek van D.C. Geijskes

**Omvang en periode.** Gepubliceerde waarnemingen uit de jaren twintig, lichtvangsten uit 1957–1963, gerichte bezoeken in 1967–1970 en vrijwel wekelijkse excursies van 15 april tot 21 oktober 1971; 38 soorten

**Mogelijke meerwaarde.** Historische reeks van gaasvliegen en verwanten met beschreven verzamelperioden

**Belangrijkste controle vóór opname.** De specimen- en soortenlijsten uit de publicatie digitaliseren, datum en plaats per record vaststellen en vergelijken met Naturalis-collecties en NDFF.

#### 3.5. [Zweefvliegen van Meijendel](https://repository.naturalis.nl/pub/317221)

**Eigenaar of uitgever.** Naturalis; onderzoek van G. Delfos

**Omvang en periode.** Regelmatige verzamelingen in 1969 en 1970, met gedateerde exemplaren uit onder meer Kijfhoek en Bierlap

**Mogelijke meerwaarde.** Historische referentie voor zweefvliegen in herkenbare deelgebieden

**Belangrijkste controle vóór opname.** De volledige specimenlijst digitaliseren en per exemplaar datum en locatie vastleggen; daarna ontdubbelen tegen museumcollecties en NDFF.

#### 3.6. TERRA-Dunes plant- en bodemmicrobiomen

**Eigenaar of uitgever.** Onderzoeksteam TERRA-Dunes, [Figshare](https://doi.org/10.6084/m9.figshare.25425601.v1)

**Omvang en periode.** 94 proefvlakken; planten 2018–2021 en bacteriën/schimmels 2018–2020

**Statistische betekenis en beperking.** Geschikt voor samenhang tussen vegetatie en microbiomen. Niet toelaten voordat de proefvlakken geografisch zijn gereconstrueerd.

#### 3.7. Rups- en bodemmicrobiomen

**Eigenaar of uitgever.** Onderzoeksteam, [Dryad](https://doi.org/10.5061/dryad.8cz8w9gnc)

**Omvang en periode.** 56 Meijendelse monsters in 2020: 29 rupsen en 27 bodemmonsters; 29 exacte GPS-locaties

**Statistische betekenis en beperking.** Eenmalige genetische en microbiële momentopname. Geen populatietrend, wel lokale ecologische vergelijking na controle van alle monsterlocaties.

#### 3.8. Schimmels bij kruipwilg

**Eigenaar of uitgever.** Onderzoeksteam, [PLOS ONE/ENA](https://doi.org/10.1371/journal.pone.0099852)

**Omvang en periode.** Twee proefvlakken, ieder samengesteld uit 20 bodemkernen; maart 2010

**Statistische betekenis en beperking.** Bruikbaar als lokale microbiële referentie, niet als tijdreeks of gebiedsdekkende inventarisatie.

#### 3.9. Plantengroei, bodemvocht en weer

**Eigenaar of uitgever.** Wageningen University & Research, [DANS](https://doi.org/10.17026/DANS-28X-UT8Q)

**Omvang en periode.** 10 bodemvochtloggers op vier diepten en één weerstation, metingen per vijf minuten van juli tot december 2020; daarnaast groei- en biomassametingen aan duinvormende grassen

**Statistische betekenis en beperking.** Gedetailleerde processtudie van de reactie van duingrassen op neerslag en droogte. Eerst locaties en meetkwaliteit controleren; één halfjaar geeft geen langjarige ontwikkeling.

#### 3.10. Genetische datasets amfibieën

**Eigenaar of uitgever.** Verschillende onderzoeksteams, Figshare

**Omvang en periode.** Kamsalamander: 22 monsters op 5 locaties; boomkikker: 18 monsters op benoemde locaties

**Statistische betekenis en beperking.** Bruikbaar voor populatiegenetische context. Jaar, locatie en relatie met bestaande RAVON-waarnemingen moeten eerst worden vastgesteld.

### 3.11. Alleen context of nog een onderzoeksaanwijzing

**Twee-spintmijt:** 573 mijten uit 2015–2017 op 18 genummerde locaties. Zonder vertaling van `MEY1–18` naar werkelijke locaties blijft dit een kandidaat voor `Meijendel_bronnen`.

**Bitterzoet-genetica:** 47 Meijendelse monsters, maar geen individuele veldlocaties. Alleen context zolang die locaties ontbreken.

**Sluipwesp *Tetrastichus coeruleus*:** 21 Meijendelse vrouwtjes zonder bruikbare locatie- en datuminformatie. Alleen context.

**Twee losse GBIF-events van Roel van Klink:** 22 voorkomensrecords uit 2011 en 2023, met 200 meter tot 5 kilometer locatie-onzekerheid. Alleen positieve verspreidingscontext en waarschijnlijk beperkte meerwaarde naast NDFF.

**Remote sensing van vegetatiehoogte en -bedekking:** WUR beschreef kaarten voor 2008 en 2014; TU Delft beschreef elf beeldmomenten uit 2019–2021. De afgeleide rasterbestanden zijn nog niet als openbare dataset gevonden.

**[Landbedekking in vogelplots](https://doi.org/10.1007/s10531-025-03175-x):** een openbare studie uit 2025 bevat voor 25 BMP-plots de verdeling van zeven landbedekkingsklassen in 2001 en 2022. De vogelgegevens overlappen met de bestaande VWG/SOVON-reeks; de afgeleide landbedekking kan wel een nieuwe verklarende laag vormen. Eerst moet worden vastgesteld of de geclassificeerde bronrasters zelf beschikbaar zijn of alleen de samenvatting per plot.

**KWR-onderzoek:** rapporten wijzen op aanvullende vegetatie-, bodem- en hydrologische gegevens. Een afzonderlijke digitale gegevenslevering is nog niet gevonden.

**Langjarige stuifkuil- en vegetatiemetingen:** publicaties noemen 32–35 stuifkuilen die vanaf 1983 tweemaal per jaar zijn gemeten, 19 permanente vegetatieplots en vergelijkingen van luchtfoto’s en orthofoto’s. De oorspronkelijke tabellen, plot-ID’s en digitale kaartlagen zijn nog niet voldoende geïdentificeerd om deze als afzonderlijke gegevensbron toe te laten.

## 4. Verwachte aanvullingen

**Vlindergegevens:** De Vlinderstichting verwacht in de week van 28 september 2026 aanvullende meetstructuur te kunnen leveren. Die levering wordt eerst vergeleken met de 82.217 NDFF-dagvlinderrecords en de bestaande routeconstructie.

**Overige meetnetten:** de overige aangeschreven bronorganisaties hebben op 25 september 2026 nog niet inhoudelijk gereageerd. Nieuwe leveringen worden niet automatisch geïmporteerd, maar eerst gecontroleerd op dekking, sleutels, nullen, inspanning en overlap.

**Habitatkaart T1:** Provincie Zuid-Holland heeft toegezegd de kaart te delen zodra zij later in 2026 beschikbaar komt. De kaart kan veranderingen in habitat helpen verklaren, maar is zelf geen soortenwaarneming.

## 5. Bronnen die niet verder worden uitgewerkt

Drie eerder gevonden publicaties bleken bij controle geen Meijendelgegevens te bevatten: een macrofaunastudie uit de Drentsche Aa, een voedselwebstudie aan Amerikaanse vogelkers in Zuid-Kennemerland en een studie naar vliegtuiggeluid bij Tjiftjaf. De voedselwebstudie noemt toestemming voor veldwerk in Meijendel, maar de gepubliceerde waarnemingstabel betreft uitsluitend Nationaal Park Zuid-Kennemerland. Zij worden daarom niet als kandidaatbron beschouwd.

Een openbare GBIF-dataset met mondiale bodemorganismen gaf 1.995 ruimtelijke treffers binnen de projectgrens. De oorspronkelijke plaatsaanduiding van al deze monsters is echter Terschelling. Dit is een georeferentiefout en geen Meijendelbron.

Algemene verzamelbronnen zoals Observation.org, iNaturalist en eBird worden ook niet opnieuw als zelfstandige Meijendelbron ingevoerd zolang niet is aangetoond dat zij waarnemingen bevatten die ontbreken in NDFF of in de primaire VWG/SOVON-reeksen. Anders zou dezelfde waarneming vooral nogmaals worden opgeslagen.

## 6. Gebruik van dit register

Dit document is het beslisoverzicht. Een bron gaat pas naar `Meijendel` wanneer per waarneming vaststaat dat zij in Meijendel is gedaan en de locatie bekend of betrouwbaar herleidbaar is. Is dat niet zo, dan blijft zij kandidaat of context in Meijendel_bronnen.

Bij iedere nieuwe levering worden achtereenvolgens gecontroleerd:

welke waarnemingen en perioden werkelijk nieuw zijn;

of locaties en oorspronkelijke sleutels bruikbaar zijn;

of bezoeken, soortenlijsten en echte nullen aanwezig zijn;

of de bron een bestaande primaire reeks overlapt;

welke analyses daardoor verantwoord mogelijk worden.

Pas daarna volgt een afzonderlijk importbesluit.

## 7. Actieplan

Het doel is niet zoveel mogelijk regels importeren, maar per bron de kortste route naar betrouwbare, niet-dubbele en geografisch toegelaten gegevens te volgen. De ruwe bestanden blijven onveranderd bewaard; `Meijendel` bevat alleen waarnemingen die aan de ruimtelijke toelatingsregel voldoen.

### Fase 1 — openbare, direct toetsbare bronnen

**Status: uitgevoerd op 26 september 2026.** STOWA en ENDURE zijn na locatie-, sleutel-, rechten- en eenheidscontrole opgenomen. ENDURE bevat veertien complete aanwezigheids-afwezigheidsmatrices en één event zonder resultatenmatrix. STOWA bevat uitsluitend positieve resultaten; de vier typen meeteenheid worden niet samengevoegd.

**Museumreeksen: uitgevoerd.** De volledige openbare Darwin Core-archieven zijn geprofileerd. Alleen gedateerde, unieke records binnen het basisgebied én met een expliciete Meijendel- of deelgebiednaam op het etiket zijn opgenomen: 4.748 NMR-vlinders en -motten, 1.881 Naturalis Botany-specimens en 869 Naturalis-kevers. `occurrenceID`, etiketplaats, oorspronkelijke en voor analyse genormaliseerde taxonnaam, datum of datuminterval, coördinaten, onzekerheid, licentie, DOI en bronmetadata zijn behouden. Ruimtelijke treffers zonder expliciet Meijendel-etiket en expliciete Meijendel-records zonder datum zijn niet toegelaten.

**Landelijke Vegetatie Databank: uitgevoerd voor de reproduceerbare bronversie 1.6.** Van 5.195 opnamen en 119.006 taxonregels zijn 3.437 opnamen en 81.310 taxonresultaten met maximaal 50 meter locatie-onzekerheid toegelaten. De overlapaudit markeert 13.169 resultaten als exact of waarschijnlijk reeds aanwezig in de provinciale PQ-reeks. Mogelijke NDFF-overlap blijft zichtbaar, maar wordt vanwege de NDFF-onzekerheidspolygonen niet automatisch als dubbel verwijderd. De duinvalleireeks kan zonder georeferentie niet op opnameniveau worden gekoppeld en blijft afzonderlijk in `Meijendel_bronnen`.

### Fase 2 — reeksen met grote historische of trendwaarde

**Ringgegevens: onderzocht, niet toegelaten.** De locatiecode `NL19` in de GBIF-biometrie betekent provincie Zuid-Holland en niet VRS Meijendel. Trektellen-site 403 bevat wel VRS-Meijendelrapporten en inspanning, maar er is geen recordsleutel naar de 100.417 ruimtelijke GBIF-treffers. Zij blijven kandidaat en worden niet met de vogelreeks vermengd.

**Bijenmonitoring: bezoekstructuur gereconstrueerd.** Alle achttien proefvlakcodes, vier deelgebieden en 162 bezoeken uit 2019, 2021 en 2023 zijn in `Meijendel_bronnen` vastgelegd. De rapporten tonen de grenzen alleen als figuur. De reeks verhuist pas naar `Meijendel` nadat die grenzen betrouwbaar zijn gegeorefereerd en de soortenmatrices foutgecontroleerd zijn gedigitaliseerd.

**Aquatische reeks: methode en locatiestructuur gereconstrueerd.** De zeven monsterpuntcodes, vijf benoemde wateren en negentien standaard- of afwijkende methodeperioden uit 1974–1975 staan in `Meijendel_bronnen`. Een betrouwbare digitale watercodekaart en een gecontroleerde soortenmatrix ontbreken nog. Daarom zijn geen waarnemingsregels naar `Meijendel` gepromoveerd. De aanvullende waterwantsen, waterkevers, libellen, neuropteren en zweefvliegen blijven kandidaat totdat datum en locatie per waarneming vaststaan.

**Droge-duinvegetatieplots: onderzocht, nog niet lokaliseerbaar per plot.** De kaart in het proefschrift is visueel gecontroleerd en toont 41 punten in Helmduinen, Kijfhoek en Bierlap, maar geen koppelbare plotcodes. Ook de LVD-selectie levert geen betrouwbare vertaling. De reeks blijft kandidaat totdat de oorspronkelijke plotkaart en opnametabellen zijn gevonden.

### Fase 3 — reeds bekende bronhouders en contextdatasets

**Ontvangen meetnetleveringen vergelijken, niet blind importeren.** De verwachte gegevens van De Vlinderstichting en eventuele latere leveringen worden eerst vergeleken met NDFF op populatie, bezoeken, sleutels, nullen en overlap. Alleen aantoonbare aanvullingen of betere primaire versies vervangen de voorlopige reconstructies.

**Contextdatasets alleen promoveren na georeferentie.** Duinvalleiplots, jachtspinnen, TERRA-Dunes en andere genummerde locaties blijven in `Meijendel_bronnen` totdat per waarneming een betrouwbare ligging in Meijendel is vastgesteld.

**Verklarende lagen afzonderlijk opbouwen.** Voeg de Habitatkaart T1, de landbedekking van 2001 en 2022 en eventueel gevonden remote-sensingrasters toe als omgevingslagen. Zij mogen ecologische veranderingen helpen verklaren, maar worden niet als soortenwaarnemingen behandeld.

### Vaste werkwijze per bron

Iedere bron doorloopt dezelfde vijf stappen: een onveranderde bronkopie met checksum bewaren; gegevenswoordenboek en rechten vastleggen; locaties en analyseeenheid controleren; overlap en dubbelen bepalen; pas daarna een reproduceerbare import en analyseview maken. Na iedere statuswijziging worden dit register en de Wordversie meteen bijgewerkt.

### Dekking van de internetcontrole

De controle van 26 september 2026 omvatte GBIF, DataCite, Zenodo, Dryad, Figshare, Europe PMC, Naturalis Repository, Wageningen Research e-depot en de repositories van Universiteit Leiden en TU Delft. Algemene aggregators zijn niet als zelfstandige bron opgenomen wanneer zij waarschijnlijk dezelfde waarnemingen als NDFF of primaire collecties bevatten. Een openbare zoekronde kan nooit bewijzen dat geen ongepubliceerde of slecht geïndexeerde bron bestaat; dit register legt daarom ook de zoekdatum en toelatingsreden vast.

## Achterliggende verantwoording

- [NDFF-staging en bronvergelijking](bronnen/bronvergelijkingen/NDFF_STAGINGDATASET.md)
- [NDFF-protocolaudit](bronnen/audits/NDFF_PROTOCOLAUDIT.md)
- [Scheiding tussen Meijendel en Meijendel_bronnen](bronnen/MEIJENDEL_BRONNEN.md)
- [Ruimtelijke audit van contextbronnen](bronnen/audits/MEIJENDEL_BRONNEN_AUDIT.md)
- [Importbesluit duinvalleivegetatie](bronnen/importbesluiten/DUINVALLEI_VEGETATIE.md)
- [Ruimtelijke bronlagen en toelatingsregels](bronnen/importbesluiten/MEIJENDEL_RUIMTELIJKE_LAGEN.md)
- [Beveiligde NDFF-ontvangst](bronnen/importbesluiten/NDFF_SECURE_ONTVANGST.md)
