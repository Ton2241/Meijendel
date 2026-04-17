# Brugjaren en T0 reeksen

Dit document vat samen hoe in de R-scripts wordt omgegaan met de methodebreuk rond `1984`, welke reeksen nu al worden overbrugd, en hoe dat zich verhoudt tot de voorgestelde `T0`-reeksen met basisjaar `100`.

## Kern

Er worden geen kunstmatige extra kalenderjaren toegevoegd.

Wel gebeurt dit:

1. De hoofdreeks wordt gesplitst in `1958-1983` en `1984-2025`.
2. Voor beide delen wordt apart een indexreeks berekend.
3. Daarna wordt een brugfactor berekend op basis van de ankerperioden `1981-1983` en `1984-1986`.
4. Die brugfactor wordt gebruikt om de post-`1984`-reeks op het niveau van de pre-`1984`-reeks aan te sluiten.
5. Vervolgens wordt de doorlopende reeks opnieuw geschaald naar een reeks met het eerste beschikbare jaar op `100`.

De bruglogica staat in [trim\_soorten\_en\_msi\_evg.R][1]. De gebruikte methode heet daar expliciet `1981_1983_naar_1984_1986`.

## Huidige status

- `Brugjaren` zijn nu al in gebruik in de R-analyses.
- `T0`-reeksen als aparte analysemethode op basis van jaar-op-jaar veranderingen zijn nog niet toegevoegd aan de R-analyses.
- Waar in de huidige code een reeks naar `100` wordt herschaald, is dat dus nog geen aparte `T0 + delta`-analyse, maar onderdeel van de bestaande brug- en indexlogica.

## Wat is hier nu al aanwezig?

In de huidige code zijn er wel indexreeksen met een vast referentiepunt van `100`, maar nog geen aparte `T0`-analyse op basis van jaar-op-jaar verschillen.

In deze code zijn er twee niveaus:

- eerst per deelreeks een interne index `index_100`
  Voor `1958-1983` en `1984-2025` elk apart.
- daarna een doorlopende gebrugde reeks `index_gebrugged`
  Die wordt na het bruggen opnieuw herschaald zodat het eerste jaar in de samengestelde reeks `100` is.

Belangrijk voor de huidige situatie:

- de brugjaren zijn dus geen extra waarnemingsjaren
- ze zijn een referentievenster om twee deelreeksen aan elkaar te koppelen
- de uiteindelijke schaal `100` is nu de herschaalde doorlopende reeks
- dit is niet hetzelfde als de hieronder beschreven voorgestelde `T0 + delta`-aanpak

## Hoe de brugfactor wordt bepaald

In de hoofd-TRIM-analyse gebeurt dit als volgt:

- gemiddelde nemen van `index_100` in `1981-1983` voor de pre-reeks
- gemiddelde nemen van `index_100` in `1984-1986` voor de post-reeks
- `brugfactor = mean(pre) / mean(post)`
- post-reeks vermenigvuldigen met die brugfactor

Dat gebeurt in [trim\_soorten\_en\_msi\_evg.R][2].

In de alternatieve ecologische-groepenanalyse wordt hetzelfde principe gebruikt op basis van dichtheidsindices in [analyse\_ecologische\_groepen.R][3].

## Bestanden die wel gebrugde reeksen bevatten

Deze bestanden steunen direct op `index_gebrugged` of op MSI die daarvan is afgeleid.

### Hoofd-TRIM-analyse soorten

- `trim/soorten/soortindices_per_jaar.csv`
- `trim/soorten/soortindices_bruikbare_tijdreeks.csv`
- `trim/soorten/soorten_trendoverzicht.csv`
- `trim/soorten/soorten_trendoverzicht_bruikbare_tijdreeks.csv`
- `trim/soorten/soorten_brugfactoren.csv`

De schrijfslag hiervoor staat in [trim\_soorten\_en\_msi\_evg.R][4].

### TRIM-MSI per ecologische groep

- `trim_msi_evg/msi_per_groep_per_jaar.csv`
- `trim_msi_evg/trendoverzicht_msi_groepen.csv`
- `trim_msi_evg/gam_voorspellingen_msi_groepen.csv`
- `trim_msi_evg/gam_trendanalyse_msi_groepen.csv`
- `trim_msi_evg/gam_interpretatie_msi_groepen.csv`

