# Architectuur

Dit project bestaat uit twee nauw gekoppelde repositories en een VPS-productieomgeving.

## Repositories

- `/Users/ton/Documents/GitHub/Meijendel` bevat `meijendel.sql`, R-analyses, Shiny, dashboard/HTML-output, GIS-data en analysemiddelen.
- `/Users/ton/Documents/GitHub/VWG_M/website/vwg-m-linux-app` bevat de FastAPI/Jinja-site voor `app.vwg-m.nl` en straks `www.vwg-m.nl`.
- Projectbrede afspraken staan in `/Users/ton/Documents/GitHub/VWG_Project`.
- Wijzigingen worden lokaal gemaakt en na controle standaard gecommit in de betreffende repository met een korte, beschrijvende commitmelding.

## Productie

- VPS: `45.87.43.90`.
- Actuele versies, containerpaden en retentie:
  `docs/vps_productie.md`; gedeelde canonieke hostinventaris:
  `/Users/ton/Documents/GitHub/VWG_Project/VPS_PRODUCTIESTATUS.md`.
- App-pad: `/srv/vwgm/vwg-m-linux-app`.
- Runtime-data: onder meer `/srv/vwgm/www`, uploads, archiefdocumenten, dashboard/grafiekoutput en back-ups.
- Canonieke SQL: `/srv/vwgm/data/Meijendel.sql`.
- Caddy verzorgt TLS, reverse proxy en `forward_auth` naar de ledenlogin.

## Applicaties

- Publieke site: Start, Meijendel, Vogels, Groepen, Tellingen, Nieuws en Werkgroep.
- Ledenomgeving: dashboard, nieuws toevoegen, mediabibliotheek, archief, contentbeheer, administratie, kavelbeheer, systeembeheer, auditlogboek, back-ups en bezoekersstatistiek.
- Dashboard en Shiny blijven onderdeel van dezelfde productieomgeving, maar zijn afgeschermd via Caddy.

## Databases

- Lokale live Meijendel-database op iMac: MySQL 9.7.1. De MySQL-container op de VPS draait eveneens exact 9.7.1.
- De lokale server is de schrijfbron. De VPS wordt uitsluitend via de gecontroleerde dump/import-deploy bijgewerkt; er is geen tweerichtingsreplicatie.
- Lokale MySQL is bron voor historische/controlerende gegevens zoals `tellers`, `plots` en `plot_jaar_teller`. `tellers` bevat uitsluitend de pseudonieme technische sleutel `id` en de unieke `tellercode`; persoonsgegevens en weergavenamen komen alleen uit de afgeschermde PostgreSQL-ledenadministratie.
- VPS PostgreSQL is operationele bron voor ledenadministratie, CMS, nieuws, archief, kavelbeheer, auditlogging en back-upmetadata.
- `meijendel.sql` is data-/importbron en back-upformaat, niet bedoeld voor snelle webrequests.

### Beveiligde NDFF-laag

### Openbare NDFF- en vangblikbronnen

De geïntegreerde openbare FFV-staging en de openbare GBIF-vangblikreeks
1953-1960 staan sinds 10 september 2026 in nieuwe brontabellen van de lokale
`Meijendel`-database. Dit zijn bronregistraties naast, niet in, de bestaande
vogel- en provinciale PQ-tabellen. `ndff_open_waarneming` bewaart 810.830
ontdubbelde FFV-regels met de openbare geometrie en `ndff_soorten` 9.828 taxa;
fysieke `ndff_<soortgroep>`-tabellen verwijzen genormaliseerd naar deze regels.

De vangblikreeks behoudt haar eigen korrel in `vangblik_locatieversie`,
`vangblik_event`, `vangblik_soorten` en `vangblik_vangst`. De 55 openbare
geversioneerde SOVON-plotgrenzen staan in `ndff_sovon_plot`; alle 37.770 events
zijn eenduidig aan één versie-2025-plot gekoppeld. Geen openbare FFV-regel en
geen vangst is door deze technische opname automatisch toegelaten voor trend-,
abundantie-, afwezigheids- of beheer-effectanalyse.

