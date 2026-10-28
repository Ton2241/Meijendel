# Besluiten

Dit bestand bewaart de inhoudelijke en technische keuzes voor deze analyse.
Nieuwe besluiten worden gedateerd toegevoegd; eerdere besluiten worden niet
stilzwijgend herschreven.

## 28 oktober 2026 — niet-lineaire en vertraagde PQ–vogelrelaties

- De volgende PQ-fase onderzoekt veranderingen binnen dezelfde plot en latere
  vogelreacties. Een lineair verband en een reactie in uitsluitend het eerste
  jaar worden niet vooraf verondersteld.
- Uit de PQ-soortensamenstelling worden vijf ecologisch benoemde gradiënten
  afgeleid: open zand/pionier, duingrasland/mossen/korstmossen, nat/riet,
  struweel/ruigte en bomen/bos. Verandering wordt per verstreken jaar tussen
  opeenvolgende PQ-opnamen uitgedrukt.
- Het hoofdmodel mag een onmiddellijke reactie, vertraging, drempel, piek,
  herstel of blijvend effect beschrijven. De gladheid wordt begrensd en het
  model wordt tegen een basis- en lineair model getoetst op achtergehouden
  plots en latere jaren.
- De vogelrespons omvat territoriumaantallen, verschijnen/verdwijnen en
  veranderingen van de gemeenschap en vooraf vastgelegde functionele,
  ecologische en habitatgroepen. Een gebeurtenisanalyse rond grotere
  vegetatieveranderingen dient als gevoeligheidsanalyse.
- De actuele dekkingsrun `20261028T142316Z-d6169d52f603` bevat geen
  modelschatting. Zij koppelt de 1.314 plotgekoppelde PQ-opnamen uit 1981–2025
  aan geldige vogelplotjaren met bekende teller/tellerteam. Bij vertraging nul
  zijn 406 vogelplotjaren in 35 plots beschikbaar; bij 3, 7, 10 en 15 jaar
  respectievelijk 349, 285, 233 en 180 vogelplotjaren. Bij vijftien jaar zijn
  nog 32 plots vertegenwoordigd.
- Deze uitkomst bewijst alleen dat vertraagde koppelingen technisch mogelijk
  blijven. De opvolgende intervalanalyse gebruikt EcoDbase uit SynBioSys als
  vogelonafhankelijke referentie voor ecotoop, sociologische groep, levensvorm
  en groeivorm. Bestaande taxongroepen vullen uitsluitend mossen, levermossen,
  korstmossen en algen aan; onbekende vaatplanten worden niet op naamgevoel
  ingedeeld.
- De formele gradiëntenrun `20261028T144429Z-f4416afa2c47` koppelt 528 van 642
  taxa aan ten minste één gradiënt. Een taxon met meerdere gradiënten verdeelt
  zijn bedekking daarover; het wordt niet dubbel geteld. Een plotjaar is geldig
  bij minimaal 80% ingedeelde bronbedekking. Van 501 PQ-plotjaren in 35 plots
  over 1981–2025 zijn er 485 geldig. Alleen twee opeenvolgende, beide geldige
  plotjaren vormen een interval; dat levert 441 intervallen.
- Na vijftien jaar kunnen 149 van deze intervallen in 30 plots aan een geldig
  vogelplotjaar worden gekoppeld. Daarom blijft vijftien jaar de vooraf
  begrensde maximale reactieduur voor gemeenschap en vogelgroepen. Dit is geen
  garantie voor iedere soort; een soortmodel gaat alleen door bij voldoende
  geldige responsrijen en numeriek geldige schatting.

## 26 oktober 2026 — gebruik van HYVEG, MODAK en PROBE

- HYVEG, MODAK en PROBE worden niet als bestaand vogelmodel of als vervanging
  van de PQ-, AHN- en luchtfotoreeksen gebruikt.
- Er wordt met de huidige database geen eigen PROBE-run uitgevoerd. Voor
  PROBE-1 ontbreekt de volledige gebiedsdekkende combinatie van
  vegetatieassociatiekaart, wortelzonecalcium, GVG en GLG.
- Een eventuele bestaande PROBE-uitvoer voor Meijendel wordt pas als
  kandidaatbron beoordeeld wanneer modelversie, invoer, scenario, kalibratie
  en validatie herleidbaar zijn. Toegevoegde voorspellende waarde wordt dan op
  dezelfde plots en achtergehouden jaren getoetst als de overige
  omgevingsblokken.
