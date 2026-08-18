# Actuele VPS-productie voor Meijendel

Momentopname: **14 augustus 2026**. De volledige gedeelde hostinventaris staat
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
| MySQL-image | `sha256:cbade841779f1661300e705721f9d2ff159865cc7a8a291affbff43ac6ec7f1d` |
| Shiny | container `shiny_meijendel`, image `vwgm-shiny:latest` |
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
gestopte 9.7.1-proefcontainer en zijn tijdelijke `/var/tmp`-datamap zijn op 14
augustus verwijderd.

Actieve Meijendel-productiecommit:
`3c42c8934a767e9817a72d034cd70c5bf3d9cdfd`.

## Opslag en containers

Na gecontroleerde opschoning zijn alleen drie containers aanwezig:

- actief: `meijendel-mysql`;
- actief: `shiny_meijendel`;
- gestopt en bewust behouden: `meijendel-mysql-95-rollback-20260813T104315Z`.

Alle 9,5 GB herbouwbare Docker-buildcache en het `hello-world`-testimage zijn
verwijderd. Docker rapporteert daarna 0 B buildcache en geen ongebruikte
volumes. Het rootfilesystem gebruikt 21 van 77 GB (28%). Een volgende
Shiny-imagebuild kan hierdoor langer duren, maar is volledig reproduceerbaar
uit `deploy/shiny_image/`.

## Beveiliging en beheer

- MySQL is niet publiek bereikbaar en `meijendel_read` heeft uitsluitend
  `SELECT` op het Meijendel-schema.
- Dashboard, Shiny, SQL en vereiste output lopen via Caddy `forward_auth` naar
  de VWG-M-login.
- UFW laat alleen SSH, HTTP en HTTPS toe.
- Ubuntu Pro is gekoppeld met alleen `esm-apps`; APT heeft 0 open updates en
  er is geen reboot nodig.
- De bare-metalback-up van 14 augustus 01:19 CEST is checksumgeldig en bevat
  de vastgepinde MySQL-herstelimage, een volledig proefherstelde dump en de
  Shiny-image.

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
de deploylock geactiveerd. Actief zijn Shiny `sha256:3846e58a...` met 0
`CRITICAL`/43 `HIGH` zonder fix, MySQL 9.7.1 `sha256:7a3fab78...` met 0/0 en
de MySQL-9.5-rollback `sha256:d15ac8c7...` met 0/0. De resterende
Shiny-meldingen zitten uitsluitend in `linux-libc-dev 6.8.0-137.137`.
