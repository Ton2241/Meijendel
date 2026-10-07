# Bronregister ecologische gegevens Meijendel

**Stand: 7 oktober 2026.**

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

**Taxonomisch register aangevuld en centraal opgeschoond, stand 3 oktober 2026.** De levende lokale database bevat 27 praktische groepen en 11.660 centrale vermeldingen: 11.659 naamvermeldingen en één uitdrukkelijk onbepaald operationeel collectieobject. De tabel met bronkoppelingen bevat 30.057 rijen: alle 18.437 oorspronkelijke bronbesluiten, drie eerdere identificatie-aliassen, 6.121 volledig bewaarde oorspronkelijke taxoncontexten, 5.495 aanvullende brongebruiken voor afgeleide meet-/doelsoortregels en de koppeling van het onbepaalde object. Er zijn 29.970 actieve koppelingen en 87 als eerdere versies bewaarde koppelingen. Dit is geen telling van unieke biologische soorten of lokale aanwezigheid. Het register heeft geen eigen waarnemingsperiode en omvat NDFF, provinciale PQ, Vangblik, SOVON/AVIMAP, de zes externe datasets en aanvullende referentiecatalogi. Meetperioden en toelatingsvoorwaarden blijven die van de afzonderlijke bronnen hieronder.

**Alle soortwaarnemingen centraal bereikbaar, 29 september 2026.** Vanuit taxa, taxa_bronkoppeling en taxon_groepen zijn alle oorspronkelijke soortwaarnemingen, afgeleide meetregels, echte nullen en historische versies in Meijendel bereikbaar. De volledige inventarisatie van 273 basistabellen geeft 127 beoordeelde routes, zonder ontbrekende koppelingen of vermenigvuldiging van soortregels. Dit omvat ook alle LVD-resultaten binnen en buiten pq_* en de vijf afzonderlijk opgeslagen externe bronnen. Alle oorspronkelijke gegevens, bronwaarden, interne verwijzingen, analysebeperkingen en 16 bestaande viewuitkomsten zijn behouden. Terugdraaien, onafhankelijk volledig herstel en levende nacontrole zijn geslaagd. Iedere volgende databasewijziging wordt vóór en na uitvoering volledig gecontroleerd; 267 rijtriggers beschermen bestaande bronidentiteiten en verwijzingen. Nieuwe gegevenslagen moeten expliciet in die controle worden opgenomen. Geen VPS-publicatie. De fysieke verplaatsing van resterende PQ/LVD-inhoud is een afzonderlijke, nog open taak. Uitvoering, aantallen per bron en periode, querygebruik en herstelbewijs staan in docs/database/TAXONREGISTER.md.

**Gerichte taxonfusie, 28 en 29 september 2026.** Na de eerste samenvoeging van drie Naturalis-keverregistraties zijn op 29 september eerst 2.156 en daarna nog 1.762 dubbele centrale rijen samengebracht. Ook Glaucium flavum staat nu één keer centraal. De 751 eerder overgebleven naamgroepen zijn inhoudelijk afgehandeld, evenals aanvullende auteurs-, rang-, spelling- en conditievarianten. Zeven gelijknamige paren blijven afzonderlijk omdat zij verschillende taxa of determinatie-eenheden betekenen. Alle oorspronkelijke waarden en bronkoppelingnummers zijn behouden; oude taxonnummers en UUIDs blijven met hun oorspronkelijke context herleidbaar. Meetrecords, perioden, locatiekwaliteit, rechten en analysegeschiktheid zijn niet veranderd. Back-up, fusieproef, terugdraaien, volledig herstel en levende nacontrole zijn geslaagd. De overige 251 tabellen en alle 16 viewuitkomsten zijn ongewijzigd. Alle 21.710 geteste bestaande bronidentiteiten vinden bij herhaling hun bestaande koppeling terug. De importpoort blokkeert onbesliste nieuwe naamvarianten. Er is niets naar de VPS gepubliceerd. Selectie, de zeven uitzonderingen en herstelbewijs staan in `docs/database/TAXONREGISTER.md`.

De aanvulling maakt overeenkomsten tussen bronnen vindbaar. In twee stappen hebben 2.509 bestaande registraties alsnog een primaire soortgroep gekregen, waarvan 1.226 in de laatste stap. Alle 87 eerder onopgeloste PQ-naamteksten uit 1981–2025 zijn onderbouwd met code, wetenschappelijke en Nederlandse naam uit Floranld_2020. Deze openbare Turboveg-referentielijst, aangeboden op 10 maart 2026 via www.synbiosys.alterra.nl/turboveg/, bevat 17.468 codes. De oorspronkelijke PQ-waarden en eerdere besluiten blijven behouden.

Alle 12.173 verschillende wetenschappelijke naamteksten zijn bij GBIF opgezocht. Uitsluitend die naamteksten zijn verstuurd, geen vindplaatsen, tellingen of persoonsgegevens. Via 917 gedeelde naamreferenties zijn nu 1.819 bestaande bronregistraties met elkaar in verband te brengen. Iedere referentie verbindt minstens twee oorspronkelijke datasets. Het zijn onderbouwde zoekverbindingen, geen bevestiging dat historische bronnen precies dezelfde soortafbakening gebruiken. Alle nieuwe koppelingen blijven daarom kandidaat met onbekende conceptrelatie; er zijn geen metingen samengevoegd.

De geraadpleegde Catalogue of Life-lijst via GBIF is een naam- en classificatiereferentie, geen nieuwe waarnemingsbron. Uitgever is de Catalogue of Life Foundation; de metadata vermelden CC BY 4.0 en DOI 10.48580/dgyy9. Omdat de dienstmetadata verschillende versielabels bevatten, zijn de feitelijke antwoorden van 27 september 2026, hun ophaaltijden en bestandshashes vastgelegd. Die bewaarde antwoorden bepalen de gebruikte versie. Darwin Core en TDWG TCS blijven de toetsingsbasis.

De eerdere beoordeling liet 278 bronregistraties zonder primaire groep. Na centralisatie en de onderbouwde fusies zijn er 235 centrale naamvermeldingen zonder primaire groep, plus het onbepaalde operationele collectieobject. Dit zijn andere teleenheden: oorspronkelijke bronregistraties blijven bij hun centrale bestemming bewaard. De ontbrekende groep betreft onder meer de scheiding schimmels/korstmossen, onvolledige classificatie, verzamelbegrippen en slijmzwammen die niet bij de huidige groepsomschrijving passen. De oorspronkelijke reden blijft per bronregistratie vastgelegd. Dit staat los van dubbelingen: een geforceerde groepskeuze zou de gegevens niet betrouwbaarder maken. Een ontbrekende groep sluit geen waarneming uit van de centrale zoekroute.

Twee oorspronkelijke actieve bronbesluiten blijven inhoudelijk onbeoordeeld en zonder biologisch doeltaxon. Naturalis-Indet. benoemt geen taxon; zijn ene collectieobject uit 2018 is nu via een aanvullende, uitdrukkelijk onbepaalde operationele koppeling centraal bereikbaar. Bij Toendrarietgans ontbreekt de wetenschappelijke bronnaam en strookt lokale code 1582 niet met de actuele EURING-code 01574. Deze bronregel wordt alleen gebruikt in twee beleidsreferentierijen en niet in vogelwaarnemingen; een nieuwe waarneming met deze onopgeloste sleutel wordt geweigerd. De 263 oorspronkelijke vogelnaamgebruiken, koppelingnummers en bronbesluiten zijn volledig bewaard. De eerdere registeraanvulling en taxonfusie en de huidige volledige waarnemingskoppeling zijn afzonderlijk gecontroleerd. Website, dashboard en Shiny zijn niet aangepast. Details en herstelbewijs staan in docs/database/TAXONREGISTER.md.

## Overkoepelende analysegeschiktheid

De database bevat vanaf 26 september 2026 één bronoverstijgende
beoordelingslaag. Deze laag kopieert geen waarnemingen. Zij verwijst naar de
bestaande brontabellen en legt per gegevensreeks vast welke analyses zijn
toegestaan en onder welke voorwaarden.

De vijf vaste analysetypen zijn:

- **V**: voorkomen en verspreiding;
- **I**: inventarisatie binnen een aantoonbaar onderzocht bezoek, monster of gebied;
- **TV**: verandering in verspreiding of bezetting;
- **TA**: verandering in aantallen, dichtheid of een aantalsindex; en
- **TK**: verandering in een vooraf gedefinieerde ecologische kwaliteitsmaat.

