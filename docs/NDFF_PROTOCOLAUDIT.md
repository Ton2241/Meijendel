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

Voor het Landelijk Meetnet Dagvlinders is bevestigd dat iedere `03.201`-regel
uit een geldig NEM-bezoek komt, dat de bezoekmomenten volledig aanwezig zijn en
dat er geen volledig vlinderloze bezoeken ontbreken. Uit tijd en geometrische
samenhang zijn onder regel `ndff-vlinderroute-v1` 3.126 bezoeken en 11
routefamilies gereconstrueerd. De matrix voor de 34 aangetroffen
dagvlindertaxa bevat 106.284 bezoek-soortregels: 20.075 positief en 86.209 echte
nullen. De 556 nachtvlinderrecords zijn bijvangst en blijven positieve
voorkomensinformatie.

Van de bezoeken zijn er 2.891 aan een waarschijnlijke route gekoppeld. Eén
ruimtelijk uitgerekte familie omvat 172 bezoeken en blijft gemarkeerd voor
handmatige controle. Voor 63 bezoeken met 185 bronrecords kon uit de aanwezige
geometrie geen route worden hersteld. De afgeleide tabellen staan in
`Meijendel`; `--audit-vlinders` controleert aantallen, matrixconsistentie en
dat geen oude afgeleide vlindertabellen in het beveiligde schema achterblijven.

De 1.535 vliesvleugelrecords onder hetzelfde protocol zijn geen bijvangst maar
een zelfstandige NEM-deelreeks. `ndff-vliesvleugelroute-v1` omvat 217 bezoeken
in 2018-2025 en zes gevolgde taxa. De matrix bevat 1.302 regels: 365 positieve
bezoek-taxoncombinaties en 937 echte nullen. Alleen tijdstippen met minstens één
vliesvleugelrecord tellen als bezoek voor deze deelreeks. Daardoor blijven de
43 uitsluitend op vliesvleugeligen gerichte bezoeken buiten de
dagvlindermatrix, terwijl alle 217 vliesvleugelbezoeken in hun eigen matrix
vallen. Controle vindt plaats met `--audit-vliesvleugelen`.

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

Het NEM-Meetprogramma Reptielen (`10.201`) is onder
`ndff-reptielroute-v1` uit uitsluitend openbare records gereconstrueerd. De 957
bronrecords uit 1990-2025 vormen 14 routefamilies en 660 route-datumbezoeken.
Van die bezoeken zijn er 648 aan een route gekoppeld; twaalf bezoeken hebben
alleen een grof kilometerhok. De 15 historische trajectgeometrieën vormen de
routeankers; 56 latere exacte locaties zijn aan het best passende anker
gekoppeld. Alleen twee protocoltaxa komen voor: Zandhagedis en Hazelworm.

De bezoek-soortmatrix bevat 1.320 regels: 661 positieve combinaties en 659
echte nullen voor Hazelworm. Ieder aangeleverd bezoek bevat minstens een
positieve Zandhagediswaarneming. De FFV-bron bevat dus geen volledig negatieve
reptielenbezoeken; ontbrekende Zandhagedisbezoeken of -nullen worden niet
gereconstrueerd. De 6.286 adulte, 64 subadulte en 761 juveniele dieren blijven
afzonderlijk optelbaar. Begin- en eindtijden worden bewaard, maar de feitelijke
inspanning is `niet_afleidbaar`. De vier `Meijendel.ndff_reptiel_*`-tabellen
worden met `--audit-reptielen` gecontroleerd en staan niet in het beveiligde
schema.

NEM-amfibieënprotocol `01.201` is onder `ndff-amfibiewater-v1` uit de 2.439
onvervaagde openbare records uit 2003-2025 gereconstrueerd. De 52 openbare
watergeometrieën vormen 50 conservatief gekoppelde waterfamilies, 211
telgebiedbezoeken en 1.300 waterbezoeken met minstens één positieve
registratie. Geometrieën worden alleen als versies van hetzelfde water
gekoppeld wanneer hun gebruiksjaren niet overlappen en hun middelpunten
hoogstens 30 meter uiteen liggen.

De matrix bevat 9.100 waterbezoek-taxonregels: 2.274 positief en 6.826 echte
protocolnullen voor zeven openbaar reconstrueerbare taxa. Een echte nul
betekent hier uitsluitend: niet gemeld in een water dat door minstens één
positieve amfibieënregistratie aantoonbaar is bezocht. Volledig negatieve
water- of telgebiedbezoeken kunnen uit de positieve FFV-export niet worden
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