- De modelopbouw houdt externe druk en gebeurtenissen, vegetatie en
  vegetatiestructuur, en de vogelrespons als afzonderlijke schakels zichtbaar.
  Kortdurende gebeurtenissen kunnen een lang vertraagde vegetatiereactie
  hebben en worden daarom niet uitsluitend met vertragingen van één tot drie
  jaar onderzocht.
- De bronbeoordeling verandert geen databasewaarde en levert geen formeel
  powergetal.

## 9 oktober 2026 — doel en samenhang

- De analyse moet uiteindelijk leiden tot een artikel voor *Holland's
  Duinen* of een andere periodiek.
- Methode, voortgang en verschillende uitkomsten worden gedurende het werk in
  één leesbaar hoofddocument bijgehouden.
- De analyse omvat soorten, de broedvogelgemeenschap als geheel, functionele
  groepen, ecologische en habitatgebonden groepen en continue functionele
  kenmerken.

## 9 oktober 2026 — opslag en herhaalbaarheid

- Alle blijvende analysespecifieke documentatie, scripts, compacte resultaten,
  figuren en artikelversies worden onder
  `analyses/broedvogel_vegetatie_power/` bijeengehouden.
- De lokale MySQL-database `Meijendel` blijft de canonieke bron. Ruwe
  gegevens worden niet gekopieerd naar de analysedirectory.
- Iedere formele uitvoering krijgt een manifest met gegevensselectie,
  aantallen, versies, modelinstellingen, controles en uitkomsten.
- Iedere berekende uitkomst wordt bewaard en gerapporteerd, ook wanneer geen
  statistisch duidelijk of ecologisch betekenisvol verband is gevonden of een
  model niet geldig kon worden geschat. De rapportage noemt steeds de gebruikte
  gegevensverzameling, het aantal, de periode en de modelstatus; uitkomsten
  worden niet geselecteerd op opvallendheid of betekenis.
- Grote tijdelijke uitvoer, caches en modelobjecten worden niet in Git
  opgenomen.

## 9 oktober 2026 — analysescope en gegevensbetekenis

- Plotgebonden analyses gebruiken standaard
  `v_meijendel_analyseplot_actueel`. Kavel 66 en kavel 91 blijven buiten beschouwing.
- De centrale bron-, nul- en afkeurregels uit
  `R/meijendel_cache_contract.R` worden hergebruikt en niet binnen deze analyse
  opnieuw geïnterpreteerd.
- Een groepswaarde wordt alleen berekend wanneer alle samenstellende
  soortcellen geldig zijn; een gedeeltelijke som blijft `NA`.

## 9 oktober 2026 — modelstrategie

- De primaire modelkorrel is soort × plot × jaar.
- Eén hiërarchisch soortmodel is leidend. Groepsuitkomsten worden uit de
  voorspelde soortreacties afgeleid; directe groepsmodellen zijn
  gevoeligheidsanalyses.
- Teller en tellerervaring worden als onderdeel van het waarnemingsproces
  gemodelleerd. Zij worden niet uitsluitend op grond van niet-significantie
  verwijderd.
- PQ-vegetatie wordt gesplitst in verschillen tussen plots en veranderingen
  binnen dezelfde plot.
- Toegevoegde voorspellende waarde wordt met achtergehouden jaren en plots
  beoordeeld, niet alleen met significantie of AIC.
- De formele poweranalyse volgt pas nadat gegevensmatrix, model en validatie
  zijn vastgesteld. Historische trendonzekerheid wordt niet als power
  aangeduid.

## 9 oktober 2026 — uitvoering en presentatie

- Modelschatting, modelvergelijking, validatie en powerberekening worden buiten
  Shiny uitgevoerd.
- Shiny of het dashboard kan later uitsluitend gevalideerde, reproduceerbare
  uitkomsten presenteren.
- Een statistische relatie wordt niet zonder aanvullend bewijs als een
  causale beheerwerking beschreven.

## 11 oktober 2026 — PQ-vegetatiemodel

- De primaire vergelijking gebruikt de gelijktijdige PQ-meting. Vertragingen
  van één, twee en drie jaar zijn gevoeligheidsanalyses; tussen PQ-meetjaren
  wordt niet geïnterpoleerd.
