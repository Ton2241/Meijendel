# Deploy naar VPS

Lees vóór VPS-werk `../docs/vps_productie.md` en de gedeelde canonieke
momentopname in
`/Users/ton/Documents/GitHub/VWG_Project/VPS_PRODUCTIESTATUS.md`.

## Verplichte veilige productielijn

Werk op een taakgerichte branch, maar deploy uitsluitend vanaf `main`. De wijziging moet vóór deploy zijn getest, naar `main` gemerged en gepusht. Lokaal `main` moet schoon zijn en exact gelijklopen met `origin/main`; rechtstreeks deployen vanaf een feature- of fixbranch is verboden.

Het deployscript moet vóór iedere productieaanpassing afdwingen:

- de actieve branch is `main` en de werkboom is schoon;
- lokaal `main` is exact gelijk aan `origin/main`;
- de op de VPS geregistreerde Meijendel-productiecommit bestaat en is een voorouder van de nieuwe commit;
- een exclusieve VPS-deploy-lock voorkomt gelijktijdige of overlappende deploys;
- een dry-run en expliciet manifest tonen alle samenhangende SQL-, R-, Shiny-, dashboard- en CSV-bestanden;
- de huidige productiecontrole is uitgevoerd en afwijkingen zijn verklaard.

Na een Shiny-imagebuild mag herbouwbare Docker-buildcache ontstaan. De log- en
kwetsbaarheidmonitor rapporteert de omvang, ongebruikte images/containers en
trialdatamappen afzonderlijk. Zij verwijdert niets zelf en mag de actieve
MySQL-9.7.1-datamap of de bewust behouden MySQL-9.5-rollback nooit als cache
behandelen.

De toegestane eindsituatie bestaat uit de actieve containers
`meijendel-mysql` en `shiny_meijendel` plus uitsluitend de aangewezen gestopte
rollback `meijendel-mysql-95-rollback-20260813T104315Z`. De canonieke imagetags
zijn `vwgm-mysql:9.7.1`, `vwgm-mysql:9.5.0-rollback` en
`vwgm-shiny:latest`. Kandidaat-, test-, `previous`- en mislukte containers,
redundante tags, ongebruikte images en herbouwbare taakcache horen na groene
activering niet in de eindsituatie. Controleer exacte targets en mounts en ruim
de tijdens de taak gemaakte artefacten als afsluitstap van dezelfde taak op.
Verwijder een bestaande rollbackcontainer of -datamap alleen na afzonderlijke
expliciete beoordeling.

Voer vóór iedere MySQL-imagewisseling of Shiny-imagebuild en opnieuw op de
kandidaat vóór activering de vaste containercontrole uit:

```sh
cd /Users/ton/Documents/GitHub/VWG_Project
scripts/vulnerability_audit_vps.sh --containers-only
scripts/vulnerability_audit_vps.sh --containers-only --image sha256:VOLLEDIGE_IMAGE_ID
```

De scan gebruikt exacte image-ID's en rapporteert `HIGH` en `CRITICAL` met de
beschikbare fix. Zij past geen image of container aan. Een noodzakelijke fix
wordt afzonderlijk gebouwd, getest en uitsluitend via deze veilige
productielijn geactiveerd.

Deploy bij voorkeur naar een release-directory per commit en activeer die atomisch. Waar dit voor gedeelde Meijendel-data nog niet mogelijk is, moet het manifest volledig zijn en moeten tijdelijke bestanden pas na succesvolle validatie atomisch naar hun definitieve pad worden verplaatst. Deploy geen los gedeeld kernbestand vanuit een andere branch.

Na deploy wacht het script met begrensde retries op Shiny en dashboard, controleert checksums, containerstatus, HTTP-routes en relevante grafiekinhoud, en registreert pas daarna de nieuwe productiecommit. Herstelmodus is alleen toegestaan met expliciete bevestiging wanneer productie al defect is; ancestrycontrole, lock, manifest en volledige groene nacontrole blijven verplicht.

Iedere rsync-verwijdering blokkeert `--apply` standaard. Alleen na expliciete beoordeling kan een deploy met verwijderingen worden gestart met `--apply --yes --allow-delete`. Lokale metadata zoals `.DS_Store` wordt altijd uitgesloten.

## Release-manifest afronden

Een geslaagde deploy en groene nacontrole zijn nog niet het einde van de release. Werk daarna het centrale bestand `/Users/ton/Documents/GitHub/VWG_Project/RELEASE_MANIFEST.yml` bij:

