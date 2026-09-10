# Besluiten

- Het dashboard is leidend voor alle grafieken. De site mag geen eigen afwijkende grafieklogica of cijfers introduceren.
- DuckDB 1.5.5 is op de lokale Apple-Silicon-iMac beschikbaar als aanvullende
  analyselaag voor grote bestanden, staging, ruimtelijke koppelingen en zware
  aggregaties. MySQL 9.7.1 blijft de canonieke schrijfbron en DuckDB vervangt
  de bestaande R-, Shiny- of dashboardketen niet. Bestaande databases worden
  vanuit DuckDB standaard read-only gekoppeld; DuckDB komt niet op de VPS, NAS
  of Samsung T7 zonder expliciete toestemming en een afzonderlijke
  architectuurbeslissing. Een blijvend `.duckdb`-, Parquet- of
  GeoParquet-bestand vereist vooraf een bewust gekozen pad en toestemming.
- Externe bestanden die kandidaat zijn voor import in de life-database worden
  duurzaam opgeslagen onder `/Volumes/T7 Data/Home_Ton/Meijendel data/`; per
  levering wordt een herkenbare submap vastgelegd. Downloads is uitsluitend een
  tijdelijke ontvangstlocatie.
- Open FFV-data en beveiligde onvervaagde NDFF-data blijven strikt gescheiden.
  Ticket 58679 gebruikt lokaal `NDFF/secure/ticket_58679`; de oorspronkelijke
  levering blijft ongewijzigd, krijgt een SHA-256-manifest en wordt niet
  opgenomen in Git, de gewone `Meijendel.sql`, algemene Shiny-caches of
  webpaden. Op uitdrukkelijk besluit van de eigenaar wordt op de fysiek
  beveiligde Samsung T7 geen extra versleutelde ontvangstzone gebruikt.
- De op 10 september 2026 ontvangen GeoPackage voor ticket 58679 is technisch
  gevalideerd: 14.573 unieke betrouwbare records, 158 taxa met records en geen
  ongeldige geometrieën. De open FFV-identiteit is reproduceerbaar koppelbaar
  als `SHA-256(obs_uri)`; 14.420 records matchen. Exacte datum en geometrie uit
  de beveiligde levering vervangen de open waarden niet maar worden als
  afzonderlijke beveiligde bronlaag bewaard.
- Een NDFF-geometrie is alleen een voorlopige plotkandidaat wanneer zij volledig
  binnen precies één geversioneerd SOVON-plot ligt. Alleen een intersectie of
  een enkel geraakt plot is onvoldoende. Van de levering voldoen 8.777 records
  aan deze ruimtelijke regel; na de PQ-poort resteren 8.494 kandidaten voor
  uitsluitend verspreidingscontext. `Multiple`, `outside` en `single_deels`
  tellen niet als aanwezigheid per plot.
- De beveiligde levering maakt geen record direct trendklaar. Van 1.931 records
  uit doelgerichte meetnetten of gebiedsmonitoring zijn 1.274 ruimtelijk en qua
  PQ-status geschikt voor een gerichte brondata-aanvraag. Zonder telobjecten,
  bezoeken, inspanning, protocolversies en afleidbare nullen blijven ook deze
  buiten trend-, abundantie- en afwezigheidsanalyses.
- NDFF wordt niet opnieuw om de ontbrekende surveystructuur gevraagd, omdat
  NDFF heeft aangegeven die niet te kunnen leveren. Voor de 1.274 geschikte
  vervolgkandidaten wordt de verwachte meetopzet uit officiële protocollen
  gereconstrueerd en worden de feitelijke native meetreeksen rechtstreeks bij
  Zoogdiervereniging, Dunea/FLORON, RAVON, ANEMOON, BLWG, De
  Vlinderstichting en Staatsbosbeheer/opdrachtgever opgevraagd. Openbare
  protocollen bewijzen het ontwerp, niet welke bezoeken werkelijk zijn
  uitgevoerd.