- Plantensoortenrijkdom, Shannon en totale bedekking worden afzonderlijk aan
  hetzelfde basismodel toegevoegd. Plantensoortenrijkdom en Shannon correleren
  binnen 501 PQ-plotjaren in 35 plots over 1981–2025 sterk (`r = 0,802`); één
  primair model met alle drie maten zou hetzelfde signaal instabiel verdelen.
- Iedere PQ-maat wordt gesplitst in het gemiddelde van de plot en de afwijking
  in het meetjaar. Een tussen-plotverband wordt niet als verandering binnen
  een plot geïnterpreteerd.
- Toegevoegde voorspellende waarde wordt primair beoordeeld met de
  negatief-binomiale logscore in vijf achtergehouden plotblokken en twee
  achtergehouden perioden. MAE en RMSE blijven zichtbaar, maar kunnen door
  grote kolonievogelaantallen worden gedomineerd.
- De formele run `20261011T084206Z-c1136b4ef309` gebruikte 37.362
  soort–plot–jaarrijen uit 406 vogelplotjaren, 35 plots en 155 soorten over
  1989–2025. Zij vond geen bestendige ruimtelijke voorspelwinst en geen
  duidelijke gemiddelde binnen-plotreactie. Een kleine relatieve tijdswinst
  telde niet als bruikbare voorspelling, omdat het model bij Aalscholver
  biologisch onrealistische aantallen produceerde. Deze run blijft als
  modeldiagnose vastgelegd en is voor de inhoudelijke PQ-uitkomst vervangen
  door de run zonder Aalscholver hieronder.
- Aalscholver (`soort_id = 5`) wordt uit het PQ-vegetatiemodel verwijderd. Het
  is een kolonievogel waarvan de aantallen vooral door beschikbaarheid en
  verplaatsing van de nestelplaats worden bepaald; die nestelplaats wordt niet
  door plantensoortenrijkdom, Shannon of totale PQ-bedekking gemeten. De soort
  blijft ongewijzigd in de vogelbrondata en in analyses waarvoor deze
  ecologische uitsluitingsgrond niet geldt.
- De vervangende formele run `20261011T101029Z-cf9b4e61c455` gebruikt 37.140
  soort–plot–jaarrijen uit 406 vogelplotjaren, 35 plots en 154 soorten over
  1989–2025. Alle 24 volledige en 42 validatiemodellen slaagden. De
  binnen-plotreacties bleven rond één en waren voor geen van de drie PQ-maten
  duidelijk. De eerdere Aalscholverextrapolatie verdween; het hoogste
  modelgemiddelde in de tijdvalidatie was 133 Vinken tegenover 11 getelde in
  M55/2025. De tijdscores verbeterden bescheiden, terwijl de ruimtelijke
  validatie tussen maten en blokken gemengd bleef. Met deze drie brede
  PQ-maten is geen bestendige extra voorspellende waarde over zowel nieuwe
  plots als latere jaren aangetoond.

## 9 oktober 2026 — analysematrix stap 1

- Alleen plotjaren die in `territoria` voorkomen vormen de vogelmeetbasis.
  Een registratie die uitsluitend in `plot_jaar_teller` staat, voegt geen
  analysejaar toe.
- De matrix bevat de volledige kruising van 156 positief vastgestelde soorten
  en 2.107 territorium-plotjaren in de 52 standaardplots. Ontbrekende
  soortregels blijven expliciet `NA`; zij worden niet door de rechthoekige
  matrix impliciet nul.
- Tellerregistraties worden per plotjaar als afzonderlijke dekking en als
  herleidbare sleutel voor teller/tellerteam toegevoegd. De technische veldnaam
  `tellerteam_sleutel` kan zowel één teller als een tellerteam van twee of meer
  tellers aanduiden. De tellerregistraties bepalen niet of een plotjaar als
  territoriumtelling bestaat.
- Kavel 62 in 2016 blijft in de algemene vogelmatrix aanwezig. Deze afzonderlijke
  roofvogeltelling wordt pas uit de teller- en tellerervaringsanalyse
  verwijderd, conform het reeds vastgelegde gebruiksbesluit.
- Iedere uitvoering bewaart de bronbestanden alleen tijdelijk, schrijft de
  volledige matrix onder de genegeerde map `resultaten/runs/` en houdt een
  compact samenvattingsbestand en SHA256-manifest in Git bij.

