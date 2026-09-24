# Ontwerp: Meijendel strikt analytisch en Meijendel_bronnen

**Datum:** 24 september 2026  
**Status:** ter goedkeuring  
**Betrokken repositories:** `Meijendel`, `VWG_M`, `VWG_Project`

## Besluit en doel

De levende database `Meijendel` wordt strikt analytisch. Een ecologische
waarneming mag daar alleen in staan als per waarneming vaststaat dat zij in
Meijendel is gedaan en de locatie beschikbaar is of betrouwbaar kan worden
herleid.

Er komt een afzonderlijke MySQL-database `Meijendel_bronnen`. Deze bewaart:

1. gestructureerde ecologische gegevens die inhoudelijk over Meijendel gaan,
   maar niet op waarnemingsniveau geografisch herleidbaar zijn;
2. kandidaatbronnen die mogelijk later alsnog geografisch kunnen worden
   gekoppeld;
3. een literatuuroverzicht uit de Zotero-collectie `Meijendel`.

`Meijendel_bronnen` wordt als afzonderlijke broncatalogus beschikbaar in het
afgeschermde Analysecentrum. De tegel `Literatuur` verdwijnt uit het
ledenarchief. Bestaande archiefdocumenten worden daarbij niet verwijderd.

## Waarom twee databases

Een verzameling tabellen binnen `Meijendel` zou de scheiding vooral in namen
uitdrukken. Een afzonderlijke database maakt de regel technisch afdwingbaar:

- analyses en analyseviews lezen standaard alleen `Meijendel`;
- brongegevens kunnen niet ongemerkt in trends, verspreidingskaarten of
  modellen terechtkomen;
- de website kan de broncatalogus met een afzonderlijk read-only recht tonen;
- een bron kan later gecontroleerd naar `Meijendel` worden gepromoveerd als de
  locatie alsnog betrouwbaar wordt vastgesteld.

## Huidige gegevens die onder de nieuwe regel vallen

De eerste migratie omvat volledige bronfamilies, niet alleen losse regels.

| Bronfamilie | Omvang en periode | Bestemming | Reden |
|---|---:|---|---|
| Duinvallei-vegetatie | 488 opnamen, 101.504 bedekkingsregels en 855 bodemmetingen uit 2001, 2008 en 2018 | `Meijendel_bronnen` | de opnamen hebben benoemde locaties, maar geen per opname betrouwbaar herleidbare geometrie |
| Vogelstand 1924 | 204 regels uit 1924 | `Meijendel_bronnen` | historische Meijendel-context zonder locatie per waarneming |
| Jachtspinnen | 3.337 gevangen exemplaren, 12 soorten en 28 genummerde locaties uit 1969–1970 | `Meijendel_bronnen` | de 28 locatienummers zijn nog niet naar werkelijke locaties te vertalen |

Voor de definitieve migratie wordt eerst een reproduceerbare audit over alle
waarnemingstabellen uitgevoerd. Bovenstaande drie bronfamilies zijn de reeds
vastgestelde gevallen; de lijst wordt niet als volledig verondersteld zonder
die audit.

Referentietabellen zonder eigen Meijendel-waarnemingen, zoals soorten,
protocollen, kenmerken en landelijke referentietrends, blijven in `Meijendel`
wanneer zij nodig zijn voor geldige analyses. De ruimtelijke toelatingsregel
geldt voor waarnemingsfeiten, niet automatisch voor dimensie- en
referentietabellen.

## Datamodel van Meijendel_bronnen

### 1. Centrale catalogus

`bron` bevat voor iedere dataset of publicatie minimaal:

- stabiele `bron_id`;
- type: `dataset`, `literatuur` of `kandidaatbron`;
- titel en korte omschrijving;
- bronorganisatie en herkomst;
- begin- en eindjaar;
- betrokken soortgroep of onderwerp;
- geografische status en uitleg waarom opname in `Meijendel` niet is
  toegestaan;
- analytische status: `context_alleen`, `kandidaat` of `gepromoveerd`;
- rechten- en toegankelijkheidsstatus;
- DOI, publieke URL of andere duurzame verwijzing;
- bronbestandnaam, bestandstype, recordaantal en SHA-256 waar van toepassing;
- datum van invoer en regelversie.

Absolute lokale paden naar de T7, NAS of thuismap worden niet op de VPS
gepubliceerd. De catalogus bewaart alleen een opslagklasse, bestandsnaam en
controlehash.

### 2. Gestructureerde brondata

Bronfamilies behouden hun eigen genormaliseerde tabellen en relaties. De
duinvalleitabellen worden daarom als complete familie overgezet, inclusief
importbatch, plots, opnamen, taxa, bedekkingen en bodemmetingen. Ook de twee
bestaande duinvallei-views worden als contextviews opnieuw opgebouwd.

De jachtspinmatrix wordt als gestructureerde contextdataset opgenomen met de
oorspronkelijke locatienummers. Die nummers worden niet als geografische
locaties gepresenteerd.

### 3. Literatuur uit Zotero

De VPS krijgt geen Zotero-database, PDF's, boeken of andere bijlagen. Alleen
bibliografische metadata uit de Zotero-collectie `Meijendel` wordt
gesynchroniseerd:

- Zotero-itemkey en, indien aanwezig, citation key;
- titel, auteurs in vaste volgorde en publicatiejaar;
- publicatietype, tijdschrift of boektitel, uitgever;
- volume, nummer en pagina's;
- DOI, URL en raadpleegdatum;
- trefwoorden, soortgroep en behandelde periode voor zover aanwezig;
- een vooraf gegenereerde Chicago-verwijzing.

