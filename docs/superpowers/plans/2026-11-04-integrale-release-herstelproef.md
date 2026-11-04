# Integrale lokale release- en herstelproef

Uitvoering met superpowers:executing-plans, bestaande Meijendel- en VWG_M-bootstrapworktrees. Specificatie: Tons opdracht van 4 november 2026 om drie technische punten af te maken, echte lokale release/herstelroute voor website/dashboard/Shiny te testen, zonder VPS.

## Afrondcriteria en architectuur

Eén versiegebonden pakket bevat dashboarddata/figuren, gedeelde bootstrap, Shiny-code/cache, websitecode/media en verwijzingen naar beide databaserestores. Bronhash, jaargrenzen, selectie, componentstatus en bestanden worden vóór activering gecontroleerd. Activering van alle drie consumenten krijgt één release-ID; een fout herstelt de vorige versie, inclusief database-inhoud. Geen vaste 2025-aanname in de generieke bouw-/koppelroute. Een 2026-fixture bewijst de jaarparameter, maar geldt nooit als echte 2026-levering.

Werk uitsluitend op loopback en nieuwe lokale testpaden/databases. Geen SSH/VPS-opdracht, geen levende analytische databasewijziging, geen mail, geen nieuwe bootstrapfits. Hergebruik alle 2025-uitkomsten. Ruwe testdata/credentials/logs buiten Git in canonieke outputs; credentials privé. MySQL krijgt een eigen datadir/socket. PostgreSQL wordt uitsluitend naar nieuwe databasekopieën hersteld. De oude parser13-cache mag alleen met een expliciet herkenbaar historisch proefprofiel worden gebruikt; nooit als parser15 of officiële2026-cache hernoemen. Normale productievalidatie blijft strikt.

- [x] Bouw generiek: lees jaargrenzen/vensters/run-ID uit gecontroleerde bronmetadata, dynamische soortinventaris en jaarlijkse samenvattingen; test2025/2026 en verkeerdebron/jaargrens.
- [x] Bereid actieve productiekoppeling voor achter expliciete releaseconfiguratie, voor website/dashboard/Shiny. Behoud lokale preview en alle formele-intervalpoorten. Nieuwe publiekspaden blijven nu lokaal gebonden.
- [x] Bouw één controleerbaar releasepakket en lokale activatie/herstelcoördinator. Test manifest/hash/pathguard, ontbrekend bestand, verkeerdejaargrens, herstel bij fout in één dienst en herstart/idempotentie. Gebruik bestaande backup-/validatiepatronen waar beschikbaar.
- [x] Beproef met echte native diensten: volledige bewaarde SQL naar geïsoleerdeMySQL; website-CMS uit bestaande lokale kandidaat naar nieuwePG-kopie; echte Shiny met herkenbaar historischcacheprofiel; dashboard met bewaarde browserdataset. Wissel van vorige500-kandidaat naar nieuwe2000-kandidaat. Controleer geschikte routes, figuren, dezelfdebootstrapbytes, versie/jaarselectie en beschikbareonzekerheidsstatussen.
- [x] Forceer een kandidaatfout en controleer herstel van drieversies én concrete databaseproefwaarden. Controleer fysieke/logischebronintegriteit en hersteldeCMS-/SQL-status; geen externeafhankelijkheid of levende databasewijziging.
- [x] Werk release-/beheerinstructies en actuele stand bij; leg resterende officiële2026-import, verse uitvoer/bootstrap, vrijgave en productie-eindcontrole vast. Onafhankelijke eindreview, gerichte controles, commit/push beidebranches. Geen merge/deploy.

Reviewfocus: geen fake2026-gegevens; geen normaleproductiecacheguard uitschakelen; geen gedeeltelijke3dienstenrelease; geen herstel naar lege/mockdatabase; geen mutatie aan levendeMeijendel; geen credentials in pakket/Git. Platformverschil macOS/Linux en uiteindelijkeVPS-infrastructuur blijven expliciete grenzen van de lokaleproef.

## Uitkomst

De native proef is geslaagd en vastgelegd in `docs/TRIM_INTEGRALE_RELEASE_HERSTELPROEF_20261104.md` en de besloten outputmap. De concrete Linux/gatewaykoppeling en bijbehorende productiecontrole blijven buiten dit native bewijs; die stap hangt niet van nieuwe 2026-tellingen af. De gewone lokale kandidaat blijft de nieuwste 2.000-periodebeoordeling tonen. Tijdelijke diensten worden gestopt; gegevens/back-ups blijven gecontroleerd bewaard.