- De native survey-eenheid blijft behouden: route, water, permanent proefvlak,
  kilometerhok, meettraject of karteringsgebied. De ruimtelijke ligging van één
  positieve NDFF-regel is onvoldoende om de hele survey aan een SOVON-plot toe
  te wijzen. Relatie met geversioneerde vogelplots volgt pas na reconstructie
  van telobject, bezoeken en inspanning; kunstmatig splitsen is alleen
  toegestaan als sectiegeometrie en sectie-inspanning beschikbaar zijn.
- Het definitieve relationele survey-schema wordt pas vastgesteld na ontvangst
  van minstens één representatieve bronlevering. Daarmee wordt voorkomen dat
  route-, water-, proefvlak- of hokstructuren in een te vroeg generiek schema
  verloren gaan.
- Van de 8.494 ruimtelijke verspreidingskandidaten gaan alleen de 1.274
  passende meetnet-/gebiedsmonitoringrecords door naar de brondata-opvraag. De
  overige 7.220 positieve records blijven uitsluitend beveiligde externe
  staging en worden niet in de life-database opgenomen zolang geen
  wetenschappelijk verantwoord analysetype en voldoende waarnemingsinspanning
  zijn aangetoond.
- De voorlopige PQ-audit van ticket 58679 bevat 162 exacte positieve dubbels en
  163 niet-beoordeelbare risicorecords. Beide categorieën tellen niet als
  zelfstandige NDFF-evidentie. De door Provincie Zuid-Holland aangeleverde
  PQ-reeks in de life-database is de oorspronkelijke, gezaghebbende bron.
  Iedere uit NDFF afkomstige PQ-regel is per definitie slechts een secundaire
  controlebron en mag de provinciale reeks nooit aanvullen, wijzigen,
  overschrijven of als extra waarneming meetellen, ook niet wanneer een
  overlapclassificatie `onafhankelijk` zou luiden. Tussen de 158 geleverde
  NDFF-taxa en de 275 taxa
  van de afzonderlijke GBIF-vangblikreeks is geen taxonomische overlap; beide
  bronlagen behouden desondanks hun eigen structuur in de later gezamenlijke
  migratie.
- De openbare GBIF Sampling Event Dataset `Meijendel research 1953-1960`
  (versie 1.7, DOI `10.15468/adsbxs`) blijft een derde, afzonderlijke bronlaag
  onder `NDFF/external_gbif/meijendel_vangblikken_1953_1960`. Zij wordt niet
  tot positieve NDFF-waarnemingen afgevlakt: sampling events, vangblikken,
  inspanning, verplaatsingen en kwaliteitsvlaggen blijven behouden. De reeks
  komt pas in aanmerking voor de life database na oplossing of expliciete
  uitsluiting van verweesde occurrences, soortspecifieke archiefonvolledigheid,
  predatierisico, methodevergelijking in 1959 en de licentie-inconsistentie.
  De uiteindelijke databaseopname wordt niet afzonderlijk uitgevoerd, maar
  tegelijk met de toegelaten delen van de definitieve NDFF-levering in één
  gecontroleerde en terugdraaibare migratie. De afzonderlijke bronidentiteit
  en meetstructuur blijven daarbij volledig behouden.
- De beveiligde NDFF-data is op 10 september 2026 in een apart lokaal
  MySQL-schema `Meijendel_ndff_secure` opgenomen. Alle 14.573 regels blijven
  daarin als beveiligde bronregistratie bewaard; 8.494 regels zijn uitsluitend
  als positieve verspreidingscontext toegelaten en 1.274 daarvan zijn gelabeld
  als trendkandidaat die op volledige brondata wacht. Dit label is geen
  trendtoelating. De bestaande vogelgerichte
  tabel `soorten` blijft ongewijzigd; NDFF-taxa komen in `ndff_soorten` en iedere
  oorspronkelijke FFV-soortgroep krijgt een eigen tabel `ndff_<soortgroep>`.
  Exacte geometrie en plotkoppeling blijven lokaal. Alleen afzonderlijk
  goedgekeurde, niet-herleidbare analyseresultaten mogen naar de VPS. De gewone
  life-database is bij deze import niet gewijzigd.
