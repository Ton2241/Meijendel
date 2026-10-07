# Importprocedure Meijendel database

**Database:** Meijendel  
**Engine:** InnoDB, UTF8MB4  
**Frequentie:** Jaarlijks  
**Laatste update van dit document:** 6 oktober 2026\

---

## Overzicht

Eén keer per jaar worden nieuwe vogelterritoria verwerkt vanuit externe bron (SOVON) naar de productietabellen. Dit document beschrijft de volgorde en de controles die daarbij horen.

## Goedkeuringsstatus

Neem voor SOVON in `territoria` uitsluitend formele territoria uit goedgekeurde
SOVON-tellingen op. Controleer die status vóór import en bewaar het besluit in
`sovon_bmp_plotjaar`. De volledige SOVON-controle van 3 oktober 2026 omvat 55
Meijendel-plots en 1984-2025. Zij levert 25 formeel afgekeurde plotjaren met
bezoeken of records op. Geen van deze 25 bevat nog een `sovon_m`-regel. Bij de
laatste correctie zijn 373 SOVON-regels met samen 756 territoria verwijderd
voor M8/2008, M45/2018, M8/2018, M75/2024 en M51/2025. M8/2019 staat nu groen;
daarvoor zijn 19 positieve SOVON-regels met 114 territoria hersteld. De matrix
voor M8/2019 bevat uitsluitend 107 lege cellen, dus geen nullen. `territoria`
bevat daarna 157.580 regels. De 60 regels uit `jrvslg_m` en vier uit
`meeuwen_literatuur` voor M35 in 1984-1987 en 2000 blijven volgens de
brongebonden regels behouden; zij zijn geen SOVON-uitkomsten.

Twaalf oranje-rode combinaties zonder bezoeken, soorten of records bevatten
in de downloads uitsluitend 980 lege matrixcellen. Zij zijn geen telling en
krijgen geen plotjaarstatus. M53/2007 bevat in SOVON 36 soorttotalen, maar geen
individuele bron-ID, datum, bezoekkoppeling of exporteerbaar waarnemingspunt;
reconstrueer deze totalen daarom niet als `dagwaarnemingen_bmp`.
Sluit 2016/M62 wel uit van de BMP-tellersensitiviteitsanalyse: dit was een
afzonderlijke roofvogeltelling.

Bezoeken en waarnemingen in `dagbezoeken_bmp` en `dagwaarnemingen_bmp` kunnen
ook afkomstig zijn uit een niet-goedgekeurde telling en zijn op zichzelf geen
bewijs van goedkeuring.

Leid afkeuring niet uitsluitend af uit het ontbreken van een territoriumregel.
Een goedgekeurd plotjaar kan voor een afzonderlijke soort immers nul territoria
hebben. Gebruik voor analyses van territoria, trends en tellersensitiviteit
alleen de goedgekeurde territoriumuitkomsten en de bijbehorende registratie in
`plot_jaar_teller`.

## Nulwaarden per bron

Gebruik voor officiële SOVON-Excelbestanden de op 6 oktober 2026 door SOVON
Helpdesk bevestigde betekenis:

- `0` is een harde nul: de soort is onderzocht maar niet vastgesteld;
- een lege cel betekent dat de soort niet is onderzocht en blijft `NA`.

Deze regel geldt voor alle SOVON-territoriummatrices in dit project. Leid uit
een lege SOVON-cel nooit alsnog nul af omdat de soort elders in Meijendel is
waargenomen.

Voor de afzonderlijke bron `jrvslg_m` geldt bij TRIM een vastgelegde
analyseaanname. Een plotjaar met jaarverslagresultaten geldt als onderzocht
voor iedere vogelsoort met ten minste één geaccepteerd positief `jrvslg_m`-
territoriumresultaat in de volledige jaarverslagreeks 1958-2025.
Ontbreekt zo'n soort in een geteld jaarverslagplot, dan krijgt de analysematrix
een afgeleide nul met status `afgeleide_jaarverslagnul`. Het is daarvoor niet
nodig dat de soort in hetzelfde kalenderjaar elders is vastgesteld. Schrijf
deze afleiding niet als bronregel naar `territoria`: die tabel blijft uitsluitend
letterlijke bronwaarden bevatten. Een aanwezige positieve waarde blijft altijd
leidend. Bij een plotjaar waarvoor ook SOVON-data bestaan, blijft een lege
SOVON-cel `NA`; een eventuele jaarverslagnul blijft een afzonderlijke,
herleidbare analysewaarde uit de jaarverslagbron.

Een niet-geteld plotjaar blijft altijd `NA`. Een formeel afgekeurd
SOVON-plotjaar blijft voor de SOVON-bron eveneens `NA`. Een zelfstandige,
geldige jaarverslagbron in hetzelfde plotjaar mag wel volgens de bovenstaande
jaarverslagregel bijdragen.

Bewaar in iedere analysematrix naast de waarde ook bron, nulstatus en
bewijsgrond. Gebruik minimaal de statussen `territorium_vastgesteld`,
`letterlijke_nul`, `afgeleide_jaarverslagnul`, `niet_onderzocht` en
`formeel_afgekeurd`. Daardoor blijft zichtbaar welke nullen rechtstreeks door
SOVON zijn geleverd en welke uit de volledige soortenregistratie in een
jaarverslagplot zijn afgeleid.

De herberekening van 7 oktober 2026 vindt binnen 662 getelde
`jrvslg_m`-plotjaren en een actuele soortpool van 128 soorten 66.116 afgeleide
jaarverslagnullen: 60.387 in 1958-1983 en 5.729 in 1984-2025. Na selectie op
het eerste positieve jaar en actieve plots worden 15.921 cellen werkelijk als
TRIM-modelinvoer gebruikt: 14.149 in 1958-1983 en 1.772 in 1984-2025. De
gedeelde matrixbouwer past de regel toe in batch-TRIM, Shiny, Sandra en GEE.
De Sandra-selectie 1997-2022 bevat geen `jrvslg_m`-plotjaar en verandert door
deze regel niet.

## Telleridentificatie

Gebruik voor de teller of het tellerteam per plot en jaar uitsluitend
`plot_jaar_teller` uit de levende lokale Meijendel-database. Het veld
`waarnemer` uit een SOVON/AVIMAP-resultatendownload is daarvoor niet leidend:
inhoudelijke controle heeft concrete toeschrijvingen gevonden aan kavels die
de genoemde waarnemer niet heeft geteld. Gebruik dit veld daarom niet om
`plot_jaar_teller` te vervangen, aan te vullen of te corrigeren. Als het wordt
ingelezen, blijft het uitsluitend een letterlijke bronwaarde voor audit.

Behoud meerdere geregistreerde tellers binnen hetzelfde plotjaar als een
tellerteam. Leid daaruit niet af wie aan welk afzonderlijk bezoek deelnam. De
AVIMAP-bezoekentabel bevat geen telleridentificatie. Deze beperking betreft
alleen de telleridentificatie en is geen algemene afwijzing van de aangeleverde
territorium- of bezoekgegevens.

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
