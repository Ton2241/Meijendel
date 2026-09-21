# Lokale Shiny-cache en begrensde gatewayuitvoer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Iedere volgende Meijendel-databaseverversing bouwt automatisch lokaal een hashgebonden Shiny-cache, weigert zware cachebouw op productie en haalt begrensde gatewayuitvoer pas na procesbeëindiging op.

**Architecture:** De lokale export levert één gevalideerde set van dump, dumpmanifest, inhoudsgebonden RDS-cache en cachemanifest. De deploy valideert en transporteert deze set naar kandidaatpaden; de exacte Shiny-image bewijst vóór database-import dat de cache direct leesbaar is. Een afzonderlijke lokale gatewayrunner laat de remote gateway naar beveiligde VPS-bestanden schrijven, bewaakt een ruime harde timeout en haalt log plus eindstatus daarna via een tweede SSH-aanroep op.

**Tech Stack:** Bash 3.2 op macOS, R 4.6.1 in productie, base R/RDS, MySQL 9.7.1, Docker Compose op Ubuntu 24.04, SSH/rsync, GNU `timeout`, bestaande `vwgm-admin`-gateway.

**Spec:** `docs/superpowers/specs/2026-09-21-lokale-shiny-cache-en-gatewayuitvoer-design.md`

## Global Constraints

- De levende lokale MySQL-database `Meijendel` op de iMac blijft de canonieke schrijfbron; dump, cache, productie-MySQL, Shiny, dashboard en website zijn afgeleiden.
- Geen nieuwe R-, Python- of systeempakketafhankelijkheid toevoegen.
- Productie mag met `MEIJENDEL_REQUIRE_PREBUILT_CACHE=1` nooit terugvallen op volledige SQL-parse.
- Cache-identiteit gebruikt volledige `sql_sha256`, `sql_bytes`, cachecontractversie en `MEIJENDEL_PARSER_CACHE_VERSION`; het absolute SQL-pad telt niet mee.
- Gatewaypreflight krijgt standaard 300 seconden; release-apply 10.800 seconden; na TERM blijft maximaal 3.600 seconden voor rollback vóór KILL.
- Cachebouw, imagebuild, database-import en zware controles worden niet parallel uitgevoerd.
- NAS en Samsung T7 worden niet gebruikt; cachebouw gebeurt lokaal op de iMac.
- Bestaande back-up-, rollback-, commit-ancestry-, globale lock-, parity- en rooktests blijven verplicht.
- Sudo- of wachtwoordinvoer gebeurt uitsluitend door Ton in een zichtbaar standaard macOS Terminal-venster.
- Productie wordt uitsluitend vanaf schone, actuele `main` gedeployed en pas na groene verificatie in `VWG_Project/RELEASE_MANIFEST.yml` geregistreerd.

## Review Focus

- Een geldig cachebestand met een manifest van een andere SQL-dump moet vóór parseraanroep worden geweigerd; Task 1 test SQL-hash en omvang afzonderlijk.
- Een bestaande lokale cache mag alleen worden hergebruikt als RDS, cachemanifest, parser-versie en beide hashes nog kloppen; Task 2 test corruptie en ongewijzigde herbouw.
- Een remote gateway die een achtergrondproces met geërfde stdout start, mag de eerste SSH-aanroep niet openhouden; Task 5 simuleert dit expliciet.
- Een timeout tijdens import moet TERM naar de gateway sturen en de bestaande rollbacktrap voldoende tijd geven; Task 5 en Task 6 testen status `timeout` en rollbackbewijs.
- Een verbroken SSH-verbinding na remote voltooiing mag het log niet verliezen of een release als geslaagd registreren; Task 5 test gerichte hervatting met dezelfde operatie-id.

---

## Bestandsstructuur

Nieuwe bestanden:

- `R/meijendel_cache_contract.R` — pure manifest-, identiteit- en cachevalidatie zonder SQL-parse.
- `R/test_meijendel_cache_contract.R` — kleine, volledig lokale R-fixtures voor het cachecontract.
- `scripts/build_meijendel_shiny_cache.R` — bouwt één RDS-kandidaat met de bestaande parser en schrijft cachemetadata.
- `scripts/test_build_meijendel_shiny_cache.sh` — end-to-end fixturetest van builder, hergebruik en atomische foutafhandeling.
- `deploy/run_gateway_job_vps.sh` — enige lokale ingang voor bestandgebonden, begrensde gatewayaanroepen.
- `deploy/test_gateway_job_runner.sh` — nagebootste SSH-tests voor succes, fout, timeout, geërfde stdout en hervatting.

Te wijzigen bestanden:

- `shiny_meijendel/helpers.R` — gebruikt het gedeelde cachecontract en kent lokale versus cache-verplichte modus.
- `scripts/export_meijendel_sql.sh` — publiceert dump, dumpmanifest, cache en cachemanifest als gekoppelde set.
- `scripts/validate_meijendel_export.sh` — valideert cacheverwijzingen in het dumpmanifest wanneer cachecontrole is gevraagd.
- `scripts/test_export_meijendel_sql.sh` en `scripts/test_meijendel_export_contract.sh` — borgen vierdelige export en veilige basenames.
- `.gitignore` — sluit inhoudsgebonden RDS-cache en cachemanifest uit.
- `deploy/deploy_meijendel_vps.sh` — vereist, valideert, reserveert ruimte voor en transporteert de cache; gebruikt uitsluitend de gatewayrunner.
- `deploy/deploy_meijendel_release_vps_remote.sh` — valideert kandidaatcache vóór import, zet productie in verplichte modus en herstelt cachekoppeling bij rollback.
- `deploy/test_meijendel_gateway_contract.sh` — breidt statische veiligheids- en timeoutcontroles uit.
- `deploy/update_en_deploy_meijendel.sh` — rapporteert de automatisch gebouwde cache en controleert haar vóór verdere generatie.
- `README.md`, `ARCHITECTURE.md`, `deploy/README_DEPLOY.md`, `docs/vps_productie.md`, `TODO.md` — documenteren de definitieve standaardketen.
- `VWG_Project/RELEASE_MANIFEST.yml` — uitsluitend na geslaagde productie-uitrol.

### Task 1: Padonafhankelijk cachecontract en verplichte productiemodus

**Files:**
- Create: `R/meijendel_cache_contract.R`
- Create: `R/test_meijendel_cache_contract.R`
- Modify: `shiny_meijendel/helpers.R:1-25,634-830,5663`

**Interfaces:**
- Consumes: key-valuevelden `sql_sha256`, `sql_bytes`, `cache_file`, `cache_manifest` uit het dumpmanifest.
- Produces: `read_meijendel_manifest(path) -> named character`; `meijendel_cache_identity(sql_sha256, sql_bytes, parser_version) -> named list`; `validate_meijendel_cache(cache, expected_identity) -> TRUE`; `load_meijendel_tables_cached(path, cache_path = NULL, sql_manifest_path = NULL, cache_manifest_path = NULL, require_prebuilt = NULL) -> list(data, from_cache, cache_path)`.

- [ ] **Step 1: Schrijf falende contracttests**

Maak kleine RDS-fixtures zonder echte SQL-parse. Test minimaal:

```r
source(file.path(repo, "R", "meijendel_cache_contract.R"))

identity <- meijendel_cache_identity(strrep("a", 64), 123L, 9L)
cache <- list(format = "meijendel-shiny-cache-v1", identity = identity, data = list(plots = data.frame()))
stopifnot(validate_meijendel_cache(cache, identity))
stopifnot(identical(identity, meijendel_cache_identity(strrep("a", 64), 123L, 9L)))

wrong_hash <- meijendel_cache_identity(strrep("b", 64), 123L, 9L)
stopifnot(inherits(try(validate_meijendel_cache(cache, wrong_hash), silent = TRUE), "try-error"))

wrong_size <- meijendel_cache_identity(strrep("a", 64), 124L, 9L)
stopifnot(inherits(try(validate_meijendel_cache(cache, wrong_size), silent = TRUE), "try-error"))

wrong_parser <- meijendel_cache_identity(strrep("a", 64), 123L, 10L)
stopifnot(inherits(try(validate_meijendel_cache(cache, wrong_parser), silent = TRUE), "try-error"))
```

Voeg in dezelfde test een tijdelijke SQL-file op twee absolute paden toe en
bewijs dat dezelfde manifestidentiteit voor beide paden geldig is.

- [ ] **Step 2: Voer de test uit en bevestig de bedoelde fout**

Run:

```bash
Rscript R/test_meijendel_cache_contract.R
```

Expected: FAIL omdat `R/meijendel_cache_contract.R` en de functies nog ontbreken.

- [ ] **Step 3: Implementeer het minimale pure cachecontract**

Gebruik base R. Accepteer alleen `key=value`-regels met unieke sleutels, exacte
64-tekens lowercase SHA-256, positieve gehele omvang en een positieve
parser-versie. Laat `validate_meijendel_cache()` stoppen met een gerichte
melding per veld. Definieer:

```r
MEIJENDEL_CACHE_FORMAT <- "meijendel-shiny-cache-v1"

meijendel_cache_identity <- function(sql_sha256, sql_bytes, parser_version) {
  list(
    format = MEIJENDEL_CACHE_FORMAT,
    sql_sha256 = validate_sha256(sql_sha256, "sql_sha256"),
    sql_bytes = validate_positive_integer(sql_bytes, "sql_bytes"),
    parser_version = validate_positive_integer(parser_version, "parser_version")
  )
}
```

Implementeer daarbij in hetzelfde bestand de private helpers
`validate_sha256(value, field) -> character(1)` en
`validate_positive_integer(value, field) -> character(1)`. Zij worden niet
buiten het cachecontract aangeroepen.

Verplaats `MEIJENDEL_PARSER_CACHE_VERSION <- 9L` naar vóór de eerste
cachefunctie en source het contract bovenaan `helpers.R` naast de bestaande
gedeelde helpers.

- [ ] **Step 4: Maak `load_meijendel_tables_cached()` fail-closed in productie**

Laat `require_prebuilt` standaard volgen uit:

```r
identical(Sys.getenv("MEIJENDEL_REQUIRE_PREBUILT_CACHE", unset = "0"), "1")
```

Bij geldige cache: zet na validatie altijd `cache$data$sql_path <- path`. Bij
ongeldige of ontbrekende cache en `require_prebuilt=TRUE`: stop met
`"Vooraf gebouwde Meijendel-cache ontbreekt of past niet"` vóór
`parse_meijendel_tables(path)`. In lokale modus blijft de bestaande parse- en
saveRDS-route werken, maar schrijf eerst naar `<cache>.next.<pid>` en hernoem
pas na succesvolle `readRDS()`.