- Een exacte, onvervaagde locatie verbetert de ruimtelijke toewijzing maar maakt
  een positieve FFV-waarneming niet trendklaar. Voor trends blijven volledige
  telbezoeken, inspanning, protocolversies en afleidbare nullen vereist; de
  bestaande PQ-reeks blijft leidend totdat de afzonderlijke PQ-overlapaudit is
  afgerond.
- Iedere analyse waarin NDFF-data wordt gebruikt, past verplicht de
  NDFF/PQ-analysepoort toe. Aanleiding is dat 1.039 van 2.007 PQ-opnamen
  (51,77%) en 24.804 van 53.122 PQ-soortwaarnemingen (46,69%) in de open
  NDFF-staging herkenbaar zijn, met een sterke daling van de dekking vanaf 2018.
  Iedere NDFF-waarneming krijgt vóór analyse een
  auditeerbare status `exact`, `waarschijnlijk_dezelfde_opname`, `mogelijk`,
  `onafhankelijk`, `niet_beoordeelbaar` of `niet_van_toepassing`, met een
  versie van de beslisregel. Alleen `onafhankelijk` en `niet_van_toepassing`
  mogen als zelfstandige NDFF-informatie meetellen wanneer het record tevens
  geen PQ-bronrecord is. De overige statussen en alle NDFF-PQ-bronrecords mogen
  hoogstens als gelabelde context worden getoond en leveren geen extra telling,
  soortenrijkdom, aanwezigheid, trend- of inspanningsbewijs naast de bestaande
  PQ-opname. Iedere analyse-uitvoer rapporteert de aantallen per status en de
  gebruikte beslisregelversie; ontbreken van deze controle blokkeert publicatie.