Protocolkwalificatie is een genormaliseerde afleidingslaag naast de bronregels.
`Meijendel.ndff_open_waarneming_protocol` koppelt ieder openbaar record aan één
interne `protocol_id`; `Meijendel_ndff_secure.ndff_waarneming_protocol` doet
hetzelfde binnen de beveiligde laag. Beide verwijzen naar de niet-gevoelige
catalogus `Meijendel.ndff_protocol`. De stabiele functionele sleutel is
`protocol_sleutel`; de recordkoppeling onderscheidt `expliciete_code` van
`expliciet_losse_waarneming`. Deze metadata verleent geen analysetoegang en
wijzigt geen analyse-, verspreidings-, trend- of innamestatus.

De inhoudelijke doelbereiklaag staat in
`Meijendel.ndff_protocol_soortgroep_geschiktheid`. Gemengde combinaties worden
in `Meijendel.ndff_protocol_soort_geschiktheid` verder uitgesplitst tot
doelsoort, bijvangst of taxonomisch onbepaald. De actuele versies zijn
`ndff-protocolbereik-v2` en `ndff-analysebesluit-v4`; eerdere versies blijven
auditspoor. Nieuwe analyses gebruiken deze tabellen vóór het
analysebesluit, zodat een niet-doelsoort geen trendgeschiktheid kan erven van
alleen de protocolcode.

De gereconstrueerde openbare NEM-routeketens staan eveneens in `Meijendel`.
`ndff_vlinder_*`, `ndff_vliesvleugel_*`, `ndff_libel_*`, `ndff_reptiel_*`,
`ndff_amfibie_*` en `ndff_vleermuis_*` bewaren per geversioneerde reconstructie meeteenheden,
brongeometrieën, bezoeken en de bezoek-soortmatrix. De libellenketen bewaart aanvullend `doelbereikstatus`,
zodat echte nullen alleen ontstaan bij een aantoonbaar algemene route en niet
bij een grof eensoortbezoek met onbekend bereik.
De reptielenketen gebruikt route plus kalenderdatum als bezoekeenheid en
behoudt expliciet dat volledig negatieve bezoeken en feitelijke inspanning niet
uit de FFV-levering kunnen worden hersteld. Alleen Hazelworm krijgt binnen een
bevestigd positief reptielenbezoek een afgeleide echte nul.
De amfibieënketen onderscheidt telgebiedbezoek en bevestigd waterbezoek. Zij
houdt exacte aantallen, presentieklassen en gemengde telwaarden uit elkaar en
leidt geen waterbezoeken of nullen af voor de vervaagde, jaarlijks
geaggregeerde Kamsalamanderrecords.
De vleermuisketen houdt NEM-VTT-auto en vleerMUS-fiets als twee routefamilies
gescheiden, bewaart de selectie van dubbele bronregels en telt akoestische
detecties nooit als individuele dieren. De doelsoortenlijst verschilt per
methodevariant; echte nullen ontstaan alleen binnen dat eigen bereik.
`ndff_konijn_*` is bewust geen bezoekmatrix. De bron bevat exacte positieve
sectietellingen van `17.209`, maar geen route- of sectie-id; de tabellen bewaren
daarom een recordclassificatie en een uitsluitend diagnostische
hok-datum-taxonsamenvatting. Geen daarvan is een native NEM-meeteenheid en er
worden geen nullen of routegebonden trends uit afgeleid.
`ndff_daz_bmp_*` koppelt openbare `17.204`-zoogdierregistraties op datum en
SOVON-plot aan de bestaande `dagbezoeken_bmp`. Een eenduidige positieve
koppeling bevestigt dat de teller tijdens dat BMP-bezoek aan DAZ deelnam.
Alleen voor zulke bezoeken bevat `ndff_daz_bmp_bezoek_taxon` een volledige
matrix voor de zeven DAZ-doelsoorten. Meervoudig koppelbare records blijven in
de kandidaatbrug en blokkeren taxonspecifiek een nul. Niet-bevestigde
BMP-bezoeken en bijvangsten krijgen nooit een afgeleide nul.
`ndff_zeereep_*` reconstrueert protocol `11.202` op RD-kilometerhok en
kalenderdatum. De zes typische doelsoorten vormen een volledige bezoekmatrix;
NMV-vindplaatsklassen blijven ordinale klassen. Vervaagde records worden niet
tot bezoeken gemaakt en seizoenstatus, ontbrekende bezoektijd en nog niet
gevalideerde waarnemersbekwaamheid blijven expliciet zichtbaar.
`ndff_bospaddenstoel_*` reconstrueert het historische protocol `11.201` in
`Meijendel`: drie vaste meetpuntfamilies, de zes brongeometrieën, een
recordselectie die exacte tellingen boven parallelle presentie kiest, een
conservatief meetpunt-doelbereik, bezoeken, bezoek-soortmatrix en jaarlijkse
maximumtelling. De keten bewaart echte nullen alleen binnen aantoonbaar gevolgde
telsoorten en houdt `11.201` volledig gescheiden van opvolger `11.204`.
`ndff_hns_*` reconstrueert protocol `12.204` in `Meijendel` als
inventarisaties, recordselectie, lokaal doelbereik, inventarisatie-taxonmatrix
en hok-jaar-taxontabel. Alleen datum/ruimteclusters die onder
`ndff-hns-v1` aannemelijk volledige HNS-lijsten zijn krijgen afgeleide nullen.
De laag bewaart onafhankelijkheid van herhaalde clusters als afzonderlijke,
nog niet bevestigde eigenschap en gebruikt bron-aantallen niet als abundantie.

