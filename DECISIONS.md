# Besluiten

- Het dashboard is leidend voor alle grafieken. De site mag geen eigen afwijkende grafieklogica of cijfers introduceren.
- Webgrafieken worden gevoed door vooraf gegenereerde dashboard-output/CSV; `Meijendel.sql` wordt niet per request geparsed.
- Dashboard, Shiny, SQL en dashboard-output zijn leden-only via Caddy `forward_auth`.
- Shiny is toegankelijk vanaf niveau 2; gewone leden niveau 1 zien/activeren Shiny niet.
- Autorisatieniveaus: 1 lid, 2 redacteur, 3 bestuurslid, 4 webmaster, 5 systeembeheer.
- Bestuursleden mogen ledenadministratie en kavelbeheer bewerken, maar rollen/rechten wijzigen blijft voor webmaster en systeembeheer.
- Runtime-data zoals uploads, archiefdocumenten en productiebeelden gaan niet in Git; Git bevat code, scripts, documentatie en lege mapstructuur waar nodig.
- Canoniek SQL-bestand op de VPS is `/srv/vwgm/data/Meijendel.sql`; oude SQL-locaties mogen hoogstens symlink zijn.
- `www.vwg-m.nl` wordt na DNS-cutover de hoofdhost; `app.vwg-m.nl` blijft voorlopig werkende alias.
- Algemene publieke zoekfunctie mag geen besloten ledenarchief of andere ledenroutes indexeren of tonen.
- Nieuwe functionaliteit moet waar relevant zichtbaar worden in auditlogging en in `handleiding_beheer.md`.
- Afgeronde wijzigingen worden standaard in Git gecommit met een korte, beschrijvende commitmelding, tenzij expliciet anders gevraagd.
- Als een wijziging voor `app.vwg-m.nl` of de VPS-site wordt gevraagd, is de standaard scope lokaal aanpassen plus deploy naar de VPS en verificatie op productie.