- [ ] **Step 5: Voer contracttest en bestaande parity-ingang uit**

Run:

```bash
Rscript R/test_meijendel_cache_contract.R
Rscript -e 'source("shiny_meijendel/helpers.R"); stopifnot(MEIJENDEL_PARSER_CACHE_VERSION == 9L)'
```

Expected: beide PASS; de tweede opdracht laadt helpers zonder runtimefout.

- [ ] **Step 6: Commit**

```bash
git add R/meijendel_cache_contract.R R/test_meijendel_cache_contract.R shiny_meijendel/helpers.R
git commit -m "Borg padonafhankelijk Shiny-cachecontract"
```

### Task 2: Automatische lokale cachebouw als onderdeel van export

**Files:**
- Create: `scripts/build_meijendel_shiny_cache.R`
- Create: `scripts/test_build_meijendel_shiny_cache.sh`
- Modify: `scripts/export_meijendel_sql.sh:1-95`
- Modify: `scripts/test_export_meijendel_sql.sh:1-85`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: gevalideerde tijdelijke dump en tijdelijk dumpmanifest.
- Produces: `meijendel_tables_cache-p<PARSER>-<SQL_SHA256>.rds` plus gelijknamig `.manifest`; voegt `cache_file` en `cache_manifest` aan het dumpmanifest toe.

- [ ] **Step 1: Schrijf een falende buildertest met kleine helperstub**

Laat de shelltest een tijdelijke stub-`helpers.R` leveren waarvan
`parse_meijendel_tables()` één kleine data.frame retourneert. Controleer:

```bash
"$BUILDER" "$dump" "$dump_manifest" "$out_dir" "$stub_helpers"
cache_file="$(awk -F= '$1 == "cache_file" {print $2}' "$dump_manifest")"
cache_manifest="$(awk -F= '$1 == "cache_manifest" {print $2}' "$dump_manifest")"
[[ "$cache_file" =~ ^meijendel_tables_cache-p[0-9]+-[0-9a-f]{64}\.rds$ ]]
[[ -s "$out_dir/$cache_file" && -s "$out_dir/$cache_manifest" ]]
```

Corrupt daarna de RDS, herhaal dezelfde hash en eis dat de builder niet meldt
`CACHE_REUSED=TRUE`. Laat de stub vervolgens falen en bewijs dat bestaande
dump, manifest en cachebytes ongewijzigd blijven.

- [ ] **Step 2: Voer de test uit en bevestig dat de builder ontbreekt**

Run:

```bash
bash scripts/test_build_meijendel_shiny_cache.sh
```

Expected: FAIL met ontbrekende builder.

- [ ] **Step 3: Implementeer de R-builder**

Laat `build_meijendel_shiny_cache.R` exact vier argumenten accepteren: dump,
dumpmanifest, kandidaat-RDS en helperspad. Source helpers, lees identiteit uit
het manifest, voer `parse_meijendel_tables(dump)` één keer uit en schrijf:

```r
cache <- list(
  format = MEIJENDEL_CACHE_FORMAT,
  identity = meijendel_cache_identity(sql_sha256, sql_bytes, MEIJENDEL_PARSER_CACHE_VERSION),
  created_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
  source_commit = Sys.getenv("MEIJENDEL_SOURCE_COMMIT", unset = "uncommitted"),
  r_version = as.character(getRversion()),
  serialization_version = 3L,
  data = data
)
saveRDS(cache, candidate_path, version = 3)
validate_meijendel_cache(readRDS(candidate_path), cache$identity)
```

- [ ] **Step 4: Breid het exportscript atomisch uit**

Bereken `sql_sha256` en parser-versie na dumpvalidatie. Gebruik tijdelijke
cachepaden met PID. Hergebruik alleen als bestaande RDS én cachemanifest volledig
valideren. Schrijf het cachemanifest met minimaal:

```text
format=meijendel-shiny-cache-manifest-v1
sql_sha256=<64 hex>
sql_bytes=<positief geheel getal>
parser_version=9
cache_sha256=<64 hex>
cache_bytes=<positief geheel getal>
r_version=<versie>
serialization_version=3
created_at=<ISO-8601>
source_commit=<40 lowercase hex of uncommitted>
```

Voeg daarna veilige basenames `cache_file=` en `cache_manifest=` toe aan het
dumpmanifest. Publiceer eerst de inhoudsgebonden cache, daarna cachemanifest,
dump en als laatste dumpmanifest; het laatste bestand is de zichtbare
commitmarker van de lokale artefactset. Breid `cleanup()` uit voor alle
kandidaatbestanden.

- [ ] **Step 5: Breid de bestaande exporttest uit naar vier artefacten**

Injecteer `MEIJENDEL_CACHE_BUILDER` als mockbare helper. Test dat falende
cachebouw de twee bestaande artefacten niet vervangt en geen half cachebestand
achterlaat. Test bij succes `cache_file`, `cache_manifest`, veilige basename en
bestaan van beide bestanden.

- [ ] **Step 6: Negeer uitsluitend gegenereerde cacheartefacten**

Voeg toe:

```gitignore
meijendel_tables_cache-p*.rds
meijendel_tables_cache-p*.manifest
```

- [ ] **Step 7: Voer alle exporttests uit**

Run:

```bash
bash scripts/test_build_meijendel_shiny_cache.sh
bash scripts/test_export_meijendel_sql.sh
bash scripts/test_meijendel_export_contract.sh
```

Expected: drie PASS-regels, nul achtergebleven `.next.*`-bestanden.

- [ ] **Step 8: Commit**

```bash
git add .gitignore scripts/build_meijendel_shiny_cache.R scripts/test_build_meijendel_shiny_cache.sh scripts/export_meijendel_sql.sh scripts/test_export_meijendel_sql.sh
git commit -m "Bouw Shiny-cache automatisch bij database-export"
```

### Task 3: Vierdelige artefactvalidatie en veilige basenames

**Files:**
- Modify: `scripts/validate_meijendel_export.sh`
- Modify: `scripts/test_meijendel_export_contract.sh`
- Modify: `deploy/update_en_deploy_meijendel.sh`

**Interfaces:**
- Consumes: dumpmanifest met `cache_file` en `cache_manifest`.
- Produces: `validate_meijendel_export.sh --with-cache DUMP DUMP_MANIFEST CACHE_DIR`; uitvoer `CACHE_STATUS=ready` bij volledige overeenkomst.

- [ ] **Step 1: Voeg falende cachemanifesttests toe**

Maak geldige kleine dump/cachefixtures en test daarna afzonderlijk:

```bash
expect_fail "cachebestand bevat pad" cache_file=../escape.rds
expect_fail "cachebestand is symlink" "$cache_path"
expect_fail "cachehash wijkt af" cache_sha256="$(printf 'b%.0s' {1..64})"
expect_fail "SQL-hash in cachemanifest wijkt af" sql_sha256="$(printf 'c%.0s' {1..64})"
expect_fail "parser-versie wijkt af" parser_version=10
```

Gebruik geen brace-expansie in productiescripts; die staat alleen in de test.

- [ ] **Step 2: Bevestig dat `--with-cache` nog niet bestaat**

Run:

```bash
bash scripts/test_meijendel_export_contract.sh
```

Expected: FAIL op onbekende optie of ontbrekende cachevelden.

- [ ] **Step 3: Implementeer cachevalidatie in de bestaande validator**

Eis exacte unieke manifestvelden, reguliere bestandsnamen, gewone bestanden
zonder symlink, SHA-256 en grootte. Vergelijk `sql_sha256` en `sql_bytes` in
beide manifesten en haal de vereiste parser-versie uit:

```bash
Rscript -e 'source("shiny_meijendel/helpers.R"); cat(MEIJENDEL_PARSER_CACHE_VERSION)'
```

Laat bestaande `--artifact-only` semantiek intact voor tests die bewust alleen
dumpintegriteit controleren; gebruik `--with-cache` in export en deploy.

- [ ] **Step 4: Laat de generatie-ingang de cache expliciet controleren**

Roep direct na `export_meijendel_sql.sh` aan:

```bash
"$REPO_DIR/scripts/validate_meijendel_export.sh" --with-cache \
  "$SQL_FILE" "$SQL_MANIFEST" "$REPO_DIR"
```

Log de cachebasename en `CACHE_STATUS=ready` voordat analyses starten.

- [ ] **Step 5: Voer export- en contracttests uit**

Run:

```bash
bash scripts/test_meijendel_export_contract.sh
bash scripts/test_export_meijendel_sql.sh
bash scripts/test_build_meijendel_shiny_cache.sh
bash -n scripts/validate_meijendel_export.sh deploy/update_en_deploy_meijendel.sh
```

Expected: alle tests PASS en shellsyntax groen.

- [ ] **Step 6: Commit**

```bash
git add scripts/validate_meijendel_export.sh scripts/test_meijendel_export_contract.sh deploy/update_en_deploy_meijendel.sh
git commit -m "Valideer dump en Shiny-cache als release-eenheid"
```

### Task 4: Cachekandidaat transporteren en vóór import bewijzen

**Files:**
- Modify: `deploy/deploy_meijendel_vps.sh:1-370`
- Modify: `deploy/deploy_meijendel_release_vps_remote.sh:1-170`
- Modify: `deploy/test_meijendel_gateway_contract.sh`

**Interfaces:**
- Consumes: gevalideerde lokale vierdelige artefactset.
- Produces: commitgebonden remote kandidaatpaden, actieve dump plus manifest,
  productiecache in `app_cache`, kandidaatstatus
  `CACHE_CANDIDATE_STATUS=ready`, runtime-uitvoer `SQL_CACHE=TRUE`.

- [ ] **Step 1: Breid de gatewaycontracttest eerst uit**

Eis in het lokale script de fragmenten:

```text
validate_meijendel_export.sh" --with-cache
CACHE_CANDIDATE_FILE=
CACHE_MANIFEST_CANDIDATE_FILE=
CACHE_CANDIDATE_STATUS=ready
MEIJENDEL_REQUIRE_PREBUILT_CACHE=1
SQL_CACHE=TRUE
```

Eis dat de remote helper de kandidaatcache vóór `DATABASE_BACKUP=` en vóór de
MySQL-import valideert. Verbied `parse_meijendel_tables` in de remote helper.