Openbare SNL-records met protocol `12.205` hebben een aparte, geversioneerde
overlaplaag in `Meijendel.ndff_snl_waarneming_context`. Die legt mogelijke of
bevestigde dubbeling met andere protocolregistraties vast, maar kent op basis
van alleen een ontbrekende match nooit de eigenschap `onafhankelijk` toe.

De op 10 september 2026 ontvangen onvervaagde levering voor NDFF-ticket 58679
blijft een afzonderlijke lokale bronlaag. Het originele GeoPackage, de exacte
geometrie, NDFF-identiteiten en de
ruimtelijke koppeling worden op de Samsung T7 beheerd onder
`/Volumes/T7 Data/Home_Ton/Meijendel data/NDFF/secure/ticket_58679`.

De lokale import gebruikt het afzonderlijke MySQL-schema
`Meijendel_ndff_secure`, een eigen `ndff_soorten`-tabel en fysieke
`ndff_<soortgroep>`-tabellen. Het algemene account `meijendel_read` krijgt geen
rechten op dit schema. De gewone `meijendel.sql`, website, algemene Shiny-app en
VPS ontvangen geen ruwe beveiligde regels, exacte geometrie of NDFF-identiteit.
De provinciale PQ-reeks in de life-database is de oorspronkelijke en
gezaghebbende PQ-bron. NDFF-PQ wordt in het beveiligde schema alleen als
secundaire controlebron geregistreerd en is door een afzonderlijke bronvlag
uit alle analyseviews geblokkeerd; zij kan de provinciale reeks niet aanvullen,
wijzigen of overschrijven.
Alleen later afzonderlijk goedgekeurde, niet-herleidbare analyses mogen worden
gepubliceerd. Het voorbereidende schema staat in
`gis/database/ndff_secure_schema.sql`. De eerste gecontroleerde import van
ticket 58679 is op 10 september 2026 uitgevoerd: alle 14.573 bronrecords zijn
als beveiligde bronregistratie opgenomen, 8.494 daarvan zijn uitsluitend voor
verspreidingscontext toegelaten en geen enkel NDFF-PQ-bronrecord is toegelaten.
Van deze regels koppelen 14.420 via de reeds gehashte openbare FFV-identiteit;
153 beveiligde regels hebben geen openbare tegenhanger. Deze koppeltabel staat
uitsluitend in `Meijendel_ndff_secure`.

