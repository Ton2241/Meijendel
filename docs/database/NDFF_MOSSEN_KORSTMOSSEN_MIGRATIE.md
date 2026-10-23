# NDFF-mossen en -korstmossen: relatiekaart en herstelproef

Stand 23 oktober 2026. Deze kaart beschrijft de **levende lokale** MySQL 9.7.4-database `Meijendel`. Zij is geen opdracht om de bestaande tabellen al te verwijderen.

## Doel en grens

De 32.353 openbare moswaarnemingen (1940–2025) en 28.643 openbare korstmoswaarnemingen (1936–2025) moeten uiteindelijk ieder precies eenmaal als volledige waarneming in respectievelijk `mossen_waarneming` en `korstmossen_waarneming` staan. De 810.830 unieke openbare NDFF-waarnemingen blijven samen telbaar: na verhuizing 749.834 in `ndff_open_waarneming` plus 60.996 in de twee nieuwe tabellen. Onvervaagde geometrieën blijven uitsluitend in `Meijendel_ndff_secure`; de 17 respectievelijk 202 koppelingen met openbare mos- en korstmosregels moeten intact blijven. De originele BLWG-kop-, bezoek- en resultaatgegevens blijven afzonderlijke entiteiten.

## Relatiekaart

`ndff_open_waarneming.waarneming_id` is momenteel de enige foreign-keyouder van 32 constraints in 28 tabellen. Daarvan bevatten de volgende verwijzingen een van de te verhuizen IDs. Aantallen zijn **koppelregels**, niet unieke waarnemingen; `ndff_open_pq_koppeling` bewaart twee regelversies per waarneming.

| Verwijzing | Mos | Korstmos | Betekenis bij verhuizing |
|---|---:|---:|---|
| `ndff_open_pq_koppeling.waarneming_id` | 64.706 | 57.286 | PQ-beoordeling en bronrol bewaren; PQ-regel voor uitsluitend `pq_*` respecteren |
| `ndff_open_ruimtelijke_beoordeling.waarneming_id` | 32.353 | 28.643 | Ruimtelijke kwaliteitsklasse behouden |
| `ndff_open_waarneming_protocol.waarneming_id` | 32.353 | 28.643 | Protocoltoewijzing behouden |
| `ndff_open_soortgroep_koppeling.waarneming_id` | 32.353 | 28.697 | Korstmos heeft 54 extra classificaties als schimmel |
| `ndff_open_leveringsverrijking.waarneming_id` | 17 | 202 | Niet-ruimtelijke metadata van de beveiligde levering behouden |
| `ndff_snl_waarneming_context.waarneming_id` | 9 | 461 | SNL-context behouden |
| `mossen_recordselectie.waarneming_id` / `.canonieke_waarneming_id` | 376 / 374 | 0 / 0 | Twee canonieke mosverwijzingen zijn NULL |
| `korstmossen_recordselectie.waarneming_id` / `.canonieke_waarneming_id` | 0 / 0 | 364 / 364 | Meetstructuur behouden |
| `korstmossen_bron_ndff_groeprecord.ndff_waarneming_id` | 0 | 364 | BLWG-bronmatch behouden |
| `korstmossen_bron_resultaat.ndff_waarneming_id` | 0 | 210 | BLWG-resultaatmatch behouden |

De overige 18 verwijzende tabellen bevatten voor beide groepen nul getroffen regels, maar hun FK-constraint moet óók worden aangepast als de gezamenlijke parent wordt vervangen door een stabiel ID-register. Daarnaast bewaren `ndff_mossen` 32.353 en `ndff_korstmossen` 28.643 ID-verwijzingen. Er is geen overlap tussen die twee groepen. Van de andere 25 groepsindexen deelt uitsluitend `ndff_schimmels` IDs met deze selectie: 54 korstmoswaarnemingen. Ook de parent-delete/update-triggers bewaken deze relaties.

De achttien nu lege maar schema-technisch afhankelijke tabellen zijn: `daz_bmp_recordselectie`, `florbase_recordselectie`, `hns_recordselectie`, `lmfa_recordselectie`, `ndff_bospaddenstoel_recordselectie`, `ndff_bospaddenstoel_verspreiding_recordselectie`, `ndff_braakbal_recordselectie`, `ndff_habslak_recordselectie`, `ndff_konijn_recordselectie`, `ndff_kwartiertelling_recordselectie`, `ndff_liveatlas_recordselectie`, `ndff_nachtvlinder_recordselectie`, `ndff_otter_bever_recordselectie`, `ndff_poldervis_recordselectie`, `ndff_ravon_n2000_recordselectie`, `ndff_tuintelling_recordselectie`, `ndff_vleermuis_recordselectie` en `sovon_avimap_ndff_daz_koppeling`.