- De tabel `weer` blijft een ruwe bron met stationsafhankelijke schalen. Alle analyses lezen uit `weer_analyse`; die view normaliseert eenheden, bewaart spoorneerslag en spoorzonneschijn als aparte vlaggen en levert bij een onbekend station bewust `NULL` voor stationsafhankelijk genormaliseerde waarden.
- Het PQ-vegetatiemeetnet wordt rechtstreeks beheerd in de levende MySQL-database en niet handmatig in `meijendel.sql`. De genormaliseerde brontabellen gebruiken het prefix `pq_`; historische geometrie blijft per opname behouden. Dashboard en Shiny lezen alleen de afgeleide korrel `pq_plot_jaar_vegetatie`, de website alleen de veilige view `website_plot_vegetatie_jaar`.
- Voorlopige PZH-imports worden versieerbaar opgeslagen met bestands-SHA en bronstatus. `SRTNUM` is de interne soortidentiteit binnen de geregistreerde soortenlijstversie; `PLABED` blijft een ruwe broncode. Afwijkende nieuw aangeleverde bodemcodes overschrijven de bestaande waarde pas na bevestiging door PZH.
- Webgrafieken worden gevoed door vooraf gegenereerde dashboard-output/CSV; lokale `meijendel.sql` wordt niet per request geparsed.
- Dashboard, Shiny, SQL en dashboard-output zijn leden-only via Caddy `forward_auth`.
- Shiny is toegankelijk vanaf niveau 2; gewone leden niveau 1 zien/activeren Shiny niet.
- Autorisatieniveaus: 1 lid, 2 redacteur, 3 bestuurslid, 4 webmaster, 5 systeembeheer.
- Bestuursleden mogen ledenadministratie en kavelbeheer bewerken, maar rollen/rechten wijzigen blijft voor webmaster en systeembeheer.
- Runtime-data zoals uploads, archiefdocumenten en productiebeelden gaan niet in Git; Git bevat code, scripts, documentatie en lege mapstructuur waar nodig.
- CMS-afbeeldingen die vanuit nieuwsberichten worden geupload zijn runtime-data onder `app/static/uploads/cms`; deploys en back-ups moeten deze map behouden.
- Canoniek SQL-bestand op de VPS is `/srv/vwgm/data/Meijendel.sql`; oude SQL-locaties mogen hoogstens symlink zijn.
- MySQL `tellers` bevat uitsluitend `id` en een unieke `tellercode`. Namen, contactgegevens, lidsoort en bandnummer worden alleen in de afgeschermde PostgreSQL-ledenadministratie beheerd en mogen niet terugkeren in `meijendel.sql` of algemene MySQL-back-ups.
- `www.vwg-m.nl` wordt na DNS-cutover de hoofdhost; `app.vwg-m.nl` blijft voorlopig werkende alias.
- Algemene publieke zoekfunctie mag geen besloten ledenarchief of andere ledenroutes indexeren of tonen.
- Nieuwe functionaliteit moet waar relevant zichtbaar worden in auditlogging en in `handleiding_beheer.md`.
- Afgeronde wijzigingen worden standaard in Git gecommit met een korte, beschrijvende commitmelding, tenzij expliciet anders gevraagd.
- Als een wijziging voor `app.vwg-m.nl` of de VPS-site wordt gevraagd, is de standaard scope lokaal aanpassen plus deploy naar de VPS en verificatie op productie.
- Nieuwsoverzichten tonen geen volledige nieuwsitems meer: startpagina en `/nieuws/index.asp` tonen lijsten of korte tekstsamenvattingen, terwijl de detailpagina achter `Lees verder` het volledige bericht toont.
- Als een nieuwsbericht met een afbeelding begint, wordt die afbeelding in de overzichtssamenvatting overgeslagen; de samenvatting bevat alleen tekst.
- Gepubliceerde nieuwsitems worden met het nieuwste item bovenaan getoond. Bij gelijke publicatiedatum is de nieuwste database-id de tie-breaker.
- Gewone leden krijgen alleen beperkte Contentbeheer-toegang als zij in het lopende jaar als BMP- of winterteller aan een kavel zijn gekoppeld; zij zien dan alleen `Kavels` en alleen hun eigen actuele kavelteksten.
- Niveau 4 en 5 behouden volledige Contentbeheer-toegang tot vaste pagina's, soortteksten en alle kavelteksten.
- De ledenpagina toont BMP-kavels, winterkavels en PTT-route uit dezelfde actuele jaartoewijzingen als de ledenadministratie; `app.teller_assignments` is de voorkeursbron, met fallback naar oudere app-/legacyvelden.
- Vogelrichtlijnsoorten worden als lijstgroep gekoppeld via `richtlijn_id = 7`; er komt geen aparte gebieds-/doelentabel voor website- en dashboardgroepen.
- De publieke Vogelrichtlijn-groepsgrafiek gebruikt dezelfde vooraf gegenereerde CSV-output als andere groepen; `chart_id = vogelrichtlijn` is de vaste sleutel.
- De vaste tekst van de Vogelrichtlijn-groep wordt beheerd via app-CMS-key `groups:vogelrichtlijn`; oude CMS-content mag de vastgestelde titel/tekst niet stilzwijgend blijven overschrijven na zo'n wijziging.
- Vogelsoortdetailpagina's mogen Meijendel-kenmerkdata read-only tonen als aanvullend blok `Vogelkenmerken`; dit blok vervangt of overschrijft geen CMS-/legacyteksten voor `Beschrijving` en `Voorkomen`.
- Publieke kenmerken op soortpagina's worden compact en leesbaar weergegeven als doorlopende tekst; technische veldcodes en primair/secundair-labels blijven uit de publieke tekst.
- De knop `Kenmerken` verschijnt alleen als er daadwerkelijk kenmerkdata is, zodat soorten zonder kenmerken geen lege navigatie of leeg blok krijgen.
- Functionele vogelgroepen vormen een aanvullende, niet-exclusieve analysedimensie en vervangen de ecologische vogelgroepen van Sierdsema niet.
- Versie 1 gebruikt zes groepen: bodemfoeragerende insecteneters, luchtfoerageerders, grondbroeders, holenbroeders, langeafstandstrekkers en zaadeters.
- Primair groepslidmaatschap krijgt voor gewogen gevoeligheidsanalyses gewicht `1,0`, secundair substantieel lidmaatschap `0,5`; daarnaast wordt altijd een binaire analyse uitgevoerd. Incidenteel gebruik telt niet mee en onbekend blijft `NULL`.
- Een hoofdgroep vereist minimaal tien soorten met een bruikbare trend. Vijf tot en met negen soorten is uitsluitend exploratief; minder dan vijf soorten wordt niet als groepsindicator geanalyseerd.
- Bestaande `F`- en `V`-codes worden niet hernoemd of stilzwijgend geherinterpreteerd. Nieuwe traits gebruiken een versiegebonden namespace `TR1_*` en legacyvertalingen worden afzonderlijk vastgelegd.
- De huidige kenmerkdata gelden voor migratie als `legacy_ongevalideerd` zolang bron, context en inhoudelijke controle ontbreken. Afwezigheid van een rij betekent niet dat een eigenschap afwezig is.
- Aanvullen van ontbrekende soortkenmerken hoort bij fase B. Fase A registreert de hiaten; fase C mag een groep pas afleiden nadat alle verplichte traits zijn aangevuld of expliciet als onbekend zijn beoordeeld.
- De migratie bouwt een nieuwe traitlaag naast de bestaande tabellen. Bestaande lezers schakelen pas om na inhoudelijke goedkeuring en groene dashboard/Shiny/website-pariteitscontroles.
- Mondiale of Europese soorttraits worden niet automatisch verheven tot een
  Nederlandse of Meijendel-broedpopulatiewaarde. Bronwaarden behouden hun eigen
  geografische, seizoens- en populatiecontext; de vereiste lokale doelcontext
  blijft `unknown` totdat zij afzonderlijk is goedgekeurd.