De interne view `Meijendel_ndff_secure.v_ndff_canonieke_waarneming` vormt
daaruit één lokale bronlaag met 810.983 unieke logische waarnemingen. Zij bevat
796.410 uitsluitend openbare records, 14.420 records waarbij de beveiligde
datum, validatiestatus en exacte geometrie de openbare representatie vervangen,
en 153 uitsluitend beveiligde records. De view blijft vanwege de exacte
geometrie buiten alle gewone en Shiny-rechten.

De niet-gevoelige tabel `Meijendel.ndff_open_pq_koppeling` vormt de
geversioneerde PQ-poort voor alle openbare records. Versie
`ndff-open-pq-poort-v1` markeert 97.318 records van protocollen `12.007` en
`12.202` als secundaire controlebron en 713.512 records als niet van
toepassing. De bronhouder wordt niet zelfstandig als PQ-bewijs gebruikt.

De interne view `Meijendel_ndff_secure.v_ndff_analyse_record` is de centrale
analysepoort boven op de canonieke bronlaag. Zij bevat precies één regel per
canonieke identiteit en combineert protocolbereik, doelsoortrelatie,
ruimtelijke toelating, PQ-status en SNL-overlapstatus. De view bevat bewust
geen geometrie of exacte datum en wordt evenmin aan gewone of Shiny-accounts
toegekend. `protocol_kandidaattypen` beschrijft alleen wat het protocol in
beginsel kan ondersteunen; `gegevensgeschiktheid` blijft `niet_beoordeeld`
totdat de ontbrekende surveystructuur later afzonderlijk is gevalideerd.

Twee afgeleide interne views bieden een veilige analysekorrel zonder dagdatum,
geometrie of bronidentiteit. `v_ndff_verspreiding_plot_jaar_taxon` reduceert
voorlopig bruikbare V-records tot positieve aanwezigheid per plot, jaar en
taxon. `v_ndff_trendkandidaat_plot_jaar_taxon` bevat alleen records met een
protocolmatige kandidaatstatus voor I, TV, TA of TK, per plot, jaar, taxon en
protocol. De kolom `bronrecords_ter_controle` is uitsluitend diagnostisch en
mag nooit als abundantie worden gebruikt. Beide views blijven lokaal en hebben
vooralsnog geen extra MySQL-grants.

`v_ndff_gebruiksdekking_soortgroep_protocol` vormt de sluitende
dekkingsadministratie boven deze lagen. De view bevat 142 combinaties uit 28
soortgroepen en 54 protocollen en telt per combinatie de canonieke records,
doelrelaties, kandidaattypen, uitsluitingsredenen, beveiligde records en nog te
valideren records. Zij bevat geen jaar, plot, taxon of bronidentiteit en krijgt
geen extra grants.

Stap 3 gebruikt daarnaast vier jaarniveau-views. `v_ndff_soortenrijkdom_plot_jaar`
en `v_ndff_dekking_intensiteit_plot_jaar_soortgroep` hebben dezelfde
plot-jaar-soortgroepkorrel, zodat rijkdom en waarnemingsintensiteit rechtstreeks
kunnen worden gecontroleerd. `v_ndff_eerste_laatste_plot_taxon` beschrijft
uitsluitend eerste en laatste positieve registratie. De view
`v_ndff_verspreidingsverandering_taxon_jaar` vergelijkt alleen jaren waarin een
taxon is geregistreerd en geeft met `jaarafstand` en `aansluitend_jaar`
expliciet aan of werkelijk sprake is van opeenvolgende jaren. Geen enkele view
maakt nulwaarnemingen of afwezigheid aan.

De volledige lokale keten is vastgezet als `ndff-analyseketen-v1`. Deze versie
staat in de centrale analysepoort en alle afgeleide analyseviews. De alleen-
lezen eindaudit in `import_ndff_protocolkwaliteit.py --audit-live` controleert
het vaste recordprofiel, unieke sleutels, statusaansluitingen, afgeleide
totalen, jaargaten en grants. Een geslaagde audit verklaart de keten uitsluitend
gereed voor verkennende verspreidingsanalyse; surveygeschiktheid en
trendvalidatie blijven een afzonderlijke vervolgfase.

