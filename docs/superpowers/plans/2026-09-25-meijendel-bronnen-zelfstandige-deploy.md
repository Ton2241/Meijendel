# Zelfstandige Meijendel_bronnen-deploy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bouw een afzonderlijke, rollbackbare productie-release voor `Meijendel_bronnen` die de ecologische database, Shiny-cache en dashboards niet leest, kopieert, importeert of herstart.

**Architecture:** `Meijendel` krijgt een bron-only lokale orchestrator, gatewayrunner en roothelper met een eigen kandidaatmanifest, back-upmap en productiestatus. De bestaande ecologische release wordt teruggebracht tot uitsluitend `Meijendel`; `VWG_M` staat de nieuwe gesloten gatewayactie toe en `VWG_Project` installeert haar hashgebonden en herstelbaar.

**Tech Stack:** Bash, Python 3 `argparse`, MySQL 9.7.1, Docker/Compose op de VPS, SSH/rsync, pytest en shellcontracttests.

**Spec:** `docs/superpowers/specs/2026-09-25-meijendel-bronnen-zelfstandige-deploy-design.md`

## Global Constraints

- De levende lokale MySQL-database blijft canoniek; de dump is een gevalideerde afgeleide.
- Lokaal en op de VPS is exact MySQL 9.7.1 vereist.
- Een bron-only release raakt `Meijendel`, Shiny, cachebestanden, R-uitvoer en ecologische productiestatus niet.
- Een ecologische release raakt `Meijendel_bronnen`, haar dump, back-ups en productiestatus niet.
- Beide paden gebruiken dezelfde globale VPS-deploy-lock.
- Alleen de drie vastgelegde catalogusviews krijgen `SELECT`; brede schemarechten zijn verboden.
- Kandidaat, manifest, Git-commit en SHA-256 moeten exact overeenkomen.
- Na importstart leidt iedere fout tot rollback van uitsluitend `Meijendel_bronnen`.
- Productie-installatie en productiedeploy vallen buiten dit implementatieplan en vereisen later afzonderlijke toestemming.
- Iedere productiewijziging doorloopt preflight, tests, back-up, kandidaatvalidatie, deploy, smoketest en releaseregistratie.

## Review Focus

- Een geldige commit met een onjuiste of geïnjecteerde SHA-256 moet vóór gatewayuitvoering worden geweigerd; Task 1 test zowel lengte als tekens.
- Een dump met een lokaal macOS-pad of ontbrekende vereiste view mag nooit kandidaat worden; Task 1 test beide blokkades.
- Een fout na `DROP/CREATE DATABASE` moet alleen de bronback-up terugzetten en mag `Meijendel` niet noemen in herstel-SQL; Task 2 simuleert deze fout.
- Een bestaande brede grant moet worden ingetrokken en na apply mogen exact drie viewgrants overblijven; Task 2 test het grantcontract.
- Een mislukte gateway-installatie moet zowel gateway als beide Meijendel-helpers exact terugzetten; Task 5 breidt de installerrollbacktest uit.

---

### Task 1: Lokale bron-only kandidaat en gesloten runner

**Files:**
- Create: `deploy/deploy_meijendel_bronnen_vps.sh`
- Create: `deploy/run_bronnen_gateway_job_vps.sh`
- Create: `deploy/test_meijendel_bronnen_gateway_contract.sh`
- Modify: `scripts/test_meijendel_bronnen_deploy_guard.sh`

**Interfaces:**
- Consumes: `meijendel_bronnen.sql`, schone actuele `main`, `mysql --login-path=meijendel_root`, globale lock `/srv/vwgm/deploy-state/production.lock`.
- Produces: kandidaat `Meijendel_bronnen.sql.candidate-<commit>-<sha256>`, manifest `meijendel-bronnen-manifest-v2`, en runneraanroep `meijendel-bronnen-release <stage> <commit> <sha256>`.

- [ ] **Step 1: Schrijf de falende contracttests**

Laat `deploy/test_meijendel_bronnen_gateway_contract.sh` eisen dat het bronpad alleen bron-dump/manifest synchroniseert, commit en 64-teken-SHA valideert, een begrensde tijdelijke hersteldatabase opruimt en geen van `Meijendel.sql`, cache, `R/`, `trim/`, `restart_shiny` of Shiny Compose noemt. Voeg een mock-SSH/rsync/MySQL-scenario toe dat de volledige dry-run zonder netwerk uitvoert. Pas `scripts/test_meijendel_bronnen_deploy_guard.sh` aan zodat het de nieuwe bestanden eist en juist verbiedt dat het ecologische pad de bron-dump bevat.

- [ ] **Step 2: Controleer RED**