## 9 oktober 2026 — teller- en ervaringsmodel

- Het vooraf goedgekeurde ontwerp in
  `ONTWERP_TELLER_EN_ERVARINGSMODEL.md` is uitgevoerd. De formele run
  `20261009T171423Z-8888e94f0aab` is de vastgelegde uitkomst van deze fase.
- Het hoofdmodel is hiërarchisch en negatief-binomiaal. Het vergelijkt op
  exact dezelfde responscellen een basismodel, een model met teller/tellerteam
  en een model met teller/tellerteam plus ervaring. GEE is een afzonderlijke
  controle.
- Ervaring bestaat uit eerdere geregistreerde teljaren in dezelfde plot en
  eerdere geregistreerde teljaren elders. Beide worden met `log(1 + jaren)`
  gemodelleerd; er komt geen willekeurige grens tussen onervaren en ervaren.
- Bij tellerteams wordt de gemiddelde getransformeerde ervaring gebruikt.
  Een analyse van uitsluitend één-teller-plotjaren voorkomt dat het resultaat
  geheel van deze teamtoerekening afhankelijk wordt.
- Kavel 62/2016 en de 99 plotjaren zonder tellerregistratie worden niet in de
  primaire tellervergelijking gebruikt. Tellergegevens worden niet geïmputeerd.
- Telinspanning wordt alleen in een afzonderlijke analyse over 1984–2025
  opgenomen. Voor 1958–1983 ontbreken BMP-bezoekgegevens.
- Confounders worden niet op grond van niet-significantie verwijderd. Alleen
  niet-identificeerbaarheid of modeluitval kan tot een gedocumenteerde
  vereenvoudiging leiden.
- De uitkomst beschrijft een systematisch effect op territoriumtotalen. Zij
  wordt niet zonder bezoekniveau-tellerkoppeling uitgelegd als het letterlijke
  aantal door een teller gemiste vogels.
- Een negatief-binomiaal soortmodel geldt alleen als bruikbaar bij een positieve
  Hessiaan en zonder convergentiewaarschuwing. Alleen na zo'n gedocumenteerde
  NB-uitval mag de vooraf bepaalde, zichtbaar gelabelde Poisson-terugval worden
  gebruikt.
- Iedere GEE-soortfit draait geïsoleerd en krijgt zestig seconden. Een
  overschrijding wordt als modeluitval bewaard; de overige soorten gaan door.
  Ook een niet-nul foutcode of een niet-eindige coëfficiënt of robuuste
  standaardfout geldt als modeluitval.
- Een checkpoint wordt alleen hervat wanneer gegevenshash, Git-commit,
  formule, familie, analysevariant en relevante pakketversies gelijk zijn.
  Compacte resultaten worden pas geschreven nadat de volledige selectie,
  modelstatussen en GLMM–GEE-rijgelijkheid de eindpoort hebben doorstaan.

## 9 oktober 2026 — gevolg van de telleranalyse

- Territoriumaantallen worden niet achteraf met één tellerpercentage
  gecorrigeerd. In volgende primaire modellen wordt teller/tellerteam als random
  intercept opgenomen. Eerdere geregistreerde jaren in dezelfde plot en in
  andere Meijendelplots blijven daarnaast als twee afzonderlijke
  `log(1 + jaren)`-variabelen in het model. Soorten mogen van het gemiddelde
  ervaringseffect afwijken.
- Deze effecten worden opnieuw geschat op de concrete populatie van ieder
  ecologisch model. De in de lange reeks gevonden spreiding van 0,382 op
  logschaal die samenhangt met teller/tellerteam, factor 1,47 per
  standaardafwijking, en de ervaringsverhoudingen
  worden dus niet als vaste correctiecoëfficiënten opgelegd.
- De lange reeks toont geen duidelijk gemiddeld effect van meer ervaring in
  dezelfde plot. Eén, drie en vijf eerder geregistreerde jaren elders hangen
  samen met gemiddeld 4,2%, 8,6% en 11,2% hogere verwachte aantallen. Dit blijft
  een statistische samenhang; zonder betrouwbare teller per bezoek is het geen
  maat voor letterlijk gemiste vogels.
