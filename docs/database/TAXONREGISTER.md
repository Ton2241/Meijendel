# Taxonregister: structuur en uitvoering

## Beoordeling uitzonderingen op 27 september 2026

Het invoermanifest v2 is nog niet geschikt voor een invoerproef. De nadere
controle van alle 15.351 voorstellen vindt 129 aanvullende naamvormsignalen
onder de eerder technisch voorbereide regels. Eén oude markering is onterecht:
`Byssonectria aggregata` bevat het soortepitheton `aggregata`, geen `agg.`.
Daarmee vragen netto 1.575 voorstellen beoordeling, tegenover de eerdere
1.447. De resterende 13.776 vallen buiten deze specifieke blokkades; dit is
geen volledige taxonomische validatie of vrijgave voor invoer.

De categorieën hieronder zijn disjunct: eerst LVD, dan het PQ-lengtesignaal,
dan de overige naamvormen. Het zijn voorstellen voor de volgende manifestversie,
geen door Ton goedgekeurde invoerbesluiten. Manifest, UUIDs, database en
applicaties zijn in deze beoordeling niet gewijzigd.

| Categorie | Voorstellen | Advies voor voorbereiding |
| --- | ---: | --- |
| LVD, bronreeks 1959–2015 | 998 | Rang leeg laten, letterlijke bronstatus afzonderlijk bewaren. Bij 122 voorstellen is het auteursveld gelijk aan de hele naam; die tekst niet als auteur overnemen. Naamvormen binnen deze categorie blijven afzonderlijk te behandelen. |
| Provinciale PQ, bronreeks 1981–2025 | 157 | Het lengtesignaal van minstens 22 tekens bewijst geen afkapping. Originele SRTNUM en tekst behouden, niets aanvullen door raden. Aantoonbaar onvolledige namen nog niet als volledige wetenschappelijke naam vastleggen; zo nodig voorlopig alleen een onopgeloste bronkoppeling. |
| Overige bijzondere naamvormen | 416 | Hybriden, verzamelcategorieën, onvolledige determinaties en ruime/enge naamgebruiken herkenbaar behouden; niet splitsen of automatisch gelijkstellen aan een gewone soort. |
| Afwijkende BGgroup-codes, referentietabel zonder eigen meetperiode | 3 | Groene specht, Tjiftjaf en Grauwe vliegenvanger voorlopig niet op de afwijkende EURING-code bevestigen. Bestaande naamkandidaten blijven kandidaten. |
| Toendrarietgans, soorten.id 647, referentie zonder eigen meetperiode | 1 | De wetenschappelijke bronnaam ontbreekt. Geen naam afleiden uit alleen de Nederlandse naam of EURING-code; bronkoppeling voorlopig zonder centraal doel. |

De 416 overige naamvormen komen uit NDFF (opgeslagen bronjaren 1700–2025),
PQ (1981–2025), Vangblik (1953–1960), SOVON/AVIMAP (2009–2026), Naturalis
Botany (1875–2025), ENDURE (2018), STOWA (1992–2010) en referentiecatalogi
zonder eigen meetperiode. Het NDFF-jaar 1700 is een opgeslagen intervalgrens,
geen bewijs voor een waarneming in dat jaar. Deze perioden beschrijven de
bronreeksen, niet afzonderlijk ieder gemarkeerd naamgebruik.

Over alle categorieën samen zijn er 502 syntactische naamvormsignalen:
218 combinaties, 101 hybride-aanduidingen zonder combinatie, 136 ruime
afbakeningen/verzamelgroepen, 16 enge afbakeningen en 31 onbepaalde
determinaties. Dit zijn beoordelingssignalen, geen 502 bewezen fouten.
De generator miste onder meer `sl`, `indet.`, `+`, `-groep` en een aansluitend
hybrideteken. Brongetrouwe registratie moet het verschil behouden tussen een
formeel taxon, hybride, aggregaat en operationele eenheid; een naamvorm alleen
bewijst geen taxonomische rang of biologische identiteit. Alleen `Indet.` is
geen bruikbare wetenschappelijke naam voor een nieuw centraal taxon.