Deze MSI wordt expliciet opgebouwd uit gebrugde soortindices in [trim\_soorten\_en\_msi\_evg.R][5].

### Alternatieve analyse ecologische groepen

Ook deze outputs gebruiken de overbrugde indexbenadering:

- `doorlopende_index_per_groep.csv`
- `trendanalyse_per_groep.csv`
- `trendanalyse_los_per_periode.csv`
- `vergelijking_trends_tussen_periodes.csv`
- `gam_trendanalyse_per_groep.csv`
- `gam_interpretatie_per_groep.csv`
- `gam_voorspellingen_per_groep.csv`
- `soortindices_voor_msi.csv`

De schrijfslag hiervoor staat in [analyse\_ecologische\_groepen.R][6].

## Bestanden die niet op brugjaren steunen

Dit zijn basisbestanden, selecties of ruwe dichtheidsuitvoer zonder toepassing van de brugfactor:

- `trim/soorten/analysebasis_plot_jaar.csv`
- `trim/soorten/soorten_modelstatus.csv`
- `trim/soorten/soorten_status_samenvatting.csv`
- `trim/soorten/soorten_bruikbare_tijdreeks_selectie.csv`
- `trim_msi_evg/groepssamenstelling_100tal.csv`
- `jaarreeksen_dichtheid_per_groep.csv`
- `vergelijking_periodes_1958_1983_vs_1984_2025.csv`
- `vergelijking_oude_analyse_vs_msi.csv`

## Relatie met html en shiny

De html en shiny rekenen deze brug niet opnieuw uit. Ze lezen de al berekende CSV-bestanden in.

Voor de gebruikersweergave betekent dat:

- `TRIM-index` toont gebrugde soortreeksen
- `TRIM-MSI` toont gebrugde groepsreeksen
- `Territoria` toont ruwe aantallen
- `Dichtheid (per km²)` toont niet-gebrugde dichtheidsuitkomsten

Zie onder meer [bmp\_meijendel\_index.html][7] en [bmp\_meijendel\_index.html][8].

## Nuance voor de Sandra-reeksen

De `Sandra`-analyse loopt vanaf `1997` en ligt daarmee volledig ná de methodebreuk van `1984`.

Daardoor speelt de brug over `1981-1983` versus `1984-1986` daar inhoudelijk geen rol. Die set werkt wel met indexreeksen met basis `100`, maar niet met deze historische overbrugging rond `1984`.

## Voorgestelde T0-reeksen met jaar-op-jaar verschillen

### Uitgangspunt

Je werkt met twee tijdreeksen, pre- en post-`1984`, die methodologisch niet goed vergelijkbaar zijn. Daarom is het verdedigbaar om niet primair de absolute niveaus te vergelijken, maar de jaar-op-jaar veranderingen.

Dat is een bekende en gangbare strategie in tijdreeksanalyse. In de literatuur en statistiek komt dit terug als:

- `first differences`: `y_t - y_{t-1}`
- `growth rates`: `(y_t - y_{t-1}) / y_{t-1}`
- `log-differences`: `log(y_t) - log(y_{t-1})`
- in ecologie: jaarlijkse groeifactor `lambda` of intrinsieke groeisnelheid `r`

### Formele opzet

Stap 1:

- normaliseer per reeks op `T0`
- `I_t = y_t / y_T0`

Stap 2:

- bereken daarna alleen de verandering van jaar op jaar

Dat kan als relatieve verandering:

- `Delta_t = (y_t - y_{t-1}) / y_{t-1}`

Of als log-difference:

- `log(y_t) - log(y_{t-1})`

Interpretatie:

- je vergelijkt niet de niveaus
- je vergelijkt de dynamiek van de reeksen

### Delta versus log-difference

Beide maten beschrijven dezelfde grootheid, verandering, maar op een andere schaal:

- relatieve verandering is een percentage ten opzichte van het vorige jaar
- log-difference is de log van de groeifactor

Bij kleine veranderingen zijn beide bijna gelijk. Bij grotere veranderingen lopen ze uiteen.

Het belangrijke verschil zit in de wiskundige eigenschappen:

- relatieve veranderingen zijn multiplicatief
- log-differences maken dat additief

Dat additieve karakter is belangrijk, omdat log-differences daardoor:

- optelbaar zijn over de tijd
- gemiddeld kunnen worden over soorten

### Waarom dit relevant is voor MSI

Het doel is niet alleen trends per soort, maar ook een `MSI`, een `Multi Species Index`.

Zo'n `MSI` wordt in de praktijk vrijwel altijd berekend als geometrisch gemiddelde van soortindices. Dat betekent impliciet:

- de analyse werkt al in log-ruimte
- log-differences passen daar methodologisch beter bij dan gewone relatieve verschillen

Daarmee is de voorlopige voorkeursrichting:

- voor T0-reeksen liever `log-differences`
- alleen uitwijken naar gewone `delta` als daar een expliciete reden voor is

### Het echte knelpunt: soortkeuze

De kernvraag is uiteindelijk niet alleen `delta` versus `log-difference`, maar vooral welke soorten je in de T0-analyse opneemt.

De dataset is niet homogeen:

- ongeveer `50` plots
- niet ieder jaar geteld, dus `NA` komt veel voor
- een mix van algemene en zeldzame soorten

Daardoor geldt:

- algemene soorten leveren vaak een bruikbare, relatief continue trend
- zeldzame soorten geven veel nullen, sprongen en instabiliteit

### Waarom zeldzame soorten veel ruis geven

Bij zeldzame soorten zie je vaak:

- veel nulwaarden
- sprongen zoals `0 -> 1 -> 0`
- grote relatieve fluctuaties door kleine aantallen
- extra gevoeligheid voor toeval, weersinvloeden en waarnemerseffecten

Gevolg:

- gewone `delta` geeft snel extreme ruis
- `log-difference` is bij nulwaarden niet gedefinieerd

Daarom klopt het eerdere advies:

- zeldzame of incidentele soorten niet forceren in dezelfde T0-differentie-analyse
- ze liever buiten de T0-analyse laten of apart analyseren

Dit is dus geen inhoudelijk oordeel over de soort, maar een methodologische keuze om instabiele signalen niet als trend te presenteren.

### Beslisregel voor opname van soorten

Voor de T0-analyse is het logisch om soorten vooraf in twee groepen te splitsen:

`1. Algemene soorten`

Deze komen wel in aanmerking voor T0-analyse als de tijdreeks voldoende stabiel is.

Indicaties:

- weinig nulwaarden
- voldoende jaren met geldige tellingen
- voldoende opeenvolgende geldige jaarparen
- geen extreem springerig patroon uitsluitend door kleine aantallen

`2. Zeldzame of incidentele soorten`

Deze komen bij voorkeur niet in de T0-analyse.

Indicaties:

- veel nulwaarden
- weinig jaren met aanwezigheid
- weinig geldige opeenvolgende jaarparen
- grote schijnfluctuaties door kleine aantallen

### Voorstel voor harde operationele criteria

Om dit document als beslisdocument te kunnen gebruiken, is hieronder een voorlopig voorstel voor vaste drempels opgenomen. Deze drempels zijn pragmatisch en moeten later desgewenst empirisch worden getoetst.

#### Opname in T0-analyse op soortniveau

Een soort komt voorlopig alleen in aanmerking voor T0-analyse als aan alle onderstaande voorwaarden wordt voldaan:

- minimaal `10` jaren met geldige tellingen binnen de te analyseren periode
- minimaal `8` geldige opeenvolgende jaarparen
- in maximaal `50%` van de geldige jaren een nulwaarde
- minimaal `5` jaren met een positieve waarde
- geen volledig extreme instabiliteit door alleen losse incidentele waarnemingen

Praktisch betekent dit:

- soorten met slechts enkele losse presenties vallen af
- soorten met vooral gaten in de reeks vallen af
- soorten die alleen op basis van zeer kleine aantallen op en neer springen vallen af

#### Extra eis voor opname in T0-MSI

Voor opname in een geaggregeerde `T0-MSI` is een strengere selectie logisch. Voorstel:

