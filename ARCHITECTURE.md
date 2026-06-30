# Architectuur

Dit project bestaat uit twee nauw gekoppelde repositories en een VPS-productieomgeving.

## Repositories

- `/Users/ton/Documents/GitHub/Meijendel` bevat `Meijendel.sql`, R-analyses, Shiny, dashboard/HTML-output, GIS-data en analysemiddelen.
- `/Users/ton/Documents/GitHub/VWG_M/website/vwg-m-linux-app` bevat de FastAPI/Jinja-site voor `app.vwg-m.nl` en straks `www.vwg-m.nl`.
- Projectbrede afspraken staan in `/Users/ton/Documents/GitHub/VWG_Project`.
- Wijzigingen worden lokaal gemaakt en na controle standaard gecommit in de betreffende repository met een korte, beschrijvende commitmelding.

## Productie

- VPS: `45.87.43.90`.
- App-pad: `/srv/vwgm/vwg-m-linux-app`.
- Runtime-data: onder meer `/srv/vwgm/www`, uploads, archiefdocumenten, dashboard/grafiekoutput en back-ups.
- Canonieke SQL: `/srv/vwgm/data/Meijendel.sql`.
- Caddy verzorgt TLS, reverse proxy en `forward_auth` naar de ledenlogin.

## Applicaties

- Publieke site: Start, Meijendel, Vogels, Groepen, Tellingen, Nieuws en Werkgroep.
- Ledenomgeving: dashboard, nieuws toevoegen, mediabibliotheek, archief, contentbeheer, administratie, kavelbeheer, systeembeheer, auditlogboek, back-ups en bezoekersstatistiek.
- Dashboard en Shiny blijven onderdeel van dezelfde productieomgeving, maar zijn afgeschermd via Caddy.

## Databases

- Lokale live Meijendel-database op iMac: MySQL 9.5.0.
- Lokale MySQL is bron voor historische/controlerende gegevens zoals `tellers`, `plots` en `plot_jaar_teller`.
- VPS PostgreSQL is operationele bron voor ledenadministratie, CMS, nieuws, archief, kavelbeheer, auditlogging en back-upmetadata.
- `Meijendel.sql` is data-/importbron en back-upformaat, niet bedoeld voor snelle webrequests.

## Grafieken

Alle grafieken op de FastAPI/Jinja-site moeten overeenkomen met het dashboard. Het dashboard is leidend voor brondata, berekening, schaal, labels, legenda, kleuren en onzekerheidsweergave.

Webgrafieken gebruiken vooraf gegenereerde dashboard-output/CSV. Parse `Meijendel.sql` niet per webrequest.

## Toegang

- Toegang tot dashboard, SQL, Shiny en dashboard-output loopt via Caddy `forward_auth` naar de VWG-M ledenlogin.
- Er is geen Appsmith-, PWA- of magic-link-login voor de actuele productie-inrichting.
- Appsmith- en PWA-documentatie is historische context, niet leidend voor productie.

## Back-up

Er is een bare-metal back-uproutine op de VPS. De NAS DS225+ haalt de nieuwste back-up rechtstreeks vanaf de VPS naar de gedeelde map `VWG-M-Backups`.

Runtime-data hoort in back-ups. Secrets, SSH keys en wachtwoorden horen niet plaintext in Git, maar moeten wel herstelbaar zijn via de afgesproken beheer- en herstelprocedure.
