# Actuele VPS-productie voor Meijendel

Momentopname: **5 september 2026**. De volledige gedeelde hostinventaris staat
canoniek in `/Users/ton/Documents/GitHub/VWG_Project/VPS_PRODUCTIESTATUS.md`.
Controleer live voordat een versieclaim opnieuw wordt gebruikt.

## Extern herstelbewijs

Op 5 september 2026 is de provider-onafhankelijke bare-metal
restore-rehearsal volledig groen uitgevoerd op een lege Scaleway DEV1-M in
AMS 1 met Ubuntu 24.04 en 100 GB block storage. De NAS-back-up van 4 september
23:15 UTC (SHA-256
`6952f9e50ea94a25967579cffefb2e96708530c6bff89ff39d60af1082bff1fc`)
herstelde PostgreSQL, de vastgepinde MySQL 9.7.1-image met UID/GID 1999, Shiny,
de VWG-M-app en Caddy. De lokale HTTPS-keten eindigde op 200; e-mail en vier
productietimers bleven geblokkeerd. Productie-DNS en productie zijn read-only
gecontroleerd en ongewijzigd gezond gebleven. Daarna zijn de exacte tijdelijke
instance, 100-GB-schijf, IPv4, Security Group, Private Network en VPC
verwijderd; AMS 1 toont nul bijbehorende Instances, Flexible IPs en Block
Storage-volumes.

## Actieve componenten

| Onderdeel | Actieve versie of status |
|---|---|
| Ubuntu | 24.04.4 LTS, kernel 6.8.0-137-generic |
| Docker Engine | 29.7.2 |
| containerd | 2.3.3 |
| Docker Compose | 5.4.0 |
| Buildx | 0.36.1 |
| MySQL | exact 9.7.1 |
| MySQL-image | `sha256:873c4256d9805230476bdfa09d9a578e73aaa507a39cc54b46d29fe0797b85fe` |
| MySQL service-identiteit | UID/GID 1999; Caddy UID 999 |
| Shiny | container `shiny_meijendel`, image `sha256:478ed47b333524f8b26df445919e1fc888ed243bc14951b14eb03d772f1ad906` |
| R in Shiny | 4.6.1 |
| Caddy | 2.11.4 |
| PostgreSQL | 16.14, voor de VWG-M-app en ledenrechten |

De actieve MySQL-container is `meijendel-mysql`. De datamap staat
versiegescheiden onder
`/srv/vwgm/meijendel-mysql-971-uid1999/data`. De canonieke
SQL-dump staat in `/srv/vwgm/data/Meijendel.sql`; Shiny en websitepaden wijzen
naar die gecontroleerde bron.

De directe gestopte rollback is
`meijendel-mysql-971-uid999-rollback-20260820` met de vorige 9.7.1-image en
datamap. Daarnaast blijven de gestopte container
`meijendel-mysql-95-rollback-20260813T104315Z`, het
MySQL-9.5-image en `/srv/vwgm/meijendel-mysql/data` bewust beschikbaar
als versiegescheiden rollback. Dit is herstelcapaciteit, geen afval. De
rollback wordt uiterlijk 25 augustus opnieuw beoordeeld volgens `TODO.md`.

Actieve Meijendel-productiecommit:
`21f6b38b67d8742b8d683653b8159c7b12d9fd04`.

## Opslag en containers

Na gecontroleerde opschoning zijn vier verklaarde containers aanwezig:

- actief: `meijendel-mysql`;
- actief: `shiny_meijendel`;
- gestopt en bewust behouden als directe fase-1B-rollback:
  `meijendel-mysql-971-uid999-rollback-20260820`;
- gestopt en bewust behouden: `meijendel-mysql-95-rollback-20260813T104315Z`.

Op 20 augustus zijn na controle van mounts en imageverwijzingen alle
fase-1B-kandidaat-, test- en mislukte container- en imageartefacten plus de
herbouwbare buildcache verwijderd. Docker bevat exact de twee actieve en twee
hierboven verklaarde rollbackcontainers met hun vier canoniek getagde images.
Het rapporteert 0 B ongebruikte image-opslag, 0 B buildcache en geen volumes.
Het rootfilesystem gebruikt 23 van 77 GB (30%). Een volgende Shiny-imagebuild
kan hierdoor langer duren. De lokale fase-8-voorbereiding gebruikt R 4.6.1,
de vaste P3M-snapshot van 18 augustus 2026 en een gesloten restore van exact
190 packages uit `renv.lock`. De multi-stagebuild houdt compilers,
ontwikkelheaders en `linux-libc-dev` buiten de runtime en kan een gevalideerde
CycloneDX-SBOM maken. De actieve productie-image is door deze lokale
voorbereiding niet gewijzigd en bevat 275 OS-pakketten.

## Beveiliging en beheer

- MySQL is niet publiek bereikbaar en `meijendel_read` heeft uitsluitend
  `SELECT` op het Meijendel-schema.
- De actieve MySQL-identiteit UID/GID 1999 is gescheiden van Caddy UID 999;
  de Caddy-checker test actieve en rollbackdatamappen in de live namespace.
- Dashboard, Shiny, SQL en vereiste output lopen via Caddy `forward_auth` naar
  de VWG-M-login.
- UFW laat alleen SSH, HTTP en HTTPS toe.
- Ubuntu Pro is gekoppeld met alleen `esm-apps`; APT heeft 0 open updates en
  er is geen reboot nodig.
- De bare-metalback-up van 20 augustus 21:56 CEST is checksumgeldig, 2.944.952.539
  bytes groot en heeft SHA-256
  `09d82dfa829da5dad47b4654d5a782112c360b479b9391536ba69c2cb6ef182f`.
  Het manifest bevat de actieve MySQL-image met UID/GID 1999 en een volledig
  gevalideerde dump.

## Monitor- en retentieafspraak

De log- en kwetsbaarheidmonitor controleert voortaan ook:

- exacte MySQL-versie en image-ID;
- Trivy-scan van de exacte image-ID's van actieve MySQL en Shiny en alle bewust
  behouden MySQL-rollbackcontainers;
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
Actief zijn Shiny `sha256:478ed47b...` en MySQL 9.7.1/UID-1999
`sha256:873c4256...`, beide met 0 `CRITICAL`/0 `HIGH`. De directe
UID-999-rollback `sha256:7a3fab78...` en de 9.5-rollback
`sha256:d15ac8c7...` hadden op 20 augustus elk 0 `CRITICAL`/8 `HIGH` in
curl/libcurl met beschikbare fix. Zij zijn gestopt en niet publiek bereikbaar;
retentie en eventuele verwijdering worden afzonderlijk beoordeeld.