- [ ] **Step 2: Voer de contracttest uit en bevestig de fout**

Run:

```bash
bash deploy/test_meijendel_gateway_contract.sh
```

Expected: FAIL op het eerste ontbrekende cachefragment.

- [ ] **Step 3: Voeg cachevelden en capaciteitsberekening aan lokale deploy toe**

Lees de veilige basenames uit het dumpmanifest, valideer met `--with-cache` en
tel cachebytes plus een extra cachekopie mee in `REQUIRED_FREE_KB`. Voeg cache
en cachemanifest zichtbaar toe aan release-/afhankelijkheidsmanifest en
rsync-dry-run. Upload dump, dumpmanifest, cache en cachemanifest naar
commitgebonden kandidaatpaden. `sync_release()` mag de actieve
`/srv/vwgm/data/Meijendel.sql` en het actieve manifest vóór de gatewayactie niet
meer vervangen; de remote helper importeert rechtstreeks uit de kandidaatdump.

- [ ] **Step 4: Maak de remote kandidaatcontrole fail-closed**

Laat de remote helper vóór databaseback-up:

1. dump- en cachehash met `sha256sum` controleren;
2. alle vier bestanden als gewone bestanden controleren;
3. een eenmalige container met read-only mounts starten;
4. `MEIJENDEL_REQUIRE_PREBUILT_CACHE=1` zetten;
5. `load_meijendel_tables_cached()` laten eindigen met `from_cache=TRUE`;
6. `CACHE_CANDIDATE_STATUS=ready` schrijven.

De container krijgt dezelfde image `vwgm-shiny:latest`, geen netwerk, een
read-only rootfilesystem waar mogelijk, en alleen de kandidaatdump,
manifesten, R-code en kandidaatcache gemount.

- [ ] **Step 5: Activeer inhoudsgebonden cache en productie-env vóór Shiny-start**

Importeer de kandidaatdump pas na `CACHE_CANDIDATE_STATUS=ready`. Bewaar daarna
de vorige actieve dump en het vorige dumpmanifest onder commitgebonden
rollbacknamen en promoveer de nieuwe dump en het nieuwe manifest met `mv` naar
de canonieke paden. Verplaats vervolgens de cache naar
`$REMOTE_SHINY/shiny_meijendel/app_cache/<cache_file>`, behoud de vorige cache,
en zorg idempotent dat Compose bevat:

```yaml
environment:
  MEIJENDEL_REQUIRE_PREBUILT_CACHE: "1"
  MEIJENDEL_SQL_MANIFEST_PATH: /srv/shiny-server/Meijendel.sql.manifest
  MEIJENDEL_CACHE_MANIFEST_PATH: /srv/shiny-server/shiny_meijendel/app_cache/meijendel_tables_cache.active.manifest
```

Kopieer het inhoudsgebonden cachemanifest atomisch naar de vaste actieve
manifestnaam; dit bestand wijst naar de inhoudsgebonden RDS. Mount het
dumpmanifest read-only naast `Meijendel.sql`. Start Shiny pas daarna. De
runtimecheck moet exact `SQL_CACHE=TRUE` melden; `FALSE` is een releasefout.

- [ ] **Step 6: Maak cachekoppeling rollbackbaar**

Bewaar vóór activering de vorige actieve dump, het dumpmanifest, het vaste
cachemanifest en de cachebasename in gewone variabelen. Bij `finish()` na
begonnen import: herstel database én de drie vorige actieve bestanden, herstart
Shiny in verplichte modus en eis opnieuw `SQL_CACHE=TRUE`. Laat
kandidaatresten staan als bewijs alleen bij mislukte rollback; ruim ze anders
exact op. Verwijder na volledig groene release alleen reguliere cachebestanden
die noch bij de actieve, noch bij de direct voorafgaande release horen; volg
geen symlinks en raak `sass/` of andere app-cachebestanden niet aan.

- [ ] **Step 7: Voer contract- en syntaxtests uit**

Run:

```bash
bash deploy/test_meijendel_gateway_contract.sh
bash deploy/test_trim_release_contract.sh
bash -n deploy/deploy_meijendel_vps.sh deploy/deploy_meijendel_release_vps_remote.sh
```

Expected: alle tests PASS; geen directe Docker-aanroep in het lokale deployscript.

- [ ] **Step 8: Commit**

```bash
git add deploy/deploy_meijendel_vps.sh deploy/deploy_meijendel_release_vps_remote.sh deploy/test_meijendel_gateway_contract.sh
git commit -m "Activeer uitsluitend vooraf gebouwde Shiny-cache"
```

### Task 5: Gatewayuitvoer via afgesloten VPS-bestanden

**Files:**
- Create: `deploy/run_gateway_job_vps.sh`
- Create: `deploy/test_gateway_job_runner.sh`
- Modify: `deploy/deploy_meijendel_vps.sh:35-140,345-365`
- Modify: `deploy/test_meijendel_gateway_contract.sh`

**Interfaces:**
- Consumes: `run_gateway_job_vps.sh preflight|apply COMMIT`, plus `VPS`, `SSH_KEY`, `GATEWAY`, optionele begrensde timeoutvariabelen en optionele `GATEWAY_OPERATION_ID` voor hervatting.
- Produces: volledige gatewaylog op stdout na voltooiing; exitcode van gateway/timeout; laatste regel `GATEWAY_JOB_STATUS=ready|failed|timeout`; operatie-id op stderr bij netwerkonderbreking.