- de soort voldoet eerst aan alle eisen voor soortniveau
- minimaal `12` geldige jaren
- minimaal `10` geldige opeenvolgende jaarparen
- in maximaal `33%` van de geldige jaren een nulwaarde
- aanwezigheid in zowel het vroege als het late deel van de analyseperiode

De reden voor deze strengere selectie is:

- een `MSI` wordt instabiel als te veel soorten zelf al een zwakke of gefragmenteerde tijdreeks hebben
- voor aggregatie moet de invoer strenger zijn dan voor een individuele soortgrafiek

#### Soorten die voorlopig buiten T0 blijven

Een soort blijft voorlopig buiten de T0-analyse als een van de volgende situaties optreedt:

- minder dan `10` geldige jaren
- minder dan `8` geldige opeenvolgende jaarparen
- meer dan `50%` nulwaarden in geldige jaren
- minder dan `5` positieve jaren
- reeks bestaat vooral uit incidentele `0 -> 1 -> 0`-sprongen

Voor `T0-MSI` geldt bovendien uitsluiting als:

- minder dan `12` geldige jaren
- minder dan `10` geldige opeenvolgende jaarparen
- meer dan `33%` nulwaarden

#### Behandeling van grensgevallen

Niet elke soort zal duidelijk in de categorie algemeen of zeldzaam vallen. Daarom is een tussenklasse praktisch:

- `geschikt voor T0-soortanalyse`
- `twijfelgeval, wel tonen op soortniveau maar niet meenemen in MSI`
- `ongeschikt voor T0, wel apart analyseren`

Dit voorkomt dat twijfelgevallen direct uit alle analyses verdwijnen, terwijl de samengestelde index toch streng bewaakt blijft.

### Praktisch advies voor dit project

Voor de T0-analyse is de werkhypothese:

- algemene soorten wel meenemen
- zeldzame soorten uitsluiten uit de T0-differentie-analyse
- zeldzame soorten apart analyseren met `TRIM` of `GLM`, bijvoorbeeld `Poisson` of `negative binomial`
- grensgevallen alleen op soortniveau tonen en niet automatisch meenemen in de `T0-MSI`

Dat sluit aan op wat eerder uit de discussie volgde:

- de T0-analyse moet vooral een robuuste dynamische trendindicator zijn
- geen verzamelbak voor alle soorten ongeacht datakwaliteit

### Geldige jaarparen

Bereken een jaar-op-jaar verandering alleen als:

- beide jaren echt geteld zijn
- beide waarden bruikbaar zijn voor de gekozen maat

Anders:

- `NA`

Dat betekent concreet:

- geen verandering berekenen over gaten in de reeks
- geen automatische imputatie in de T0-differentie-analyse

### Effect op de MSI

Zelfs bij correcte berekening geldt:

- dominante, algemene soorten bepalen meestal de index
- zeldzame soorten verstoren de index of moeten worden uitgesloten

Daarom moet de resulterende `MSI` correct worden geïnterpreteerd als:

- primair een indicator van de gemiddelde trend van de algemene soorten

En niet direct als:

- een maat voor totale biodiversiteit

### Vergelijking met brugjaren

Voordelen van `T0 + verandering`:

- minder afhankelijk van absolute schaal en telmethode
- geen expliciete schatting nodig van een correctiefactor
- bruikbaar als de methodebreuk groot is en lastig te modelleren is
- legt nadruk op dynamiek

Nadelen van `T0 + verandering`:

- verlies van niveau-informatie
- grotere gevoeligheid voor ruis
- geen expliciete correctie van de breuk zelf
- minder intuïtieve lange-termijninterpretatie

Voordelen van `brugjaren`:

- niveauvergelijking blijft mogelijk
- expliciete correctie over de methodebreuk
- meestal stabieler voor langjarige interpretatie

Nadelen van `brugjaren`:

- meer aannames
- afhankelijk van de kwaliteit van de geschatte correctiefactor

### Beslispunten voor implementatie

Om dit om te zetten naar R-analyse moeten nog expliciet besluiten worden genomen over:

- keuze voor `log-difference` als standaard of niet
- definitieve selectiecriteria voor opname van soorten
- definitieve ondergrens voor aantal geldige jaren
- definitieve ondergrens voor aantal geldige opeenvolgende jaarparen
- omgang met nulwaarden
- aparte behandeling van zeldzame soorten
- of er een aparte categorie `twijfelgeval` komt
- of er een aparte T0-output per soort en een aparte T0-MSI per groep komt