Deze status staat verkennende berekeningen nadrukkelijk toe. De views leveren
registratie-, verspreidings-, rijkdoms- en intensiteitsmaten en protocolmatige
trendkandidaten. De verplichte kwaliteitsmelding begrenst de interpretatie:
zonder aanvullende surveyvalidatie zijn dit geen gevalideerde
populatietrends, abundanties, afwezigheden of causale beheereffecten.

## Functionele vogelgroepen en traits

De bestaande tabellen `soorten_kenmerken`, `soorten_kenmerken_datadictionary` en
`soorten_kenmerken_hoofdcategorien` blijven tijdens de migratie de ongewijzigde
legacybron. Hun codes worden niet hernoemd: bestaand `F` betekent functionele
habitat/foerageerwijze en bestaand `V` betekent voedsel van volwassen vogels.

De in fase B geïmplementeerde traitlaag bestaat uit de volgende onderdelen:

- `trait_definition`: versieerbare definitie, domein, datatype, eenheid,
  levensfase en standaardseizoen van één trait;
- `trait_category`: toegestane categorieën voor categorische traits;
- `trait_source`: volledige bron, datasetversie, DOI/URL, licentie en
  raadpleegdatum;
- `trait_import_batch`: reproduceerbare import met bronversie, bestands-SHA en
  gebruikte taxonomie;
- `trait_taxon_mapping`: expliciete koppeling tussen bronnaam en Meijendel-soort;
- `trait_analysis_scope` en `trait_analysis_scope_species`: versieerbare,
  gescheiden afbakening van alle 159 territoriumhoudende broedvogels en de 95
  soorten met een bruikbare lange TRIM-reeks;
- `species_trait_value`: één soortwaarde met afzonderlijke velden voor numeriek,
  boolean of categorie, plus seizoen, levensfase, geografische/populatiecontext,
  kwaliteitsstatus en voorkeursstatus;
- `species_trait_value_source`: één of meer bronnen per soortwaarde;
- `legacy_trait_mapping`: expliciete, beoordeelde vertaling van een bestaande
  code naar nul, één of meer nieuwe traits;
- `functional_group_definition`: versie, onderzoeksvraag, drempels en
  machineleesbare selectieregel van een afgeleide groep;
- `functional_group_membership`: reproduceerbare materialisatie per
  groepsversie met binair lidmaatschap, gewicht, onderbouwing en generatiecommit.
- `v_trait_gap_v1`: controleweergave voor alle 159 × 15 verplichte
  soort-traitcombinaties en de benodigde vervolgactie.

Belangrijke constraints:

- precies één waardetype per niet-onbekende `species_trait_value`; een expliciete
  `unknown` heeft juist geen numerieke, boolean- of categoriewaarde;
- onbekend is `NULL` met status `unknown`, nooit automatisch `FALSE` of `0`;
- proporties liggen tussen 0 en 1;
- maximaal één voorkeurswaarde per soort, trait, levensfase, seizoen en context
  bij scalaire traits;
- bij meerkeuzetraits maximaal één voorkeurswaarde per soort, trait, categorie,
  levensfase, seizoen en context;
- een publiceerbare waarde heeft minimaal één controleerbare bron;
- soorten mogen in meerdere functionele groepen voorkomen;
- afgeleide groepen lezen uitsluitend goedgekeurde voorkeurswaarden van een
  vastgelegde traitversie.

De nieuwe tabellen staan sinds fase B naast de ongewijzigde legacytabellen. Naast
de 15 verplichte doeltraits bevat `TR1` acht ondersteunende brontraits. De
bronhiërarchie voor de doelcontext is: Nederlandse soortbron, Europese fallback,
mondiale fallback. Het Nederlands Soortenregister en de Vogelbescherming-
vogelgids dekken elk alle 159 scopesoorten; Europese en mondiale waarden behouden
hun oorspronkelijke context en worden niet stilzwijgend lokaal gemaakt.