- [ ] **Step 1: Schrijf mock-SSH-tests voor de runner**

De mock bewaart remote bestanden in een tijdelijke map. Test vijf scenario's:

```bash
assert_status success 0 'GATEWAY_JOB_STATUS=ready'
assert_status failure 23 'GATEWAY_JOB_STATUS=failed'
assert_status timeout 124 'GATEWAY_JOB_STATUS=timeout'
assert_inherited_stdout_returns_before_child_exit
assert_resume_fetches_existing_completed_operation
```

Controleer ook dat de eerste SSH-opdracht de gatewayuitvoer naar het remote
logbestand omleidt en dat pas een tweede SSH-opdracht `cat` uitvoert.

- [ ] **Step 2: Voer de runner-test uit en bevestig dat het script ontbreekt**

Run:

```bash
bash deploy/test_gateway_job_runner.sh
```

Expected: FAIL met ontbrekende runner.

- [ ] **Step 3: Implementeer argument- en timeoutvalidatie**

Accepteer alleen fasen `preflight` en `apply` en exact 40 lowercase hex voor de
commit. Valideer gehele grenzen:

```bash
preflight: 60..900, default 300
apply: 1800..14400, default 10800
kill_after: 600..7200, default 3600
```

Maak standaard een operatie-id uit 16 bytes `/dev/urandom`, hex-gecodeerd; bij
hervatting accepteer alleen 32 lowercase hex.

- [ ] **Step 4: Implementeer de remote bestandgebonden uitvoering**

De eerste SSH-aanroep maakt met `umask 077` een operatiemap onder
`/srv/vwgm/deploy-state/gateway-jobs/<id>`, weigert bestaande symlinks en voert
in een subshell uit:

```bash
timeout --foreground --signal=TERM --kill-after="${kill_after}s" "${limit}s" \
  sudo -n /usr/local/sbin/vwgm-admin meijendel-release "$stage" "$commit" \
  >"$log.next" 2>&1
rc=$?
mv "$log.next" "$log"
printf 'operation_id=%s\nexit_code=%s\nfinished_at=%s\n' \
  "$operation_id" "$rc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$status.next"
mv "$status.next" "$status"
```

Zorg met een remote trap dat ook gewone fouten een statusbestand opleveren.
De SSH-stdout bevat alleen `GATEWAY_REMOTE_COMPLETED=<id>`.

- [ ] **Step 5: Haal status en log afzonderlijk op**

Lees in een tweede SSH-aanroep eerst het statusbestand zonder symlinks te
volgen, vergelijk operatie-id, toon daarna het log. Verwijder exact die
operatiemap pas na succesvolle lokale ontvangst. Bij netwerkfout: behoud map,
toon id en geef niet-nul terug. Bij exitcode 124/137: rapporteer timeout en eis
in de log `ROLLBACK|` plus een geslaagde herstelstatus zodra import was gestart.

- [ ] **Step 6: Vervang beide directe gatewayaanroepen**

Gebruik in `deploy_meijendel_vps.sh` uitsluitend:

```bash
gateway_preflight="$($GATEWAY_RUNNER preflight "$LOCAL_COMMIT")"
gateway_apply="$($GATEWAY_RUNNER apply "$LOCAL_COMMIT")"
```

Behoud alle bestaande inhoudscontroles op `MYSQL_VERSION`,
`PREFLIGHT_STATUS`, `DATABASE_BACKUP`, `SHINY_STATUS` en `RELEASE_STATUS`.

- [ ] **Step 7: Voer runner-, contract- en shelltests uit**

Run:

```bash
bash deploy/test_gateway_job_runner.sh
bash deploy/test_meijendel_gateway_contract.sh
bash -n deploy/run_gateway_job_vps.sh deploy/deploy_meijendel_vps.sh
```

Expected: alle tests PASS; de geërfde-stdoutfixture keert terug vóór haar
achtergrondkind eindigt.

- [ ] **Step 8: Commit**

```bash
git add deploy/run_gateway_job_vps.sh deploy/test_gateway_job_runner.sh deploy/deploy_meijendel_vps.sh deploy/test_meijendel_gateway_contract.sh
git commit -m "Begrens en sluit gatewayuitvoer af"
```

### Task 6: Integrale rollback-, lock- en regressiecontrole

**Files:**
- Modify: `deploy/test_meijendel_gateway_contract.sh`
- Modify: `scripts/test_workspace_guard.sh`
- Modify: `scripts/test_container_image_definitions.sh` indien de nieuwe read-only kandidaatcontainer extra statische controle vereist.

**Interfaces:**
- Consumes: interfaces uit Tasks 1-5.
- Produces: één lokaal uitvoerbare regressieset die cachemisser, timeout, rollback, lockvrijgave en statusregistratie blokkeert.

- [ ] **Step 1: Voeg een falende volgorde- en rollbackfixture toe**

Gebruik gemockte `ssh`, `rsync` en gatewayrunner. Leg een gebeurtenislog vast en
eis deze partiële volgorde:

```text
validate-cache
stage-candidate
candidate-cache-ready
database-backup
database-import
shiny-cache-true
production-smoke
write-state
release-lock-removed
```