1. lees `/srv/vwgm/deploy-state/VWG_M.commit` en `/srv/vwgm/deploy-state/Meijendel.commit`;
2. controleer dat beide commits voorouders zijn van de respectieve `origin/main`;
3. voeg een nieuwe, onveranderlijke release toe met exact één commit per repository;
4. pas `current_release` aan;
5. valideer YAML en commit/push/merge de wijziging naar `VWG_Project/main`.

Als alleen Meijendel wijzigde, blijft de geregistreerde VWG_M-commit ongewijzigd in de nieuwe release. Een productiedeploy is administratief niet afgerond zolang deze manifeststap ontbreekt.

Als het huidige deployscript een van deze controles nog niet technisch afdwingt, moet die beveiliging eerst worden geïmplementeerd en getest. Voer tot die tijd geen nieuwe productiedeploy uit.



## Uitvoeren

Voor de volledige standaardroutine: database dumpen, afgeleide bestanden opnieuw genereren en daarna deployen:

```sh
cd /Users/ton/Documents/GitHub/Meijendel
./deploy/update_en_deploy_meijendel.sh
```

Dit script genereert en controleert de lokale output, maar deployt niet meer in dezelfde run. Commit en push de gegenereerde bestanden, merge naar `main` en voer daarna vanaf een schone, actuele `main` eerst de deploy-preflight en vervolgens de bevestigde deploy uit.

Voor alleen deployen van al bijgewerkte lokale bestanden:

```sh
cd /Users/ton/Documents/GitHub/Meijendel
./deploy/deploy_meijendel_vps.sh
./deploy/deploy_meijendel_vps.sh --apply --yes
```

Eerste, eenmalige inrichting nadat de werkelijk draaiende productiecommit is vastgesteld en in `main` is geïntegreerd:

```sh
./deploy/deploy_meijendel_vps.sh --initialize-state VOLLEDIGE_GIT_COMMIT --yes
```

Voor het opnieuw installeren van de Caddy-configuratie voor `app.vwg-m.nl`:

```sh
cd /Users/ton/Documents/GitHub/Meijendel
./deploy/deploy_caddy_vps.sh
./deploy/deploy_caddy_vps.sh --apply --yes
```

Voor het herbouwen van het Shiny-image geldt dezelfde tweestapswerkwijze:

```sh
./deploy/rebuild_shiny_image_vps.sh
./deploy/rebuild_shiny_image_vps.sh --apply --yes
```

De Shiny-basisimage staat in `deploy/shiny_image/Dockerfile` vast op een
multi-platformdigest. De Dockerfile is multi-stage: de builder bevat de
compilers, headers en `*-dev`-pakketten; de uiteindelijke runtime bevat alleen
de expliciete uitvoerbibliotheken en de gekopieerde R-packages. De
definitietest blokkeert onder meer `linux-libc-dev`, compilers en ontwikkel-
packages in de runtime.

`rebuild_shiny_image_vps.sh` maakt bij beveiligingsonderhoud eerst een
kandidaat met `--pull --no-cache`, scant de exacte resulterende image-ID en
start hem op een
afwijkende localhostpoort met dezelfde read-only mounts. Activeer hem pas na de
package-, ontbrekende-library-, cache- en readinesscontroles. Een kandidaat
met een `CRITICAL`- of `HIGH`-bevinding wordt niet geactiveerd. Bij een fout
na het begin van de wissel zet het script de vorige exacte image-ID automatisch
terug. Houd de vorige image-ID alleen tijdens
de gecontroleerde activering en directe rollbackperiode beschikbaar. Leg het
bewijs daarna vast in scanuitvoer en het release-manifest en verwijder de oude
container, tag en image als zij niet de expliciet aangewezen rollback zijn.

De versievaste MySQL-afgeleiden staan in `deploy/mysql_image/`. Zij werken
Oracle Linux-pakketten bij, maar schakelen de MySQL-repositories tijdens die
update uit. Daardoor blijven server en clients exact 9.7.1 respectievelijk
9.5.0. De niet gebruikte `mysql-shell` wordt verwijderd. `gosu` 1.19 wordt
vanaf commit `6456aaa0f3c854d199d0f037f068eb97515b7513` opnieuw gebouwd met de
digestvaste Go 1.25.13-builder en functioneel getest.

Voor iedere MySQL-kandidaat geldt:

