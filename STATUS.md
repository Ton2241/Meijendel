# Status Meijendel

Laatste update: 18 augustus 2026

Dit document bevat actuele status, resterende risico's en logische vervolgstappen voor Meijendel-onderdelen die ook de VWG-M-site raken. Stabiele architectuur staat in `ARCHITECTURE.md`; open werk staat in `TODO.md`.

## Repositoryhygiëne

Gereed:

- Gegenereerde R- en Sass-bestanden onder `app_cache/` worden niet meer door Git gevolgd en zijn projectbreed genegeerd.
- De Meijendel-deploypreflight controleert na de lokale Shiny/dashboard-pariteitscontrole opnieuw dat de werkboom schoon is.
- Generatie, archivering en deploy controleren fail-fast dat de lokale MySQL-server, `mysql` en `mysqldump` exact 9.7.1 zijn; de deploypreflight vereist daarnaast exact 9.7.1 op de VPS.
- Projectbrede begin- en eindcontrole vereist schone werkbomen, actuele upstreams en opruiming van aantoonbaar verouderde worktreeverwijzingen in alle drie repositories.
- De actuele VPS-inrichting en versies zijn vastgelegd in
  `docs/vps_productie.md`. De gestopte MySQL-9.7.1-proefcontainer, tijdelijke
  proefdatamap, het `hello-world`-testimage en 9,5 GB herbouwbare Docker-cache
  zijn verwijderd. Alleen actieve MySQL/Shiny en de bewust behouden
  versiegescheiden MySQL-9.5-rollbackcontainer blijven aanwezig; Docker heeft
  geen ongebruikte volumes of buildcache.
- De containerremediatie is uitgevoerd met digestvaste kandidaatbuilds, exacte
  scans, geïsoleerde tests, preflight, deploylock en rooktest. Actieve MySQL
  9.7.1 en de MySQL-9.5-rollback staan op 0 `CRITICAL`/0 `HIGH`; Shiny staat op
  0 `CRITICAL`/43 `HIGH`, alle zonder beschikbare fix in
  `linux-libc-dev 6.8.0-137.137`. De vorige containers/images blijven tijdelijk
  als herstelbewijs behouden; opruiming is afzonderlijk werk.

## SQL-naam en historische PWA

Gereed:

- De lokale canonieke SQL-dump heet `meijendel.sql`.
- Scripts en documentatie in deze repo gebruiken lokaal `meijendel.sql`; het productiepad op de VPS blijft `/srv/vwgm/data/Meijendel.sql`.
- De historische map `pwa_ledenadministratie/` is verwijderd uit de Meijendel-repo.
- De 15 eerder hernoemde objecten van het verlaten ledenadministratieprototype zijn uit de live database verwijderd.
- MySQL `tellers` en de opnieuw gegenereerde `meijendel.sql` bevatten uitsluitend `id` en de unieke `tellercode`; alle 2.449 historische koppelingen zijn intact en de volledige dumprestore is gecontroleerd.
- De actuele Git-versie bevat geen oude SQL-back-up meer. Het gedateerde kavelimportscript leest een eventueel persoonsgegeven tellermappingbestand voortaan alleen via `MEIJENDEL_TELLER_MAPPING_CSV` buiten Git.

## Wintertellingen 2000/01–2024/25

Gereed:

- De bezoek-, protocol-, taxon- en nulreconstructie-audit is reproduceerbaar vastgelegd.
- Per kavel en wintermaand gebruikt de analyse maximaal één volledig regulier
  bezoek: standaard de telling het dichtst bij de 15e. Bekende dubbele,
  correctie- en aanvullingsregistraties zijn met expliciete bezoek-id-regels
  afgehandeld; enkelvoudige tellingen buiten het voorkeursweekend blijven
  behouden tenzij een gemotiveerde uitzondering wordt vastgelegd.
- De vaste telregel is verwerkt: ieder volledig regulier bezoek registreert alle
  waargenomen vogels, ook watervogels en wetlandsoorten. Het historische teltype
  is daarom een modelcovariaat en geen soortspecifieke nulbeperking.
- De 223 aangetroffen broncodes zijn tot 220 canonieke soorten samengebracht;
  `Canadese gans spec.` en `Grote Canadese gans (maxima)` vallen onder
  `Grote Canadese Gans`.
- Alle 220 soorten hebben jaar-, maand- en plotuitvoer. 77 soorten zijn volledig
  modelmatig getest: 17 zijn `betrouwbaar`, 41 `indicatief`; in totaal zijn 162
  soorten uitsluitend `alleen_beschrijvend`.