Run: `bash deploy/test_meijendel_bronnen_gateway_contract.sh && bash scripts/test_meijendel_bronnen_deploy_guard.sh`  
Expected: FAIL omdat de bron-only scripts nog ontbreken en het ecologische script nog gekoppeld is.

- [ ] **Step 3: Implementeer de minimale lokale orchestrator en runner**

`deploy_meijendel_bronnen_vps.sh` ondersteunt `--apply --yes`, valideert lokaal via een tijdelijke database, schrijft manifestvelden `format`, `commit`, `sql_sha256`, `sql_bytes`, `literature_total`, `literature_active`, `literature_removed`, `literature_active_with_tags`, voert dry-run en route-smoke uit en roept alleen `run_bronnen_gateway_job_vps.sh` aan. De runner volgt de bestaande hervatbare gatewayjobstructuur maar accepteert exact stage, commit en hash.

- [ ] **Step 4: Controleer GREEN en syntax**

Run: `bash -n deploy/deploy_meijendel_bronnen_vps.sh deploy/run_bronnen_gateway_job_vps.sh && bash deploy/test_meijendel_bronnen_gateway_contract.sh`  
Expected: PASS en `OK: zelfstandige Meijendel_bronnen-gateway...`.

- [ ] **Step 5: Commit**

```bash
git add deploy/deploy_meijendel_bronnen_vps.sh deploy/run_bronnen_gateway_job_vps.sh \
  deploy/test_meijendel_bronnen_gateway_contract.sh scripts/test_meijendel_bronnen_deploy_guard.sh
git commit -m "Voeg zelfstandige kandidaatroute voor Meijendel_bronnen toe"
```

### Task 2: Bron-only roothelper met back-up en rollback

**Files:**
- Create: `deploy/deploy_meijendel_bronnen_release_vps_remote.sh`
- Create: `deploy/test_meijendel_bronnen_release_remote.sh`
- Modify: `deploy/test_gateway_job_runner.sh`

**Interfaces:**
- Consumes: actionargumenten `preflight|apply`, exacte commit en SHA-256 plus het v2-manifest uit Task 1.
- Produces: `/srv/vwgm/data/Meijendel_bronnen.sql`, back-up onder `/srv/vwgm/backups/meijendel-bronnen-mysql/`, status `/srv/vwgm/deploy-state/Meijendel_bronnen.release`, `SOURCES_STATUS=ready` of `ROLLBACK_STATUS=ready`.

- [ ] **Step 1: Schrijf falende helper- en rollbacktests**

Gebruik een tijdelijke `MEIJENDEL_REMOTE_BASE` en PATH-mocks voor `docker`. Test preflight, manifest/hashmismatch, lege back-up, importfout, exacte drie grants, statusformaat en de afwezigheid van ecologische import-, cache- en herstartcommando's. Breid de runner-test uit met timeout-na-bronimport, waarbij `SOURCES_DATABASE_BACKUP=` plus `ROLLBACK_STATUS=ready` verplicht zijn.

- [ ] **Step 2: Controleer RED**

Run: `bash deploy/test_meijendel_bronnen_release_remote.sh && bash deploy/test_gateway_job_runner.sh`  
Expected: FAIL omdat de roothelper ontbreekt en de runner het bronrollbackcontract nog niet kent.

- [ ] **Step 3: Implementeer de roothelper**

Maak functies `restore_sources_backup`, `validate_manifest`, `apply_view_grants`, `validate_sources_database` en `write_sources_state`. Gebruik `SET SESSION sql_log_bin=0`, `gzip -t`, `CHECK TABLE EXTENDED`, foreign-key- en viewtellingen. De EXIT-trap herstelt alleen de bronback-up wanneer `import_started=1` en schrijft status pas na alle controles atomair.

- [ ] **Step 4: Controleer GREEN**

Run: `bash -n deploy/deploy_meijendel_bronnen_release_vps_remote.sh && bash deploy/test_meijendel_bronnen_release_remote.sh && bash deploy/test_gateway_job_runner.sh`  
Expected: alle scenario's PASS; de foutinjectie meldt aantoonbaar `ROLLBACK_STATUS=ready`.

- [ ] **Step 5: Commit**

```bash
git add deploy/deploy_meijendel_bronnen_release_vps_remote.sh \
  deploy/test_meijendel_bronnen_release_remote.sh deploy/test_gateway_job_runner.sh
git commit -m "Voeg rollbackbare bron-only releasehelper toe"
```

### Task 3: Ontkoppel de bestaande ecologische release

**Files:**
- Modify: `deploy/deploy_meijendel_vps.sh`
- Modify: `deploy/deploy_meijendel_release_vps_remote.sh`
- Modify: `deploy/test_meijendel_gateway_contract.sh`
- Modify: `deploy/README_DEPLOY.md`
- Modify: `scripts/test_meijendel_bronnen_deploy_guard.sh`