Laat een tweede scenario op `database-import` falen en eis:

```text
rollback-started
rollback-database-ready
rollback-cache-true
release-lock-removed
```

`write-state` mag daarin niet voorkomen.

- [ ] **Step 2: Voer de uitgebreide test uit en bevestig de eerste fout**

Run:

```bash
bash deploy/test_meijendel_gateway_contract.sh
bash scripts/test_workspace_guard.sh
```

Expected: FAIL totdat de ontbrekende testinjectiepunten of volgordecontroles zijn toegevoegd.

- [ ] **Step 3: Voeg uitsluitend benodigde testinjectiepunten toe**

Gebruik omgevingsvariabelen met veilige productie-defaults, bijvoorbeeld
`MEIJENDEL_GATEWAY_RUNNER`, `MEIJENDEL_EXPORT_VALIDATOR` en
`MEIJENDEL_RSYNC_BIN`. Accepteer geen willekeurige shelltekst als override;
alleen een bestaand uitvoerbaar bestandspad.

- [ ] **Step 4: Voer de volledige kleine regressieset uit**

Run:

```bash
Rscript R/test_meijendel_cache_contract.R
bash scripts/test_build_meijendel_shiny_cache.sh
bash scripts/test_export_meijendel_sql.sh
bash scripts/test_meijendel_export_contract.sh
bash deploy/test_gateway_job_runner.sh
bash deploy/test_meijendel_gateway_contract.sh
bash deploy/test_trim_release_contract.sh
bash scripts/test_workspace_guard.sh
bash scripts/test_container_image_definitions.sh
```

Expected: alle opdrachten exit 0; geen skip en geen achtergebleven tijdelijke fixturemap.

- [ ] **Step 5: Commit**

```bash
git add deploy/test_meijendel_gateway_contract.sh scripts/test_workspace_guard.sh scripts/test_container_image_definitions.sh
git commit -m "Test cache-, timeout- en rollbackvolgorde"
```

### Task 7: Documentatie en actuele dump volledig lokaal valideren

**Files:**
- Modify: `README.md`
- Modify: `ARCHITECTURE.md`
- Modify: `deploy/README_DEPLOY.md`
- Modify: `docs/vps_productie.md`
- Modify: `TODO.md`

**Interfaces:**
- Consumes: definitieve commando's, paden, timeouts en foutmeldingen uit Tasks 1-6.
- Produces: één actuele beheerprocedure zonder handmatige cachevoorwarmstap.

- [ ] **Step 1: Werk alle vijf documentatiebronnen synchroon bij**

Leg exact vast:

- export bouwt automatisch cache alleen bij nieuwe SQL-hash/parser-versie;
- de vier artefactnamen en manifestvelden;
- lokale belasting is eenmalig per verversing, niet periodiek of continu;
- VPS bouwt nooit cache en faalt gesloten;
- gateway-log wordt na voltooiing opgehaald; hervatting gebruikt operatie-id;
- timeoutwaarden en rollbackinterpretatie;
- NAS heeft geen rekenrol;
- cache-retentie volgt actieve plus directe rollbackrelease.

Verwijder de twee open TODO-punten pas nadat de actuele dump en de volledige
lokale regressies groen zijn; noteer productie-uitrol afzonderlijk als nog open
tot Task 8 is afgerond.

- [ ] **Step 2: Bouw de cache voor de actuele gevalideerde lokale dump**

Run in de lokale uitvoercontext:

```bash
scripts/validate_meijendel_export.sh --artifact-only meijendel.sql meijendel.sql.manifest
scripts/export_meijendel_sql.sh meijendel.sql meijendel.sql.manifest
scripts/validate_meijendel_export.sh --with-cache meijendel.sql meijendel.sql.manifest .
```

Expected: `EXPORT_STATUS=ready` en `CACHE_STATUS=ready`. Registreer werkelijke
looptijd, maximale lokale geheugendruk indien beschikbaar, SQL-hash,
cachehash en cachegrootte. Wijzig geen database-inhoud.

- [ ] **Step 3: Voer volledige lokale Meijendel-validatie uit**

Run:

```bash
deploy/update_en_deploy_meijendel.sh
deploy/deploy_meijendel_vps.sh
```

De tweede opdracht blijft dry-run. Expected: alle generatie/paritychecks groen,
vier artefacten zichtbaar, kandidaatcachecontrole nog niet op productie
uitgevoerd, nul onverklaarde verwijderingen en productie ongewijzigd.

- [ ] **Step 4: Controleer werkboom en documentatiediff**

Run:

```bash
git status --short
git diff --check
git diff -- README.md ARCHITECTURE.md deploy/README_DEPLOY.md docs/vps_productie.md TODO.md
```

Bevestig dat gegenereerde cachebestanden niet in Git staan en dat alleen
bedoelde analyse-output gewijzigd is. Behandel inhoudelijke outputwijzigingen
als blokkade; een cache-infrastructuurwijziging mag cijfers niet wijzigen.

- [ ] **Step 5: Commit**

```bash
git add README.md ARCHITECTURE.md deploy/README_DEPLOY.md docs/vps_productie.md TODO.md
git commit -m "Documenteer automatische cache- en gatewayketen"
```

### Task 8: Review, integratie en gecontroleerde productie-uitrol