Buiten de afgedwongen foreign keys zijn 17 openbare regels gekoppeld aan beveiligde mosregels en 202 aan beveiligde korstmosregels via `Meijendel_ndff_secure.ndff_open_secure_koppeling`. De beveiligde views `v_ndff_canonieke_waarneming` en `v_ndff_analyse_record` lezen nu rechtstreeks uit `Meijendel.ndff_open_waarneming`. Hun bronselectie moet vóór de verhuizing worden bijgewerkt, zonder exacte locaties in `Meijendel` op te slaan. Import-, protocol-, ruimtelijke en exportcontroles in `gis/scripts/` en `scripts/` gebruiken de gezamenlijke tabel eveneens. Een fysieke verhuizing zonder hun aanpassing zou 60.996 regels voor die afnemers laten verdwijnen.

De directe codeafnemers zijn ten minste `gis/scripts/import_ndff_public_gbif.py` (bronimport en beveiligde koppeling), `gis/scripts/import_ndff_secure_delivery.py` (secure-koppeling), `gis/scripts/import_ndff_protocolkwaliteit.py` (protocol- en broncontroles), `gis/scripts/import_external_ecology_sources.py` (centrale taxonpoort en gegenereerde triggers), `gis/scripts/import_meijendel_ruimtelijke_lagen.py` (ruimtelijke toewijzing), `gis/scripts/audit_blwg_korstmossen.py` (bronvergelijking), `scripts/test_meijendel_export_contract.sh` en `scripts/validate_meijendel_export.sh`. De schema's `gis/database/ndff_public_schema.sql`, `gis/database/ndff_protocolkwaliteit_schema.sql` en `gis/database/ndff_secure_schema.sql` leggen de bestaande tabel- en viewrelaties vast. Hun wijziging en regressietoets horen bij de live-fase.

## Open inhoudelijke keuze vóór de levende verhuizing

De actuele PQ-beoordeling `ndff-open-pq-poort-v2` noemt 492 mos- en 275 korstmoswaarnemingen `historische_vegetatiecontext`, en 10.903 mos- en 2.998 korstmoswaarnemingen `niet_beoordeelbaar`. Zij bewijst niet dat al deze regels provinciale PQ-opnamen zijn. De bindende projectregel verlangt dat **werkelijke PQ-inhoud uitsluitend onder `pq_*`** staat. Daarom mag de migratie deze beoordeling niet wissen of alle betreffende regels stilzwijgend als niet-PQ bestempelen. De fysieke bestemming van bevestigde of nog niet uitgesloten PQ-regels moet met die bestaande regel verenigbaar zijn.

## Herstelproef en acceptatiepoort

Een proef mag uitsluitend in een afzonderlijk, exact benoemd lokaal MySQL-proefschema plaatsvinden. Kopieer daarin alle 60.996 bronregels en alle hierboven getroffen kindregels. Leg aantallen en bronidentiteit/geometrie-/payloadchecksums vóór de proef vast. Probeer vervolgens de nieuwe fysieke groepstabellen met gelijkblijvende `waarneming_id` en een smal, gedeeld ID-register als FK-ouder. Simuleer verwijdering van de oude parentregels, herstel de bron- en kindregels uit de proefkopieën en vergelijk iedere koppeling en checksum. Test ook de 54 dubbele soortgroepclassificaties, de 219 beveiligde koppelidentiteiten en de twee bestaande secure-viewselecties. Een smal ID-register bewaart uitsluitend de sleutel en fysieke locatie; het is geen tweede waarneming.

**Stopregel:** geen levende bronregel, FK of groepsindex verwijderen zolang één van deze toetsen faalt, de PQ-bestemming onbeslist is, de bijbehorende import-/analysescripts nog uit de oude tabel lezen, of de gescheiden beveiligde gegevens niet aantoonbaar correct worden gekoppeld. Een grote `Meijendel.sql`-export en Shiny-cachebouw vereisen afzonderlijk akkoord; de herstelproef gebruikt die keten niet.

### Uitkomst 23 oktober 2026

De reproduceerbare proef `gis/scripts/rehearse_ndff_mos_korstmos_restore.py --apply` is geslaagd. Zij verplaatste in het geïsoleerde schema 60.996 volledige bronregels, behield hun IDs en herstelde daarna zowel de parent als alle 13 daadwerkelijk geraakte kindtabellen uit afzonderlijke proefkopieën. De ouder-checksum was vóór en na herstel `4118877743`; alle kindtabellen behielden hun aantallen en checksums. De proef omvatte onder meer 121.992 PQ-beoordelingsregels, 61.050 soortgroepkoppelingen en de 54 extra schimmelindexregels. Het proefschema is na de controle verwijderd. In `Meijendel` en `Meijendel_ndff_secure` is niets gewijzigd. Deze proef bewijst herstelbaarheid van de geselecteerde rijen en relaties; zij bewijst **nog niet** dat alle bestaande applicatie- en importpaden een permanente gesplitste opslag kunnen lezen.

