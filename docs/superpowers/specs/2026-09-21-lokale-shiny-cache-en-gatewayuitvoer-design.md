# Ontwerp: lokale Shiny-cache en begrensde gatewayuitvoer

Datum: 21 september 2026
Status: ter inhoudelijke goedkeuring
Leidende repository: `Meijendel`

## Aanleiding

Release `2026-09-21.1` maakte twee zwakke plekken zichtbaar.

1. De eerste Shiny-cacheopbouw voor `Meijendel.sql` van 2.758.897.731 bytes
   vond op de productie-VPS plaats. R las de dump herhaaldelijk; de opbouw duurde
   circa 26 minuten en gebruikte maximaal circa 2,85 GB RAM op een VPS met
   circa 3,8 GiB geheugen. Na de opbouw werkte de persistente cache wel: de
   Shiny-route antwoordde met HTTP 200 in 5,75 seconden en circa 2,8 GB RAM was
   weer beschikbaar.
2. De gesloten releasegateway rondde de release af, maar een na de
   Shiny-herstart geërfd uitvoerkanaal hield de oorspronkelijke SSH-sessie open.
   De beheeractie was klaar; de lokale client kon dat niet betrouwbaar uit de
   nog open verbinding afleiden.

Deze twee verbeteringen moeten bij iedere volgende verversing automatisch deel
uitmaken van de bestaande export- en deployketen. Zij zijn geen losse
beheerhandelingen.

## Doel en succescriteria

De levende lokale MySQL-database `Meijendel` op de iMac blijft de canonieke
schrijfbron. `Meijendel.sql`, de Shiny-cache, productie-MySQL, dashboard en
website blijven afgeleiden.

De wijziging is geslaagd wanneer:

- een gevalideerde nieuwe dump automatisch een lokaal gebouwde, inhoudsgebonden
  Shiny-cache krijgt;
- dump, dumpmanifest en cache aantoonbaar bij elkaar horen;
- de productie-VPS een nieuwe dump nooit meer als terugvalroute volledig door R
  parseert;
- een ontbrekende, beschadigde of niet-passende cache de release vóór
  activering blokkeert;
- gatewayuitvoer tijdens de hele beheeractie uitsluitend naar een uniek,
  beveiligd tijdelijk VPS-bestand gaat en pas na beëindiging wordt opgehaald;
- zowel gateway als lokale deploy een eindstatus en exitcode krijgen, met een
  harde maar voor import en rollback ruime tijdsgrens;
- bestaande back-up-, automatische databaserollback-, rooktest-,
  commit-ancestry- en globale deploy-lockcontroles behouden blijven;
- normaal functioneren van website, MySQL en Shiny tijdens voorbereiding niet
  wordt belast door cacheberekening of parallelle zware taken.

## Gekozen aanpak

De cache wordt op de lokale iMac vooraf gebouwd en samen met de dump als één
hashgebonden release-eenheid behandeld. De VPS voert alleen goedkope
integriteits- en leescontroles uit. Productie gebruikt een expliciete
`cache-verplicht`-modus en mag bij een cachemisser niet terugvallen op parsen.

Deze aanpak heeft de voorkeur boven:

- opnieuw voorverwarmen op de VPS, ook met `nice`, `ionice` of een
  geheugenlimiet: dat vermindert de schade maar houdt de 26 minuten durende
  zware productieberekening in stand;
- uitsluitend de SQL-parser optimaliseren: dat is nuttig als latere,
  afzonderlijke verbetering, maar niet nodig om de productiebelasting nu
  sluitend te voorkomen;
- de NAS als rekenknooppunt gebruiken: de NAS is voor back-up en herstel, niet
  voor deze releaseberekening. De iMac is de bronmachine en bouwt de cache één
  keer per gewijzigde dump.

## Releaseartefacten en identiteit

Een databaseverversing levert vier gekoppelde artefacten op:

1. `meijendel.sql`;
2. `meijendel.sql.manifest`;
3. `meijendel_tables_cache-p<PARSER>-<SQL_SHA256>.rds`;
4. `meijendel_tables_cache-p<PARSER>-<SQL_SHA256>.manifest`.

Het dumpmanifest noemt de exacte basenames van cache en cachemanifest. Alleen
een basename volgens dit patroon wordt geaccepteerd; paden, `..` en symlinks
worden geweigerd.

De cache-identiteit bestaat minimaal uit:

- formaat- en cachecontractversie;
- `sql_sha256` uit het gevalideerde dumpmanifest;
- `sql_bytes`;
- `MEIJENDEL_PARSER_CACHE_VERSION`;
- R-serialisatieversie en de gebruikte R-versie;
- cachebestandsgrootte en SHA-256 van het cachebestand;
- aanmaakmoment en broncommit, uitsluitend als provenance en niet als
  geldigheidscriterium.

Het absolute pad van `Meijendel.sql` maakt geen deel meer uit van de
cache-identiteit. Daardoor kan een cache die lokaal voor dezelfde bytes is
gebouwd veilig worden gebruikt bij het productiepad
`/srv/shiny-server/Meijendel.sql`. Na het laden wordt `data$sql_path` altijd op
het actuele lokale runtimepad gezet.

Het cachebestand krijgt een inhoudsgebonden naam op basis van SQL-hash en
parser-versie. Daardoor overschrijft een kandidaat nooit de cache van de
actieve of vorige dump. Gegenereerde caches en hun tijdelijke bestanden blijven
buiten Git. Lokaal blijft alleen de cache bewaard waarnaar het actuele
dumpmanifest verwijst. Op de VPS blijven na een geslaagde release de actieve en
de direct voorafgaande gevalideerde cache beschikbaar; verwijdering van de
voorafgaande cache volgt pas wanneer ook de bestaande rollbackretentie wordt
beëindigd.

## Lokale export en cachebouw

`scripts/export_meijendel_sql.sh` blijft de enige normale ingang voor een
nieuwe database-export. De bestaande tijdelijke dump wordt eerst volledig
geïmporteerd in een tijdelijk lokaal schema en gevalideerd. Daarna bouwt een
afzonderlijke helper de Shiny-cache uit precies die tijdelijke dump.

De helper:

- gebruikt de bestaande parser en geen tweede implementatie van de
  tabelselectie;
- schrijft eerst naar een tijdelijk bestand;
- leest het resultaat opnieuw in en controleert cachestructuur, verplichte
  tabellen, SQL-identiteit en parser-versie;
- controleert met een tweede cache-load dat `from_cache=TRUE` is;
- maakt het cachemanifest en verifieert beide SHA-256-hashes;
- publiceert dump, dumpmanifest, cache en cachemanifest pas nadat alle vier
  controles zijn geslaagd.

Bij een fout blijven de eerder geldige vier artefacten staan. Tijdelijke dump,
proefschema en kandidaatcache worden door de bestaande cleanup uitgebreid en
opgeruimd. Een ongewijzigde SQL-hash met dezelfde parser-versie hergebruikt de
al gevalideerde lokale cache; de 26 minuten durende berekening wordt dus alleen
uitgevoerd wanneer de dumpinhoud of parser-versie verandert.

De cachebouw draait lokaal, serieel en niet tegelijk met een productiedeploy.
Er komt geen periodieke of continue taak bij. De extra rekentijd hoort alleen
bij een handmatig gestarte databaseverversing.

## Runtimecontract van Shiny

De bestaande functie `load_meijendel_tables_cached()` krijgt twee modi.

- Lokaal/ontwikkeling: een cachemisser mag, zoals nu, de dump parsen en een
  cache bouwen.
- Productie/deployvalidatie: `MEIJENDEL_REQUIRE_PREBUILT_CACHE=1` verplicht een
  geldige vooraf gebouwde cache. Een misser, foutieve hash, verkeerde
  parser-versie of onleesbare RDS geeft direct een gerichte fout. De parser
  wordt in deze modus niet aangeroepen.

De cachevalidatie gebruikt de reeds door de deploy geverifieerde SQL- en
cachemanifesten. De dumpgrootte wordt nogmaals met `stat` gecontroleerd. De
deploy controleert de werkelijke SHA-256 van dump en cache vóór de container
wordt herstart; Shiny hoeft daarom bij ieder proces niet opnieuw 2,76 GB te
hashen.

Een cache die met een lokaal afwijkende R-versie is geschreven, wordt vóór
database-import door de exacte kandidaat-Shiny-image met `readRDS()` geopend en
inhoudelijk gecontroleerd. Incompatibiliteit blokkeert dus terwijl de actieve
database en actieve Shiny-container nog ongewijzigd zijn.

## Overdracht en activering op de VPS

De lokale deploypreflight vereist voortaan alle vier artefacten. Hij controleert
de onderlinge hashes, parser-versie, cachecontractversie en schijfruimte. De
rsync-dry-run toont dump, beide manifesten en cache expliciet.