- Bij 121 voldoende gedekte soorten veranderde de geschatte jaarlijkse trend
  mediaan 0,545 procentpunt in absolute zin; voor 31 soorten meer dan één
  procentpunt per jaar. De mediane intervalbreedte nam 11% toe. Tellercorrectie
  is daarom verplicht in de volgende verklarende modellen, ook al is de
  gemiddelde trendverschuiving klein.
- Plotjaren zonder geregistreerde teller blijven buiten de primaire, voor
  teller gecorrigeerde analyse. Zij kunnen alleen in een afzonderlijke
  gevoeligheidsanalyse worden gebruikt. Het model zonder teller blijft als
  vergelijking bestaan, niet als route om teller op grond van significantie
  te verwijderen.
- GEE blijft uitsluitend een robuustheidscontrole. De geldige GEE-uitkomsten
  ondersteunden de hoofdrichting voor ongeveer vier op de vijf soorten, maar
  waren niet voor alle soorten technisch bruikbaar en zijn daarom geen
  vervanging van het hiërarchische hoofdmodel.

## 11 oktober 2026 — vegetatiesamenstelling, IPI en landbedekking

- De volledige provinciale PQ-samenstelling wordt per plotjaar met een
  Hellinger-transformatie en drie compositieassen samengevat. De drie assen
  verklaren samen 27,8%; dit is een gerichte reductie, geen volledige weergave
  van de 642 taxa in 1.314 gekoppelde opnamen uit 1981–2025.
- Dekking bij nul tot en met drie jaar vertraging blijft gerapporteerd. Alleen
  het gelijktijdige model is geschat, omdat dit wel ruimtelijke maar geen
  temporele voorspelwinst gaf. Lagmodellen worden niet automatisch toegevoegd
  wanneer het primaire tijdssignaal ontbreekt.
- IPI wordt vooraf samengebracht tot open duin, nat/water, struweel en bos. De
  fracties beschrijven de verdeling van bemonsterde PQ-opnamen en worden niet
  als oppervlakteaandeel van de vogelplot geïnterpreteerd.
- Online Resource 2 van Schmidt-Tauscher, Häger en Van der Hagen wordt bij
  iedere formele run opnieuw opgehaald en met SHA256 vastgelegd. De zeven
  klassen voor 25 plots in 2001 en 2022 worden niet jaarlijks geïnterpoleerd;
  zij worden gekoppeld aan vogelvensters 1997–2001 en 2018–2022.
- M17 heeft in de actuele vogelmatrix geen territoriumplotjaar en valt daarom
  zonder kunstmatige aanvulling uit de landbedekkingsmodellen. M71 behoudt de
  bronafwijking van 0,57 niet-geclassificeerde hectare; klasseaandelen zijn
  genormaliseerd over de werkelijk geclassificeerde 47,89 hectare.
- Een effectcoëfficiënt wordt alleen als geldige modelvergelijking beschouwd
  wanneer zowel basis- als vegetatiemodel numeriek geldig zijn. Alle overige
  coëfficiënten, waarschuwingen en niet-positief-definiete Hessianen blijven wel
  in de uitkomsten zichtbaar.
- De taxonsamenstelling verbetert de ruimtelijke voorspelling in vier van vijf
  plotblokken, IPI in drie van vier geldige blokken. Beide verslechteren de
  logscore in twee van twee tijdsblokken. Zij beschrijven dus vooral verschillen
  tussen plots en bewijzen geen voorspelling van verandering door de tijd.
- Wateroppervlak levert voor watervogels het duidelijkste ruimtelijke
  landbedekkingssignaal. De overige vogelgroepen geven gemengde scores of te
  veel numerieke uitval voor een algemeen voorspelmodel. Het onverwachte
  negatieve binnen-plotverband bij rietvogels wordt niet causaal uitgelegd.
- Vegetatiehoogte wordt niet algemeen toegevoegd. Er volgt alleen een gerichte
  proef voor bos-, boomgroep- en struweelvogels met AHN DSM minus DTM, gekoppeld
  aan werkelijke inwinningsjaren en getoetst op extra voorspelling buiten de
  schattingsgegevens.
- `glmmTMB`-validatie blijft op de 8GB-iMac sequentieel. Twee gelijktijdig
  gevorkte R-processen veroorzaakten een niet-afvangbare numerieke crash; dat
  is als mislukte uitvoerpoging vastgelegd en is geen ecologische uitkomst.

## 12 oktober 2026 — gerichte habitatmodellen, AHN en weer

