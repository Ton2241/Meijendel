# Besluiten

- Het dashboard is leidend voor alle grafieken. De site mag geen eigen afwijkende grafieklogica of cijfers introduceren.
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
- Versie 1 gebruikt vijf groepen: bodemfoeragerende insecteneters, luchtfoerageerders, grondbroeders, holenbroeders en langeafstandstrekkers.
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
- TR1 bevat naast 14 verplichte doeltraits acht ondersteunende brontraits. Deze
  bewaren binaire of semikwantitatieve broninformatie zonder een kunstmatig lokaal
  percentage te construeren.
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
