# MySQL 9.7.4 beveiligingsrebuild — ontwerp

## Doel

Een afzonderlijke, gecontroleerde onderhoudsroute voor een MySQL 9.7.4→9.7.4
image-rebuild. De route bouwt een verse kandidaat uit de gepinde 9.7.4-bron,
bewijst de pakketcorrecties en databasecompatibiliteit, wisselt pas na expliciet
`--apply --yes` en behoudt exact één terugvalimage en -container.

## Grenzen

- De levende lokale Meijendel-database, `meijendel.sql` en de actieve VPS-
  database blijven buiten de lokale voorbereiding en tests.
- De bestaande 9.7.1→9.7.4-route wordt niet hergebruikt of aangepast.
- Zonder `--apply --yes` zijn alleen lokale controles en read-only VPS-
  preflight toegestaan. De route blokkeert wanneer de beheerde VPS-wachtrij
  verplicht is maar deze onderhoudsactie daar niet beschikbaar is.
- Geen Docker-prune, geen datamapmigratie en geen wijziging van
  `Meijendel.commit`.

## Gekozen aanpak

Een nieuwe lokale wrapper en remote helper volgen het bestaande begrensde
image-onderhoudspatroon. De actieve datamount wordt uit de containerinspectie
gebonden in plaats van hard gecodeerd. De kandidaat moet MySQL 9.7.4 en
UID/GID 1999 gebruiken, 0 HIGH/0 CRITICAL scannen en minimaal deze RPM-versies
bevatten:

- `libxml2` 2.9.13-18.el9_9.1;
- `curl` en `libcurl` 7.76.1-44.el9_9.1;
- `krb5-libs` 1.21.1-10.0.1.el9_9.2.

Een logische dump wordt uitsluitend op de VPS in een tijdelijke, afzonderlijke
datamap teruggezet en met de bestaande validator bron 9.7.4/doel 9.7.4
vergeleken. Bij een latere apply volgen automatische rollback, rooktest,
isolatiecontrole en een checksum- en herstelgevalideerde back-up. Finalisatie
verwijdert later uitsluitend de exact aangemaakte rollback, na afzonderlijk
akkoord en een aantoonbaar groene externe back-upketen.

## Niet-doelen

- Geen database-, schema- of gegevenswijziging.
- Geen MySQL-versie-upgrade.
- Geen productie-uitvoering, merge naar `main` of release-publicatie tijdens
  de gelijktijdige databaseoperatie in de andere chat.