Daarnaast blijven 2.875 primaire groepen leeg. Dat mag voor voorlopige
registratie; groepskandidaten op uitsluitend naam worden niet bevestigd.
De 24 naamgelijke regels met verschillende broncodes blijven afzonderlijk,
waaronder de twee `Elachista`-naamgebruiken. De 786 oude trait-goedkeuringen
worden niet omgezet in bevestigde taxonconceptrelaties. Catalogusregistratie
is geen bewijs van lokale aanwezigheid; dat blijft ook gelden voor de
ENDURE-afwezigheidscategorieën uit 2018.

Bewijs staat lokaal naast het ongewijzigde manifest in
`outputs/taxa-manifest-20260927.h2EugE/beoordeel_uitzonderingen.py` en
`beoordeling-categorieen.json`. De controle verifieert de manifesthash,
de sluitende categorie-indeling en de ongewijzigde invoer. Darwin Core en
TDWG TCS zijn opnieuw geraadpleegd: rang, taxonomische status, auteurschap,
naamgebruik en conceptrelatie blijven afzonderlijk. Geen afwijking voorgesteld.

Vervolg: eerst bovenstaande keuzes vaststellen, dan een volgende
manifestversie maken met behoud van UUIDs en letterlijke bronwaarden.
Daarna opnieuw controleren en pas vervolgens een afgebakende invoer met
ROLLBACK beproeven. Geen ROLLBACK-proef of definitieve invoer uitgevoerd.

## Invoermanifest overige taxa van 27 september 2026

Na de inventarisatie van alle 251 fysieke tabellen en 16 views is een
invoervoorstel gemaakt, niet uitgevoerd. De levende database bevat nog steeds
27 groepen, 263 voorlopige vogelnaamgebruiken en 263 kandidaat-bronkoppelingen.
De analytische toelatingsstatussen, metingen, applicaties en productie blijven
ongewijzigd. `Meijendel_bronnen` en de beveiligde NDFF-database zijn niet in
dit manifest opgenomen.

Het definitieve voorstel staat lokaal buiten Git in
`outputs/taxa-manifest-20260927.h2EugE/invoermanifest-v2.json`, met
`samenvatting-v2.json`, `uitzonderingen-v2.json`, `naamovereenkomsten.json`,
de bronextracties en `controleer_manifest.py`. De eerste manifestversie
blijft als auditspoor behouden; v2 behoudt alle oorspronkelijke UUIDs en
bronidentiteiten. De brongegevens zijn opnieuw live gelezen en inhoudelijk
gelijk aan de inventarisatie.

SHA-256 van het definitieve manifest:
`5e60222fcf308b672e339395e9318ec661a17aa78132f71cfb8565e8215e6137`.
De manifestcontrole en de bestaande live-acceptatiepoort voor vogels slagen.
Alle 251 fysieke tabellen hebben vóór en na deze voorbereiding dezelfde
rijtelling; de drie registertabellen zijn ook inhoudelijk ongewijzigd.
De bijgewerkte Wordversie van het bronregister is gerenderd en visueel
gecontroleerd.

Het voorstel bevat 14.401 nieuwe brongebonden naamgebruiken en 15.351
bronkoppelingen, geen telling van biologische soorten. De vier primaire
catalogi bevatten 9.828 NDFF-regels (opgeslagen jaren 1700–2025), 714
provinciale PQ-codes (1981–2025), 275 Vangblik-taxa (1953–1960) en 35
SOVON/AVIMAP-taxa (2009–2026). De zes externe datasets leveren 3.181
verschillende taxonomische bronweergaven (1875–2025 gezamenlijk): 785
Botany, 84 Coleoptera, 247 NMR, 628 ENDURE, 998 LVD en 439 STOWA. Het eerdere
inventarisatieaantal van 3.173 dataset/naamcombinaties was grover: nu blijven
ook zes oorspronkelijke Coleoptera-naamvarianten en twee extra ENDURE-
metadatavarianten afzonderlijk herkenbaar.