**Interfaces:**
- Consumes: bestaand ecologisch dump-, cache- en Shiny-contract.
- Produces: ongewijzigde ecologische releasefunctionaliteit zonder enige bron-dump, bronback-up, bronimport, bronstatus of brongrant.

- [ ] **Step 1: Verscherp eerst de falende negatieve contracttests**

Laat beide contracttests iedere verwijzing naar `Meijendel_bronnen`, `SOURCES_` en bron-viewgrants in de twee ecologische scripts afwijzen. Behoud alle bestaande eisen voor ecologische hash, cache, back-up, rollback, Shiny-herstart en smoke.

- [ ] **Step 2: Controleer RED**

Run: `bash deploy/test_meijendel_gateway_contract.sh && bash scripts/test_meijendel_bronnen_deploy_guard.sh`  
Expected: FAIL op de huidige gekoppelde bronverwijzingen.

- [ ] **Step 3: Verwijder uitsluitend het bronpad uit de ecologische scripts**

Laat de ecologische back-up alleen `$MYSQL_DATABASE` bevatten, verwijder bronkandidaten, bronhashes, bronimport, grants en bronrollback. Pas de README aan met twee expliciete commando's en zet erbij dat data-only Zotero-updates nooit het ecologische script gebruiken.

- [ ] **Step 4: Controleer GREEN en bestaande regressiecontracten**

Run: `bash -n deploy/deploy_meijendel_vps.sh deploy/deploy_meijendel_release_vps_remote.sh && bash deploy/test_meijendel_gateway_contract.sh && bash scripts/test_meijendel_bronnen_deploy_guard.sh && bash deploy/test_trim_release_contract.sh`  
Expected: PASS; het ecologische contract bevat nog alle cache- en rollbackwaarborgen maar geen bronverwijzingen.

- [ ] **Step 5: Commit**

```bash
git add deploy/deploy_meijendel_vps.sh deploy/deploy_meijendel_release_vps_remote.sh \
  deploy/test_meijendel_gateway_contract.sh deploy/README_DEPLOY.md \
  scripts/test_meijendel_bronnen_deploy_guard.sh
git commit -m "Ontkoppel broncatalogus van ecologische release"
```

### Task 4: Sta de nieuwe actie begrensd toe in VWG_M

**Files:**
- Modify: `website/vwg-m-linux-app/deploy/vwgm_admin_gateway_vps.py`
- Modify: `website/vwg-m-linux-app/tests/test_vwgm_admin_gateway.py`

**Interfaces:**
- Consumes: `meijendel-bronnen-release`, stage `preflight|apply`, `exact_commit`, nieuwe validator `exact_sha256`.
- Produces: commandplan naar `/usr/local/libexec/vwgm-admin/meijendel-bronnen-release-root` met exact vier vaste argumenten.

- [ ] **Step 1: Schrijf de falende parsertest**

Voeg `test_meijendel_bronnen_release_accepts_only_fixed_stage_commit_and_sha256` toe. Accepteer alleen lowercase 40-hex commit en lowercase 64-hex hash; verwerp verkeerde lengte, hoofdletters, `;id`, `main`, vrije stage en extra argumenten.

- [ ] **Step 2: Controleer RED**

Run vanuit `website/vwg-m-linux-app`: `pytest -q tests/test_vwgm_admin_gateway.py -k meijendel_bronnen_release`  
Expected: FAIL omdat actie, pad en `exact_sha256` ontbreken.

- [ ] **Step 3: Implementeer de minimale allowlist-uitbreiding**

Voeg constante `MEIJENDEL_BRONNEN_RELEASE`, validator `exact_sha256(value: str) -> str`, parser en commandplan toe. Wijzig geen bestaande acties of sudo-beleid.

- [ ] **Step 4: Controleer GREEN en gatewayregressies**

Run: `pytest -q tests/test_vwgm_admin_gateway.py`  
Expected: alle gatewaytests PASS.

- [ ] **Step 5: Commit in VWG_M**

```bash
git add website/vwg-m-linux-app/deploy/vwgm_admin_gateway_vps.py \
  website/vwg-m-linux-app/tests/test_vwgm_admin_gateway.py
git commit -m "Sta begrensde broncatalogusrelease toe"
```

### Task 5: Installeer de nieuwe roothelper gecontroleerd via VWG_Project

**Files:**
- Modify: `scripts/install_vwgm_admin_gateway_vps.sh`
- Modify: `scripts/install_vwgm_admin_gateway_vps_remote.sh`
- Modify: `scripts/test_admin_gateway_installer.sh`

**Interfaces:**
- Consumes: `Meijendel/deploy/deploy_meijendel_bronnen_release_vps_remote.sh` en de VWG_M-gateway uit Task 4.
- Produces: root-owned modus `0750` op `/usr/local/libexec/vwgm-admin/meijendel-bronnen-release-root`, met hashcontrole, installatierollback en onveranderd hashgebonden sudoerscontract.