- Het dashboard bevat een nieuw winteronderdeel met jaarindex, maandindex,
  geldige bezoeken, ruimtelijke spreiding en een methodologische waarschuwing.
  De bestaande ruwe wintersom blijft apart beschikbaar en wordt niet als
  dichtheid of populatie-index gepresenteerd.
- Het dashboard toont alle soorten met een kwaliteitsfilter. De eerdere
  soortgroepfilter en de herhaalde methodetekst onder iedere soort zijn vervangen
  door één knop `Toelichting` met een toegankelijke uitleg-pop-up. Beschrijvende
  soorten krijgen geen modelindex maar geregistreerd gemiddelde per geldig
  bezoek en waarnemingsfrequentie.
- Methode en besluit staan in `MDs/wintertellingen_pilot.md`; het bestaande
  publieksartikel blijft een pilotconcept en wordt pas na inhoudelijke
  soortbeoordeling geactualiseerd.

## Functionele vogelgroepen — fase A tot en met E afgerond

Gereed:

- Scope versie 1 is vastgesteld op zes niet-exclusieve groepen:
  bodemfoeragerende insecteneters, luchtfoerageerders, grondbroeders,
  holenbroeders, langeafstandstrekkers en zaadeters.
- Het bestaande traitstelsel is tegen de canonieke lokale SQL-dump geaudit.
- Het minimale traitwoordenboek, het doelgegevensmodel en de gecontroleerde
  migratieroute zijn vastgelegd in `MDs/README_bmp_meijendel_index.md` en
  `ARCHITECTURE.md`.
- De audit heeft geen MySQL-, dashboard-, Shiny- of productiegegevens gewijzigd.
- De levende lokale database bleek inhoudelijk gelijk aan de fase-A-dump voor de
  relevante legacytabellen; alleen tijdzoneweergave van timestamps verschilde.
- De nieuwe traitlaag, bronregistratie, taxonomische mappings, analysescope,
  groepsdefinities en gapview zijn naast legacy in de lokale MySQL-database gebouwd.
- Drie externe datasets zijn reproduceerbaar geïmporteerd: EltonTraits 1.0,
  European bird life-history data en Global Nest Traits v2. Alle drie hebben voor
  de 95 scopesoorten een expliciet goedgekeurde taxonomische koppeling.
- De legacy-import bevat 1.027 waarden; externe imports bevatten 285 Elton-, 190
  Europese life-history- en 456 nesttraitwaarden. Alle 1.958 bronwaarden zijn aan
  hun bron en importbatch gekoppeld.
- Voor alle 95 soorten zijn de 14 verplichte doeltraits inhoudelijk aangevuld:
  1.330 van 1.330 soort-traitcellen staan in `v_trait_gap_v1` op `gereed` en er
  resteert geen geprefereerde `unknown`.
- Het eindbatch `TR1FINAL_20260718` bevat 1.505 goedgekeurde waarden; het aantal
  is hoger dan 1.330 doordat substraat, methode, holtetype/-oorsprong en
  winterregio meerkeuzetraits zijn.
- Nederlandse bronnen zijn leidend: het Nederlands Soortenregister en de
  Vogelbescherming-vogelgids dekken elk alle 95 soorten. Europese bronnen zijn
  fallback, mondiale bronnen alleen laatste fallback en controle. Elke
  eindwaarde heeft minimaal twee bronkoppelingen en de gebruikte soortpagina of
  datasetlocator is in de database vastgelegd.
- De eerder volledig ontbrekende Torenvalk, Tortelduif, Boerenzwaluw, Barmsijs
  en Goudvink hebben nu eveneens alle 14 verplichte traits.
- Kwalitatieve Nederlandse beschrijvingen zijn met vaste, gedocumenteerde
  klassen naar analysewaarden vertaald. Die waarden zijn reproduceerbare
  proxies, geen gemeten lokale populatiepercentages; onzekerheid staat in
  `confidence_score` en `evidence_note`.
- Fase C heeft voor iedere combinatie van vijf groepen en 95 scopesoorten een
  reproduceerbare classificatie gematerialiseerd: 475 rijen met binair
  lidmaatschap, gewicht, reden, gebruikte traitwaarden, confidence en
  bronlocators.
- De selectieregels gebruiken naast de aandelen ook de in fase A verplichte
  methode- en substraatgates. Daardoor tellen bijvoorbeeld zoekvlucht zonder
  actieve luchtvangst en luchtjagers zonder bodemfoerageermethode niet mee.
- Twee controleviews zijn beschikbaar: `v_functional_group_membership_v1` voor
  soortniveau en `v_functional_group_summary_v1` voor omvang, gewicht,
  gevoeligheid en publicatiestatus.
