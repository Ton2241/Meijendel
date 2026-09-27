# Taxonregister: structuur en uitvoering

Stand: 27 september 2026. Deze stap betreft uitsluitend drie lege tabellen in
de levende lokale database `Meijendel`. Geen extra database, views, import,
groepsindeling of koppeling van bestaande gegevens. Het eerdere voorstel om
eerst een databasekopie te gebruiken geldt niet voor deze uitdrukkelijk
geautoriseerde, toevoegende structuurstap.

## Wat hoort waar?

| Tabel | Eén rij betekent | Belangrijkste inhoud |
| --- | --- | --- |
| `taxon_groepen` | Eén praktische soortgroep | Stabiele code, naam, omschrijving, eventueel bovenliggende groep en bron van de indeling. |
| `taxa` | Eén taxonnaamgebruik met zijn taxonomische context | Eigen ID en UUID, naam/auteur, rang, conceptbron, taxonomische status, synoniem- en hiërarchiekoppelingen. |
| `taxa_bronkoppeling` | Eén geversioneerd beoordelingsbesluit over een brontaxon en eventueel een centraal taxon | Bronidentiteit, oorspronkelijke naam/indeling, bronversie, doel, relatie, methode en onderbouwing. |

De praktische groep staat los van de formele taxonomie. Een rijk is daarom
geen verplicht kenmerk van een groep. De groepshiërarchie kan bijvoorbeeld
vlinders en dagvlinders bevatten, zonder daarmee taxonomische rangen voor te
schrijven. Elk taxon heeft maximaal één primaire gebruiksgroep; aanvullende
groepsindelingen vallen buiten deze eerste structuur.

`taxa` is bewust niet beperkt tot soorten. Ook ondersoorten, geslachten,
aggregaten, hybriden en operationele eenheden kunnen worden geregistreerd.
Een onbekende Nederlandse naam, groep of rang blijft `NULL`. Een beschikbare
wetenschappelijke naam of expliciete operationele aanduiding is wel nodig;
een nog onopgeloste broncode kan zonder centraal taxon in de bronkoppeling
blijven staan. `accepted` en `synonym` zijn statussen, geen rangen.

Dezelfde naam kan verschillende afbakeningen hebben. Daarom is de naam niet
uniek. `naam_volgens` en de bijbehorende identificatie/versie beschrijven welke
taxonomische behandeling bedoeld wordt. Een vastgesteld taxon vereist die
context en een vastgelegde beoordelaar en datum. Het eigen UUID wordt door de
latere importeur toegekend en verandert niet bij een tekstcorrectie. Een
wezenlijk ander taxonconcept krijgt een nieuwe identiteit; de bestaande wordt
niet stilzwijgend overschreven.

De bestaande tabel `soorten` blijft de vogeltabel. Ook `ndff_*`,
`externe_ecologie_*`, `pq_*` en `vangblik*` blijven ongewijzigd. Metingen,
vindplaatsen, aantallen, bedekking en meetmethoden horen niet in dit register.
De nieuwe tabellen bewaren taxonomische gegevens en hun herkomst, niet alle
ecologische informatie over een soort. Gestructureerde aanvullende namen en
bronvelden passen in JSON; relationele sleutels en analysewaarden worden daar
niet in verstopt. Een eventueel kenmerkenregister vraagt later een eigen
besluit, inclusief eenheden, bronnen en tijdsafhankelijkheid.

## Bronidentiteit en koppelingen

Een bron-ID is pas betekenisvol samen met `bron_systeem`, `bron_dataset` en
`bron_versie`. Alle vier worden letterlijk en hoofdlettergevoelig bewaard.
Ontbreekt een formele lijstversie, dan gebruikt de importeur een gedocumenteerde
snapshotidentiteit, niet een verzonnen versienummer. Een afgeleide sleutel
wordt expliciet onderscheiden van een oorspronkelijke bron-ID.

De database berekent een SHA-256 over de JSON-array van deze vier velden.
Dat voorkomt te lange samengestelde indexen en dubbelzinnige aaneenplakking.
De oorspronkelijke velden blijven controleerbaar; de latere importeur moet
bij een bestaande hash ook alle vier waarden vergelijken en botsingen
weigeren. Normalisatie van broncodes mag alleen volgens een vastgelegde
bronregel, nooit door namen willekeurig klein te maken of tekens te schrappen.

