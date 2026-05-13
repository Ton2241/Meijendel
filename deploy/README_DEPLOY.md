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

Als het script geen uitvoerrechten heeft:

```sh
chmod +x /Users/ton/Documents/GitHub/Meijendel/deploy/update_en_deploy_meijendel.sh
chmod +x /Users/ton/Documents/GitHub/Meijendel/deploy/deploy_meijendel_vps.sh
```

Daarna opnieuw:

```sh
cd /Users/ton/Documents/GitHub/Meijendel
./deploy/deploy_meijendel_vps.sh
```

## Controle na afloop

Het script toont aan het einde zelf:

- output van de publieke PWA auth-status
- aantal regels in databaseview `pwa_teller_stats`
- checksums van de SQL op Shiny en `www`
- containerstatus via `docker ps`

Handmatig controleren kan met:

```sh
ssh -i ~/.ssh/vwgm_spectraip_ed25519 ton@45.87.43.90
docker ps
curl -sS http://127.0.0.1:8091/api/auth/status.php
curl -I http://127.0.0.1:3838/
```

## Wat wordt bijgewerkt

Het script uploadt alleen gewijzigde bestanden met `rsync --checksum` en werkt deze VPS-onderdelen bij:

- Shiny SQL: `/srv/vwgm/shiny/Meijendel.sql`
- HTML/dashboard SQL: `/srv/vwgm/www/Meijendel.sql`
- Shiny-app: `/srv/vwgm/shiny/shiny_meijendel/`
- gedeelde R-code: `/srv/vwgm/shiny/R/`
- ledenadministratie/PWA-code: `/srv/vwgm/ledenadministratie/`
- HTML-dashboard: `/srv/vwgm/www/bmp_meijendel_index.html`
- dashboard-outputmappen:
  - `/srv/vwgm/www/output_ecologische_groepen/`
  - `/srv/vwgm/www/trim_msi_evg/`

Daarna voert het script op de VPS uit:

- Docker Compose-stack voor ledenadministratie/PWA rebuilden en starten
- `Meijendel.sql` opnieuw importeren in `leden_pwa_mysql`
- PWA-views opnieuw aanmaken/verversen
- Shiny-container `shiny_meijendel` herstarten
- publieke PWA auth-status, databaseview `pwa_teller_stats` en Shiny HTTP-endpoint controleren

Het script maakt geen automatische backup op de VPS.

De oude servermap `/srv/vwgm/ledenadministratie/deploy/sql/` wordt bewust genegeerd. De actuele PWA-views staan in `/srv/vwgm/ledenadministratie/sql/`; de oude map kan op de VPS root-rechten hebben en is niet nodig voor de huidige Docker Compose-config.

## Voorwaarden

Voer het script uit vanaf de lokale iMac waarop deze repo staat.

Benodigd:

- SSH-key: `~/.ssh/vwgm_spectraip_ed25519`
- toegang tot VPS: `ton@45.87.43.90`
- lokale MySQL bereikbaar op `127.0.0.1:3306`; het dump-script gebruikt `mysqldump --no-defaults` om conflicterende opties uit `~/.my.cnf` te negeren
- de dump wordt gemaakt met kolomnamen in `INSERT`-regels (`--complete-insert`), omdat de R-scripts die kolomnamen gebruiken bij het inlezen
- GTID-restore-informatie wordt bewust niet meegenomen (`--set-gtid-purged=OFF`) en de dump gebruikt `--single-transaction`
- lokaal SQL-bestand: `meijendel.sql` in de repo-root
- lokaal PWA-project: `pwa_ledenadministratie/`
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