1. bouw vanaf de passende Dockerfile en leg de volledige image-ID vast;
2. scan die ID met `VWG_Project/scripts/vulnerability_audit_vps.sh --image`;
3. test 9.7.1 via een verse logische dump/import, exacte rijtellingen en
   `CHECK TABLE ... EXTENDED` op een afwijkende localhostpoort;
4. test 9.5.0 tegen een tijdelijke fysieke kopie van uitsluitend zijn eigen,
   gestopte 9.5-datamap;
5. voer de wissel onder `/srv/vwgm/deploy-state/production.lock` uit, behoud de
   vorige containers en image-ID's uitsluitend gedurende activering en directe
   rollbackcontrole en draai readiness en de volledige rooktest;
6. wijzig de herstelimage-ID en het centrale release-manifest mee.

Na een groene wissel worden alle in deze taak gemaakte kandidaten en de niet als
rollback aangewezen vorige containers, tags en images exact verwijderd. Toon
daarna `docker ps -a`, `docker images`, `docker system df`, de exacte image-scan,
back-upstatus en de volledige rooktest. Een volgende taak mag niet beginnen met
onverklaarde tijdelijke Docker-artefacten.

Een 9.7-datamap mag nooit met 9.5 worden gestart. Kandidaatdatamappen en
testcontainers zijn tijdelijk; actieve en rollbackdatamappen worden niet
opgeruimd als onderdeel van imageonderhoud.

Als het script geen uitvoerrechten heeft:

```sh
chmod +x /Users/ton/Documents/GitHub/Meijendel/deploy/update_en_deploy_meijendel.sh
chmod +x /Users/ton/Documents/GitHub/Meijendel/deploy/deploy_meijendel_vps.sh
chmod +x /Users/ton/Documents/GitHub/Meijendel/deploy/deploy_caddy_vps.sh
```

Daarna opnieuw:

```sh
cd /Users/ton/Documents/GitHub/Meijendel
./deploy/deploy_meijendel_vps.sh
```

## Controle na afloop

Het script toont aan het einde zelf:

- checksums van de SQL op Shiny en `www`
- containerstatus via `docker ps`
- SQL-cache-status, bijvoorbeeld `SQL cache: from_cache=TRUE ...`

Handmatig controleren kan met:

```sh
ssh -i ~/.ssh/vwgm_spectraip_ed25519 ton@45.87.43.90
docker ps
curl -I http://127.0.0.1:3838/
```

## Wat wordt bijgewerkt

Het script uploadt alleen gewijzigde bestanden met `rsync --checksum` en werkt deze VPS-onderdelen bij:

- canonieke SQL met de veilige koppeltabel `tellers` (`id`, `tellercode`) en zonder historische `pwa_*`-objecten: `/srv/vwgm/data/Meijendel.sql`
- compatibiliteitspaden voor Shiny, dashboard en FastAPI zijn symlinks naar de canonieke SQL:
  - `/srv/vwgm/shiny/Meijendel.sql`
  - `/srv/vwgm/www/Meijendel.sql`
  - `/srv/vwgm/vwg-m-linux-app/data/Meijendel.sql`
- Shiny-app: `/srv/vwgm/shiny/shiny_meijendel/`
- gedeelde R-code: `/srv/vwgm/shiny/R/`
- HTML-dashboard: `/srv/vwgm/www/bmp_meijendel_index.html`
- dashboard-outputmappen:
  - `/srv/vwgm/www/output_ecologische_groepen/`
  - `/srv/vwgm/www/trim_msi_evg/`
  - `/srv/vwgm/www/wintertellingen/` (alle canonieke wintersoorten, protocolmatrix, gevalideerde indices, beschrijvende reeksen, dekking en besluitstatus)
- vooraf gegenereerde websitegrafieken voor Groepen:
  - `/srv/vwgm/www/groepen_grafieken/gam_dashboard_groepen.csv`
  - `/srv/vwgm/www/groepen_grafieken/groep_soorten.csv`
  - `/srv/vwgm/www/groepen_grafieken/groep_dichtheid.csv`

Daarna voert het script op de VPS uit:

- een gedateerde back-up van de bestaande MySQL-database `meijendel` onder `/srv/vwgm/backups/meijendel-mysql/`;
- import van de gefilterde canonieke SQL in container `meijendel-mysql`, gevolgd door controles op de PQ-tabellen, publieke vegetatieview en historische geometrie; bij import- of validatiefout wordt de zojuist gemaakte databaseback-up automatisch hersteld;
- Shiny `app_cache` behouden en schrijfbaar mounten
- Shiny-container `shiny_meijendel` na vervanging van de canonieke SQL geforceerd
  opnieuw aanmaken, zodat de bind mount altijd de actuele SQL-inode gebruikt