De letter zegt alleen welk soort analyse wordt bedoeld. Zij is geen algemeen
kwaliteitsoordeel. Daarom bewaart de catalogus daarnaast afzonderlijk de
ruimtelijke kwaliteit, bezoekstructuur, beschikbaarheid van nulwaarnemingen,
methode-informatie, validatiestatus en beveiliging. Per analysetype luidt het
besluit `toegelaten`, `voorlopig_toegelaten`, `alleen_context` of
`niet_toegelaten`, steeds met een concrete voorwaarde en kwaliteitsmelding.

De tabellen `analyse_datareeks` en `analyse_datareeks_geschiktheid` bevatten de
beoordeling op reeksniveau. Alleen records die daarvan afwijken komen in
`analyse_recorduitzondering`. De view `v_analyse_catalogus` is de volledige
ingang; `v_analyse_selectieadvies` geeft het compacte overzicht per reeks en
analysetype. Voor NDFF wordt de bestaande actuele v4-classificatie rechtstreeks
in deze view getoond. De 1.040 NDFF-protocolbesluiten worden dus niet opnieuw
opgeslagen.

Met **beheerder** wordt hieronder de primaire bronorganisatie of uitgever bedoeld voor zover die nu bekend is. Het is geen afzonderlijke uitspraak over juridisch eigendom of auteursrecht.

## Beheerregel

Iedere ontdekking, levering, import, verplaatsing, uitsluiting of nieuwe beoordeling van een Meijendel-gegevensbron wordt in dit document verwerkt. Dat geldt ook wanneer eigenaar, omvang, periode, locatiekwaliteit, rechten, overlap, validatiestatus of statistische bruikbaarheid verandert. Daarbij worden steeds de analytische database MySQL Meijendel, de MySQL contextdatabase Meijendel_bronnen en de kandidaatbronnen gezamenlijk gecontroleerd. Iedere wijziging van Meijendel vereist ook de volledige voor- en nacontrole van de bereikbaarheid van alle soortwaarnemingen via het centrale taxonregister. De Markdown-versie is leidend; de Wordversie wordt in dezelfde wijziging inhoudelijk gelijkgetrokken, gerenderd en gecontroleerd.

## 1. Bronnen in MySQL-database `Meijendel`

### 1.1. Vogelgegevens van Vogelwerkgroep Meijendel en SOVON

**Omvang en periode.** De database bevat 1.097.599 vogelwaarnemingen uit 1958–2025. De oorspronkelijke telgebieden, bezoeken, protocollen en aantallen zijn beschikbaar. Het betreft territoriumgegevens vanaf 1958, bezoekwaarnemingen van wintertellingen vanaf seizoen 2000/2001 en bezoekwaarnemingen van BMP-tellingen vanaf 2009.

**Beheerder.** Vogelwerkgroep Meijendel en SOVON.

**Gebruik.** Trends, verspreidingsveranderingen, fenologie en relaties met vegetatie, weer en beheer kunnen verantwoord worden onderzocht, mits veranderingen in methode en dekking expliciet worden verwerkt.

**Status.** Analyseklaar en primaire bron.

**Aanvullende SOVON-jaarleveringen, 2 oktober 2026.** Op de T7 staan voor ieder jaar uit 1984–2025 twee aanvullende officiële SOVON/AVIMAP-werkboeken: 42 territoriummatrices en 42 werkboeken met totalen per bezoek, samen 84 Excelbestanden. Iedere jaarmap bevat daarnaast een puntlaag met individuele bezoekwaarnemingen en een puntlaag met territoria. De waarnemingslagen bevatten samen 623.264 punten uit 2007 en 2009–2025; de territoriumpuntlagen bevatten 126.682 punten uit dezelfde jaren. Voor 1984–2006 en 2008 zijn beide puntlagen leeg. Alle werkboeken zijn leesbaar en bevatten uitsluitend het jaarlabel van de betreffende jaarmap; in de hoofdmap zijn geen losse Excelbestanden achtergebleven. Tracks en de actuele SOVON-gebiedspolygonen worden niet opgenomen. Het lopende jaar 2026 valt buiten deze afgeronde reeks.

De 42 territoriummatrices bevatten 222.852 plot-soortregels: 52.450 positieve resultaten, 86.983 expliciete nulcellen en 83.419 lege cellen. Een lege cel geldt niet als nul. De puntlagen bevatten 22.305 bronwaarnemingen die nog niet in `dagwaarnemingen_bmp` staan; omgekeerd ontbreekt geen bestaande SOVON-bron-ID in de nieuwe levering. Bij 2.629 gedeelde bron-ID's levert SOVON broedcode 0 terwijl de database `NULL` bevat. De downloads bevatten geen zelfstandig veld dat een telling formeel als afgekeurd markeert. Vergelijking en eventuele verrijking volgen daarom per jaar. Daarbij worden BMP-type, standaard alle soorten of een expliciete uitzondering, volledig geteld, goedgekeurd of formeel afgekeurd en de toepasselijke officiële soortenlijst afzonderlijk vastgelegd. Broedcode 0 blijft een positieve vogelwaarneming. Tellercodes worden per jaar gecontroleerd.

**Jaarcontrole 1984, 2 oktober 2026.** De SOVON-download bevat 230 bezoeken in 16 plots. Alle 230 bezoeken zijn inhoudelijk gelijk aan de 230 bezoeken onder bron `sovon_m` in `dagbezoeken_bmp`; er is daarom geen bezoek toegevoegd. Voor 15 bezochte plotjaren bevat de download 568 positieve vogelcellen met samen 7.811 territoria, 860 letterlijke nulcellen en 18 lege soortcellen. Van de 568 positieve waarden zijn 562 exact gelijk aan de bestaande SOVON-regels in `territoria`. De 860 letterlijke nullen zijn als regels met `territoria = 0` en SOVON als bron rechtstreeks aan `territoria` toegevoegd. De 18 cellen zijn leeg binnen plotjaren die voor andere soorten wel resultaten bevatten; zij zijn niet ingevoerd en gelden niet als nul. De 40 geselecteerde maar niet-bezochte plots met 3.497 uitsluitend lege vogelcellen zijn genegeerd.

Voor M35 bevat de SOVON-download acht bezoeken en 49 lege vogelcellen, zonder positieve waarde of letterlijke nul. De levende database bevat dezelfde acht bezoeken onder `sovon_m`, geen territoriumregel onder `sovon_m`, en 13 afzonderlijke regels met samen 106 territoria onder `jrvslg_m`. Het verslag over 1983-1985 stelt dat de resultatentabel 1984 uitsluitend BMP-getelde kavels omvat. Kavel 35 staat in de bezettingslijst bij J. Bosland en heeft resultaten in die tabel. De lege SOVON-cellen betekenen dus niet dat M35 niet is geteld en zijn geen nullen; de SOVON-resultaten ontbreken. De jaarverslagregels blijven buiten deze SOVON-verwerking. De zes overige positieve verschillen zijn meeuwenwaarden voor M7, M8, M4-5 en M16s. Zij zijn niet als SOVON-regel toegevoegd, omdat `meeuwen_literatuur` voor deze zes plot-soortcombinaties leidend blijft in `territoria`.

**Jaarcontrole 1985, 3 oktober 2026.** De SOVON-download bevat 323 bezoeken in 24 plots; alle 323 komen veld voor veld overeen met `dagbezoeken_bmp`. De vogelmatrix bevat 864 positieve waarden, 1.386 letterlijke nulcellen en 2.742 lege cellen. Van de positieve waarden zijn 855 gelijk aan bestaande SOVON-regels. De negen overige positieve waarden zijn meeuwenaantallen voor M7, M16, M8 en M16s en zijn niet toegevoegd, omdat `meeuwen_literatuur` voor die combinaties leidend blijft. Van de 1.386 letterlijke nullen zijn 1.385 als `territoria = 0` met SOVON als bron toegevoegd. De ene uitgesloten nul is M4-5/Zilvermeeuw: SOVON levert 0, terwijl `meeuwen_literatuur` 55 territoria bevat. De leidende literatuurwaarde blijft staan. De 22 lege cellen binnen twaalf plots met overige resultaten, de 49 uitsluitend lege M35-cellen en de 2.671 lege cellen in 32 niet-bezochte plots zijn niet ingevoerd.

