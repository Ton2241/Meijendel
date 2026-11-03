# Beoordeling van bestaande lange indexsamenvattingen

> Uitvoering: superpowers:executing-plans. Voorafcriteria zijn de specificatie.

Doel: de goedgekeurde kleine vervolgstap, vier soorten, bestaande indices
1958–2025 en dezelfde50trekkingen, zonder TRIM/telmodellen opnieuw te fitten.
Nieuwe bestanden: één analysehelper/CLI en gerichte test voor nulbehandeling,
vensters en indexsamenvatting; CRITERIA/README/compacteCSV/figuren als bewijs.
Gebruik bestaande batchmerge en opgeslagen baseline/indices.

- [x] Criteria afzonderlijk committen voordat de uitkomsten worden berekend.
- [x] RED→GREEN: exact exponentieel, constant, nul einde/begin, ontbrekende
  en dubbele jaren, geheel nulreeks en schaalinvariantie.
- [x] Bestaande50draws en baseline vergelijken; reproduceer oude nulvriendelijke
  uitkomsten en beoordeel vorm/venster/dekking afzonderlijk.
- [x] Resultaten per soort; bronregisterMD/Word en besluiten bijwerken.
- [x] Eén onafhankelijke eindreview inclusief alle Wordpagina's en verificatie.
- [ ] Commit/push volgens projectafspraak en eindpreflight.

Bestaande taakbranch codex/trim-brug-bootstrap is schoon en gelijk aan origin.
Startpreflight stopt op een reeds aanwezige, taakvreemde afwijking van
VWG_Project/main versusorigin/main. Geen wijziging van die branch in deze taak.
GeenDB/2026/cache/500/deploy en geen nieuwe selectie voor alle156soorten.

Uitvoering: criteria58a093ba vóór berekening; REDstub faalt op exponentiële test, daarna GREEN voor alle benoemde randgevallen. Geen nieuwe vogeltelmodelfits. De primaire3/5/7-vensters liggen vast; verschillen worden als inhoudelijk aandachtspunt gemeld, niet als automatische afkeur. Kavelpopulaties blijven onderscheiden.

Uitvoeringskeuze: verschillen tussen de exponentiële samenvatting en vensterverandering zijn diagnostiek, geen gelijke-doelgrootheidstest. Kosten bij verkeerde interpretatie: onterechte methodeafwijzing. De 17/52-vergelijking onderzoekt verschillende kavelpopulaties en kan deze indexmaat niet zelfstandig goed- of afkeuren.

Eindreview schoon: geen Critical/Important/Minor. Alle 612 regels, 544 curvewaarden, 50 draw-identiteiten en 3/5/7-jaarvensters onafhankelijk bevestigd (maximale afwijking 5,0e-12). Alle 60 Wordpagina’s visueel schoon. Voorafcriteria en codehash gecontroleerd; vier hoofd-CSV-hashes ongewijzigd.
