# NDFF-protocolaudit per soortgroep

## Besluit

De 810.830 unieke FFV-waarnemingsregels zijn **niet als één ongestructureerde
set rechtstreeks trendklaar**.
Een gevalideerde waarneming en een geregistreerde protocolnaam bewijzen nog niet
dat de FFV-export alle telbezoeken, inspanning, telobjecten en afleidbare
nulwaarnemingen bevat. Protocolmatig passende gegevens mogen daarom wel
voorlopig en verkennend worden gebruikt, terwijl de leveringsgeschiktheid
afzonderlijk `niet_beoordeeld` blijft totdat de betreffende levering inhoudelijk
is onderzocht. Iedere uitkomst vermeldt deze beperking;
voorlopige toelating is geen definitieve trendvalidatie.

Alleen records uit een voor de soortgroep passend doelgericht meetnet zijn
kandidaat voor protocolgebonden trendinvoer. Bij een expliciete NEM-code wordt
uitgegaan van een protocolgeldig positief bezoek. De native meeteenheid en
bezoekmatrix moeten nog wel per protocol worden gereconstrueerd. Bruikbare
nullen worden uitsluitend afgeleid binnen de doelsoorten en bezochte
meeteenheden van dat protocol; nooit voor bijvangsten.

### Uitgevoerde reconstructies `03.201` en `07.201`

