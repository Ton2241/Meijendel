# Actuele VPS-productie voor Meijendel

Momentopname: **18 augustus 2026, 12:36 CEST**. De volledige gedeelde hostinventaris staat
canoniek in `/Users/ton/Documents/GitHub/VWG_Project/VPS_PRODUCTIESTATUS.md`.
Controleer live voordat een versieclaim opnieuw wordt gebruikt.

## Actieve componenten

| Onderdeel | Actieve versie of status |
|---|---|
| Ubuntu | 24.04.4 LTS, kernel 6.8.0-137-generic |
| Docker Engine | 29.7.2 |
| containerd | 2.3.3 |
| Docker Compose | 5.4.0 |
| Buildx | 0.36.1 |
| MySQL | exact 9.7.1 |
| MySQL-image | `sha256:7a3fab78504a0ed4fb7abda10761e5335d7c1c0228ef09fdafe1cac29c764784` |
| Shiny | container `shiny_meijendel`, image `sha256:478ed47b333524f8b26df445919e1fc888ed243bc14951b14eb03d772f1ad906` |
| R in Shiny | 4.6.0 |
| Caddy | 2.11.4 |
| PostgreSQL | 16.14, voor de VWG-M-app en ledenrechten |

De actieve MySQL-container is `meijendel-mysql`. De datamap staat
versiegescheiden onder
`/srv/vwgm/meijendel-mysql-971-cutover-20260813T104315Z/data`. De canonieke
SQL-dump staat in `/srv/vwgm/data/Meijendel.sql`; Shiny en websitepaden wijzen
naar die gecontroleerde bron.

De gestopte container `meijendel-mysql-95-rollback-20260813T104315Z`, het
MySQL-9.5-image en `/srv/vwgm/meijendel-mysql/data` blijven bewust beschikbaar
als versiegescheiden rollback. Dit is herstelcapaciteit, geen afval. De
rollback wordt uiterlijk 25 augustus opnieuw beoordeeld volgens `TODO.md`.

Actieve Meijendel-productiecommit:
`e22e54227abd0b388bec27bc911c747aa496eea0`.

## Opslag en containers

Na gecontroleerde opschoning zijn alleen drie containers aanwezig:

- actief: `meijendel-mysql`;
- actief: `shiny_meijendel`;
- gestopt en bewust behouden: `meijendel-mysql-95-rollback-20260813T104315Z`.

Op 18 augustus zijn na controle van mounts en imageverwijzingen alle
kandidaat-, `previous`- en mislukte container- en imageartefacten plus de
herbouwbare buildcache verwijderd. Docker bevat exact deze drie containers en
de drie bijbehorende canoniek getagde images. Het rapporteert 0 B ongebruikte
image-opslag, 0 B buildcache en geen volumes. Het rootfilesystem gebruikt 23
van 77 GB (30%). Een volgende
Shiny-imagebuild kan hierdoor langer duren, maar is volledig reproduceerbaar
uit `deploy/shiny_image/`. De multi-stagebuild houdt compilers, ontwikkelheaders
en `linux-libc-dev` buiten de runtime; de actieve image bevat 275 OS-pakketten.

## Beveiliging en beheer

- MySQL is niet publiek bereikbaar en `meijendel_read` heeft uitsluitend
  `SELECT` op het Meijendel-schema.
- Dashboard, Shiny, SQL en vereiste output lopen via Caddy `forward_auth` naar
  de VWG-M-login.
- UFW laat alleen SSH, HTTP en HTTPS toe.
- Ubuntu Pro is gekoppeld met alleen `esm-apps`; APT heeft 0 open updates en
  er is geen reboot nodig.
- De bare-metalback-up van 18 augustus 12:36 CEST is checksumgeldig en bevat
  uitsluitend de drie toegestane images, een volledig proefherstelde dump en
  179 archieffoto's.

## Monitor- en retentieafspraak

De log- en kwetsbaarheidmonitor controleert voortaan ook:

- exacte MySQL-versie en image-ID;
- Trivy-scan van de exacte image-ID's van actieve MySQL en Shiny en de bewust
  behouden MySQL-9.5-rollbackcontainer;
- actieve versus gestopte containers en hun mounts;
- Shiny/R-versie en HTTP-readiness;
- Docker buildcache, ongebruikte images/containers/volumes en tijdelijke
  trialdatamappen;
- dat de actieve 9.7.1-datamap en de bewust behouden 9.5-rollback niet als
  generieke cache worden verwijderd;
- release-state, SQL-symlinks, back-upchecksum en rooktests.

De monitor rapporteert read-only. Verwijderen gebeurt alleen na expliciete
opdracht en na controle van exacte targets en mounts.
De scan wordt wekelijks en vóór iedere MySQL-imagewisseling of Shiny-imagebuild
uitgevoerd via
`VWG_Project/scripts/vulnerability_audit_vps.sh --containers-only`. Scan een
al op de VPS aanwezige kandidaat vóór activering aanvullend met
`--image sha256:...`. Rapporteer iedere `CRITICAL`- en `HIGH`-bevinding met
geïnstalleerde versie en beschikbare fix. Een bevinding leidt nooit automatisch
tot pull, rebuild, containerwissel of herstart; daarvoor blijft de normale
test-, preflight- en deploylijn verplicht.

De eerste volledige imagescan van 18 augustus 2026 vond in Shiny 17
`CRITICAL`/233 `HIGH`, in actieve MySQL 1/27 en in de 9.5-rollback 1/88. De
daaropvolgende kandidaatbuilds zijn exact gescand en geïsoleerd getest en onder
de deploylock geactiveerd. De eerste runtimekandidaat bevatte nog
`linux-libc-dev`; de definitieve multi-stagebuild verwijdert alle bouwpakketten.
Actief zijn Shiny `sha256:478ed47b...`, MySQL 9.7.1 `sha256:7a3fab78...` en de
MySQL-9.5-rollback `sha256:d15ac8c7...`, alle met 0 `CRITICAL`/0 `HIGH`.
Na de afsluitende opruiming bleven de exacte scan en volledige
multi-hostrooktest groen; herstelbewijs staat in scans, back-up en release, niet
in extra gestopte containers.