- De groepslijsten zijn inhoudelijk geaccordeerd. Dashboard en Shiny tonen de
  zes functionele groepen naast legacy; website-output en VWG_M bevatten
  dezelfde nieuwe categorie. Fase E heeft deze samenhangende release op
  productie gepubliceerd en met rooktests en een visuele browsercontrole
  gevalideerd.
- `R/trim_soorten_en_msi_evg.R` maakt binair/gewogen × volledig/robuust,
  samenstelling, trendoverzicht en leave-one-species-out-trendgevoeligheid.
- De lokale uitvoer bevat 1.628 functionele MSI-rijen. Shiny/dashboard-pariteit
  over 1958-2025 is groen met maximaal absoluut verschil `5,12e-13`.
- De dashboard/website-paritycheck is groen met 33 chart-id's, waaronder twaalf
  functionele reeksen (zes groepen × binair/gewogen).
- Op 20 juli 2026 is de traitscope uitgebreid van de 95 lange TRIM-reeksen naar
  alle 159 soorten met ten minste één territorium in Meijendel. De oorspronkelijke
  95 blijven als aparte model-/robuustheidsscope bestaan.
- Alle 159 soorten hebben ieder alle 15 verplichte TR1-traits, met
  expliciete taxonmapping, bronlocators, confidence en afleidingsnotitie. De
  gapmatrix bevat nu 2.385/2.385 gereed-cellen; geen doelwaarde is `unknown` en
  iedere nieuwe eindwaarde heeft minimaal drie bronkoppelingen.
- `functional_group_membership` bevat nu 954 rijen (6 × 159), zonder onbekende
  classificaties. De Appelvink heeft 15/15 traits en valt op basis van de
  vastgelegde V1-regels secundair onder bodemfoeragerende insecteneters.
- De 29 soorten zonder volwassen-voedselcode zijn aangevuld. De nieuwe
  zaadtrait bevat 159 goedgekeurde voorkeurswaarden en levert 29 primaire en 34
  secundaire zaadeters op: 63 binaire leden en een gewogen groepsomvang van 46,0.

Nulmeting van `meijendel.sql` vóór de voedsel- en zaadaanvulling:

- `soorten_kenmerken`: 2.437 relaties, 159 soorten en 546 gebruikte codes;
- waarden: 2.091 primair (`1`), 346 secundair (`2`), geen incidentele waarde
  (`3`), terwijl het schema `3` wel toestaat;
- datadictionary: 559 codes, waarvan 545 actief en 14 ongebruikt;
- één verweesde code door hoofdletterverschil: `F-Mud`;
- zeven soorten hebben een verouderde, gedenormaliseerde soortnaam in 86
  kenmerkrijen;
- één exact dubbele vogeltypering bij Orpheusspotvogel en Braamsluiper;
- `soorten_kenmerken_voedsel` bevat 808 afgeleide/overlappende regels zonder
  foreign keys en is geen geschikte nieuwe hoofdbron.

Dekking in die nulmeting bij de 95 soorten met een bruikbare lange TRIM-reeks:

- functionele habitat/foerageren: 90 van 95;
- voedsel voor jongen: 66 van 95;
- gedrag/ecologie/levenswijze: 60 van 95;
- migratie: 76 van 95;
- nestplaats: 88 van 95;
- voedsel volwassen vogels: 87 van 95.

Resterende risico's na fase C:

- Een aanwezige hoofdcategorie betekent niet dat alle voor een groep verplichte
  traits gevuld zijn. Het legacystelsel kan onbekend niet onderscheiden van
  afwezig.
- Semikwantitatieve aandelen en nesthoogteklassen zijn deels afgeleid uit
  kwalitatieve Nederlandse tekst. Fase C rapporteert daarom naast de baseline
  ook een inclusieve en strikte drempelvariant van respectievelijk −0,10 en
  +0,10, plus de minimumstatus na leave-one-species-out.
- Mondiale bronnen bevatten aantoonbaar enkele voor Nederlandse toepassing
  onwaarschijnlijke coderingen. Ze zijn niet blind overgenomen; Nederlandse
  broninformatie gaat voor en Europese/mondiale waarden blijven als herleidbare
  fallback of controle gekoppeld.
- De legacy-afwijkingen `F-Mud`, zeven gedenormaliseerde soortnamen en de gelijke
  typering van Orpheusspotvogel/Braamsluiper zijn behouden en zichtbaar gemaakt;
  legacy is niet stilzwijgend gecorrigeerd.