Op 15 september 2026 zijn alle zeventien unieke PDF-downloads van de officiële
pagina [Handleidingen en telformulieren](https://vlinderstichting.nl/wat-kan-jij-doen/tellen/meetnetten/handleidingen-en-telformulieren/)
gecontroleerd. Ze zijn als bijlagen opgenomen onder Zotero-item `QBAFD7C6`,
`Meetnetten Vlinderstichting`. De inhoudelijke hoofdbron is Van Swaay et al.
(2018), *Handleiding landelijke meetnetten vlinders, libellen en
nachtvlinders*; de online-invoerhandleiding uit 2023 beschrijft de feitelijke
route-, bezoek-, sectie- en deelnamevelden.

De handleidingen onderscheiden bij dagvlinders algemene routes, soortgerichte
routes en drie typen ei-/rupstelplots. Een algemene route telt alle dagvlinders
per sectie; een soortgerichte route uitsluitend de aangewezen soort. Een route
is maximaal een kilometer lang, telt maximaal twintig meestal
vijftig-metersecties en blijft door de jaren gelijk. Iedere ronde is een apart
bezoek met datum, begin- en eindtijd, weer, tellers en aantallen per sectie.
Bezoeken zonder waargenomen vlinders moeten eveneens worden ingevoerd. Het
meetroutenportaal bewaart bovendien route-ID, secties, routewijzigingen en
beheerinformatie.

Daarom is de eerdere `ndff-vlinderroute-v1`-matrix op 15 september 2026
vervangen door `ndff-vlinderroute-v2`. De 80.442 positieve dagvlinderrecords en
20.075 positieve bezoek-taxoncombinaties zijn behouden. Van de 86.209 eerder
als `echte_nul` opgeslagen regels zijn 3.795 niet-onderbouwde nullen verwijderd:

- één routefamilie bevat in 87 bezoeken en 16 jaren uitsluitend Groot dikkopje (*Ochlodes
  sylvanus*) en volgt het patroon van een soortgerichte route; de 2.871 nullen
  voor de andere 33 taxa vallen buiten het protocolbereik;
- 28 van de 63 bezoeken zonder routekoppeling bevatten maar één positief taxon;
  hun 924 nullen voor de overige 33 taxa bewijzen geen algemene route.

De overige 82.414 afgeleide dagvlindernullen zijn in v2 behouden. Routetype,
doelsoort, doelbereik en bewijsgrond zijn nu expliciet opgeslagen. Bij 28
eensoortbezoeken zonder route blijft het doelbereik `onbepaald` en staan alleen
de positieve waarnemingen in de matrix. De 35 bezoeken zonder route waarop
meerdere dagvlindertaxa zijn gemeld hebben de herkenbare status
`algemene_route_aannemelijk`. De openbare waarnemingsregels bevatten nog steeds
geen oorspronkelijke route- of sectie-ID; dat blijft een beperking voor
analyse en publicatie. De 556 nachtvlinderrecords onder `03.201` blijven
positieve voorkomensinformatie.

Van de bezoeken zijn er 3.063 aan een routefamilie gekoppeld. Daarvan zijn
2.891 bezoeken direct bruikbaar en blijven 172 bezoeken uit één ruimtelijk
uitgerekte familie gemarkeerd voor handmatige controle. Voor 63 bezoeken met
185 bronrecords kon uit de aanwezige geometrie geen route worden hersteld. De
afgeleide tabellen staan in
`Meijendel`; `--audit-vlinders` controleert aantallen, matrixconsistentie en
dat geen oude afgeleide vlindertabellen in het beveiligde schema achterblijven.

De elf routefamilies zijn daarnaast als afzonderlijke interpretatielaag aan de
gepubliceerde Meijendelroutes gekoppeld. De technische familie-ID blijft
ongewijzigd; `ndff_vlinder_route_identificatie` bewaart routenummer, naam,
bewijsbron en zekerheid.

| Familie | Officiële route | Nummer | Zekerheid |
|---:|---|---:|---|
| 1 | Het Scheepje | 307 | hoog |
| 2 | Parnassiapad | 117 | hoog |
| 3 | Meijendel | 1844 | aannemelijk |
| 4 | Hertenkamp | 205 | aannemelijk |
| 5 | Helmduinen | 206 | hoog |
| 6 | Violenwater | 385 | hoog |
| 7 | Voorlinden | 1764 | aannemelijk |
| 8 | Sprang A | 1871 | aannemelijk |
| 9 | Bierlap (Groot dikkopje) | 1767 | hoog |
| 10 | Kijfhoekhoogte | 204 | hoog |
| 11 | De Klip | 1753 | hoog |

Lentevreugd valt buiten de afgesproken selectie. Familie 7 is niet gesplitst:
24 geometrieën vormen de ruimtelijke hoofdcomponent bij Voorlinden en twee
noordelijke geometrieën zijn als `ruimtelijke_uitbijter` gemarkeerd. Op 76
tijdstippen komen beide componenten binnen hetzelfde geregistreerde bezoek
voor; splitsing zou die bezoeken kunstmatig over twee routes verdelen.

De 1.535 vliesvleugelrecords onder hetzelfde protocol betreffen uitsluitend
taxa van het geslacht *Bombus*. De handleidingen tonen twee mogelijke
bovenliggende structuren: een eigen hommelroute of de optionele hommeltelling
op een dagvlinderroute. Het invoerportaal bewaart per bezoek een expliciete
deelnamevlag; bovendien telt een waarnemer óf alle hommels als `hommel
onbekend`, óf op soort na afspraak met de coördinator. Die twee kenmerken staan
niet in de FFV-regels. De 365 positieve bezoek-taxoncombinaties blijven geldig,
maar de 937 huidige soortspecifieke `echte_nul`-regels zijn daarom voorlopig en
mogen niet als afwezigheid worden gebruikt. De 43 bezoeken zonder gelijktijdige
dagvlinderregel zijn waarschijnlijk zelfstandige hommelbezoeken; de 174
samenvallende bezoeken kunnen optionele medetellingen zijn. Versie 2 moet
deelname en determinatieniveau expliciet modelleren.

Het Landelijk Meetnet Libellen (`07.201`) is onder
`ndff-libellenroute-v1` uit uitsluitend openbare records gereconstrueerd. De
3.280 bronrecords uit 2007-2021 vormen 461 bezoeken, negen routefamilies en 29
taxa. De bezoek-soortmatrix bevat 13.173 regels: 2.170 positieve combinaties en
11.003 echte nullen. Alle negen routefamilies bevatten door de jaren heen meer
dan één protocoltaxon en zijn daarom als algemene route gekwalificeerd.

Van 60 bezoeken is alleen een grof vlak beschikbaar. Bij 53 daarvan bewijzen
meerdere getelde taxa eveneens het algemene doelbereik. Zeven grove bezoeken
bevatten slechts één taxon; hun doelbereik blijft `onbepaald`. Voor deze zeven
wordt alleen de positieve telling bewaard en worden geen andere soorten als
afwezig ingevuld. De vier `Meijendel.ndff_libel_*`-tabellen worden met
`--audit-libellen` gecontroleerd; er staan geen afgeleide libellengegevens in
het beveiligde schema.

De officiële libellenhandleidingen bevestigen deze scheiding: een algemene
route telt alle libellen per vaste sectie, een soortgerichte route alleen de
doelsoort. Route-ID, sectie-ID, routetype, bezoekweer, teller en veranderingen
zijn native velden maar ontbreken in FFV. De huidige 454 als algemeen
gekwalificeerde bezoeken zijn protocolmatig bruikbaar; de zeven bezoeken met
`onbepaald` doelbereik blijven terecht zonder afgeleide nullen. De afzonderlijke
Riviersluiptelling is geen gewone libellenroute: zij bestaat uit telkens
vijftien minuten zoeken langs honderd meter rivieroever naar larvenhuidjes, met
expliciete nultellingen. In de huidige Meijendel-selectie is deze methode niet
als afzonderlijke NDFF-reeks aangetroffen.

Voor dagactieve nachtvlinders en nectarplanten op een dagvlinderroute geldt een
afzonderlijke deelnamekeuze per bezoek. Alleen wanneer die keuze aan staat,
mag een lege soortenlijst als nul gelden. De 556 nachtvlinderregels onder
`03.201` blijven daarom uitsluitend positieve voorkomensinformatie. In de
huidige `03.201`-levering zijn geen nectarplantregels aangetroffen.

Het nachtvlinderprotocol `03.203` vereist een vast telpunt, dezelfde val en
lamp, een volledige nacht, ten minste zes tellingen per jaar en afzonderlijke
aantallen binnen en buiten de val. De 596 FFV-records zijn echter tot
jaarperioden en kilometerhokken geaggregeerd; bezoekdatum, telpunt, val, lamp en
binnen/buiten-status ontbreken. De bestaande kwalificatie als positieve
hokjaarcontext zonder nullen of trendinvoer blijft daarom juist.

### Selectie van volledige toegelaten libellenbezoeken

**Selectie voor bezoekanalyses, 17 oktober 2026.** Gebruik `ndff-libellen-selectie-v1` via `--selecteer-libellen` in `gis/scripts/import_ndff_protocolkwaliteit.py`. De selectie wordt opnieuw berekend uit de levende database, voor analysetype `TV` of `TA`. Alleen een gereconstrueerd algemeen routebezoek waarvan alle bronrecords `voorlopig_bruikbaar` zijn, binnen `meijendel_natura2000` vallen en het gekozen analysetype toestaan, wordt met zijn volledige bestaande taxonmatrix doorgegeven. Ontbrekende of dubbele bron-/analysekoppelingen, afwijkende bezoekaantallen, plots zonder scopestatus en ontbrekende centrale taxonkoppelingen blokkeren de selectie. Taxa zonder soortgroep blijven bereikbaar.

De controle van de 3.280 bronrecords en 461 bezoeken uit 2007–2021 selecteert 98 bezoeken met 515 bronrecords uit 2010–2021. Hun bestaande matrix bevat 2.842 regels: 353 positieve combinaties en 2.489 afgeleide nullen. De 73 gedeeltelijk toegelaten bezoeken uit 2010–2020 en de 290 geheel uitgesloten bezoeken uit 2007–2020 worden niet als volledige matrix doorgegeven. De afzonderlijk toegelaten positieve records uit gedeeltelijke bezoeken blijven beschikbaar als voorkomensinformatie via de bestaande NDFF-analyseview. De selectie bewaart `gegevensgeschiktheid`, `kwaliteitsmelding`, het nulbewijs en de centrale taxonverwijzing. Zij bevestigt geen gevalideerde trend of afwezigheid. Er zijn geen records, bestaande nullen of analysebesluiten gewijzigd en geen extra tabellen of views gemaakt.

De alleen-lezen T7-controle van 17 oktober 2026 vond in de gecontroleerde gegevensmap en archiefinhoud geen afzonderlijke Vlinderstichting-levering. Alle 3.280 libellenregels uit 2007–2021 in de stagingdataset komen op identificatie, periode, taxonnaam, aantal en protocol overeen met de levende database. De beveiligde NDFF-levering van 14.573 records uit 1950–2025 bevat geen `07.201`-records en geen gevuld `sessionid`. Deze controle sluit een levering elders niet uit; de oorspronkelijke route- en bezoekadministratie is hiermee niet verkregen.

Controleer de selectie zonder matrixuitvoer:

```bash
python3 gis/scripts/import_ndff_protocolkwaliteit.py --audit-libellen-selectie
```

Gebruik de volledige geselecteerde matrix als JSON voor een interne berekening:

```bash
python3 gis/scripts/import_ndff_protocolkwaliteit.py --selecteer-libellen --libellen-analysetype TV
```

Voor een aantalsvergelijking kiest de afnemer expliciet `--libellen-analysetype TA`.
Dit is geen goedkeuring van een trendmodel. De oorspronkelijke reconstructie
`ndff-libellenroute-v1` en de algemene analyseketen `ndff-analyseketen-v1` blijven
ongewijzigd; de aanvullende, strengere selectie heeft haar eigen versie.
De bron- en matrixlezing gebeurt in één alleen-lezen databasesnapshot. De functie
`read_libel_analysis_selection()` geeft dezelfde selectie terug voor hergebruik
in Python. De bestaande reconstructie-audit `--audit-libellen` blijft daarnaast
nodig voor de inhoudelijke consistentie van de aangeleverde matrix.
`plot_ids` beschrijft de plots van de toegelaten bronrecords, geen bewezen
plotgebonden nul voor ieder taxon. Een bezoek dat meerdere toegelaten plots
zou bestrijken wordt niet kunstmatig in onafhankelijke plotbezoeken gesplitst.
Naast de algemene V-kwaliteitsvelden bevat iedere uitvoerregel ook
`analysetype_gegevensgeschiktheid` en `analysetype_kwaliteitsmelding` uit het
afzonderlijke actuele TV- of TA-besluit. Ontbreekt dat besluit of de toelichting,
dan stopt de selectie. De algemene V-status vervangt dit typegebonden besluit niet.
De codes TV en TA geven het gekozen protocolmatige gebruik aan; de onveranderde
kwaliteitsmelding en gegevensgeschiktheid bepalen de grenzen van de interpretatie.

### Dekking en eerste beschrijvende libellenvergelijking

**Stand 17 oktober 2026.** De 98 geselecteerde bezoeken met 515 bronrecords uit
2010–2021 vormen zes gereconstrueerde routefamilies in vier plots. De jaren
2016, 2018 en 2019 ontbreken in deze selectie. Dat zegt niets over wel of niet
tellen buiten de selectie; deze jaren worden niet met nullen aangevuld.

| Routefamilie | Plot | Jaar | Geselecteerde bezoeken |
|---|---|---|---:|
| 1 | M14 | 2015 / 2017 | 3 / 9 |
| 3 | M16 | 2010 / 2011 / 2012 / 2013 / 2014 / 2015 | 9 / 10 / 9 / 10 / 10 / 8 |
| 4 | M74 | 2020 / 2021 | 6 / 9 |
| 6 | M74 | 2020 | 5 |
| 8 | M74 | 2021 | 9 |
| 9 | M105 | 2020 | 1 |

Alle 98 geselecteerde bronperioden beginnen en eindigen op dezelfde kalenderdag.
De 28 bezoeken van de routefamilies 4, 6 en 8 delen in M74 veertien plot-datums:
vijf in 2020 en negen in 2021. De bronperioden verschillen. Een gedeelde
plot-datum bewijst dus geen dubbele waarneming en rechtvaardigt geen
verwijdering, maar zonder native route-/sectieadministratie is hun onderlinge
onafhankelijkheid evenmin aangetoond. Deze bezoeken worden niet samengevoegd
of als bewezen onafhankelijke herhalingen opgeteld. De 98 bezoeken geven 84
unieke plot-datums; ook dat zijn geen 84 bewezen native bezoeken.

Routefamilie 3 in M16 heeft 56 geselecteerde bezoeken uit zes opeenvolgende
jaren, 2010–2015. De seizoensdekking verschilt: mei ontbreekt in de selectie
van 2015, terwijl in 2010 en 2012 slechts één septemberbezoek is geselecteerd.
Voor een eerste beschrijvende vergelijking is daarom uitsluitend juni–augustus
gebruikt: 36 bezoeken met 156 bronrecords, precies zes bezoeken per jaar en twee
per maand. Dit maakt de maandverdeling gelijk; het bewijst geen gelijke
inspanning, detectiekans of volledigheid van alle oorspronkelijke bezoeken.

De onderstaande uitkomst telt per taxon het aantal geselecteerde bezoeken met
een positieve registratie, steeds uit zes bezoeken per jaar. Er worden geen
aangeleverde aantallen opgeteld. Alle 29 taxa worden getoond, ook de achttien
zonder positieve registratie in deze deelreeks. Een 0 betekent hier uitsluitend
geen positieve registratie tijdens deze zes geselecteerde bezoeken. De
1.044 onderliggende matrixregels bevatten 103 positieve combinaties en 941
bestaande afgeleide nullen. De nullen en hun bewijs zijn onveranderd behouden;
zij worden niet als zelfstandig bewijs van afwezigheid gepresenteerd.

| Taxon | 2010 | 2011 | 2012 | 2013 | 2014 | 2015 |
|---|---:|---:|---:|---:|---:|---:|
| Azuurwaterjuffer | 0 | 0 | 0 | 0 | 0 | 1 |
| Bloedrode heidelibel | 0 | 0 | 0 | 0 | 0 | 0 |
| Bruine glazenmaker | 0 | 0 | 0 | 0 | 0 | 0 |
| Bruine winterjuffer | 0 | 0 | 0 | 0 | 0 | 0 |
| Bruinrode heidelibel | 0 | 3 | 1 | 1 | 3 | 0 |
| Geelvlekheidelibel | 0 | 0 | 0 | 0 | 0 | 0 |
| Gewone oeverlibel | 4 | 3 | 6 | 6 | 4 | 2 |
| Gewone pantserjuffer | 0 | 0 | 0 | 0 | 0 | 0 |
| Glassnijder | 0 | 0 | 0 | 0 | 0 | 0 |
| Grote keizerlibel | 0 | 2 | 3 | 2 | 3 | 2 |
| Grote roodoogjuffer | 0 | 0 | 0 | 0 | 0 | 1 |
| Houtpantserjuffer | 1 | 1 | 0 | 0 | 0 | 0 |
| Kleine roodoogjuffer | 0 | 0 | 0 | 0 | 0 | 0 |
| Lantaarntje | 4 | 1 | 0 | 3 | 5 | 1 |
| Noordse witsnuitlibel | 0 | 0 | 0 | 0 | 0 | 0 |
| Paardenbijter | 0 | 0 | 0 | 0 | 0 | 0 |
| Platbuik | 0 | 0 | 0 | 0 | 0 | 0 |
| Steenrode heidelibel | 0 | 0 | 0 | 1 | 1 | 0 |
| Tengere grasjuffer | 0 | 0 | 0 | 0 | 0 | 0 |
| Tengere pantserjuffer | 0 | 0 | 0 | 0 | 0 | 0 |
| Variabele waterjuffer | 0 | 0 | 0 | 0 | 0 | 0 |
| Viervlek | 0 | 0 | 0 | 1 | 0 | 0 |
| Vroege glazenmaker | 0 | 0 | 0 | 0 | 0 | 0 |
| Vuurjuffer | 0 | 0 | 0 | 0 | 0 | 0 |
| Vuurlibel | 0 | 0 | 0 | 0 | 0 | 0 |
| Watersnuffel | 6 | 6 | 6 | 6 | 6 | 3 |
| Zwarte heidelibel | 0 | 0 | 0 | 0 | 0 | 0 |
| Zwervende heidelibel | 0 | 0 | 1 | 1 | 0 | 2 |
| Zwervende pantserjuffer | 0 | 0 | 0 | 0 | 0 | 0 |

**Betekenis en grens.** Dit is een vergelijking van geregistreerde aanwezigheid
binnen één gereconstrueerde routefamilie en een gelijk gekozen deel van het
seizoen. Er is geen trendmodel geschat en er zijn geen effectgrootte,
significantietoets, abundantie-, afwezigheids- of beheerconclusie afgeleid. De
routefamilie is geen bevestigd oorspronkelijk routenummer. Weer, teller,
oorspronkelijke inspanning en volledig lege bezoeken zijn niet door deze
berekening verkregen. Zowel `gegevensgeschiktheid` als
`analysetype_gegevensgeschiktheid` blijven voor de 1.044 regels
`niet_beoordeeld`. De algemene en TV-kwaliteitsmelding blijven bij elke
onderliggende regel aanwezig:

> Voorlopig resultaat op basis van protocolgeschiktheid en doelbereik. De soortgroep valt binnen het inhoudelijke doelbereik van het protocol. De protocoltypen blijven voorlopig bruikbaar, met afzonderlijke beoordeling van leveringsgeschiktheid. De leveringsgeschiktheid (telobjecten, bezoeken, inspanning, nulwaarnemingen en meeteenheden) en verdere validatie zijn nog niet beoordeeld. Gebruik de uitkomst daarom verkennend en niet als definitief bewijs van trend, afwezigheid of beheereffect.

**Vaste lokale opdracht.** Voer vóór inhoudelijke rapportage de bestaande
controles `--audit-live` en `--audit-libellen` uit. De onderstaande opdracht
maakt de beschrijvende vergelijking opnieuw uit de levende database:

```bash
python3 gis/scripts/import_ndff_protocolkwaliteit.py --verken-libellen \
  --libellen-routefamilie 3 --libellen-jaar-van 2010 --libellen-jaar-tot 2015 \
  --libellen-maanden 6 7 8
```

De opdracht gebruikt `ndff-libellen-verkenning-v1` en uitsluitend analysetype
`TV`. Routefamilie, beide jaartallen en unieke maanden 1–12 zijn verplicht;
zij kunnen voor een andere afgebakende vergelijking worden aangepast. De bron-,
bezoekdatum- en matrixlezing gebeuren in dezelfde alleen-lezen snapshot.
`ndff-libellen-selectie-v1` blijft de toelating bepalen; de opdracht verandert
geen reconstructie of analysebesluit.

De opdracht stopt bij een ontbrekende jaar-maandcombinatie of een ongelijk
aantal geselecteerde bezoeken per gekozen maand en jaar. Ook ontbrekende of
tegenstrijdige bezoekdatums, bronperioden over meerdere kalenderdagen,
meerdere bezoeken op dezelfde routedatum, dubbele centrale bezoek-taxonparen
en onvolledige taxonmatrices blokkeren de vergelijking. De verwachte centrale
taxonset komt uit de volledige gereconstrueerde matrix, vóór toelating en keuze
van route, jaren en maanden. Daardoor wordt ook een taxon dat in het hele
gekozen tijdvak ontbreekt herkend. De afzonderlijke reconstructie-audit blijft
nodig om de volledige reconstructie zelf tegen het bronprofiel te controleren.
Ontbrekende bezoeken of taxonregels worden nooit als nul aangevuld. Gelijke aantallen bezoeken per
maand bewijzen nog geen gelijke inspanning of detectiekans.

De interne JSON-uitvoer bevat de gekozen routefamilie, plot-ID's, jaren en
maanden, de dekking per jaar-maand, de omvang en alle taxonuitkomsten. Per taxon
staan per jaar zowel het aantal geselecteerde bezoeken als het aantal bezoeken
met positieve registratie. Ook taxa zonder positieve registratie en taxa zonder
soortgroep blijven zichtbaar. De algemene en TV-kwaliteitsvelden, bestaande
nulbewijzen en de versies blijven behouden; de toelichting op de grenzen van
interpretatie staat bij de uitvoer. Er worden geen aantallen individuen opgeteld
of trendmodellen geschat. Voor de afzonderlijke oorspronkelijke matrixregels
blijft `--selecteer-libellen` beschikbaar. Zonder `--verken-libellen` mogen de
route-, jaar- en maandopties niet worden gebruikt; de opdracht stopt dan vóór
databasecontact, zodat deze opties nooit per ongeluk een import starten.

De reconstructie-audit van 17 oktober 2026 geeft nul ongeldige matrixregels,
nul afwijkingen tussen positieve bron- en matrixaantallen en nul nullen buiten
algemeen doelbereik. De controle van de vaste analyseketen is afzonderlijk
uitgevoerd. Er zijn geen bronrecords, analysebesluiten of databasetabellen
gewijzigd en geen export, cachebouw of VPS-publicatie uitgevoerd.

### Wetenschappelijke meerwaarde van ontbrekende Vlinderstichting-velden

De handleidingen maken zichtbaar welke ontbrekende gegevens vooral extra
ecologische zeggingskracht opleveren:

| Ontbrekend gegeven | Reeks | Wetenschappelijke winst voor Meijendel |
|---|---|---|
| Oorspronkelijk route- of telpuntnummer | dagvlinders, hommels, libellen, nachtvlinders | Bevestigt dat dezelfde meeteenheid door de jaren wordt gevolgd en voorkomt dat een verplaatste route als ecologische verandering wordt gezien. |
| Secties en geometrieversies | dagvlinders en libellen | Maakt verandering binnen een route zichtbaar en koppelt die aan habitat, vegetatie en lokaal beheer. |
| Routetype en doelsoort | dagvlinders, hommels en libellen | Bepaalt voor welke soorten een niet-melding werkelijk nul is; essentieel voor verspreidings- en trendmodellen. |
| Volledige bezoekadministratie, inclusief lege bezoeken | alle meetnetten | Onderscheidt echte afwezigheid van niet tellen en maakt detectiekans, bezetting en betrouwbare jaartrends mogelijk. |
| Deelname per module | hommels, dagactieve nachtvlinders en nectarplanten | Voorkomt dat niet-deelnemen als achteruitgang wordt uitgelegd en maakt trends per soortgroep vergelijkbaar. |
| Determinatieniveau (`op soort` of verzamelgroep) | hommels en optionele microvlinders | Bepaalt op welk taxonomisch niveau trends verantwoord zijn en voorkomt schijnbare soortafnames door gewijzigde herkenning. |
| Tellers en aantal deelnemers | routes en telpunten | Maakt correctie mogelijk voor verschillen in ervaring en waarnemingskans; verbetert de vergelijkbaarheid tussen jaren. |
| Weer, begin-/eindtijd en bezoekduur | dagvlinders, hommels en libellen | Helpt tijdelijke verschillen in activiteit te scheiden van echte ecologische verandering. |
| Route-, habitat- en beheerwijzigingen | routes | Maakt een onderscheid mogelijk tussen verandering door beheer of vegetatie en verandering door een gewijzigde telling. |
| Val-, lamp-, brandduur- en binnen/buiteninformatie | nachtvlinders | Maakt vangsten tussen nachten en jaren vergelijkbaar; zonder deze gegevens kan een methodewijziging op een populatieverandering lijken. |
| Volledige macronachtvlinderlijst en deelname aan microvlinders | nachtvlinders | Levert echte nullen binnen het gekozen taxonomische bereik en voorkomt vertekening door optionele registratie. |

De grootste directe winst komt van route-/telpunt-ID's, volledige bezoeken en
het doelsoortenbereik. Daarmee veranderen positieve waarnemingen in een
controleerbare meetreeks met echte nullen. Weer, teller en methodekenmerken
verhogen daarna de kwaliteit doordat bekende verschillen in detectie en
telinspanning kunnen worden gecorrigeerd.

### Benodigde reconstructieversie 2 voor Vlinderstichting-meetnetten

De kleinste verantwoorde vervolgstap is niet één generiek surveyschema, maar een
uitbreiding van de bestaande protocoltabellen met de werkelijk onderscheiden
entiteiten:

1. route of telpunt met oorspronkelijk nummer, type, doelsoort en
   geldigheidsperiode;
2. vaste secties en geometrieversies;
3. afzonderlijk bezoek met datum/tijd, teller, weer, volledigheid en
   methodegeldigheid;
4. deelname per bezoek aan dagvlinders, dagactieve nachtvlinders, hommels en
   nectarplanten;
5. telling per bezoek, sectie, taxon, levensstadium en teleenheid;
6. route- en beheerwijzigingen;
7. voor nachtvlinders daarnaast telpunt, valtype, lamptype, brandduur en
   binnen/buiten de val.

Deze velden worden pas gevuld wanneer zij rechtstreeks aanwezig zijn of onder
een expliciete, geversioneerde afleidingsregel vallen. Ontbrekende deelname- of
routetypevelden worden nooit uit een ontbrekende soort afgeleid.

Het NEM-Meetprogramma Reptielen (`10.201`) is onder
`ndff-reptielroute-v2` uit uitsluitend openbare records gereconstrueerd. De 957
bronrecords uit 1990-2025 vormen 14 routefamilies en 660 route-datumbezoeken.
Van die bezoeken zijn er 648 aan een route gekoppeld; twaalf bezoeken hebben
alleen een grof kilometerhok. De 15 historische trajectgeometrieën vormen de
routeankers; 56 latere exacte locaties zijn aan het best passende anker
gekoppeld. Alleen twee protocoltaxa komen voor: Zandhagedis en Hazelworm.

De bezoek-soortmatrix bevat 1.320 regels: 661 positieve combinaties en 659
nullen voor Hazelworm met bereik `binnen_geleverd_positief_bezoek`. Ieder
aangeleverd bezoek bevat minstens een
positieve Zandhagediswaarneming. De FFV-bron bevat dus geen volledig negatieve
reptielenbezoeken; ontbrekende Zandhagedisbezoeken of -nullen worden niet
gereconstrueerd. De 6.286 adulte, 64 subadulte en 761 juveniele dieren blijven
afzonderlijk optelbaar. Begin- en eindtijden worden bewaard, maar de feitelijke
inspanning is `niet_afleidbaar`; de bronperiode wordt expliciet niet als
inspanning geïnterpreteerd. De vier `Meijendel.ndff_reptiel_*`-tabellen
worden met `--audit-reptielen` gecontroleerd en staan niet in het beveiligde
schema.

NEM-amfibieënprotocol `01.201` is onder `ndff-amfibiewater-v2` uit de 2.439
onvervaagde openbare records uit 2003-2025 gereconstrueerd. De 52 openbare
watergeometrieën vormen 50 conservatief gekoppelde waterfamilies, 211
telgebiedbezoeken en 1.300 waterbezoeken met minstens één positieve
registratie. Geometrieën worden alleen als versies van hetzelfde water
gekoppeld wanneer hun gebruiksjaren niet overlappen en hun middelpunten
hoogstens 30 meter uiteen liggen.

De matrix bevat 9.100 waterbezoek-taxonregels: 2.274 positief en 6.826
`niet_gemeld_methode_onbekend`. De RAVON-handleiding maakt duidelijk dat een
nul alleen binnen het juiste programmaonderdeel, seizoen, stadium en de
gebruikte zoekmethode betekenis heeft. Die informatie ontbreekt in de
FFV-export; daarom zijn de 6.826 eerdere nullen ingetrokken. Volledig negatieve
water- of telgebiedbezoeken kunnen uit de positieve FFV-export evenmin worden
hersteld. Exacte aantallen, RAVON-presentieklassen, minimumaantallen,
schattingen en gemengde telwaarden blijven afzonderlijk herkenbaar;
presentieklassen worden nooit als exacte aantallen opgeteld. De twee
Bastaardkikkerlabels zijn alleen voor analyse genormaliseerd, met behoud van
beide bronlabels.

De 80 vervaagde Kamsalamanderrecords zijn jaarlijkse aggregaten en vormen geen
reconstrueerbare openbare waterbezoeken. Zij blijven in de bestaande
beveiligde bronlaag; er zijn geen afgeleide `ndff_amfibie_*`-tabellen in
`Meijendel_ndff_secure` en er worden geen Kamsalamandernullen afgeleid. De vijf
openbare tabellen worden gecontroleerd met `--audit-amfibieen`.

RAVON-protocol `13.202` is apart vastgelegd onder
`ndff-ravon-n2000-v1`. De 67 positieve records vormen 25
monsterlocatieproxy's; 14 regels zijn doelsoort en 53 bijvangst. De handleiding
vereist soortspecifieke methode en inspanning en kent expliciete negatieve
registratie. Omdat deze context niet in de NDFF-regels staat, zijn geen
bezoeken of nullen afgeleid. Voor `13.201` is om dezelfde reden de eerdere
term waterlocatieproxy vervangen door de neutralere `monsterlocatieproxy`.

De actuele protocolbesluiten zijn beschikbaar via
`Meijendel.v_ndff_analysebesluit_actueel`; deze view voorkomt dat historische
regelversies in dezelfde analyse worden meegeteld.

### Zoogdiervereniging: toets aan de officiële meetnethandleidingen

De officiële handleidingen voor `17.201`, `17.202`, `17.207`, `17.208`,
`17.209` en `17.210` zijn op 15 september 2026 onder het Zotero-parentitem
`Meetnetten - Zoogdiervereniging` geplaatst en met de ontvangen NDFF-regels
vergeleken. Protocol `17.204` valt buiten deze vergelijking: daarvoor is de
primaire SOVON/AVIMAP-export leidend.

De inhoudelijke correctie betreft `17.201`. De 3.960 wintertelrecords uit
1976-2025 bevatten 3.786 registraties van soorten waarvoor het NEM-wintermeetnet
in beginsel geschikt is, 124 positieve
bijvangsten en 50 registraties `Plecotus auritus/austriacus` die niet veilig
aan een trendsoort kunnen worden toegewezen. De gecombineerde categorie
`Myotis mystacinus/brandtii` is volgens de handleiding juist een officiële
telcategorie en is als doelsoort behouden. De soortindeling staat in
`ndff_protocol_soort_geschiktheid` onder `ndff-protocolbereik-v2`.

Deze classificatie maakt de positieve wintertellingen beter selecteerbaar,
maar reconstrueert nog geen lokale trendmatrix. De NDFF-regels missen het
vaste object-id, de expliciete status geteld/niet geteld en de start- en
stopredenen van een object. Juist deze gegevens bepalen volgens de handleiding
of een ontbrekende telling mag worden bijgeschat of als nul moet gelden.

De vergelijking gaf voor de overige vijf reeksen geen nieuwe noodzakelijke
databasecorrectie. `17.202` bevat zeven positieve records zonder eenduidige
trenddoelsoort; `17.207` bevat drie losse positieve Otterregistraties en geen
bewijs van drie uitgevoerde sporenronden; `17.208` is al naar NEM-VTT en
VleerMUS gescheiden; `17.209` blijft zonder route- en sectie-id een positieve
sectietelreeks; `17.210` bevat vijf positieve jaarrecords maar geen concrete
bezoekdatum of volledigheidsstatus. Voor deze reeksen worden daarom geen
nieuwe nullen afgeleid.

Bronnen: [NEM-handleiding Wintertellingen vleermuizen 2025](https://www.zodion.nl/sites/default/files/2025-11/handleiding_nem_meetprogramma_wintertellingen_vleermuizen_2025.pdf),
[NDFF Protocollen](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/)
en [CBS Meetprogramma's flora en fauna 2025](https://longreads.cbs.nl/meetprogrammas-flora-en-fauna-2025/meetprogrammas/).

Het Vleermuistransectprotocol (`17.208`) is onder
`ndff-vleermuistransect-v1` uit uitsluitend onvervaagde openbare records
gereconstrueerd. De 2.624 bronrecords uit 2013-2025 bestaan uit twee
zelfstandige meetreeksen: 26 bezoeken van een noordelijke NEM-VTT-autoroute en
18 bezoeken van een zuidelijke vleerMUS-fietsroute. In 2019 zijn 73 oude
vleerMUS-regels op middernacht aantoonbaar dubbel aangeleverd naast een
overeenkomende regel met werkelijk tijdstip; de oude regels blijven in de
recordselectie zichtbaar maar tellen niet mee. Daardoor blijven 2.551
akoestische detecties over, niet 2.551 individuele vleermuizen.

De NEM-VTT-route heeft vier doelsoorten: Gewone dwergvleermuis, Ruige
dwergvleermuis, Laatvlieger en Rosse vleermuis. De vleerMUS-route heeft de
eerste drie als doelsoort; Rosse vleermuis en overige taxa zijn daar
bijvangst. De matrix bevat 242 bezoek-taxonregels: 126 positieve
doelsoortregels, 32 echte nullen binnen het geldige methodebereik en 84
positieve bijvangstregels. Negen bezoeken vallen buiten het huidige
methodeseizoen en zes bezoeken hebben een herhalingsinterval dat volgens de
huidige handleiding nadere controle verdient. Ze blijven bewaard en zichtbaar
gemarkeerd. De vijf `Meijendel.ndff_vleermuis_*`-tabellen worden gecontroleerd
met `--audit-vleermuizen`; er staan geen afgeleide vleermuisgegevens in het
beveiligde schema.

Het konijnentelprotocol (`17.209`) is onder `ndff-konijnentelling-v1`
geclassificeerd uit 5.809 onvervaagde openbare records uit 1984-2023. Daarvan
zijn 5.095 positieve Konijnrecords en 714 positieve bijvangsten. Alle waarden
zijn exacte tellingen van levende, geziene dieren en de bronhouder is de
Zoogdiervereniging. De huidige landelijke methode telt een vaste route in
secties, in voor- en najaar, vier tot acht keer per seizoen. De ontvangen
FFV-laag bevat echter geen route- of sectie-id: elf kilometerhokken, 812
kalenderdatums en 5.084 hok-datum-taxoncombinaties kunnen daardoor niet tot
native bezoeken worden teruggebracht.

Er zijn 725 hok-datum-taxoncombinaties met meerdere sectieregels. In 71 groepen
hebben twee records ook dezelfde telwaarde; de 142 betrokken records blijven
allemaal behouden, omdat gelijke sectietellingen geen bewezen dubbelen zijn.
Elf records hebben een exacte datum-hok-taxon-waardeovereenkomst met DAZ-BMP
(`17.204`) en zijn alleen als mogelijke overlap gemarkeerd. Alle 5.809
kilometerhokgeometrieën raken meerdere SOVON-plots. Daarom bevat
`ndff_konijn_recordselectie` de kwaliteitsstatus per bronrecord en is
`ndff_konijn_hokdatum_taxon` uitsluitend een diagnostische proxy. Er worden
geen routebezoeken, nullen of TRIM-invoer afgeleid. Voor trendgebruik is een
vertaaltabel van NDFF-record naar oorspronkelijke route en sectie nodig. De
twee openbare tabellen worden gecontroleerd met `--audit-konijnen`; er staan
geen afgeleide konijnentabellen in het beveiligde schema.

Methodische bronnen: [NEM Meetprogramma's Zoogdieren](https://www.netwerkecologischemonitoring.nl/meetprogrammas/zoogdieren),
[Zoogdieren in Zuid-Holland](https://www.zoogdiervereniging.nl/sites/default/files/2019-10/2016.36%20Zoogdieren%20in%20Zuid-Holland.pdf)
en [Telganger Konijnentellingen](https://www.zoogdiervereniging.nl/sites/default/files/2026-04/telganger_2023-2_0-24-29_konijnentellingen.pdf).

Het DAZ-BMP-protocol (`17.204`) is onder `ndff-daz-bmp-v1` gekoppeld aan de
bestaande BMP-bezoeken. De NDFF-regels bevatten uitsluitend zoogdieren; zij
zijn nevenregistraties van het deel van de BMP-vogeltellers dat aan DAZ deelnam
en alle tijdens zo'n bezoek waargenomen zoogdieren noteerde. Daarom bewijst een
eenduidig gekoppeld positief 17.204-record deelname van dat bezoek. Het
ontbreken van zo'n record bij een ander BMP-bezoek bewijst geen deelname en
levert dus geen volledig negatief DAZ-bezoek op.

Van de 10.670 openbare records koppelen 3.171 op datum en precies één geraakt
SOVON-plot eenduidig aan 1.475 BMP-bezoeken in 49 plots (2005-2022). Voor deze
bezoeken is een matrix gemaakt voor Konijn, Haas, Vos, Ree, Eekhoorn, Egel en
Muskusrat. Zij bevat 10.325 doelsoortregels: 2.681 positieve tellingen, 7.552
echte nullen en 92 onbesliste regels. Die 92 worden niet als nul gebruikt,
omdat een positief record van hetzelfde taxon meerdere BMP-bezoeken kan
betreffen. Van de 161 positieve bijvangstrecords koppelen er 50 eenduidig; zij
vormen 49 positieve bezoek-taxonregels en krijgen nooit nullen. De overige
1.026 meervoudig koppelbare en 6.473 niet koppelbare bronrecords blijven
zichtbaar in de recordselectie. De vier tabellen worden gecontroleerd met
`--audit-daz-bmp`; er staan geen afgeleide DAZ-tabellen in het beveiligde
schema.

De vier tabellen heten sinds 3 oktober 2026 `daz_bmp_*`. De historische
reconstructieversie `ndff-daz-bmp-v1` en alle 27.923 bestaande rijen zijn bij
de atomaire hernoeming behouden. De tabelgroep bevat daarnaast uitsluitend
letterlijke positieve zoogdiertellingen uit de jaarlijkse SOVON-BMP-bestanden.
Voor 2005 betreft dit 79 ontbrekende bezoek-taxonregels met samen 281 dieren;
er zijn uit deze jaarbestanden geen zoogdiernullen afgeleid.

Methodische grondslag: [NEM Meetprogramma Zoogdieren](https://www.netwerkecologischemonitoring.nl/meetprogrammas/zoogdieren)
en [Kwaliteitsrapportage NEM 2024](https://www.netwerkecologischemonitoring.nl/wp-content/uploads/2025/05/meetprogrammasvoorfloraenfauna2024.pdf).

Na afronding van alle NDFF-protocolbewerkingen wordt een nieuw volledig
BMP/SAP-bestand gedownload. Naar verwachting bevat dit de primaire
zoogdierregistraties per BMP-telling en mogelijk de oorspronkelijke locaties.
Daarmee kan `ndff-daz-bmp-v1` onder een nieuwe reconstructieversie worden
verbeterd: oorspronkelijke bezoekkoppelingen gaan vóór de huidige afleiding uit
datum en openbaar kilometerhok, volledig negatieve deelnemende bezoeken kunnen
worden toegevoegd en de nu ambigue of niet koppelbare NDFF-records kunnen
opnieuw worden beoordeeld. NDFF blijft daarbij als secundaire controlebron
behouden.

### Nederlandse Mycologische Vereniging: toets aan de officiële handleidingen

Op 15 september 2026 zijn drie officiële handleidingen onder Zotero-parentitem
`Meetnetten - Nederlandse Mycologische Vereniging (NMV)` (`GATY566T`)
opgenomen: de algemene handleiding 2023, de invoerhandleiding 2022 en de
historische handleiding Paddestoelenmonitoring.

Het NEM-meetnet Zeereeppaddenstoelen (`11.202`) is onder
`ndff-zeereep-v2` gereconstrueerd op zijn oorspronkelijke meeteenheid: het
RD-kilometerhok. De 3.729 onvervaagde openbare records vormen 161 bevestigde
hok-datumbezoeken in 21 kilometerhokken, verspreid over 2014-2025. Negen
vervaagde records zijn niet als bezoek gebruikt. De bezoek-soortmatrix omvat
de zes typische doelsoorten en bevat 966 regels: 224 positieve combinaties en
742 niet-meldingen. De handleiding staat uitdrukkelijk toe dat een teller
slechts één of enkele bekende soorten volgt. Omdat de NDFF-export niet vermeldt
welke soorten per bezoek zijn geteld, hebben de 742 regels de status
`niet_gemeld_tellerscope_onbekend`; zij zijn geen echte nullen.

De bronwaarden blijven inhoudelijk intact: `1-3`, `4-20` en `21 of meer` zijn
NMV-klassen van vindplaatsen en geen aantallen vruchtlichamen. Honderd bezoeken
vallen in het aanbevolen kernseizoen oktober-december; 61 bezoeken staan
afzonderlijk gemarkeerd als buiten dat venster. Zonder aanvullende tellerscope
zijn alleen de positieve registraties rechtstreeks bruikbaar; de niet-meldingen
mogen niet in een bezettings- of trendmodel als nul worden ingevoerd. Controle
vindt plaats met `--audit-zeereeppaddenstoelen`; de drie afgeleide tabellen
staan uitsluitend in `Meijendel`.

Methodische bronnen: [NDFF 11.202](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/11-202-zeereeppaddenstoelen/)
en [NMV-methodiek Zeereeppaddenstoelen](https://www.mycologen.nl/onderzoek/meetnet/zeereep-concept/zeereep-methodiek/).

Het historische NEM-meetnet Bospaddenstoelen (`11.201`) is onder
`ndff-bospaddenstoel-v1` gereconstrueerd op vaste meetpunten. De 982 openbare
bronregels bevatten twee technische representaties. Voor 473
plot-datum-taxoncombinaties staat een presentieregel naast een regel met het
exacte vruchtlichaamaantal; de exacte regel is canoniek gemaakt zonder de
presentieregel uit het auditspoor te verwijderen. Daardoor blijven 509 unieke
positieve resultaten over op drie meetpunten en 110 bezoeken in 1999-2016.

De historische handleiding stelde per meetpunt een vaste keuze verplicht: alle
telsoorten óf één of enkele geselecteerde telsoorten; die keuze mocht tijdens
de reeks niet veranderen en een afwezige geselecteerde soort werd als nul
ingevuld. Daarom omvat het afgeleide doelbereik uitsluitend de 76
meetpunt-taxoncombinaties die door minstens één positieve melding aantoonbaar
zijn. De bezoekmatrix telt 2.934 regels: 506 positieve doelsoortresultaten en
2.428 echte bezoeknullen. De drie positieve regels voor `Fungi sp. indet.` zijn
bijvangst en krijgen geen nullen. De nul betekent geen vruchtlichaam tijdens dat
bezoek; zij bewijst geen afwezig mycelium en geen ongeschikte habitat.

De jaarlijkse tabel telt 977 meetpunt-jaar-taxonregels, waarvan 316 met een
positieve exacte maximumtelling en 661 nullen. Conform de historische
handleiding is de jaarwaarde het hoogste aantal vruchtlichamen op één teldag,
niet de som van bezoeken. Zeven bevestigde bezoeken in december staan als
buiten het historische kernseizoen juli-november gemarkeerd. Volledig negatieve
bezoeken, oorspronkelijke meetpuntnummers, terreinschetsen en zoektijd ontbreken
in de NDFF-export en zijn niet aangevuld. Controle vindt plaats met
`--audit-bospaddenstoelen`; alle zeven afgeleide tabellen staan in `Meijendel`.

Methodische bronnen: [NDFF 11.201](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/11-201-meetnet-bospaddenstoelen-nem/)
en de [historische handleiding Paddestoelenmonitoring](https://www.netwerkecologischemonitoring.nl/wp-content/uploads/2017/08/Handleiding-paddenstoelen.pdf).

## Toepassing op beveiligde levering 58679

De op 10 september 2026 ontvangen levering bevestigt de protocolaudit. Van de
14.573 positieve records vallen 1.926 onder een passend doelgericht meetnet en
5 onder gebiedsmonitoring. Na de strenge SOVON-plottoewijzing en PQ-poort zijn
1.274 daarvan ruimtelijk geschikt voor een gerichte aanvraag van volledige
brondata. De GeoPackage bevat zelf geen telobjecten, bezoekstructuur,
inspanning, protocolversies of afleidbare nullen; `zoid` en `sessionid` zijn in
alle records 0. Daarom waren in de beveiligde levering op zichzelf nul records
direct trendklaar. Dit sluit latere reconstructie met de volledige openbare
reeks en de officiële protocolregels niet uit; `03.201` is inmiddels zo
uitgewerkt.

## NEM-reconstructie op de volledige canonieke laag

De eerdere vervolgselectie van 1.274 records was uitsluitend gebaseerd op de
beveiligde levering van 191 soorten. Zij is geen rangorde voor alle NDFF-data.
Na voltooiing van `ndff-analyseketen-v1` is de prioriteit opnieuw bepaald op de
810.983 unieke canonieke records. Daarvan zijn 65.464 records voorlopig
kandidaat voor minstens één protocolmatig gebruikstype buiten uitsluitend
positieve voorkomensinformatie (`V`). `Gegevensgeschiktheid` blijft in de
algemene analysepoort `niet_beoordeeld`; een voltooide protocolreconstructie
krijgt daarnaast haar eigen, strengere matrix en audit.

| Protocol | Records | Bezoeken | Jaren | Stand |
|---|---:|---:|---|---|
| `03.201` Dagvlinders | 82.217 | 3.126 | 1990-2025 | gereconstrueerd |
| `03.201` Vliesvleugeligen | 1.535 | 217 | 2018-2025 | zelfstandige NEM-deelreeks gereconstrueerd |
| `07.201` Libellen | 3.280 | 461 | 2007-2021 | negen routefamilies en bezoek-soortmatrix gereconstrueerd |
| `10.201` Reptielen | 957 | 660 | 1990-2025 | 14 routefamilies en bezoek-soortmatrix gereconstrueerd |
| `01.201` Amfibieën | 2.519 | 225 | 2003-2025 | eerst deelprotocol per bezoek bepalen |
| `17.208` Vleermuistransect | 2.624 | 44 | 2013-2025 | twee meetreeksen en bezoek-soortmatrix gereconstrueerd; 73 dubbelen onderdrukt |
| `17.209` Konijnen in de duinen | 5.809 | 812 | 1984-2023 | eerst overlap met bestaande tellingen toetsen |
| `11.202` Zeereeppaddenstoelen | 3.738 | 161 | 2014-2025 | 21 kilometerhokken en bezoek-soortmatrix gereconstrueerd; 9 vervaagde records uitgesloten |
| `02.202` Korstmossen | 384 | 32 | 2000-2025 | 12 proefvlakken en bezoek-soortmatrix gereconstrueerd; 20 vervaagde records uitgesloten |
| `02.204` Mossen | 377 | 7 hokken | 2000-2011 | 7 volledige hokinventarisaties en inventarisatie-soortmatrix gereconstrueerd; 1 vervaagd record uitgesloten |
| `11.201` Bospaddenstoelen | 982 | 110 | 1999-2016 | drie vaste meetpunten, bezoekmatrix en jaarlijkse maxima gereconstrueerd; 473 parallelle presentieregels onderdrukt |
| `12.204` Het Nieuwe Strepen | 4.569 | 23 lijstkandidaten | 2012-2024 | bezoekmatrix gereconstrueerd; onafhankelijkheid herhalingen nog niet bevestigd |
| `17.204` DAZ-BMP | 10.670 | 1.475 bevestigd | 1994-2022 | gekoppeld aan BMP; doelsoortmatrix met taxonspecifieke ambiguïteitsblokkade |
| `03.203` Nachtvlinders | 596 | 4 | 2019-2025 | geen nullen uit huidige NDFF-regels afleiden |
| `11.204` Bospaddenstoelen verspreiding | 14 | 2 | 2017 | te klein voor lokale trend |
| `13.201` Beek- en poldervissen | 20 | 6 | 2014 | te klein voor lokale tijdreeks |
| `17.207` Bever en otter | 3 | 3 | 2024 | te klein en slechts één lokaal taxon |
| `12.202` LMF-M&N | 15.129 | 329 | 1981-2024 | niet naast provinciale PQ gebruiken |

Record- en bezoekaantallen zijn bron- en reconstructiecontroles, geen
populatieomvang. Per protocol worden vóór nullen de native meeteenheid, het
volledige doelsoortenbereik en eventuele overlap met primaire bronnen getoetst.

### Primaire SOVON/AVIMAP-bron voor DAZ en overige bijvangsten

Op 13 september 2026 is de volledige export van SOVON/AVIMAP-project 252
gecontroleerd. De puntlaag telt 660.688 unieke bron-ID's. Daarvan zijn 19.960
niet-vogelregels uit 4.364 bezoeken geïmporteerd: 19.877 zoogdierregels
(2009-2026), 75 amfibie-/reptielregels (2009-2026), vier mierenregels
(2017-2019) en vier dagvlinderregels (2015-2017). De 35 taxa zijn gekoppeld aan
`ndff_soorten` waar de naam eenduidig overeenkomt; zeven resterende taxa hebben
een expliciete handmatige taxonreferentie. De 807 regels uit 2026 zijn als
lopend, mogelijk onvolledig jaar gemarkeerd.

De primaire DAZ-matrix `sovon-avimap-daz-v1` omvat 4.354 bezoeken, 30.478
bezoek-doelsoortcombinaties, 6.859 positieve uitkomsten en 23.619 echte nullen.
Daarnaast zijn 179 uitsluitend positieve bijvangst-uitkomsten bewaard. Een
echte nul wordt alleen afgeleid binnen een bezoek waarin minimaal één zoogdier
in de oorspronkelijke SOVON-bron staat; bezoeken zonder zoogdierregel hebben
geen aantoonbare DAZ-deelname en blijven buiten de matrix.

De vergelijking met alle 10.670 openbare `17.204`-regels gebeurt op datum,
taxon en RD-kilometerhok. Voor 2.654 NDFF-regels is ook de totale telwaarde
gelijk; 1.917 overlappende regels hebben een telwaardeconflict. In beide
gevallen is de primaire SOVON-bron leidend en wordt NDFF niet daarnaast geteld.
De overige 6.099 NDFF-regels hebben geen tegenhanger in deze SOVON-export en
blijven herkenbaar als uitsluitend secundaire bron. Geen ruwe NDFF-regel is
fysiek verwijderd.

De meegeleverde vogelgegevens zijn uitsluitend-lezen vergeleken. Alle 297.092
bestaande dagwaarneming-ID's en alle 7.227 bestaande bezoek-ID's komen in de
SOVON-export voor. De export bevat daarnaast tot en met 2025 respectievelijk
303.867 vogelregels en 7.228 bezoeken die niet in de database staan. Bij de
gemeenschappelijke dagregels zijn datum, soort, aantal, coördinaten en overige
inhoudelijke velden gelijk, behalve 155 inmiddels als buiten het plot gemarkeerde
regels; lege versus nulwaarden verklaren de schijnverschillen in broedcode en
cluster-ID. Vrije bezoektekst wijkt bij 297 bezoeken af en bezoekduur bij 17
bezoeken na afronding op hele minuten. Voor territoria zijn 260 bronresultaten
niet in de database aanwezig, staan 104 database-uitkomsten uit 2009-2025 niet
in deze export en verschillen 53 gemeenschappelijke aantallen. De export bevat
geen resultaten of territoriapunten voor 2008 en slechts een beperkte set voor
2007. Daarom zijn de vogeltabellen niet gewijzigd; deze afwijkingen vragen een
afzonderlijke vogelbronbeslissing.

Die bronbeslissing is op 13 september 2026 genomen. De primaire download is
voor aanwezige SOVON-regels leidend en wordt tot en met 2025 aanvullend en
corrigerend verwerkt. Ontbrekende vogelregels, bezoeken en
territoriumresultaten worden toegevoegd. Bij dezelfde bron-ID worden de actuele
SOVON-velden overgenomen, waaronder `in_plot`, bezoektekst en bezoekduur; bij
dezelfde plot-soort-jaarcombinatie wordt het territoriumaantal bijgewerkt. Er
worden geen bestaande gegevens verwijderd alleen omdat zij in de export
ontbreken. Dat beschermt handmatige aanvullingen en is noodzakelijk omdat de
export geen resultaten voor 2008 en slechts een beperkte set voor 2007 bevat.
Jaar 2026 blijft geheel buiten deze vogelsynchronisatie. De reproduceerbare
commando's zijn `--sync-sovon-avimap-vogels` en
`--audit-sovon-avimap-vogels`.

De uitvoering voegde 303.867 vogelwaarnemingen, 7.228 bezoeken en 260
territoriumresultaten toe. Zij corrigeerde bij rechtstreeks overeenkomende
bronregels 155 `in_plot`-waarden, 297 bezoekteksten, 165 bezoekduren en 53
territoriumaantallen. Van de bezoekduren bevatten 47 bronwaarden een aantoonbaar
geheel-etmaalartefact; alleen die waarden zijn uit begin- en eindtijd herleid.
Eén bezoek uit 2023 houdt bronconform een duur boven 24 uur en een expliciete
correctie-opmerking. De drie positieve niet-vogelregels en zeven DAZ-matrixregels
van dat bezoek hebben daarom status `handmatige_controle_bezoekduur`. De 2.521
bestaande territoriumregels zonder exportregel bleven ongewijzigd. Een tweede
volledige synchronisatie leverde nul toevoegingen en nul correcties op.

Voor statistisch gebruik staan de primaire niet-vogelregels expliciet in
`v_sovon_avimap_niet_vogel_analyse`. Alleen de zeven DAZ-doelsoorten krijgen
protocolkandidaattypen `V,TA`; gebruik voor tellingen de afzonderlijke
bezoek-taxonmatrix `v_sovon_avimap_daz_analyse`. Overige zoogdieren en de
amfibieën-, reptielen-, mieren- en dagvlinderbijvangsten zijn uitsluitend
positieve aanwezigheidsinformatie (`V`). Ontbreken is daar geen nul en de
ruwe aantallen zijn geen populatietrend. Het lopende jaar blijft afzonderlijk
als uitgesloten gemarkeerd.

### Het Nieuwe Strepen (`12.204`)

De eerdere telling van 1.145 verschillende begin-/eindtijdcombinaties was geen
bezoektelling. Bij app-invoer heeft vrijwel iedere plantwaarneming haar eigen
tijdstip. Regelversie `ndff-hns-v2` groepeert de 4.569 openbare bronregels
daarom op kalenderdatum en ruimtelijk samenhangende RD-kilometerhokken. Het hok
met minimaal 80% van de regels geldt als waarschijnlijk doelhok. Een cluster
geldt als `volledige_lijst_aannemelijk` wanneer het binnen 27 april-30 september
ligt en ten minste 50 taxa bevat. Dit zijn transparante, conservatieve
reconstructiedrempels en geen landelijke FLORON-protocolnormen.

De reconstructie bevat 26 datum/ruimteclusters: 23 aannemelijk volledige
inventarisaties met 4.524 bronregels en drie fragmenten met samen zes regels.
Daarnaast blijven 39 openbaar vervaagde jaarregels positief beschikbaar, maar
zonder koppeling aan een bezoek. Het uit de volledige lijsten aantoonbare lokale
doelbereik omvat 703 taxa. De bezoekmatrix bevat 4.439 positieve combinaties en
11.730 afgeleide protocolnullen; het hok-jaarbestand bevat 3.269 positieve combinaties en
5.167 nullen over twaalf hok-jaren.

FLORON heeft op 6 oktober 2026 bevestigd dat één kalenderdag in één
kilometerhok de beschikbare teleenheid is. Binnen zo'n telling kunnen conform
het protocol één, twee of drie oorspronkelijke lijsten liggen. FLORON levert
geen persoonsgegevens of daarvan afgeleide waarnemerscodes. De onderliggende
lijsten kunnen daarom niet als afzonderlijke waarnemersherhalingen worden
gebruikt, maar tellingen op verschillende kalenderdagen zijn wel afzonderlijke
dag-hoktellingen.

Deze informatie bevestigt de groepering van de 26 clusters: ieder cluster bevat
precies één verschillende begindatum en één doelhok. V2 gebruikt de begindatum
als teldatum; een latere `periode_stop` bewijst geen tweede velddag. Bij 21
clusters staat nu neutraal dat hetzelfde hok in hetzelfde jaar op meerdere
kalenderdagen is geteld. Dat is geen uitspraak over onafhankelijke waarnemers.
De recordselectie, het doelbereik, de positieve combinaties en afgeleide nullen
zijn gelijk aan `ndff-hns-v1`; v1 blijft als historisch auditspoor bewaard. De
11.730 nullen blijven afgeleide
protocolnullen: zij zijn niet door FLORON opgeslagen, maar volgen uit een
aannemelijk volledige HNS-telling en het lokale doelbereik. Gebruik de matrix
voorlopig voor verspreidings- en occupancyanalyse; voer aantallen en dubbele
vindplaatsen niet als plantenabundantie in. Controleer de laag met
`--audit-hns`.

Methodische grondslag: [FLORON Het Nieuwe Strepen](https://www.floron.nl/Meedoen/Het-Nieuwe-Strepen),
[FLORON protocol 2019](https://www.floron.nl/Portals/1/Downloads/Protocol%20Het%20Nieuwe%20Strepen%202019_papierenstreeplijst_mei2019.pdf),
[NEM Flora](https://www.netwerkecologischemonitoring.nl/meetprogrammas/flora)
en [CBS Meetprogramma's 2025](https://longreads.cbs.nl/meetprogrammas-flora-en-fauna-2025/meetprogrammas/).

### Korstmossen op steen, heiden en stuifzanden (`02.202`)

Regelversie `ndff-korstmos-v2` reconstrueert 364 onvervaagde openbare
bronregels tot twaalf proefvlakken en 32 bezoeken in 2000-2025. Vier vaste
proefvlakken zijn in zes meetjaren herhaald; acht proefvlakken hebben één
bevestigd bezoek. Het openbare lokale doelbereik omvat dertig taxa. Omdat het
protocol per bezoek een complete soortenlijst voorschrijft, bevat de
bezoek-soortmatrix 287 positieve combinaties en 673 echte nullen.

De officiële methode schrijft per locatie twee onafhankelijke tellingen voor.
De bron bevat 67 bezoek-taxoncombinaties met twee gelijke klassen en tien met
twee verschillende klassen. Dit zijn geen technische dubbelen of fouten, maar
afzonderlijke waarnemertellingen. Bij twaalf bezoeken is de dubbele telling in
de export aantoonbaar; bij twintig bezoeken is zij niet aantoonbaar. Dat laatste
bewijst niet dat slechts één teller aanwezig was. De FFV-levering bevat slechts
twee ordinale klassen,
terwijl de oorspronkelijke BLWG-methode zes klassen onderscheidt. Gebruik de
matrix daarom voor presentie/occupancy en de grove rang alleen als ordinale
indicator, niet als exacte bedekking. Voor waarnemerspecifieke detectieanalyse
zijn alsnog waarnemer- of lijst-ID's nodig; de gecombineerde plotanalyse wordt
daardoor niet geblokkeerd. Twintig vervaagde Saucijs-baardmosrecords
worden niet naar openbare afgeleide tabellen gekopieerd en leveren daar ook geen
nullen. Controleer de laag vóór gebruik met `--audit-korstmossen`.

Methodische grondslag: [NDFF protocol 02.202](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/2-202-korstmossen-op-steen-heiden-en-stuifzanden-nem/),
[BLWG meetnet](https://www.blwg.nl/meetnet-korstmossen-in-stuifzanden-nem)
en [NEM Korstmossen](https://www.netwerkecologischemonitoring.nl/meetprogrammas/korstmossen).
De beoordeelde BLWG-documenten staan in Zotero onder `Meetnetten - BLWG`
(`8E3TCBHW`).

**Primaire BLWG-levering, 8 oktober 2026 — nog niet geïmporteerd.** Het
ontvangen Excelbestand bevat zes plots, 32 oorspronkelijke formulieren
(`kopid`) en 292 positieve soortregels. Vier vaste plots hebben
zes meetronden in de veldjaren 2000, 2006, 2011, 2015, 2020 en 2025;
twee eenmalige plots hebben alleen formulieren uit 2021. De 32 bronformulieren
zijn niet identiek aan de 32 hierboven uit NDFF afgeleide plot-datumbezoeken:
de bron scheidt onafhankelijke waarnemers op hetzelfde plot en dezelfde datum.
Van de 292 bronregels matchen 269 op plot, velddatum en soortnaam met
onvervaagde NDFF-regels; twintig *Usnea articulata*-regels zijn in de openbare
NDFF-levering vervaagd en drie zijn taxonomische naamsverschillen
(*Bacidia/Bacidina caligans* tweemaal; *Leptogium/Scytinium pulvinatum*
eenmaal). De oorspronkelijke `Kwantiteit`-codes 1, 2, 3, 5 en 6 bevatten
meer detail dan de twee openbare NDFF-klassen. Analyseer volgens de
velddatum, niet volgens het vaak een jaar eerdere rapportagejaar.

Dezelfde NDFF-selectie 02.202 heeft daarnaast 92 regels op zes andere,
eenduidig aan een SOVON-plot gekoppelde BLWG-locaties: twee met een bezoek op
15 februari 2015 (36 regels) en vier met een bezoek op 31 maart 2018
(56 regels). Deze ontbreken in de primaire Excel-levering. Vraag uitsluitend
gericht of de oorspronkelijke plot- en bezoekgegevens voor deze zes locaties
ook beschikbaar zijn. Wijzig tot na een afzonderlijke integratie-audit geen
NDFF-bronregels of afgeleide matrix; bescherm de twintig publiek vervaagde
waarnemingen en hun plotkoppeling.

### Meetnet mossen (`02.204`)

Regelversie `ndff-mos-v2` reconstrueert 376 onvervaagde openbare bronregels
tot zeven volledige kilometerhokinventarisaties. De 21 bronperioden daarbinnen
zijn negentien dagclusters en twee jaarintervallen; zij worden niet als 21
onafhankelijke bezoeken behandeld. Eén inventarisatie overspant de jaargrens
2010-2011. Geen kilometerhok is in de lokale levering in een latere meetronde
herhaald, zodat deze selectie zelfstandig geen lokale tijdtrend ondersteunt.

Het uit de openbare records aantoonbare lokale doelbereik omvat 111 taxa. De
inventarisatie-soortmatrix bevat 354 positieve combinaties en 423 echte nullen.
Van de positieve combinaties hebben er 312 een BLWG-talrijkheidsklasse 1-3 en
41 alleen een presentiewaarde. Eén combinatie heeft conflicterende
talrijkheidsklassen. Daarnaast blijven 21 gelijke parallelle bronregels in het
auditspoor staan, maar zij tellen niet als extra resultaat.

Het protocol vereist een zo volledig mogelijke soortenlijst per geselecteerd
kilometerhok, minimaal acht mensuren, alle relevante biotopen en een
talrijkheidsklasse per soort. De expliciete protocolcode geldt als bewijs voor
die minimale inspanning en habitatdekking; een precieze bezoekduur of waarnemer
hoeft niet opnieuw te worden opgevraagd om de inventarisatie als protocolconform
te behandelen. De FFV-export bevat geen oorspronkelijk BLWG-lijst-ID. Een
kilometerhok wordt niet als aanwezigheid of nul in ieder geraakt SOVON-plot
geïnterpreteerd. Eén vervaagd record wordt niet naar openbare afgeleide tabellen
gekopieerd. Controleer de laag vóór gebruik met `--audit-mossen`.

Methodische grondslag: [BLWG Meetnet Mossen](https://www.verspreidingsatlas.nl/projecten/blwg/meetnetmossen.aspx),
[BLWG Inventarisatiehandleiding](https://www.blwg.nl/wp-content/uploads/2025/08/BLWG-Inventarisatiehandleiding.pdf)
en [GBIF-beschrijving protocol 02.204](https://www.gbif.org/dataset/2d1a33c3-f278-40d2-a662-e0d3369658e2).

### FLORBASE-streeplijsten (`12.001`)

Regelversie `ndff-florbase-v1` groepeert 21.161 onvervaagde openbare
bronregels per werkelijk RD-kilometerhok en jaar. Dat levert 183 hok-jaren in
36 hokken op. De 118 hok-jaren in 33 hokken met minimaal vijftig geregistreerde
taxa gelden als `volledige_lijst_aannemelijk`; de overige 65 blijven fragment.
De grens van vijftig taxa is een transparante lokale reconstructiedrempel en
geen officiële FLORON-protocolnorm.

Het uit de aannemelijk volledige lijsten aangetoonde lokale doelbereik omvat
857 taxa. De inventarisatie-taxonmatrix bevat 19.405 positieve combinaties en
81.721 `protocolnul_onder_volledigheidsaanname`. Van de positieve combinaties
hebben 18.731 alleen presentie-informatie en 674 ook aantalsinformatie. Deze
aantallen of meerdere vindplaatsen worden niet geaggregeerd tot lokale
abundantie. De 987 bronregels uit fragmenten blijven als positieve informatie
traceerbaar maar leveren geen nullen.

FLORON heeft op 6 oktober 2026 bevestigd dat één jaar in één kilometerhok als
één telling moet worden behandeld en dat de organisatie niet over een fijnere
bronstructuur beschikt. Voor 2011 werd uitsluitend soort, jaar, kilometerhok en
waarnemer opgeslagen. Expliciete registraties van niet-aangetroffen soorten
worden niet bewaard. De eerder gevraagde lijst-ID, volledigheidsvlag,
bezoekdatum, bezoekduur en historische checklistversie kunnen deze reeks daarom
niet alsnog verrijken.

De huidige hok-jaarindeling is daarmee bevestigd, maar de grens van vijftig taxa
blijft een lokale volledigheidsaanname. De 81.721 afgeleide nullen zijn geschikt
voor voorlopige inventarisatie- en verspreidingsvergelijkingen met een
gevoeligheidsanalyse voor deze drempel, niet zonder waarschuwing voor een
definitieve trendclaim. De native meeteenheid is het kilometerhok; geen
aanwezigheid of nul wordt naar ieder geraakt SOVON-plot doorgezet. De 213
vervaagde records worden niet naar deze openbare afgeleide laag gekopieerd.
Controleer de laag met `--audit-florbase`.

Methodische grondslag: [NDFF protocol 12.001](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/12-001-totaalproject-floron/),
[FLORON kilometerhokinventarisatie](https://www.floron.nl/Meedoen/Kilometerhokken-inventariseren)
en [FLORON inventarisatiehandleiding](https://www.floron.nl/Portals/1/Downloads/2022%20handleiding%20inventarisatie-projecten.pdf).

### LMF-A (`12.211`)

Het officiële FLORON-rapport over Berkheide, Meijendel en Solleveld maakt de
bovenliggende meetstructuur van protocol `12.211` expliciet. Dunea laat per
kilometerhok een vaste looproute lopen. In het zomerseizoen worden daar 75
goed herkenbare aandachtssoorten gevolgd, gemiddeld eens per vier jaar. De
oorspronkelijke uitkomst is per soort één FLORON-abundantieklasse voor de hele
route; wanneer groeiplaatsen apart zijn ingevoerd, worden exacte aantallen eerst
opgeteld.

Regelversie `ndff-lmfa-v1` groepeert de 5.980 NDFF-regels tot 30 routes en 124
routejaren. Van deze routejaren staan er 79 in de rapporttabel voor 1999-2019;
45 latere of afwijkende hokjaren zijn herkenbaar aan protocol `12.211`, maar
niet in die rapporttabel bevestigd. De bezoek-soortmatrix telt 9.300 regels:
1.493 positieve uitkomsten en 7.807 echte nullen. Bij 161 positieve combinaties
zijn meerdere bronklassen of meetwijzen aanwezig; daarvoor wordt geen
kunstmatige abundantieklasse berekend.

Het soortenhoofdstuk van het rapport noemt Ruig zoutkruid, maar Tabel 4 met de
uitdrukkelijke 75 trendsoorten niet. Positieve records van deze en andere
aanvullende planten blijven bewaard, maar leveren geen nullen. Vervaagde
bronregels dragen alleen bij aan niet-gevoelige routejaaruitkomsten; hun exacte
vindplaatsen blijven buiten de openbare tabellen. De analysemethode uit het
rapport waarbij een ontbrekende meetronde met een eerdere of latere ronde werd
ingevuld, wordt niet overgenomen: de database bewaart uitsluitend uitgevoerde
routejaren.

FLORON heeft op 6 oktober 2026 bevestigd dat Dunea de onderliggende
LMF-A-gegevens beheert en dat FLORON alleen de software als dienst levert. Van
de 7.807 afgeleide nullen horen 4.945 bij de 79 in het rapport bevestigde
routejaren. De overige 2.862 horen bij de 45 alleen uit NDFF afgeleide
routejaren. Voor validatie van die 45 routejaren zijn de primaire Dunea-export,
routeversies en eventuele methodewijzigingen de kortste gegevenslijn.
Een gerichte controle op 7 oktober 2026 van de lokale reposities, documenten,
iCloud-downloads en Zotero vond geen primaire Dunea-export. Alleen het officiële
rapport en algemene methodedocumenten zijn lokaal aanwezig. De resterende
leemte kan daarom alleen rechtstreeks met een bestaande Dunea-export worden
gesloten.

De gerichte plantenprojecten `12.002` en `12.003`, Nectarindex `12.209` en
LMF-A `12.211` zijn doelsoortafhankelijk geclassificeerd. Voor de negen
Nectarindexregels uit één datum en één geometrie is geen lokale trend- of
nulstructuur gemaakt.

Methodische grondslag: [FLORON-rapport LMF-A 1999-2019](https://www.verspreidingsatlas.nl/redactie/pdf/f085962d-9fe4-4c7e-86bf-102fc0d35dea.pdf),
[FLORON kilometerhokinventarisaties](https://www.floron.nl/Meedoen/Kilometerhokken-inventariseren),
[Het Nieuwe Strepen](https://www.floron.nl/meedoen/het-nieuwe-strepen) en
[Nectarindex](https://www.floron.nl/nectarindex). De vier officiële PDF's staan
in Zotero onder parent-item `Meetnetten - FLORON` (`U95RCP8M`).

### HabSlak (`04.006`)

Regelversie `ndff-habslak-v2` groepeert 2.629 onvervaagde openbare records per
kalenderdatum en openbare geometrie tot 251 monsters. Dat levert 1.730
positieve monster-taxoncombinaties voor 51 taxa. Verschillende telonderwerpen,
zoals levende dieren en lege huisjes, blijven afzonderlijke meetwaarden in JSON
en worden niet bij elkaar opgeteld. De oorspronkelijke monster-ID en het
monstertype zijn niet meegeleverd.

De handleiding noemt Nauwe korfslak, Zeggekorfslak en Platte schijfhoren als
doelsoorten, maar in deze Meijendel-selectie is alleen Nauwe korfslak als
doelsoort aangetroffen. De soortprotocollen uit 2014 onderscheiden monitoring
op vaste locaties van verspreidingsonderzoek per 10x10-km-hok. Voor monitoring
zijn per locatie een voorgeschreven monster of meerdere sublocaties nodig. De
NDFF-export bevat geen oorspronkelijke locatie-ID's, monsteromvang,
sublocaties, volledige negatieve locaties of doelbereik per veldformulier.
Daarom zijn alle 66 hok-jaren qua bemonsteringsvolledigheid niet beoordeelbaar.
Alleen positieve Nauwe-korfslakmeldingen bewijzen aanwezigheid; er worden geen
nullen afgeleid. Voor begeleidende soorten wordt afwezigheid evenmin afgeleid.

De 143 vervaagde openbare records blijven traceerbaar in de recordselectie maar
worden niet aan openbare monsters of exacte locaties gekoppeld. Een openbare
positieve doelsoortmelding mag alleen de reeds openbare hokjaarstatus bepalen.
Alle vier afgeleide tabellen staan in `Meijendel`; er is geen nieuwe tabel in
`Meijendel_ndff_secure`. Controleer de laag met `--audit-habslak`.

Methodische grondslag: [NDFF protocol 04.006](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/4-006-slakken-van-de-habitatrichtlijn/),
[ANEMOON HabSlak](https://www.anemoon.org/projecten/natura2000/habslak-protocollen)
en de algemene handleiding plus drie soortprotocollen in Zotero onder
parent-item `Meetnetten - Stichting ANEMOON` (`BPU2U3KE`).

### Braakbalonderzoek (`17.002`)

Regelversie `ndff-braakbal-v1` koppelt alle 389 positieve openbare bronregels
aan 37 geometrie-jaaraggregaten en 226 positieve taxoncombinaties voor veertien
taxa. De aangeleverde aantallen omvatten samen 9.381 prooidieren, waaronder
3.424 Veldmuizen. Herhaalde taxonregels binnen hetzelfde jaar en dezelfde
geometrie worden transparant samengevoegd, maar de som wordt niet als lokale
abundantie geïnterpreteerd.

Van de 389 regels zijn er 387 tot een openbaar 10 x 10 km-vlak vervaagd. De
twee onvervaagde regels betreffen één Mol en één Konijn en vormen geen
volledige braakbalpartij. De bron bevat geen oorspronkelijke partij-, nest- of
locatie-ID's. Daardoor kan één geometrie-jaaraggregaat meerdere partijen en
vindplaatsen omvatten. Achttien aggregaten hebben een som van minimaal 150
prooidieren, maar krijgen juist daarom de voorzichtige status
`som_minimaal_150_partij_onbekend`: de gebruikelijke omvangsdrempel kan niet
aan één oorspronkelijke partij worden toegeschreven.

De laag bevat daarom nul afgeleide nullen en nul SOVON-plotkoppelingen. Zij is
alleen geschikt voor positieve regionale taxonsamenstelling en indicatieve
verandering in registraties, steeds met de ruimtelijke en
partij-onzekerheidsmelding. Alle afgeleide tabellen staan in `Meijendel`; er is
geen braakbalafleiding in `Meijendel_ndff_secure`. Controleer de laag met
`--audit-braakballen`.

Methodische grondslag: [NDFF 17.002](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/17-002-braakbalonderzoek-nem/),
de [methodische rapportage van de Zoogdiervereniging](https://www.zoogdiervereniging.nl/sites/default/files/publications/2009.05%20Verspreidingsonderzoek%20muizen%20en%20spitsmuizen%20in%202008_0.pdf)
en de [CBS-kwaliteitsrapportage NEM 2025](https://longreads.cbs.nl/meetprogrammas-flora-en-fauna-2025/meetprogrammas/).

### Jaarrond Tuintelling (`102.002`)

Regelversie `ndff-tuintelling-v1` verwerkt alle 309 openbare bronregels uit
2015 tot en met 7 maart 2022. De zes openbare geometrieversies vormen bij een
afstandsdrempel van één meter drie tuinvakfamilies. Deze afleiding herkent
kleine geometrieverschuivingen door de jaren heen, maar bewijst geen
oorspronkelijke tuin-ID.

Er zijn 125 telperioden gereconstrueerd: 119 weektellingen, vijf dagperioden en
één tijdstiptelling van vijf minuten. Per telling kiest een deelnemer volgens
het protocol de getelde soortgroepen en meldt daarbinnen alle waargenomen
soorten. De FFV-export bevat de oorspronkelijke keuzevlag niet. Daarom geldt
een soortgroep alleen als geteld wanneer in dezelfde tuinvakfamilie en periode
minstens één positieve regel voor die groep aanwezig is. Dit levert 213
bevestigde periode-soortgroepcombinaties.

Binnen het beperkte doelbereik van 33 taxa die ergens in deze lokale levering
positief zijn aangetroffen, bevat de matrix 1.645 regels: 308 positieve
periode-soortgroep-taxoncombinaties en 1.337
`protocolnul_binnen_lokaal_doelbereik`. De 309e positieve bronregel betreft een
tweede levensstadium van Bruine kikker binnen dezelfde combinatie en blijft als
afzonderlijke meetwaarde behouden. Een voorlopige nul betekent uitsluitend dat
het taxon niet is gemeld binnen een positief bevestigde soortgroeptelling. Zij
geldt niet voor alle landelijke tuinsoorten en niet voor een niet-getelde
soortgroep.

Ruimtelijk vormt de reeks geen Meijendelmeting: 308 bronregels liggen buiten de
SOVON-plots en één regel raakt meerdere plots. Geen telperiode krijgt daarom
een plotkoppeling. Ook bevat de levering geen record na de vernieuwing van de
Jaarrond-Tuintellingwerkwijze in juli 2022. Gebruik de matrix uitsluitend als
regionale tuincontext en niet voor een lokale Meijendeltrend. Alle zes
afgeleide tabellen staan in `Meijendel`; er is geen afleiding in
`Meijendel_ndff_secure`. Controleer met `--audit-tuintellingen`.

Methodische grondslag: [NDFF 102.002](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/102-002-jaarrond-tuintelling/),
[Jaarrond Tuintelling](https://tuintelling.sovon.nl/),
[Sovon over de werkwijze](https://www.sovon.nl/tellen/telprojecten/jaarrond-tuintelling)
en [Sovon over de vernieuwing in 2022](https://www.sovon.nl/actueel/nieuwsberichten/jaarrond-tuintelling-vernieuwd).

### LiveAtlas (`102.005`)

Regelversie `ndff-liveatlas-v1` verwerkt alle 231 openbare bronregels uit 2021
tot en met september 2025. Zij bevatten uitsluitend exacte positieve aantallen:
455 getelde exemplaren van 33 taxa, verdeeld over Dagvlinders en Libellen.
Exact gelijke begin- en eindtijd groeperen de bronregels tot 64 afgeleide
bezoeken. Deze sleutel is reproduceerbaar, maar is geen oorspronkelijk
LiveAtlas-bezoek-ID.

De bezoeken vormen 87 bezoek-soortgroepcombinaties: 53 voor Dagvlinders en 34
voor Libellen. Na samenvoeging van herhaalde taxonregels blijven 169 positieve
bezoek-soortgroep-taxonuitkomsten over. De oorspronkelijke meetwaarden en
recordidentiteiten blijven daarbij in `meetwaarden_json` controleerbaar.

Volgens de LiveAtlas-methode worden route, begin- en eindtijd,
waarnemersinspanning en per soortgroep de keuze compleet of incompleet
vastgelegd. In de FFV-levering ontbreken echter de route, het oorspronkelijke
bezoek-ID, het aantal waarnemers en de complete-lijststatus per soortgroep. De
128 verschillende openbare recordgeometrieën zijn daarom niet als route
gereconstrueerd. Ook worden geen niet-gemelde soorten als nul aangemerkt: alle
169 taxonregels zijn positief en dragen `geen_nul_afleidbaar`.

De bezoekduur ligt voor 23 bezoeken binnen de aanbevolen 15-90 minuten; één
bezoek duurt korter en 40 duren langer. Ruimtelijk zijn 12 bezoeken eenduidig
aan één SOVON-plot gekoppeld omdat alle bijbehorende bronregels volledig binnen
hetzelfde plot liggen. Van de overige bezoeken raken er 35 meerdere plots,
liggen er vijf buiten de plots en hebben twaalf een gemengde status. Ook bij de
12 eenduidige bezoeken bewijst de recordgeometrie niet de volledige route.

Gebruik deze laag voor positieve verspreidingscontext, bezoekintensiteit en
indicatieve verandering van geregistreerde aantallen. Gebruik haar niet als
complete bezoekmatrix en interpreteer een ontbrekend taxon nooit als
afwezigheid. Alle vier afgeleide tabellen staan in `Meijendel`; er is geen
LiveAtlas-afleiding in `Meijendel_ndff_secure`. Controleer met
`--audit-liveatlas`.

Methodische grondslag: [NDFF 102.005](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/102-005-liveatlas/)
en de [Sovon-handleiding LiveAtlas](https://stats.sovon.nl/static/publicaties/Handleiding_LiveAtlas_versieAug2023.pdf).

### Kwartiertellingen (`102.007`)

Regelversie `ndff-kwartiertelling-v1` verwerkt alle 102 openbare bronregels
uit 2023-2025. Zij bevatten exacte positieve aantallen van 19 taxa: 100
dagvlinderregels en twee nachtvlinderregels. Exact gelijke begin- en eindtijd
groeperen de regels tot 17 afgeleide telintervallen. Dit is een reproduceerbare
groepering, geen oorspronkelijk tel-ID.

De intervallen vormen 18 interval-soortgroepcombinaties en 49 positieve
interval-soortgroep-taxonuitkomsten. Herhaalde regels voor hetzelfde taxon
worden opgeteld, terwijl iedere oorspronkelijke meetwaarde en recordidentiteit
in `meetwaarden_json` behouden blijft. Drie intervallen duren korter dan 15
minuten, zeven exact 15 minuten en zeven 16-21 minuten. Korter stoppen is
volgens het protocol mogelijk; duren boven 15 minuten blijven als
`bronafwijking_boven_15_minuten` bewaard voor latere controle en worden niet
automatisch verwijderd.

De oorspronkelijke ButterflyCount-registratie bevat route en getelde tijd en
kan een complete soortenlijst of een soortgerichte telling betreffen. De FFV-
levering bevat route, oorspronkelijk tel-ID en dit lijsttype niet. Daarom zijn
de 87 recordgeometrieën niet tot route samengevoegd en zijn geen nullen
afgeleid. Alle 49 taxonregels zijn positief en dragen
`geen_nul_afleidbaar`.

Veertien intervallen zijn eenduidig aan één SOVON-plot gekoppeld omdat alle
bronregels volledig binnen hetzelfde plot liggen. Eén interval raakt meerdere
plots en twee hebben een gemengde ruimtelijke status. Gebruik deze laag voor
positieve verspreidingscontext, telintervalcontext en indicatieve verandering
in geregistreerde aantallen; gebruik haar niet voor afwezigheid of als
volledige trendmatrix. Alle vier afgeleide tabellen staan in `Meijendel`; er is
geen afleiding in `Meijendel_ndff_secure`. Controleer met
`--audit-kwartiertellingen`.

Methodische grondslag: [NDFF 102.007](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/102-007-kwartiertellingen-dagvlinders-nachtvlinders-libellen-en-sprinkhanen/)
en de [korte handleiding ButterflyCount](https://assets.vlinderstichting.nl/docs/0c3f0890-915f-452f-bbcd-b67b873dc191.pdf).

### Resterende NEM-reeksen (`03.203`, `11.204`, `13.201`, `17.207`)

De laatste vier NEM-protocollen zijn op 13 september 2026 in één transactie
gereconstrueerd. Alle 633 bronrecords hebben precies één recordkoppeling en de
vaste audit vindt geen afgeleide tabel in `Meijendel_ndff_secure`.

| Protocol | Bronrecords | Gereconstrueerde eenheid | Taxonregels | Afgeleide echte nullen |
|---|---:|---|---:|---:|
| `03.203` Nachtvlinders | 596 | 5 openbare geometrie-jaren | 84 positief | 0 |
| `11.204` Bospaddenstoelen | 14 | 2 afgeleide bezoeken | 14 positief | 0 |
| `13.201` Beek- en poldervissen | 20 | 3 waterproxy's, 6 bezoeken | 17 positief + 2 niet gemeld | 0 |
| `17.207` Bever en Otter | 3 | 1 kilometerhok-jaar | 1 positief | 0 |

Bij `03.203` zijn alle openbare regels tot één kilometer vervaagd en op
jaarniveau geleverd. De som 878 wordt daarom alleen als geregistreerd aantal
bewaard. Bij `11.204` blijven de NMV-aantalsklassen intact; omdat de teller
alleen herkende soorten hoeft te melden, is de lijst niet bewezen compleet.
Bij `13.201` is Kleine modderkruiper de lokaal aangetroffen doelsoort. Op twee
bezoeken ontbreekt deze soort, maar zonder submethode en doelbereik heet dat
`doelsoort_niet_gemeld`, niet nul. Bij `17.207` behouden drie positieve
Otterpunten hun recordniveau-plotcontext; het kilometerhok raakt meerdere plots
en ontbrekende Bever bewijst geen afwezigheid.

De tabellen staan onder `Meijendel.ndff_nachtvlinder_*`,
`Meijendel.ndff_bospaddenstoel_verspreiding_*`,
`Meijendel.ndff_poldervis_*` en `Meijendel.ndff_otter_bever_*`. Controleer met
`--audit-resterende-nem`. Protocol `12.202` is bewust niet opnieuw opgebouwd:
de provinciale PQ-reeks blijft de gezaghebbende bron.

Methodische grondslag: [NDFF 03.203](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/3-203-landelijk-meetprogramma-nachtvlinders-nem/),
[NMV-methodiek](https://www.mycologen.nl/onderzoek/meetnet/bospaddenstoelen/methodiek/),
[NDFF 13.201](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/13-201-meetnet-beek-en-poldervissen-nem-3/)
en [NDFF 17.207](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/17-207-verspreidingsonderzoek-bever-en-otter-nem/).

### Gemengde atlas- en verspreidingsleveringen (`04.004` en `07.001`)

Protocol `04.004` bevat 2.237 canonieke molluskenrecords en `07.001` bevat
2.762 libellenrecords. Daarvan zijn respectievelijk 1.282 en 850 records
ruimtelijk bruikbaar voor plotcontext. De ANM-bron combineert
gebiedsinventarisaties met historische, literatuur- en collectieregistraties.
Protocol `07.001` accepteert zowel gebiedsinventarisaties als losse
waarnemingen. De NDFF-levering bevat voor geen van beide protocollen een
onderscheidende lijst-, bezoek- of inspanningssleutel.

Daarom worden geen bezoeken, complete soortenlijsten of nullen gereconstrueerd.
`V` heeft leveringsstatus `voorwaardelijk`. `I` en `TV` behouden hun
protocolmatige kandidaatstatus, maar hebben leveringsstatus `onvoldoende` en
mogen alleen als indicatieve verandering in geregistreerde aanwezigheid worden
berekend. `TA` en `TK` zijn voor deze levering uitgesloten. Aangeleverde
aantallen blijven broninformatie en worden niet over records geaggregeerd.
De 199 openbaar vervaagde `04.004`-records worden niet naar een openbare
afgeleide tabel gekopieerd. De beoordeling is vastgelegd in de bestaande
`ndff_analysebesluit`-regels; er zijn geen kunstmatige bezoekmatrices gebouwd.

Methodische grondslag: [NDFF protocol 04.004](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/4-004-atlasproject-nederlandse-mollusken/)
en [NDFF protocol 07.001](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/7-001-verspreidingsonderzoek-libellen/).

Daarnaast zijn omvangrijke inventarisatiereeksen aanwezig: `03.001` (1.834),
`12.204` (929) en `12.006` (661). Hun omvang maakt ze niet automatisch geschikt
voor aantalstrends.

Aanvullende bronvragen worden pas gesteld wanneer tijd, geometrie en de
officiële protocolomschrijving een noodzakelijke sleutel niet kunnen leveren.
Zij blokkeren de technisch verantwoorde reconstructies niet.

### Ingetrokken bronvragen en vervolgvolgorde

Ton Lansink heeft op 13 september 2026 alle zeven geselecteerde
bronorganisaties per e-mail aangeschreven. Daarbij zijn de in dit traject per
organisatie opgestelde verzoekteksten gebruikt. De verzoeken plaatsen de
aanvullende gegevensvraag in het kader van zeventig jaar vogeltellingen in 2028
en de voorgenomen ecologische geschiedenis van Meijendel. Zij vermelden dat de
relevante NDFF-data, inclusief de geleverde onvervaagde records, al beschikbaar
zijn en dat uitsluitend aanvullende meetstructuur wordt gevraagd voor
statistisch verantwoord gebruik.

| Organisatie | Gebruikt e-mailadres |
|---|---|
| De Vlinderstichting | `meetnet@vlinderstichting.nl` |
| Zoogdiervereniging | `info@zoogdiervereniging.nl` |
| RAVON | `info@ravon.nl` |
| FLORON | `info@floron.nl` |
| BLWG | `henk-jan@blwg.nl` |
| Stichting ANEMOON | `anemoon@cistron.nl` |
| Staatsbosbeheer | `info@staatsbosbeheer.nl` |

Ton Lansink heeft deze zeven verzoeken op 14 september 2026 ingetrokken. Zij
zijn niet langer openstaand en krijgen geen herinnering of vervolgbericht. De
nieuwe vaste volgorde is:

1. eerst de Meijendel-database verbeteren met de informatie die al in de
   openbare en beveiligde NDFF-leveringen en de officiële documentatie staat;
2. daarna exact vaststellen welke gegevens nog ontbreken en NDFF daarover
   gericht bevragen;
3. pas na het NDFF-antwoord beoordelen of voor een specifiek protocol nog een
   kleine, gerichte vraag aan een bronhouder nodig is.

### Actuele status bronvragen op 25 september 2026

Na de verdere vergelijking van de NDFF-leveringen, de lokale database en de
officiële protocollen zijn alle bronorganisaties waarvoor een gerichte
aanvullende gegevensvraag resteerde opnieuw aangeschreven. Deze nieuwe
verzoeken vervangen de op 14 september ingetrokken verzoeken.

De Vlinderstichting heeft bevestigd dat zij verwacht de gevraagde gegevens in
de loop van de week van 28 september 2026 te kunnen leveren. Van de overige
aangeschreven organisaties is op 25 september 2026 nog geen inhoudelijke
reactie ontvangen. Behandel de verzoeken daarom als verzonden en in
afwachting van antwoord; stel geen nieuw verzoek op en stuur geen herinnering
zonder eerst deze actuele correspondentiestatus te controleren.

FLORON heeft op 6 oktober 2026 inhoudelijk geantwoord. De organisatie bevestigt
jaar plus kilometerhok als beschikbare FLORBASE-eenheid en kalenderdag plus
kilometerhok als beschikbare HNS-eenheid. FLORON slaat niet op welke soorten
niet zijn aangetroffen, levert geen persoonsgegevens of afgeleide
waarnemerscodes en verwijst voor LMF-A naar Dunea als gegevensbeheerder. De
`uri` of `identity` uit de NDFF-export is de beschikbare stabiele sleutel per
waarneming. De brede FLORON-bronvraag is daarmee gesloten. Nieuwe vragen aan
FLORON over lijst-ID's, nulwaarnemingen of extra FLORBASE-bezoekmetadata hebben
geen zin.

Een eventuele latere bronlevering wordt vóór iedere databasewijziging op
herkomst, dekking, koppelsleutels, gebruiksvoorwaarden en overlap met NDFF
gecontroleerd.

De eerste databaseverbetering uit deze nieuwe volgorde is op 14 september
uitgevoerd. Voor 14.420 gekoppelde records zijn de bruikbare niet-ruimtelijke
velden uit ticket 58679 opgenomen in
`Meijendel.ndff_open_leveringsverrijking`. De publieke `bronhouder` en de
`dataeigenaar_uri` uit de projectlevering blijven daarbij afzonderlijk. Alle
gekoppelde regels zijn door NDFF als `betrouwbaar` beoordeeld, maar dit
recordoordeel verandert de eerder vastgelegde protocolgeschiktheid en
surveybeperkingen niet.

Er zijn geen fictieve datasets, onderzoeken, bezoeken of sessies aangemaakt.
De velden `zoid` en `sessionid` zijn overal nul en `datm_dkkng` en `opp_dkkng`
overal leeg. De volgende externe stap is daarom een kleine, gerichte vraag aan
NDFF over de werkelijk aanwezige en exporteerbare bovenliggende entiteiten.
Een tweede gerichte vraag betreft de geometrie: 1.828 gekoppelde records met
de openbare vlag `vervaagd=0` hebben toch een andere leveringsgeometrie. Tot de
betekenis daarvan vaststaat, blijft de exacte geometrie beveiligd.

## Reconstructie van de surveystructuur

De GeoPackage bevat niet alle bovenliggende survey-entiteiten die in het
NDFF-gegevensmodel worden onderscheiden. Daarom wordt de database eerst
verbeterd met alle reeds geleverde velden en de officiële documentatie. De
openbare handleidingen van de meetnetbeheerders bepalen het bedoelde ontwerp.
Feitelijke bezoeken worden waar verantwoord uit tijd en geometrische samenhang
gereconstrueerd. Daarna wordt NDFF gericht gevraagd welke ontbrekende dataset-,
onderzoek-, opname-, bezoek- of sessiegegevens beschikbaar en exporteerbaar
zijn. Alleen wat na het NDFF-antwoord noodzakelijk blijft, kan aanleiding zijn
voor een nieuwe, minimale bronhoudervraag.

De 1.274 vervolgkandidaten bestaan uit tien protocol-broncombinaties:

| Protocol | Records | Bronorganisatie | Native telobject | Prioriteit |
|---|---:|---|---|---:|
| Vleermuistransecttelling (NEM) | 572 | Zoogdiervereniging | vaste route/transect | 1 |
| LMF-a | 478 | Dunea en FLORON | vaste looproute in kilometerhok | 1 |
| Slakken van de Habitatrichtlijn | 112 | Stichting ANEMOON | zoek-/proefvlak of monsterlocatie | 2 |
| Monitoring amfibieën (NEM) | 72 | RAVON | telgebied met genummerde wateren | 1 |
| Korstmossen op steen, heiden en stuifzanden | 20 | BLWG | permanent proefvlak | 2 |
| Het Nieuwe Strepen | 12 | FLORON | complete kilometerhokinventarisatie | 3 |
| SNL/N2000-gebiedsmonitoring | 5 | Staatsbosbeheer/opdrachtgever | beheer- of karteringsgebied | 3 |
| Meetnet mossen | 1 | BLWG | geselecteerd kilometerhok | 4 |
| Landelijk Meetnet Vlinders | 1 | De Vlinderstichting | vaste route met secties | 3 |
| RAVON Meetnet Natura 2000 | 1 | RAVON/opdrachtgever | meetpunt, water of traject | 4 |

De prioriteiten in deze tabel zijn inhoudelijke validatieprioriteiten, geen
actieve volgorde voor externe verzoeken. Eerst worden database en NDFF-
gegevensmodel benut. Prioriteit 1 verdient daarna als eerste een gerichte
NDFF-controle. Prioriteit 2 is voorwaardelijk kansrijk. Prioriteit 3 is vooral
bruikbaar binnen het eigen meetnetmodel of voor periodieke toestand. Prioriteit
4 is in deze levering te klein voor een lokale trend, tenzij later een veel
completere reeks beschikbaar blijkt.

Het native telobject blijft altijd leidend. Dat een afzonderlijke NDFF-
waarneming volledig binnen één SOVON-plot ligt, bewijst niet dat de volledige
route, het water, proefvlak, kilometerhok of karteringsgebied binnen dat plot
ligt. Eerst worden telobject en volledige bezoeken gereconstrueerd. Daarna
wordt de geversioneerde relatie met SOVON-plots vastgelegd. Een route of gebied
wordt niet kunstmatig over vogelplots verdeeld zonder sectiegeometrie en
bijbehorende inspanning.

Voor LMF-a noemen openbare bronnen zowel een drie- als vierjarige cyclus. Dat
is een concrete methodebreuk die vóór analyse moet worden opgelost met
protocolversies, routeversies, doelsoortenlijsten en feitelijke bezoeken.

## Uitkomst per soortgroep

| Soortgroep | Records | Doelmeetnet | SNL | PQ-risico | Advies |
|---|---:|---:|---:|---:|---|
| Amfibieen | 12.982 | 2.560 (19,72%) | 0 | 0 | Kansrijk na brondata |
| Dagvlinders | 129.238 | 80.442 (62,24%) | 247 | 0 | Kansrijk na brondata |
| Eencelligen | 156 | 0 | 0 | 0 | Niet opnemen voor trends |
| Geleedpotigen (overig) | 247 | 0 | 0 | 0 | Niet opnemen voor trends |
| Insecten (overig) | 1.888 | 0 | 0 | 0 | Niet opnemen voor trends |
| Kevers | 8.079 | 0 | 0 | 0 | Niet opnemen voor trends |
| Korstmossen | 28.643 | 643 (2,24%) | 461 | 3.273 | Voorwaardelijk; PQ-blokkade |
| Kranswieren, wieren en algen | 555 | 0 | 33 | 14 | Voorwaardelijk; PQ-blokkade |
| Kreeftachtigen | 2.052 | 0 | 0 | 0 | Niet opnemen voor trends |
| Libellen | 32.325 | 3.280 (10,15%) | 278 | 0 | Kansrijk na brondata |
| Microvlinders | 22.849 | 0 | 0 | 0 | Niet opnemen voor trends |
| Mossen | 32.353 | 424 (1,31%) | 9 | 11.395 | Voorwaardelijk; PQ-blokkade |
| Nachtvlinders | 72.978 | 596 (0,82%) | 0 | 0 | Kansrijk na brondata |
| Ongewervelden (overig) | 1.760 | 0 | 0 | 0 | Niet opnemen voor trends |
| Reptielen | 3.347 | 957 (28,59%) | 0 | 0 | Kansrijk na brondata |
| Schimmels | 77.670 | 4.734 (6,10%) | 0 | 0 | Kansrijk na brondata |
| Snavelinsecten | 7.819 | 0 | 0 | 0 | Niet opnemen voor trends |
| Spinachtigen | 2.480 | 0 | 0 | 0 | Niet opnemen voor trends |
| Sprinkhanen en krekels | 9.163 | 0 | 1.468 | 0 | Alleen periodieke gebiedstoestand na SNL-brondata |
| Vaatplanten | 277.812 | 10.549 (3,80%) | 3.777 | 82.636 | Voorwaardelijk; PQ-blokkade |
| Vissen | 1.280 | 46 (3,59%) | 0 | 0 | Kansrijk na brondata |
| Vleermuizen | 9.912 | 6.596 (66,55%) | 0 | 0 | Kansrijk na brondata |
| Vliegen en muggen | 10.495 | 0 | 0 | 0 | Niet opnemen voor trends |
| Vliesvleugeligen | 12.365 | 0 | 0 | 0 | Niet opnemen voor trends |
| Weekdieren | 13.043 | 2.772 (21,25%) | 0 | 0 | Kansrijk na brondata |
| Zoogdieren (overig) | 39.339 | 16.465 (41,85%) | 0 | 0 | Kansrijk na brondata |

`Doelmeetnet` betekent hier uitsluitend: protocol en soortgroep passen bij
elkaar. Het betekent niet dat deze FFV-regels mogen worden geïmporteerd of
geanalyseerd als trend. Een voorbeeld van de soortgroeptoets: 1.535
Vliesvleugeligen zijn geregistreerd binnen het Vlindermeetnet, maar zijn
bijvangst voor die soortgroep en tellen daarom niet als trendmeetnet.

## Toelatingsklassen

1. **Niet opnemen voor trends:** losse waarnemingen, ObsIdentify, iNaturalist,
   collecties, literatuur en atlasgegevens. Bewaar deze alleen in de externe
   staging als verspreidingscontext.
2. **Gestructureerde context:** een inventarisatieprotocol kan aanwezigheid
   ondersteunen, maar zonder volledige bezoeken en inspanning geen afwezigheid,
   detectiekans of populatietrend.
3. **Doelgericht meetnet — brondata opvragen:** vraag volledige telobjecten,
   bezoeken, inspanning, protocolversies, tellingen en nullen op bij de
   beheerder. Controleer daarna lokale dekking en continuiteit.
4. **SNL-gebiedsmonitoring — brondata opvragen:** bruikbaar voor periodieke
   toestand of beheercycli indien de volledige meetronden beschikbaar zijn;
   niet automatisch als jaarlijkse trend.
5. **PQ-overlap eerst uitsluiten:** records uit `12.007 Vegetatieopnamen` en
   `12.202 LMF-M&N` blijven buiten de life-tabellen totdat
   `ndff_pq_koppeling` de bronopname heeft beoordeeld. De door Provincie
   Zuid-Holland aangeleverde PQ-reeks in de life-database is de oorspronkelijke
   en gezaghebbende bron. NDFF-PQ blijft uitsluitend secundair QA-materiaal en
   mag de provinciale reeks nooit aanvullen, wijzigen of dubbel tellen.

De PQ-regel geldt niet alleen voor trendanalyse. Ook bij aanwezigheid,
verspreiding, soortenrijkdom, multivariate analyse en inspanningsmaten mogen
`exact`, `waarschijnlijk_dezelfde_opname`, `mogelijk` en
`niet_beoordeelbaar` niet als zelfstandige NDFF-evidentie naast de bestaande
PQ-opname worden geteld. Iedere analyse controleert en rapporteert daarom de
PQ-status en beslisregelversie.

## Minimale acceptatietoets voor brondata

Een meetnetdeel wordt pas kandidaat voor een `ndff_<soortgroep>`-tabel als alle
volgende punten controleerbaar zijn:

- stabiel telobject en geversioneerde geometrie;
- datum en afzonderlijk bezoek-/sampling-event-ID;
- protocolnaam én protocolversie;
- vastgelegde duur, route/lengte/oppervlakte, methode en apparatuur waar
  relevant;
- complete soortenlijst of expliciet afleidbare nulwaarnemingen;
- telling/schaal die binnen jaren vergelijkbaar is;
- bronhouder, validatiestatus en bekende kwaliteitsbeperkingen;
- voldoende herhaalde telobjecten binnen Meijendel en de gekozen analysetijd;
- eenduidige relatie met de geversioneerde SOVON-plotlaag;
- geen onbeoordeelde PQ-dubbeling, vervaging of meerplot-toewijzing.

Pas daarna volgt per soort en meetnet een dekkingstabel `plot x jaar`, controle
op methodebreuken en een modelkeuze die bij het protocol hoort. Ontbrekende
tellingen worden nooit automatisch als nul of met machine learning ingevuld.

## Geïmplementeerde protocolkwaliteitslaag

De beoordeelde matrix staat tevens in
`docs/bronnen/protocollen/Natuurprotocollen_gebruiksmatrix.xlsx`; de inhoudelijke
onderbouwing staat in
`docs/bronnen/protocollen/Classificatie_natuurprotocollen_wetenschappelijk_gebruik.docx`.
De gebruikte bestanden zijn met SHA-256 vastgezet in de importeur.

Regelversie `ndff-protocolkwaliteit-v1` is lokaal in MySQL toegepast voor de
protocolcatalogus, recordkoppelingen en ruimtelijke beoordeling. De actuele
voorlopige analysebesluiten gebruiken na de doelbereiktoets de afzonderlijke
regelversie `ndff-analysebesluit-v4`; de oorspronkelijke v1-, v2- en v3-besluiten
blijven als historische auditlaag beschikbaar. De laag bevat:

- `ndff_protocol`: 54 gestandaardiseerde protocollen;
- `ndff_protocol_mapping`: 91 gecontroleerde tekstkoppelingen uit openbare en
  beveiligde NDFF-records, zonder ongemapte protocoltekst;
- `ndff_open_waarneming_protocol`: precies één protocolkoppeling voor alle
  810.830 openbare records;
- `Meijendel_ndff_secure.ndff_waarneming_protocol`: precies één
  protocolkoppeling voor alle 14.573 beveiligde records;
- `ndff_protocol_gebruik`: 54 wetenschappelijke gebruiksregels;
- `ndff_protocol_soortgroep_geschiktheid`: 114 doelbereikbesluiten op het
  werkelijk voorkomende protocol-soortgroepniveau;
- `ndff_protocol_soort_geschiktheid`: 620 protocol-taxonbesluiten voor tien
  gemengde combinaties;
- `ndff_open_ruimtelijke_beoordeling`: 810.830 beoordelingen tegen de
  SOVON-plotlaag 2025;
- `ndff_open_pq_koppeling`: 810.830 geversioneerde PQ-poortbesluiten, waarvan
  6.326 historische vegetatiecontext, 90.992 secundaire PQ-controlebron en
  713.512 niet van toepassing;
- `ndff_snl_waarneming_context`: recordgebonden bronoverlapstatus voor de
  6.273 openbare records met protocol `12.205`;
- `ndff_analysebesluit`: 1.040 besluiten per bron, soortgroep, protocol en
  analysetype.

De interne view `Meijendel_ndff_secure.v_ndff_analyse_record` materialiseert
deze regels niet, maar brengt ze bij raadpleging samen tot één analysebesluit
per canonieke waarneming. De livecontrole omvat 810.983 unieke records zonder
ontbrekende protocol-, ruimtelijke, PQ- of gegevensgeschiktheidsstatus. Daarvan
zijn 306.479 voorlopig bruikbaar, 4 voorlopig bruikbaar met een
overlapwaarschuwing, 91.007 uitgesloten via de PQ-poort en 413.493 ruimtelijk
uitgesloten. De 430.263 expliciet losse waarnemingen hebben uitsluitend
kandidaattype `V`. Van de canonieke records behouden 709.109
`gegevensgeschiktheid = niet_beoordeeld`. De 4.999 records onder `04.004` en
`07.001` hebben na leveringsonderzoek de algemene V-status `voorwaardelijk`;
hun I- en TV-besluiten staan afzonderlijk op `onvoldoende`. De view levert een
verplichte `kwaliteitsmelding` en is geen verklaring dat trendgebruik al
volledig is gevalideerd.

Binnen de 6.326 historische vegetatieopnamen uit 1952-1980 zijn 5.179 records
afkomstig van Provincie Zuid-Holland en 1.147 van Alterra. De ruimtelijke poort
laat 3.160 records toe als positieve context; 3.166 records blijven uitgesloten
omdat zij niet eenduidig aan één Meijendel-plot zijn gekoppeld. Geen van deze
records levert een nulwaarneming of een gevalideerde PQ-trend.

Acht andere bronprotocollen zijn voor de huidige NDFF-levering expliciet als
uitsluitend positieve registratiebron beoordeeld: `12.004` (6.864 openbare
records), `12.006` (10.670), `17.005` (79), `17.006` (36), `102.004` (178),
`102.006` (73.844), `104.000` (382) en `105.000` (3.754). Samen betreft dit
95.807 openbare bronrecords en 95.844 canonieke records na toepassing van de
beveiligde vervangingslaag. De broncode blijft als `protocol_sleutel` behouden
met bewijsmethode `expliciete_code`; deze regels worden niet tot `LOS`
omgecodeerd. `V` is `voorwaardelijk` en `voorlopig_toegelaten`; `I`, `TV`,
`TA` en `TK` zijn `onvoldoende` en `uitgesloten_huidige_levering`. De reden is
dat deze leveringen geen complete bezoeken, onderzoeksinspanning, volledige
soortenlijst of afleidbare nullen bevatten. De classificatie zegt dus iets
over verantwoord gebruik van de levering en wist de historische bronbetekenis
niet uit.

De afzonderlijke beoordeling van de resterende gestructureerde protocollen
omvat 1.031 records: `17.002` Braakbalonderzoek (389), `102.002` Jaarrond
Tuintelling (309), `102.005` LiveAtlas (231) en `102.007` Kwartiertellingen
(102). De braakbalregels zijn inmiddels conservatief gereconstrueerd tot 37
geometrie-jaaraggregaten; deze zijn uitdrukkelijk geen partijen of bezoeken en
leveren geen nullen of plotkoppelingen. De tuintelling is inmiddels
gereconstrueerd tot 125 telperioden binnen drie afgeleide tuinvakfamilies, met
voorlopige nullen uitsluitend binnen positief bevestigde soortgroepen en lokaal
doelbereik. LiveAtlas is inmiddels gereconstrueerd tot 64 afgeleide bezoeken,
87 bezoek-soortgroepcombinaties en 169 uitsluitend positieve taxonuitkomsten.
De kwartiertellingen zijn gereconstrueerd tot 17 afgeleide telintervallen, 18
interval-soortgroepcombinaties en 49 uitsluitend positieve taxonuitkomsten. Bij
beide ontbreken route-ID en complete-lijststatus in FFV; NDFF vermeldt voor
`102.007` bovendien expliciet dat de routegegevens nog niet worden meegeleverd.

Daarom is `V` voor alle vier voorwaardelijk toegestaan. Voor `17.002` is
alleen `TV` indicatief toegestaan; voor `102.002`, `102.005` en `102.007` zijn
`I` en `TV` indicatief toegestaan. Indicatief betekent hier verandering in
geregistreerde tellingen met `gegevensgeschiktheid='onvoldoende'`, niet een
gevalideerde populatietrend. `TA` en `TK` zijn uitgesloten en voor `17.002`
geldt dat ook voor `I`. Voor LiveAtlas en Kwartiertellingen worden geen nullen
afgeleid. Na de
ruimtelijke en PQ-poorten blijven 13 braakbalrecords, 77 LiveAtlas-records en
95 kwartiertellingrecords over; alle 309 tuintellingrecords zijn ruimtelijk
uitgesloten voor een eenduidige Meijendel-plotanalyse.

Methodische grondslag: [NDFF 17.002](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/17-002-braakbalonderzoek-nem/),
[NDFF 102.002](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/102-002-jaarrond-tuintelling/),
[NDFF 102.005](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/102-005-liveatlas/),
[NDFF 102.007](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/102-007-kwartiertellingen-dagvlinders-nachtvlinders-libellen-en-sprinkhanen/)
en de [CBS-kwaliteitsrapportage NEM 2025](https://longreads.cbs.nl/meetprogrammas-flora-en-fauna-2025/meetprogrammas/).

Voor praktisch gebruik zijn twee verder geaggregeerde interne views gebouwd.
`v_ndff_verspreiding_plot_jaar_taxon` bevat 106.855 positieve
plot-jaar-taxonsignalen uit 306.466 voorlopig bruikbare bronrecords.
`v_ndff_trendkandidaat_plot_jaar_taxon` bevat 10.855
plot-jaar-taxon-protocolcombinaties uit 65.464 bronrecords met minimaal één
protocolmatige kandidaatmogelijkheid buiten `V`. Zij blijven een prioriteiten-
en selectielaag, geen berekende trend; per analysetype is
`ndff_analysebesluit` leidend voor de leveringsstatus. De dagvlindercontrole vond
binnen de kandidaatview 5.161 combinaties voor protocollen `03.001`, `03.201`,
`102.005` en `102.007`; protocol `LOS` komt er nul keer in voor.

De aanvullende view `v_ndff_gebruiksdekking_soortgroep_protocol` maakt de
selectiestatus direct raadpleegbaar voor 142 combinaties van 28 soortgroepen en
54 protocollen. De som van alle statuskolommen sluit per combinatie en over het
geheel exact aan op 810.983 canonieke records. Er zijn 306.479 voorlopig
bruikbare V-kandidaten, 6.133 I-kandidaten, 60.015 TV-kandidaten, 57.605
TA-kandidaten en 4.727 TK-kandidaten. Deze aantallen mogen worden gecombineerd
in selecties, maar niet worden opgeteld omdat één record meerdere kandidaattypen
kan ondersteunen. Voor alle records blijft aanvullende gegevensvalidatie
wenselijk.

De vier aanvullende jaarniveau-views maken stap 3 compleet. De
soortenrijkdoms- en dekkingsviews bevatten beide 12.640 sluitend vergelijkbare
plot-jaar-soortgroepregels; zij omvatten 106.855 positieve taxonsignalen en
306.466 bronrecords. Daarvan zijn 201.372 records losse waarnemingen en 105.094
protocolgebonden. De eerste/laatste-view bevat 42.934 plot-taxonreeksen. De
verspreidingsveranderingsview bevat 33.356 taxon-jaarregels. Van de mogelijke
jaarvergelijkingen springen 8.344 over minstens één ontbrekend jaar; die zijn
expliciet gemarkeerd met `aansluitend_jaar = 0` en mogen niet als jaar-op-jaar
worden gerapporteerd. Alle views beschrijven geregistreerde positieve
aanwezigheid en produceren geen nulwaarnemingen.

## Formele gereedstatus analyseketen

De lokale databaseketen is op 11 september 2026 vastgezet als
`ndff-analyseketen-v1`. De reproduceerbare eindaudit controleert in één opdracht
de canonieke representaties, dubbele sleutels, verplichte velden,
recordstatussen, alle afgeleide viewtotalen, tijdsaansluitingen en ongewenste
grants:

```bash
python3 gis/scripts/import_ndff_protocolkwaliteit.py --audit-live
```

De gecontroleerde audit slaagt met 810.983 unieke canonieke records, nul
dubbelen, nul ontbrekende kernstatussen, nul afwijkende ketenversies en nul
grants op de nieuwe interne views voor gewone of Shiny-accounts. Daarmee is de
keten gereed voor verkennende analyses van geregistreerde aanwezigheid en
verspreiding. Ook verkennende berekeningen van verandering, meldingsintensiteit
en associaties met beheer zijn toegestaan wanneer de selectieregels en
kwaliteitsmelding zichtbaar blijven. Zonder aanvullende bron- en
surveyvalidatie worden de resultaten niet gepresenteerd als een gevalideerde
populatietrend, abundantie, afwezigheid of causaal beheereffect. De afzonderlijke
validatiefase is nodig om te bepalen welke kandidaten later wel zo kunnen worden
gebruikt.

### Doelsoorten en bijvangsten

De 114 werkelijk voorkomende openbare combinaties van een gecodeerd protocol
en een FFV-soortgroep zijn onder `ndff-protocolbereik-v2` volledig beoordeeld:

- 53 combinaties (`268.538` records) vallen als geheel binnen de doelgroep;
- 3 combinaties (`623` records) zijn bijvangst: Nachtvlinders binnen `03.201`,
  overige zoogdieren binnen vogelprotocol `14.204`, en Vleermuizen binnen
  DAZ-BMP `17.204`;
- 37 combinaties (`78.158` records) zijn algemene bron-, literatuur-,
  collectie- of appregistraties en ondersteunen alleen `V`;
- 11 combinaties (`6.673` records) gebruiken een beperkte of
  projectspecifieke doelsoortenafbakening die niet per NDFF-record is
  meegeleverd; ook daar is voorlopig alleen `V` toegestaan;
- 10 combinaties (`26.672` records) zijn gemengd en zijn daarom ook per taxon
  beoordeeld.

Binnen de tien gemengde combinaties zijn 620 aanwezige
protocol-taxoncombinaties vastgelegd: 70 doelsoortbesluiten met samen 19.447
records, 549 bijvangstbesluiten met samen 7.221 records en één taxonomisch
onbepaald besluit met 4 records. Die laatste categorie betreft
`Plecotus auritus/austriacus`: de naam omvat zowel een doelsoort als een
niet-doelsoort van de zoldertelling en ondersteunt daarom alleen `V`.
Deze soortindeling staat in
`ndff_protocol_soort_geschiktheid`; de groepsindeling staat in
`ndff_protocol_soortgroep_geschiktheid`.

### Uitwerking van doelsoortafhankelijke en gemengde combinaties

De officiële protocolbronnen leveren de volgende beslissingen op:

| Protocol en soortgroep | Besluit v2 | Vastgestelde doelafbakening |
|---|---|---|
| `02.204` Mossen | doelgroep | Het gekozen kilometerhok wordt zo volledig mogelijk op mossen geïnventariseerd; alle gemelde mossen vallen binnen het doelbereik. |
| `04.006` Weekdieren | gemengd | Nauwe korfslak (`Vertigo angustior`), Zeggekorfslak (`V. moulinsiana`) en Platte schijfhoren (`Anisus vorticulus`); overige weekdieren zijn bijvangst. |
| `10.002` Amfibieën | blijft afhankelijk | eDNA is een techniek; de doelsoort volgt uit het project of de gebruikte assay en ontbreekt in de levering. |
| `11.201` Schimmels | gemengd | De officiële historische lijst omvat 110 telsoorten. Van de aangetroffen taxa zijn 49 gecontroleerd aan die lijst gekoppeld; `Fungi sp. indet.` is geen doelsoort. |
| `11.202` Schimmels | gemengd | Duinfranjehoed, Zeeduinchampignon, Duinstinkzwam, Duinveldridderzwam, Helmharpoenzwam en Zandtulpje; overige schimmels zijn begeleidende soorten/bijvangst. |
| `12.015` Vaatplanten en Kranswieren, wieren en algen | blijft afhankelijk | De karteerlijst wordt per Staatsbosbeheer-opdracht vastgesteld. De concrete lijst en opdrachtbegrenzing ontbreken in de NDFF-regels; alle 1.083 records ondersteunen daarom voorlopig alleen positieve voorkomensinformatie (`V`). |
| `12.205` zeven soortgroepen | blijft afhankelijk | Kwalificerende soorten verschillen per SNL-beheertype en versie. Beheertype en versie ontbreken in de records. |
| `13.201` Vissen | gemengd | Beekprik, beekdonderpad, bittervoorn, grote en kleine modderkruiper, rivierdonderpad en rivierprik; overige vissen zijn bijvangst. |
| `13.202` Amfibieën en Vissen | gemengd | Kamsalamander, beekprik, rivierdonderpad, bittervoorn, kleine en grote modderkruiper; andere amfibieën en vissen zijn bijvangst. |
| `17.202` Vleermuizen | gemengd | Voor populatietrend zijn Ingekorven vleermuis en Grijze grootoorvleermuis doelsoort; overige zolderwaarnemingen zijn verspreidingsinformatie. |
| `17.505` en `17.506` Vleermuizen | blijft afhankelijk | Doelsoort en onderzochte functie volgen uit het projectplan; de protocolcode alleen legt die niet vast. |

In de actuele classificatie blijven zestien combinaties bewust
`doelsoortafhankelijk`. Dit betreft geen algemene twijfel over de protocollen,
maar ontbrekende context van de concrete opdracht, het beheertype of het
project. Gokken op basis van de aangetroffen soort is niet toegestaan.

Voor Staatsbosbeheer is een openbaar praktijkrapport gevonden waarin de
soortkartering met een vooraf vastgestelde, per opdracht aangevulde soortenlijst
en Tansley Plus/SBB-abundantieklassen wordt beschreven. Dat sluit aan op de
methoden in de Meijendel-records, maar bewijst niet welke lijst en begrenzing in
Meijendel zijn gebruikt. Voor SNL is BIJ12 de beheerder van de landelijke
werkwijze; Staatsbosbeheer is in de levering hoofdzakelijk bronhouder of
uitvoerder. Die twee protocollen worden daarom niet samengevoegd.

### SNL is context, geen automatische onafhankelijke bron

SNL staat voor Subsidiestelsel Natuur en Landschap. Kwalificerende soorten
worden gebruikt bij beoordeling van natuurkwaliteit en kunnen mede relevant
zijn voor subsidiëring. Protocolcode `12.205` bewijst daarom niet dat een record
uit een zelfstandige inventarisatie komt; dezelfde onderliggende waarneming kan
ook onder een andere bron of protocolregistratie voorkomen.

Regelversie `ndff-snl-overlap-v1` gebruikt vier statussen:

- `overlap_bevestigd`: dezelfde onderliggende waarneming is met bewijs
  vastgesteld; niet zelfstandig meetellen;
- `overlap_mogelijk`: dezelfde soort, exacte starttijd en openbare geometrie
  komen ook onder een ander protocol voor; handmatige of broncontrole nodig;
- `geen_overlap_gevonden`: binnen deze toets is geen kandidaat gevonden, maar
  onafhankelijkheid is niet bewezen;
- `onvoldoende_onderzocht`: de noodzakelijke sleutelvelden of toetsing
  ontbreken.

Een bevestigde onafhankelijke inventarisatie vergt aanvullende herkomst-,
bezoek- of telronde-informatie en wordt daarom niet als vijfde automatische
status ingevoerd.

De eerste toepassing op alle 6.273 SNL-records leverde 97 keer
`overlap_mogelijk` en 6.176 keer `geen_overlap_gevonden` op. Er zijn nog geen
records als `overlap_bevestigd` aangemerkt en geen record kreeg
`onvoldoende_onderzocht`. De mogelijke matches zijn kandidaten voor nadere
controle en worden niet automatisch als dubbel verwijderd.

Gebruikte primaire bronnen zijn onder meer [BLWG Meetnet Mossen](https://www.verspreidingsatlas.nl/projecten/blwg/meetnetmossen.aspx),
[ANEMOON HabSlak](https://www.anemoon.org/projecten/natura2000/habslak-protocollen),
[NDFF-protocollen](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/),
[RAVON Natura 2000](https://www.ravon.nl/publicaties/handleiding-meetnet-amfibieen-en-vissen-in-natura-2000-gebieden/),
[BIJ12 SNL](https://www.bij12.nl/onderwerp/natuurinformatie/monitoring-en-natuurinformatie/werkwijze-monitoring-beoordeling-natuurnetwerk-natura-2000/)
en de handleidingen van NMV en Zoogdiervereniging in de protocoldocumentatie.

Voor niet-V-analyses gelden hierdoor drie verschillende uitkomsten:

- `voorlopig_toegelaten`: de gehele soortgroep valt binnen het doelbereik;
- `alleen_na_doelsoortselectie`: gebruik uitsluitend expliciet geregistreerde
  doelsoorten uit de soorttabel;
- `wacht_op_doelsoortafbakening`: de doelstatus is nog niet uit het record of
  een voldoende specifieke bronlijst afleidbaar; alleen `V` is nu bruikbaar.

Deze doelbereiktoets vervangt de leveringsvalidatie niet.
`Gegevensgeschiktheid` blijft per v4-besluit `niet_beoordeeld` totdat het
betreffende protocol is onderzocht. Voor `04.004` en `07.001` is die beoordeling
inmiddels vastgelegd; de kwaliteitsmelding blijft verplicht bij iedere uitkomst.

De recordkoppelingen gebruiken `protocol_id` uitsluitend als interne foreign
key. `protocol_sleutel` blijft de stabiele identificatie. Van de openbare
records hebben 380.664 bewijsmethode `expliciete_code` en 430.166
`expliciet_losse_waarneming`; bij de beveiligde records zijn dit respectievelijk
4.913 en 9.660. De laatste categorie verwijst naar sleutel `LOS` en is geen
onderzoeksprotocol. De import blokkeert lege protocolwaarden in plaats van deze
stilzwijgend als losse waarneming te classificeren. `analyse_status` is geen
protocolstatus; wetenschappelijke toelating blijft uitsluitend via de aparte
analysebesluiten, ruimtelijke toets en PQ-poort verlopen.

Van de openbare records zijn 365.854 onvervaagde geometrieën volledig binnen
precies één plot gelegen. Dit is uitsluitend een ruimtelijke toelatingsvoorwaarde
voor positieve verspreidingscontext. `Single_deels`, `multiple`, `outside` en
alle vervaagde geometrieën zijn ruimtelijk geblokkeerd. De PQ-poort blijft een
afzonderlijke verplichte voorwaarde. Protocolmatig passende besluiten voor
inventarisatie, verspreidingstrend, aantalsindex en kwaliteitstrend zijn
`voorlopig_toegelaten`. Zij mogen verkennend worden gebruikt, met de verplichte
melding dat leveringsgeschiktheid en verdere validatie nog niet zijn beoordeeld.
Niet-onderbouwde protocol–analysetypecombinaties blijven uitgesloten.

Het schema en de reproduceerbare invoer staan in:

- `gis/database/ndff_protocolkwaliteit_schema.sql`;
- `gis/database/ndff_protocolkwaliteit_seed.csv`;
- `gis/scripts/build_ndff_protocolkwaliteit_seed.py`;
- `gis/scripts/import_ndff_protocolkwaliteit.py`;
- `gis/scripts/test_ndff_protocolkwaliteit.py`.

## Reproduceerbare bestanden

- script: `gis/scripts/analyse_ndff_protocollen.py`;
- rapport: `/Volumes/T7 Data/Home_Ton/Meijendel data/NDFF/open_ffv/reports/ndff_protocolaudit_1950_2025/ndff_protocolaudit_meijendel_1950_2025.html`;
- soortgroepsamenvatting: dezelfde map, `ndff_protocolaudit_soortgroepen.csv`;
- volledige protocolmatrix: dezelfde map, `ndff_protocolaudit_protocolmatrix.csv`;
- alle berekeningen en bronnen: dezelfde map, `ndff_protocolaudit_resultaten.json`.

## Officiële methodische bronnen

- [NDFF Protocollen](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/)
- [NDFF Bijsluiter](https://ndff.nl/natuurdata/bijsluiter/)
- [NDFF Flora- en Faunaverkenner](https://ndff.nl/natuurdata/afnemen-en-gebruiken/flora-fauna-verkenner/)
- [NDFF Vegetatieopname](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/12-007-vegetatieopname/)
- [NDFF LMF-M&N](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/12-202-landelijk-meetnet-flora-milieu-en-natuurkwaliteit/)
- [NDFF LMF-a](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/12-211-landelijk-meetnet-flora-aandachtssoorten-lmf-a/)
- [CBS Kwaliteitsrapportage NEM 2025](https://longreads.cbs.nl/meetprogrammas-flora-en-fauna-2025/meetprogrammas/)
- [CBS methode kwaliteitsbeoordeling](https://longreads.cbs.nl/meetprogrammas-flora-en-fauna-2025/kwaliteitsbeoordeling/)
- [Netwerk Ecologische Monitoring - kwaliteit](https://www.netwerkecologischemonitoring.nl/)
- [NDFF 03.201 Landelijk Meetnet Dagvlinders](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/3-201-landelijk-meetnet-vlinders-nem/)
- [NDFF 07.201 Landelijk Meetnet Libellen](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/7-201-landelijk-meetnet-libellen-nem/)
- [NDFF 03.203 Landelijk Meetprogramma Nachtvlinders](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/3-203-landelijk-meetprogramma-nachtvlinders-nem/)
- [Zoogdiervereniging Vleermuistransecttelling](https://www.zoogdiervereniging.nl/sites/default/files/2024-10/Handleiding%20Vleermuis%20transecttellingen.pdf)
- [FLORON Het Nieuwe Strepen](https://www.floron.nl/meedoen/het-nieuwe-strepen)
- [RAVON monitoring amfibieën](https://www.ravon.nl/publicaties/handleiding-voor-het-monitoren-van-amfibieen-in-nederland/)
- [RAVON Meetnet Natura 2000](https://www.ravon.nl/publicaties/handleiding-meetnet-amfibieen-en-vissen-in-natura-2000-gebieden/)
- [ANEMOON HabSlak-protocollen](https://www.anemoon.org/projecten/natura2000/habslak-protocollen)
- [BLWG Meetnet korstmossen](https://www.blwg.nl/meetnet-korstmossen-in-stuifzanden-nem)
- [De Vlinderstichting vlinderroute](https://vlinderstichting.nl/wat-kan-jij-doen/tellen/meetnetten/een-route-tellen/vlinderroute-tellen/)
- [BIJ12 Werkwijze Monitoring en Beoordeling Natuurkwaliteit](https://www.bij12.nl/wp-content/uploads/2023/11/WW-00-TEXT-%E2%80%93-Monitoring-en-Beoordeling-Natuurkwaliteit-EHS-en-Natura-2000.pdf)


## Konijnenuitzet en primaire BMP/DAZ-waarnemingen

**Eerste analyse; aangevuld en op onderdelen gecorrigeerd door de sectie `Heranalyse met alle konijnenbronnen` hieronder. Gebruik die heranalyse voor de actuele conclusie.**

Stand: 20 oktober 2026. Opdracht: de vier door Amy van Nobelen (Dunea) opgegeven uitzethokken vastleggen als maatregel; historische en recente konijnenregistraties tijdens BMP-rondes vergelijken; aanvullende informatie benoemen. Alleen de levende lokale database is gewijzigd. Geen nieuwe waarnemingen of nullen, geen export, cachebouw of VPS-publicatie.

### Broncontrole en ruimtelijke keuze

Gecontroleerd zijn de door Ton gedeelde mail, de levende maatregel-, namen-, plot-, taxon-, BMP- en AVIMAP-tabellen, het bronregister, de bestaande protocolaudit, de lokale Zotero-catalogus (zoektermen konijnen en bijplaats), de officiële ODH-beschikking van 28 augustus 2023 inclusief activiteitenplan en de Dunea-jaarverslagen 2023 en 2024. De Zotero-catalogus levert vijf treffers op konijnen, waaronder het werkprotocol uit 2022 en historische publicaties uit 1976, 1990, 1991 en 2003, en nul treffers op bijplaats. Deze metadata bevatten geen uitzetlogboek voor de vier actuele hokken. Er is geen bijlage van externe opslag geopend en geen externe vraag verzonden. De mail heeft geen zichtbare verzenddatum; 20 oktober 2026 is de datum waarop Ton deze deelde, geen uitzetdatum.

De vier aangeleverde Google Maps-links zijn gevolgd. Hun bestemmingen bevatten WGS84-coördinaten. Na transformatie naar EPSG:28992 liggen beide A-punten binnen de actuele SOVON-kavel M7 en beide B-punten binnen M45. De kaveltoets gebruikt `v_meijendel_sovon_plot_actueel` en de Natura 2000-selectie `v_meijendel_analyseplot_actueel`. M66 en M91 zijn niet opgenomen. De feitelijke punten vervangen geen bestaande gebiedspolygonen.

| Hok | Bronlabel | Breedtegraad | Lengtegraad | Kavel |
|---|---|---:|---:|---|
| A1 | Kijfhoek/Bierlap hok 1 | 52.142559 | 4.349128 | M7 |
| A2 | Kijfhoek/Bierlap hok 2 | 52.142481 | 4.348571 | M7 |
| B1 | Loopert hok 1 | 52.117861 | 4.320931 | M45 |
| B2 | Loopert hok 2 | 52.118227 | 4.321215 | M45 |

Bronlinks: [A1](https://maps.app.goo.gl/wTQRMm2JxG6xc1BP7), [A2](https://maps.app.goo.gl/8fZN9degfhhAJpBB7), [B1](https://maps.app.goo.gl/Bf8PTHbFBp7WbBnb8), [B2](https://maps.app.goo.gl/hv1cdD9n2C2ynKSU6).

De controle omvat alle 183 objecten van het levende namenregister. Kleine Pan en De Loopert zijn onderbouwde namen met polygonen; de vier hokken liggen daarbuiten: A1 en A2 op 172,8 en 202,2 meter van Kleine Pan, B1 en B2 op 102,7 en 145,8 meter van De Loopert. De Kijfhoek- en Bierlap-polygonen bevatten de A-punten evenmin. Loopert is bovendien afzonderlijk geregistreerd als historische naam zonder geometrie. Waterschaps-vallei ontbreekt als afzonderlijk object in het register, maar is een bewezen planlabel in het activiteitenplan. De ODH-kaarten op PDF-pagina 13 en 14 zijn visueel bekeken. Namen uit een plan en namen uit de mail mogen daarom niet automatisch als geometrisch gelijk worden behandeld. De kleinste resterende vraag is hoe de vier feitelijke hokken zich verhouden tot de planlocaties en of hokken zijn verplaatst. De bestaande naampolygonen zijn niet gewijzigd of als fout bestempeld.

Het [Dunea-jaarverslag 2023](https://www.dunea.nl/over-dunea/-/media/bestanden/over-dunea/jaarberichten/dunea-jaarverslag-2023.pdf), gedrukte p. 37, bevestigt eerste overplaatsingen in oktober 2023. Dit corrigeert de eerdere conclusie dat uitzetting pas in 2024 begon. Het jaarverslag noemt geen aantal en geen individueel hok. Het [jaarverslag 2024](https://www.dunea.nl/duinen/-/media/bestanden/over-dunea/jaarberichten/dunea-jaarverslag-2024.pdf) meldt eveneens een gestarte pilot en monitoring. Het [ODH-activiteitenplan](https://omgevingsdiensthaaglanden.nl/wp-content/uploads/besluiten/2023/08/30/4e5424ce-bc9f-42ce-870f-1a146507f6d1/Besluit%20op%20aanvraag%2001069060-ODH701135.pdf) noemt in het plan voor oktober 2023 en januari 2024 telkens 20–40 konijnen en mogelijke herhaling in 2024 en 2025. Deze getallen zijn plannen, geen uitgevoerde aantallen. Ook de letterlijke formulering afgelopen vier jaar uit de mail wordt niet automatisch in vier uitvoeringsjaren vertaald.

### Registratie in de levende database

De bestaande uitvoering `konijnen_bijplaatsing_2024_2026` en de onderbouwde jaarregel 2024 zijn behouden. Haar oude M8/M41-relaties zijn met de eerdere bewijsnotities bewaard als `te_beoordelen`; ze leveren geen geverifieerde plot-jaarrij meer. De actuele punten behoren tot de nieuwe uitvoering `konijnen_feitelijke_hokken_20261020`, onder hetzelfde bestaande project. Die heeft vier puntgeometrieën en twee geverifieerde kavelrelaties, maar geen uitzetdatum, hoeveelheid of jaarregel. Daardoor projecteert de jaarview de huidige hokken niet terug naar onbewezen historische jaren. Het project vermeldt de vanaf oktober 2023 bevestigde programmabrede uitvoering. Een concrete locatie per uitzetmoment blijft onbewezen.

De bestaande seed `gis/database/maatregelen_seed.sql` bevat de herhaalbare aanvulling. Uitvoering gebeurde in één transactie met controles op uitgangsaantallen, kavelkoppeling en eindtotalen. Alleen de betrokken maatregeltabellen zijn vooraf geback-upt: `~/.codex/backups/meijendel/2026-10-20-konijnen/vooraf.sql`, SHA256 `37f623f0fed40a58203eb534428167add80a8d3b5513d619c502e19f0c0e51d3`.

De actuele laag telt 22 projecten, 91 uitvoeringen, 132 jaarregels, 55 bronnen, 132 uitvoering-bronrelaties, 261 kavelrelaties waarvan 256 geverifieerd, zeven geometrieën en 355 bronvaste plot-jaarrijen. Vóór de aanvulling waren dat respectievelijk 22, 90, 132, 53, 129, 259, 256, drie en 357. De daling van twee plot-jaarrijen volgt uit de herbeoordeling van M8/M41; er zijn geen oorspronkelijke regels verwijderd.

Toetsingsbasis, geraadpleegd op 20 oktober 2026: [Darwin Core](https://dwc.tdwg.org/terms/) en [TDWG TCS](https://tcs.tdwg.org/terms/). De uitzetmaatregel is een beheerhandeling, geen soortwaarneming of taxonconcept. Bronidentiteit en bronlabel blijven apart van locatie-identiteit. De puntpositie sluit aan bij decimalLatitude/decimalLongitude, geodeticDatum en georeferenceRemarks; de transformatie en ontbrekende precisie blijven expliciet. Er is geen schema, taxonidentiteit of waarnemingsstatus gewijzigd en er is geen nieuwe afwijking van de canonieke importbasis ingevoerd. De databasebrede centrale taxonpoort controleerde vóór én na de wijziging 128 routes. De aparte historische DAZ-audit slaagt met nul ongeldige matrixregels; de 7.552 historische afgeleide nulregels blijven uitsluitend auditspoor en zijn niet in deze analyse gebruikt. Beide bronregisterversies zijn inhoudelijk gelijk bijgewerkt, alle 55 gerenderde pagina’s zijn in overzicht gecontroleerd en de gewijzigde pagina’s 29, 33 en 34 afzonderlijk bekeken. Het bestaande seedcontract slaagt inclusief herhaalbaarheid, vier puntgeometrieën en blokkering van onbewezen jaarprojectie. Een eerste proef vond dat brontype handmatige_registratie wel in de levende database maar niet in een verse seed aanwezig was; de aanvulling registreert dit bestaande type nu met hetzelfde patroon als de eerdere beheermigratie. Er is geen nieuw brontype bedacht.

### Historische en recente tellingen

Primaire bron: actuele batch 1, `sovon-avimap-252-v1`, ontvangen 13 september 2026. Uitkomsten volgen `v_sovon_avimap_daz_analyse` en reconstructieversie `sovon-avimap-daz-v1`. De kwaliteit blijft `voorwaardelijk`: een echte nul geldt alleen binnen een door een zoogdierregel bevestigd DAZ-bezoek en voor de zeven doelsoorten. Geheel negatieve zoogdierbezoeken kunnen in deze bronselectie ontbreken. De som van tellingen is een som van waargenomen dieren over bezoeken; dezelfde dieren kunnen vaker zijn gezien. Zij is geen aantal unieke dieren, populatieomvang of bewezen trend. De huidige kavelgrenzen bepalen welke kavels hier worden besproken; een historische BMP-plotcode bewijst niet dat ieder vroeg bezoek exact dezelfde voetafdruk had.

BMP-rondes zijn afzonderlijk geteld in `dagbezoeken_bmp` en op bezoek-ID, plot-ID en datum vergeleken. In M7 staan voor 1984–2008 238 historische BMP-rondes; in M45 voor 1986–2008 140. Dit bewijst vogelbezoeken, geen deelname aan zoogdiertellingen. De secundaire reconstructie bevat voor M7 in 2006 drie bevestigde DAZ-bezoeken met vier positieve zoogdierbronregels en in 2008 één bezoek met één zoogdierregel. Daaronder staan twee konijnenmeldingen met elk aantal één: 26 mei en 19 juni 2006, NDFF-ID 655300 en 655310, eenduidig gekoppeld aan een BMP-bezoek. Zij worden uitsluitend als historische positieve aanwezigheid gebruikt. Voor M45 is in deze reconstructie vóór 2009 geen bevestigd DAZ-bezoek gevonden; dat is geen bewijs van afwezigheid. De secundaire bron is `ndff-daz-bmp-v1`, met vervangingscontrole tegen de actuele SOVON-koppeling. Er zijn geen historische nullen afgeleid of als afwezigheid gebruikt.

De primaire SOVON-reeks bevat voor M7 vóór 1 oktober 2023 116 bevestigde DAZ-bezoeken met een telsom van 199 konijnen over 2010–2023. Voor M45 zijn dat 41 bezoeken met telsom negen over 2017–2023. In 2009 heeft geen van beide kavels een bevestigd zoogdierbezoek in deze primaire selectie. De volledige primaire jaarlijkse uitkomsten staan hieronder; een streep betekent dat zoogdierdeelname niet is bevestigd.

| Jaar | M7: bevestigde DAZ-bezoeken | M7: telsom konijn | M45: bevestigde DAZ-bezoeken | M45: telsom konijn |
|---|---:|---:|---:|---:|
| 2009 | — | — | — | — |
| 2010 | 4 | 18 | — | — |
| 2011 | 11 | 7 | — | — |
| 2012 | 7 | 9 | — | — |
| 2013 | 8 | 18 | — | — |
| 2014 | 2 | 0 | — | — |
| 2015 | 11 | 63 | — | — |
| 2016 | 11 | 38 | — | — |
| 2017 | 9 | 22 | 1 | 0 |
| 2018 | 10 | 12 | — | — |
| 2019 | 9 | 10 | 8 | 6 |
| 2020 | 8 | 1 | 8 | 3 |
| 2021 | 10 | 1 | 7 | 0 |
| 2022 | 6 | 0 | 8 | 0 |
| 2023 | 10 | 0 | 9 | 0 |
| 2024 | 9 | 2 | 8 | 0 |
| 2025 | 9 | 2 | 5 | 0 |
| 2026, onvolledige export | 10 | 1 | 8 | 0 |

De achteruitgang in registraties in M7 is dus al ruim vóór de uitzetting zichtbaar: van 63 over elf bevestigde bezoeken in 2015 naar nul over zes bezoeken in 2022 en nul over tien in 2023. De twee registraties in zowel 2024 als 2025 betekenen een beperkte hernieuwde registratie, zonder terugkeer naar het eerdere niveau. In M45 werden in 2019 en 2020 respectievelijk zes en drie konijnen geteld; in 2021–2025 geen binnen de bevestigde zoogdierbezoeken. Dat ondersteunt geen zichtbaar herstel in deze BMP-selectie. Het bewijst niet dat er bij de hokken geen konijnen leven of dat uitzetting geen effect heeft.

In M7 zijn alle achttien BMP-rondes in 2024–2025 gekoppeld aan een zoogdierbezoek. In M45 zijn dat dertien van zeventien rondes: acht van negen in 2024 en vijf van acht in 2025. De vier ontbrekende koppelingen zijn geen konijnennullen. Ook in M7 bewijst deze koppeling niet dat alle delen van de kavel of alle zoogdieren tijdens ieder bezoek volledig zijn onderzocht.

De vier recente M7-meldingen met aantal één dateren van 10 maart en 10 april 2024 en 30 maart en 29 april 2025. Het ene exemplaar in de onvolledige jaargang 2026 is geregistreerd op 19 juli. Beperking tot maart–juni verandert de uitkomsten voor 2024–2025 niet; voor 2026 wordt M7 dan nul over negen bevestigde bezoeken. De levering bevat in 2026 alleen niet-vogelregistraties van 4 februari tot en met 19 juli en heeft status `uitgesloten_lopend_jaar`. Die jaargang is uitsluitend als afzonderlijke positieve aanvulling getoond, niet als volledig trendjaar.

### Aangrenzende kavels en afstand tot hokken

Direct aangrenzend is operationeel gedefinieerd als minder dan één meter afstand tussen de actuele SOVON-polygonen. Bij M7 gaat het om M6, M8, M14, M15, M16s, M61, M63 en M64; bij M45 om M1a, M1b, M43, M46 en M83. De vergelijking is beschrijvend. Andere beheeringrepen, zichtbaarheid, bezoektijd, telroute en tellerwisselingen zijn niet als gelijk verondersteld.

| Buurkavel | DAZ-bezoeken 2024 | Telsom 2024 | DAZ-bezoeken 2025 | Telsom 2025 |
|---|---:|---:|---:|---:|
| M6 | 5 | 0 | 6 | 1 |
| M8 | 9 | 0 | 8 | 1 |
| M14 | 9 | 0 | 7 | 0 |
| M15 | 7 | 0 | 3 | 0 |
| M16s | 3 | 0 | 5 | 0 |
| M61 | 8 | 0 | 3 | 0 |
| M63 | 9 | 0 | 7 | 0 |
| M64 | — | — | — | — |
| M1a | 8 | 0 | 8 | 0 |
| M1b | 8 | 0 | 7 | 0 |
| M43 | — | — | 1 | 0 |
| M46 | 9 | 0 | 9 | 0 |
| M83 | 9 | 0 | 7 | 0 |

Rond M7 zijn er in 2024–2025 twee konijnenregistraties tijdens 89 bevestigde bezoeken in de zeven buurpercelen met DAZ-deelname. Rond M45 zijn er nul tijdens 66 bevestigde bezoeken in vijf buurpercelen, met ontbrekende deelname in M43 in 2024. M64 heeft in 2024 wel tien geregistreerde BMP-rondes maar geen bevestigd zoogdierbezoek; M43 heeft twaalf en dertien BMP-rondes in 2024 en 2025, tegenover respectievelijk nul en één bevestigd zoogdierbezoek. Deze gevallen mogen dus niet als volledig bemeten vergelijkingskavels worden gepresenteerd.

De historische buurvergelijking gebruikt dezelfde bevestigde SOVON/AVIMAP-bezoeken. De aantallen beschikbare kavels wisselen per periode; de telsommen zijn daarom geen onderling gelijke inventarisaties of populatieschattingen.

| Omgeving | Periode | Kavels met gegevens | Bevestigde bezoeken | Telsom konijn |
|---|---|---:|---:|---:|
| Buren M7 | 2009–2018 | 8 | 403 | 1.774 |
| Buren M7 | 2019–2023, vóór oktober | 6 | 127 | 21 |
| Buren M7 | 2024–2025 | 7 | 89 | 2 |
| Buren M45 | 2009–2018 | 4 | 266 | 396 |
| Buren M45 | 2019–2023, vóór oktober | 4 | 166 | 26 |
| Buren M45 | 2024–2025 | 5 | 66 | 0 |

Ook over de directe buren ligt het recente registratieniveau dus lager dan in de voorafgaande perioden. Wisselende dekking en inspanning verhinderen een directe vertaling naar populatieverandering of een uitzettingseffect. Alle 2019–2023-bezoeken in deze buurselectie dateren uiterlijk 29 juni 2023 en vallen daarmee vóór de eerste gedocumenteerde overplaatsingen in oktober.

Een tweede selectie gebruikt de kortste afstand van een positieve AVIMAP-konijnenregel tot een van beide hokken per locatie. Iedere bron-ID telt per locatie hoogstens eenmaal, zodat overlappende buffers niet dubbel tellen. Voor 2019–2026 zijn de telsommen binnen 500 meter van locatie A achtereenvolgens 10, 1, 1, 0, 1, 2, 3 en 2; voor locatie B 7, 3, 0, 0, 1, 0, 0 en 0. Het nulcijfer betekent hier nul geregistreerde positieve regels in de buffer, geen bewezen afwezigheid of volledig onderzochte buffer.

In 2024 liggen de twee A-meldingen beide meer dan 250 meter van de hokken; de kleinste afstand is 310,6 meter. In 2025 liggen twee van de drie meldingen binnen 250 meter, met minimaal 109,1 meter. Binnen 100 meter zijn er in 2024–2025 geen meldingen. Bij B zijn er sinds 2024 geen positieve konijnenregels binnen 500 meter. Vóór de uitzetting zijn er al positieve registraties dicht bij de huidige punten: bij A een registratie op 20 mei 2023 op 81,8 meter en bij B in 2019 op 90,1 meter. Ook dicht bij de hokken is nieuw geregistreerde aanwezigheid dus niet automatisch door uitzetting ontstaan.

Er is geen model voor een causaal uitzettingseffect geschat: de plaatsings- en vrijlatingsdata en aantallen per hok ontbreken, de recente positieve uitkomsten zijn schaars en de vergelijkingskavels hebben uiteenlopende zoogdierdekking. Deze eerste analyse rapporteert alle nuluitkomsten binnen bevestigde bezoeken én de ontbrekende dekking. De twee 2024/2025-jaargangen ondersteunen in M7 een klein registratiesignaal, in M45 en zijn buren geen zichtbaar signaal; zij bewijzen geen populatieherstel of afwezigheid van effect.

### Aanvullende informatie: kleinste bruikbare lijst

Voor Amy/Dunea, na bovenstaande broncontrole:

1. **Jaren en data per hok.** Welke kalenderjaren worden bedoeld met afgelopen vier jaar? Per hok en per uitzetmoment de datum van plaatsen en de datum waarop de dieren het hok konden verlaten; onderscheid plaatsing in een afgesloten hok van feitelijke vrijlating. Vermeld ook jaren zonder uitzetting.
2. **Werkelijk uitgezette aantallen.** Per hok en uitzetmoment het aantal geplaatste dieren en, voor zover bekend, het aantal dat levend is vrijgelaten. De 20–40 dieren uit het activiteitenplan zijn beoogde aantallen; een uitvoeringslogboek of bestaande jaarrapportage heeft de voorkeur boven een nieuw samengesteld bestand.
3. **Ligging door de jaren heen.** Zijn de vier kaartpunten voor alle uitzetjaren dezelfde gebleven? Zo niet: oorspronkelijke positie en datum van verplaatsing. Hoe verhouden Kijfhoek/Bierlap en Loopert zich tot de planlabels Kleine Pan en Waterschaps-vallei? Een bestaande kaart of hoknummering volstaat; de huidige puntcoördinaten hoeven niet opnieuw te worden aangeleverd.
4. **Bestaande monitoring.** Het beschikbare uitzetlogboek, de jaarlijkse pilotrapportages en eventuele eindrapportage, plus de oorspronkelijke telgegevens van duinwachters/camera’s met datum, locatie, methode, telinspanning en nuluitkomsten. Deze kunnen de vergelijking met BMP rechtstreeks aanvullen. De beschikking schreef jaarlijkse rapportage en een eindrapport voor; dat bewijst niet dat die documenten al zijn ingediend of beschikbaar zijn.
5. **Nuttige uitvoeringscontext, indien vastgelegd.** Bijvoeren, openstellen/verwijderen van rasters, sterfte, ziekte, gemerkte dieren en herkenbare voortplanting, met datum en hok. Dit helpt een klein of ontbrekend BMP-signaal te duiden. Geen brede nieuwe onderzoeksuitvraag; bestaande registraties zijn voldoende.

Voor Ton en de betrokken BMP-teller/tellerteams, afzonderlijk van de vraag aan Dunea:

6. **Consequente zoogdierregistratie.** Zijn zoogdieren bij de vier M45-rondes zonder bevestigde deelname in 2024–2025 wel onderzocht? Zijn daarbij nulwaarnemingen, niet-doorgegeven meldingen of afwijkende routes bekend? Controleer dit ook in M43 en M64 waar de zoogdierdekking ontbreekt. Welke routes, bezoektijden of registratieafspraken veranderden vóór en na de uitzetting? Beschikbare bezoek-ID’s, data en tellertoedeling moeten eerst uit de lokale tabellen worden gebruikt; hiervoor is geen uitvraag van de al aanwezige vogelbezoekdata nodig.

### Herhaalbare selectie

De primaire jaarselectie (geen NDFF-dubbeling; één matrixrij per bevestigd bezoek en konijn):

```sql
SELECT p.kavel_nummer, v.jaar, COUNT(*) AS daz_bezoeken,
       SUM(v.aantal) AS som_tellingen,
       SUM(v.waarnemingsstatus='waargenomen') AS positieve_bezoeken
FROM v_sovon_avimap_daz_analyse v
JOIN v_meijendel_analyseplot_actueel p USING(plot_id)
WHERE p.kavel_nummer IN ('M7','M45')
  AND v.nederlandse_naam='Konijn'
GROUP BY p.kavel_nummer,v.jaar
ORDER BY p.kavel_nummer,v.jaar;
```

De naampolygoonafstand gebruikt `ST_Distance` na transformatie van de vier WGS84-punten; kavels volgen `ST_Intersects`. De puntbufferselectie berekent per `(batch_id, bron_waarneming_id, locatie)` eerst de minimale `ST_Distance` tot de twee hokpunten en aggregeert daarna eenmaal per bron-ID. De historische secundaire selectie vóór 2009 gebruikt uitsluitend `daz_bmp_recordselectie.reconstructieversie='ndff-daz-bmp-v1'`, taxon `Oryctolagus cuniculus`, eenduidige bezoek-ID en uitsluiting van actuele `sovon_vervangt_ndff%`-koppelingen. Geen secundaire nulregels worden gebruikt.


## Heranalyse met alle konijnenbronnen

Stand: 20 oktober 2026. Deze heranalyse vervangt de conclusie van de eerste, grotendeels op AVIMAP gebaseerde vergelijking hierboven. Vraag: wat laten alle aanwezige konijnenbronnen zien vóór en na de bijplaatsing, in M7 en M45 en rond de vier feitelijke uitzethokken? Brondata, maatregelregistratie en toelatingsregels zijn niet gewijzigd. De berekeningen zijn lokaal uitgevoerd; uitsluitend tijdelijke sessietabellen zijn als rekencache gebruikt. Er is geen database-export, cachebouw of VPS-publicatie uitgevoerd.

### Volledigheid en bronidentiteit

Alle 128 centrale taxonroutes zijn gecontroleerd op het versiegebonden centrale taxon Konijn, `taxon_id=38949`, wetenschappelijke naam `Oryctolagus cuniculus`. De bestaande helper `central_taxon_query()` is gebruikt, niet een vrije overeenkomst op het woord konijn. Afgeleide tabellen, soortcatalogi en protocolkoppelingen zijn geen extra dieren of onafhankelijke bronnen. In de gedeelde tabel `daz_bmp_bezoek_taxon` is nadrukkelijk per reconstructieversie gekeken: de versie `sovon-bmp-jaarbestanden-v1` bevat oorspronkelijke aanvullende SOVON-bezoektotalen en mag niet als uitsluitend NDFF-afleiding worden afgedaan. Dat was een beperking van de eerdere analyse.

| Oorspronkelijke bronlaag | Konijnregels | Periode | Betekenis |
|---|---:|---|---|
| SOVON/AVIMAP | 10.003 | 2009–2026 | Positieve puntregistraties tijdens BMP-bezoeken |
| Aanvullend bewaarde SOVON-jaarbestanden | 1.787 | 2005–2025 | Positieve bezoek-taxontotalen; andere korrel dan puntregistraties |
| NDFF, protocol 17.209 | 5.095 | 1984–2023 | Sectietellingen zonder route-/sectienummer, geleverd op kilometerhok |
| NDFF, protocol 17.204 | 4.742 | 1994–2022 | Oudere BMP-zoogdierregistraties, met overlap met primaire SOVON-bronnen |
| NDFF, LOS | 1.773 | 1960–2025 | Losse meldingen van levende/dode dieren en sporen |
| NDFF, 102.006 | 7 | 2021–2023 | ObsIdentify |
| NDFF, 14.204 | 8 | 2017–2021 | Punt Transect Telling |
| NDFF, 17.005 | 4 | 1970 | Atlas van de Nederlandse Zoogdieren 1992 |
| NDFF, 17.002 | 1 | 2011 | Braakbalonderzoek |

De zeven NDFF-protocollen tellen samen 11.630 canonieke Konijnrecords. Alle konijnen hebben in de canonieke laag representatie `alleen_openbaar`; er zijn voor dit taxon geen extra beveiligde waarnemingen of vervangingen uit de beveiligde levering. De canonieke route blijft wel verplicht gebruikt. De 5.809 records van protocol 17.209 bestaan uit 5.095 Konijnrecords en 714 bijvangsten. Het getal 5.809 mag dus niet als aantal konijnenwaarnemingen worden gepresenteerd. De in het bronregister eerder genoemde 812 bezoeken zijn eveneens gecorrigeerd: het zijn 812 kalenderdatums voor het gehele protocol, geen bewezen oorspronkelijke bezoeken.

Van de 10.003 AVIMAP-konijnenregels vallen er 9.704 binnen de actuele Natura 2000-analysescope. M66 levert 284 regels uit 2009–2026 en M91 vijftien uit 2014–2020; deze 299 regels zijn buiten de lokale kavel-/bufferanalyse gehouden. De oorspronkelijke bronperiode en bronregels blijven ongewijzigd.

### Overlap en analysepoorten

Van de 1.787 aanvullend bewaarde SOVON-bezoektotalen hebben 1.562 regels uit 2009–2025 een AVIMAP-tegenhanger op hetzelfde bezoek; de overige 225 betreffen 2005–2008, vóór de huidige AVIMAP-reeks. De gemeenschappelijke waarden van M7 en M45 zijn gelijk. Elders verschillen binnen-plotwaarden wanneer het jaarbestand een afzonderlijk aantal buiten het plot vermeldt. Deze bezoektotalen worden daarom niet bij de puntregistraties opgeteld en zijn niet gebruikt om dieren zonder eigen puntpositie naar de 500-meterzone te verplaatsen.

Van de 4.742 NDFF-konijnenregels onder 17.204 zijn er 900 als `sovon_vervangt_ndff_exact` en 968 als `sovon_vervangt_ndff_telconflict` vastgelegd; 2.874 hebben geen SOVON-overlap in de bestaande koppeling. Die laatste status bewijst geen onafhankelijke bron en geeft geen ruimtelijke toelating. De zes Konijnrecords onder 17.209 met `mogelijke_overlap_17_204` blijven apart herkenbaar; zij zijn niet zonder bewijs verwijderd of gecombineerd. De elf mogelijke overlappingen uit de algemene protocolaudit betreffen alle taxa, niet alleen Konijn.

Er zijn daarnaast vijf mogelijke paren tussen toegelaten losse NDFF-meldingen en SOVON-punten op datum en overlappend liggingsvlak: drie NDFF-regels in M8 uit 2015, één in M42 uit 2016 en één in M34 uit 2025. Dat is een waarschuwing voor mogelijk dezelfde waarneming, geen bewezen dubbeling. Er is geen totaalsom over beide bronnen gevormd. In de recente doelkavels M7/M45 en in de A/B-buffervergelijking voor 2024–2025 is geen dergelijk kandidaatpaar aangetroffen.

De verplichte `v_ndff_gebruiksdekking_soortgroep_protocol` is vooraf gelezen. Alle inhoudelijke NDFF-selecties volgen `v_ndff_analyse_record`, keten `ndff-analyseketen-v1`, besluitversie `ndff-analysebesluit-v4`, doelbereik `ndff-protocolbereik-v2`. Alleen `record_selectiestatus='voorlopig_bruikbaar'` wordt als lokale aanwezigheid gebruikt, gevolgd door `v_meijendel_analyseplot_actueel`. Grof gelokaliseerde records worden uitsluitend als uitgesloten broncontext besproken; zij worden niet alsnog als kavelwaarneming toegelaten.

Van de 11.630 NDFF-Konijnrecords zijn 754 voorlopig bruikbaar, waarvan één losse melding uit 2019 in M66 buiten de analysescope valt. De lokale selectie bevat daardoor 753 regels: 751 LOS en twee ObsIdentify. De oorspronkelijke telonderwerpen zijn 724 levende exemplaarmeldingen uit 1995–2025, vijftien meldingen van vers dood gevonden dieren uit 1960–2018 en veertien spoor-/mest-/vraatmeldingen uit 2010–2024. De 724 regels zijn geen 724 dieren; aantallen en herhaalde meldingen verschillen. Gegevensgeschiktheid blijft bij LOS `niet_beoordeeld` en bij ObsIdentify `voorwaardelijk`; gebruik is uitsluitend geregistreerde aanwezigheid (`V`). Ontbrekende meldingen zijn geen afwezigheid of nulbezoeken. De kwaliteitsmelding van de centrale view blijft van toepassing: ruwe meldingsaantallen zijn geen gevalideerde populatietrend.

### M7 en M45: aanvullende informatie en recente uitkomsten

Het historische SOVON-jaarbestand bevat voor M7 op 6 juni 2006 één positief bezoektotaal van twee konijnen. Dit komt boven op de eerder gevonden secundaire NDFF/BMP-meldingen van elk één konijn op 26 mei en 19 juni 2006. Het zijn drie verschillende bezoekdatums; zij zijn geen vier verschillende individuen. De twee historische afgeleide nulregels uit 2006 en 2008 zijn niet gebruikt als afwezigheidsbewijs. In M45 is vóór 2009 in deze geselecteerde bronversies geen positief konijnenbezoek gevonden; dat is geen bewijs dat er geen konijnen waren.

De primaire historische AVIMAP-uitkomsten uit de eerdere volledige jaartabel zijn opnieuw berekend en ongewijzigd. In M7 bevat 2015 nog 63 getelde konijnen over elf bezoeken met zoogdiermeldingen. In 2022 en 2023 bevat die selectie nul konijnen over respectievelijk zes en tien van zulke bezoeken. Die uitkomst geldt uitsluitend voor die bezoekselectie: de aanvullende bronnen bewijzen dat in M7 in mei 2023 wel een levend konijn is gemeld.

| Jaar | M7: AVIMAP-telsom / bezoeken met zoogdiermelding | M7: aanvullende levende LOS-meldingen | M45: AVIMAP-telsom / bezoeken met zoogdiermelding | M45: aanvullende levende LOS-meldingen |
|---|---:|---:|---:|---:|
| 2022 | 0 / 6 | 0 | 0 / 8 | 0 |
| 2023 | 0 / 10 | 1 | 0 / 9 | 0 |
| 2024 | 2 / 9 | 1 | 0 / 8 | 0 |
| 2025 | 2 / 9 | 0 | 0 / 5 | 0 |

De vijf toegelaten losse M7-meldingen betreffen november 2015, december 2017, februari 2018, mei 2023 en mei 2024. Iedere melding betreft één levend exemplaar, maar herhaalde individuen zijn niet te onderscheiden. De melding van mei 2023 gaat vooraf aan de eerste gedocumenteerde Dunea-overplaatsingen in oktober 2023. De conclusie hernieuwde aanwezigheid vanaf 2024 is daarom voor de kavel als geheel ingetrokken. Zij was hoogstens een beschrijving van de beperktere BMP-selectie. In M45 is geen toegelaten LOS- of ObsIdentify-konijnenregel gevonden.

De teldekking blijft ongelijk. Voor 2024–2025 heeft M7 achttien BMP-rondes en achttien bezoeken met zoogdierregistratie. M45 heeft zeventien BMP-rondes en dertien bezoeken met zoogdierregistratie. De vier overige rondes zijn geen konijnennullen. Een positieve melding van een andere zoogdiersoort bewijst bovendien niet zelfstandig dat alle konijnen in het hele telgebied zijn geteld. De technische bezoekmatrix blijft een voorwaardelijke reconstructie, geen bewijs dat iedere ronde volledig voor het formele meetnet is uitgevoerd.

De eerder doorgerekende directe buren zijn opnieuw op aanvullende meldingen gecontroleerd. In 2024–2025 komen er geen nieuwe, toegelaten NDFF-konijnenmeldingen in de dertien aangrenzende kavels bij. De oorspronkelijke SOVON-resultaten blijven daarom twee konijnenregistraties tijdens 89 bezoeken met zoogdiermeldingen in zeven buren van M7, en nul tijdens 66 van zulke bezoeken in vijf buren van M45. De ontbrekende zoogdierdekking in M64 en in M43/2024 blijft zichtbaar; die kavels tellen niet als volledig bemeten nulgebieden.

### Rond de feitelijke hokken: 100, 250 en 500 meter

Per locatie is de vereniging van de cirkels rond de twee hokpunten gebruikt. Een bron-ID telt per locatie eenmaal. SOVON-punten kunnen aan de buffer worden getoetst. Voor losse NDFF-meldingen is onderscheid gemaakt tussen een liggingsvlak dat geheel binnen de buffer ligt (`ST_Within`) en een vlak dat de buffer slechts raakt (`ST_Intersects`). Een centroid of kortste afstand mag de laatste categorie niet in bewezen lokale aanwezigheid veranderen.

| Locatie en jaar | Positieve SOVON-puntregels binnen 500 m | Aanvullende levende LOS-regels met geheel liggingsvlak binnen 500 m | Betekenis |
|---|---:|---:|---|
| A, 2023 | 1 | 1 | Beide vóór de programmastart in oktober; aanwezigheid bestond al |
| A, 2024 | 2 | 1 | Twee SOVON-punten buiten 250 m; het losse meldingsvlak doorsnijdt de 250-metergrens |
| A, 2025 | 3 | 0 | Twee SOVON-punten binnen 250 m, geen binnen 100 m |
| B, 2023 | 1 | 0 | Historische aanwezigheid in de ruimere omgeving |
| B, 2024 | 0 | 0 | Geen precies gelokaliseerde positieve melding in deze selectie |
| B, 2025 | 0 | 0 | Eén grovere melding is uitsluitend mogelijke context, zie hieronder |

Bij A staan in 2024 en 2025 dus telkens drie recente registraties binnen 500 meter, over twee verschillende bronnen. Dat is geen telling van drie verschillende konijnen en geen bewijs dat inspanning of trefkans gelijk was. Binnen 100 meter van de A-hokken is in beide jaren geen konijnenregistratie gevonden; in 2023 was er al een SOVON-punt op 81,8 meter. De aanvullende LOS-melding van 2024 ligt met haar gehele onzekerheidsvlak binnen 500 meter, maar doorsnijdt de grens van 250 meter. De onafhankelijk gecontroleerde kortste afstand tot dat vlak is 246,8 meter; de waarneming ligt dus niet bewezen geheel binnen of geheel buiten 250 meter. De twee SOVON-punten liggen wel buiten 250 meter. Geen van deze drie regels is een telling in het hok zelf.

Bij B zijn in 2024–2025 geen voldoende precies gelokaliseerde levende konijnenmeldingen binnen 500 meter gevonden. Er is wel één LOS-melding van één levend exemplaar uit 2025, vervaagd tot een kilometerhok van 1.000.000 m². Dat hok raakt de 500-meterzone gedeeltelijk. De werkelijke waarneming kan binnen of buiten die zone liggen. Deze regel blijft `uitgesloten_ruimtelijk` en wordt niet als lokale waarneming of nul gebruikt. De eerdere algemene formulering dat rond Loopert geen meldingen bestaan is daarom aangescherpt tot geen voldoende precies gelokaliseerde melding binnen deze selectie.

De SOVON-bufferhistorie blijft herkenbaar en is uitgebreid tot alle beschikbare jaren. Bij A zijn er bijvoorbeeld in 2015 75 positieve puntregels met een telsom van 98, tegen twee regels/telsom twee in 2024 en drie regels/telsom drie in 2025. Bij B bevat 2015 zes regels/telsom zes, 2016 negen en 2020 drie; na één positieve regel uit 2023 zijn er geen punten uit 2024–2025 binnen de buffer. Door wisselende bezochte kavels, routes, tijdstippen en registratie-intensiteit zijn dit beschrijvende uitkomsten, geen populatie-index of formele voor-na-effectschatting.

### Wat voegt het zelfstandige konijnenmeetnet toe?

De 5.095 Konijnrecords van 17.209 zijn alle gekoppeld aan kilometerhokken die meerdere actuele SOVON-plots raken. Route- en sectie-id ontbreken, en alle regels zijn in de gewone NDFF-analyseview ruimtelijk uitgesloten. De bron blijft aanwezig, met kwaliteitsstatus `wacht_op_route_sectie_koppeling`; dit is geen reden om bronregels te verwijderen of gelijke sectietellingen als dubbelen te behandelen.

Voor locatie A raken twee kilometerhokken de zone van 500 meter. Zij bevatten 896 positieve Konijnrecords uit 1984–2022. Geen van deze brongeometrieën ligt geheel binnen de zone; geen van de vier exacte hokpunten valt in een aangeleverd telhok. De dichtstbijzijnde telhokrand ligt op 58,2 meter van een A-punt. Dat is afstand tot het onzekerheidsvlak, niet afstand tot een waargenomen konijn. De 896 regels zouden met een onjuiste ruimtelijke join alle tegelijk in M7, M8 en M64 worden meegeteld. De kandidaatrelatie met drie kavels is geen bewijs van 2.688 onafhankelijke waarnemingen of van aanwezigheid in iedere kavel.

Voor locatie B is de minimale afstand tussen een aangeleverd telhok en een B-punt 574,5 meter. Geen telhok raakt daarom de 500-meterzone. De bronhokken raken wel enkele buurpercelen, waaronder M1a, M1b en M46; voor M1b en M46 worden bijvoorbeeld dezelfde 1.404 bronrecords uit 1984–2023 geraakt. Ook die twee kavelaantallen mogen niet bij elkaar worden opgeteld. Dit zijn uitsluitings- en kandidaatdiagnostieken, geen nieuwe lokale verspreidingsselecties.

De zelfstandige meetnetlevering bevat geen gegevens uit 2024–2025 en bij de twee A-kandidaathokken ook geen records uit 2023. Daardoor is de huidige levering niet geschikt om een recente reactie op de bijplaatsing te meten. Er is geen routejaarindex, bezoekaantal, nulmatrix, abundantie of trend uit deze hokaggregaten afgeleid. De oorspronkelijke route-/sectiekoppeling en recentere bronjaren zijn nodig voordat dit meetnet een plaatsgebonden voor-na-vergelijking kan dragen.

### 2026, conclusie en verificatie

De onvolledige AVIMAP-jaargang 2026 is afzonderlijk gehouden. Zij bevat in M7 één konijnenmelding tijdens tien bezoeken met zoogdiermeldingen; in M45 nul tijdens acht. Binnen de A-zone zijn twee SOVON-punten uit 2026 aanwezig, één in M7 en één in M8. De bron eindigt voor niet-vogels op 19 juli 2026 en is niet als volledig jaar met 2024–2025 vergeleken. De aanvullende NDFF-bronnen eindigen in 2025 of eerder.

De kernconclusie is aangescherpt: konijnen waren aantoonbaar vóór de bijplaatsing aanwezig in de omgeving van beide locaties. Rond A zijn in 2024 en 2025 enkele registraties beschikbaar, ook buiten de BMP-rondes. Rond B ontbreekt in die jaren een voldoende precies gelokaliseerd signaal, maar één vervaagde melding uit 2025 kan de omgeving betreffen. Het zelfstandige konijnenmeetnet vergroot de historische context, zonder in de huidige export een recente effectvergelijking mogelijk te maken. Een positief uitzettingseffect is niet aangetoond en ook niet uitgesloten. Het totaal van alle bronregels is geen aantal dieren en geen gezamenlijke tijdreeks.

Er is geen causaal uitzettingsmodel geschat: de feitelijke uitzet- en vrijlatingsdata en aantallen per hok zijn niet bekend, de recente positieve gegevens zijn schaars, de bezoekdekking verschilt en de zelfstandige routetellingen missen ruimtelijke en recente meetstructuur. Aanwezige openbare plannen en jaarverslagen bepalen niet de uitgevoerde hoeveelheid per hok. Er is geen nieuw extern informatieverzoek opgesteld of verzonden.

De alleen-lezen audit `--audit-live` slaagt voor keten v1: nul canonieke dubbelingen, nul onjuiste representaties en nul ontbrekende analysevelden; alle 810.983 canonieke records zijn technisch sluitend verwerkt. `--audit-konijnen` slaagt: 5.809 protocolrecords, 5.095 doelsoortregels, 714 bijvangsten, nul afgeleide nulregels en expliciete meervoudige plotkoppeling voor alle bronregels. Die technische controles bewijzen geen trendgeschiktheid. Primaire jaaruitkomsten zijn opnieuw uit de bezoekmatrix berekend; losse meldingen zijn onafhankelijk naar telonderwerp, maand, scope en volledige liggingsgeometrie gecontroleerd. Een aanvullende afstandscontrole voorkomt dat een gedeeltelijke overlap met de 250-meterzone als volledig binnen of buiten wordt gepresenteerd. De contexttabellen duinvallei_taxon en jachtspin_soort bevatten nul Oryctolagus-vermeldingen; de dataset-/kandidaatcatalogus bevat geen aanvullende konijnenmeetbron. Beide bronregisterversies zijn inhoudelijk gelijk. Alle 56 gerenderde Wordpagina’s zijn in overzicht en de gewijzigde pagina’s 18, 34 en 35 afzonderlijk visueel gecontroleerd.

### Reproduceerbare kernselecties

De centrale inventarisatie gebruikt `central_query_routes(CentralQueryDatabase().schema())` en per route `central_taxon_query(..., taxon_id=38949)`. Alle oorspronkelijke en afgeleide rollen en alle reconstructieversies zijn daarna afzonderlijk beoordeeld. De jaarlijkse bezoekselectie hierboven blijft herhaalbaar met de eerdere SQL, met aanvullend onderstaande bron- en overlapcontroles.

```sql
-- Aanvullende SOVON-totalen per kavel en jaar; uitsluitend positief,
-- geen ontbrekende waarden of historische afgeleide nullen als nul tellen.
SELECT p.kavel_nummer,v.jaar,COUNT(*) positieve_bezoeken,SUM(m.aantal) telsom
FROM daz_bmp_bezoek_taxon m
JOIN dagbezoeken_bmp v ON v.bezoek_id=m.bezoek_id
JOIN taxa_bronkoppeling t ON t.koppeling_id=m.taxon_bronkoppeling_id
JOIN v_meijendel_analyseplot_actueel p ON p.plot_id=v.plot_id
WHERE t.taxon_id=38949 AND m.reconstructieversie='sovon-bmp-jaarbestanden-v1'
GROUP BY p.kavel_nummer,v.jaar;

-- Aanvullende NDFF-aanwezigheid. Geen record uit de uitgesloten klassen
-- en geen M66/M91; één canonieke identiteit wordt één keer geselecteerd.
SELECT p.kavel_nummer,v.jaar,v.protocol_sleutel,w.telonderwerp,COUNT(*) records
FROM Meijendel_ndff_secure.v_ndff_analyse_record v
JOIN ndff_open_waarneming w ON w.waarneming_id=v.open_waarneming_id
JOIN v_meijendel_analyseplot_actueel p ON p.plot_id=CAST(v.plot_id AS UNSIGNED)
WHERE v.wetenschappelijke_naam='Oryctolagus cuniculus'
  AND v.record_selectiestatus='voorlopig_bruikbaar'
GROUP BY p.kavel_nummer,v.jaar,v.protocol_sleutel,w.telonderwerp;
```

Voor buffers is per locatie `ST_Union(ST_Buffer(hok1,r),ST_Buffer(hok2,r))` gebruikt, voor r=100, 250 en 500 meter in EPSG:28992. SOVON-punten volgen `ST_Intersects(punt,buffer)`. Voor NDFF is `ST_Within(analyse_geometrie,buffer)` vereist om een melding geheel binnen de buffer te noemen; losse intersecties blijven als mogelijke overlap zichtbaar. De diagnostiek van uitgesloten records wordt afzonderlijk uitgevoerd en verandert nooit `record_selectiestatus`. Bron-ID's zijn vóór iedere bufferaggregatie per locatie uniek. Datum en geometrie zijn alleen lokaal voor de overlapcontrole gebruikt; de rapportage bevat geen beveiligde waarnemingslocaties.
