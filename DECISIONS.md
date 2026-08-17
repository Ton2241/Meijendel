# Besluiten

- Het dashboard is leidend voor alle grafieken. De site mag geen eigen afwijkende grafieklogica of cijfers introduceren.
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
- NDFF/FFV-waarnemingen vormen een afzonderlijke bronlaag en worden nooit
  vermengd met `territoria`, `dagwaarnemingen_bmp`, `dagwaarnemingen_wv` of de
  PQ-vegetatietabellen. Eigen gestandaardiseerde tellingen blijven leidend voor
  trends, aantallen en afwezigheidsinformatie.
- FFV-downloads slaan vogelgegevens over. Een export mag alle overige
  soortgroepen en meerdere kilometerhokken bevatten; exportindeling en latere
  tabelindeling zijn nadrukkelijk niet hetzelfde. Vraag als `GeoPackage RD` aan
  en splits de selectie alleen om ruim onder de FFV-grens van 100.000
  waarnemingen te blijven. De operationele streefgrens is maximaal circa 80.000
  waarnemingen per aanvraag. Splits eerst ruimtelijk in hokken en zo nodig
  aanvullend op soortgroep. Behoud de oorspronkelijke soortgroep, geometrie,
  datum, vervaging, bronhouder, protocol en overige herkomstvelden voor zover de
  FFV die levert.
- De definitieve NDFF-downloadreeks loopt tot en met 31 december 2025. De
  proeflevering met eindjaar 2026 wordt alleen voor schema- en kwaliteitsanalyse
  gebruikt en telt niet als definitieve bronlevering.
- Rond eerst alle FFV-aanvragen af. Bouw daarna uit de ongewijzigd bewaarde
  bronbestanden één geïntegreerde stagingdataset en verwijder exportoverlap
  primair op de stabiele bronwaarde `Identiteit`. Als de stabiliteit daarvan bij
  een overlappende proef niet bevestigd wordt, is aanvullende samengestelde
  matching en handmatige controle vereist; records mogen niet alleen op
  soortnaam, datum of geometrie worden samengevoegd.
- Iedere oorspronkelijke FFV-soortgroep krijgt een eigen NDFF-waarnemingstabel,
  vergelijkbaar in functie met `territoria` en de dagwaarnemingstabellen maar
  nadrukkelijk zonder de NDFF-records als territoria te interpreteren. De vaste
  naamconventie is `ndff_<soortgroep>` met een genormaliseerde ASCII-naam in
  `snake_case`, bijvoorbeeld `ndff_kreeftachtigen`,
  `ndff_kranswieren_wieren_algen`, `ndff_korstmossen` en `ndff_amfibieen`.
  Exportbundeling verandert deze tabelindeling niet. De oorspronkelijke
  FFV-soortgroep blijft daarnaast ongewijzigd als bronwaarde opgeslagen en de
  volledige mapping van FFV-label naar tabelnaam wordt vóór de eerste import
  gevalideerd.
- Gebruik voor iedere NDFF-waarneming afzonderlijke velden voor de vraag of zij
  vervaagd is en voor het vervagingsniveau. Bewaar daarnaast de oorspronkelijke
  FFV-waarde. Vervaging is een eigenschap van het record en niet uitsluitend van
  de soort: in de huidige gevalideerde deelset hebben 314 van de 344 taxa met
  vervaagde records zowel vervaagde als niet-vervaagde waarnemingen en komt dit
  bij 257 taxa binnen hetzelfde kalenderjaar voor. Bereken daarom pas afgeleid
  per soort welk aandeel ruimtelijk nauwkeurig genoeg is voor een betrouwbare
  SOVON-plotkoppeling.
- Neem pas nadat alle downloads zijn voltooid en de geïntegreerde stagingdataset
  is opgebouwd een definitief besluit of en hoe vervaagde waarnemingen worden
  opgenomen en geanalyseerd. Die beoordeling combineert vervagingsniveau en
  plotbetrouwbaarheid met de vaststellingsmethode en onderzoeksstructuur. Breng
  per soortgroep en tijdvak minimaal `Protocol`, `Telonderwerp`,
  `Schaal (telmethode)`, `Determinatiemethode`, `Zoek- of vangmethode`,
  `Bronhouder` en de ruimtelijke nauwkeurigheid in beeld, inclusief ontbrekende
  waarden en methodewisselingen door de tijd. Classificeer vervolgens, voor
  zover de bronvelden dit toelaten, eenmalige losse meldingen, herhaalde maar
  niet-gestandaardiseerde meldingen en structurele/protocolgebonden reeksen.
  Beoordeel waarnemerskwaliteit uitsluitend op controleerbare meegeleverde
  kwaliteits- of validatiekenmerken; leid haar niet af uit aantallen,
  soortnamen of herhaling. Zonder informatie over inspanning of herhaalbare
  methode mogen aantallen meldingen niet als populatietrend of afwezigheid
  worden geïnterpreteerd.