De SOVON-download bevat voor 1985 geen bezoekwaarnemingen, territoriumpunten, formele afkeuringsaanduiding of tellercodes. Er is daarom niets toegevoegd aan `dagwaarnemingen_bmp` en geen broedcode 0 hersteld. Het verslag bevestigt dat J. Bosland M35 telde en dat kavel 16 bij J.P. Oppentocht hoorde. Op besluit van de data-eigenaar zijn daarom drie ontbrekende regels aan `plot_jaar_teller` toegevoegd: 1985/M35–B_0042 en 1984 en 1985/M16s–A_0042. De al aanwezige regels 1984/M35–B_0042 en 1984 en 1985/M16–A_0042 zijn behouden; er is niets verplaatst of gedupliceerd.

**Jaarcontrole 1986, 3 oktober 2026.** De SOVON-download bevat 305 bezoeken in 25 plots; alle 305 komen op bron-ID en inhoud overeen met `dagbezoeken_bmp`. De vogelmatrix bevat 925 positieve waarden, 1.422 letterlijke nulcellen en 2.645 lege cellen. Van de positieve waarden zijn 919 gelijk aan bestaande SOVON-regels. De zes overige positieve waarden zijn meeuwenaantallen voor M7, M16 en M8 en zijn niet toegevoegd, omdat `meeuwen_literatuur` voor die combinaties leidend blijft. Van de 1.422 letterlijke nullen zijn 1.417 als `territoria = 0` met SOVON als bron toegevoegd. De vijf uitgesloten nullen betreffen Stormmeeuw, Kleine Mantelmeeuw en Zilvermeeuw op M14 en Stormmeeuw en Zilvermeeuw op M4-5; `meeuwen_literatuur` bevat daar positieve aantallen. De 27 lege cellen binnen plots met overige resultaten, de 49 uitsluitend lege M35-cellen en de 2.569 lege cellen in 31 niet-bezochte plots zijn niet ingevoerd.

Het bezoektotalenbestand vermeldt bij 927 soort-plotregels telkens één niet-bruikbare waarneming, dus 927 aggregaatvermeldingen, maar bevat geen individuele bron-ID, bezoek, datum, broedcode, locatie of formele afkeurstatus. De lege puntlagen en het lege standaardbestand `resultaten.xlsx` leveren evenmin individuele regels. Deze vermeldingen zijn daarom niet als formeel afgekeurde waarnemingen in `dagwaarnemingen_bmp` gereconstrueerd. M66 HGC bevat 15 bezoeken en 45 positieve SOVON-regels met samen 336 territoria. Voor dit plotjaar ontbreekt een tellercode in zowel de download als `plot_jaar_teller`; ook het jaarverslag noemt M66 HGC niet. Het tellerveld blijft daarom leeg. M35 bevat zeven bezoeken en 49 lege matrixcellen. Het jaarverslag bevat 17 regels met samen 156 territoria en `meeuwen_literatuur` twee Stormmeeuwterritoria, samen gelijk aan het verslagtotaal van 158; deze afzonderlijke bronnen zijn niet als SOVON-regels ingevoerd.

**Jaarcontrole 1987, 3 oktober 2026.** De SOVON-download bevat 328 bezoeken; alle 328 komen op bron-ID en inhoud overeen met `dagbezoeken_bmp`. De vogelmatrix bevat 1.088 positieve waarden, 1.788 letterlijke nulcellen en 2.116 lege cellen. Van de positieve waarden zijn 1.081 gelijk aan bestaande SOVON-regels. De zeven overige positieve waarden zijn Stormmeeuw, Kleine Mantelmeeuw en Zilvermeeuw op M15 en M16 en Kleine Mantelmeeuw op M8. Zij zijn niet toegevoegd, omdat `meeuwen_literatuur` voor deze combinaties leidend blijft. Alle 1.788 letterlijke nullen waren niet-conflicterend en zijn als `territoria = 0` met SOVON als bron toegevoegd. De 32 lege cellen binnen bezochte plots met overige resultaten, de 49 uitsluitend lege M35-cellen, de twee lege M8-cellen en de 2.033 lege cellen in 25 niet-bezochte plots zijn niet ingevoerd.

Het bezoektotalenbestand vermeldt bij 1.091 soort-plotregels telkens één niet-bruikbare waarneming, dus 1.091 aggregaatvermeldingen, maar bevat geen individuele bron-ID, bezoek, datum, broedcode, locatie of formele afkeurstatus. Deze vermeldingen zijn daarom niet als formeel afgekeurde waarnemingen gereconstrueerd. Voor M66 HGC ontbreekt een tellercode in zowel de download als `plot_jaar_teller`; dit veld blijft leeg. De overige 29 plots met resultaten hebben al een database-tellercode. M8 heeft 41 positieve waarden, 57 letterlijke nullen en twee lege cellen, maar geen bezoekregels in de SOVON-download of `dagbezoeken_bmp`. Het jaarverslag noemt R. Wanders als teller en twaalf BMP-bezoeken; de bestaande databasecode `RWNS00` blijft staan. De twaalf verslagbezoeken zijn niet als SOVON-bezoeken gereconstrueerd. M35 heeft zeven SOVON-bezoeken maar uitsluitend 49 lege matrixcellen. In de database staan voor M35 zeventien jaarverslagregels met samen 54 territoria en één `meeuwen_literatuur`-regel met 64 territoria; deze bronnen blijven gescheiden van SOVON.

**Jaarcontroles 1988-2004, 3 oktober 2026.** De zeventien SOVON-downloads bevatten samen 5.141 in-scope bezoeken. Alle 5.141 stonden al op bron-ID en inhoud gelijk in `dagbezoeken_bmp`; er is geen bezoek toegevoegd of gewijzigd. De matrices bevatten na uitsluiting van De Horsten samen 19.197 positieve SOVON-resultaten. Die waren gelijk aan de bestaande SOVON-regels, behoudens meeuwencombinaties waarvoor een aanwezige regel uit `meeuwen_literatuur` leidend bleef. In `territoria` zijn per jaar uitsluitend de volgende aantallen letterlijke, niet-conflicterende SOVON-nullen toegevoegd: 1988 1.444; 1989 1.512; 1990 1.622; 1991 1.761; 1992 1.739; 1993 2.057; 1994 1.838; 1995 1.811; 1996 1.797; 1997 1.829; 1998 1.834; 1999 1.873; 2000 1.773; 2001 1.846; 2002 1.884; 2003 1.854; 2004 1.984. Samen zijn dit 30.458 nieuwe regels. `territoria` bevat daarna 106.921 regels. Alle nieuwe nulregels zijn via `soorten`, `taxa_bronkoppeling`, `taxa` en `taxon_groepen` als vogels bereikbaar; de jaarlijkse databasebrede nacontrole omvat 128 routes en geeft nul fouten.

In 1991 zijn vier SOVON-meeuwennullen niet ingevoerd omdat voor dezelfde plot-soortcombinatie een positieve, leidende waarde uit `meeuwen_literatuur` bestaat. Een retroactieve afwezigheidscontrole over 1984-2004 houdt 1.309 `jrvslg_m`-regels en 70 `meeuwen_literatuur`-regels bewust in stand: de SOVON-matrix bevat voor die combinaties geen positieve of letterlijke nulwaarde, en ontbreken in de download is geen wijzigings- of verwijderingsgrond. Jaarverslagen zijn ieder jaar gebruikt om ontbrekende tellers en andere bronverschillen te verklaren. In 1988-2004 leverde dit geen ontbrekende tellerkoppeling op; waar database en download geen teller bevatten, noemde ook het verslag geen ondubbelzinnig aan een bestaande code koppelbare waarnemer voor dat plotjaar.

De Horsten behoort niet tot Meijendel. Uit de download van 1996 zijn daarom negen bezoeken, 41 positieve resultaten met samen 636 territoria, 30 letterlijke nullen en vier lege cellen volledig genegeerd. De uitsluitend lege selecties van De Horsten in volgende jaren zijn eveneens buiten de vergelijking gehouden. Voor 2000 verklaart het jaarverslag de lege SOVON-resultaten van M35: de werkgroep telde M35 en M36 wel, maar stuurde die resultaten dat jaar niet aan SOVON. De bestaande `jrvslg_m`-regels blijven daarom staan; uit de lege SOVON-cellen is niets afgeleid.

