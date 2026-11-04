# Integrale Linux-gateway — uitvoeringsplan

> Uitvoering: superpowers:executing-plans; één onafhankelijke eindreview.

Doel: de bestaande releasecoördinator via de bestaande hashgebonden VPS-gateway gebruiken en de daadwerkelijke Linux-route met de bewaarde 1958–2025-uitvoer voor alle 156 soorten beproeven. Tons expliciete opdracht van 4 november is de uitvoeringsautorisatie; geen officiële gegevens-/websitepublicatie.

Architectuur: een vaste gatewayactie met begrensde fasen en exacte commit + pakkethash. Een root-owned Linux-adapter levert database-/servicehandelingen aan de bestaande coördinator. De afgeschermde proef heeft eigen MySQL-container/datadir, PostgreSQL-kopie, website, dashboard, Shiny en Caddy op loopbackpoorten. Zij hergebruikt exacte bestaande images; geen build of nieuwe bootstrapfits. Productieprofiel gebruikt dezelfde handelingen, maar vereist gevalideerde bron, actuele maincommits en een expliciete productie-vrijgavemarker. De huidige proef vervangt geen productiegegevens of publiek proces.

Gekozen route: bestaande gesloten gateway uitbreiden. Een vrij SSH-/rootdeploypad of alleen lokale mocks beantwoordt de opdracht niet. Installatie behoudt de bestaande hashbinding, rollback, sudoersgrenzen en globale productielock. Nieuwe code wordt eerst lokaal getest en gereviewd; benodigde installatie-/sudo-stappen worden gebundeld in het standaard macOS Terminal-venster.

- [x] Meijendel: Linux-adapter, vaste runtime-/pakcontracten, isolatie-/bron-/herstelguards en tests. Reuse coördinator; echte read-only bewaarde invoer. Geen packagecode als root uitvoeren.
- [x] VWG_M/VWG_Project: gatewayparser/dispatch + root-filecontroles; hashgebonden installer met exacte rollback voor nieuwe bestanden; tests voor ongeldige fasen, hash/commit/paden, oude acties, sudoers en installatie.
- [ ] Lokaal testpakket en afgeschermde VPS-proef klaarzetten; alle drie branches commit/push/main-integratie volgens productieprotocol. Na concrete checks één zichtbare sudo-stap voor technische installatie en proef.
- [ ] Linux-proef: bron-/schema-/jaaridentiteit; activering; bewuste fout na echte wijzigingen in beide proefdatabases; volledig automatisch herstel; expliciet terugzetten; echte HTTP-/cache-/bootstrap-/Caddy-authcontroles. Canonieke container-IDs, restarttellingen, Caddy en beide release-statebestanden vóór/na gelijk. Eigen containers/databases/diensten na bewijs gecontroleerd opruimen, bewijs bewaren.
- [ ] Beheer-/releasehandleidingen en integrale kandidaat bijwerken, resterende officiële 2026-poorten vastleggen, onafhankelijke eindreview en eindpreflight/commits/push. Geen diagnostische marge als formele CI vrijgeven.

Reviewfocus: geen user-owned root-code uitvoeren; geen CMS-kopie over productie; productie-eigen SQL-objecten behouden; geen geheime gegevens in argv/log/Git; geen live proces stoppen tijdens proef; veilige incomplete starts/backup-/herstelfouten; hostarchitectuur/cacheversie werkelijk controleren; bewijs niet vervangen door stilstaande containers.