- De oude legacykandidaten blijven uitsluitend historische kwaliteitscontext;
  de goedgekeurde fase-C-materialisatie is leidend voor functionele analyse.

Vervolgbeheer:

- Houd de luchtgroep uitsluitend exploratief en toon bij bodem-insecteneters de
  drempelwaarschuwing. Herhaal na iedere bron-, trait-, regel- of
  soortselectiewijziging alle analyses en paritychecks.
- Volgende productiedeploys en centrale release-registraties blijven uitsluitend
  via de verplichte deploy-preflight en het projectbrede release-manifest lopen.

## Dashboard, websitegrafieken en Shiny

Gereed:

- Shiny kiest voor `SQL laden` automatisch het bestaande omgevingspad: lokaal de repo-dump en op productie `/srv/shiny-server/Meijendel.sql`; een niet-bestaand relatief standaardpad wordt niet meer vooraf ingevuld.
- Het PQ-vegetatiemeetnet staat in de levende MySQL-database in de `pq_`-tabellen. De voorlopige PZH-export van 17 juli 2026 voegt `SRTNUM`, soortenlijstversie, `PLABED` en reproduceerbare importprovenance toe; historische RD-geometrie blijft per opname bewaard. De repositorydump wordt uitsluitend uit de gevalideerde levende database gegenereerd.
- Vierendertig afwijkende nieuw aangeleverde bodemcodes zijn per opname als `te_bevestigen` vastgelegd zonder de bestaande canonieke bodemcode te overschrijven. `PLABED` en de nog inconsistente milieu-indicatorvelden worden niet als analysecovariaat gebruikt.
- `pq_plot_jaar_vegetatie` levert uitsluitend daadwerkelijk gemeten plot-jaren en voedt vegetatiecovariaten in Shiny en het blok `Vegetatiemeetnet (PQ)` onder `Plots-kenmerken` in het dashboard.
- De publieke website gebruikt alleen de veilige view `website_plot_vegetatie_jaar`; ruwe taxa, PQ-nummers en historische coördinaten blijven intern.
- De Meijendel-productiedeploy maakt vóór iedere MySQL-import een volledige VPS-databaseback-up, valideert na import de PQ-tabellen/view en historische geometrie en herstelt de back-up automatisch als import of validatie faalt.
- `R/check_dashboard_website_parity.R` controleert de gegenereerde Groepen-output voor websitegebruik: verplichte CSV's, kolommen, chart-id's, numerieke waarden, jaarbereik en aanwezigheid van de Meijendel-serie.
- `deploy/update_en_deploy_meijendel.sh` voert deze check automatisch uit na `R/build_groepen_grafieken_dashboard_csv.R` en vóór deploy.
- Websitegrafieken blijven daarmee afgeleid van `groepen_grafieken/groep_dichtheid.csv`; losse websiteberekening blijft uitgesloten.
- `R/check_shiny_dashboard_parity.R` controleert de Shiny-berekeningskern tegen de dashboard-CSV `trim_msi_evg/msi_per_groep_per_jaar.csv`.
- Dashboard-MSI is canoniek voor publicatie en websiteafleiding. Shiny volgt daarom dezelfde MSI-definitie: pre/post-1984 TRIM-modellen, brugfactor op basis van 1981-1983 versus 1984-1986, groeps-MSI op `index_gebrugged`, en `robuust` op soorten met een bruikbare pre- en postreeks.
- `shiny_meijendel/helpers.R` is gelijkgetrokken met de dashboardlogica voor de Shiny-groep-MSI.
- `deploy/update_en_deploy_meijendel.sh` en `deploy/deploy_meijendel_vps.sh` voeren `R/check_shiny_dashboard_parity.R` nu als harde deploygate uit over 1958-2025 voordat Shiny/de dashboardomgeving naar de VPS gaat.
- De paritycontrole tussen Shiny en dashboard is actueel groen.
- De Shiny-deploycontrole toont voortaan ook containerstatus en resourcegebruik.

Open:

- Shiny blijft relatief zwaar doordat de app TRIM-modellen interactief kan draaien; gebruik blijft daarom bedoeld voor redacteuren/beheerders en niet als publieke rekenservice.

## Soortpagina's

Gereed:

- Publieke vogelsoortdetailpagina's combineren legacy/CMS-teksten, vooraf gegenereerde Meijendel-cijfers en read-only Meijendel-kenmerkdata.
- De kopknoppen verwijzen naar `Beschrijving`, `Voorkomen` en alleen bij beschikbare data naar `Kenmerken`.
- Het blok `Vogelkenmerken` leest bestaande Meijendel-tabellen voor ecologische vogelgroepen, Rode/Oranje Lijst, Vogelrichtlijn en soortkenmerken, maar schrijft niets terug naar Meijendel of CMS.
- Kenmerken worden bewust als doorlopende tekst getoond, zonder technische veldcodes of waarde-labels.