### Voorlopig beslisschema

Stap 1: controleer of een soort genoeg geldige jaren heeft.

- minder dan `10`: niet opnemen in T0
- `10` of meer: ga door

Stap 2: controleer het aantal geldige opeenvolgende jaarparen.

- minder dan `8`: niet opnemen in T0
- `8` of meer: ga door

Stap 3: controleer nulwaarden en positieve jaren.

- meer dan `50%` nulwaarden of minder dan `5` positieve jaren: niet opnemen in T0
- anders: geschikt voor T0-soortanalyse

Stap 4: controleer of de soort ook streng genoeg is voor MSI.

- minimaal `12` geldige jaren
- minimaal `10` geldige opeenvolgende jaarparen
- maximaal `33%` nulwaarden
- aanwezigheid in vroeg en laat deel van de reeks

Bij voldoen:

- opnemen in `T0-MSI`

Bij niet voldoen maar wel geschikt op soortniveau:

- wel tonen als T0-soortreeks
- niet meenemen in `T0-MSI`

### Voorlopige projectconclusie

De sterkste strategie voor dit project is waarschijnlijk combineren:

- `brugjaren` voor niveaucontinuiteit en vergelijking over de breuk
- `T0 + log-differences` als aanvullende robuustheidsanalyse voor trendrichting en dynamiek

De vraag verschuift daarmee van een keuze tussen twee formules naar een beslisstructuur:

- eerst soortkeuze
- daarna keuze van de maat
- daarna aggregatie naar `MSI`

Kort samengevat:

- `log-difference` is methodologisch meestal de beste basis
- maar alleen als de soort een voldoende stabiele tijdreeks heeft
- zeldzame soorten horen daarom meestal niet thuis in dezelfde T0-analyse
- voor die soorten is een aparte aanpak verdedigbaarder

## Eerste repo-doorrekening van de T0-selectie

Op basis van de huidige repo-inhoud is een eerste selectie doorgerekend voor alle soorten binnen de ecologische vogelgroepen.

Gebruikte bronbestanden:

- [Meijendel.sql](/Users/ton/Documents/GitHub/Meijendel/Meijendel.sql)
- [analysebasis_plot_jaar.csv](/Users/ton/Documents/GitHub/Meijendel/trim/soorten/analysebasis_plot_jaar.csv)
- [groepssamenstelling_100tal.csv](/Users/ton/Documents/GitHub/Meijendel/trim_msi_evg/groepssamenstelling_100tal.csv)
- [evg_selctie_T0soort_T0msi.csv](/Users/ton/Documents/GitHub/Meijendel/R/evg_selctie_T0soort_T0msi.csv)

### Inleidende aannames bij deze doorrekening

Deze eerste selectie is een operationele doorrekening van de hierboven vastgelegde drempels. Daarbij zijn de volgende aannames gebruikt:

- `geldige jaren` zijn alle analysejaren met surveydekking in de basis
- dat zijn in deze repo `68` jaren, van `1958` tot en met `2025`
- `geldige jaarparen` zijn opeenvolgende jaren waarin de soort in beide jaren een positieve jaarwaarde heeft
- `nul_aandeel` is het aandeel analysejaren waarin de soort op jaarbasis op `0` uitkomt
- `pre_1984_aanwezig` betekent minstens één positief jaar in `1958-1983`
- `post_1984_aanwezig` betekent minstens één positief jaar in `1984-2025`

Belangrijke nuance:

- doordat vrijwel alle soorten tegen dezelfde set analysejaren worden getoetst, discrimineren de criteria in de praktijk vooral op `positieve_jaren`, `geldige_jaarparen`, `nul_aandeel` en aanwezigheid vóór en na `1984`
- dit is dus een eerste technische selectie, geen definitieve ecologische validatie
- soorten kunnen in meerdere ecologische groepen voorkomen, omdat de EVG-koppeling in de data zo is vastgelegd

### Samenvatting per ecologische vogelgroep

`100 Watervogels`

- `T0-soortanalyse`: `14` soorten
- `T0-MSI`: `14` soorten
- alle geselecteerde soorten op soortniveau vallen hier ook in de strengere `T0-MSI`

