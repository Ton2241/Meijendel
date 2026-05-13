# Projectinstructies Meijendel

Hou rekening met de volgende IT-infrastructuur:

1. iMac M1 8GB Tahoe 26.4 of later Opstart Macintosh HD
2. Samsung Portable SSD T7 2 terrabyte
3. NAS DS225+ met 6 GB geheugen
4. MySQL 9.5.0

Antwoord in het Nederlands, compact en praktisch.

Werk standaard op de lokale iMac M1 in mijn thuismap/projectmap. Ga ervan uit dat projecten lokaal staan tenzij ik expliciet zeg dat bestanden op de Samsung Portable SSD T7, op de NAS DS225+ of op de VPS staan. Vraag eerst om bevestiging voordat je paden op externe opslag of NAS gebruikt. Gebruik voor de NAS standaard Synology DSM via de browser.

Bij codewerk:
- onderzoek eerst kort de bestaande code en volg de bestaande patronen, naamgeving en structuur
- zoek eerst naar bestaande helpers of utilities voordat je nieuwe toevoegt
- lever standaard een werkende wijziging op in plaats van alleen een plan, tenzij ik expliciet om analyse of brainstorm vraag
- creëer geen nieuwe bestanden in de repo tenzij ik daar expliciet om vraag
- wees voorzichtig met bestaande niet-door-jou-gemaakte wijzigingen en draai die nooit terug zonder expliciete instructie
- benoem aannames, risico's en blockers kort en concreet
- houd wijzigingen zo klein mogelijk, maar wel volledig genoeg om het probleem echt op te lossen
- voeg tests of verificatiestappen toe als dat logisch is; als je iets niet kon verifiëren, zeg dat expliciet

Bij communicatie:
- wees direct, feitelijk en beknopt
- geef bij grotere wijzigingen een korte samenvatting van wat is aangepast en hoe het is gecontroleerd
- stel alleen vragen als dat echt nodig is om veilig verder te kunnen

MySQL:
- gebruik voor lokale database-acties standaard de lokale MySQL-client
- voor inloggen is `-u root -p` nodig

VPS / app.vwg-m.nl:
- Appsmith is niet meer actief op de VPS en is niet relevant voor inloggen of gebruikersbeheer van `app.vwg-m.nl`
- `app.vwg-m.nl` gebruikt de zelfstandige PWA onder `pwa_ledenadministratie/` met containers `leden_pwa_web` en `leden_pwa_mysql`
- magic-link-login is nog niet geactiveerd op productie; voorlopig loopt inloggen op `app.vwg-m.nl` nog via gebruikersnaam en wachtwoord
- behandel `appsmith_ledenadministratie/` als historische/lokale Appsmith-context, niet als actuele productie-inrichting
- bij vragen over gebruikers of inloggen op `app.vwg-m.nl`: kijk eerst naar de actuele gebruikersnaam/wachtwoord-configuratie en PWA/VPS-configuratie, niet naar Appsmith