- Shiny HTTP-endpoint controleren
- SQL-cache voorverwarmen, zodat de eerste gebruiker niet de volledige SQL-parse hoeft af te wachten

Het script maakt geen automatische backup op de VPS.

De ledenadministratie/PWA wordt niet meer naar de VPS gedeployed en hoort op productie niet te draaien.
`www.vwg-m.nl` bevat voor productie Meijendel:

- startpagina/app-home
- dashboard `bmp_meijendel_index.html` met bijbehorende outputbestanden
- Shiny-app onder `/shiny_meijendel/`

Daarnaast zijn er op dezelfde VPS proefroutes voor het nabouwen van de VWG-site:

- statische proefsite onder `/proef-vwg-m/` vanuit `/srv/vwgm/vwg-m-proef/public`
- publieke VWG-M website onder `/` via `127.0.0.1:8091`
- tijdelijke proefalias onder `/proef-vwg-m-app/` via `127.0.0.1:8091`

De normale Meijendel-deploy raakt `/srv/vwgm/vwg-m-proef/` niet aan.

Toegang tot dashboard, Shiny, SQL en dashboard-output loopt op `www.vwg-m.nl`
via Caddy `forward_auth` naar de VWG-M ledenlogin. De voormalige hoofdhost
`app.vwg-m.nl` verwijst ieder pad permanent met HTTP 308 naar hetzelfde pad op
`www.vwg-m.nl`. Er is geen PWA-login, magic-link-login of
ledenadministratie-API op productie.

## Grafieken op de VWG-site

Alle grafieken op `app.vwg-m.nl` moeten qua cijfers en opmaak gelijk blijven aan de dashboardgrafieken. Gebruik daarom geen losse webberekening en parse `Meijendel.sql` niet per request. De FastAPI/Jinja-site leest vooraf gegenereerde CSV-output:

```sh
/srv/vwgm/www/groepen_grafieken/gam_dashboard_groepen.csv
/srv/vwgm/www/groepen_grafieken/groep_soorten.csv
/srv/vwgm/www/groepen_grafieken/groep_dichtheid.csv
```

`groep_dichtheid.csv` bevat per `chart_id` de dashboardgelijke dichtheidsreeks: territoria per jaar gedeeld door het Meijendel-oppervlak in dat jaar. Deze CSV is leidend voor de groepsgrafieken op de FastAPI/Jinja-site. `groep_soorten.csv` bevat per `chart_id` de soortnamen die voor de grafiek zijn gebruikt en wordt onder de grafiek op de groepspagina getoond. `gam_dashboard_groepen.csv` blijft beschikbaar als historische/analytische output voor TRIM-GAM, maar wordt niet meer gebruikt voor de groepsgrafieken op de website. De productie-CSV bevat dit voor de ecologische groepen, Rode/Oranjelijstgroepen en Natura 2000-habitatgroepen. De SVG-route is:

```sh
/groepen/grafiek/{chart_id}.svg
```

Voor ecologische groepen gebruikt de CSV direct de dashboardbestanden in `trim_msi_evg/`. Voor Rode/Oranje en habitatgroepen volgt de CSV-generator dezelfde dashboardlogica: de Meijendel-lijn wordt opgebouwd uit de TRIM-soortindexbestanden in `trim/soorten/`, habitatsoorten komen uit `soorten_habitattypen` in `Meijendel.sql`, en de landelijke lijn wordt gewogen samengesteld uit `gam_voorspellingen_landelijk_msi_groepen.csv`. Er is dus geen aparte website-GAM of habitat-fallback meer.

De CSV wordt in de standaardroutine gegenereerd door:

```sh
Rscript R/build_groepen_grafieken_dashboard_csv.R meijendel.sql groepen_grafieken
```

Daarna uploadt `deploy/deploy_meijendel_vps.sh` de map `groepen_grafieken/` naar `/srv/vwgm/www/groepen_grafieken/`.

## Caddy en toegang

De Caddy-configuratie staat in de repo als template:

```sh
deploy/caddy/Caddyfile.template
```

De actuele productieconfiguratie in de leidende repository `VWG_M` beschermt
de analyseroutes van `www.vwg-m.nl`; `app.vwg-m.nl` verwijst met HTTP 308 door
naar de overeenkomstige `www`-route:

- startpagina `/`
- dashboard `/bmp_meijendel_index.html`
- SQL-data `/Meijendel.sql` en `/meijendel.sql`
- Shiny-app `/shiny_meijendel/`
- dashboard-outputmappen
- publieke website `/`
- tijdelijke proefroutes `/proef-vwg-m/` en `/proef-vwg-m-app/`

De publieke website op `app.vwg-m.nl` gebruikt geen algemene Basic Auth meer. Het dashboard, de dashboard-outputbestanden, Shiny en de SQL-dump blijven afgeschermd via `forward_auth` naar de VWG-M ledenlogin.

Secrets, sessiesleutels, wachtwoorden en eventuele oude Basic Auth-hashes staan bewust niet in de repo. De oude include `/etc/caddy/vwg_basic_auth.caddy` kan op de server blijven staan voor rollback, maar de actuele template importeert deze niet meer. Noteer geheime waarden alleen in een password manager of server-side secret store; niet in Git.

`deploy/deploy_caddy_vps.sh`:

- genereert bij elke run een nieuwe sessie-secret
- valideert en installeert de publieke Caddy-config
- uploadt een tijdelijke Caddyfile
- valideert de config met `caddy validate`
- maakt een backup van `/etc/caddy/Caddyfile`
- herlaadt Caddy
- controleert dat directe toegang zonder sessie `401` geeft en met sessie `200`

Een normale Meijendel-deploy via `deploy/deploy_meijendel_vps.sh` overschrijft Caddy niet. Gebruik `deploy/deploy_caddy_vps.sh` alleen bij nieuwe VPS-inrichting of bij bewuste wijziging van de Caddy-routes/authenticatie.

Zowel de Caddy-deploy als de Shiny-image-rebuild gebruikt dezelfde geregistreerde Meijendel-productiecommit en globale VPS-deploy-lock. Zonder `--apply --yes` voeren deze scripts alleen validatie, manifest/dry-run en huidige productiecontrole uit.

## Voorwaarden

Voer het script uit vanaf de lokale iMac waarop deze repo staat.

Benodigd:

- SSH-key: `~/.ssh/vwgm_spectraip_ed25519`
- toegang tot VPS: `ton@45.87.43.90`
- lokale MySQL bereikbaar op `127.0.0.1:3306`; het dump-script gebruikt `mysqldump --no-defaults` om conflicterende opties uit `~/.my.cnf` te negeren
- lokale MySQL-server, `mysql`, `mysqldump` en de productiecontainer draaien exact op MySQL 9.7.1; de preflight blokkeert iedere versieafwijking
- login-path `meijendel_root` is lokaal beschikbaar voor de niet-interactieve versiecontrole; overschrijven kan alleen via `MEIJENDEL_MYSQL_LOGIN_PATH`
- de versiecontrole gebruikt de tools uit `PATH` en valt bij de officiële macOS-pakketinstallatie terug op `/usr/local/mysql/bin`
- de dump wordt gemaakt met kolomnamen in `INSERT`-regels (`--complete-insert`), omdat de R-scripts die kolomnamen gebruiken bij het inlezen
- GTID-restore-informatie wordt bewust niet meegenomen (`--set-gtid-purged=OFF`) en de dump gebruikt `--single-transaction`
- de tabel `tellers` wordt meegenomen en mag uitsluitend `id` en `tellercode` bevatten; de preflight blokkeert ieder uitgebreider schema
- lokaal SQL-bestand: `meijendel.sql` in de repo-root; op de VPS wordt dit uitsluitend geplaatst als `/srv/vwgm/data/Meijendel.sql`
- op de VPS bestaande Docker/Compose-config onder `/srv/vwgm`

## Configuratie overschrijven

Standaard gebruikt het script:

```sh
VPS=ton@45.87.43.90
SSH_KEY=~/.ssh/vwgm_spectraip_ed25519
REMOTE_BASE=/srv/vwgm
MYSQL_HOST=127.0.0.1
MYSQL_PORT=3306
MYSQL_USER=root
MYSQL_DATABASE=meijendel
```

Deze waarden kunnen tijdelijk worden overschreven:

```sh
VPS=ton@andere-host SSH_KEY=~/.ssh/andere_key ./deploy/deploy_meijendel_vps.sh
MYSQL_PORT=3307 ./deploy/update_en_deploy_meijendel.sh
```
