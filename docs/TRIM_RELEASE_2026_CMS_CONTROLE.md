# Lokale controle van CMS-inhoud en figuren voor de release 2026

Gecontroleerd in VWG_M op commit `7bc1562`, met PostgreSQL `vwg_linux_port_test` op 127.0.0.1 in een alleen-lezen transactie. De inventarisatie omvat 60 app-paginadefinities uit de secties Meijendel, groepen, soorten en tellingen. De testdatabase bevat drie rijen in `app.cms_pages`. Alle drie zijn actief en dateren van 30 juli 2026. De applicatie gebruikt ze voor `/tellingen/index.asp`, `/meijendel/verhalen/broedvogels-en-begrazing.asp` en `/meijendel/verhalen/paradox-open-duin.asp`. Voor de overige 57 definities komt de effectieve tekst uit de checkout. De testdatabase bevat daarnaast één historische `app.webpages`-rij voor de map Meijendel, ID 2. Deze controle beschrijft de lokale stand. Bij de uiteindelijke release moeten CMS-overschrijvingen en uploads van de gekozen releasebasis met deze inventaris worden vergeleken.

De effectieve teksten zijn opgehaald via de normale CMS-functie, inclusief de tekstvervangingen van de app. De controle van beeldverwijzingen betreft de inline afbeeldingen in de teksten en de databron van de grafieken. De gerenderde pagina’s, afbeeldingen in alle schermformaten en de live MySQL-reeks voor de meeuwengrafiek horen in de lokale schermproef.

De correcties zijn inmiddels op een afzonderlijke lokale CMS-kandidaat toegepast. Uitvoering, routecontroles en resterende ontbrekende bestanden staan in [de aansluitnotitie](TRIM_RELEASE_2026_AANSLUITING.md).

De vervolgcontrole op 4 november 2026 heeft de drie archieffoto’s teruggevonden en hersteld. De actuele websitekoppelingen zijn in een afzonderlijke lokale MySQL-proef geplaatst. De volledige soortpagina’s en gewone connector werken. Zie de afsluitende bevindingen in [de aansluitnotitie](TRIM_RELEASE_2026_AANSLUITING.md).

## Voorbereiding die losstaat van de officiële levering

- **Begrazing.** De opgeslagen tekst verwijst naar `nachtegaalhabitat-kijfhoek-bierlap-hollands-duinen-86.jpg`. Dat bestand ontbreekt in de checkout. Migratie 167 bevat de vervanging door `nachtegaalhabitat-meijendel-roman-boed.webp`, die lokaal aanwezig is. Neem de bestaande correctie op in de lokale releasekandidaat en controleer foto, alt-tekst en credit samen. Het kaartbestand `begrazingsgebieden-hollands-duinen-60.jpg` is lokaal aanwezig.
- **Paradox open duin.** In de opgeslagen CMS-tekst ontbreekt de passage over GPS-onderzoek aan de Meervleermuis uit migratie 174. Vergelijk het met de inhoudelijke correcties in migratie 174 en neem de relevante correcties mee bij de samenstelling van de kandidaat. De SVG is lokaal aanwezig. Zij vergelijkt 27 vergelijkbaar getelde kavels in 1997–2001 en 2018–2022, met Boomleeuwerik en de overige soorten van lage vegetatie als afzonderlijke reeksen. Laat figuur en bijschrift bij die vergelijking horen.
- **Meeuwenkolonie.** Drie afbeeldingen in de verhaaltekst verwijzen naar de uploadcollectie `photo-archive`, onder IDs 7, 10 en 19. De bestanden zijn afwezig in de checkout. Controleer lokaal de beschikbare uploadkopie en de bijschriften. De grafiek komt afzonderlijk uit een dynamische som van territoria van vier meeuwensoorten vanaf 1973. Controleer bij de releaseproef het eindjaar, de piek in het bijschrift, de selectie van tellingen en de behandeling van lege jaren.
- **Groepsgrafieken.** De websitefunctie `group_gam_svg()` leest feitelijk `groep_dichtheid.csv`. Alle 32 onderscheiden grafiekcodes uit de app leverden met de lokale CSV geldige SVG-XML op, elk met 68 jaarregels over 1958–2025. Leg dichtheid, MSI en GAM per scherm apart vast. Vergelijk gelijksoortige grafieken op waarden, schaal en legenda. Controleer expliciet waarom Bebouwing en Overige situaties dezelfde grafiekcode 900 delen.

