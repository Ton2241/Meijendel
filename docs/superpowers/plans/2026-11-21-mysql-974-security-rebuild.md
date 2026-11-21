# MySQL 9.7.4 Security Rebuild Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lever een lokaal geteste, nog niet uitgevoerde onderhoudsroute voor een veilige MySQL 9.7.4→9.7.4 image-rebuild.

**Architecture:** Een nieuwe wrapper bindt repository-, VPS- en scanpreflight; een nieuwe remote helper bouwt en valideert de kandidaat, voert bij latere apply de begrensde wissel uit en kan de exact behouden rollback later finaliseren. De bestaande validator blijft leidend voor databasevergelijking.

**Tech Stack:** Bash, Docker Buildx, MySQL 9.7.4, RPM/microdnf, bestaande VWG-admin-gateway en rooktests.

**Spec:** `docs/superpowers/specs/2026-11-21-mysql-974-security-rebuild-design.md`

## Global Constraints

- Raak tijdens ontwikkeling en tests geen levende lokale of VPS-database aan.
- Behoud MySQL exact 9.7.4 en UID/GID exact 1999:1999.
- Kandidaat: 0 HIGH/0 CRITICAL en minimaal libxml2 2.9.13-18.el9_9.1, curl/libcurl 7.76.1-44.el9_9.1 en krb5-libs 1.21.1-10.0.1.el9_9.2.
- Geen Docker-prune, geen datamapmigratie, geen wijziging van `Meijendel.commit`.
- Geen merge naar `main` of productie-uitvoering zolang de gelijktijdige databaseoperatie loopt.

## Review Focus

- Een andere actieve image-ID moet de apply blokkeren.
- Een verouderde RPM of een kandidaatscan met HIGH/CRITICAL moet blokkeren.
- Een ontbrekende of gewijzigde datamount moet blokkeren.
- Een mislukte wissel moet de oude container automatisch onder de oorspronkelijke naam starten.
- Finalisatie mag alleen exact één gestopte rollback van deze route verwijderen.

---

### Task 1: Contracttest voor de nieuwe route

**Files:**
- Create: `scripts/test_rebuild_mysql_974_security.sh`

**Interfaces:**
- Consumes: scannerregels en pakketversies uit het ontwerp.
- Produces: uitvoerbare regressietest voor wrapper en remote helper.

- [ ] Schrijf de test voor versie-, scan-, mount-, rollback- en finalisatiecontracten.
- [ ] Voer de test uit en bevestig dat zij faalt omdat de nieuwe route ontbreekt.

### Task 2: Wrapper en remote onderhoudshelper

**Files:**
- Create: `deploy/rebuild_mysql_974_security_vps.sh`
- Create: `deploy/rebuild_mysql_974_security_vps_remote.sh`
- Modify: `deploy/README_DEPLOY.md`

**Interfaces:**
- Consumes: `deploy/mysql_image/Dockerfile.9.7.4`, `deploy/production_guard.sh`, `deploy/validate_mysql_uid_migration_vps_remote.sh`.
- Produces: read-only preflight, expliciete apply en afzonderlijke finalisatie.

- [ ] Implementeer minimale wrapper- en remote route volgens het ontwerp.
- [ ] Documenteer dat de historische 9.7.1-route hiervoor ongeschikt is.
- [ ] Voer de contracttest uit en bevestig groen.

### Task 3: Gerichte regressie en branchafronding

**Files:**
- Modify indien nodig: `scripts/test_container_image_definitions.sh`

**Interfaces:**
- Consumes: alle bestanden uit Task 1 en 2.
- Produces: geverifieerde taakbranch zonder productie-effect.

- [ ] Draai Bash-syntaxcontrole, de nieuwe contracttest en de bestaande containerdefinitietest.
- [ ] Controleer de diff op secrets, databaseaanroepen tijdens tests en ongerichte verwijdering.
- [ ] Commit en push uitsluitend de taakbranch; merge en productie blijven uitgesteld.
