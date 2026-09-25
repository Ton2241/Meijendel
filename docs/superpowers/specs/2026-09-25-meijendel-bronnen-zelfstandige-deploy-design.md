# Ontwerp: zelfstandige deploy van Meijendel_bronnen

**Datum:** 25 september 2026  
**Status:** ter goedkeuring  
**Betrokken repositories:** `Meijendel`, `VWG_M`, `VWG_Project`

## Doel

Een wijziging in de Zotero-collectie `Meijendel` of in de contextcatalogus mag
alleen `Meijendel_bronnen` vervangen. De ecologische database `Meijendel`, de
3,7 GB ecologische dump, de Shiny-cache, R-uitvoer en dashboards blijven dan
onaangeroerd.

De nieuwe route behoudt dezelfde productiewaarborgen als de huidige
gecombineerde release: schone actuele `main`, hashes, globale deploy-lock,
back-up vóór import, kandidaatvalidatie, automatische rollback, minimale
databaserechten, smoketest en centrale releaseregistratie.

## Besluit

Er komen twee volledig gescheiden releasepaden:

1. `deploy_meijendel_vps.sh` publiceert uitsluitend de ecologische database,
   cache, Shiny-code en afgeleide uitvoer;
2. `deploy_meijendel_bronnen_vps.sh` publiceert uitsluitend
   `Meijendel_bronnen.sql`.

De bestaande globale VPS-lock blijft gedeeld. Daardoor kunnen een ecologische
release, bronrelease en website-release niet gelijktijdig elkaars database- of
bestandsstatus wijzigen.

## Lokale bronrelease

Het nieuwe script `deploy/deploy_meijendel_bronnen_vps.sh`:

- accepteert standaard alleen preflight en met `--apply --yes` de uitvoering;
- vereist een schone `main` die exact gelijk is aan `origin/main`;
- vereist lokaal en op de VPS exact MySQL 9.7.1;
- controleert dat `meijendel_bronnen.sql` geen absoluut lokaal pad bevat;
- controleert de vereiste tabellen en views;
- herstelt de dump in een tijdelijke lokale database en controleert schema,
  foreign keys, views en kerngetallen;
- maakt een manifest met SHA-256, bestandsgrootte, actieve literatuurregels,
  niet-meer-in-exportregels en actuele regels met trefwoorden;
- voert een rsync-dry-run uit en kopieert bij apply alleen dump en manifest;
- bindt de kandidaat aan zowel de exacte Git-commit als de exacte dumphash;
- controleert vóór en na de wijziging de afgeschermde website-route.

De tijdelijke lokale hersteldatabase krijgt een unieke, begrensde naam en
wordt ook na een fout verwijderd. Het script wijzigt Zotero en de levende
lokale database niet; synchronisatie en dumpgeneratie blijven afzonderlijke,
expliciete stappen.

## Gesloten VPS-gateway

De gateway krijgt een nieuwe toegestane actie:

```text
vwgm-admin meijendel-bronnen-release preflight|apply <commit> <sha256>
```

De roothelper accepteert geen vrije commando's of paden. Kandidaatbestanden,
manifest, commit en hash moeten exact overeenkomen. De actie gebruikt dezelfde
globale deploy-lock als de bestaande releases.

### Preflight

De remote preflight controleert:

- MySQL-container en versie 9.7.1;
- aanwezigheid en schrijfbaarheid van de afzonderlijke back-upmap;
- voldoende ruimte voor kandidaat, back-up en rollbackmarge;
- geldige huidige bronstatus, indien die al bestaat;
- afwezigheid van actieve replicatie voor een import zonder binlog.

### Apply

De apply-fase:

1. valideert kandidaat, manifest, commit en SHA-256;
2. maakt een gecomprimeerde back-up van uitsluitend `Meijendel_bronnen`;
3. controleert dat de back-up niet leeg is en gzip-technisch geldig is;
4. vervangt uitsluitend `Meijendel_bronnen` met `sql_log_bin=0`;
5. trekt eventuele brede rechten in en verleent precies drie `SELECT`-grants
   op `v_bron_catalogus`, `v_literatuur_overzicht` en
   `v_contextdataset_overzicht`;
6. voert `CHECK TABLE EXTENDED`, foreign-key-, view- en kerngetalcontroles uit;
7. activeert de gevalideerde bron-dump en schrijft atomair de productiestatus;
8. zet bij iedere fout na importstart uitsluitend de bronback-up terug en
   controleert ook die herstelstatus.