**Controlejaar 2005, afgerond.** De 111 geleverde bezoeken staan veld voor veld gelijk in `dagbezoeken_bmp`; 1.156 positieve vogelresultaten zijn gelijk. De 1.999 letterlijke, niet-conflicterende vogelnullen zijn in `territoria` opgenomen; 1.766 lege cellen niet. De puntenlaag bevat nul features. Het bezoektotalenbestand bevat daarnaast 101 positieve zoogdierregels op 58 bestaande BMP-bezoeken in zeven plots: Konijn 46 regels met totaal 241, Ree 34 met totaal 89, Vos 15 met totaal 22, Eekhoorn vijf met totaal 6 en Dwergspitsmuis één met totaal 1. Twintig waarden waren al gelijk. De overige 81 SOVON-regels met 284 dieren op 46 bezoeken zijn afzonderlijk opgenomen onder `sovon-bmp-jaarbestanden-v1`; daaronder vallen ook de twee afwijkende Konijnwaarden in M16. Bezoek 365793 bevat SOVON 2 naast NDFF 9 en bezoek 365789 bevat SOVON 1 naast NDFF 3. Het NDFF-auditspoor blijft staan; SOVON is bij gecombineerd gebruik leidend. Er zijn geen zoogdiernullen afgeleid.

**Controlejaar 2006, afgerond.** De 172 geleverde bezoeken staan veld voor veld gelijk in `dagbezoeken_bmp`; 1.069 positieve vogelresultaten zijn gelijk. De 1.865 letterlijke, niet-conflicterende vogelnullen zijn in `territoria` opgenomen; 1.987 lege cellen niet. De puntenlaag bevat nul features. Het bezoektotalenbestand bevat 159 positieve zoogdierregels. Daarvan waren 36 gelijk. Onder `sovon-bmp-jaarbestanden-v1` zijn 123 aanvullende regels met samen 523 dieren op 72 bezoeken opgenomen zonder nulafleiding. Daaronder staan acht afwijkende SOVON-bezoektotalen naast het NDFF-auditspoor; SOVON is bij gecombineerd gebruik leidend.

**Controlejaar 2007, afgerond.** De 172 geleverde bezoeken staan veld voor veld gelijk in `dagbezoeken_bmp`; 1.166 positieve vogelresultaten zijn gelijk. Alle 1.924 letterlijke vogelnullen zijn in `territoria` opgenomen; 1.831 lege cellen niet. Het bezoektotalenbestand bevat 249 positieve zoogdierregels. Daarvan waren 101 al gelijk. Onder `sovon-bmp-jaarbestanden-v1` staan 148 aanvullende regels met 692 dieren op 84 bezoeken, inclusief de elf afwijkende SOVON-bezoektotalen. Het historische NDFF-auditspoor blijft bestaan; SOVON is bij gecombineerd gebruik leidend en beide waarden worden niet opgeteld. Voor M6 vermeldt de download teller `JASQ00`. Het verslag noemt T. Lansink voor M6 en M61 en J. van As voor M83; de database koppelt M6 en M61 aan `ALNK00` en M83 aan `JASQ00`. De downloadcode bij M6 is daarom niet overgenomen.

**Controlejaren 2008-2022, afgerond.** De vijftien downloads bevatten 6.306 in-scope bezoeken. Zij staan alle al in `dagbezoeken_bmp`; bij 154 bezoeken verschilt uitsluitend afsluitende witruimte in `opmerking`, zodat geen bezoek is gewijzigd. Aan `territoria` zijn 37.213 letterlijke, niet-conflicterende SOVON-nullen toegevoegd. Lege cellen zijn niet ingevoerd. Bestaande Meijendelwaarden die in de download ontbreken zijn behouden. De 81 positieve downloadwaarden uit 2022 voor M105, M71 en M36 staan al met exact dezelfde aantallen onder `jrvslg_m`; een tweede SOVON-kopie is daarom niet gemaakt. Voor 2008-2022 staan 3.929 aanvullende positieve zoogdierregels op 2.334 bezoeken onder `sovon-bmp-jaarbestanden-v1`. Alle bronwaarden zijn na invoer gelijk aan de downloads; er zijn geen zoogdiernullen afgeleid.

**Controlejaren 2023-2025, afgerond.** De drie downloads bevatten 1.367 in-scope bezoeken. Zij staan alle al in `dagbezoeken_bmp`; bij 24 bezoeken verschilt uitsluitend afsluitende witruimte in `opmerking`. Aan `territoria` zijn 8.012 nieuwe letterlijke nulregels toegevoegd. M53/Zwarte Kraai 2023 is na afzonderlijk akkoord van één naar nul gecorrigeerd: de kavelmatrix levert nul en het enige territoriumpunt, met aantal 1 en broedcode 2, heeft `inplot = 0`. Het punt blijft als bron- en auditgegeven behouden. Voor 2023-2025 zijn 1.171 aanvullende positieve zoogdierregels op 886 bezoeken toegevoegd, inclusief buiten-plotwaarden; geen zoogdiernullen zijn afgeleid. Het verslag 2024 koppelt M75 aan Patricia van Veen. De bestaande code `ANBN01` is daarom voor M75/2024 toegevoegd. Voor M51/2025 blijft de teller leeg: er is geen lokaal jaarverslag 2025 en de exportcode geldt niet zelfstandig als tellerbewijs. De positieve SOVON-resultaten voor M75/2024 en M51/2025 bleven bij deze bestandsvergelijking aanvankelijk staan, maar zijn na de afzonderlijke actuele statuscontrole van 3 oktober 2026 alsnog verwijderd omdat beide plotjaren op sovon.nl oranje-rood en afgekeurd staan. M84s/2025 is eveneens formeel afgekeurd; daarvoor stonden geen territoriumregels in de database.

Vanaf 3 oktober 2026 geldt als hoofdregel dat alle werkelijk aanvullende SOVON-gegevens in de bestaande Meijendel-kerntabellen mogen worden opgenomen. Bestaande Meijendelgegevens blijven staan wanneer zij in de download ontbreken. Alleen een afzonderlijke conflictregel kan daarvan afwijken. Een aanwezige regel uit `meeuwen_literatuur` blijft voor meeuwen leidend; zonder zo'n regel mag de SOVON-waarde aanvullen of corrigeren. Een ontbrekende teller mag vanuit het jaarverslag worden toegevoegd wanneer kavel en waarnemer ondubbelzinnig zijn en een bestaande code beschikbaar is. De Horsten wordt volledig genegeerd. Niet-conflicterende letterlijke SOVON-nullen worden zonder nieuwe jaarbeslissing opgenomen; niet tot individuele bronregels herleidbare aggregaatvermeldingen worden niet als formeel afgekeurde waarnemingen gereconstrueerd. Ieder jaar wordt eerst volledig vergeleken. Nieuwe soortenconflicten, nieuwe gegevensmodellen en wel individueel herleidbare afkeuringsinformatie blijven afzonderlijke beslispunten.

De data-eigenaar heeft op 2 oktober 2026 besloten de actuele officiële SOVON BMP-A-soortenlijst vanaf 1984 toe te passen. Lijstversie `sovon-bmp-a-actueel-retroactief-vanaf-1984-v1` gebruikt het officiële PDF-bestand met SHA-256 `3af7adf5febb2164d554246882ead82d93efd9bb505b8c195fc842e09fa67b39`. De volledige lijst bevat 264 officiële namen. Daarvan zijn 240 op exacte naam en negen via een vastgelegde naamvariant gekoppeld aan het centrale taxonregister. Vijftien officiële lijstnamen blijven uitsluitend als lijstmetadata bewaard, omdat geen verantwoorde centrale identiteit kon worden vastgesteld; zij zijn dus geen waarnemingsregels. Zestien historische matrixcategorieën die niet op de actuele lijst staan, zijn als expliciet uitgesloten bewaard. De retroactieve BMP-A-toepassing is geen taxonomische conceptfusie.