- AHN2/2008, AHN3/2014, AHN4/2020 en AHN5/2023 zijn met dezelfde bronproducten,
  rasteruitlijning en rekenregel geharmoniseerd. DSM minus DTM is op twee meter
  resolutie samengevat tot open terrein, lage vegetatie, struweel, bomen,
  hoogteverdeling en randlengte. De afgeleide laag omvat 220 regels voor 55
  plots en blijft een reproduceerbaar analyseproduct; zij wordt niet als
  bronmeting in de levende database opgeslagen.
- De gerichte modellen gebruiken steeds een vooraf passende vogelgroep en
  corrigeren naast teller/tellerteam en ervaring ook voor bezoekduur,
  registratie van ongunstige bezoeksomstandigheden en vier seizoensmaten uit
  `weer_analyse`. Ontbrekende bezoekweercodering wordt niet weggefilterd: de
  gestandaardiseerde waarde wordt op het gemiddelde gezet en een afzonderlijke
  indicator bewaart dat de code ontbrak.
- Een vaste bronfactor blijft in het model wanneer meer dan één bron aanwezig
  is. Binnen een trainingsset met precies één bron wordt die factor
  structureel weggelaten, omdat zij daar niet schatbaar is. Dit is geen
  stepwise selectie op significantie.
- De zes landbedekkingsmodellen houden twee meetjaren, 2001 en 2022, en blijven
  daarom zonder uitvoerbare tijdstoets. De vier AHN-modellen hebben nu vier
  onafhankelijke structuurmomenten. Zij leren uit 2008 en 2014 en worden op de
  vensters na 2020 en 2023 getoetst. Alleen de AHN-tijdstoets voor
  boomgroepvogels slaagt numeriek; de verbetering van de gemiddelde logscore
  is 0,0024 en de minimale verbetering na het weglaten van een soort −0,0174.
  De drie andere AHN-tijdstoetsen vallen numeriek uit.
- Van twintig volledige modellen zijn twaalf numeriek geldig; van vijftig
  ruimtelijke validaties 24. Geen van de tien gerichte habitatmodellen voldoet
  aan de vooraf vastgelegde poort naar power. Ook de acht ongeldige volledige
  modellen en 26 ongeldige ruimtelijke validaties blijven gerapporteerd.
- AHN1/1997–1998 is voor 55 plots afzonderlijk gereconstrueerd uit 12.318.672
  oorspronkelijke punten. Omdat twee verdedigbare rastermethoden gemiddeld
  48,0 procentpunt verschil in open terrein en 14,0 procentpunt verschil in
  bomen geven, wordt AHN1 niet aan AHN2–AHN5 gekoppeld. Het blijft een
  historische gevoeligheidsanalyse.
- De beperkte RGB/CIR-proef is uitgevoerd met tien PDOK-beelden uit 2016,
  2020, 2022, 2023 en 2024. Van de 55 bronplots zijn M66 en M91 conform de
  Natura 2000-scope uitgesloten; de analyse omvat 53 plots.
- De vier uit AHN afgeleide hoogteklassen zijn niet voldoende overdraagbaar
  tussen beeldjaren. De ruwe kenmerken behalen macro-F1 0,469 voor 2020 naar
  2023 en 0,420 voor 2023 naar 2020, onder de vooraf gekozen grens van 0,60.
  Een gevoeligheidsrun met radiometrische normalisatie en beeldtextuur scoort
  lager. De luchtfoto's worden daarom niet tot een jaarlijkse structuurreeks
  uitgebreid.
- Water en kaal zand worden niet met onbewezen spectrale drempels gescheiden.
  Daarvoor ontbraken in deze proef onafhankelijke pixelreferenties. De
  luchtfoto's kunnen AHN dus niet vervangen.

## 19 oktober 2026 — oorspronkelijke landbedekkingsrasters

- De classificatierasters voor 2001 en 2022 zijn als onveranderde bronkopie
  met SHA256 opgeslagen. Alle 739.372 geldige pixels konden aan een van zeven
  klassen en een van 25 bronplots worden gekoppeld. De opnieuw berekende
  oppervlakten bevestigen de gepubliceerde tabel: gemiddeld absoluut verschil
  0,0032 hectare en maximaal 0,030 hectare over 350 vergelijkingen.
