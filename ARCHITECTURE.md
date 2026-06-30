# Architectuur

Dit project bestaat uit twee nauw gekoppelde repositories en een VPS-productieomgeving.

## Repositories

- `/Users/ton/Documents/GitHub/Meijendel` bevat `Meijendel.sql`, R-analyses, Shiny, dashboard/HTML-output, GIS-data en analysemiddelen.
- `/Users/ton/Documents/GitHub/VWG_M/website/vwg-m-linux-app` bevat de FastAPI/Jinja-site voor `app.vwg-m.nl` en straks `www.vwg-m.nl`.
- Wijzigingen worden lokaal gemaakt en na controle standaard gecommit in de betreffende repository met een korte, beschrijvende commitmelding.
- Wijzigingsverzoeken voor `app.vwg-m.nl` of de VPS-site worden zowel lokaal als op de VPS doorgevoerd, met verificatie na deploy.

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

## Nieuws en CMS

Status 2026-06-30:

- Nieuwsitems worden lokaal in de FastAPI/Jinja-site aangepast, gecommit en daarna naar de VPS gedeployed.
- De nieuwseditor ondersteunt afbeeldinguploads vanuit een nieuwsbericht; productiebeelden zijn runtime-data onder `app/static/uploads/cms`.
- De startpagina en `/nieuws/index.asp` sorteren gepubliceerde nieuwsitems op nieuwste bovenaan. Bij gelijke publicatiedatum is de nieuwste database-id leidend.
- `/nieuws/index.asp` toont alleen een korte tekstsamenvatting zonder start-afbeeldingen; de volledige inhoud staat op de detailpagina achter `Lees verder`.
- De editor-/preview-layout is zo aangepast dat invoertekst en preview niet meer over elkaar heen vallen.

Gewijzigde sitebestanden voor deze nieuws/CMS-ronde: `app/static/site.css`, `app/templates/base.html`, `app/queries.py`, `app/templates/home.html`, `app/templates/news_archive.html`, `app/templates/news_index.html`, `app/main.py`, `deploy/README_DEPLOY.md`, `docs/herstelrunbook.md`, `handleiding_beheer.md`, `scripts/backup_baremetal_vps.py`, `deploy/systemd/vwg-m-archive-ocr.service`, `deploy/systemd/vwg-m-archive-ocr.timer` en `scripts/reindex_member_archive_ocr.py`.

Resterende risico's: de ingelogde nieuwsflow is nog niet volledig geautomatiseerd getest; brede deploys moeten CMS-uploads expliciet behouden; archief/OCR-systemd units moeten apart op productie worden geactiveerd en gecontroleerd als die live gebruikt worden.

Aanbevolen volgende stap: voeg aan de smoke-test of een aparte redactiecheck toe dat een redacteur een nieuwsbericht met afbeelding kan maken, publiceren en terugzien op startpagina, nieuwsoverzicht en detailpagina.

## Leden en contentbeheer

Status 2026-06-30:

- Leden met een actuele BMP- of winterkavelkoppeling in `app.teller_assignments` voor het lopende jaar krijgen beperkte toegang tot `Contentbeheer`.
- Beperkte leden zien binnen Contentbeheer alleen de module `Kavels` en daarna alleen de kavelteksten waarvoor zij in het lopende jaar teller zijn.
- Niveau 4 en 5 behouden volledige toegang tot vaste pagina's, soortteksten en alle kavelteksten.
- De ledenpagina `Mijn gegevens en rechten` toont BMP-kavels, winterkavels en PTT-route uit dezelfde actuele jaartoewijzingen als de ledenadministratie, met fallback naar oude app- of legacyvelden.

Gewijzigde sitebestanden voor deze ronde: `app/main.py`, `app/queries.py`, `app/templates/member.html` en `handleiding_beheer.md`.

Resterende risico's: de server-side checks zijn actief en de algemene smoke-test is groen, maar er is nog geen volledige ingelogde browsertest met een gewoon telleraccount voor kaveltekst openen, wijzigen en publiceren. PTT-routeteksten zijn nog niet beschikbaar zolang er geen aparte route-tekstmodule of routepagina's zijn.

Aanbevolen volgende stap: voer een ingelogde test uit met een niveau-1 telleraccount en controleer ledenpagina, Contentbeheer-tegel, kaveltekstlijst, bewerken/publiceren en publieke kavelpagina.

## Databases

- Lokale live Meijendel-database op iMac: MySQL 9.5.0. Deze is bron voor historische/controlerende gegevens zoals `tellers`, `plots` en `plot_jaar_teller`.
- VPS PostgreSQL: operationele bron voor ledenadministratie, CMS, nieuws, archief, kavelbeheer, auditlogging en back-upmetadata.
- `Meijendel.sql` is data-/importbron en back-upformaat, niet bedoeld voor snelle webrequests.

## Grafieken

Alle grafieken op de FastAPI/Jinja-site moeten exact overeenkomen met het dashboard. Het dashboard is leidend voor brondata, berekening, schaal, labels, legenda, kleuren en onzekerheidsweergave. Webgrafieken gebruiken vooraf gegenereerde dashboard-output/CSV, niet on-the-fly parsing van `Meijendel.sql`.

## Back-up

Er is een bare-metal back-uproutine op de VPS. De NAS DS225+ haalt de nieuwste back-up rechtstreeks vanaf de VPS naar de gedeelde map `VWG-M-Backups`. Runtime-data hoort in back-ups; secrets, SSH keys en wachtwoorden niet plaintext in Git, maar wel in het herstelrunbook.
