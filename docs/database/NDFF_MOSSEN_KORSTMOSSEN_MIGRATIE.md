# NDFF-mossen en -korstmossen: relatiekaart en fysieke verhuizing

Stand 23 oktober 2026. Deze kaart beschrijft de **levende lokale** MySQL 9.7.4-database `Meijendel`, inclusief de vandaag afgeronde fysieke verhuizing. De historische aantallen hieronder zijn de nulmeting van vóór de verhuizing.

## Doel en grens

De 32.353 openbare moswaarnemingen (1940–2025) en 28.643 openbare korstmoswaarnemingen (1936–2025) staan ieder precies eenmaal als volledige waarneming in respectievelijk `mossen_waarneming` en `korstmossen_waarneming`. De 810.830 unieke openbare NDFF-waarnemingen blijven samen telbaar: 749.834 in `ndff_open_waarneming` plus 60.996 in de twee groepstabellen. Onvervaagde geometrieën blijven uitsluitend in `Meijendel_ndff_secure`. De originele BLWG-kop-, bezoek- en resultaatgegevens blijven afzonderlijke entiteiten.

## Relatiekaart

Vóór de verhuizing was `ndff_open_waarneming.waarneming_id` de foreign-keyouder van 32 constraints in 28 tabellen. Alle 32 verwijzen nu naar `ndff_open_waarneming_register`. De volgende nulmeting toont welke verwijzingen een verhuisd ID bevatten. Aantallen zijn **koppelregels**, niet unieke waarnemingen; `ndff_open_pq_koppeling` bewaart twee regelversies per waarneming.

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

De overige 18 verwijzende tabellen bevatten voor beide groepen nul getroffen regels; ook hun FK-constraint is aangepast. De voormalige ID-indexen `ndff_mossen` en `ndff_korstmossen` bevatten respectievelijk 32.353 en 28.643 verwijzingen en zijn na de eindcontrole verwijderd. Er was geen overlap tussen die twee groepen. Van de andere groepsindexen deelt uitsluitend `ndff_schimmels` IDs met deze selectie: 54 korstmoswaarnemingen. De nieuwe triggers bewaken de bron en het smalle register.

De achttien nu lege maar schema-technisch afhankelijke tabellen zijn: `daz_bmp_recordselectie`, `florbase_recordselectie`, `hns_recordselectie`, `lmfa_recordselectie`, `ndff_bospaddenstoel_recordselectie`, `ndff_bospaddenstoel_verspreiding_recordselectie`, `ndff_braakbal_recordselectie`, `ndff_habslak_recordselectie`, `ndff_konijn_recordselectie`, `ndff_kwartiertelling_recordselectie`, `ndff_liveatlas_recordselectie`, `ndff_nachtvlinder_recordselectie`, `ndff_otter_bever_recordselectie`, `ndff_poldervis_recordselectie`, `ndff_ravon_n2000_recordselectie`, `ndff_tuintelling_recordselectie`, `ndff_vleermuis_recordselectie` en `sovon_avimap_ndff_daz_koppeling`.

Buiten de afgedwongen foreign keys zijn 17 openbare regels gekoppeld aan beveiligde mosregels en 202 aan beveiligde korstmosregels via `Meijendel_ndff_secure.ndff_open_secure_koppeling`. De bestaande beveiligde view `v_ndff_canonieke_waarneming` selecteert nu uit de drie fysieke openbare tabellen via het register; `v_ndff_analyse_record` blijft daarop aansluiten. De logische selectie bevat zowel vóór als na verhuizing 810.983 waarnemingen. Exacte locaties zijn niet naar `Meijendel` gekopieerd. Import-, protocol-, ruimtelijke en exportcontroles zijn aangepast voor de gesplitste opslag.

De directe codeafnemers zijn ten minste `gis/scripts/import_ndff_public_gbif.py` (bronimport en beveiligde koppeling), `gis/scripts/import_ndff_secure_delivery.py` (secure-koppeling), `gis/scripts/import_ndff_protocolkwaliteit.py` (protocol- en broncontroles), `gis/scripts/import_external_ecology_sources.py` (centrale taxonpoort en gegenereerde triggers), `gis/scripts/import_meijendel_ruimtelijke_lagen.py` (ruimtelijke toewijzing), `gis/scripts/audit_blwg_korstmossen.py` (bronvergelijking), `scripts/test_meijendel_export_contract.sh` en `scripts/validate_meijendel_export.sh`. De schema's `gis/database/ndff_public_schema.sql`, `gis/database/ndff_protocolkwaliteit_schema.sql` en `gis/database/ndff_secure_schema.sql` leggen de bestaande tabel- en viewrelaties vast. Hun wijziging en regressietoets horen bij de live-fase.

