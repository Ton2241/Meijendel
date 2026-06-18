# Deploy naar VPS



## Uitvoeren

Voor de volledige standaardroutine: database dumpen, afgeleide bestanden opnieuw genereren en daarna deployen:

```sh
cd /Users/ton/Documents/GitHub/Meijendel
./deploy/update_en_deploy_meijendel.sh
```

Voor alleen deployen van al bijgewerkte lokale bestanden:

```sh
cd /Users/ton/Documents/GitHub/Meijendel
./deploy/deploy_meijendel_vps.sh
```

Voor het opnieuw installeren van de Caddy-configuratie voor `app.vwg-m.nl`:

```sh
cd /Users/ton/Documents/GitHub/Meijendel
./deploy/deploy_caddy_vps.sh
```

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

- Shiny SQL zonder `tellers`, `appsmith_*` en `pwa_*` objecten: `/srv/vwgm/shiny/Meijendel.sql`
- HTML/dashboard SQL zonder `tellers`, `appsmith_*` en `pwa_*` objecten: `/srv/vwgm/www/Meijendel.sql`
- Shiny-app: `/srv/vwgm/shiny/shiny_meijendel/`
- gedeelde R-code: `/srv/vwgm/shiny/R/`
- HTML-dashboard: `/srv/vwgm/www/bmp_meijendel_index.html`
- dashboard-outputmappen:
  - `/srv/vwgm/www/output_ecologische_groepen/`
  - `/srv/vwgm/www/trim_msi_evg/`
- vooraf gegenereerde websitegrafieken voor Groepen:
  - `/srv/vwgm/www/groepen_grafieken/gam_dashboard_groepen.csv`
  - `/srv/vwgm/www/groepen_grafieken/groep_soorten.csv`
  - `/srv/vwgm/www/groepen_grafieken/groep_dichtheid.csv`

Daarna voert het script op de VPS uit:

- Shiny `app_cache` behouden en schrijfbaar mounten
- Shiny-container `shiny_meijendel` via `docker compose up -d shiny` controleren/herstarten
- Shiny HTTP-endpoint controleren
- SQL-cache voorverwarmen, zodat de eerste gebruiker niet de volledige SQL-parse hoeft af te wachten

Het script maakt geen automatische backup op de VPS.

De ledenadministratie/PWA wordt niet meer naar de VPS gedeployed en hoort op productie niet te draaien.
`app.vwg-m.nl` bevat voor productie Meijendel:

- startpagina/app-home
- dashboard `bmp_meijendel_index.html` met bijbehorende outputbestanden
- Shiny-app onder `/shiny_meijendel/`

Daarnaast zijn er op dezelfde VPS proefroutes voor het nabouwen van de VWG-site:

- statische proefsite onder `/proef-vwg-m/` vanuit `/srv/vwgm/vwg-m-proef/public`
- publieke VWG-M website onder `/` via `127.0.0.1:8091`
- tijdelijke proefalias onder `/proef-vwg-m-app/` via `127.0.0.1:8091`

De normale Meijendel-deploy raakt `/srv/vwgm/vwg-m-proef/` niet aan.

Toegang tot dashboard, Shiny, SQL en dashboard-output loopt via Caddy `forward_auth` naar de VWG-M ledenlogin. Er is geen PWA-login, magic-link-login of ledenadministratie-API op productie.

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

De template beschermt alle routes van `app.vwg-m.nl`:

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

## Voorwaarden

Voer het script uit vanaf de lokale iMac waarop deze repo staat.

Benodigd:

- SSH-key: `~/.ssh/vwgm_spectraip_ed25519`
- toegang tot VPS: `ton@45.87.43.90`
- lokale MySQL bereikbaar op `127.0.0.1:3306`; het dump-script gebruikt `mysqldump --no-defaults` om conflicterende opties uit `~/.my.cnf` te negeren
- de dump wordt gemaakt met kolomnamen in `INSERT`-regels (`--complete-insert`), omdat de R-scripts die kolomnamen gebruiken bij het inlezen
- GTID-restore-informatie wordt bewust niet meegenomen (`--set-gtid-purged=OFF`) en de dump gebruikt `--single-transaction`
- de tabel `tellers` wordt niet meegenomen in de deploy-dump
- lokaal SQL-bestand: `meijendel.sql` in de repo-root
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