- TR1 bevat naast 15 verplichte doeltraits acht ondersteunende brontraits. Deze
  bewaren binaire of semikwantitatieve broninformatie zonder een kunstmatig lokaal
  percentage te construeren.
- Zaadeters worden bepaald met `TR1_DIET_SEED_SHARE`: primair vanaf `0,50`,
  secundair vanaf `0,25` en uitgesloten daaronder. De waarde betreft volwassen
  vogels in het broedseizoen en is een reproduceerbare klasseproxy, geen lokaal
  gemeten dieetaandeel.
- Taxonomische bronkoppelingen worden expliciet en controleerbaar opgeslagen. Bij
  de Europese life-historydataset wordt voor de import de oorspronkelijke
  combinatie `Genus` + `Species` gebruikt, omdat het meegeleverde gestandaardiseerde
  veld aantoonbaar ten minste één foutieve soortomzetting bevat.
- Technische voltooiing van fase B is geen toestemming voor fase C: pas na
  inhoudelijke beoordeling van de gapmatrix mogen groepslidmaatschappen worden
  gegenereerd.
- Voor de inhoudelijke fase-B-aanvulling geldt de vaste bronhiërarchie
  Nederland > Europa > mondiaal. Het Nederlands Soortenregister en de
  Vogelbescherming-vogelgids zijn voor alle 95 soorten vastgelegd; Europese en
  mondiale datasets worden alleen als fallback en inhoudelijke controle gebruikt.
- Kwalitatieve Nederlandse soortteksten mogen via versiegebonden, vaste klassen
  worden omgezet naar semikwantitatieve analyseproxies. `approved` betekent hier
  reproduceerbaar en geschikt voor de fase-C-selectieregel, niet dat een lokaal
  populatieaandeel rechtstreeks is gemeten. Confidence en afleidingsnotitie zijn
  daarom verplicht en fase C voert drempelgevoeligheidsanalyses uit.
- Tegenstrijdige of ecologisch onwaarschijnlijke mondiale coderingen worden niet
  gemiddeld met Nederlandse informatie. De Nederlandse bron gaat voor; de
  afwijkende mondiale waarde blijft uitsluitend als herleidbare bronwaarde of
  controle behouden.
- Fase-C-groepsafleiding gebruikt behalve de aandeelgrenzen ook de in fase A
  verplichte contextgates. Bodem-insecteneters vereisen een passend substraat én
  grond-/strooiselmethode en sluiten dominante luchtvangst uit;
  luchtfoerageerders vereisen uitvaljacht of continue luchtjacht. Nest- en
  trekgroepen vereisen respectievelijk passende nesthoogte/holtetype en een
  langeafstandswinterregio.