## PQ-beoordeling blijft afzonderlijk

De PQ-beoordeling `ndff-open-pq-poort-v2` noemt 492 mos- en 275 korstmoswaarnemingen `historische_vegetatiecontext`, en 10.903 mos- en 2.998 korstmoswaarnemingen `niet_beoordeelbaar`. Zij bewijst niet dat al deze regels provinciale PQ-opnamen zijn. De bindende projectregel verlangt dat **bevestigde PQ-inhoud uitsluitend onder `pq_*`** staat. Deze migratie verplaatst alleen de oorspronkelijke NDFF-bronregels; zij verandert geen PQ-beoordeling en voegt geen kandidaat toe aan de provinciale PQ-reeks. De inhoudelijke beoordeling van de niet-gematchte kandidaten blijft open.

## Herstelproef en acceptatiepoort

Een proef mag uitsluitend in een afzonderlijk, exact benoemd lokaal MySQL-proefschema plaatsvinden. Kopieer daarin alle 60.996 bronregels en alle hierboven getroffen kindregels. Leg aantallen en bronidentiteit/geometrie-/payloadchecksums vóór de proef vast. Probeer vervolgens de nieuwe fysieke groepstabellen met gelijkblijvende `waarneming_id` en een smal, gedeeld ID-register als FK-ouder. Simuleer verwijdering van de oude parentregels, herstel de bron- en kindregels uit de proefkopieën en vergelijk iedere koppeling en checksum. Test ook de 54 dubbele soortgroepclassificaties, de 219 beveiligde koppelidentiteiten en de twee bestaande secure-viewselecties. Een smal ID-register bewaart uitsluitend de sleutel en fysieke locatie; het is geen tweede waarneming.

**Toegepaste stopregel:** geen levende bronregel of groepsindex verwijderen zolang een herstelproef, bronkopie, FK-controle, centrale taxonpoort of beveiligde selectie faalt. De afzonderlijke inhoudelijke PQ-beoordeling wordt hierdoor niet gewijzigd. Een grote `Meijendel.sql`-export en Shiny-cachebouw vereisen afzonderlijk akkoord; deze verhuizing gebruikte die keten niet.

### Uitkomst 23 oktober 2026

De reproduceerbare proef `gis/scripts/rehearse_ndff_mos_korstmos_restore.py --apply` is geslaagd. Zij verplaatste in het geïsoleerde schema 60.996 volledige bronregels, behield hun IDs en herstelde daarna zowel de parent als alle 13 daadwerkelijk geraakte kindtabellen uit afzonderlijke proefkopieën. De ouder-checksum was vóór en na herstel `4118877743`; alle kindtabellen behielden hun aantallen en checksums. De proef omvatte onder meer 121.992 PQ-beoordelingsregels, 61.050 soortgroepkoppelingen en de 54 extra schimmelindexregels. Het proefschema is na de controle verwijderd. In `Meijendel` en `Meijendel_ndff_secure` is niets gewijzigd. Deze proef bewijst herstelbaarheid van de geselecteerde rijen en relaties; zij bewijst **nog niet** dat alle bestaande applicatie- en importpaden een permanente gesplitste opslag kunnen lezen.

De vóór de verhuizing aanwezige centrale taxontriggers eisten nog een bronregel in `ndff_open_waarneming`. Hun generator is aangepast en de triggers zijn opnieuw geplaatst: zij gebruiken nu het smalle register en de fysieke opslaglocatie. De nieuwe regels beschermen ook tegen verweesde verwijzingen, dubbele identiteiten en het verwijderen van nog gebruikte bronregels.

## Historische uitvoeringsvolgorde na een geslaagde proef