## Verhalen en overzichtspagina’s

Voor verhaalroutes is het vaste voorvoegsel `/meijendel/verhalen/` en de uitgang `.asp`. De kolom over de levering betreft de officiële **broedvogellevering**. Verlengingen van andere bronreeksen vragen een eigen gevalideerde levering of een afzonderlijke heranalyse.

| Pagina | Vastgelegd voor de release | Afhankelijk van de officiële levering |
|---|---|---|
| `/meijendel/index.asp` en `/meijendel/verhalen.asp` | Controleer de samenvattingen en kaarten die naar tel- en analysepagina’s verwijzen. | Actualiseer alleen cijfers en eindjaren die de nieuwe reeks samenvatten. |
| `/meijendel/vogelonderzoek.asp` | De uitleg bevat een recente vergelijking met 2025. Houd methodebreuk en historische omslagjaren expliciet. | Herbereken de recente vergelijking en controleer de omschrijving van de dekking. |
| `/meijendel/beschrijving.asp` | De gecontroleerde tekst gebruikt historische beschrijving en historische jaartallen. | Geen wijziging voorzien op basis van de broedvogellevering. |
| `/meijendel/bereikbaarheid.asp`, `/meijendel/vogelaarswandeling.asp`, `/meijendel/bescherming.asp` | Toegang, route en gebiedsbescherming hebben eigen bronnen en peildata. | Geen wijziging voorzien op basis van de broedvogellevering. |
| `broedvogels-en-begrazing` | Herstel de lokaal ontbrekende fotokoppeling via de bestaande correctie. De Nachtegaalstudie uit 2025 blijft herkenbaar als aangehaalde studie. | Alleen een expliciete actualisatie van de lokale vogelanalyse vraagt nieuwe tellingen en herberekening van de bijbehorende vergelijking. |
| `paradox-open-duin` | Vergelijk de opgeslagen tekst met migratie 174. De figuur met 27 kavels heeft vaste vensters 1997–2001 en 2018–2022. | Actualiseer een nieuwe peildatum en tellingstotalen samen. De vergelijking met 13 kavels en 1958–1962 tegenover 2021–2025 vraagt een heranalyse zodra het eindvenster verandert. |
| `meeuwenkolonie` | Controleer drie archieffoto’s en de koppeling tussen dynamische grafiek en bronvermelding. | Ververs de vier-soortensom en het grafiekeindjaar zodra 2026 gevalideerd is. Beoordeel de tekst tegen dezelfde reeks. |
| `riet-en-watervogels` | De tekst verwijst naar Open water en Rietvegetaties. Benoem welke uitspraken op dichtheid en welke op de geometrische groepsindex rusten. | Herbereken actuele groeps- en soortuitspraken en controleer de gelinkte grafieken en bronperiode. |
| `landelijke-spiegel` | Sovon-rapport over 2025 is de aanleiding. De lokale vergelijking noemt onder meer circa 9% daling bij water en 9% stijging bij riet in 2025 tegenover 2024. | Actualiseer lokale vergelijkingen op een passend gemeenschappelijk venster. Voor landelijke verlenging is de landelijke bronlevering bepalend. |
| `grote-karekiet` | De tekst onderscheidt 10 territoriumregels met samen 11 territoria in 1958–2025 van twee dagwaarnemingen in 2025. | Controleer 2026 op territoria, dagwaarnemingen, broedcode en kaveldekking en pas de uitspraken per bron aan. |
| `raaf-in-meijendel` | Onderscheid de brede vogel- en winterbezoeken, BMP-dagwaarnemingen, territoria en losse veldinformatie. | Hercontroleer de lokale uitspraak over het ontbreken van BMP-registraties en territoria in de verlengde reeks. Brede telreeksen en landelijke broedgevallen hebben eigen einddata. |
| `tapuit-in-meijendel` | Scheid de lokale territoriumgeschiedenis van de vegetatie-inventarisatie van de Kikkervalleien uit 2025. | Controleer laatste lokale territoriumstatus en bronsteun. De aangehaalde vegetatiestudie houdt haar bronperiode. |
| `wisseling-van-de-wacht` | De soortvergelijkingen verwijzen naar TRIM-uitvoer over 1958–2025. Controleer ook de historische ankerjaren. | Ververs eindwaarden, soortselecties en richting van vergelijkingen uit de nieuwe trenduitvoer. |
| `steeds-meer-van-hetzelfde` | De tekst gebruikt eindwaarden voor onder meer boomholte-, gebouw- en grondholenbroeders. De pagina linkt naar functionele groepen. | Herbereken de cijfers en groepssamenstelling bij actualisatie. Geef iedere groep de eigen onzekerheidsstatus. |
| `trekvogels-twee-werelden` | De tekst gebruikt een lokaal gepaarde kavelanalyse en een afzonderlijke dashboardindex voor langeafstandstrekkers. | Actualiseer de dashboardwaarde en tekst samen. Wijzig de vaste kavelvergelijking uitsluitend bij een nieuwe analyse. |
| `terugkeer-van-de-nacht` | De tekst bevat recente territoriumuitspraken over onder meer Bosuil en Ransuil en een afzonderlijke bezoekanalyse. | Controleer territoria en recente kavelspreiding. Voor een update van detectie zijn de dagwaarnemingen en bezoeken nodig. |
| `klimaatverandering` | De eerste-registratieanalyse gebruikt BMP-bezoeken en dagwaarnemingen uit 2007–2025 met weergegevens. | Alleen een nieuwe gekoppelde bezoek- en weeranalyse kan die periode verlengen. |
| `vogels-op-de-klok-van-het-weer` | De vaste analyse vergelijkt de eerste registratie met telmoment en weer. | Verleng uitsluitend met gevalideerde bezoeken, dagwaarnemingen en weergegevens. |
| `predatie-in-het-duin` | De bronparagraaf gebruikt 70.895 territoriumregels over 1958–2025 en een vergelijking met 27 kavels. | Maak een nieuwe peildatum met bijbehorende broncijfers bij actualisatie. Een veranderde kavelvergelijking vraagt een eigen heranalyse. |
| `broedvogels-en-stikstof` | De beheerplanevaluatie uit 2025 en de soortfoto’s hebben elk een eigen bron. | Herbereken alleen de lokaal geactualiseerde soort- of groepsuitkomsten. Behoud bronjaar en reikwijdte van de beheerplanevaluatie. |
| `recreatie-en-broedvogels` | De tekst koppelt vogelgegevens aan recreatiecontext. | Controleer alleen geactualiseerde vogeluitspraken. Een nieuwe uitspraak over recreatiedruk vraagt passende recreatiegegevens. |
| `geschiedenis-vogelwerkgroep` | Scheid het historische begin van de actuele aanduiding van omvang, kavels en telperiode. | Hercontroleer het actuele onderzoeksbereik en de tellingstotalen bij een gewijzigde bronselectie. |
| `konijn-en-grijs-duin` | De tekst bevat 26 van 284 bezoeken met konijn in 2025 en een vaste vergelijking in 19 kavels. | Verleng uitsluitend met gevalideerde DAZ-bezoeken en konijnregistraties met vergelijkbare registratie-inspanning. |
| `pq-vegetatie` | De vegetatietrend gebruikt de provinciale PQ-bron, waaronder 83 PQ’s in Berkheide en 164 in Meijendel voor 1994–2025. | De broedvogellevering verandert de PQ-periode niet. Een nieuwe geïntegreerde vergelijking vraagt beide passende bronnen. |
| `natuurherstel` | De achtste inventarisatie uit 2025 en de aangehaalde vegetatiestudie hebben vaste bronperioden. | Voor verlenging van de herstelvergelijking is een nieuwe passende inventarisatie nodig. |