Bij `--apply --yes` worden dump en cache eerst naar commitgebonden
kandidaatpaden gestuurd. Vóór database-import voert de exacte Shiny-image een
begrensde, read-only kandidaatcontrole uit:

- kandidaatdump en kandidaatmanifest zijn gekoppeld;
- cache en cachemanifest zijn gekoppeld;
- `load_meijendel_tables_cached()` geeft in verplichte modus direct
  `from_cache=TRUE`;
- de verplichte tabellen en kolommen zijn aanwezig;
- de controle start geen volledige SQL-parse.

Pas daarna volgt de bestaande databaseback-up en import. Na een groene import
worden dumpmanifest, cachemanifest en inhoudsgebonden cache voor de nieuwe
release beschikbaar gemaakt, waarna Shiny opnieuw wordt aangemaakt. De actieve
runtimecontrole eist opnieuw `from_cache=TRUE`.

Bij een fout na het begin van de import herstelt de bestaande rollback de
database. De vorige, inhoudsgebonden cache blijft beschikbaar; kandidaatcache
en kandidaatmanifest worden niet als actief gemarkeerd. Shiny wordt met de
herstelde combinatie opnieuw gestart. De productiecommit wordt pas na de
volledige rooktest geschreven.

De VPS bouwt geen cache. Ook bij een handmatige Shiny-herstart of cacheverlies
blijft productie gesloten: eerst moet via de normale releaseketen een passende
cache worden hersteld. Dit voorkomt dat een incidentele beheerhandeling alsnog
de zware parse activeert.

## Gatewayuitvoer en tijdsgrenzen

De lokale deploy krijgt één helper voor alle gesloten gatewayaanroepen. Per
aanroep maakt de lokale laag een onvoorspelbare operatie-id. Een kleine remote
shellwrapper:

1. maakt met `umask 077` een uniek tijdelijk log- en statusbestand in de
   bestaande deploy-stateomgeving;
2. leidt stdout en stderr van `sudo -n /usr/local/sbin/vwgm-admin ...` volledig
   naar dat logbestand;
3. voert de gateway uit onder GNU `timeout`;
4. schrijft na beëindiging atomisch exitcode, eindtijd en status;
5. geeft via SSH uitsluitend de korte voltooiingsstatus terug.

Daarna haalt de lokale client het gesloten logbestand in een afzonderlijke
SSH-aanroep op, controleert operatie-id en eindstatus, toont de inhoud en
verwijdert log en statusbestand alleen na succesvolle ontvangst. Een verbroken
eerste SSH-sessie laat het bestand beschikbaar voor gerichte hervatting; een
volgende release verwijdert niet blind andere operatiebestanden.

De voorgestelde standaardgrenzen zijn:

- gatewaypreflight: 5 minuten;
- release-apply inclusief grote SQL-import: 3 uur;
- na het eerste TERM-signaal maximaal 1 uur voor de bestaande rollback- en
  hersteltrap voordat een KILL is toegestaan.

Deze waarden zijn bewust ruim ten opzichte van de release van 21 september.
Zij voorkomen een onbeperkt hangende sessie zonder een legitieme import of
rollback voortijdig af te breken. Alleen expliciete, begrensde omgevingsvariabelen
voor test- en noodsituaties mogen de waarden aanpassen; nul, negatieve en
onredelijk hoge waarden worden geweigerd.

Doordat alle procesuitvoer al vóór `sudo` naar een gewoon bestand is omgeleid,
kan een door Docker of Shiny geërfd descriptor de SSH-stdout niet meer
openhouden. `ServerAliveInterval` en `ServerAliveCountMax` blijven daarnaast de
netwerkuitval bewaken; zij vervangen de procestimeout niet.

## Belasting en beschikbaarheid

De iMac draagt de eenmalige cacheberekening. De productie-VPS ontvangt en leest
alleen de cache, controleert hashes en voert de bestaande seriële import uit.
Er worden geen cachebouw, imagebuild, database-import en zware controles
parallel gestart.

De cachekandidaatcontrole gebeurt vóór productie-import en buiten de actieve
Shiny-container. Zij heeft alleen read-only mounts en een begrensde looptijd.
De actieve website en database blijven tijdens deze voorbereiding beschikbaar.
De korte bestaande omschakeling en Shiny-herstart blijven onderdeel van het
normale deployvenster.

