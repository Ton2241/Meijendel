# Importprocedure Meijendel database

**Database:** Meijendel  
**Engine:** InnoDB, UTF8MB4  
**Frequentie:** Jaarlijks  
**Laatste update van dit document:** februari 2026  

---

## Overzicht

Eén keer per jaar worden nieuwe vogelterritoria verwerkt vanuit externe bron (SOVON) naar de productietabellen. Dit document beschrijft de volgorde en de controles die daarbij horen.

---

## Betrokken werktabellen

| Tabel                       | Functie                                     | Bron                                 |
| --------------------------- | ------------------------------------------- | ------------------------------------ |
| `import_waarnemingen_breed` | Brede SOVON-download met plots als kolommen | [AANVULLEN: URL of locatie download] |
| `import_waarnemingen_lang`  | Lange versie van dezelfde SOVON-download    | [AANVULLEN: URL of locatie download] |
|                             |                                             |                                      |
|                             |                                             |                                      |

---

## Stap 1: maak een backup

Voer dit uit vóór elke import, zonder uitzondering.

1. Open TablePlus en maak verbinding met Meijendel.
2. Klik op `File > Export > SQL Dump`.
3. Sla op als `meijendel_backup_JJJJMMDD.sql` in de map op de iMAC.


---

## Stap 2: laad de SOVON-download in de werktabellen

[AANVULLEN: beschrijf hier hoe u de download inlaadt, bijvoorbeeld via TablePlus Import, een CSV-import of een extern script.]

Controleer na het laden:

```sql
-- Controleer of de werktabellen gevuld zijn.
SELECT 'import_waarnemingen_breed' AS tabel, COUNT(*) AS aantal_rijen
FROM import_waarnemingen_breed
UNION ALL
SELECT 'import_waarnemingen_lang', COUNT(*)
FROM import_waarnemingen_lang
UNION ALL
SELECT 'habitattypen_doelstelling', COUNT(*)
FROM habitattypen_doelstelling;
```

Verwacht resultaat: alle drie tabellen bevatten rijen. Is een tabel leeg? Stop en controleer de import.

---

## Stap 3: verwerk de data naar de productietabellen

[AANVULLEN: voeg hier de SQL-queries in die de data vanuit de werktabellen naar `waarnemingen`, `habitattypen` en andere productietabellen verplaatsen.]

Voer na elke INSERT een telling uit om te controleren of het aantal rijen klopt:

```sql
-- Voorbeeld controletelling na INSERT in waarnemingen.
SELECT jaar, COUNT(*) AS aantal_waarnemingen
FROM waarnemingen
WHERE jaar = [AANVULLEN: importjaar]
GROUP BY jaar;
```

---

## Stap 4: controleer referentiële integriteit

Controleer of alle geïmporteerde soorten en plots bekend zijn in de productietabellen:

```sql
-- Controleer of alle euring_codes uit de import bestaan in soorten.
-- Rijen in het resultaat zijn onbekende soorten die eerst toegevoegd moeten worden.
SELECT DISTINCT i.euring_code
FROM import_waarnemingen_lang i
LEFT JOIN soorten s ON i.euring_code = s.euring_code
WHERE s.euring_code IS NULL;
```

```sql
-- Controleer of alle plot_ids uit de import bestaan in plots.
-- Rijen in het resultaat zijn onbekende plots.
SELECT DISTINCT i.plot_id
FROM import_waarnemingen_lang i
LEFT JOIN plots p ON i.plot_id = p.plot_id
WHERE p.plot_id IS NULL;
```

Los ontbrekende soorten of plots op vóór u verder gaat.

---

## Stap 5: maak de werktabellen leeg

Pas uitvoeren nadat stap 3 en 4 zonder fouten zijn afgerond.

```sql
TRUNCATE TABLE import_waarnemingen_breed;
TRUNCATE TABLE import_waarnemingen_lang;
TRUNCATE TABLE habitattypen_doelstelling;
```

---

## Stap 6: leg de import vast in GitHub

1. Exporteer het bijgewerkte schema via `File > Export > SQL Dump`.
2. Sla op als `meijendel_schema_JJJJMMDD.sql` in de repository-map.
3. Open GitHub Desktop.
4. Commit met bericht `Jaarlijkse import JJJJ verwerkt` en push naar origin.


## Contactpersoon en beheer

**Beheerder:** [AANVULLEN]  
**Repository:** [AANVULLEN: GitHub URL]  
**Laatste succesvolle import:** [AANVULLEN: datum en jaar]