De aanvankelijk aangelegde ontvangsttabellen met kopieën van bezoeken en resultaten zijn op 2 oktober 2026 verwijderd. Over blijven vijf `sovon_bmp_*`-tabellen met uitsluitend niet elders aanwezige vergelijkingsmetadata: jaarlevering, plotjaarvoorwaarden, tellercodes, soortenlijstversie en soortenlijstnamen. Na afronding van de jaarvergelijking en de actuele SOVON-statuscontrole 1984-2025 bevat `territoria` 157.580 regels uit 1958-2025. Daarvan zijn 138.917 regels uit bron `sovon_m` in 1984-2025: 52.224 positieve waarden en 86.693 letterlijke nullen. `dagbezoeken_bmp` bevat voor 1984-2025 alle 14.455 in-scope SOVON-bezoeken uit de downloads; `dagwaarnemingen_bmp` bevat 600.959 vogelrecords. De download is dus geen tweede in te voeren gegevenslaag: per jaar is hij met de bestaande kerntabellen vergeleken en alleen een vastgesteld, besloten aanvullend gegeven heeft tot een wijziging geleid. De afgeleide dump, het exportmanifest en de lokale Shiny-cache zijn op 3 oktober 2026 na een geslaagde proefimport vernieuwd onder SQL-hash `57dea9216785c7c743ff2b7f6dfb06bf8af4bd7c74928b6d7560e7698ab69b83`; er is niets naar de VPS gepubliceerd.

De 860 ingevoerde nullen zijn uitsluitend letterlijke nulcellen uit de SOVON-matrix. Op 3 oktober 2026 is besloten dat `territoria` alleen werkelijk door de bron geleverde territoriumwaarden bevat; afgeleide gegevens worden niet in deze tabel opgenomen. Voor de 249 centraal gekoppelde officiële BMP-A-lijstsoorten en de 15 plotjaren met resultaten zijn 3.735 plot-soortcombinaties mogelijk; 2.338 daarvan ontbreken geheel uit de matrix en blijven buiten `territoria`. Ook de 225 ontbrekende combinaties van de 15 nog niet centraal gekoppelde officiële lijstnamen en de 15 plotjaren blijven buiten `territoria`. BMP-type, volledigheid, soortenlijst en overige protocolmetadata kunnen dus wel worden gebruikt voor controle en analyse, maar nooit om in `territoria` een ontbrekende bronregel als nul aan te maken.

Voor kavel 16 vermeldt het verslag dat in 1984 alleen het centrale deel is geïnventariseerd. De bestaande geaccepteerde historische kavelmapping koppelt `16S` aan SOVON-plot 29456 (`M16s`). Dit past bij de download: M16s bevat 15 bezoeken en 90 vogelcellen, waarvan 47 positief, 42 expliciete nul en één leeg; M16 bevat geen bezoeken en 99 lege cellen. Op besluit van de data-eigenaar is de bestaande teller A_0042 daarom voor 1984 ook aan M16s gekoppeld. De bestaande historische tellerregel op M16 is niet verplaatst of verwijderd. De volledige centrale nacontrole na de 1985-verwerking omvat 128 taxonroutes en geeft nul fouten.

**Taxonomische ontsluiting, 27 september 2026.** De 263 gebruikte vogelcategorieën uit `soorten` hebben ieder een voorlopig naamgebruik in `taxa` en een kandidaat in `taxa_bronkoppeling`. De koppelproef omvat 71.155 territoriumregels (1958–2025), 600.959 BMP-regels (2007–2025) en 105.712 wintertelregels (2000–2025). Dit is een afgebakende controle van deze drie tabellen, niet een nieuwe telling van alle vogelbronnen. Bron-IDs en letterlijke cataloguswaarden blijven behouden. De kandidaten leggen nog geen gelijkheid met externe taxonconcepten vast; brongegevens, analytische status en gebruik door website, dashboard en Shiny veranderen niet.

**Telleridentificatie, bijgewerkt 3 oktober 2026.** Voor telleridentificatie is `plot_jaar_teller` in de levende lokale database de leidende projectregistratie. Een vergelijking met `waarnemer` uit de actuele SOVON/AVIMAP-resultatendownload omvat 25.555 soortresultaten in 752 plotjaren uit 2007 en 2009–2026. In 282 plotjaren is de ene AVIMAP-code exact gelijk aan de databasecode, in 56 is zij lid van een groter geregistreerd tellerteam, in 400 ontbreekt zij geheel in het geregistreerde team en voor 14 plotjaren ontbrak aanvankelijk `plot_jaar_teller`. Inhoudelijke controle door de data-eigenaar toont concrete AVIMAP-toeschrijvingen aan kavels die de genoemde waarnemer niet heeft geteld. Het AVIMAP-veld wordt daarom niet gebruikt om `plot_jaar_teller` te vervangen, aan te vullen of te corrigeren; het blijft uitsluitend als letterlijke bronwaarde en auditinformatie behouden. Deze beperking betreft alleen telleridentificatie en keurt de territorium- en bezoekgegevens uit de download niet als geheel af. Bij meerdere tellers blijft een plotjaar een teamregistratie. Omdat de AVIMAP-bezoekentabel geen teller bevat, wordt zonder andere expliciete bron niet afgeleid wie aan een afzonderlijk bezoek deelnam. Tellersensitiviteitsanalyses gebruiken `plot_jaar_teller` en houden tellerteams en ontbrekende koppelingen afzonderlijk herkenbaar. Op basis van inhoudelijke vaststelling door de data-eigenaar zijn vier koppelingen op 1 oktober toegevoegd: 2010/M54a–AZNA00 (`plot_id` 12381), 2012/M66–WCLE00 (`plot_id` 3503), 2018/M34–B_0097 (`plot_id` 3496) en 2018/M8–B_0098 (`plot_id` 3530). Op 3 oktober zijn na controle van de jaarverslagen 1985/M35–B_0042 en 1984 en 1985/M16s–A_0042 toegevoegd. Het verslag 2024 noemt Patricia van Veen ondubbelzinnig als teller van M75; de bestaande code `ANBN01`, die ook in 2025 en 2026 aan M75 is gekoppeld, is daarom voor 2024 toegevoegd. `plot_jaar_teller` bevat nu 2.458 regels.

**Goedkeuringsstatus territoria, actueel 3 oktober 2026.** De inhoudelijke regel is dat `territoria` voor afgekeurde SOVON-tellingen geen actieve SOVON-uitkomsten bevat. De eerdere tussenstand van elf afgekeurde plotjaren is vervangen door een volledige visuele controle van 55 Meijendel-plots op sovon.nl voor 1984-2025; De Horsten is genegeerd. Daaruit volgen 25 formeel afgekeurde plotjaren met bezoeken of records: M35/1984-1988, M35/2000, M53/2007, M8/2008, M35 en M36/2009, M105 en M54a/2012, M53/2015, M34, M45, M8, M54b en M55/2018, M78/79/2019, M61/2021, M75 en M1a/2022, M75/2024 en M51 en M84s/2025. Zij staan met `beoordelingsstatus = formeel_afgekeurd` in `sovon_bmp_plotjaar`. De 373 SOVON-regels met samen 756 territoria voor M8/2008, M45/2018, M8/2018, M75/2024 en M51/2025 zijn na een herstelde en geteste back-up uit `territoria` verwijderd. Geen van de 25 plotjaren bevat nog een `sovon_m`-regel. Wel blijven voor M35 in 1984-1987 en 2000 60 regels uit `jrvslg_m` en vier uit `meeuwen_literatuur`, samen 481 territoria, volgens de afzonderlijke bronregels behouden. Bezoeken en individueel herleidbare waarnemingen blijven in de kerntabellen als auditspoor.

M8/2019 staat bij de actuele controle groen en vervangt daarom de eerdere afkeuringsbeslissing. De 10 bezoeken en 483 vogelwaarnemingen stonden al in de database. Uit het SOVON-standaardresultatenbestand zijn 19 positieve regels met samen 114 territoria hersteld. De 107 matrixcellen zijn allemaal leeg; er is daarom geen nul toegevoegd. De twaalf overige oranje-rode combinaties zonder bezoeken, soorten of records bevatten in de downloads samen 980 uitsluitend lege matrixcellen en nul standaardresultaten, bezoeken, waarnemingspunten en territoriumpunten. Zij zijn niet als afgekeurde telling en ook niet als plotjaarrecord vastgelegd. M35/2004 bevat wel 20 bestaande regels uit `jrvslg_m`, samen 44 territoria; die niet-SOVON-bron blijft ongemoeid.

M53/2007 vraagt een afzonderlijke beperking. SOVON toont 8 bezoeken, 36 soorten en 36 records, maar de acht bezoeken bevatten elk nul soorten en nul exemplaren; de detailpagina geeft aan dat uitsluitend territoriumlocaties zijn ingevoerd. De jaar-download bevat 99 lege matrixcellen en geen standaardresultaten, waarnemingspunten of territoriumpunten. De ingelogde interface biedt alleen kaart- en PDF-uitvoer, niet de individuele bron-ID, datum en bezoekkoppeling die nodig zijn voor `dagwaarnemingen_bmp`. Daarom zijn geen individuele waarnemingen gereconstrueerd. `dagbezoeken_bmp` bevat de 8 bezoeken; `dagwaarnemingen_bmp` en `territoria` bevatten voor dit plotjaar nul regels. De status en deze beperking staan wel in `sovon_bmp_plotjaar`.