Resterende risico's:

- Er is nog geen uitgebreide visuele regressiecheck over meerdere soorten en viewports.

Aanbevolen volgende stap:

- Voer een visuele regressiecheck uit over meerdere soorten en viewports.

## Nieuws en CMS

Gereed:

- Nieuwsitems worden lokaal in de FastAPI/Jinja-site aangepast, gecommit en daarna naar de VPS gedeployed.
- De nieuwseditor ondersteunt afbeeldinguploads vanuit een nieuwsbericht; productiebeelden zijn runtime-data onder `app/static/uploads/cms`.
- De startpagina en `/nieuws/index.asp` sorteren gepubliceerde nieuwsitems op nieuwste bovenaan. Bij gelijke publicatiedatum is de nieuwste database-id leidend.
- `/nieuws/index.asp` toont alleen een korte tekstsamenvatting zonder start-afbeeldingen; de volledige inhoud staat op de detailpagina achter `Lees verder`.
- De editor-/preview-layout is zo aangepast dat invoertekst en preview niet meer over elkaar heen vallen.

Resterende risico's:

- De ingelogde nieuwsflow is nog niet volledig geautomatiseerd getest.
- Brede deploys moeten CMS-uploads expliciet behouden.
- Archief/OCR-systemd units moeten apart op productie worden geactiveerd en gecontroleerd als die live gebruikt worden.

Aanbevolen volgende stap:

- Voer een ingelogde redactiecheck uit waarin een redacteur een nieuwsbericht met afbeelding maakt, publiceert en terugziet op startpagina, nieuwsoverzicht en detailpagina.

## Leden en contentbeheer

Gereed:

- Leden met een actuele BMP- of winterkavelkoppeling in `app.teller_assignments` voor het lopende jaar krijgen beperkte toegang tot `Contentbeheer`.
- Beperkte leden zien binnen Contentbeheer alleen de module `Kavels` en daarna alleen de kavelteksten waarvoor zij in het lopende jaar teller zijn.
- Niveau 4 en 5 behouden volledige toegang tot vaste pagina's, soortteksten en alle kavelteksten.
- De ledenpagina `Mijn gegevens en rechten` toont BMP-kavels, winterkavels en PTT-route uit dezelfde actuele jaartoewijzingen als de ledenadministratie, met fallback naar oude app- of legacyvelden.
- Kavelbezetting kan lokaal vanuit de beveiligde website-CSV-export worden gecontroleerd en verwerkt met `scripts/apply_website_kavelbezetting.py`: volledige jaarroute (`dry-run`, `plan`, `apply`) en lopend-jaar-diffroute (`diff-run`, `diff-plan`, `diff-apply`).

Resterende risico's:

- De server-side checks zijn actief en de algemene smoke-test is groen.
- Er is nog geen volledige ingelogde browsertest met een gewoon telleraccount voor kaveltekst openen, wijzigen en publiceren.
- PTT-routeteksten zijn nog niet beschikbaar zolang er geen aparte route-tekstmodule of routepagina's zijn.

Aanbevolen volgende stap:

- Voer een ingelogde test uit met een niveau-1 telleraccount en controleer ledenpagina, Contentbeheer-tegel, kaveltekstlijst, bewerken/publiceren en publieke kavelpagina.

## Vogelrichtlijn en groepen

Gereed:

- De Vogelrichtlijn-groep gebruikt dezelfde `richtlijn_id = 7` bron als de Meijendel-database en het dashboard.
- Dashboardgroepen gebruiken voor `Vogelrichtlijn` dezelfde twee weergaven als andere groepen: `Dichtheid per km2` en `TRIM`.
- Websitegrafiek `vogelrichtlijn` wordt vooraf gegenereerd via `R/build_groepen_grafieken_dashboard_csv.R`.
- De publieke FastAPI/Jinja-site leest deze CSV-output via `/srv/vwgm/www/groepen_grafieken/`.
- `Contentbeheer` beheert de tekst via app-CMS-key `groups:vogelrichtlijn`.

Resterende risico's:

- De route werkt en de algemene smoke-test is groen.
- Er is nog geen ingelogde CMS-publicatietest voor deze vaste pagina.

Aanbevolen volgende stap:

- Voer een ingelogde CMS-publicatietest uit voor de vaste pagina `Vogelrichtlijn`.
