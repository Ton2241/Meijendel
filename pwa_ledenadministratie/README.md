# PWA ledenadministratie

Dependency-vrije PWA voor de VWG-M ledenadministratie. De applicatie gebruikt eigen MySQL-views met `pwa_` prefix en heeft geen Appsmith-runtime of Appsmith-views nodig.

## Onderdelen

- Informatie per lid met detailkaart en CSV-export.
- Beheerfunctie voor geautoriseerde beheerders: lidgegevens, beheerstatus en beheeropmerking wijzigen met auditlog.
- Telhistorie van alle tellers met jaar/zoekfilter en CSV-export.
- Actieve tellers per jaar.
- Datakwaliteit.

## Lokaal testen

1. Draai eenmalig `sql/02_magic_link_auth.sql` en `sql/03_admin_beheer.sql` in database `meijendel`.
2. Draai daarna `sql/01_views_ledenadministratie_pwa.sql`.
3. Maak optioneel `config.php` naast `config.example.php`:

```php
<?php

return [
    'db' => [
        'host' => '127.0.0.1',
        'port' => 3306,
        'database' => 'meijendel',
        'user' => 'meijendel_pwa',
        'password' => '...',
        'charset' => 'utf8mb4',
    ],
    'auth' => [
        'admin_emails' => ['beheerder@example.org'],
    ],
];
```

4. Start lokaal vanuit deze map:

```sh
php -S 127.0.0.1:8080
```

5. Open `http://127.0.0.1:8080/`.

## Deployment op app.vwg-m.nl

Plaats de inhoud van deze map onder de webroot van `app.vwg-m.nl` of onder een subpad. Gebruik HTTPS; zonder HTTPS werkt installatie als PWA niet betrouwbaar.

Aanbevolen productieconfiguratie:

- Zet databasegegevens via omgevingsvariabelen `MEIJENDEL_DB_HOST`, `MEIJENDEL_DB_PORT`, `MEIJENDEL_DB_NAME`, `MEIJENDEL_DB_USER`, `MEIJENDEL_DB_PASSWORD`, of via een niet-gecommitte `config.php`.
- Gebruik voor productie een aparte MySQL-gebruiker met alleen de benodigde rechten op `tellers`, `pwa_%` tabellen en `pwa_%` views; gebruik niet `root`.
- Zet beheerders expliciet via `ADMIN_EMAILS` of `ADMIN_TELLER_IDS`.
- Draai bij deployment eerst `sql/02_magic_link_auth.sql`, `sql/03_admin_beheer.sql` en daarna `sql/01_views_ledenadministratie_pwa.sql` op de productie-MySQL.
- Scherm de PWA af met authenticatie voordat persoonsgegevens publiek bereikbaar zijn.
- Laat `service-worker.js`, `manifest.webmanifest`, `assets/*`, `index.html` en `api/*.php` vanaf hetzelfde domein serveren.
- Controleer dat PHP PDO MySQL actief is.
- Neem bij Nginx de regels uit `.htaccess` over: juiste MIME types, `service-worker.js` niet lang cachen en directe toegang tot `config.php` blokkeren.

## Niet committen

`config.php` bevat lokale of productiecredentials en hoort niet in git.