De actuele database heeft bovendien door het centrale taxonregister gegenereerde triggers die op ruim vijftig NDFF-kinder- en groepstabellen een bestaande rij in `ndff_open_waarneming` eisen. Twee parent-triggers verbieden het verwijderen of wijzigen zolang een kind verwijst. Zelfs na het omzetten van alle 32 foreign keys zouden die triggers een levende verhuizing blokkeren. De triggergenerator in `gis/scripts/import_external_ecology_sources.py` en de twee bestaande beveiligde views moeten daarom aantoonbaar zijn aangepast en opnieuw getest voordat de live-fase begint.

## Volgorde na een geslaagde proef

1. Pas scripts, constraints, triggers en beveiligde selecties op een taakbranch aan en voer regressietoetsen uit.
2. Leg een herstelbare kopie van alle werkelijk geraakte rijen en relaties vast; controleer deze vóór enige productie-`DELETE`.
3. Vul de fysieke groepswaarnemingstabellen met onveranderde bronwaarden en IDs; controleer aantallen, checksums, taxonkoppeling en PQ-/analysebesluiten.
4. Zet de FK-ouder veilig om naar het smalle ID-register en verwijder pas dan de 60.996 oude parentregels. Controleer dat alle 810.830 unieke openbare NDFF-identiteiten precies eenmaal aanwezig en bereikbaar zijn.
5. Verwijder **als laatste** `ndff_mossen` en `ndff_korstmossen` na volledige nacontrole, inclusief herstelproef, afnemers en bronregister in Markdown én DOCX. Geen VPS-publicatie zonder afzonderlijk akkoord.

## Uitvoeringsplan voor de fysieke verhuizing

De bestaande herstelproef is stap nul, niet de migratie zelf. De verdere stappen
worden op de bestaande taakbranch uitgevoerd; de levende database verandert pas
na een tweede, volledige proef.

1. **Leescontract.** Voeg een smal register voor alle openbare NDFF-ID's toe met
   uitsluitend `waarneming_id` en fysieke opslaglocatie. Behoud de oorspronkelijke
   waarnemingskolommen alleen in de drie elkaar uitsluitende fysieke tabellen.
   Test dat iedere identiteit exact eenmaal voorkomt, ook de 54 korstmosregels
   met een extra schimmelclassificatie.
2. **Schrijfcontract.** Laat alle 32 bestaande foreign keys en de gegenereerde
   taxontriggers naar het gedeelde ID-register verwijzen. Nieuwe invoer mag nooit
   twee fysieke kopieën van één ID opleveren. Test invoer, wijziging, verwijdering
   en weigering van verweesde kinderregels.
3. **Afnemers.** Pas de twee bestaande beveiligde views en alle directe
   import-, protocol-, ruimtelijke, BLWG- en exportafnemers aan. Geen nieuwe
   views of dubbele waarnemingstabellen. Test de 219 koppelingen naar de
   beveiligde levering en de centrale route vanuit `taxa`.
4. **Volledige geïsoleerde proef.** Voer het migratiescript uit op een lokaal
   proefschema met dezelfde structuur en getroffen rijen. Vergelijk vóór en na
   aantallen, identiteit, payload, geometrie, PQ-status, protocol, taxonroute,
   secure-selecties en kindverwijzingen. Bewijs ook terugzetting.
5. **Levende uitvoering.** Maak een herstelbare kopie van exact de betrokken
   gegevens. Voer daarna alleen de in stap 4 beproefde migratie lokaal uit.
   Verwijder de oude groepsindexen pas na een groene volledige nacontrole.
   Werk beide bronregisterversies en alle betrokken documentatie bij. De zware
   export/cacheketen en VPS-publicatie zijn uitdrukkelijk geen onderdeel hiervan.

**Beslisregel voor PQ-kandidaten:** de bestaande `niet_beoordeelbaar`- en
`historische_vegetatiecontext`-beoordelingen blijven ongewijzigd. Een kandidaat
wordt door deze opslagmigratie niet als bevestigde PQ-opname of als zelfstandige
waarneming heringedeeld. Werkelijke PQ-inhoud blijft onder de bindende `pq_*`-
opslagregel vallen; een bevestigde PQ-regel mag niet stilzwijgend in een van de
nieuwe groepstabellen worden ondergebracht.