**Natura 2000-analysescope vogelplots, vastgesteld 1 oktober 2026 en bijgewerkt na de volledige SOVON-controle.** De geldige bronverzameling `territoria` bevat 157.580 regels, 54 plots en 2.164 plotjaren uit 1958-2025. M66 (Haagsche Golf Club, `plot_id = 3503`) bevat daarin 4.323 regels en 10.420 territoria in 39 jaren uit 1985-2025. M91 (Voorlinden, `plot_id = 3514`) bevat 1.674 regels en 4.672 territoria in 18 jaren uit 1993-2021. Beide plots blijven als geldige brondata bewaard, maar hebben in `plot_analyse_scope` onder `meijendel_natura2000` de status `in_scope = 0` met reden `Geen onderdeel van Natura 2000-analysegebied.` De standaardselectie via `v_meijendel_analyseplot_actueel` bevat daardoor 151.583 territoriumregels, 52 plots en 2.107 plotjaren uit 1958-2025. Repositoryberekeningen gebruiken deze scope standaard en nemen M66 en/of M91 alleen mee na een uitdrukkelijke keuze van de gebruiker. `plots.in_gebruik` beschrijft alleen actueel gebruik en bepaalt deze inhoudelijke grens niet.

**Standaard analysepoort territoria, vastgesteld 4 oktober 2026.** Batchanalyse, Shiny en de zelfstandige GEE/power-route gebruiken dezelfde statusgestuurde selectie. Binnen de standaardscope met 151.583 territoriumregels in 52 plots en 2.107 plotjaren uit 1958-2025 is uitsluitend een aanwezige bronregel een analysewaarde. De 86.693 letterlijke `sovon_m`-nullen uit 1984-2025 blijven nul; een ontbrekende soortregel of lege matrixcel blijft `NA`. De 25 formeel afgekeurde SOVON-plotjaren uit 1984-2025 leveren voor SOVON geen analysewaarde. De 60 `jrvslg_m`-regels en vier `meeuwen_literatuur`-regels voor M35 in vijf van die afgekeurde plotjaren blijven als onafhankelijke bronwaarden geldig. M66 en M91 blijven standaard uitgesloten; `plots.in_gebruik` bepaalt deze inhoudelijke scope niet. Een soort komt pas in de analysepopulatie wanneer binnen exact de gebruikte plot-jaar-basis minstens één geaccepteerd positief territorium aanwezig is; nulregels vullen daarna de meetmatrix aan, maar maken op zichzelf geen soort tot analysekandidaat. GEE/GLMM-kenmerkenanalyses nemen zulke nul-only-soorten niet als afzonderlijk cluster op. Een groeps-, richtlijn- of habitatgroeptotaal wordt alleen berekend wanneer alle samenstellende soortcellen voor dat plotjaar een geaccepteerde waarde hebben; een gedeeltelijke som blijft `NA`. De herberekende hoofd-TRIM-uitvoer over 1958-2025 bevat daardoor 156 soorten in de statuslaag, 135 soorten met minimaal één indexreeks en 94 soorten met een brugbare reeks in beide modelperioden. De Sandra-uitvoer over 25 plots in 1997-2022 bevat 132 positief waargenomen soorten en 110 formele soorttrends. Deze poort is ook de standaard voor datasets waarmee de power voor relaties met vegetatieontwikkeling of beheermaatregelen wordt beoordeeld; ontbrekende bronwaarden worden nooit stilzwijgend als afwezigheid gebruikt.

### 1.2. Provinciale permanente kwadraten

**Omvang en periode.** De levering van Provincie Zuid-Holland bevat 254 permanente kwadraten, 2.007 vegetatieopnamen en 53.122 taxonregels uit 1981–2025.

**Beheerder.** Provincie Zuid-Holland.

**Gebruik.** De reeks ondersteunt analyses van vegetatiesamenstelling, bedekking, successie en verandering per permanent kwadraat. Overeenkomende NDFF-regels (zie verder) worden niet als een tweede waarneming geteld.

**Status.** Analyseklaar en primaire bron.

**PQ-integratie, 27–28 september 2026.** De 53.122 provinciale taxonregels uit 1981–2025 zijn lokaal en op de VPS rechtstreeks verbonden met het centrale taxonregister. De 714 oorspronkelijke taxonvermeldingen zijn daar met alle bronvelden behouden; de afzonderlijke PQ-taxoncatalogus is verwijderd. De 2.007 opnamen en de 513 gepubliceerde plot-jaaruitkomsten zijn ongewijzigd. Daarnaast zijn 644 vermoedelijk verwante LVD-bronopnamen met 16.627 resultaten uit 1981–2015 binnen de PQ-tabellen bijeengebracht. Zij behouden alle bronwaarden en 652 mogelijke opnamekoppelingen en tellen niet zelfstandig mee. De oorspronkelijke externe rijen zijn pas na inhoudscontrole verwijderd. De volledige migratie, het terugdraaien en het herstel uit back-up zijn beproefd. De gecontroleerde publicatie naar website, dashboard en Shiny is op 28 september om 15:33 uur geslaagd; hun bestaande provinciale uitkomsten zijn gelijk gebleven.

### 1.3. Zoogdieren tijdens SOVON- en VWG-bezoeken

**Omvang en periode.** De SOVON-levering bevat 19.877 zoogdierwaarnemingen uit 2009–2026. De analysematrix omvat 4.354 bevestigde bezoeken, 30.478 combinaties van bezoek en doelsoort en 23.619 afgeleide nulwaarnemingen. De 807 regels uit 2026 behoren tot een nog niet afgerond jaar.

**Beheerder.** SOVON en Vogelwerkgroep Meijendel.

**Gebruik.** Voor de tijdens deze bezoeken gevolgde zoogdieren, waaronder het konijn, zijn analyses van trefkans, verspreiding en ontwikkeling mogelijk. Bezoeken zonder enige zoogdierregistratie gelden niet automatisch als een bezoek waarop systematisch naar zoogdieren is gekeken.

**Status.** Analyseklaar binnen deze afbakening; de primaire SOVON-bron gaat voor eventuele overeenkomstige NDFF-regels.

**Aanvullende bezoektotalen 2005–2022, 3 oktober 2026.** De vier tabellen `ndff_daz_bmp_*` zijn zonder kopie of gegevensverlies hernoemd naar `daz_bmp_*`. Alle historische rijen, foreign keys, centrale taxonroutes en reconstructieversies zijn behouden. Het schema ondersteunt daarnaast positieve SOVON-bezoektotalen met een afzonderlijk aantal buiten het plot en met `geen_nulafleiding` als expliciete status. Onder `sovon-bmp-jaarbestanden-v1` staan nu 4.281 aanvullende bezoek-taxoncellen op 2.536 bezoeken, met 16.221 dieren binnen en 370 buiten het plot. De 22 betrokken brontaxa zijn via versiegebonden koppelingen centraal bereikbaar; de routes blijven kandidaat/onbekend en leggen geen onbewezen conceptgelijkheid vast. Gelijke bronwaarden zijn niet gedupliceerd. Afwijkende positieve SOVON-bezoektotalen staan met afzonderlijke herkomst naast het NDFF-auditspoor; SOVON is bij gecombineerd gebruik leidend en beide lagen worden nooit opgeteld. Deze bezoekaggregaten blijven afzonderlijk van de 19.877 individuele SOVON/AVIMAP-waarnemingen hierboven.

De 7.552 eerder uit `ndff-daz-bmp-v1` afgeleide nulregels zijn als volledig historisch auditspoor bewaard, maar herclassificeerd als `historische_afgeleide_nul`. De 1.475 bijbehorende bezoeken vermelden expliciet dat de reconstructie geen bewijs van afwezigheid levert. De regels zijn daarmee ongeschikt voor analyses die echte nullen vereisen.