`200 Rietvogels`

- `T0-soortanalyse`: `7` soorten
- `T0-MSI`: `6` soorten
- `Blauwborst` haalt hier wel de soortselectie, maar niet de strengere `T0-MSI`

`300 Vogels van pionierbegroeiingen`

- `T0-soortanalyse`: `14` soorten
- `T0-MSI`: `9` soorten
- vooral soorten met meer gaten of hogere nul-aandelen vallen hier af voor `T0-MSI`

`400 Vogels van open heide`

- `T0-soortanalyse`: `6` soorten
- `T0-MSI`: `4` soorten
- `Veldleeuwerik` en `Wulp` halen hier wel soortniveau, maar niet de strengere MSI-selectie

`500 Weidevogels`

- `T0-soortanalyse`: `9` soorten
- `T0-MSI`: `7` soorten
- ook hier vallen enkele soorten af bij de strengere MSI-criteria

`600 Struweelvogels`

- `T0-soortanalyse`: `22` soorten
- `T0-MSI`: `19` soorten
- dit is een van de rijkste groepen voor de voorgestelde T0-benadering

`700 Bosrandvogels`

- `T0-soortanalyse`: `18` soorten
- `T0-MSI`: `16` soorten

`800 Bosvogels`

- `T0-soortanalyse`: `29` soorten
- `T0-MSI`: `21` soorten
- dit is de grootste groep in de huidige doorrekening

`900 Vogels van bebouwing/overige`

- `T0-soortanalyse`: `9` soorten
- `T0-MSI`: `4` soorten
- hier is het verschil tussen soortniveau en MSI-niveau relatief groot

### Interpretatie van deze eerste uitkomst

Deze eerste repo-doorrekening bevestigt de eerder geformuleerde hoofdgedachte:

- voor T0-analyse zijn vooral algemene en vrij continu aanwezige soorten bruikbaar
- de strengere `T0-MSI`-selectie reduceert het aantal soorten verder
- zeldzamere of meer gefragmenteerde reeksen vallen relatief vaak af tussen `T0-soortanalyse` en `T0-MSI`

Dat ondersteunt de beslislijn uit dit document:

- eerst soortselectie
- daarna keuze voor `log-difference`
- daarna pas aggregatie naar `MSI`

### Praktisch resultaat

Het volledige overzicht per soort en per ecologische groep staat in:

- [evg_selctie_T0soort_T0msi.csv](/Users/ton/Documents/GitHub/Meijendel/R/evg_selctie_T0soort_T0msi.csv)

Dat bestand bevat per soort onder meer:

- groep en groepsnaam
- soort-id, euring-code en soortnaam
- aantal analysejaren
- aantal positieve jaren
- aantal geldige jaarparen
- nul-aandeel
- aanwezigheid vóór en na `1984`
- selectie voor `T0-soortanalyse`
- selectie voor `T0-MSI`

## Ecologische validatie van de T0-MSI-selectie

Na de technische selectie is voor de soorten met `t0_msi = TRUE` een extra ecologische beoordeling toegevoegd. Die beoordeling heeft drie mogelijke uitkomsten:

- `houden`
  De soort past inhoudelijk goed bij de betreffende ecologische vogelgroep en is bruikbaar als groepsindicator.
- `twijfelgeval`
  De soort voldoet technisch, maar is ecologisch minder scherp als groepsindicator, bijvoorbeeld doordat zij te algemeen is, een brede habitatvoorkeur heeft of op de groepsgrens zit.
- `niet_opnemen`
  De soort voldoet technisch, maar is ecologisch onvoldoende passend voor opname in een uiteindelijke `T0-MSI` van die groep.

Daarmee wordt onderscheid gemaakt tussen:

- `technische selectie`
  Filter op jaren, jaarparen, nulwaarden en pre/post-`1984`
- `ecologische eindselectie`
  Inhoudelijke keuze of de soort echt als indicator voor die EVG-groep moet meetellen

### Gebruikte ecologische beoordelingslogica

Bij de handmatige review zijn vooral deze vragen gebruikt:

