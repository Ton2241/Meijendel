# Uitvoering proef met gezamenlijke kavelinformatie

Spec en onveranderlijke voorafregistratie:
`trim/bootstrap/random_kavel_20261103/CRITERIA.md`.
Gebruikersopdracht: vier soorten, dezelfde 50 trekkingen, bron t/m2025,
criteria vooraf en resultaten/beperkingen achteraf.
Uitvoering: superpowers:executing-plans; codewijzigingen RED→GREEN.

- [x] Criteria afzonderlijk committen vóór eerste proefberekening.
- [x] Bestaande model-, convergentie-, kalibratie- en tekenhelpers hergebruiken;
  aanvullende RE-helper testen op behouden nulplots en onbekende kavelniveaus.
- [x] Baseline en volledige tijdsvalidatie voor kandidaat en referentie uitvoeren.
- [x] Dezelfde50trekkingen uitvoeren; k3/7, brug3/5 en historische17-baseline.
- [x] Criteria A–D mechanisch toepassen; resultaten en beperkingen per soort.
- [x] Onafhankelijke code-/resultaatreview, registerMD/Word, beeldcontrole,
  gerichte regressies, commit/push en eindpreflight.

Geen bestaande hoofdresultaten vervangen, geenDB/2026/500/deploy.

Rulings vóór de berekening: de dekkingsproef toetst de lange én periodehellingen; dit is de conservatieve interpretatie van D. Onbekende kavels worden lognormaal gemarginaliseerd; een nulbijdrage op logschaal is geen marginale gemiddeldeverwachting. De kosten van onjuiste aannamen zijn respectievelijk te strenge afwijzing en vertekende verwachtingen; beide beperkingen zijn in het rapport benoemd.

Uitvoering en controle: baseline plus exact dezelfde 50 opgeslagen trekkingen
voltooid; 204 schattingen, 408 periodecontroles, 80 CV-regels en 16
gevoeligheidsvarianten. Alle geslaagde fits behouden input- en nulcellen.
De vier gerichte R-controles zijn groen. Voorafcriteria en codehash komen
exact overeen met manifest/commit. Onafhankelijke eindreview bevestigt alle
50 draw-identiteiten, checkpoint/CSV-gelijkheid, volledige celdekking en
A–D-uitkomsten. Geen blokkerende of uitgestelde kleine bevindingen.
RegisterMD/Word-paragraaf inhoudelijk gelijk; alle 59 gerenderde Wordpagina's
en vier curvefiguren visueel gecontroleerd zonder defecten. De vier
hoofd-CSV-checksums zijn ongewijzigd. Vastlegging op de bestaande taakbranch;
geen merge of VPS-publicatie.

GitHub-push nog niet uitgevoerd: automatische goedkeuringscontrole wees de bestemmingstoestemming af. De bestaande origin is geverifieerd als https://github.com/Ton2241/Meijendel.git, branch codex/trim-brug-bootstrap. De lokale vastlegging is voltooid; toestemming voor deze push blijft afzonderlijk open. Een CSV is naar LF-regelafbreking genormaliseerd, zonder gegevenswijziging.