Een bronvermelding kan onbeoordeeld blijven, meerdere kandidaten hebben of
een onderbouwde koppeling krijgen. `taxonrelatie` onderscheidt gelijk,
bron omvat doel, bron is deel van doel, overlap en disjunct. Richting is altijd
van brontaxon naar centraal taxon. Alleen een actuele, bevestigde relatie
`gelijk` is bruikbaar als exacte taxontoewijzing. Een bevestigde bredere,
nauwere of overlappende relatie is geen toestemming om gegevens samen te voegen.

Per bronidentiteit kan hoogstens één actuele exacte koppeling bestaan.
Besluitversies en een intrekkingsdatum bewaren eerdere beoordelingen. Dit is
geen automatisch auditlog: de latere importeur moet eerdere besluiten
intrekken en nieuwe besluiten toevoegen, niet bestaande besluiten overschrijven.
Ook dezelfde bronvermelding in verschillende kandidaatregels moet dezelfde
bronmetadata houden; die consistentie vraagt importvalidatie.

## Onderbouwing

De wetenschappelijke internetverkenning is uitgevoerd op 27 september 2026.
De standaarden geven begrippen en uitwisselregels; zij schrijven niet deze
concrete MySQL-tabellen voor. Het schema is een daarop gebaseerd lokaal ontwerp,
geen volledige implementatie van alle mogelijkheden van Darwin Core of TCS.