Daarnaast omvat het manifest 365 nog niet gekoppelde `soorten`-regels,
4 aanvullende protocolcategorieën, 786 kenmerkenkoppelingen en 163
functionele groepsreferenties uit `BGgroup`. De kenmerken en groepsreferenties
krijgen samen 949 kandidaatverwijzingen naar bestaande of voorgestelde
naamgebruiken, geen 949 nieuwe taxa. De bronvermelding `soorten.id=647`
(Toendrarietgans) heeft in de lokale soort-, taxon- en traitcatalogi geen
beschikbare wetenschappelijke naam en blijft zonder doeltaxon. Niets wordt
automatisch op EURING-code of naam bevestigd.

13.904 voorstellen zijn technisch voorbereid voor voorlopige brongetrouwe
registratie; 1.447 zijn apart gezet voor beoordeling vóór invoer. Dit is geen
inhoudelijke goedkeuring van de eerste groep. Onder de blokkades vallen
onbeoordeelde taxonvormen, mogelijk onvolledige PQ-namen, drie afwijkende
`BGgroup`-codes en de LVD-rangfout. Voor 2.875 bronvermeldingen blijft de
primaire groep nog leeg; 1.490 daarvan hebben uitsluitend op naam een
groepskandidaat. Geen nieuwe groepen voorgesteld.

De LVD-import zet bij 81.310 resultaten uit 1959–2015 de bronstatus ten
onrechte in `taxonrang`: 81.285 keer `accepted` (997 namen) en 25 keer
`synonym` (één naam, 1976–2013). Dit is teruggevonden in
`gis/scripts/import_external_ecology_sources.py`. Het manifest bewaart de
letterlijke waarde en status, maar laat de centrale rang leeg. De bestaande
importcode en bronlaag zijn niet gerepareerd. Het bronregister vermeldt deze
beperking in zowel Markdown als Word.