- is de soort een kernsoort van de betreffende ecologische groep
- is de trend van de soort waarschijnlijk informatief voor de groep en niet vooral voor een ander milieu
- is de soort te algemeen om als scherpe groepsindicator te dienen
- is er sprake van een exoot, restgroep, randsoort of brede generalist

Typische redenen voor `twijfelgeval`:

- brede habitatvoorkeur
- soort ligt op de grens van twee groepen
- soort is wel aanwezig in de groep, maar geen sterke kernindicator

Typische redenen voor `niet_opnemen`:

- duidelijke mismatch tussen soort en groepskern
- te algemene cultuurvolger
- indicatorwaarde voor de gekozen groep is zwak of misleidend

### Uitkomst van de ecologische review per groep

Alle aantallen hieronder gaan alleen over soorten die technisch al `t0_msi = TRUE` waren.

`100 Watervogels`

- `houden`: `12`
- `twijfelgeval`: `2`
- `niet_opnemen`: `0`

`200 Rietvogels`

- `houden`: `4`
- `twijfelgeval`: `2`
- `niet_opnemen`: `0`

`300 Vogels van pionierbegroeiingen`

- `houden`: `4`
- `twijfelgeval`: `3`
- `niet_opnemen`: `2`

`400 Vogels van open heide`

- `houden`: `1`
- `twijfelgeval`: `1`
- `niet_opnemen`: `2`

`500 Weidevogels`

- `houden`: `3`
- `twijfelgeval`: `2`
- `niet_opnemen`: `2`

`600 Struweelvogels`

- `houden`: `7`
- `twijfelgeval`: `7`
- `niet_opnemen`: `5`

`700 Bosrandvogels`

- `houden`: `5`
- `twijfelgeval`: `5`
- `niet_opnemen`: `6`

`800 Bosvogels`

- `houden`: `9`
- `twijfelgeval`: `9`
- `niet_opnemen`: `3`

`900 Vogels van bebouwing/overige`

- `houden`: `3`
- `twijfelgeval`: `1`
- `niet_opnemen`: `0`

### Hoe dit in het CSV-bestand is verwerkt

In [evg_selctie_T0soort_T0msi.csv](/Users/ton/Documents/GitHub/Meijendel/R/evg_selctie_T0soort_T0msi.csv) zijn drie extra kolommen toegevoegd:

- `ecologische_beoordeling_t0_msi`
- `ecologische_toelichting_t0_msi`
- `t0_msi_eindselectie`

Interpretatie:

- `t0_msi = TRUE` betekent dat de soort technisch de drempels haalt
- `t0_msi_eindselectie = TRUE` betekent dat de soort na ecologische beoordeling voorlopig wordt `gehouden`
- soorten met `twijfelgeval` of `niet_opnemen` staan dus niet in de voorlopige ecologisch gevalideerde eindselectie

### Voorlopige betekenis voor het project

Deze extra review bevestigt dat technische selectie alleen niet genoeg is. Vooral in groepen als `Struweelvogels`, `Bosrandvogels` en `Bosvogels` blijven na de technische selectie nog meerdere soorten over die ecologisch twijfelachtig of te algemeen zijn.

De praktische beslislijn wordt daarmee:

1. technische T0-selectie
2. ecologische review per soort binnen de EVG-groep
3. pas daarna opname in de voorlopige `T0-MSI`-eindselectie

[1]:	/Users/ton/Documents/GitHub/Meijendel/R/trim_soorten_en_msi_evg.R:480
[2]:	/Users/ton/Documents/GitHub/Meijendel/R/trim_soorten_en_msi_evg.R:502
[3]:	/Users/ton/Documents/GitHub/Meijendel/R/analyse_ecologische_groepen.R:310
[4]:	/Users/ton/Documents/GitHub/Meijendel/R/trim_soorten_en_msi_evg.R:849
[5]:	/Users/ton/Documents/GitHub/Meijendel/R/trim_soorten_en_msi_evg.R:667
[6]:	/Users/ton/Documents/GitHub/Meijendel/R/analyse_ecologische_groepen.R:646
[7]:	/Users/ton/Documents/GitHub/Meijendel/bmp_meijendel_index.html:672
[8]:	/Users/ton/Documents/GitHub/Meijendel/bmp_meijendel_index.html:890
