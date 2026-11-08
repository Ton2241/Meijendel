# Soortgerichte opslag van Meijendel-waarnemingen

## Doel

De volledige soortwaarneming staat fysiek precies eenmaal in een herkenbare
soortgroeptabel. De centrale taxonroute, bronidentiteit, oorspronkelijke
meetwaarden, afscherming en bestaande afnemers blijven intact. Alleen een
aangetoonde of onderbouwd vermoedelijke PQ-opname wordt fysiek `pq_*`;
een protocolgebonden PQ-risicobesluit staat daar als besluit, zonder de
bronwaarneming automatisch tot PQ te verklaren. Vogels en Vangblik blijven
in hun bestaande meetstructuur. Geen VPS-publicatie.

## Nulmeting 8 november 2026

- `ndff_open_waarneming`: 749.834 volledige openbare bronregels uit
  1700–2025, in 25 bronlabelvarianten. Alle 749.834 hebben via het centrale
  taxonregister één primaire groep.
- 24 `ndff_*`-groepstabellen bevatten uitsluitend een ID. De 179
  dubbel gelabelde records horen volgens `taxon_groepen` primair bij
  kreeftachtigen; beide originele groepslabels blijven bewaard.
- `mossen_waarneming` en `korstmossen_waarneming` zijn reeds volledige
  fysieke groepstabellen.
- 90.992 openbare regels uit 1981–2025 zijn alleen op protocol
  `12.007`/`12.202` voor zelfstandige telling geblokkeerd. Er is
  geen afzonderlijk benoemde PQ- of opnamesleutel in hun bronpayload.
  De 1.621.660 geversioneerde openbare PQ-besluiten blijven behouden.

## Werkpakketten en acceptatie

1. **Contract en selectie.** Vervang de bronprefixvoorkeur in
   `VWG_Project/workflow.md`; corrigeer `TODO.md`,
   `TAXONREGISTER.md` en beide bronregistervormen. Test dat ieder
   openbaar NDFF-ID precies één centrale primaire groep heeft, ook de
   179 dubbel gelabelde records. Een protocol alleen levert geen
   PQ-opname-ID op.
2. **Fysieke opslag.** Gebruik het bestaande smalle
   `ndff_open_waarneming_register` als onveranderlijke FK-ouder.
   Maak volledige `<groep>_waarneming`-tabellen voor de 24 nog
   ID-only-groepen, naar het geteste patroon van mossen en korstmossen.
   Bewaar alle 45 oorspronkelijke bronkolommen, inclusief ID en batch,
   bronhouder, protocol, payload en geometrie. Test één-op-één-vulling,
   hashgelijkheid en de weigering van een tweede fysieke kopie.
3. **Centrale route en afnemers.** Breid de bestaande taxonroutegenerator,
   ID-locator, beschermende triggers en twee beveiligde NDFF-views uit.
   Pas NDFF-import en analyses op dezelfde groepindeling aan.
   Test alle 127 bestaande taxonroutes plus de nieuwe routes, de
   openbare en afgeschermde selecties en ongewijzigde website-,
   dashboard- en Shiny-waarden. Geen nieuwe presentatieviews.
4. **PQ-besluiten.** Bewaar alle openbare en beveiligde geversioneerde
   PQ-beoordelingen onder een afgeschermde passende `pq_*`-route.
   Verplaats alleen bronopnamen waarvoor meer dan een protocolcode een
   echte of vermoedelijke opname-identiteit onderbouwt.
   Test uitsluiting van zelfstandig meetellen, historie, privacy en
   herinvoerblokkade.
5. **Geïsoleerde proef en lokale uitvoering.** Registreer een nieuwe
   T7-proef, kopieer de actuele databases, herstel ze onafhankelijk en
   test de volledige migratie, rollback en herhaling. Pas daarna één
   gecontroleerde lokale live-uitvoering met verse herstelkopie.
   Verwijder oude volledige bronrijen en ID-only-tabellen uitsluitend
   na behoudsvergelijking. Genereer en valideer de lokale SQL-afspiegeling
   volgens de projectpoort; publiceer niets naar de VPS.

## Stopregels

Geen live-DML of `DROP TABLE` wanneer een bronhash, taxonroute, FK,
bronidentiteit, afnemerwaarde of herstelproef afwijkt. Een groep zonder
eenduidige primaire centrale toewijzing blijft buiten de fysieke
verplaatsing totdat haar identiteit inhoudelijk is vastgesteld.