- Ruimtelijke structuurmaten zijn toegelaten als afgeleide analyse-uitvoer:
  per klasse aandeel, aantal en dichtheid van aaneengesloten vlakken, aandeel
  van het grootste vlak en randdichtheid; per plot ook klassenrijkdom,
  Shannon-diversiteit en interne randdichtheid.
- De rasters worden niet als jaarlijkse reeks gelezen. De oorspronkelijke
  trainingspolygonen en validatiepunten ontbreken en er blijven slechts twee
  onafhankelijke kaartjaren. De eerdere luchtfoto-uitkomst verandert daarom
  niet.

## 26 oktober 2026 — historische Dunea-luchtfotoreeks als kandidaatvervolg

- Harrie Van der Hagen meldt een gebiedsdekkende Dunea-reeks met vier
  zwart-witjaren uit 1938–1966 en waarschijnlijk negen
  kleureninfraroodjaren uit 1975–2023. De exacte inventaris, bestanden,
  interpretaties, rechten en de laatste twee jaren zijn nog niet door Dunea
  bevestigd. De bron is daarom nog niet tot de analyse toegelaten.
- Volgens Harrie beslist Maarten Werink over beschikbaarstelling. Het idee
  voor een gezamenlijke proef via een stage is eerder alleen terloops door
  Harrie aan Ton genoemd en was geen voorstel of toezegging van Maarten.
  Maarten wordt daarom zonder veronderstelde voorkennis rechtstreeks om
  toegang en voorwaarden gevraagd; Harrie wordt niet om overdracht van
  Dunea-bestanden gevraagd.
- Een eventuele proef begint met de onderling beter vergelijkbare
  kleureninfraroodreeks vanaf 1975. De zwart-witbeelden van 1938–1966 hebben
  een grovere schaal en beeldspecifieke beperkingen en worden niet vooraf met
  die reeks samengevoegd.
- Het voorspelmodel behandelt vegetatiestructuur niet als enige oorzaak.
  Plaats- en jaargebonden gebeurtenissen en ingrepen, waaronder verandering in
  konijnenstand, aanplant, begrazing en het opnieuw openmaken van het duin,
  worden opgenomen zodra daarvoor voldoende bronbewijs beschikbaar is.

## 12 oktober 2026 — stikstof en CBS-landgebruik

- Stikstofdepositie en CBS-landgebruik zijn als afzonderlijke verklarende
  blokken toegevoegd aan hetzelfde soortgerichte vogelmodel. Tijd,
  oppervlakte, bron, teller/tellerteam, geregistreerde ervaring, bezoekduur,
  ongunstige bezoeksomstandigheden en vier weermaten blijven vaste correcties.
  Omgevingswaarden zijn vooraf gesplitst in verschillen tussen plots en
  veranderingen binnen dezelfde plot.
- Het stikstofmodel gebruikt 60.127 soort–plot–jaarrijen uit 674 plotjaren in
  51 plots, voor 155 soorten en 2005–2023. Het verschil tussen plots is een
  factor 1,157 per standaardafwijking; het binnen-plotverband is 1,002 en niet
  aantoonbaar. De enige geldige ruimtelijke validatie verslechtert en de
  tijdstoets valt numeriek uit. Stikstof gaat daarom niet door naar power.
- Het CBS-landgebruik gebruikt 15.039 soort–plot–jaarrijen uit 168 plotjaren in
  49 plots, voor 155 soorten en de kaartjaren 2010, 2015, 2017 en 2022. De
  broncodes van 1996 blijven uitgesloten zolang zij niet inhoudelijk aan de
  latere klassen zijn geharmoniseerd.
- Van twaalf volledige basis- en omgevingsmodellen zijn vier geldig; alleen het
  stikstofpaar is volledig geldig. Van 36 validaties zijn er twaalf geldig en
  24 ongeldig. Bos verbetert de logscore in vier van vier geldige ruimtelijke
  blokken en water in twee van twee, maar de volledige modellen zijn ongeldig
  en geen van de zes tijdstoetsen slaagt. Dit blijft een ruimtelijke
  aanwijzing, geen gevalideerde voorspelling van vogelverandering.
- Geen van de zes omgevingsmodellen voldoet aan de vooraf vastgelegde poort
  naar power. Alle coëfficiënten, nulbevindingen en numerieke uitval blijven in
  de compacte resultaatbestanden en het uitvoermanifest bewaard.