**Files:**
- Modify after successful deployment: `/Users/ton/Documents/GitHub/VWG_Project/RELEASE_MANIFEST.yml`
- Verify only: `/Users/ton/Documents/GitHub/VWG_Project/VPS_PRODUCTIESTATUS.md`

**Interfaces:**
- Consumes: volledig geteste featurebranch en actuele vierdelige artefactset.
- Produces: Meijendel `main`, geïnstalleerde hashgebonden gatewayhelper, groene productierelease en centraal geregistreerde release.

- [ ] **Step 1: Voer branchreview en volledige verificatie vóór integratie uit**

Gebruik `superpowers:requesting-code-review`. Controleer specifiek cachemisser,
symlink/path traversal, shell quoting, timeout/rollback, state-updatevolgorde en
onbedoelde database-/analysewijzigingen. Herhaal daarna de volledige regressieset
uit Task 6 en:

```bash
/Users/ton/Documents/GitHub/VWG_Project/scripts/workspace_preflight.sh
git diff --check main...HEAD
```

Expected: alle tests groen; reviewer heeft geen open kritieke of hoge bevinding.

- [ ] **Step 2: Integreer volgens de branchworkflow**

Push de featurebranch, werk haar bij met actuele `main`, herhaal gerichte tests,
merge naar `main`, push `main` en controleer:

```bash
git status --short --branch
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)"
```

Expected: schone Meijendel-main exact gelijk aan origin/main.

- [ ] **Step 3: Installeer de gewijzigde remote releasehelper hashgebonden**

Voer eerst read-only uit vanuit `VWG_Project` met de Meijendel-main-worktree als
bron:

```bash
MEIJENDEL_DIR=/Users/ton/Documents/GitHub/Meijendel-mysql-openssl-worktree \
  scripts/install_vwgm_admin_gateway_vps.sh
scripts/test_admin_gateway_installer.sh
```

Voor `--apply --yes` opent Codex een zichtbaar standaard macOS Terminal-venster
en controleert de prompt. Ton voert daar zelf eventueel het sudo-wachtwoord in:

```bash
MEIJENDEL_DIR=/Users/ton/Documents/GitHub/Meijendel-mysql-openssl-worktree \
  scripts/install_vwgm_admin_gateway_vps.sh --apply --yes
```

Expected: hashgebonden installatie groen, installerrollback gemeld, bestaande
accounts en Docker-groepsrechten ongewijzigd.

- [ ] **Step 4: Voer productiepreflight en deploy uit vanaf schone main**

Eerst:

```bash
deploy/deploy_meijendel_vps.sh
```

Controleer vier hashes, benodigde ruimte, huidige productie, dry-run en cache.
Daarna pas:

```bash
deploy/deploy_meijendel_vps.sh --apply --yes
```

Expected: kandidaatcache vóór import groen, databaseback-up gemeld,
`SQL_CACHE=TRUE`, Shiny ready, publieke 310-soortenselectie groen, volledige
rooktest groen, gatewayjob beëindigd en globale lock vrij.

- [ ] **Step 5: Controleer productie zonder extra zware berekening**

Lees live uit:

```bash
ssh -i ~/.ssh/vwgm_spectraip_ed25519 ton@45.87.43.90 \
  'cat /srv/vwgm/deploy-state/Meijendel.commit; docker stats --no-stream shiny_meijendel; curl -fsSI http://127.0.0.1:3838/'
/Users/ton/Documents/GitHub/VWG_M/website/vwg-m-linux-app/scripts/smoke_vps.sh
```

Controleer tevens dat geen gatewayjob actief is, alleen voltooide eigen
operatiebestanden zijn opgeruimd, dump/cachemanifesten overeenkomen en Shiny
niet opnieuw de SQL-parser heeft gestart.

Start daarna, serieel en alleen als VPS-geheugen en schijfruimte normaal zijn,
een verse bare-metalback-up via het bestaande zichtbare beheerpad. Valideer
checksum en herstelmanifest en controleer dat de actieve inhoudsgebonden cache,
het actieve cachemanifest en `Meijendel.sql.manifest` in het archief staan. De
bestaande back-upcode bevat `/srv/vwgm/shiny` al; wijzig daarvoor geen
VWG_M-code tenzij deze controle onverwacht faalt.

- [ ] **Step 6: Registreer de release centraal**

Voeg pas nu een nieuwe onveranderlijke release bovenaan
`VWG_Project/RELEASE_MANIFEST.yml` toe met de exact live geregistreerde VWG_M-
en Meijendel-commits. Commit en push VWG_Project; voer daarna uit:

```bash
/Users/ton/Documents/GitHub/VWG_Project/scripts/workspace_preflight.sh
/Users/ton/Documents/GitHub/VWG_Project/scripts/weekly_monitor_vps.sh
```

Expected: release-state exact gelijk aan manifest; geen `URGENT` of
`OVERDUE` die door deze release is ontstaan. Een reguliere `DUE` blijft een
afzonderlijke taak.

- [ ] **Step 7: Rond documentatiebranch en productiebewijs af**

Werk `TODO.md` alleen bij als productie daadwerkelijk `SQL_CACHE=TRUE` meldt en
de gatewayrunner binnen de bedoelde tijd sluit. Commit/push die afronding via
de normale main-workflow. Controleer ten slotte alle drie repositories en alle
actieve taakbranches met de projectpreflight.