Standaardtoets opnieuw uitgevoerd op 27 september 2026:
[Darwin Core](https://dwc.tdwg.org/terms/) en
[TDWG TCS](https://tcs.tdwg.org/terms/), in het bijzonder scientificName,
scientificNameID, taxonRank, taxonomicStatus, nameAccordingTo en het
onderscheid tussen naamgebruik en conceptrelatie. Alle doelen blijven
`voorlopig`/`unresolved`, alle koppelingen kandidaat/onbekend of onbeoordeeld
zonder doel. Geen externe concept-ID, parentrelatie of synoniemrelatie
afgeleid; UUIDs zijn willekeurig en vastgelegd, niet uit namen berekend.
Een afgeleide bronsleutel is expliciet als zodanig gemarkeerd. De betekenis
van bronversie en het bronbestand met zijn hash blijven bewaard.

Vervolg: eerst de uitzonderingen en de invoerselectie besluiten. Daarna
acceptatiepoort uitbreiden, bronhashes en unieke identiteiten opnieuw
toetsen, back-up maken, dezelfde invoer met ROLLBACK beproeven en pas na
geslaagde controles toevoegend uitvoeren. Een gewijzigde bron of herhaalde
manifestinvoer moet vóór schrijven blokkeren. Geen kandidaatkoppelingen
gebruiken om waarnemingen op te tellen of afnemers om te schakelen.

## Uitvoeringsplan vogelnaamgebruiken 27 september 2026

Opdracht: doorgaan na de beoordeling van 58 gemarkeerde vogelcategorieën.
De brongetrouwe toevoeging betreft 263 gebruikte IDs uit `soorten`, niet een
vervanging van de vogeltabel of een nieuwe externe standaardtaxonomie.
Implementatie in `codex/taxonregister-vogels`; tijdelijke uitvoer en bewijs
blijven buiten Git in `outputs/vogel-taxoncontrole-20260927.timBzc/`.
Er worden geen nieuwe gevolgde bestanden gemaakt.

Standaardtoets, opnieuw geraadpleegd 27 september 2026:
[Darwin Core](https://dwc.tdwg.org/terms/) (`taxonID`, `scientificName`,
`nameAccordingTo`, `taxonConceptID`, `taxonRank`) en
[TDWG TCS](https://tcs.tdwg.org/terms/) (naamgebruik, concept en conceptrelatie).
De lokale broncatalogus en haar SHA-256 vormen de expliciete context. Eigen
UUIDs zijn naamonafhankelijk; bron-ID, bronversie en letterlijke bronvelden
blijven gescheiden. Externe concept-IDs, taxonrangen en parent-/synoniemrelaties
worden niet afgeleid. Beheerstatus `voorlopig`, taxonomische status
`unresolved`, koppelstatus `kandidaat`, relatie `onbekend`.
Geen afwijking van de afgesproken basisstructuur.

### Uitvoering en acceptatie

- [x] Voeg eerst de alleen-lezen acceptatiepoort `--fase vogels` toe aan
  `gis/scripts/test_taxonregister_live_schema.py`; de poort moet vóór invoer
  falen doordat de 263 naamgebruiken en koppelingen nog ontbreken.
- [x] Genereer een vast manifest met 263 UUIDs, oorspronkelijke bronvelden,
  afzonderlijke taxonvormen en de 58 beoordelingen. IJsgors krijgt in het
  nieuwe register `Calcarius lapponicus`, Ringsnaveleend `Aythya collaris`;
  de oude cataloguswaarden blijven ongewijzigd en letterlijk bewaard.
- [x] Maak een gecontroleerde logische back-up en voer hetzelfde invoerrecept
  eerst uit met ROLLBACK. Controleer lege doelen, juiste lokale server,
  bronhash, uitsluitend de gebruikte vogel-ID’s, geen triggers en geen
  externe inkomende relaties; blokkeer bij afwijkingen of herhaalde invoer.
- [x] Voeg daarna uitsluitend de 263 taxa en 263 kandidaatkoppelingen toe
  in één transactie, met SQL-voorwaarden vóór COMMIT en verificatie daarna.
- [x] Bewijs behoud van alle overige tabellen en geëxporteerde objecten met
  identieke deterministische exports, en controleer de volledige vogelpanels,
  tellingen, bronmetadata en een één-op-één-koppelproef. Pas geen afnemers aan.
- [x] Werk bestaande status-, besluit- en brondocumentatie bij, voer relevante
  regressiecontroles en onafhankelijke review uit, en commit/push/integreer.

Terugdraaien is beperkt tot exact de manifest-UUIDs en hun kandidaatbesluiten,
na vergelijking van de volledige toegevoegde rijen en controle op nieuwe
verwijzingen. Geen globale DELETE, DROP of herstel van de volledige database.
De productiedump, caches en VPS worden in deze stap niet vernieuwd.

Reviewfocus: naamsconflicten niet samenvoegen; oorspronkelijke NULL/spaties en
alle talen bewaren; kandidaten niet als exact gebruiken; herhaalde/gewijzigde
invoer weigeren; transactie bij iedere fout afbreken vóór COMMIT.

Stand: 27 september 2026. De drie fysieke tabellen staan in de levende lokale
database `Meijendel`: 27 praktische groepen, 263 voorlopige vogelnaamgebruiken
en 263 kandidaat-bronkoppelingen. Geen extra database, views, verplaatsing van
waarnemingen of aansluiting van applicaties.
De oorspronkelijke structuurstap en het controlebewijs blijven hieronder
herkenbaar bewaard; de groepsvulling staat in de laatste sectie.
Het eerdere voorstel om
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
werkelijk aangemaakte schema en de afgesproken inhoud; zij voegt geen
proefrecords toe. `--fase leeg` toetst de oorspronkelijke structuurstap;
`--fase groepen` toetst de historische tussenstand met 27 groepen en lege
taxa/bronkoppelingen. `--fase vogels` is nu standaard en toetst daarnaast de
263 voorlopige vogelnaamgebruiken en hun afzonderlijke bronkandidaten.
Een volgende import vereist een bijbehorende uitbreiding van deze acceptatiepoort.

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

Voor de oorspronkelijke lege structuurstap mocht een eventuele terugdraaiing
uitsluitend de drie nieuwe tabellen betreffen,
in afhankelijkheidsvolgorde: bronkoppeling, taxa, groepen. Eerst aantonen dat ze
nog leeg zijn en geen externe verwijzingen hebben; uitvoering vereist een
afzonderlijk besluit. Nooit hiervoor de volledige database terugzetten, want
dat zou intussen toegevoegde gegevens kunnen vernietigen. Deze leegtevoorwaarde
is inmiddels niet meer vervuld. Voor de vogelinvoer geldt uitsluitend de
hierboven beschreven, recordgerichte terugdraaiing na afzonderlijk besluit.

## Uitkomst vogelinvoer, 27 september 2026

Om 17:16 lokale tijd zijn 263 naamgebruiken en 263 kandidaten in één
transactie toegevoegd. De acceptatiepoort `--fase vogels` is geslaagd.
De 263 broncategorieën blijven afzonderlijk: 251 met taxonvorm `taxon`,
7 operationele eenheden, 3 aggregaten en 2 hybriden. `taxon` is hier geen
uitspraak dat de rang soort bewezen is; rang en externe concept-ID blijven
leeg. Alle 263 naamgebruiken zijn `voorlopig/unresolved`; alle 263 koppelingen
zijn `kandidaat/onbekend`, zonder actieve exacte toewijzing.

| Gecontroleerde brontabel | Regels | Periode | Gebruikte broncategorieën | Som telwaarden |
| --- | ---: | --- | ---: | ---: |
| `territoria` | 71.155 | 1958–2025 | 159 | 495.208 |
| `dagwaarnemingen_bmp` | 600.959 | 2007–2025 | 203 | 621.226 |
| `dagwaarnemingen_wv` | 105.712 | 2000–2025 | 238 | 737.310 |

Deze drie verzamelingen gebruiken samen 263 verschillende bron-IDs. Alle
rijaantallen, sommen, nullen, ontbrekende waarden en volledige
plot–soort–jaarpanels zijn behouden. De 628 catalogusregels en hun acht
bronvelden, traitkoppelingen en bestaande taxonextracties zijn eveneens gelijk.
De koppelproef vermenigvuldigt geen waarnemingen. Zij bewijst bronherleidbaarheid,
niet gelijkheid met een extern taxonconcept of analytische samenvoegbaarheid.

De deterministische exports van alle overige 249 fysieke tabellen plus
geëxporteerde views, routines, events en triggers zijn bytegelijk vóór en na
invoer. SHA-256 van beide gzipbestanden:
`907d30aa737a4f417e7a3b1305fcfad263de4fb0c265c0eabd2d4f74ce713d09`.
Dit omvat ook de ongewijzigde 27 groepen, PQ, Vangblik, externe ecologie en
NDFF. Website, dashboard, Shiny, publicatiedump en caches zijn niet aangepast;
er is geen applicatie- of VPS-rooktest uitgevoerd of daarmee geclaimd.

Bewijs staat lokaal in `outputs/vogel-taxoncontrole-20260927.timBzc/`:

- `vogelinvoer-register-voor.sql.gz` en `vogelinvoer-overig-voor.sql.gz`:
  gecontroleerde logische back-up; gzip-integriteit en hashes vastgesteld.
- `vogelinvoer_manifest.json`: 263 bronrecords en vaste nieuwe UUIDs;
  SHA-256 `5ec7657dc76605e7ad865cf68b1c3e47c0992b74cff90ef4beb1070f797a10ca`.
- `vogelinvoer_transactie.sql`: begrensde toevoeging met controles vóór COMMIT;
  SHA-256 `155b265f29113b5f31b822ad8ab435edd200a2cb35f4b56c8c7ececcd9bd4f86`.
- `vogelinvoer_rehearsal.json` en `vogelinvoer_apply.json`: geslaagde
  rollbackproef en daaropvolgende invoer met hetzelfde manifest en SQL.
- `vogelinvoer_eindcontrole.json` en `vogelinvoer-overig-na.sql.gz.json`:
  behoud van de volledige extracties en overige databaseobjecten.

Onafhankelijke review vond geen kritieke of belangrijke bevindingen. De kleine
aanbeveling om naast hashes/exitcode ook proefmodus, ROLLBACK en validatiemarker
te eisen, is vóór COMMIT verwerkt en met een eerst falende regressietest
geverifieerd. Zeven schemacontracttests en beide exporttests slagen.

Herhaalde invoer is ook na COMMIT beproefd met uitsluitend de voorafgaande
poort: MySQL blokkeert bij de eis dat beide doeltabellen leeg zijn, vóór enige
permanente INSERT. Het bronregister is in Markdown en Word inhoudelijk gelijk;
alle 19 gerenderde Wordpagina’s zijn visueel gecontroleerd.

De eerstvolgende inhoudelijke stap is beoordeling van de kandidaten tegen
expliciet geversioneerde externe naamgebruiken/concepten. Bij nieuwe besluiten
blijft de bronidentiteit gelijk, blijft het oorspronkelijke besluit bewaard
en moet de richting van een eventuele conceptrelatie onderbouwd zijn. Alleen
naamovereenkomst is geen grond om de 263 kandidaten als exact te bevestigen.

## Uitvoeringslog eerste, lege structuurstap

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

## Vervolg op de lege structuurstap

Pas na deze structuurstap beoordelen we met de bestaande databasegegevens
welke groepen, taxa en bronkoppelingen passen. Dan volgen ook proeven voor
homoniemen, synoniemen, taxonsplitsingen, onopgeloste codes, bronversies en
dubbeltellingen. Hiërarchiecycli, zelfverwijzingen, synoniemketens,
metadata-consistentie en conceptwijzigingen moeten vóór import expliciet
worden getoetst: foreign keys bewijzen alleen dat een doel bestaat, niet dat
de taxonomische relatie inhoudelijk klopt. De onderstaande vervolgstap vult
alleen de groepscatalogus; taxon- en koppelproeven bleven in die tussenstap
uitgesteld. De inmiddels uitgevoerde vogelinvoer staat bovenaan dit document.

## Groepscatalogus v1: uitgevoerd op 27 september 2026

Opdracht van 27 september 2026: vul uitsluitend `taxon_groepen` en leg Darwin
Core en TDWG TCS vast als blijvende toetsingsbasis. De centrale afspraak staat
in `../../../VWG_Project/workflow.md`, sectie `Darwin Core en TDWG TCS als
verplichte toetsingsbasis`. Afwijkingen vereisen vooraf expliciete goedkeuring
door Ton. Alle drie repository-instructies verwijzen naar die afspraak.

De vulling gebruikt de 26 bestaande groepscodes plus `vogels`: 27 praktische
groepen, stand 27 september 2026, zonder waarnemingsperiode. Ze zijn geen
vastgestelde lijst van soorten en bewijzen geen lokale aanwezigheid. Geen
bovenliggende groepen worden ingevuld: dit is een vlakke gebruikscatalogus,
geen taxonomische stamboom. Groepscodes zijn brononafhankelijk en blijven
stabiel als de weergavenaam later preciezer wordt. Dezelfde groepen kunnen
rechtstreekse leveringen en bestaande NDFF-, PQ-, Vangblik- of andere bronnen
ontsluiten, maar deze stap wijst nog geen taxon of bronrecord toe.

De huidige 26 codes zijn opnieuw gecontroleerd in
`ndff_open_soortgroep_koppeling`; samengestelde bronlabels worden niet als
nieuwe groep ingevoerd. Bestaande overlap tussen korstmossen/schimmels en
kreeftachtigen/overige geleedpotigen blijft ongemoeid. Vogels krijgt alleen een
catalogusrij, geen wijziging van `soorten`. PQ en Vangblik zijn meetstructuren,
geen taxon_groepen. De gegevensstatus van bestaande bronnen verandert niet;
het bronregister hoeft voor deze catalogusvulling niet te worden herzien.

Standaardtoets (27 september 2026):

- [Darwin Core](https://dwc.tdwg.org/terms/) beschrijft onder meer taxonRank,
  taxonomicStatus, scientificName en nameAccordingTo. Geen groepscode wordt
  als waarde van die velden gebruikt. Dit is een lokale gebruiksindeling.
- [TCS](https://tcs.tdwg.org/terms/) onderscheidt naam, taxonconcept en relaties
  tussen concepten. De vulling schept geen taxonconcepten, rangrelaties of
  equivalenties; de bestaande structuur en broncontext blijven behouden.
- Er is geen afwijking van de vastgelegde basisstructuur nodig en er wordt
  geen volledige standaardconformiteit van bestaande brongegevens geclaimd.

### Reproduceerbare vulling

Onderstaande SQL is het uitvoeringsrecept; het bestaande
`taxonregister_schema.sql` blijft uitsluitend de historische lege DDL-stap.
Voer niet opnieuw uit op een gevulde catalogus. De preflight vereist de
verwachte lokale serveridentiteit, drie lege registertabellen, geen triggers
op de groepentabel en een gecontroleerde back-up. Eén INSERT binnen een
transactie vult de catalogus zonder bestaande rijen te wijzigen. Laat de
MySQL-client bij fouten stoppen (geen `--force`).

```sql
-- Groepscatalogus v1; eenmalig, uitsluitend op de vooraf leeg gecontroleerde tabel.
-- Geen schemawijziging, UPDATE, DELETE, taxa-import of bronkoppeling.
SET NAMES utf8mb4;
START TRANSACTION;
INSERT INTO taxon_groepen
  (groep_code, groep_naam, omschrijving, sorteervolgorde,
   indeling_bron, indeling_versie, groepmetadata)
SELECT code, naam, omschrijving, volgorde,
  'Meijendel/docs/database/MEIJENDEL_TABELINVENTARIS.md (2026-09-26); bestaande lokale groepscodes, aangevuld met vogels; semantische toets aan Darwin Core en TDWG TCS',
  'meijendel-soortgroepen-v1',
  JSON_OBJECT('indelingstype','praktische_soortgroep',
    'standaardtoets_datum','2026-09-27',
    'toetsingsbasis',JSON_ARRAY('https://dwc.tdwg.org/terms/','https://tcs.tdwg.org/terms/'))
FROM (
  SELECT 'vogels' AS code, 'Vogels' AS naam, 'Vogels; groepslabel voor het register, zonder wijziging of koppeling van de bestaande vogeltabel.' AS omschrijving, 10 AS volgorde
  UNION ALL
  SELECT 'amfibieen', 'Amfibieën', 'Amfibieën; reptielen blijven een afzonderlijke gebruiksgroep.', 20
  UNION ALL
  SELECT 'dagvlinders', 'Dagvlinders', 'Praktische dagvlindergroep; niet alle overdag actieve vlinders.', 30
  UNION ALL
  SELECT 'eencelligen', 'Eencelligen', 'Praktische verzamelgroep voor als eencelligen beschreven bronregistraties; geen formeel rijk.', 40
  UNION ALL
  SELECT 'geleedpotigen_overig', 'Overige geleedpotigen', 'Overige geleedpotigen buiten de specifiekere gebruiksgroepen; brondubbellabels niet automatisch overnemen.', 50
  UNION ALL
  SELECT 'insecten_overig', 'Overige insecten', 'Overige insecten buiten de benoemde insectengroepen; onbekende determinaties blijven afzonderlijk beoordeelbaar.', 60
  UNION ALL
  SELECT 'kevers', 'Kevers', 'Kevers, inclusief latere herkenbaarheid van collectiestukken en Vangblik; geen kopie van vangsten.', 70
  UNION ALL
  SELECT 'korstmossen', 'Korstmossen', 'Korstmossen als praktische gebruiksgroep; formele taxonomie en eventuele overlap met schimmellabels apart bewaren.', 80
  UNION ALL
  SELECT 'kranswieren_wieren_algen', 'Kranswieren, wieren en algen', 'Praktische verzamelgroep; geen gezamenlijk formeel rijk veronderstellen.', 90
  UNION ALL
  SELECT 'kreeftachtigen', 'Kreeftachtigen', 'Kreeftachtigen; mogelijke bronoverlap met overige geleedpotigen later op taxonniveau beoordelen.', 100
  UNION ALL
  SELECT 'libellen', 'Libellen en juffers', 'Libellen in brede zin, inclusief juffers; stabiele groepscode libellen.', 110
  UNION ALL
  SELECT 'microvlinders', 'Microvlinders', 'Praktische microvlindergroep naast dagvlinders en nachtvlinders; geen formele taxonomische rang.', 120
  UNION ALL
  SELECT 'mossen', 'Mossen en levermossen', 'Mossen in brede praktische zin, inclusief levermossen en hauwmossen; formele indeling blijft bij het taxon.', 130
  UNION ALL
  SELECT 'nachtvlinders', 'Nachtvlinders', 'Bestaande nachtvlindergroep naast de afzonderlijke microvlindergroep; activiteitstijd bepaalt de toewijzing niet.', 140
  UNION ALL
  SELECT 'ongewervelden_overig', 'Overige ongewervelden', 'Overige ongewervelden buiten de afzonderlijke gebruiksgroepen, bijvoorbeeld wormen.', 150
  UNION ALL
  SELECT 'reptielen', 'Reptielen', 'Reptielen als praktische gebruiksgroep; amfibieën en vogels blijven afzonderlijk.', 160
  UNION ALL
  SELECT 'schimmels', 'Paddenstoelen en schimmels', 'Paddenstoelen en overige schimmels; korstmossen hebben een eigen gebruiksgroep, bronlabels blijven behouden.', 170
  UNION ALL
  SELECT 'snavelinsecten', 'Snavelinsecten', 'Snavelinsecten, waaronder wantsen, cicaden en bladluizen.', 180
  UNION ALL
  SELECT 'spinachtigen', 'Spinachtigen', 'Spinachtigen, waaronder spinnen, hooiwagens en mijten; niet beperken tot spinnen.', 190
  UNION ALL
  SELECT 'sprinkhanen_en_krekels', 'Sprinkhanen en krekels', 'Sprinkhanen en krekels als afzonderlijk herkenbare gebruiksgroep.', 200
  UNION ALL
  SELECT 'vaatplanten', 'Vaatplanten', 'Vaatplanten, inclusief zaadplanten en varens; PQ-metingen blijven in de PQ-structuur.', 210
  UNION ALL
  SELECT 'vissen', 'Vissen', 'Vissen als praktische gebruiksgroep; geen vaste formele klasse opleggen.', 220
  UNION ALL
  SELECT 'vleermuizen', 'Vleermuizen', 'Vleermuizen als afzonderlijke gebruiksgroep; de overige zoogdieren staan apart.', 230
  UNION ALL
  SELECT 'vliegen_en_muggen', 'Vliegen en muggen', 'Vliegen en muggen als gezamenlijk herkenbare gebruiksgroep.', 240
  UNION ALL
  SELECT 'vliesvleugeligen', 'Vliesvleugeligen', 'Vliesvleugeligen, waaronder bijen, wespen en mieren.', 250
  UNION ALL
  SELECT 'weekdieren', 'Weekdieren', 'Weekdieren, waaronder slakken en tweekleppigen.', 260
  UNION ALL
  SELECT 'zoogdieren_overig', 'Overige zoogdieren', 'Zoogdieren buiten de afzonderlijke vleermuizengroep; inclusief latere herkenbaarheid van Vangblik-taxons.', 270
) AS catalogus;
SELECT ROW_COUNT() AS ingevoegde_groepen;
COMMIT;
```

Historische controle, destijds geslaagd:
`python3 gis/scripts/test_taxonregister_live_schema.py --fase groepen`.
Gebruik voor de huidige stand `--fase vogels`. Zowel `--fase leeg` als
`--fase groepen` hoort na de vogelinvoer te falen; deze poorten bewaren de
voorwaarden van eerdere tussenstappen. Alle controles zijn alleen-lezen.

De daadwerkelijke INSERT heeft 27 rijen toegevoegd; de alleen-lezen
groepscontrole slaagde toen. De back-up van de vooraf lege tabel en de exports voor
de vergelijking staan in `outputs/taxongroepen-20260927.WpDeqd/` (lokaal,
buiten Git). De overige 250 basistabellen, 16 views en overige geëxporteerde
objecten zijn vóór/na byte-identiek (`cmp` geslaagd). Beide gecomprimeerde
exports hebben SHA-256:
`cf156b58b32700d9a7d6636477193f6652e732f90ea1daf4e795f54f8c9e955f`.
Dit omvat ook de destijds nog lege `taxa` en `taxa_bronkoppeling`. De 7 bestaande
schemacontracttests en de 2 exporttests zijn opnieuw geslaagd. Geen
applicatiecode, publicatiedump, cache of VPS gewijzigd; geen nieuwe
functionele website- of Shiny-gebruikerstest uitgevoerd.

De eerder beschreven terugdraaiing van drie lege tabellen is nu niet meer
toepasselijk: `taxon_groepen` bevat gegevens. Terugdraaien vereist opnieuw een
expliciet besluit en controle op eventuele nieuwe verwijzingen; nooit een
volledige databaseherstelactie voor alleen deze catalogusvulling.