- De baseline wordt altijd naast een inclusieve drempelverschuiving van −0,10 en
  een strikte verschuiving van +0,10 opgeslagen. Leave-one-species-out controleert
  minimaal of de publicatiestatus van de groepsomvang door één soort verandert.
- De fase-C-baseline levert vier robuuste hoofdgroepen op. De groep
  luchtfoerageerders telt zeven soorten en mag daarom uitsluitend exploratief
  worden gebruikt. De bodem-insectengroep daalt in de strikte variant naar 16
  soorten en is dus niet drempelrobuust. Geen van de lijsten wordt gepubliceerd
  voordat zij inhoudelijk is geaccordeerd en analysepariteit groen is.
- Fase D gebruikt voor functionele groepen dezelfde gebrugde TRIM-soortindices
  en dezelfde volledige/robuuste soortselectie als de bestaande MSI-keten.
  Binaire en gewogen MSI zijn gewogen geometrische gemiddelden op logschaal.
- Functionele groepen krijgen geen landelijke vergelijkingslijn zolang geen
  landelijk bronbestand met exact dezelfde traitdefinities, groepsregels en
  gewichten beschikbaar is; dashboard en website tonen wel de Meijendel-lijn.
- De website toont per functionele groep afzonderlijk de binaire en gewogen
  dashboardreeks. Luchtfoerageerders blijven expliciet exploratief en de
  bodem-insectengroep houdt een zichtbare drempelwaarschuwing.
- Nederlandse soortnaamsynoniemen voor uitwisseling met de VWG-M-website staan
  centraal in `R/species_name_synonyms.R`. Analyses en databasekoppelingen blijven
  op `soort_id` en Euring-code draaien; alleen invoerresolutie en publieke
  weergavenamen worden gecanonicaliseerd. Soortrecords worden niet samengevoegd,
  omdat onder meer Barmsijs en Kleine Barmsijs afzonderlijke IDs en taxa hebben.
- Traitverrijking wordt niet langer begrensd door vooraf bepaalde
  modelleerbaarheid. `BROEDVOGELS_MEIJENDEL_V1` bevat alle 159 soorten met een
  positief territorium sinds 1958; `TRIM_BRUIKBAAR_V1` blijft uitsluitend een
  afzonderlijke analyse-/robuustheidsscope van 95 soorten.
- Voor gedomesticeerde vormen, exoten en taxa zonder volledige externe dekking
  wordt een expliciete stamsoort-/synoniemmapping en lagere confidence gebruikt.
  Ontbrekende externe data wordt niet als nul geïnterpreteerd en klasseproxies
  worden nooit als gemeten Meijendel-populatiepercentages gepresenteerd.
- Bij ieder volledig regulier winterbezoek worden in elk kavel alle waargenomen
  vogels genoteerd, inclusief water- en wetlandsoorten. Zowel volledige bezoeken
  `Alle vogelsoorten` als `Watervogels en wetlandsoorten` leveren daarom voor
  iedere soort geldige nullen; het historische teltype blijft alleen als
  modelcovariaat aanwezig. Deelbezoeken, soortgerichte en overige tellingen
  blijven uitgesloten.
- Wintertellingindices gebruiken aantallen per volledig regulier bezoek, met een
  negatief-binomiaal model en een binaire gevoeligheidsanalyse.
  Index 100 is het modelgemiddelde over 2000/01–2004/05. Een klassiek occupancy-
  of N-mixturemodel wordt niet gebruikt omdat vrijwel geen gesloten
  detectiereplicaten bestaan. Alle 220 canonieke geregistreerde soorten staan in
  het dashboard: `betrouwbaar` en `indicatief` krijgen een gestandaardiseerde
  index, `alleen_beschrijvend` krijgt uitsluitend geregistreerde gemiddelden en
  waarnemingsfrequenties. Historische codes `Canadese gans spec.` en `Grote
  Canadese gans (maxima)` worden onder `Grote Canadese Gans` samengevoegd. De
  bestaande seizoenssom blijft uitsluitend als duidelijk gewaarschuwde ruwe
  telling beschikbaar.