## Tellingen, soorten en groepen

| Pagina | Lokale bron en aanpassing | Wacht op de levering |
|---|---|---|
| `/tellingen/index.asp` | Opgeslagen actieve CMS-intro. Controleer dat de tekst de route naar BMP, winter en andere tellingen correct beschrijft. | Dynamische recente broedvogelcijfers volgen de gevalideerde bron. |
| `/tellingen/bmp.asp`, `/tellingen/jaar.asp`, `/tellingen/totaallijst.asp`, `/tellingen/euringlijst.asp` | Bronroute en downloads. Bereid controle van jaarfilter, codekoppeling en ontbrekende tellingen voor. | Jaar 2026, totalen en exportregels volgen de gevalideerde levering. |
| `/soorten/index.asp`, `/soorten/alle-soorten.asp`, `/soorten/vogel.asp?id=…` | De introductie van de soortenindex komt uit de checkout. Bereid per soort een afzonderlijke weergave van telling, periode, index en uitval voor. | Verifieer nieuwe soort-ID’s, broedstatus, jaren en vrijgegeven onzekerheid na herberekening. |
| `/groepen/index.asp` en de vier categorieoverzichten | Bronteksten en navigatie komen uit de checkout. Controleer koppelingen en variantlabels. | Actualiseer eventuele broncijfers bij de herbouw van de groepenuitvoer. |

