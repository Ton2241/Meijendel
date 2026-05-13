# Appsmith start ledenadministratie

Eerste versie: read-only dashboard op de bestaande MySQL-tabel `tellers`.

## Datasource

Maak in Appsmith een MySQL datasource:

- Host: `host.docker.internal`
- Port: `3306`
- Database: `meijendel`
- Username: `root`
- Password: lokaal MySQL-wachtwoord
- SSL: uit

## Pagina "Leden"

Gebruik deze widgets:

- `inpZoeken`: Input voor naam, tellercode of woonplaats.
- `selSoortLid`: Select, options uit `q_soort_lid_opties.data`.
- `selDatakwaliteit`: Select, options uit `q_datakwaliteit_opties.data`.
- `tblTellers`: Table, data uit `q_tellers.data`.
- Detailvelden of JSON/Form-widget: data uit `q_teller_detail.data[0]`.
- Kleine stat cards: data uit `q_stats.data`.
- Tweede table/tab "Datakwaliteit": data uit `q_datakwaliteit.data`.

## Query's

1. Draai `01_views_ledenbeheer.sql` eenmalig in MySQL.
2. Maak daarna in Appsmith de query's uit `02_appsmith_queries.sql`.
3. Zet `q_tellers`, `q_teller_detail` en `q_stats` op "run on page load".
4. Laat `inpZoeken`, `selSoortLid` en `selDatakwaliteit` na wijziging `q_tellers.run()` uitvoeren.

## Bewuste beperking

Deze start is read-only. Bewerken van ledengegevens komt pas in een volgende stap, met validatie en liefst eerst een backup/export.