- [ ] **Step 1: Schrijf de falende installatietest**

Eis bronpad, hashvariabele, kandidaatregel, upload, syntaxcontrole, back-up, installatie, live hashcontrole en herstelregel. Verhoog de mockverwachting van tien naar elf uploads en test dat een afgebroken installatie de nieuwe helper als bestaand bestand of `.absent` terugzet.

- [ ] **Step 2: Controleer RED**

Run: `bash scripts/test_admin_gateway_installer.sh`  
Expected: FAIL omdat de elfde helper en rollbackdekking ontbreken.

- [ ] **Step 3: Breid lokale en remote installer minimaal uit**

Voeg `MEIJENDEL_BRONNEN_RELEASE_SOURCE/HASH`, staging, cleanup, omgevingsdoorgifte, `bash -n`, `backup_one`, `restore_one`, `install`, live hash- en moduscontrole toe. Laat accounts, groepen, sudoersvorm en bestaande helpers verder ongewijzigd.

- [ ] **Step 4: Controleer GREEN**

Run: `bash scripts/test_admin_gateway_installer.sh && bash scripts/test_weekly_monitor.sh`  
Expected: beide PASS; mock-apply toont exact elf uploads en één interactieve SSH-installatiestap.

- [ ] **Step 5: Commit in VWG_Project**

```bash
git add scripts/install_vwgm_admin_gateway_vps.sh \
  scripts/install_vwgm_admin_gateway_vps_remote.sh scripts/test_admin_gateway_installer.sh
git commit -m "Neem bronreleasehelper op in beheergateway"
```

### Task 6: Integrale documentatie en verificatie

**Files:**
- Modify: `deploy/README_DEPLOY.md`
- Modify: `docs/superpowers/specs/2026-09-25-meijendel-bronnen-zelfstandige-deploy-design.md` (`Status: uitgevoerd` pas na groene verificatie)
- Test: alle gewijzigde contract- en projecttests in drie repositories

**Interfaces:**
- Consumes: Tasks 1–5.
- Produces: drie reviewbare branches, volledig testbewijs en een exact productie-installatie/deploy-runbook zonder uitvoering.

- [ ] **Step 1: Voeg een falende documentatiecontrole toe aan het broncontract**

Eis in `deploy/test_meijendel_bronnen_gateway_contract.sh` de afzonderlijke preflight/apply-commando's, bronstatuspad, back-uplocatie, expliciete uitsluiting van Shiny en de volgorde gateway-installatie → bronpreflight → afzonderlijke productiegoedkeuring → bronapply.

- [ ] **Step 2: Controleer RED en werk README/spec bij**

Run: `bash deploy/test_meijendel_bronnen_gateway_contract.sh`  
Expected: eerst FAIL op ontbrekende runbooktekst; na documentatieaanpassing PASS.

- [ ] **Step 3: Draai de volledige lokale verificatie**

Run in `Meijendel`:

```bash
for test in deploy/test_*.sh scripts/test_*.sh; do bash "$test"; done
python3 -m unittest discover -s gis/scripts -p 'test_*.py'
```

Run vanuit de root van `VWG_M`:

```bash
scripts/test_local.sh
```

Run in `VWG_Project`:

```bash
bash scripts/test_admin_gateway_installer.sh
bash scripts/test_weekly_monitor.sh
scripts/workspace_preflight.sh
```

Expected: nul fouten; de preflight meldt alle drie repositories op hun bedoelde reviewbranches of na integratie exact gelijk aan hun remote branch.

- [ ] **Step 4: Leg het eerste echte productiepad vast zonder het uit te voeren**

Documenteer na integratie op schone actuele `main` deze afzonderlijk te autoriseren volgorde:

```bash
VWG_Project/scripts/install_vwgm_admin_gateway_vps.sh
VWG_Project/scripts/install_vwgm_admin_gateway_vps.sh --apply --yes
Meijendel/deploy/deploy_meijendel_bronnen_vps.sh
Meijendel/deploy/deploy_meijendel_bronnen_vps.sh --apply --yes
```

Expected bij latere uitvoering: gateway-installatiepreflight vóór installatie; daarna lokale tijdelijke restore en manifestcontrole groen, rsync alleen dump en manifest en eindmelding `Preflight klaar; productie is niet aangepast.` Geen van deze productiecommando's wordt in deze implementatietaak uitgevoerd.

- [ ] **Step 5: Maak oplevercommits indien documentatie na eerdere taken wijzigde**

Commit alleen de resterende documentatie/testwijzigingen per repository. Push of productie-installatie gebeurt pas na een afzonderlijke gebruikersopdracht en de finishing-a-development-branch-keuze.