Voor alle 159 × 15 doelcontexten is een goedgekeurde voorkeurswaarde vastgelegd.
Kwalitatieve Nederlandse feiten zijn met vaste klassen omgezet in
semikwantitatieve analyseproxies. De omzettingsregel is zelf als bron
`TR1_DERIVATION_RULES_V1` geregistreerd; iedere eindwaarde verwijst daarnaast
naar minimaal twee inhoudelijke bronnen. `confidence_score` en `evidence_note`
maken onderscheid tussen directe classificatie en grovere proxy. Categorie
`not_applicable` maakt bij niet-holenbroeders expliciet onderscheid tussen
"niet van toepassing" en onbekend. De gapview aggregeert meerkeuzecategorieën en
rapporteert alle 2.385 verplichte cellen als `gereed`.

Fase C materialiseert exact één rij per groep en scopesoort in
`functional_group_membership`, dus 6 × 159 = 954 rijen. De machineleesbare regels
gebruiken niet alleen de numerieke drempels, maar ook de verplichte
foerageermethode, het substraat, nesthoogte, holtetype en winterregio. Iedere
`rationale_json` bevat de beslisreden, gebruikte waarde-id's, confidence,
bronlocators en de classificatie bij een inclusieve (−0,10) en strikte (+0,10)
drempel. `generation_commit` verwijst naar de Git-toestand met de goedgekeurde
fase-B-input. De traits-scope staat los van modelleerbaarheid: de volledige
functionele variant kan iedere later modelleerbare soort gebruiken; de robuuste
variant houdt de afzonderlijke 95-soortenscope aan.

De zesde definitie `fg_v1_zaad` gebruikt het verplichte volwassen-dieettrait
`TR1_DIET_SEED_SHARE`. De baseline classificeert waarden vanaf `0,50` als
primair en vanaf `0,25` als secundair; de generieke inclusieve en strikte
drempelvarianten blijven ook voor deze groep beschikbaar.

`v_functional_group_membership_v1` ontsluit de soortclassificaties;
`v_functional_group_summary_v1` levert primaire/secundaire aantallen, binaire en
gewogen omvang, gevoeligheidsaantallen én -statussen, minimumconfidence,
publicatiestatus en de minimumstatus na weglaten van één soort. Deze views zijn
controle- en analysebronnen; publicatie volgt pas na inhoudelijke accordering en
pariteit.

Fase D leest de goedgekeurde materialisatie rechtstreeks uit de SQL-dump. De
canonieke functionele MSI gebruikt dezelfde gebrugde TRIM-soortindices als de
ecologische groepen en wordt per groep berekend als gewogen geometrisch
gemiddelde. Er zijn altijd vier varianten: `binair`/`gewogen` ×
`volledig`/`robuust`. Standalone dashboard en Shiny moeten exact paritair zijn;
websitegrafieken lezen uitsluitend de vooraf gegenereerde dashboard-CSV.

Dashboard, Shiny en lokale websitecode zijn na groene pariteitscontroles
aangesloten. Functionele groepen blijven aanvullend; legacytabellen en bestaande
ecologische groepen blijven read-only beschikbaar. Productie volgt uitsluitend
via de afzonderlijke deploy-preflight en release-registratie.

## Grafieken

Alle grafieken op de FastAPI/Jinja-site moeten overeenkomen met het dashboard. Het dashboard is leidend voor brondata, berekening, schaal, labels, legenda, kleuren en onzekerheidsweergave.

Webgrafieken gebruiken vooraf gegenereerde dashboard-output/CSV. Parse `meijendel.sql` niet per webrequest.

## Toegang

- Toegang tot dashboard, SQL, Shiny en dashboard-output loopt via Caddy `forward_auth` naar de VWG-M ledenlogin.
- Er is geen PWA- of magic-link-login voor de actuele productie-inrichting.
- PWA-documentatie is historische context, niet leidend voor productie.

## Back-up

Er is een bare-metal back-uproutine op de VPS. De NAS DS225+ haalt de nieuwste back-up rechtstreeks vanaf de VPS naar de gedeelde map `VWG-M-Backups`.

Runtime-data hoort in back-ups. Secrets, SSH keys en wachtwoorden horen niet plaintext in Git, maar moeten wel herstelbaar zijn via de afgesproken beheer- en herstelprocedure.