De NAS krijgt geen rekenrol en wordt niet tijdens de deploy benaderd. De
bestaande back-up- en herstelketen blijft ongewijzigd; een cache is afgeleid en
kan lokaal opnieuw worden gebouwd, maar de bij de actieve dump horende cache en
manifesten worden wel in het VPS-herstelarchief meegenomen voor snel herstel.

## Foutafhandeling

De release blokkeert vóór productie-import bij:

- ontbrekend artefact of manifestveld;
- verschil tussen werkelijke en vastgelegde dump- of cachehash;
- verschil in SQL-omvang;
- verkeerde parser- of cachecontractversie;
- onleesbare of inhoudelijk onvolledige RDS-cache;
- `from_cache=FALSE` in verplichte modus;
- onvoldoende VPS-schijfruimte;
- niet-afgeronde gatewaystatus, timeout of niet-nul-exitcode.

Na begonnen import blijft de bestaande automatische databaserollback leidend.
Timeoutuitvoer moet expliciet tonen of rollback is begonnen en geslaagd. Een
ontbrekende eindstatus wordt nooit als succes geïnterpreteerd. Geen van deze
fouten werkt het productie-statebestand of centrale release-manifest bij.

## Test- en verificatieplan

De implementatie begint met falende regressietests.

### Cachecontract

- dezelfde dumpbytes valideren op twee verschillende absolute paden;
- gewijzigde dumpbytes, omvang of SQL-hash worden geweigerd;
- gewijzigde parser- of cachecontractversie wordt geweigerd;
- beschadigde en inhoudelijk onvolledige RDS worden geweigerd;
- productie-verplichtmodus roept bij een misser de parser aantoonbaar niet aan;
- lokale ontwikkelmodus behoudt de bestaande terugval en schrijft atomisch;
- exportfalen laat de vorige vier geldige artefacten intact;
- een ongewijzigde dumphash hergebruikt de bestaande cache;
- de exacte Shiny-image leest de lokaal gebouwde cache vóór import;
- runtimecontrole na herstart meldt verplicht `from_cache=TRUE`.

### Gatewaycontract

- een testproces dat stdout erft, houdt de lokale SSH-uitvoer niet open;
- stdout en stderr worden na beëindiging volledig en in volgorde opgehaald;
- succes, gewone fout, TERM-timeout en afgebroken verbinding krijgen ieder een
  eenduidige status;
- logbestanden hebben modus `0600`, zijn niet voorspelbaar benoemd en worden
  niet via symlinks gevolgd;
- alleen het eigen voltooide operatiebestand wordt verwijderd;
- timeout laat de bestaande rollbacktrap lopen en een geslaagde release blijft
  de globale lock altijd vrijgeven;
- de bestaande test blijft directe lokale Docker-aanroepen verbieden.

### Volledige releasecontrole

- shellsyntax en alle bestaande Meijendel-contracttests;
- dump-/cache-export tegen een kleine fixture en tegen de actuele lokale dump;
- dry-run toont de vier gekoppelde artefacten en nul onverklaarde verwijderingen;
- kandidaatcontrole vóór import;
- volledige Shiny/dashboardpariteit en publieke soortselectie;
- productie-rooktest, statusbestanden, back-upbewijs en centrale
  release-registratie volgens de bestaande projectworkflow.

## Documentatie en beheer

De implementatie werkt minimaal bij:

- `README.md` waar de exportketen wordt beschreven;
- `ARCHITECTURE.md` voor het cache- en releasecontract;
- `deploy/README_DEPLOY.md` voor uitvoering, timeout, hervatting en fouten;
- `docs/vps_productie.md` voor de afgeleide cacheartefacten en retentie;
- `TODO.md`, waarbij beide punten pas na volledige test en productieverificatie
  als afgerond worden verwijderd.

Een toekomstige databaseverversing hoeft daarna geen afzonderlijke cache- of
gatewayhandeling meer te onthouden: het exportscript maakt de cache; de
deploypreflight eist haar; de VPS weigert een zware parse; de gateway levert
altijd een begrensde, achteraf opgehaalde uitslag.

## Buiten scope

- de gepauzeerde gestratificeerde TRIM-bootstrap;
- inzet van NAS of VPS als algemeen rekencluster;
- inhoudelijke wijziging van de levende Meijendel-database;
- optimalisatie of herschrijving van de volledige SQL-parser, zolang de
  vooraf gebouwde cache het productieprobleem sluitend oplost;
- wijziging van dashboard-, TRIM- of websiteselecties.