- [Wieczorek e.a. (2012), Darwin Core: An Evolving Community-Developed Biodiversity Data Standard](https://doi.org/10.1371/journal.pone.0029715):
  wetenschappelijke grondslag voor gedeelde termen en gegevensuitwisseling.
- [Darwin Core, normatieve termen](https://dwc.tdwg.org/terms/): onderscheid
  tussen taxonID, scientificNameID, taxonConceptID, nameAccordingTo,
  taxonRank, taxonomicStatus en verwijzingen naar geaccepteerde,
  bovenliggende en oorspronkelijke namen.
- [TDWG Taxon Concept Schema](https://tcs.tdwg.org/terms/): naam en
  taxonomische afbakening zijn verschillende zaken; relaties kunnen ook
  inclusie, overlap of uitsluiting uitdrukken. Daarom geen automatische
  gelijkstelling op alleen naam of broncode.
- [GBIF IPT, checklist best practices](https://ipt.gbif.org/manual/en/ipt/latest/best-practices-checklists):
  eigen identificaties voor naamgebruiken en expliciete synoniemkoppelingen.

## Technische uitvoering en veiligheidsgrens

SQL: `gis/database/taxonregister_schema.sql`.
Installatiecontrole: `gis/scripts/test_taxonregister_live_schema.py`.
Beide werken op de lokale MySQL 9.7.1. De controle leest uitsluitend het
werkelijk aangemaakte schema en de leegte van de drie tabellen; zij voegt geen
proefrecords toe. Na toekomstige imports is deze leegtecontrole niet meer de
toepasselijke acceptatietest.

De migratie bevat alleen drie `CREATE TABLE`-opdrachten, met InnoDB, Unicode,
interne foreign keys zonder cascades en afgedwongen CHECK-regels. Geen
`IF NOT EXISTS`: een reeds bezette naam moet blokkeren. De voorafgaande
uitvoeringscontrole moet alle drie namen tegelijk vrij vinden en de lokale
serveridentiteit bevestigen. MySQL-DDL is atomair per statement, niet voor de
hele reeks. Bij een fout dus stoppen, de gedeeltelijke stand inspecteren en
niet blind opnieuw uitvoeren.

Vóór uitvoering is een volledige consistente logische back-up gemaakt in de
lokale, Git-genegeerde map `outputs/taxonregister-20260927.W0WSU6/`:
`meijendel-voor.sql.gz`. Gzip-integriteit gecontroleerd. SHA-256:
`18199af4611743128ef19a352724a71f2500153b592cca348b5f4d459d76daba`.
Er is geen herstelproef naar een tweede database uitgevoerd.

De eindcontrole vergelijkt dezelfde deterministische volledige export vóór en
na de migratie, na uitsluiting van uitsluitend de drie nieuwe tabellen.
Daarmee wordt vastgesteld of de bestaande structuur en gegevens gelijk zijn
gebleven. De werkelijke uitkomst staat hieronder; alleen het bestaan van een
back-up is geen bewijs dat de wijziging veilig is verlopen.

Er wordt geen publicatiedump of Shiny-cache vernieuwd en niets naar de VPS
uitgerold. De bestaande `meijendel.sql` weerspiegelt na deze stap dus nog niet
het nieuwe lokale schema. Vóór een toekomstige release moet de normale
export-, cache-, validatie- en publicatieketen opnieuw worden uitgevoerd.

Een eventuele terugdraaiing mag uitsluitend de drie nieuwe tabellen betreffen,
in afhankelijkheidsvolgorde: bronkoppeling, taxa, groepen. Eerst aantonen dat ze
nog leeg zijn en geen externe verwijzingen hebben; uitvoering vereist een
afzonderlijk besluit. Nooit hiervoor de volledige database terugzetten, want
dat zou intussen toegevoegde gegevens kunnen vernietigen.

## Uitvoeringslog

- [x] Wetenschappelijke en technische bronnen gecontroleerd.
- [x] Leegte-/schematest vóór migratie faalt zoals verwacht: tabellen ontbreken.
- [x] Volledige back-up gemaakt en integriteit gecontroleerd.
- [x] Onafhankelijke schema-review afgerond. Eén testcorrectie: `NO ACTION`
  naast `RESTRICT` accepteren; beide blokkeren cascades bij InnoDB.
- [x] Drie lege tabellen rechtstreeks in de levende database aangemaakt.
- [x] Werkelijke structuur en onveranderde bestaande database gecontroleerd.
- [x] Projectdocumentatie en regressiecontroles afgerond.

De controle op 27 september 2026 bevestigt 3 lege nieuwe tabellen, 6 exact
gecontroleerde interne foreign keys en 24 afgedwongen CHECK-regels. Het totaal
is nu 251 basistabellen en 16 bestaande views. Geen nieuwe view gemaakt.
De 248 bestaande basistabellen, 16 views en overige geëxporteerde objecten
leveren vóór en na de toevoeging byte-identieke gecomprimeerde SQL op:
beide SHA-256-waarden zijn de hierboven vastgelegde back-uphash. `cmp` slaagt.
De tweede export heet `meijendel-na-bestaand.sql.gz` in dezelfde uitvoermap.
Dit bewijst de onveranderde bestaande exportinhoud, niet de werking van nog
niet uitgevoerde import- of taxonkoppelproeven.

Ook geslaagd: de 7 bestaande `gis/scripts/test_*schema_contract.py`-controles,
`scripts/test_meijendel_export_contract.sh` en
`scripts/test_export_meijendel_sql.sh`. Dit zijn gerichte regressiecontroles,
geen volledige nieuwe website-/Shiny-gebruikerstest. Applicatiebestanden,
publicatieartefacten en VPS zijn niet aangepast. Werk vastgelegd op de
taakbranch `feature/taxonregister-structuur`; de twee vooraf aanwezige Pages-
bestanden bij de tabelinventaris zijn niet gewijzigd of aan Git toegevoegd.

De MySQL-regels zijn gecontroleerd aan de officiële documentatie voor
[CHECK-constraints](https://dev.mysql.com/doc/refman/9.7/en/create-table-check-constraints.html),
[gegenereerde kolommen](https://dev.mysql.com/doc/refman/9.7/en/create-table-generated-columns.html)
en [foreign keys](https://dev.mysql.com/doc/refman/9.7/en/create-table-foreign-keys.html).

## Eerstvolgende stap, nog niet uitgevoerd

Pas na deze structuurstap beoordelen we met de bestaande databasegegevens
welke groepen, taxa en bronkoppelingen passen. Dan volgen ook proeven voor
homoniemen, synoniemen, taxonsplitsingen, onopgeloste codes, bronversies en
dubbeltellingen. Hiërarchiecycli, zelfverwijzingen, synoniemketens,
metadata-consistentie en conceptwijzigingen moeten vóór import expliciet
worden getoetst: foreign keys bewijzen alleen dat een doel bestaat, niet dat
de taxonomische relatie inhoudelijk klopt. De groepskeuze wordt dus nog niet
met zaadrecords vastgezet.