Voor iedere groepsdetailpagina hieronder geldt dezelfde concrete releasehandeling. Ververs voor de aangegeven code(s) de dichtheidsreeks en de soortlijst, en controleer de SVG en de legenda. Nieuwe jaarwaarden, dekking en groepssamenstelling wachten op de gevalideerde bron. Een vrijgegeven groepsband hoort bij een afzonderlijk berekende, passende groepsschatter.

| Groepspagina | SVG-code(s) |
|---|---|
| `/groepen/2110-embryonale-wandelende-duinen.asp` | `2110-embryonale-wandelende-duinen` |
| `/groepen/2120-witte-duinen.asp` | `2120-witte-duinen` |
| `/groepen/2130-grijze-duinen.asp` | `2130-grijze-duinen` |
| `/groepen/2160-duindoornstruwelen.asp` | `2160-duindoornstruwelen` |
| `/groepen/2180-duinbossen.asp` | `2180-duinbossen` |
| `/groepen/2190-vochtige-duinvalleien.asp` | `2190-vochtige-duinvalleien` |
| `/groepen/3140-kranswierwateren.asp` | `3140-kranswierwateren` |
| `/groepen/6430-ruigten-en-zomen.asp` | `6430-ruigten-en-zomen` |
| `/groepen/open-water.asp` | `100` |
| `/groepen/rietvegetaties.asp` | `200` |
| `/groepen/pioniersvegetaties-en-ruigten.asp` | `300` |
| `/groepen/open-heide-en-hoogveen.asp` | `400` |
| `/groepen/grazige-vegetaties.asp` | `500` |
| `/groepen/struiken-en-struwelen.asp` | `600` |
| `/groepen/bosranden-boomgroepen-bos.asp` | `700` |
| `/groepen/bebouwing.asp` | `900` |
| `/groepen/overige-situaties.asp` | `900` |
| `/groepen/bodemfoeragerende-insecteneters.asp` | `functioneel-bodem-insect-binair`, `functioneel-bodem-insect-gewogen` |
| `/groepen/luchtfoerageerders.asp` | `functioneel-lucht-binair`, `functioneel-lucht-gewogen` |
| `/groepen/grondbroeders.asp` | `functioneel-grondbroed-binair`, `functioneel-grondbroed-gewogen` |
| `/groepen/holenbroeders.asp` | `functioneel-holenbroed-binair`, `functioneel-holenbroed-gewogen` |
| `/groepen/langeafstandstrekkers.asp` | `functioneel-lange-trek-binair`, `functioneel-lange-trek-gewogen` |
| `/groepen/zaadeters.asp` | `functioneel-zaad-binair`, `functioneel-zaad-gewogen` |
| `/groepen/rode-lijst.asp` | `rode-lijst` |
| `/groepen/oranje-lijst.asp` | `oranje-lijst` |
| `/groepen/vogelrichtlijn.asp` | `vogelrichtlijn` |
| `/groepen/rode-en-oranje-lijst.asp` | `rode-en-oranje-lijst` |