De centrale taxonroute bindt afgeleide bronidentiteiten mede aan de tabelnaam. Daarom zijn ook de 23 gebruikte bronkoppelingen naar `daz_bmp_bezoek_taxon` gemigreerd en zijn alle centrale schrijfguards opnieuw opgebouwd. Geen koppeling werd door een andere waarnemingstabel gedeeld. De volledige controle van 279 tabellen en 128 taxonroutes geeft nul fouten. Twee afzonderlijke tabelback-ups zijn met ongewijzigde SHA-256 teruggelezen in tijdelijke databases; beide herstelproeven reproduceerden exact de vier tabelrijtellingen vóór de betreffende wijziging.

### 1.4. Historisch vangblikonderzoek

**Omvang en periode.** De GBIF-dataset *Meijendel research 1953–1960* bevat 37.770 vangblikevents, 60.560 vangsten, 275 taxa en 99.652 individuen. Per event zijn vangblik, datum, duur en locatie bekend.

**Beheerder.** De historische reeks is afkomstig uit het onderzoek van Piet den Boer en is gepubliceerd als [GBIF Sampling Event Dataset](https://doi.org/10.15468/adsbxs).

**Gebruik.** Binnen 1953–1960 zijn analyses mogelijk van soortensamenstelling, seizoensverloop en ruimtelijke verschillen. Lege events zijn niet voor alle taxa een bewezen nul; verplaatsingen van vangblikken en een methodeproef in de kwaliteitsvelden zijn vastgelegd.

**Status.** Analyseklaar binnen de historische onderzoeksopzet.

**Vangblik-opschoning, 28 september 2026.** De 60.560 vangstregels uit 1953–1960 zijn lokaal rechtstreeks verbonden met het centrale taxonregister. De 275 oorspronkelijke taxonvermeldingen zijn daar met alle bronvelden behouden; de afzonderlijke tabel `vangblik_soorten` is verwijderd. Alle 99.652 individuen, events, locaties, kwaliteitsvlaggen en oorspronkelijke bronwaarden zijn behouden. Ook de twee vangstregels uit 1959 zonder bijbehorend event blijven herkenbaar en uitgesloten. De bestaande taxonkoppelingen blijven kandidaat; deze opschoning bevestigt geen nieuwe soortidentificaties en verandert de analysegeschiktheid niet. De migratie, het terugdraaien en het volledige herstel uit back-up zijn beproefd. Website, dashboard en Shiny zijn niet aangepast; er is niets naar de VPS gepubliceerd.

### 1.5. NDFF: één canonieke laag van openbare en beveiligde gegevens

**Omvang en periode.** De openbare levering bevat 810.830 unieke niet-vogelrecords uit de downloadselectie 1950–2025. De ruwe bronjaren lopen echter van 1700 tot 2025: 5.336 regels hebben een bronjaar in 1700–1949. Dat bevestigt geen waarnemingsdatum in die eerdere jaren; bronintervallen en datumkwaliteit blijven per record behouden. De beveiligde levering bevat 14.573 records voor 191 geselecteerde taxa. Daarvan vervangen 14.420 records hun openbare, vervaagde tegenhanger en zijn 153 records alleen in de beveiligde levering aanwezig. De gecombineerde laag telt daardoor 810.983 unieke waarnemingen.

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

**Omvang en periode.** 4.569 records, 26 gereconstrueerde dag-hoktellingen, 2012–2024. Daarvan zijn 23 tellingen met minimaal vijftig taxa als aannemelijk volledig geclassificeerd en drie tellingen als fragment. Daarnaast zijn 39 vervaagde jaarregels niet aan een telling gekoppeld.

**Wat heeft FLORON bevestigd?** Op 6 oktober 2026 meldde FLORON dat één kalenderdag in één kilometerhok als telling mag worden beschouwd. Zo'n telling kan één, twee of drie oorspronkelijke lijsten omvatten. Persoonsgegevens en daarvan afgeleide waarnemerscodes worden niet geleverd. De `uri` of `identity` uit de NDFF-export is de stabiele sleutel van de afzonderlijke waarneming.

**Wat kan nu?** Regelversie `ndff-hns-v2` is op 7 oktober 2026 in de lokale database opgebouwd. Ieder van de 26 clusters bevat precies één begindatum en één doelhok. De 4.439 positieve combinaties en 11.730 afgeleide protocolnullen kunnen voorlopig per dag en kilometerhok worden gebruikt voor inventarisatie- en occupancyanalyse. De onderliggende één tot drie lijsten mogen niet als afzonderlijke herhaaltellingen worden gebruikt.

**Wat is gecorrigeerd?** V2 gebruikt steeds de begindatum als teldatum; een latere `periode_stop` geldt niet als tweede velddag. Bij 21 tellingen staat nu neutraal dat hetzelfde hok in hetzelfde jaar op meerdere kalenderdagen is geteld. Dat zegt niets over onafhankelijke waarnemers. De recordselectie, het doelbereik, de 4.439 positieve combinaties en de 11.730 nullen zijn gelijk aan v1. V1 blijft als historisch auditspoor bewaard. De indeling van 23 volledige tellingen en drie fragmenten blijft een lokale reconstructie en moet als zodanig zichtbaar blijven.

#### 1.5.12. FLORBASE en andere vaatplantinventarisaties

**Omvang en periode.** 21.374 NDFF-records, 1974–2025. De 21.161 onvervaagde records zijn samengevat tot 183 combinaties van jaar en kilometerhok. Daarvan hebben 118 hok-jaren minimaal vijftig geregistreerde taxa; 65 kleinere reeksen blijven fragment.

**Wat heeft FLORON bevestigd?** Eén jaar in één kilometerhok is de fijnste beschikbare teleenheid. Voor 2011 werden alleen soort, jaar, kilometerhok en waarnemer opgeslagen. FLORON beschikt niet over de eerder gevraagde lijst-ID's, volledigheidsvlaggen, bezoekdata, bezoekduur, checklistversies of expliciete registraties van niet-aangetroffen soorten.

**Wat kan nu?** Positieve waarnemingen, floristische samenstelling en veranderingen in geregistreerde verspreiding kunnen per kilometerhok en jaar worden onderzocht. De huidige 81.721 protocolnullen blijven afhankelijk van de lokale regel dat een hok-jaar met minimaal vijftig taxa als aannemelijk volledig geldt. Zij zijn geen door FLORON geleverde nulwaarnemingen en ondersteunen zonder gevoeligheidsanalyse geen definitieve trendclaim. Een nieuw verzoek aan FLORON kan deze leemte niet oplossen.

#### 1.5.13. LMF-aandachtssoorten

**Omvang en periode.** 5.980 records, 30 vaste kilometerhokroutes en 124 routejaren, 2000–2025. Het openbare FLORON-rapport bevestigt 79 routejaren uit 1999–2019; 45 routejaren zijn alleen uit NDFF-records afgeleid.

**Wat heeft FLORON bevestigd?** Dunea beheert de onderliggende LMF-A-gegevens. FLORON levert alleen de software als dienst aan Dunea.

**Wat kan nu?** Binnen de 75 doelsoorten bevat de matrix 1.493 positieve resultaten en 7.807 afgeleide nullen. Van die nullen horen 4.945 bij de 79 in het rapport bevestigde routejaren. De overige 2.862 horen bij de 45 alleen uit NDFF afgeleide routejaren en blijven voorlopig.

**Wat ontbreekt voor zelfstandige trends?** Voor de 45 niet in het rapport bevestigde routejaren ontbreken nog de primaire Dunea-export, routeversies en eventuele methodewijzigingen. Op 7 oktober 2026 zijn de lokale reposities, documenten, iCloud-downloads en Zotero hierop gericht doorzocht. Er is geen primaire Dunea-export gevonden; alleen het officiële rapport en algemene methodedocumenten zijn lokaal aanwezig. De lokale zoekroute is daarmee afgerond. Wanneer deze validatie prioriteit krijgt, is de kortste vervolgstap een rechtstreeks verzoek aan Dunea om een bestaande volledige LMF-A-export.

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

**Bronopslag na de gerichte ontvlechting van 29 september 2026.** De vijf niet-LVD-bronnen staan ieder onder een herkenbare bronnaam: `endure_*`, `stowa_limnodata_*`, `naturalis_botany_*`, `naturalis_coleoptera_*` en `nmr_vlinders_*`. Iedere familie heeft een dataset-, event-, resultaat- en overlaptabel. Samen gaat het om vijf datasets, 7.557 events, 17.606 resultaten en 5.942 overlapbeoordelingen uit 1875–2025; dit zijn bronregels en geen opgetelde unieke waarnemingen. Hun oorspronkelijke IDs, bronversies, bronmetadata, expliciete afwezigheden, eenheden, analysebeperkingen en mogelijke overlappen blijven behouden. Bronresultaten blijven via `taxa_bronkoppeling` vanuit `taxa` en met `taxon_groepen` als indeling bereikbaar. De bestaande analyse-ingang levert dezelfde uitkomsten. De overige 2.793 LVD-opnamen met 64.683 resultaten uit 1959–2015 staan onder `lvd_*`; de 644 eerder onder `pq_*` gebrachte LVD-opnamen met 16.627 resultaten uit 1981–2015 blijven daar. Dit is geen oordeel dat alle LVD-opnamen permanente kwadraten zijn. Er is niets naar de VPS gepubliceerd. De volledige brontabelkaart, controles en herstelafbakening staan in [het taxonregister](database/TAXONREGISTER.md).

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

**Overlap en gebruik.** De oorspronkelijke controle op datum, taxon en afstand markeerde 8.006 resultaten als exacte en 5.163 als waarschijnlijke overlap met de primaire provinciale PQ-reeks. Dit betreft overeenkomsten per taxonregel, geen bewezen identieke volledige opnamen. Bij de PQ-integratie zijn de 644 volledige LVD-opnamen waartoe deze 13.169 resultaten behoren verplaatst, inclusief alle 16.627 bijbehorende resultaten uit 1981–2015. Geen van deze bronvarianten telt zelfstandig mee. Alle 32.657 bestaande overlapregels bij de verplaatste resultaten zijn behouden, ook hun mogelijke NDFF-koppelingen. Over de volledige LVD-selectie hebben 51.078 resultaten een mogelijke overeenkomst met een NDFF-regel op taxon, datum en onzekerheidspolygoon. Omdat NDFF geen gedeelde bron-ID levert en de polygonen ruimtelijke onzekerheid weergeven, wordt die mogelijke overlap niet automatisch als dubbel verwijderd. De opnamecontext blijft beschikbaar voor historische vegetatiesamenstelling en verspreiding; vergelijking door de tijd vereist controle van opnametype, oppervlak en herhaling.

**PQ-broncontrole, 27 september 2026.** Het oorspronkelijke LVD-archief is met toestemming alleen-lezen op de T7 gecontroleerd. De bestandshash klopt met de geïmporteerde bronversie. Het archief bevat opname-identificaties, maar geen vaste PQ-identificatie; voor de 3.437 geïmporteerde opnamen uit 1959–2015 bevat de reference-extensie geen aanvullende bronverwijzingen. Vergelijking met de 2.007 provinciale opnamen uit 1981–2025 levert op datum en afstand 654 mogelijke opnameparen uit 1981–2015 op. Bij 20 paren zijn de volledige lijsten met letterlijke taxonnamen en bedekkingscodes gelijk; bij vier daarvan verschillen de percentages. Verschillende namen zijn in deze vergelijking niet als synoniemen samengenomen. Ook een gelijke lijst bewijst op zichzelf geen gedeelde PQ-identiteit. De verplaatsing omvat uitsluitend de 644 LVD-opnamen met al vastgelegde provinciale overlap, samen 652 mogelijke opnameparen. De twee overige nabijheidskandidaten worden niet verplaatst. De herhaalbare vergelijking voor beide opslagplaatsen is `gis/scripts/run_external_ecology_overlap_audit.py --pq-inventarisatie`. Uitvoeringsbewijs en gecontroleerde herstelback-up staan lokaal onder `outputs/pq-integratie`.

**Taxonomische importbeperking, vastgesteld 27 september 2026.** De oorspronkelijke import gebruikte bij alle 81.310 toegelaten LVD-resultaten (1959–2015; 998 verschillende naamstrings) een status als taxonrang: 81.285 keer `accepted` en 25 keer `synonym`. De oorspronkelijke status blijft ook in de bronmetadata bewaard. Bij de 16.627 verplaatste resultaten heet dit veld nu `taxonomische_status_aangeleverd`; hun oorspronkelijke taxonrang wordt via het centrale register uit de bewaarde broncontext gelezen en blijft leeg waar de bron geen rang levert. De 64.683 overige resultaten staan nog in de externe bronlaag met de oude veldnaam, die niet als rang mag worden gebruikt. De historische bulkimport blokkeert na de migratie tegen het opnieuw invoeren van verplaatste bronregels. Alle meetwaarden, ruimtelijke toelating en oorspronkelijke overlapbesluiten zijn behouden. Zie `docs/database/TAXONREGISTER.md` voor model, controles en herstelwijze.

**Aanvullende taxonomische metadata, beoordeeld 27 september 2026.** In de extractie van 998 LVD-naamgebruiken uit de bronreeks 1959–2015 is bij 122 het veld `scientificNameAuthorship` gelijk aan de volledige `scientificName`. Manifest v3 heeft deze tekst niet als auteur overgenomen: het centrale veld `naam_auteur` bleef bij die invoer voor deze 122 naamgebruiken leeg. Bij de centralisatie zijn afzonderlijk onderbouwde auteursnamen aangevuld; de oorspronkelijke lege waarde blijft in de broncontext bewaard. De letterlijke bronmetadata zijn in `taxa_bronkoppeling` behouden. Dit betreft 122 naamgebruiken, niet 122 waarnemingen. De toevoeging aan het register verandert geen meetwaarden, ruimtelijke toelating, overlapbesluiten of bestaande bronvelden.

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

**Waarde en beperking.** Historische vogelcontext. Zonder locatie per regel geen kavel- of ruimtelijke analyse. Het productieoverzicht van 28 september 2026 toont daarnaast een bestaande tabel `vogelstand_1924` buiten de canonieke export. Deze blijft tijdens de PQ-publicatie onaangetast; haar aanwezigheid geeft geen nieuwe analysetoestemming. Dit schema-overzicht bewijst de tabelnaam en het type, niet haar actuele rijtelling.

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

**[Landbedekking in vogelplots](https://doi.org/10.1007/s10531-025-03175-x):** de openbare studie van Schmidt-Tauscher, Häger en Van der Hagen uit 2025 behandelt 25 BMP-plots met samen 925 hectare. Het openbare supplement bevat inmiddels de volledige tabel met de oppervlakte van zeven landbedekkingsklassen per plot in 2001 en 2022: struweel, bos, boomgroepen, lage vegetatie, riet, kaal zand en water. De vogelgegevens overlappen met de bestaande VWG/SOVON-reeks. De plot-tabel voegt wel een ecologisch specifiekere verklarende laag toe dan de reeds aanwezige CBS-landgebruikgegevens voor 55 plots in 1996, 2010, 2015, 2017 en 2022. De classificatie is afgeleid uit luchtfoto’s, teruggebracht tot pixels van 5 bij 5 meter en had een totale nauwkeurigheid van 81% in 2001 en 82% in 2022. De geclassificeerde rasters zelf zitten niet in het openbare supplement; de auteurs vermelden dat de gebruikte en gemaakte datasets op verzoek verkrijgbaar zijn. Met die rasters kunnen ook ruimtelijke samenhang, versnippering, randen en het vegetatiemozaïek binnen plots worden onderzocht. Het blijven twee momentopnamen binnen 25 van de 55 plots; zij meten geen jaarlijkse ontwikkeling, voedsel, nestgelegenheid of andere habitatkwaliteit en bewijzen op zichzelf geen beheereffect.

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

**Landelijke Vegetatie Databank: uitgevoerd voor de reproduceerbare bronversie 1.6.** Van 5.195 opnamen en 119.006 taxonregels zijn 3.437 opnamen en 81.310 taxonresultaten uit 1959–2015 met maximaal 50 meter locatie-onzekerheid toegelaten. De PQ-integratie heeft 644 volledige bronopnamen met 16.627 resultaten uit 1981–2015 naar de PQ-tabellen verplaatst, met vermoedelijke koppelingen en zonder zelfstandig meetellen. De overige 2.793 opnamen met 64.683 resultaten blijven in de externe bronlaag. De bestaande analyse-ingang ontsluit beide opslagplaatsen zonder fysieke kopieën. Mogelijke NDFF-overlap blijft zichtbaar, maar wordt vanwege de NDFF-onzekerheidspolygonen niet automatisch als dubbel verwijderd. De duinvalleireeks kan zonder georeferentie niet op opnameniveau worden gekoppeld en blijft afzonderlijk in `Meijendel_bronnen`.

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