Het NEM-meetnet Zeereeppaddenstoelen (`11.202`) is onder
`ndff-zeereep-v1` gereconstrueerd op zijn oorspronkelijke meeteenheid: het
RD-kilometerhok. De 3.729 onvervaagde openbare records vormen 161 bevestigde
hok-datumbezoeken in 21 kilometerhokken, verspreid over 2014-2025. Negen
vervaagde records zijn niet als bezoek gebruikt. De bezoek-soortmatrix omvat
de zes typische doelsoorten en bevat 966 regels: 224 positieve combinaties en
742 protocolafgeleide echte nullen. Eén doelsoort is in geen enkel bezoek
gemeld en blijft daardoor als nulreeks expliciet zichtbaar.

De bronwaarden blijven inhoudelijk intact: `1-3`, `4-20` en `21 of meer` zijn
NMV-klassen van vindplaatsen en geen aantallen vruchtlichamen. Honderd bezoeken
vallen in het aanbevolen kernseizoen oktober-december; 61 bezoeken staan
afzonderlijk gemarkeerd als buiten dat venster. De NDFF-export bevat geen
bezoektijd of waarnemersbekwaamheid. Daarom zijn de nullen protocolmatig
bruikbaar voor een voorlopige bezettingsanalyse, maar iedere uitkomst vermeldt
dat deze twee leveringskenmerken nog niet zijn gevalideerd. Controle vindt
plaats met `--audit-zeereeppaddenstoelen`; de drie afgeleide tabellen staan
uitsluitend in `Meijendel`.

