# Fysieke NDFF-opslag van vlinders en libellen

**Uitvoering: 17 november 2026, uitsluitend lokale levende database `Meijendel`.**

Ton heeft de openbare NDFF-bronregels voor Dagvlinders, Nachtvlinders en
Microvlinders onder één soortgroeptabel laten brengen en die voor Libellen onder
een tweede. Dit is een opslagverhuizing, geen nieuwe meting of validatie.

| Fysieke brontabel | Openbare regels na verhuizing |
| --- | ---: |
| `ndff_open_waarneming` (overige groepen) | 492.444 |
| `vlinders_waarneming` | 225.065 |
| `libellen_waarneming` | 32.325 |
| `mossen_waarneming` | 32.353 |
| `korstmossen_waarneming` | 28.643 |
| **Unieke openbare NDFF-identiteiten** | **810.830** |

De vier vroegere `ndff_dagvlinders`, `ndff_nachtvlinders`,
`ndff_microvlinders` en `ndff_libellen` waren enkelkoloms-indexen op dezelfde
waarnemingen. Ze zijn verwijderd nadat de nieuwe volledige bronrijen en
afnemers waren gecontroleerd. `ndff_open_waarneming_register` bevat per
`waarneming_id` precies één verwijzing naar de fysieke bronrij, geen kopie van
de waarneming. De oorspronkelijke NDFF-identiteit, payload, polygoon,
protocolkoppeling, PQ-poort en ruimtelijke beoordeling zijn behouden. De
beveiligde levering bevat 61 corresponderende vlinderrecords; die blijven
uitsluitend in `Meijendel_ndff_secure`. De lokale canonieke selectie blijft
810.983 unieke regels tellen, inclusief 153 beveiligde regels zonder openbare
tegenhanger.

## Koppeling aan De Vlinderstichting

De tabellen `vlinders_waarneming_routekoppeling` en
`libellen_waarneming_routekoppeling` leggen alleen een **afgeleide** koppeling
vast voor NDFF-regels met de betreffende meetnetcode. De bronregels en Toves
primaire jaarcijfers worden niet opgeteld als onafhankelijke waarnemingen.

- Vlinders: 80.998 NDFF-regels zijn aan een gereconstrueerd bezoek verbonden.
  Voor 78.500 is een Tove-routejaar aannemelijk. Daarvan steunt bij 16.708
  de familie-identificatie alleen op het gedeelde bezoekinterval; het eigen
  NDFF-vlak bewijst die route niet afzonderlijk. De 2.219 regels van
  routefamilie 7 horen vermoedelijk bij de historische route Voorlinden 1764,
  waarvoor Tove geen telobject of jaarcijfers leverde. Voor 94 Eikenpage-regels
  ontbreken de bijbehorende jaren van Toves afzonderlijke route 5169; zij
  worden niet aan de algemene Vallei-route 4588 toegeschreven. Voor 185
  regels is geen route herleidbaar.
- Libellen: 3.280 NDFF-regels zijn aan een gereconstrueerd bezoek verbonden.
  Voor 2.403 is één Tove-locatiejaar aannemelijk; bij 201 daarvan berust de
  familie-identificatie alleen op het bezoekinterval. Voor 526 regels laat
  het bronvlak geen keuze tussen twee Hertenkamp-poelen toe. De overige 351
  hebben geen herleidbare route. Tove leverde nog geen soortjaarcijfers voor
  libellen.

Een routejaarkoppeling bewijst geen identiek afzonderlijk bezoek. De NDFF-
polygonen kunnen een onzekerheidsbuffer weergeven. De bestaande protocol-,
ruimtelijke en gegevensgeschiktheidsregels blijven daarom van toepassing.

## Herstel en controles

Voor de wijziging is de doelgerichte SQL-herstelkopie bewaard op T7 onder
`Meijendel data/Backups-archief/Meijendel/2026-11-17_ndff_vlinders_libellen_before.sql.gz`
(220.529.340 bytes; SHA-256
`acf3684355bd6294bb74094a6cded7a78d5ead9a0b298f15b668fc652a1625f5`).
De gzip is volledig leesbaar; voor de ouder, het register en de vier indexen
zijn zowel tabeldefinities als gegevensregels aangetroffen. De DDL, foreign
keys, route-SQL en omschakelprocedure zijn eerst op een geïsoleerde MySQL
9.7.4-server op T7 uitgevoerd. Vervolgens zijn de bronrijen gekopieerd en
voor het verwijderen op identiteit, payload, status en geometrie vergeleken.
De omschakeling en de fysieke verwijdering gebeurden pas na de pariteitscheck.

Na afloop: 810.830 registeridentiteiten, 810.983 canonieke regels, nul
vlinder- of libellenregels in de overgebleven `ndff_open_waarneming`, nul
registerrijen zonder bron en geen vier oude groepsindexen. De centrale
taxonquerypoort rapporteerde `errors=[]`; de bestaande dagvlinder-, libellen-
en resterende NEM-audits slaagden. De algemene NDFF-groepsinventarisatie
toont 28 reeds bestaande korstmos/schimmelregels zonder gekozen primaire
taxongroep afzonderlijk als `nog_geen_centrale_groep`; deze regels zijn niet
door de verhuizing ontstaan of verborgen.

De opslag volgt het onderscheid tussen een waarneming (*Occurrence*),
gereconstrueerd bezoek (*Event*) en locatie (*Location*) in
[Darwin Core](https://dwc.tdwg.org/terms/). Taxonidentiteit blijft via het
centrale register gekoppeld volgens de projecttoets aan
[TDWG TCS](https://tcs.tdwg.org/terms/). Er is geen nieuw taxonconcept uit een
route- of jaarcode afgeleid.

Er is geen `meijendel.sql`-export, cachebouw of VPS-publicatie gestart.