- NDFF-taxa worden geregistreerd in een afzonderlijke tabel `ndff_soorten`.
  De bestaande vogelgerichte tabel `soorten` blijft ongewijzigd. Bewaar in
  `ndff_soorten` minimaal de oorspronkelijke en wetenschappelijke NDFF-naam,
  soortgroep, geaccepteerde naam/status en de gebruikte taxonomische versie.
  Leg overeenkomsten met de PQ-taxonomie afzonderlijk en controleerbaar vast
  via een vertaaltabel naar `pq_vegetatie_taxon.SRTNUM`; een naamsovereenkomst
  alleen mag geen bestaande taxoncode overschrijven.
- Controleer vóór import of NDFF-vaatplantwaarnemingen geheel of gedeeltelijk
  afkomstig zijn uit dezelfde opnamen als de bestaande PQ-waarnemingen. Maak
  eerst kandidaten op basis van bronhouder en vegetatieprotocol en vergelijk
  daarna per opname datum, ruimtelijke afstand, gekoppeld taxon, soortenlijst
  als opnamevingerafdruk en waar mogelijk bedekking of Braun-Blanquetwaarde.
  Classificeer iedere kandidaat als `exact`,
  `waarschijnlijk_dezelfde_opname`, `mogelijk`, `onafhankelijk` of
  `niet_beoordeelbaar`. Bewaar de controle in een audittabel
  `ndff_pq_koppeling`, inclusief afstand, datumverschil, taxonmatchmethode,
  soortenlijst-overlap, abundantiecompatibiliteit, bron/protocolcompatibiliteit
  en beslisregelversie. Verwijder de NDFF-bronwaarneming niet, maar tel een
  bevestigde gedeelde opname in analyses niet nogmaals als onafhankelijke
  waarneming wanneer de PQ-opname al wordt gebruikt.
- Alle NDFF-waarnemingen moeten reproduceerbaar aan de Meijendel-kavelindeling
  kunnen worden gerelateerd. Een waarnemingsvlak dat meerdere kavels raakt
  wordt niet kunstmatig aan een kavel toegewezen: de koppeling bewaart per
  geraakt `plot_id` de ruimtelijke methode en waar mogelijk het overlapoppervlak
  en overlapaandeel.
- De geïntegreerde stagingdataset blijft als controleerbaar tussenproduct
  beschikbaar. Alleen records waarvan de brongeometrie minimaal één vastgelegde
  SOVON-plotpolygoon raakt, zijn kandidaat voor database-import. Records zonder
  plotintersectie blijven uitsluitend in bronbestanden en uitsluitingsaudit en
  worden niet in de Meijendel-database opgenomen. Een intersectie alleen bewijst
  geen aanwezigheid in een plot: vervaagde of grote geometrieën krijgen geen
  exacte plottoewijzing en worden standaard uitgesloten van analyses per plot.
- De NDFF-databaseopslag scheidt biologische FFV-soortgroepen van ruimtelijke
  betrouwbaarheid. Een gedeeld `ndff_waarneming_register` beheert bronidentiteit
  en hoofdgroep; `ndff_import_record` bewaart alle bronbestanden waarin hetzelfde
  ontdubbelde record voorkwam en `ndff_waarneming_geometrie` bewaart de canonieke
  brongeometrie. Iedere FFV-soortgroep krijgt de afgesproken eigen
  `ndff_<soortgroep>`-waarnemingstabel.
  Betrouwbare plotrelaties komen uitsluitend in
  `ndff_waarneming_plot`. Vervaagde records komen daarnaast in
  `ndff_vervaagde_waarneming` en niet-vervaagde maar ruimtelijk ambigue
  gebiedsgeometrieën in `ndff_gebiedswaarneming`. Eventuele kandidaatoverlappen
  worden apart opgeslagen en zijn geen aanwezigheid per plot.
- Het buiten het aangevraagde kilometerhok doorlopen van een niet-vervaagde
  geometrie is op zichzelf geen uitsluitingsgrond: het aanvraaghok is een
  selectiefilter, niet de werkelijke begrenzing van een brongeometrie. Classificeer
  zulke records op vervaging, plotintersectie, aantal geraakte plots,
  overlapoppervlak/-aandeel en geometrieschaal. Zonder voldoende eenduidigheid
  blijven zij een gebiedswaarneming en krijgen zij geen reguliere plotkoppeling.
- Elke NDFF-import bewaart minimaal downloadmoment, selectieperiode,
  kilometerhokken, categorie, bestandsnaam, SHA-256, FFV-peildatum,
  recordaantal, vervagingsinformatie en de meegeleverde NDFF-bronvermelding.
  Herimport moet idempotent zijn en correcties of verwijderingen uit latere
  bronleveringen zichtbaar kunnen verwerken.