De helper importeert `Meijendel` niet, valideert geen Shiny-cache en herstart
geen container. De website leest de database per request en heeft voor een
data-only bronrelease geen applicatieherstart nodig.

## Productiestatus en provenance

Naast `/srv/vwgm/deploy-state/Meijendel.commit` komt een afzonderlijke status:

```text
/srv/vwgm/deploy-state/Meijendel_bronnen.release
```

Die bevat exact één commit, dumphash en UTC-tijdstip in een vast formaat. De
releasehelper schrijft dit bestand atomair. `RELEASE_MANIFEST.yml` registreert
bij een bronrelease afzonderlijk:

- Meijendel-repositorycommit;
- SHA-256 van `Meijendel_bronnen.sql`;
- aantallen totaal, actueel, niet meer in export en actueel met trefwoorden;
- back-upstatus, importstatus, rechtencontrole en bron-smoketest.

Een bronrelease verandert de ecologische productiestatus niet. Een ecologische
release verandert de bronstatus niet.

## Aanpassing bestaande ecologische release

Alle verwerking van `Meijendel_bronnen.sql` verdwijnt uit:

- `deploy/deploy_meijendel_vps.sh`;
- `deploy/deploy_meijendel_release_vps_remote.sh`;
- de bijbehorende contracttests en documentatie.

De ecologische release blijft de volledige bestaande controleketen gebruiken:
dumpmanifest, cache, pariteitsanalyse 1958–2025, wintertellingcontrole,
databaseback-up, import, Shiny-herstart, runtimecachecontrole en smoketest.
Zij laat `Meijendel_bronnen` en de afzonderlijke bronback-ups ongemoeid.

## Installatie en beheer

`VWG_Project` installeert de nieuwe roothelper via de bestaande gecontroleerde
gateway-installer. Hashcontrole, kandidaatinstallatie, syntaxcontrole, back-up
van de vorige helper en rollback bij installatiefout worden uitgebreid met de
nieuwe actie.

`VWG_M` breidt uitsluitend de allowlist en argumentvalidatie van
`vwgm_admin_gateway_vps.py` uit. De websitecode en gebruikersinterface hoeven
voor deze infrastructuurwijziging niet te veranderen.

## Tests en acceptatiecriteria

De wijziging is gereed wanneer aantoonbaar geldt:

1. de bron-only contracttest faalt wanneer ecologische dump, cache, R-code,
   dashboarduitvoer of Shiny-herstart in het bronpad voorkomt;
2. de ecologische contracttest faalt wanneer `Meijendel_bronnen` nog in het
   ecologische pad voorkomt;
3. ongeldige commit, hash, manifest, ontbrekende view, lokaal pad, brede grant
   en lege dump blokkeren vóór activatie;
4. een gesimuleerde fout na importstart herstelt uitsluitend
   `Meijendel_bronnen` en meldt `ROLLBACK_STATUS=ready`;
5. de ecologische databasehash en `Meijendel.commit` blijven bij een
   bronrelease ongewijzigd;
6. de bronrelease registreert de juiste hash en kerngetallen in de eigen
   status;
7. de gateway-installer kan de nieuwe helper gecontroleerd installeren en
   terugzetten;
8. alle bestaande Meijendel-, gateway- en VWG_M-tests blijven groen;
9. documentatie beschrijft duidelijk welk script voor welk releasetype geldt.

## Verwachte uitkomst

Bij de productie-export van 25 september 2026 bevatte de broncatalogus 522
auditregels: 518 actuele literatuuritems, vier niet meer in de export en 342
actuele items met een of meer trefwoorden. Een gelijksoortige data-only update
verwerkt voortaan alleen de bron-dump van circa 2,1 MB. De precieze doorlooptijd
wordt tijdens de eerste preflight gemeten; doel is enkele minuten zonder verlies
van back-up- of rollbackzekerheid.

## Buiten deze wijziging

- Automatisch wijzigen van Zotero of de levende lokale database tijdens deploy.
- Een preflightbewijs waarmee zware controles van een volledige ecologische
  release later kunnen worden hergebruikt.
- Een afzonderlijke MySQL-container voor `Meijendel_bronnen`.
- Wijziging van de broncataloguspagina of zoekfunctionaliteit.
- Productie-installatie of productiedeploy zonder afzonderlijke expliciete
  opdracht.