1. Pas scripts, constraints, triggers en beveiligde selecties op een taakbranch aan en voer regressietoetsen uit.
2. Leg een herstelbare kopie van alle werkelijk geraakte rijen en relaties vast; controleer deze vóór enige productie-`DELETE`.
3. Vul de fysieke groepswaarnemingstabellen met onveranderde bronwaarden en IDs; controleer aantallen, checksums, taxonkoppeling en PQ-/analysebesluiten.
4. Zet de FK-ouder veilig om naar het smalle ID-register en verwijder pas dan de 60.996 oude parentregels. Controleer dat alle 810.830 unieke openbare NDFF-identiteiten precies eenmaal aanwezig en bereikbaar zijn.
5. Verwijder **als laatste** `ndff_mossen` en `ndff_korstmossen` na volledige nacontrole, inclusief herstelproef, afnemers en bronregister in Markdown én DOCX. Geen VPS-publicatie zonder afzonderlijk akkoord.

## Historisch uitvoeringsplan voor de fysieke verhuizing

Dit vóór de verhuizing vastgelegde plan is op 23 oktober 2026 uitgevoerd;
het is geen opdracht om de migratie opnieuw uit te voeren. De herstelproef
was stap nul. De levende uitvoering volgde na de aanvullende proef.

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

### Uitkomst 23 oktober 2026: levende verhuizing afgerond

De voorcontrole bevestigde 810.830 unieke openbare NDFF-regels, waarvan
32.353 mossen en 28.643 korstmossen, zonder ID-overlap. De herstelproef met
alle 60.996 doelregels staat hierboven. Een afzonderlijke proef met drie
voorbeeldrecords testte vervolgens de nieuwe fysieke tabellen, het gedeelde
register, de triggers en de transactie, inclusief een bewuste fout die volledig
werd teruggedraaid. Beide proefschema's zijn na verificatie verwijderd.

De levende MySQL-migratie zette alle 32 externe sleutels om, verving de
bronbewakende triggers en actualiseerde de bestaande beveiligde selectie. De
60.996 bronregels zijn in één transactie omgeschakeld; de controles bevestigden
749.834 + 32.353 + 28.643 = 810.830 openbare regels en ongewijzigd 810.983
logische regels in de beveiligde selectie. Pas daarna zijn de twee oude
ID-indexen verwijderd. De centrale taxonpoort controleerde 313 basistabellen
en rapporteerde nul fouten. De kwalificaties van PQ-kandidaten zijn niet
gewijzigd of opgewaardeerd. Het historische bootstrap-importpad weigert een
reeds gesplitste database. Er is geen zware export of Shiny-cachebouw gedaan en
geen VPS-publicatie uitgevoerd.

## Actuele leesroute en controle van oude codeverwijzingen

Documentatiecontrole van 24 oktober 2026: `ndff_mossen` en
`ndff_korstmossen` bestaan niet meer als openbare tabellen in `Meijendel`.
Een alleen-lezen controle van de fysieke verdeling gebruikt het register:

```sql
SELECT opslag_tabel, COUNT(*) AS openbare_identificaties
FROM Meijendel.ndff_open_waarneming_register
GROUP BY opslag_tabel;
```

De bij deze migratie vastgestelde verdeling is 749.834, 32.353 en 28.643
voor respectievelijk `ndff_open_waarneming`, `mossen_waarneming` en
`korstmossen_waarneming`. Lees de volledige bronvelden uit de betreffende
fysieke tabel, gekoppeld via `waarneming_id`; tel het register niet als extra
waarnemingen mee.

Oude namen in `migrate_ndff_mossen_korstmossen.py` en de bijbehorende
`rehearse_*`-scripts beschrijven de historische uitgangssituatie en de
herstelproef. Het openbare `ndff_public_schema.sql` en de bootstrap-import
`import_ndff_public_gbif.py` bevatten eveneens historische indexdefinities;
hun controles blokkeren toepassing op een reeds gesplitste database. Deze
paden zijn geen actuele importvoorbeelden voor de gesplitste opslag.
`import_external_ecology_sources.py` bewaart de oude indexen in het
historische schemacontract en verwijdert ze uit de verwachte tabellen zodra
het openbare register aanwezig is.

De gelijknamige tabellen in `ndff_secure_schema.sql` en de groepsmapping in
`import_ndff_secure_delivery.py` behoren tot het afzonderlijke beveiligde
schema `Meijendel_ndff_secure`. Hun gelijkluidende namen bewijzen geen
achtergebleven openbare indexen. De `sync_bronregister_*`-scripts bevatten
ook oude tekst als zoekanker voor een eerdere documentcorrectie. Deze
historische en schema-afhankelijke verwijzingen zijn behouden; er is bij deze
documentatiecorrectie geen databasecode uitgevoerd of gewijzigd.