Methodische bronnen: [NDFF 11.202](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/11-202-zeereeppaddenstoelen/)
en [NMV-methodiek Zeereeppaddenstoelen](https://www.mycologen.nl/onderzoek/meetnet/zeereep-concept/zeereep-methodiek/).

Het historische NEM-meetnet Bospaddenstoelen (`11.201`) is onder
`ndff-bospaddenstoel-v1` gereconstrueerd op vaste meetpunten. De 982 openbare
bronregels bevatten twee technische representaties. Voor 473
plot-datum-taxoncombinaties staat een presentieregel naast een regel met het
exacte vruchtlichaamaantal; de exacte regel is canoniek gemaakt zonder de
presentieregel uit het auditspoor te verwijderen. Daardoor blijven 509 unieke
positieve resultaten over op drie meetpunten en 110 bezoeken in 1999-2016.

Het protocol stond per meetpunt registratie van alle telsoorten óf van één of
enkele telsoorten toe. Daarom omvat het afgeleide doelbereik uitsluitend de 76
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

### Het Nieuwe Strepen (`12.204`)

De eerdere telling van 1.145 verschillende begin-/eindtijdcombinaties was geen
bezoektelling. Bij app-invoer heeft vrijwel iedere plantwaarneming haar eigen
tijdstip. Regelversie `ndff-hns-v1` groepeert de 4.569 openbare bronregels
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
11.730 echte nullen; het hok-jaarbestand bevat 3.269 positieve combinaties en
5.167 nullen over twaalf hok-jaren.

De NDFF-export bevat geen FLORON-lijst-ID, teller of deelnemersaantal. Van tien
hok-jaren zijn herhaalde datumclusters aanwezig; 21 inventarisaties krijgen
daarom de status `herhaling_aanwezig_onafhankelijkheid_niet_bevestigd`. Twee
clusters binnen veertien dagen kunnen twee onafhankelijke tellers zijn, maar ook
velddagen van één inventarisatie. Gebruik de matrix voorlopig voor
verspreidings-/occupancyanalyse met deze waarschuwing; voer aantallen en dubbele
vindplaatsen niet als plantenabundantie in. Controleer de laag met `--audit-hns`.

Methodische grondslag: [FLORON Het Nieuwe Strepen](https://www.floron.nl/Meedoen/Het-Nieuwe-Strepen),
[FLORON protocol 2019](https://www.floron.nl/Portals/1/Downloads/Protocol%20Het%20Nieuwe%20Strepen%202019_papierenstreeplijst_mei2019.pdf),
[NEM Flora](https://www.netwerkecologischemonitoring.nl/meetprogrammas/flora)
en [CBS Meetprogramma's 2025](https://longreads.cbs.nl/meetprogrammas-flora-en-fauna-2025/meetprogrammas/).

### Korstmossen op steen, heiden en stuifzanden (`02.202`)

Regelversie `ndff-korstmos-v1` reconstrueert 364 onvervaagde openbare
bronregels tot twaalf proefvlakken en 32 bezoeken in 2000-2025. Vier vaste
proefvlakken zijn in zes meetjaren herhaald; acht proefvlakken hebben één
bevestigd bezoek. Het openbare lokale doelbereik omvat dertig taxa. Omdat het
protocol per bezoek een complete soortenlijst voorschrijft, bevat de
bezoek-soortmatrix 287 positieve combinaties en 673 echte nullen.

De bron bevat 67 gelijke parallelle registraties, die traceerbaar blijven maar
niet dubbel meetellen. Bij tien bezoek-taxoncombinaties spreken twee grove
NDFF-bedekkingsklassen elkaar tegen; die twintig bronregels blijven als
abundantieconflict bewaard. De FFV-levering bevat slechts twee ordinale klassen,
terwijl de oorspronkelijke BLWG-methode zes klassen onderscheidt. Gebruik de
matrix daarom voor presentie/occupancy en de grove rang alleen als ordinale
indicator, niet als exacte bedekking. Twintig vervaagde Saucijs-baardmosrecords
worden niet naar openbare afgeleide tabellen gekopieerd en leveren daar ook geen
nullen. Controleer de laag vóór gebruik met `--audit-korstmossen`.

Methodische grondslag: [NDFF protocol 02.202](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/2-202-korstmossen-op-steen-heiden-en-stuifzanden-nem/),
[BLWG meetnet](https://www.blwg.nl/meetnet-korstmossen-in-stuifzanden-nem)
en [NEM Korstmossen](https://www.netwerkecologischemonitoring.nl/meetprogrammas/korstmossen).

### Meetnet mossen (`02.204`)

Regelversie `ndff-mos-v1` reconstrueert 376 onvervaagde openbare bronregels
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
talrijkheidsklasse per soort. De FFV-export bevat geen BLWG-lijst-ID,
waarnemer of bezoekduur; deze ontbrekende metadata blijven als
kwaliteitswaarschuwing zichtbaar. Een kilometerhok wordt niet als aanwezigheid
of nul in ieder geraakt SOVON-plot geïnterpreteerd. Eén vervaagd record wordt
niet naar openbare afgeleide tabellen gekopieerd. Controleer de laag vóór
gebruik met `--audit-mossen`.

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

FLORON registreert op de oorspronkelijke streeplijst of het onderzoek volledig
was, naast bezoekdata en bezoekduur. Die volledigheidsvlag, de lijst-ID,
bezoekduur en historische checklistversie ontbreken in de FFV-export. Daarom
zijn de afgeleide nullen geschikt voor voorlopige inventarisatie- en
verspreidingsvergelijkingen, maar niet zonder waarschuwing voor een definitieve
trendclaim. De native meeteenheid is het kilometerhok; geen aanwezigheid of nul
wordt naar ieder geraakt SOVON-plot doorgezet. De 213 vervaagde records worden
niet naar deze openbare afgeleide laag gekopieerd. Controleer de laag met
`--audit-florbase`.

Methodische grondslag: [NDFF protocol 12.001](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/12-001-totaalproject-floron/),
[FLORON kilometerhokinventarisatie](https://www.floron.nl/Meedoen/Kilometerhokken-inventariseren)
en [FLORON inventarisatiehandleiding](https://www.floron.nl/Portals/1/Downloads/2022%20handleiding%20inventarisatie-projecten.pdf).

### HabSlak (`04.006`)

Regelversie `ndff-habslak-v1` groepeert 2.629 onvervaagde openbare records per
kalenderdatum en openbare geometrie tot 251 monsters. Dat levert 1.730
positieve monster-taxoncombinaties voor 51 taxa. Verschillende telonderwerpen,
zoals levende dieren en lege huisjes, blijven afzonderlijke meetwaarden in JSON
en worden niet bij elkaar opgeteld. De oorspronkelijke monster-ID en het
monstertype zijn niet meegeleverd.

De handleiding noemt Nauwe korfslak, Zeggekorfslak en Platte schijfhoren als
doelsoorten, maar in deze Meijendel-selectie is alleen Nauwe korfslak als
doelsoort aangetroffen. Voor die soort geldt een kilometerhok als voldoende
onderzocht bij minimaal vijftien kansrijke monsterlocaties. Van 66 bemonsterde
hok-jaren voldoen er vier aan die drempel; alle vier hebben een positieve
melding. Er worden daarom nu geen voorlopige nullen afgeleid. De reconstructie
kan bij een toekomstige volledige selectie alleen
`protocolnul_onder_doelbereikaanname` vormen, omdat doelbereik per veldformulier
ontbreekt. Voor begeleidende soorten wordt afwezigheid nooit afgeleid.

De 143 vervaagde openbare records blijven traceerbaar in de recordselectie maar
worden niet aan openbare monsters of exacte locaties gekoppeld. Een openbare
positieve doelsoortmelding mag alleen de reeds openbare hokjaarstatus bepalen.
Alle vier afgeleide tabellen staan in `Meijendel`; er is geen nieuwe tabel in
`Meijendel_ndff_secure`. Controleer de laag met `--audit-habslak`.

Methodische grondslag: [NDFF protocol 04.006](https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/4-006-slakken-van-de-habitatrichtlijn/),
[ANEMOON HabSlak](https://www.anemoon.org/projecten/natura2000/habslak-protocollen)
en de openbare handleiding
[Slakken van de Habitatrichtlijn waarnemen](https://www.ndff.nl/wp-content/uploads/2015/12/04.006-Handleiding-Slakken-van-de-Habitatrichtlijn-waarnemen.pdf).

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

## Reconstructie van de surveystructuur

De mededeling van NDFF dat de GeoPackage alle beschikbare informatie per
waarneming bevat, betekent dat de ontbrekende surveystructuur niet opnieuw bij
NDFF wordt gevraagd. De openbare handleidingen van de meetnetbeheerders bepalen
het bedoelde ontwerp. Feitelijke bezoeken worden waar mogelijk uit gelijke
begin- en eindtijden gereconstrueerd en meeteenheden uit geometrische samenhang.
Alleen niet-reconstrueerbare sleutels of historische wijzigingen worden later
gericht bij de bronorganisatie nagevraagd.

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

Prioriteit 1 wordt als eerste opgevraagd. Prioriteit 2 is voorwaardelijk
kansrijk. Prioriteit 3 is vooral bruikbaar binnen het eigen meetnetmodel of
voor periodieke toestand. Prioriteit 4 is in deze levering te klein voor een
lokale trend, tenzij de bronhouder een veel completere reeks kan leveren.

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
`Natuurprotocollen/Natuurprotocollen_gebruiksmatrix.xlsx`; de inhoudelijke
onderbouwing staat in
`Natuurprotocollen/Classificatie_natuurprotocollen_wetenschappelijk_gebruik.docx`.
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
  97.318 secundaire PQ-controlebron en 713.512 niet van toepassing;
- `ndff_snl_waarneming_context`: recordgebonden bronoverlapstatus voor de
  6.273 openbare records met protocol `12.205`;
- `ndff_analysebesluit`: 1.040 besluiten per bron, soortgroep, protocol en
  analysetype.

De interne view `Meijendel_ndff_secure.v_ndff_analyse_record` materialiseert
deze regels niet, maar brengt ze bij raadpleging samen tot één analysebesluit
per canonieke waarneming. De livecontrole omvat 810.983 unieke records zonder
ontbrekende protocol-, ruimtelijke, PQ- of gegevensgeschiktheidsstatus. Daarvan
zijn 303.319 voorlopig bruikbaar, 4 voorlopig bruikbaar met een
overlapwaarschuwing, 97.333 uitgesloten via de PQ-poort en 410.327 ruimtelijk
uitgesloten. De 430.263 expliciet losse waarnemingen hebben uitsluitend
kandidaattype `V`. Van de canonieke records behouden 710.140
`gegevensgeschiktheid = niet_beoordeeld`. De 4.999 records onder `04.004` en
`07.001` hebben na leveringsonderzoek de algemene V-status `voorwaardelijk`;
hun I- en TV-besluiten staan afzonderlijk op `onvoldoende`. De view levert een
verplichte `kwaliteitsmelding` en is geen verklaring dat trendgebruik al
volledig is gevalideerd.

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
niet uit. `17.002`, `102.002`, `102.005` en `102.007` zijn niet meegenomen,
omdat zij een afzonderlijk te beoordelen, mogelijk gestructureerde
surveyopzet hebben.

Voor praktisch gebruik zijn twee verder geaggregeerde interne views gebouwd.
`v_ndff_verspreiding_plot_jaar_taxon` bevat 105.999 positieve
plot-jaar-taxonsignalen uit 303.319 voorlopig bruikbare bronrecords.
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
geheel exact aan op 810.983 canonieke records. Er zijn 303.319 voorlopig
bruikbare V-kandidaten, 6.133 I-kandidaten, 60.015 TV-kandidaten, 57.605
TA-kandidaten en 4.727 TK-kandidaten. Deze aantallen mogen worden gecombineerd
in selecties, maar niet worden opgeteld omdat één record meerdere kandidaattypen
kan ondersteunen. Voor alle records blijft aanvullende gegevensvalidatie
wenselijk.

De vier aanvullende jaarniveau-views maken stap 3 compleet. De
soortenrijkdoms- en dekkingsviews bevatten beide 12.611 sluitend vergelijkbare
plot-jaar-soortgroepregels; zij omvatten 105.999 positieve taxonsignalen en
303.319 bronrecords. Daarvan zijn 201.372 records losse waarnemingen en 101.947
protocolgebonden. De eerste/laatste-view bevat 42.714 plot-taxonreeksen. De
verspreidingsveranderingsview bevat 33.022 taxon-jaarregels. Van de mogelijke
jaarvergelijkingen springen 8.059 over minstens één ontbrekend jaar; die zijn
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

### Uitwerking van de 19 doelsoortafhankelijke combinaties

De officiële protocolbronnen leveren de volgende beslissingen op:

| Protocol en soortgroep | Besluit v2 | Vastgestelde doelafbakening |
|---|---|---|
| `02.204` Mossen | doelgroep | Het gekozen kilometerhok wordt zo volledig mogelijk op mossen geïnventariseerd; alle gemelde mossen vallen binnen het doelbereik. |
| `04.006` Weekdieren | gemengd | Nauwe korfslak (`Vertigo angustior`), Zeggekorfslak (`V. moulinsiana`) en Platte schijfhoren (`Anisus vorticulus`); overige weekdieren zijn bijvangst. |
| `10.002` Amfibieën | blijft afhankelijk | eDNA is een techniek; de doelsoort volgt uit het project of de gebruikte assay en ontbreekt in de levering. |
| `11.201` Schimmels | gemengd | De officiële historische lijst omvat 110 telsoorten. Van de aangetroffen taxa zijn 49 gecontroleerd aan die lijst gekoppeld; `Fungi sp. indet.` is geen doelsoort. |
| `11.202` Schimmels | gemengd | Duinfranjehoed, Zeeduinchampignon, Duinstinkzwam, Duinveldridderzwam, Helmharpoenzwam en Zandtulpje; overige schimmels zijn begeleidende soorten/bijvangst. |
| `12.015` Kranswieren, wieren en algen | blijft afhankelijk | De doelsoortenlijst hoort bij de concrete Staatsbosbeheer-karteringsopdracht en is niet uit het record afleidbaar. |
| `12.205` zeven soortgroepen | blijft afhankelijk | Kwalificerende soorten verschillen per SNL-beheertype en versie. Beheertype en versie ontbreken in de records. |
| `13.201` Vissen | gemengd | Beekprik, beekdonderpad, bittervoorn, grote en kleine modderkruiper, rivierdonderpad en rivierprik; overige vissen zijn bijvangst. |
| `13.202` Amfibieën en Vissen | gemengd | Kamsalamander, beekprik, rivierdonderpad, bittervoorn, kleine en grote modderkruiper; andere amfibieën en vissen zijn bijvangst. |
| `17.202` Vleermuizen | gemengd | Voor populatietrend zijn Ingekorven vleermuis en Grijze grootoorvleermuis doelsoort; overige zolderwaarnemingen zijn verspreidingsinformatie. |
| `17.505` en `17.506` Vleermuizen | blijft afhankelijk | Doelsoort en onderzochte functie volgen uit het projectplan; de protocolcode alleen legt die niet vast. |

Daarmee zijn acht van de negentien combinaties opgelost. Elf blijven bewust
`doelsoortafhankelijk`: één eDNA-combinatie, één florakartering, zeven
SNL-combinaties en twee Vleermuisprotocol-combinaties. Dit is geen ontbrekende
algemene handleiding, maar ontbrekende projectcontext. Gokken op basis van de
aangetroffen soort is niet toegestaan.

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