Voor het overzicht wordt standaard **Chicago Manual of Style 17th edition,
notes and bibliography** gebruikt. De gerenderde verwijzing wordt naast de
gestructureerde velden bewaard, zodat zij op de VPS leesbaar blijft zonder
toegang tot de Zotero-installatie op de NAS. De synchronisatie is een
eenrichtingsimport vanuit Zotero; de website wijzigt Zotero nooit.

## Analysecentrum

Er komt een afzonderlijke pagina `/analysecentrum/bronnen`, bereikbaar voor
dezelfde ingelogde leden en externe onderzoekers die het Analysecentrum mogen
gebruiken.

De startpagina krijgt de knop **Meijendel_bronnen** met een expliciete
toelichting: contextdata en literatuur, niet automatisch geschikt voor
statistische analyse.

De bronnenpagina biedt:

- zoeken en filteren op titel, auteur, jaar, soortgroep, onderwerp en brontype;
- een literatuuroverzicht met Chicago-verwijzingen en publieke DOI/URL;
- een overzicht van contextdatasets met omvang, periode, geografische en
  analytische status;
- detailweergaven en alleen waar rechten dit toestaan een gecontroleerde CSV-
  download.

De pagina gebruikt de bestaande read-only MySQL-verbinding van de website,
maar met een afzonderlijke databasenaam en uitsluitend `SELECT` op vastgelegde
views. Het gewone analyse-account krijgt geen schrijfrechten. Shiny en de
statistische dashboardketen blijven uitsluitend uit `Meijendel` lezen.

## Wijziging ledenarchief

De categorie `Literatuur` verdwijnt uit:

- de tegelweergave van het archief;
- het zoekfilter;
- het uploadformulier;
- de omschrijving van het archief op de ledenpagina.

De categoriecode en bestaande documenten blijven intern bestaan, zodat geen
archiefmateriaal wordt verwijderd en oude directe links controleerbaar blijven.
Nieuwe literatuurregistraties lopen uitsluitend via Zotero en
`Meijendel_bronnen`.

## Migratie en kwaliteitscontrole

De uitvoering gebeurt in deze volgorde:

1. audit alle waarnemingstabellen in `Meijendel` op geografische
   herleidbaarheid per record;
2. maak `Meijendel_bronnen` en de catalogus- en literatuurtabellen;
3. kopieer complete bronfamilies en controleer aantallen, relaties en hashes;
4. importeer de jachtspinmatrix en de Zotero-metadata;
5. herstel beide databases in een tijdelijke omgeving en test alle views;
6. pas website, rechten, back-up en deployketen aan;
7. verwijder pas daarna de succesvol overgezette bronfamilies uit
   `Meijendel`;
8. genereer en valideer afzonderlijke dumps voor `Meijendel` en
   `Meijendel_bronnen`;
9. voer de volledige lokale testset, VPS-preflight en productiesmoketest uit.

De migratie blokkeert wanneer bron- en doelaantallen, foreign keys of hashes
niet overeenkomen. Er wordt niets uit `Meijendel` verwijderd voordat de
hersteltest van `Meijendel_bronnen` slaagt.

## Dump, back-up en productie

- `Meijendel.sql` blijft de strikt analytische dump.
- `Meijendel_bronnen.sql` wordt een afzonderlijke, niet-publieke dump.
- De bestaande publieke routes `/Meijendel.sql` en `/meijendel.sql` publiceren
  nooit `Meijendel_bronnen.sql`.
- De MySQL-productiecontainer bevat beide databases, maar met gescheiden
  rechten.
- Back-up, hersteltest en release-manifest rapporteren beide databases
  afzonderlijk.
- De T7 blijft de duurzame opslagplaats voor grote oorspronkelijke
  bronbestanden; de database bevat de normalisatie en controlemetadata.

## Tests en acceptatiecriteria

De wijziging is gereed wanneer aantoonbaar geldt:

1. alle geauditeerde niet-lokaliseerbare waarnemingsfeiten staan niet meer in
   `Meijendel` en wel volledig in `Meijendel_bronnen`;
2. analyses, Shiny en dashboard blijven functioneren en lezen geen
   broncontext;
3. `Meijendel_bronnen` toont per dataset de reden waarom zij niet als gewone
   analysebron geldt;
4. Zotero-verwijzingen zijn in Chicago-stijl leesbaar zonder NAS- of
   Zotero-toegang en bevatten geen attachments of lokale paden;
5. alleen geauthenticeerde Analysecentrumgebruikers bereiken de bronnenpagina;
6. de literatuurtegel, het literatuurfilter en de uploadkeuze zijn uit het
   ledenarchief verdwenen, terwijl bestaande bestanden behouden blijven;
7. beide dumps kunnen afzonderlijk worden hersteld en hun aantallen en hashes
   komen overeen met de gevalideerde lokale databases;
8. documentatie, release-manifest en werkinstructies beschrijven de nieuwe
   scheiding eenduidig.

## Niet in deze wijziging

- Het publiceren of kopiëren van Zotero-bijlagen en volledige teksten.
- Het alsnog geografisch reconstrueren van de 28 jachtspinlocaties.
- Het opnemen van ruwe beveiligde NDFF-geometrie in `Meijendel_bronnen`.
- Het automatisch promoveren van een bron naar `Meijendel`.

Promotie vereist later een afzonderlijk, vastgelegd besluit en bewijs dat de
locatie per waarneming betrouwbaar beschikbaar of herleidbaar is.
