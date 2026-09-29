# Taxonregister: structuur en uitvoering

## Alle waarnemingen vanuit het centrale taxonregister

Bindende opdracht Ton, 29 september 2026: alle soortwaarnemingen zijn vanuit
`taxa` via `taxa_bronkoppeling` vindbaar, met de indeling in `taxon_groepen`.
Dit omvat oorspronkelijke waarnemingen, afgeleide meetregels en echte nullen.
Geen afzonderlijke taxoncatalogus is de ingang. Een naamregistratie zonder
werkende verbinding naar de waarneming voldoet niet. Bij iedere databasewijziging
wordt de volledige verbinding gecontroleerd. Deze opdracht is op 29 september
2026 volledig lokaal uitgevoerd en gecontroleerd. Er is niets naar de VPS gepubliceerd.

### Ontwerp en uitvoeringsplan

Doel: bestaande bronwaarden en identificaties behouden, de ontbrekende expliciete
verbindingen aanvullen en hernieuwde ontkoppeling blokkeren. De implementatie
blijft in de bestaande importmodule, bestaande tests en bestaande live-controlepoort.
Geen nieuwe views, geen VPS-publicatie en geen verplaatsing van PQ-bronopnamen
als onderdeel van deze voorafgaande taxonkoppeling.

- [x] Alle fysieke soort-/waarnemingslagen, bestaande sleutelroutes, afgeleide
  meetregels en import-/exportschrijvers inventariseren; onbekende nieuwe lagen
  moeten de controlepoort laten falen.
- [x] Een complete sleutelkaart opstellen. Nieuwe waarnemingsverwijzingen gebruiken
  `taxon_bronkoppeling_id`, met foreign key, index en verplichte integriteitscontrole.
  Bestaande vogel-ID-routes blijven behouden. Afgeleide bronidentiteiten bevatten
  de reconstructieversie en oorspronkelijke naamcontext; geen fuzzy match.
- [x] Niet-geïdentificeerd bronmateriaal als zodanig bereikbaar houden, zonder
  biologische soort, rang of conceptgelijkheid te verzinnen. De originele
  onbeoordeelde beslissing en bronmetadata blijven bewaard.
- [x] Queryhelpers starten bij `taxa`; een LEFT JOIN met `taxon_groepen` bewaart
  ook de nog niet ingedeelde taxa. Alle bronlagen worden met herkomst afzonderlijk
  teruggegeven; bronregels en afgeleide nullen worden niet bij elkaar opgeteld.
- [x] Tests eerst laten falen bij ontbrekende verbinding, fout doel, gewijzigde
  bronidentiteit, groeps-NULL, duplicatie, nieuwe onbekende tabel en historische versie.
  Daarna de kleinste volledige implementatie en invoerborging toevoegen.
- [x] Verse volledige back-up, identieke proefdatabase, transactionele rollback,
  schemaherstel en volledig herstel uit de back-up bewijzen. Alle oorspronkelijke
  cellen, geometrieën, meetwaarden, bronmetadata en bestaande viewuitkomsten vergelijken.
- [x] Alleen dezelfde bewezen code en dezelfde bronstand lokaal toepassen;
  aansluitend alle centrale routes, schrijvers en bestaande afnemers controleren.
- [x] Bronregister in Markdown en Word, besluiten, status en TODO actualiseren;
  onafhankelijke review, regressietests, commit/push/merge en workspace-preflight.

Toetsingsbasis: op 29 september 2026 geraadpleegd:
[Darwin Core](https://dwc.tdwg.org/terms/) en [TDWG TCS](https://tcs.tdwg.org/).
Waarneming, identificatie, naamgebruik, taxonconcept en bronbesluit blijven gescheiden.
Een centrale sleutel bevestigt geen historische conceptgelijkheid of analysetoelating.

### Uitvoering en bewijs

De oorspronkelijke waarnemingslagen zijn volledig onderzocht. Vogeltellingen
lopen via de bestaande sleutel naar `soorten`, openbare NDFF-regels via
`ndff_soorten`, en AVIMAP via zijn samengestelde bronsleutel. Deze drie bestaande
catalogi krijgen een vaste centrale bronkoppeling. PQ en Vangblik hadden die
verwijzing al. Externe bronresultaten en afgeleide soortmetingen krijgen haar
ook. De broncodes blijven staan. Een query begint bij `taxa`, niet bij een van
deze oude catalogi.

De eerste herstelproef heeft twee beveiligingsgaten zichtbaar gemaakt: een
bestaande maar verkeerde bronkoppeling moest worden geweigerd, en wijzigingen
van de bovenliggende dataset mochten de herkomst niet stilzwijgend veranderen.
Beide zijn aangescherpt en met schrijfproeven gecontroleerd. Ook verwijzingen
naar een niet-bestaande NDFF-waarneming worden geweigerd. De levende database
is pas na de volledige eindproef en onafhankelijke review gewijzigd. De lokale
nacontrole is geslaagd: alle 122 beoordeelde routes zijn bereikbaar, zonder
ontbrekende verbindingen of vermenigvuldiging van soortregels. Alle oorspronkelijke
cellen en schema-eigenschappen en alle 16 bestaande viewuitkomsten zijn behouden.

De lokale stand is nu 27 groepen, 11.660 centrale vermeldingen en 30.035
bronkoppelingen. Het register heeft geen eigen waarnemingsperiode. De 11.659
bestaande centrale vermeldingen en alle 24.561 eerdere bronkoppelingen zijn
ongewijzigd bewaard. Er zijn 5.473 brongebruiken voor afgeleide meet-/doelsoortregels
toegevoegd en één uitdrukkelijk onbepaald operationeel registerobject met zijn
bronkoppeling voor het Naturalis Botany-collectieobject uit 2018. Dit laatste
is geen nieuwe biologische soort. De 235 nog niet ingedeelde naamvermeldingen
en dit operationele object blijven via de LEFT JOIN bereikbaar. Alle
weergavenamen zijn gevuld en uniek. 242 rijtriggers beschermen de centrale
bronidentiteit, versie en verwijzingen. Het levende bewijs staat onder
`live/result.json` in de herstelmap hieronder.

De 27 bestaande GIS-regressietestbestanden zonder databasewrites, de nieuwe
routeproeven en de standaard volledige live-test zijn groen. Positieve invoer
van nieuwe NDFF-LMFA- en SOVON-reconstructieversies is in de geïsoleerde proef
getest en teruggedraaid. Ongeldige taxonverwijzingen en gewijzigde broncontext
worden geweigerd. De export-, gekoppelde-cache- en Shiny-reproduceerbaarheidsproeven
zijn groen. Bestaande website-, dashboard- en Shiny-leesroutes zijn niet gewijzigd;
hun bestaande queryuitkomsten zijn in de volledige vergelijking behouden.
Geen nieuwe dump, cachevervanging, bronverplaatsing of VPS-upload.

Het bronregister is in Markdown en Word inhoudelijk gelijk; alle 22 pagina's
van de Wordversie zijn visueel gecontroleerd. De vier eigen tijdelijke
proef- en hersteldatabases zijn na verificatie verwijderd. De volledige
back-up en alle controlebewijzen blijven in de onderstaande herstelmap bewaard.

De volledige back-up staat buiten Git in
`/Users/ton/Documents/Codex/Herstel/taxa-centrale-querypoort-20260929/Meijendel_before.sql.gz`.
SHA-256: `0e7f65ae9fa632191cb894b0040ee4d98b8a82200fb6dcb0ad0ba45be5c68e67`.
Transactioneel terugdraaien betreft de gegevenswijzigingen. Omdat MySQL DDL
niet transactioneel terugdraait, wordt daarnaast een volledige herinstallatie
van gegevens én oorspronkelijke structuur uit deze back-up bewezen.

De onafhankelijke eindproef staat in dezelfde herstelmap onder
`proef-3/result.json`. Alle 122 beoordeelde routes zijn bereikbaar, zonder
ontbrekende of vermenigvuldigde soortregels. Het transactionele terugdraaien,
ongeldige schrijfproeven en volledige herstel van de 253 basistabellen en
16 views zijn geslaagd. De onafhankelijk herstelde database was
`Meijendel_taxa_query_herstel_2026092903`. De exact beproefde module heeft
SHA-256 `e144a2a3d604fcc3341e13dbab1957f39cee94112f06ea6b068cdd467cd9a69a`;
het migratieplan `f3b5f4c8816ab1447ec078887eb7650d39e00e33c5432abc34974ef8689c4f9e`.
Een andere bronstand, module of back-up wordt vóór de lokale wijziging geweigerd.

De schema-vergelijking bewaart alle oorspronkelijke fysieke kolomtypen,
nullability, defaults, indexen, CHECK-betekenis en foreign-key-kolommen met
update-/verwijderregels. MySQL herleidt bij herstel de nullability van een
berekend viewveld opnieuw; daarom worden voor views de definities, kolomtypen
en volledige uitkomsten gecontroleerd, niet die afgeleide nullability-vlag.
Een ALTER kan in de bestaande SHA-256-CHECK de introducer van de identieke
ASCII-regex `^[0-9a-f]{64}$` van `utf8mb4` naar `ascii` wijzigen. Alleen die
bewezen gelijkwaardige literal in die ene bestaande CHECK wordt genormaliseerd;
andere CHECKs, tekensets en collaties worden niet gelijkgesteld. Het oorspronkelijke
proefbewijs blijft bewaard, ook na gecontroleerde hervatting van de geïsoleerde proef.

De verplichte poort staat in de bestaande importmodule als
`central_query_audit()` en in de bestaande live-test als fase `waarnemingen`.
Zij controleert het volledige fysieke schema, niet alleen bekende tabelnamen.
Een nieuwe tabel of gewijzigde kolom vereist een expliciete beoordeling van
de centrale route voordat zij aan het schema-contract wordt toegevoegd.
Foreign keys moeten naar de gecontroleerde database wijzen. De daadwerkelijke
triggerinhoud, bronidentiteit, centrale sleutelroutes en eenduidige
bereikbaarheid worden bij iedere normale voor- en nacontrole gecontroleerd.
De vergelijking van alle oorspronkelijke celwaarden, fysieke kolomtypen,
indexen, constraints en 16 viewuitkomsten hoort bij de afzonderlijke
migratie-/herstelproef. Zij is geen onderdeel van de normale bereikbaarheidspoort:
een gewone import mag immers nieuwe meetwaarden toevoegen. Bij migraties en
opschoning blijft die volledige vergelijking van te behouden inhoud verplicht.

De poort is verplicht vóór en na iedere import, migratie, gegevenswijziging,
structuurwijziging of export van `Meijendel`. Rijtriggers beschermen bestaande
waarnemingslagen tijdens het schrijven. MySQL heeft geen algemene DDL-trigger:
een beheerder met rootrechten kan beveiliging bewust verwijderen. Daarom mag
handmatige root-SQL nooit de volledige voor- en nacontrole vervangen of
overslaan. Een falende poort betekent dat de wijziging niet is afgerond.

### Reikwijdte en gebruik

De onderstaande hoeveelheden zijn oorspronkelijke bronregels. Zij zijn geen
opgetelde unieke waarnemingen: bronnen kunnen overlappen en afgeleide meetregels
hebben een andere betekenis dan bronwaarnemingen. De volledige controle omvat
ook de afgeleide matrices, doelsoortregels, nulregels, historische versies en
via een bronwaarneming verbonden beoordelingsregels. Vier oude invoertabellen
zijn leeg en mogen geen ongecontroleerde blijvende soortwaarnemingen bevatten.

| Oorspronkelijke bronlaag | Regels | Bronperiode | Centrale sleutelroute |
|---|---:|---|---|
| `territoria` | 71.155 | 1958–2025 | Via behouden vogel-ID en centraal verbonden `soorten` |
| `dagwaarnemingen_bmp` | 600.959 | 2007–2025 | Dezelfde vogelroute |
| `dagwaarnemingen_wv` | 105.712 | 2000–2025 | Dezelfde vogelroute |
| `ndff_open_waarneming` | 810.830 | Ruwe bronjaren 1700–2025 | Via behouden `soort_key` en centraal verbonden `ndff_soorten` |
| `sovon_avimap_waarneming` | 19.960 | 2009–2026 | Via de bestaande samengestelde AVIMAP-bronsleutel |
| `pq_vegetatie_waarneming` | 53.122 | 1981–2025 | Rechtstreeks via `taxon_bronkoppeling_id` |
| `pq_vegetatie_bronresultaat` | 16.627 | 1981–2015 | Rechtstreeks, met de oorspronkelijke LVD-broncontext |
| `vangblik_vangst` | 60.560 | 1953–1960 | Rechtstreeks, met de oorspronkelijke determinatievelden |
| `externe_ecologie_resultaat` | 82.289 | 1875–2025, verschillend per bron | Rechtstreeks, met volledige taxonbroncontext en datasetversie |

De laatste laag omvat ENDURE: 9.072 regels uit 2018; resterende LVD:
64.683 regels uit 1959–2015; Naturalis Botany: 1.881 regels uit 1875–2025;
Naturalis Coleoptera: 869 regels uit 1906–2023; NMR: 4.748 regels uit
1955–2015; STOWA: 1.036 regels uit 1992–2010. De LVD-regels binnen en buiten
`pq_*` zijn hiermee taxonomisch bereikbaar; dit is geen fysieke verplaatsing
van de resterende LVD-levering en geen uitspraak dat alle opnamen permanente
kwadraten zijn. De afzonderlijke PQ-integratie blijft in `TODO.md` beschreven.

Van de openbare NDFF-laag hebben 5.336 regels een ruw bronjaar in 1700–1949.
Dat is geen bevestiging van hun feitelijke waarnemingsdatum. De centrale
ontsluiting verandert die oorspronkelijke datums of hun kwaliteitsbeoordeling niet.

Voer vóór en na iedere wijziging de volledige controle uit:

```bash
python3 gis/scripts/test_taxonregister_live_schema.py
```

Deze bestaande test kiest standaard de actuele fase `waarnemingen`. De oudere
fasen zijn historische deelproeven, geen bewijs van de volledige actuele dekking.
De normale imports en export roepen dezelfde controle automatisch aan rond de
werkelijke schrijfactie, met dezelfde MySQL-client, server, poort en database.

Maak SQL voor een gekozen bronlaag vanuit een centraal taxon, bijvoorbeeld:

```bash
python3 gis/scripts/import_external_ecology_sources.py \
  --centrale-query-sql --taxon-id 35699 --tabel ndff_open_waarneming
```

De helper controleert eerst de volledige database en geeft een gewone SELECT,
geen nieuwe view. Zonder `--tabel` geeft hij de afzonderlijke beoordeelde
bronroutes. Koppelen gebeurt met IDs, niet door wetenschappelijke naamteksten
opnieuw te vergelijken. De LEFT JOIN met `taxon_groepen` behoudt ook taxa
zonder groepsindeling. Kies daarna de benodigde bronvelden en kwaliteitsfilters;
tel overlappende bronnen en gereconstrueerde nullen niet zonder meer samen.

Onopgeloste **referentiegegevens zonder waarnemingen** zijn geen fictieve
waarnemingen. De catalogusregel `soorten.id=647` bevat Toendrarietgans zonder
wetenschappelijke bronnaam, met een eerder vastgesteld codeconflict. Zij is
niet gebruikt in de vogelwaarnemingen. Haar oorspronkelijke onbeoordeelde
bronbesluit blijft behouden; een nieuwe waarneming met die onopgeloste sleutel
wordt geweigerd. Niet-geïdentificeerd daadwerkelijk bronmateriaal blijft
daarentegen via een uitdrukkelijk onbepaald operationeel registerobject vindbaar.

## Weergavenaam voor alle taxa

Besluit Ton, 29 september 2026: voeg `taxa.weergavenaam` toe en vul deze
voor iedere centrale vermelding. De naam is bedoeld voor leesbare lijsten,
niet voor koppelingen of de vaststelling dat twee bronconcepten identiek zijn.
De oorspronkelijke wetenschappelijke en Nederlandse namen blijven staan.

### Vaste gebruiksregels

- Gebruik de Nederlandse naam; ontbreekt die, gebruik dan de wetenschappelijke
  naam. Maak alleen de presentatie schoon: overtollige spaties vervallen;
  de verkeerd gedecodeerde aanhalingstekens in de twee Cryptomonas-namen
  worden leesbaar. De oorspronkelijke bronvelden worden niet aangepast.
- Krijgen verschillende vermeldingen dezelfde naam, voeg dan de wetenschappelijke
  naam toe. Zo worden de vogel en plant `Hop — Upupa epops` en
  `Hop — Humulus lupulus`. Is dat nog niet onderscheidend, beoordeel eerst
  de betekenis en kies een inhoudelijke verduidelijking; geen volgnummers.
- De zeven eerder beoordeelde paren krijgen de hieronder vastgelegde labels.
  Het geleverde determinatieniveau blijft behouden, ook bij historische vogels.
- Bestaande weergavenamen blijven bij import gelijk. Een nieuwe bron is geen
  reden voor een nieuwe centrale rij of voor het hernoemen van een bestaande.
  Bij een latere inhoudelijke naamcorrectie moet ook de weergavenaam expliciet
  worden beoordeeld en opnieuw op uniciteit worden gecontroleerd.
- Gebruik voor nieuwe registerpresentaties deze kolom. Identificeer en verbind
  gegevens uitsluitend via de bestaande IDs/UUIDs en bronkoppelingen.
  Dit is geen opdracht om bestaande website-, dashboard- of Shiny-presentaties
  te wijzigen en geen toestemming tot publicatie naar de VPS.

| Taxon-ID | Weergavenaam |
|---|---|
| 471 | Barmsijs — Grote of Kleine niet onderscheiden |
| 472 | Grote barmsijs |
| 284 | Kleine Canadese gans |
| 285 | Grote Canadese gans |
| 30322 | Elachista — algengeslacht |
| 30633 | Elachista — microvlindergeslacht |
| 33906 | Sierlijke franjehoed |
| 33907 | Sierlijke franjehoed — inclusief Kortwortelfranjehoed |
| 34312 | Witsteelfranjehoed |
| 34313 | Witsteelfranjehoed — inclusief Zoetgeurende witsteelfranjehoed |
| 35436 | Brede orchis |
| 42297 | Brede orchis / Rietorchis — niet onderscheiden |
| 39058 | Dagvlinder — niet nader bepaald |
| 41317 | Vlinder — dag- of nachtvlinder niet onderscheiden |

### Invoer en technische borging

De nieuwe kolom is `VARCHAR(700) NOT NULL`, met de volledige unieke index
`uq_taxa_weergavenaam` onder `utf8mb4_0900_ai_ci` en
`ck_taxa_weergavenaam` tegen lege/witruimtewaarden, controlekarakters en
randspaties. Hoofdletters en accenten mogen dus niet het enige onderscheid
zijn. De wetenschappelijke naam zelf krijgt geen unieke index.

Nieuwe importcode gebruikt `prepare_registry_import()` in
`gis/scripts/import_external_ecology_sources.py`. Deze voert eerst de bestaande
identiteitscontrole `resolve_registry_import()` uit. Bij herkende bronidentiteit
wordt de bestaande koppeling plus weergavenaam teruggegeven; bij werkelijk
nieuwe invoer wordt `nieuw_taxon` met weergavenaam voorbereid. Dit resultaat
is geen toestemming om onbesliste taxa in te voeren. De aanroeper beoordeelt
de bron en gebruikt een actuele, vergrendelde registerselectie in dezelfde
transactie als de uiteindelijke invoer. De database weigert een ontbrekende,
lege of al gebruikte weergavenaam, ook als een oude losse invoerroute deze
voorbereiding overslaat. Een geldige unieke tekst alleen bewijst echter
geen geldige taxonidentiteit. Historische import-/migratiescripts mogen niet
blind opnieuw worden uitgevoerd; het nieuwe veld is een verplichte voorwaarde.

### Toetsing aan Darwin Core en TDWG TCS

Op 29 september 2026 opnieuw geraadpleegd: de
[Darwin Core-termen](https://dwc.tdwg.org/terms/), in het bijzonder
`scientificName`, `vernacularName`, `taxonID` en `taxonConceptID`, de
[TCS-standaardbeschrijving](https://www.tdwg.org/standards/tcs/) en de
[TCS-vocabulairetoelichting](https://tcs.tdwg.org/).
De lokale uitwerking houdt naam, concept en identiteit gescheiden.
`weergavenaam` is een aanvullende presentatielaag, geen formele
wetenschappelijke naam, vernacularName of conceptidentifier. Exporteer de
samengestelde labels niet stilzwijgend naar die standaardvelden. Er worden
geen standaardtermen hergedefinieerd, bronconcepten bevestigd of nieuwe
taxonomische interpretaties toegevoegd; geen afwijking van de afgesproken
Darwin Core/TDWG TCS-basisstructuur.

### Uitvoering en behoudscontrole

Het naamplan omvat de 11.659 centrale vermeldingen van 29 september 2026;
het register heeft geen eigen waarnemingsperiode. Er zijn 10.609 vermeldingen
met een Nederlandse naam; de overige 1.050 gebruiken de wetenschappelijke
naam, met de expliciete Lepidoptera-verduidelijking hierboven. Bij 194
vermeldingen is een wetenschappelijke aanvulling nodig. Het plan bevat
11.659 verschillende labels; de langste telt 113 tekens.

Lokaal uitgevoerd en gecontroleerd op 29 september 2026. Alle 11.659 centrale
vermeldingen hebben een gevulde, unieke weergavenaam. Alle oorspronkelijke
taxoncellen, inclusief IDs/UUIDs en tijdstempels, zijn identiek gebleven.
Alle 24.561 bronkoppelingen, alle 252 overige tabellen en alle 16 bestaande
viewuitkomsten zijn gelijk aan de uitgangstoestand. De schema- en vogelcontrole
bevestigen de bestaande relaties en 263 oorspronkelijke vogelnaamgebruiken.

Vooraf zijn een verse volledige back-up en een identieke proefdatabase gemaakt.
Rollback, een opzettelijke late fout, verouderde invoer, herhaling, ongeldige
labels en een nieuwe import met rollback zijn beproefd. Ook herstel vanuit
de tussenstanden na lege kolomtoevoeging en na gecommitteerde vulling slaagt.
De volledige back-up is daarna opnieuw hersteld en met de oorspronkelijke
database vergeleken. Proef, herstel en levende nacontrole zijn geslaagd.
De database weigert ontbrekende, NULL-, lege en dubbele weergavenamen.
Alle 28 GIS-testbestanden slagen. De aanvullende verwijzingscontrole vindt
geen verweesde taxon-, provinciale PQ-, LVD-bronresultaat- of Vangblik-koppeling.
De eigen proefdatabase is verwijderd; de volledige herstelback-up blijft bewaard.

Geen exportdump,
cache, applicatiecode of VPS-publicatie. Omdat geen broninhoud, omvang,
beoordeling of analysegeschiktheid verandert, blijven beide verschijningsvormen
van het bronregister ongewijzigd; deze presentatieafspraak hoort hier.
Uitvoeringsbestanden en herstelbewijs staan buiten Git in
`/Users/ton/Documents/Codex/Herstel/taxa-weergavenaam-20260929/`.
Leidend zijn `labels.json`, `trial_verified.json`, `restore_verified.json`
en `live_verified.json`. De volledige back-up `Meijendel_before.sql.gz` heeft
SHA-256 `ead876e85a5954d531ff8482e53eecf78e1d8f65d4f98d2a29d33019467e4eed`.
`run_display.py` voert uitsluitend benoemde fasen uit; na een fout eerst
diagnose. `recover` draait alleen de eigen schema-uitbreiding terug, mits
de bewaarde uitgangstoestand en bekende schemahashes dat aantoonbaar toelaten.
Bij `ALTER TABLE` herschrijft MySQL de tekenreeks van de bestaande UUID-controle
van `_utf8mb4` naar `_ascii`. Alleen dat exact geïdentificeerde, semantisch
gelijke patroon wordt voor de schemahash genormaliseerd; overige
schemaverschillen blijven blokkeren. Broninhoud wordt niet genormaliseerd.

## Opschoning afgerond op 29 september 2026

De 751 eerder overgebleven naamgroepen zijn inhoudelijk beoordeeld. Ook
verschillende auteursnotaties, rangafkortingen, spellingen en volgorden van
dezelfde samengestelde determinatie zijn onderzocht. In de levende lokale
database zijn nog 1.762 dubbele centrale rijen samengebracht. Er staan nu
11.659 centrale naamvermeldingen, tegenover 13.421 vóór deze vervolgstap.
Dit zijn geen 11.659 unieke biologische soorten: het register bevat ook
ondersoorten, geslachten en bredere determinatie-eenheden en heeft geen eigen
waarnemingsperiode. Er zijn geen onbesliste herhaalde naamgroepen meer uit
deze inventarisatie. De zeven inhoudelijk verschillende naamparen hieronder
zijn bewust niet samengevoegd.

Alle 21.799 bestaande bronkoppelingnummers zijn behouden. Er zijn 2.762
volledige oorspronkelijke taxoncontexten toegevoegd aan het bestaande
bronarchief; dat telt nu 6.121 contexten. `taxa_bronkoppeling` bevat 24.561
rijen en `taxon_groepen` blijft 27 groepen bevatten. Alle 31.160 geteste oude
IDs en UUIDs leiden naar de juiste centrale vermelding. De oorspronkelijke
bronwaarden en eventuele eerdere centrale versies blijven terugvindbaar.
Geen waarneming is verwijderd of samengevoegd.

### Gelijke namen met verschillende betekenis

| Naam | Behouden IDs | Waarom afzonderlijk |
|---|---|---|
| Acanthis flammea | 471, 472 | Barmsijs als aggregaat tegenover Grote barmsijs; EURING 16630 en 16631. |
| Branta canadensis | 284, 285 | De vogelbron onderscheidt Kleine en Grote Canadese gans. |
| Elachista | 30322, 30633 | Een algengeslacht en een vlindergeslacht; verschillende nomenclatuurcodes. |
| Psathyrella corrugis | 33906, 33907 | Sierlijke franjehoed tegenover de eenheid die ook Kortwortelfranjehoed omvat. |
| Psathyrella piluliformis | 34312, 34313 | Witsteelfranjehoed tegenover de eenheid die ook de Zoetgeurende omvat. |
| Dactylorhiza majalis | 35436, 42297 | Brede orchis tegenover Brede orchis én Rietorchis. |
| Lepidoptera | 39058, 41317 | PQ-broncode 3755 betekent ‘Dagvlinder’; de andere bron bedoelt de hele orde. De eerste determinatie mag niet tot alle vlinders worden verruimd. |

Ook verschillende formele rangen, subgenera, cultivars en expliciete subsets
blijven afzonderlijk. Bij Cortinarius zijn de bijna gelijke namen
`emollitus` en `emmolitus` niet verenigd: de bron noemt respectievelijk Gele
galgordijnzwam en het Fries-naamgebruik. Een verkeerde externe naamtreffer
maakt deze homoniemen niet identiek. De eindcontrole gebruikt beide
naamvelden en de bronbetekenis; alleen unieke naamtekst afdwingen zou hier
taxonomische fouten veroorzaken.

### Belangrijkste inhoudelijke correcties

De verkorte PQ-namen zijn getoetst aan de volledige Floranld-naam, code en
NDFF-identiteit. Baldellia blijft de bedoelde ondersoort; Polytrichum de
bedoelde variëteit. De gecombineerde waterkers-eenheid wordt niet met één
van haar twee soorten gelijkgesteld. De bredere LVD-Carex-eenheid gaat naar
`Carex demissa/oederi`, niet naar alleen Dwergzegge.

Bij Myosotis discolor bevat de oorspronkelijke LVD-waarneming van 29 april
2003 code 842. Die verbindt de vermelding met de brede Floranld-eenheid en
Bleek/Veelkleurig vergeet-mij-nietje; zij is niet vernauwd tot één van de
soorten. Bij Myosotis laxa bevatten zeven LVD-resultaten uit 2005–2013 code
841, overeenkomstig de PQ-code. `caespitosa` en `cespitosa` zijn hier
spellingvarianten; centraal wordt de oorspronkelijke spelling `cespitosa`
gebruikt. Dit volgt uit de oorspronkelijke codes en
[de nomenclatuurtoelichting van Landcare Research](https://biotanz.landcareresearch.co.nz/scientific-names/8EC2BE04-17E6-4576-BDE8-53F48B648A3B),
niet uit de afwijkende COL-synoniemenroute.

De LVD-conditie ‘dood’ creëert geen afzonderlijk taxon. Twee Buntgrasregels
uit 2006 en één Dicranum-regel uit 2009 behouden die conditie in de
ongewijzigde waarneming en volledige broncontext. De ene dode Hypnum-regel
uit 2009 hoort bij de brede eenheid `cupressiforme/andoi`: de LVD-catalogus
onderscheidt zelf Gewoon klauwtjesmos van het smallere Gesnaveld klauwtjesmos.
Floranld 2788 en 3287 bevestigen die naamafbakening. De LVD-doodcodes 9517,
9521 en 9524 zijn **niet** gelijkgesteld aan dezelfde getallen in
Floranld_2020: die betekenen daar andere taxa. Geen dood materiaal is als
levend geherinterpreteerd.

### Behoud, toetsing en nieuwe imports

De uitvoering gebruikt 1.208 afzonderlijk beoordeelde groepen in
`taxa-beoordeelde-fusie-v2`. Elk besluit bevat oorspronkelijke IDs, behouden
ID, veldcorrecties, reden, bewijsverwijzingen en een hash van alle betrokken
broncellen. Bij vervolgfusies blijft het eerste UUID-archief bestaan;
tussentijdse centrale rijen komen in `beoordeelde_fusies`. De bestaande
`register_broncontext` wordt nooit overschreven. De nominale centrale
vermelding bevestigt geen gelijkheid van historische taxonconcepten:
kandidaatstatussen en onbekende conceptrelaties blijven behouden. Dit volgt
de scheiding tussen naamgebruik, concept en bronidentiteit van Darwin Core
en TDWG TCS; geen afwijking van de afgesproken basisstructuur.

De volledige back-up, fusieproef, normale rollback, opzettelijke late fout,
weigering van verouderde invoer, herhaalde uitvoering en volledige
herstelproef zijn geslaagd. De levende nacontrole bevestigt alle broncellen
en verwijzingen, alle 251 overige tabellen en alle 16 viewuitkomsten.
De vogelcontrole behoudt de 263 oorspronkelijke naamgebruiken. Alle 21.710
actieve, eenduidige bestaande bronidentiteiten vinden bij importherhaling
hun bestaande koppeling terug. De 28 GIS-testbestanden slagen.

Nieuwe bronidentiteiten met een gecorrigeerde oude naam, dezelfde
binominale stam maar afwijkende rang/auteursnotatie, of een hogere taxonnaam
met auteursuffix worden vóór invoer tegengehouden voor beoordeling. Dat is
geen automatische gelijkstelling: een nieuw onderscheiden taxon kan pas na
een brongetrouw besluit worden toegevoegd. De bestaande importpoort blijft
verplicht; losse root-SQL valt niet onder deze geteste bescherming.

Er is niets naar de VPS gepubliceerd. Applicatiecode, exportdump en
Shiny-cache zijn niet vervangen. Uitvoeringsbewijs en volledige back-up:
`/Users/ton/Documents/Codex/Herstel/taxa-restgroepen-20260929/`.
Leidend zijn `reviewed_plan.json`, `r3_trial_verified.json`,
`r3_restore_verified.json` en `r3_live_verified.json`. Eerdere proefselecties
in dezelfde map zijn niet de uiteindelijke uitvoering. De eigen tijdelijke
proefdatabase is na verificatie verwijderd; de herstelbestanden blijven bewaard.

## Historie van de eerste centrale selectie

De bewezen selectie is op 29 september 2026 in de levende lokale database
uitgevoerd en gecontroleerd, na proef, terugdraaien en volledig herstel uit
de back-up. In 1.203 naamgroepen zijn 3.359 centrale rijen teruggebracht tot
1.203 vermeldingen: 2.156 dubbele rijen minder. Het register is daarmee van
15.577 naar 13.421 rijen gegaan. Het betreft
naamregistraties, geen telling van unieke biologische soorten; het register
heeft geen eigen waarnemingsperiode.

Bij *Glaucium flavum* gaan 40249 en 45031 naar 35699. De oorspronkelijke
velden van alle drie vermeldingen, inclusief Nederlandse naam en auteurschap,
blijven behouden. Datzelfde behoud geldt voor iedere geselecteerde groep.
Alle 18.440 bestaande bronkoppelingen behouden hun nummer. Daarnaast zijn
3.359 oorspronkelijke taxoncontexten bewaard in `taxa_bronkoppeling`, dataset
`taxa_naamgebruik_archief`. Ook de eigen oorspronkelijke context van de
behouden centrale rij wordt gearchiveerd. Oude nummers en UUIDs worden door
`resolve_taxon_usage()` met hun oorspronkelijke context teruggevonden.

De proef en levende nacontrole tonen: alle 251 overige tabellen zijn inhoudelijk identiek, evenals
alle 16 bestaande viewuitkomsten. De volledige vogelcontrole slaagt. De
18.351 actieve, eenduidig gekoppelde bronidentiteiten vinden bij herhaling
hun bestaande koppeling terug; er ontstaat geen nieuwe centrale rij. De
twee actieve bronvermeldingen zonder taxon en ingetrokken besluiten worden
niet alsnog gekoppeld. Een verouderde momentopname, opzettelijke late fout
en herhaalde uitvoering blokkeren zonder achterblijvende gegevenswijziging.
De tabel `taxa_bronkoppeling` bevat nu 21.799 rijen, inclusief de bewaarde
broncontexten; `taxon_groepen` blijft 27 rijen bevatten. Geen waarneming is
verwijderd of samengevoegd. De VPS, exportdump, Shiny-cache en applicatiecode
zijn niet gewijzigd. Bewijs: `r2_trial_verified.json`,
`r2_restore_verified.json` en `r2_live_verified.json` in de herstelmap.

### Uitgangsstand voor de inmiddels afgeronde vervolgcontrole

Na die eerste selectie bleven 751 naamgroepen met samen 1.960 centrale rijen
buiten de selectie. Zij zijn in de vervolgstap hierboven afgehandeld.
Destijds waren zij niet allemaal bewezen verschillende taxa en evenmin
een verwijderlijst. De onderstaande indeling telt iedere groep
eenmaal, naar de eerste relevante belemmering.

| Reden | Naamgroepen | Nodige vervolgstap |
|---|---:|---|
| Externe naamreferentie geeft geen voldoende eenduidige aansluiting | 527 | Onderscheid alternatieve taxa, rangnotatie en te zwakke of ontbrekende naamtreffers. |
| Auteursvermeldingen verschillen | 78 | Stel vast of het schrijfwijzen van dezelfde naam of werkelijk andere namen zijn. |
| Classificatie verschilt | 74 | Onderbouw oude/nieuwe familie- of orde-indeling zonder verschillende taxa te verenigen. |
| Brede, enge of samengestelde determinatie | 64 | Behoud het geleverde determinatieniveau; maak soort en verzamelbegrip niet gelijk. |
| Praktische groep ontbreekt of verschilt | 8 | Bepaal eerst de bedoelde taxongroep uit de brongegevens. |

Van de 527 referentiegevallen hebben 331 gelijknamige alternatieven, vallen
124 exacte treffers op de gebruikte scoregrens af en verschillen bij 35 de
rangnotaties. Verder zijn er 24 zonder exacte treffer, 11 treffers op een
hoger niveau en twee schrijfvarianten. De scoregrens is een conservatieve
selectieregel, geen bewijs dat de betrokken taxa verschillen. Deze gevallen
zijn in de vervolgcontrole inhoudelijk beoordeeld. Voorbeelden van daadwerkelijke
naamverwarring staan in de bewaarde referenties bij *Euphrasia stricta*, *Isothecium myosuroides* en
*Polytrichum longisetum*. Een zelfde geaccepteerde referentiesleutel heft een
verschil tussen soort en aggregaat niet op.

Opdracht Ton, 28 september 2026: echte dubbelen samenbrengen, alle
broninformatie en interne verwijzingen behouden, nieuwe dubbelen bij import
voorkomen. Geen VPS-publicatie. Dit verruimt de hieronder beschreven eerste,
uitsluitend broninterne fusie. Een andere leverancier is geen reden voor een
extra centrale vermelding. Gelijke naamtekst alleen bewijst echter geen
gelijke soortafbakening.

De centrale vermelding en het oorspronkelijke bronnaamgebruik blijven
verschillende zaken: de volledige oorspronkelijke taxonrij wordt bij de
bronverbinding bewaard, met oorspronkelijke ID/UUID, bronversie en
conceptcontext. Een omgeleide ID zoekt de centrale vermelding op, maar bewijst
geen congruentie van historische concepten. Bestaande kandidaat/onbekend-
besluiten worden niet stilzwijgend bevestigd. Homoniemen, aggregaten,
ruime/enge afbakeningen en onopgeloste inhoudelijke conflicten worden niet
automatisch verenigd. Synoniemen vereisen een afzonderlijk onderbouwde
naamrelatie; een fuzzy naamtreffer is onvoldoende.

Uitvoering in de bestaande importmodule en haar bestaande tests, op branch
`codex/taxa-eenlijst`. Geen nieuwe catalogus of view. De bestaande
analyseview moet brongebonden rang blijven tonen wanneer die van de centrale
rang afwijkt. Behoud van alle overige tabelinhoud, viewuitkomsten en
bronbesluit-IDs is een harde acceptatievoorwaarde.

Uitvoeringsplan (zelfstandig uitvoeren; geen herhaalde opdrachtbevestiging):

1. Test en implementeer een deterministische selectie met expliciete
   uitsluitingen voor naamgenoten, brede afbakeningen en veldconflicten.
   Gebruik exacte naam/auteurs-/classificatiecontext en bewaarde referenties.
2. Test de broncontextresolver en importpoort: hergebruik bestaande
   bronidentiteiten en centrale taxa; blokkeer onbesliste gelijknamige invoer.
   Bewaar broncontext volledig en behandel herleiding nooit als conceptbewijs.
3. Bouw de transactionele fusie met snapshotcontrole, vergrendeling,
   volledige celcontrole, ID-behoud en fail-closed gedrag bij sleutelbotsingen.
4. Maak een verse volledige back-up. Voer de proef, normale rollback,
   opzettelijke late fout, herhaalproef en volledig herstel geïsoleerd uit.
   Vergelijk alle overige tabellen en bestaande viewuitkomsten.
5. Pas uitsluitend de bewezen selectie identiek lokaal toe; controleer
   resterende naamgroepen en alle verwijzingen. Actualiseer documentatie en
   beide bronregisterversies, voer onafhankelijke eindreview en regressies
   uit, commit/push/merge en sluit af met workspace-preflight. Geen deploy.

Toetsingsbasis: [Darwin Core](https://dwc.tdwg.org/terms/) bewaart naam,
auteurschap, rang en nameAccordingTo; [TDWG TCS](https://tcs.tdwg.org/terms/)
onderscheidt TaxonName van brongebonden TaxonConcept. Deze normalisatie
verklaart historische bronconcepten niet identiek. Bewijs, proefuitkomsten
en voortgang staan buiten Git onder
`/Users/ton/Documents/Codex/Herstel/taxa-eenlijst-20260928/`.
Voor de aangescherpte uitvoering zijn alleen de `r2_`-bewijsbestanden
leidend. De eerste proef selecteerde nog 19 groepen met verschillende
referentierangen en is niet de uitvoeringselectie. De gebundelde
GBIF-antwoorden van 27 september zijn integraal bewaard en op SHA-256
gecontroleerd; [GBIF beschrijft de naaminterpretatie en haar beperkingen](https://techdocs.gbif.org/en/data-processing/taxonomy-interpretation).

De importpoort `resolve_registry_import()` verlangt bij een bestaande
bronidentiteit dezelfde bronvelden en metadata. Vanaf de toevoeging van de
weergavenaam wordt deze identiteitscontrole aangeroepen via de verplichte
voorbereiding `prepare_registry_import()`, zoals bovenaan beschreven.
Bij een nieuwe bronidentiteit
zijn een eenduidige centrale naam, verenigbare broncontext en een gecontroleerde
naamreferentie vereist. Bij twijfel stopt de koppeling. `None` is nadrukkelijk
geen toestemming om een nieuwe rij in te voegen: een werkelijk nieuw taxon
vraagt het afzonderlijke, brongetrouwe invoerbesluit uit de vaste afspraak
hieronder. De historische bulkimports blijven geblokkeerd. Er is geen
generieke nieuwe schrijver en geen unieke index op wetenschappelijke naam toegevoegd;
zo'n index zou legitieme naamgenoten ten onrechte verbieden. Handmatige SQL
als root kan deze toepassingscontroles omzeilen en valt niet onder de
geteste importgarantie.

## Vaste importafspraak vanaf 27 september 2026

Besluit Ton: iedere volgende import met taxongegevens gebruikt het bestaande
centrale register voor de identificatie en koppeling. Er worden geen nieuwe
afzonderlijke soorten- of taxoncatalogi per organisatie, levering of import
aangemaakt. Deze sectie is de canonieke importafspraak.

- Zoek eerst in `taxa_bronkoppeling` naar de bronidentiteit, inclusief
  bronsysteem, dataset, bronversie en oorspronkelijke taxoncode. Controleer
  het bijbehorende naamgebruik in `taxa` en de praktische indeling via
  `taxon_groepen`. Gebruik geen naamtekst als enige koppelsleutel.
- Hergebruik een passend bestaand taxon. Voeg een werkelijk ontbrekend
  taxon of noodzakelijk afzonderlijk naamgebruik met broncontext toe aan
  `taxa`, en leg de bronverbinding vast in `taxa_bronkoppeling`. Maak geen
  duplicaat alleen omdat de levering van een andere organisatie komt.
  Gebruik de bestaande praktische groepen; een benodigde nieuwe groep wordt
  onderbouwd in `taxon_groepen` toegevoegd, niet in een aparte catalogus.
- Vul bij iedere nieuwe centrale vermelding ook `weergavenaam` en toets
  die via `prepare_registry_import()`; volg de canonieke sectie
  `Weergavenaam voor alle taxa` hierboven. Een bestaande vermelding behoudt
  haar label. Gelijke of verschillende weergavenamen zijn geen taxonomisch bewijs.
- Bepaal bij twijfel eerst de juiste taxonnaam en de bedoelde afbakening,
  met de oorspronkelijke broncode, lijstversie en beschikbare referenties.
  Houd de betrokken regels buiten de definitieve import zolang dat niet is
  opgelost. Bewaar de oorspronkelijke levering en de onderzoeksuitkomst;
  neem geen dichtstbijzijnde naamtreffer of onbeoordeelde kandidaat als
  definitieve identificatie over.
- Een aantoonbaar brede determinatie, zoals `Lepidoptera`, hoeft niet alsnog
  tot een soort te worden teruggebracht. Bewaar het werkelijk geleverde
  determinatieniveau. Een naamtreffer bevestigt evenmin automatisch dat
  historische bronnen dezelfde taxonomische afbakening gebruiken.
- Verbind de nieuwe gegevens met dit register en bewaar bronwaarden,
  bronversies en de onderbouwing van de koppeling. Waarnemingen, aantallen,
  locaties en meetevents blijven buiten de drie taxontabellen. Een
  taxontoewijzing is geen besluit om waarnemingen samen te voegen.
- Toets iedere uitvoering aan Darwin Core en TDWG TCS, volgens de
  [projectbrede afspraak](../../../VWG_Project/workflow.md#darwin-core-en-tdwg-tcs-als-verplichte-toetsingsbasis).
  Afwijkingen vereisen vooraf expliciete goedkeuring door Ton. Voer vóór
  definitieve invoer de bij de import passende koppel-, herhaalbaarheids-,
  terugdraai- en behoudscontroles uit.

Dit besluit geldt voor volgende imports. Het verwijdert of hernoemt geen
bestaande catalogi en verandert geen bestaande kandidaatbesluiten in
bevestigde koppelingen. Bestaande importscripts moeten vóór hun volgende
gebruik aan deze afspraak worden getoetst en zo nodig aangepast; deze
vastlegging is op zichzelf geen softwarewijziging. Vogeltabel `soorten`,
website, dashboard en Shiny blijven onaangetast. Een wijziging van bestaande
afnemers of een migratie vraagt een afzonderlijk gecontroleerde uitvoering.

## Gerichte fusie van dubbele naamregistraties

Op 28 september 2026 heeft Ton de gerichte fusie opgedragen, met behoud van
alle informatie en interne verwijzingen. De eerste uitvoering is beperkt tot
twee groepen uit dezelfde Naturalis-keverlevering van 24 september 2026:

- `Rhantus frontalis`: 40390 naar 40389;
- `Haliplus ruficollis`: 40403 en 40404 naar 40402.

De vijf centrale rijen bevatten dezelfde taxonomische velden binnen hun groep,
dezelfde broncontext en dezelfde snapshot. De oorspronkelijke bronvelden
verschillen uitsluitend in de vermelding van een subgenus: `(Rhantus)`,
`(Haliplinus)`, `(Haliplus)` of geen subgenus. De naam met auteur, rang en
overige classificatie zijn gelijk. [ICZN artikel 6.1](https://code.iczn.org/chapter-2-the-number-of-words-in-the-scientific-names-of-animals/article-6-interpolated-names/)
rekent de tussen haakjes geplaatste subgenusnaam niet tot het binomen.
[Naturalis](https://repository.naturalis.nl/document/148523) plaatst de
Meijendelse ruficollis bij subgenus Haliplinus;
[LANUV Arbeitsblatt 20, p. 16](https://www.lanuv.nrw.de/fileadmin/lanuvpubl/4_arbeitsblaetter/40020.pdf)
beschrijft de overgang van Haliplinus naar Haliplus. Dit onderbouwt deze
normalisatie van naamregistraties, geen nieuwe determinatie van de exemplaren.

De veel ruimere inventarisatie van 28 september telde 1.814 groepen met
letterlijk gelijke wetenschappelijke namen, samen 4.453 centrale rijen.
Dat zijn kandidaatdubbelen, niet 2.639 bewezen verwijderbare taxa. De eerste
fusie omvat slechts drie dubbele rijen. Glaucium flavum 35699, 40249 en
45031 blijft buiten deze uitvoering: NDFF-naamgebruik, Naturalis-naamgebruik
en de gedeelde Catalogue of Life-naamreferentie hebben verschillende
broncontexten en rollen. Een actuele geaccepteerde naam bewijst niet dat
historische bronnen dezelfde soortafbakening hanteerden. Ook vogelaggregaten,
brede PQ-determinaties en homoniemen worden niet automatisch samengevoegd.
Van de vijf gevonden naamgroepen met dezelfde opgegeven conceptbron en
bronversie zijn alleen de twee kevergroepen toegelaten. Elachista bevat
verschillende rijken/groepen; bij Psathyrella corrugis en Psathyrella
piluliformis staat naast een nauwer naamgebruik ook een uitdrukkelijk
ruimere bronvermelding. Die drie groepen blijven gescheiden. Voor de
andere naamgroepen ontbreekt nog een bronoverstijgend besluit over dezelfde
taxonomische afbakening. Dat is de resterende inhoudelijke opgave, geen
technisch probleem dat met een unieke naamindex kan worden opgelost.

Getoetst aan [Darwin Core](https://dwc.tdwg.org/terms/) en
[TDWG TCS](https://tcs.tdwg.org/terms/): `scientificName`, auteurschap,
`taxonRank` en de bron die het naamgebruik bepaalt blijven bewaard.
Naamnormalisatie verandert geen `kandidaat/onbekend`-besluit in bevestigde
conceptgelijkheid. Er is geen afwijking van de afgesproken toetsingsbasis.

De bestaande `koppeling_id` blijft voor alle bronvermeldingen behouden;
uitsluitend het centrale doeltaxon van drie bronkoppelingen verandert.
PQ- en Vangblik-records hoeven daardoor niet te worden aangepast. De volledige
oorspronkelijke centrale rijen en bronkoppelingen worden per fusie bewaard in
`taxa.taxonmetadata.fusie_historie`, inclusief datums met microseconden en
JSON-velden. De overige taxonvelden van het behouden record blijven gelijk.

Oude numerieke taxon-IDs en UUIDs worden vastgelegd in drie technische
doorverwijzingen binnen `taxa_bronkoppeling`, met
`bron_dataset='taxa_fusie_alias'` en regelversie `taxa-gerichte-fusie-v1`.
De metadata-rol `technische_fusie_alias` onderscheidt ze van biologische
bronbesluiten. Zij blijven `kandidaat/onbekend`; de technische identiteit
mag niet als nieuwe taxonomische conceptbeoordeling worden uitgelegd.
Een bestaande kandidaatnaamreferentie in dataset `taxa` is geen alias.
De twee Rhantus-naamreferenties 50230 en 50231 behouden hun oorspronkelijke
bron-UUID en doel 44804; de oude UUID van 40390 wordt via de alias opgelost.

`resolve_taxon_identity()` in `gis/scripts/import_external_ecology_sources.py`
zoekt een huidig of voormalig centraal ID/UUID op. De resolver weigert
ambiguïteit, ketens, cycli en ontbrekende doelen. Een toekomstige import
zoekt eerst de volledige oorspronkelijke bronidentiteit op en hergebruikt
haar bestaande koppeling en huidige doel. Bij invoer met een centraal
taxon-ID of UUID moet ook deze aliasresolver worden gebruikt. Een verwijderd
ID mag niet opnieuw worden aangemaakt. Historische bulkimports blijven
geblokkeerd; er is geen algemene unieke index op naam toegevoegd.

Uitvoeringsvoorwaarden: volledige lokale back-up; geïsoleerde proef met
volledige broncontextcontrole; normale ROLLBACK én een opzettelijke SQL-fout
na de mutaties; controle van alle broncellen en oude identificaties; volledig
herstel van de proefdatabase; daarna pas de identieke levende uitvoering.
De SQL houdt het register gedurende de transactie vergrendeld en controleert
de volledige vooraf gelezen registerinhoud opnieuw vóór schrijven. Iedere
SQL-fout breekt af zonder COMMIT. Het schema, alle overige tabelchecksums en
alle viewuitkomsten worden voor en na vergeleken. Geen VPS-publicatie,
geen vervanging van dump, dashboard of Shiny-cache.

Herstel- en proefartefacten staan lokaal in
`/Users/ton/Documents/Codex/Herstel/taxa-fusie-20260928/`.
De geïsoleerde fusieproef is geslaagd: de volledige oorspronkelijke rijen
en koppelingen zijn reconstrueerbaar; de drie oude IDs en UUIDs worden
eenduidig opgelost; historische bronidentiteiten vinden dezelfde koppeling;
herhalen en een verouderde snapshot worden geweigerd. Normale ROLLBACK en
een opzettelijke SQL-fout na alle mutaties laten geen gewijzigde records
achter. De 251 overige tabelchecksums en de volledige uitkomsten van alle
16 views zijn gelijk gebleven. De schemacontrole omvat alle definities,
met uitzondering van de volgende AUTO_INCREMENT-tellerwaarde: een afgebroken
insert mag een nummer overslaan. Er is geen eis om zulke nummers te hergebruiken.
Ook het volledige herstel en de levende uitvoering zijn op 28 september 2026
geslaagd. De levende database bevat nu 15.577 centrale naamregistraties en
18.440 bronkoppelingrijen: alle 18.437 bestaande bronbesluiten plus drie
technische identificatie-aliassen. De 27 groepen zijn ongewijzigd. Alle
1.819 logische UUID-bronverwijzingen zijn oplosbaar, inclusief de verwijzing
naar het samengevoegde record 40390. De oorspronkelijke vogel-, PQ- en
Vangblik-koppelingen zijn gelijk gebleven. Er resteren 1.812 groepen met
dezelfde wetenschappelijke naam, samen 4.448 rijen; dat zijn niet automatisch
bewezen dubbelen. De volledige back-up, proefuitkomsten en herstelcontrole
blijven bewaard. Alleen de eigen tijdelijke proefdatabase is na deze
controle verwijderd. Alle 28 GIS-testscripts slagen vóór en na de levende
uitvoering. De Wordversie van het bronregister is inhoudelijk gelijk aan
Markdown; alle 22 gerenderde pagina's zijn visueel gecontroleerd.
De volgende AUTO_INCREMENT-waarde is geen onderdeel
van de terugdraai-eis; alle bestaande identificaties zijn dat wel.

Uitvoerroute: `run.py` in de herstelmap voert achtereenvolgens `backup`,
`clone`, `trial`, `restore`, `live` en `cleanup` uit. Dit is een vastgelegde
eenmalige taakroute, geen algemene importopdracht: de `live`-poort vereist
gelijke hashes van importmodule, proefhelper, tests en back-up, alle groene
proefresultaten en een ongewijzigde levende uitgangssituatie. Een bestaand
startbewijs verhindert blinde herhaling. Terugdraaien na latere nieuwe
gegevensinvoer vereist eerst een afzonderlijke herstelbeoordeling; zet dan
niet zonder meer deze volledige momentopname over de levende database heen.

## Gerichte Vangblik-opschoning

Ton heeft op 28 september 2026 de gerichte lokale opschoning goedgekeurd.
De 60.560 vangstregels met 99.652 individuen uit 1953–1960 zijn rechtstreeks
verbonden met de bestaande 275 bronkoppelingen in `taxa_bronkoppeling`.
Daarmee loopt de identificatie via `taxa` en `taxon_groepen`.
Alle negen oorspronkelijke velden van `vangblik_soorten` staan volledig in
`taxa_bronkoppeling.bronmetadata`; na bewezen behoud is die dubbele catalogus
verwijderd. `bron_dataset='vangblik_soorten'` blijft een historische bronidentificatie,
geen verwijzing naar een nog bestaande tabel.

De 37.770 events, 135 locatieversies, plotkoppelingen, bronbestanden, aantallen,
kwaliteitsvlaggen en ruwe bronwaarden blijven intact. Ook de twee vangstregels
uit 1959 zonder bijbehorend event blijven herkenbaar en uitgesloten. De
275 centrale koppelingen blijven `kandidaat`: het verplaatsen van een bestaande
bronverwijzing bevestigt geen taxonomische conceptgelijkheid.

Getoetst op 28 september 2026 aan [Darwin Core](https://dwc.tdwg.org/terms/)
en [TDWG TCS](https://tcs.tdwg.org/terms/): gebeurtenis, waarneming,
naamgebruik en taxonconcept blijven afzonderlijke entiteiten. Bronwaarden voor
`eventID`, `occurrenceID`, `scientificName`, `taxonRank` en oorspronkelijke
classificatie blijven beschikbaar. Er is geen afwijking van de afgesproken
toetsingsbasis en geen nieuwe biologische determinatie.

Uitvoering verloopt via `gis/scripts/import_ndff_public_gbif.py` met
`--vangblik-integratie`. De helper vereist een verse volledige back-up en,
voor de levende database, een geslaagde identieke proef plus volledig herstel
op een eigen lokale proefdatabase. Het herstelbewijs omvat zowel alle andere
tabelinhoud als het oorspronkelijke Vangblik-schema, de catalogus en de
koppelkaart. Elke vangst wordt vóór en na vergeleken op alle oorspronkelijke
cellen. Na een fout volgt diagnose; de helper weigert een blinde herhaling
op een gedeeltelijk gemigreerd schema. Lokale bewijsstukken worden bewaard
onder `outputs/vangblik-integratie/`.

Het historische bootstrap-schema en de oude bulkimport zijn geen route voor
nieuwe leveringen. Zij blokkeren vóór schrijven zodra de centrale verwijzing
aanwezig is. Nieuwe leveringen volgen de vaste centrale importafspraak hierboven.
Er zijn geen rechtstreekse Vangblik-afnemers in website, dashboard of Shiny
gevonden. Er wordt niets naar de VPS gepubliceerd. De bestaande `Meijendel.sql`
blijft een expliciete momentopname van vóór deze lokale migratie; een volgende
afzonderlijk goedgekeurde publicatie vereist een verse export en vergelijking.

De lokale uitvoering is op 28 september 2026 geslaagd. Alle 60.560 vangstregels
zijn via precies 275 bronkoppelingen verbonden; de 99.652 individuen en de twee
verweesde regels zijn behouden. Alle oorspronkelijke vangstcellen en alle negen
catalogusvelden zijn identiek reconstrueerbaar. De inhoud van de overige 252
tabellen is gelijk gebleven, inclusief de drie centrale taxontabellen en alle
vogel- en PQ-tabellen. Er blijven vijf fysieke `vangblik_*`-tabellen over.

Bewijs onder `outputs/vangblik-integratie/`: `proef/result.json` bevat de
volledige migratieproef en transactionele terugdraaicontrole;
`migrated_bewijs.json` bevestigt de centrale relaties en geblokkeerde
heraanmaak; `restored_bewijs.json` bewijst volledig herstel van inhoud,
catalogus en beide oorspronkelijke tabeldefinities. `live/result.json` bevat
de uitgevoerde lokale migratie. `live_bewijs.json` bevestigt de onafhankelijke
nacontrole, inclusief ongewijzigde definities van alle overige tabellen en
16 views (`schema_overige_voor.sql` gelijk aan `schema_overige_na.sql`). De back-up
`Meijendel_voor_vangblik_integratie.sql.gz` heeft SHA-256
`ccbd41095053d8bba2f69b21bdeb7805e7b47d5a9062805eb42970aee43f13c5`.
Het manifest en de herstelhelper blijven bij dit lokale bewijs bewaard.
Bij later herstel wordt eerst opnieuw een afzonderlijke proefkopie gemaakt;
een oudere back-up mag geen nadien gewijzigde levende bron overschrijven.
De eigen proefdatabase `Meijendel_vangblik_proef_20260928` is na de geslaagde
nacontrole verwijderd; back-up en bewijs zijn behouden. De importlogica,
bootstrap-blokkade, ruimtelijke contracten, analysegeschiktheid, exportcontrole
en levende registerpoort (`test_taxonregister_live_schema.py --fase vogels`)
zijn groen. De bronregisterversies zijn inhoudelijk gelijk en alle 21
gerenderde Wordpagina's zijn gecontroleerd.

## PQ-integratie en behoud van bronopnamen

### Bindende eindtoestand vanaf 29 september 2026

Alle PQ-informatie wordt brononafhankelijk opgeslagen onder `pq_*`, met
centrale taxonkoppeling. Dit geldt ook voor nieuwe, aanvullende en
vervangende leveringen. De volledige, canonieke opslagafspraak staat in
[`VWG_Project/workflow.md`](../../../VWG_Project/workflow.md), sectie
`Alle PQ-gegevens uitsluitend in pq_*`. Zij omvat ook PQ-specifieke
bronmetadata, beoordelingen en opnamekoppelingen; geen losse actieve
bestanden of PQ-restopslag elders in `Meijendel`.

De hierna beschreven uitvoering van 27–28 september betreft uitsluitend
de toen geselecteerde provinciale PQ- en vermoedelijke LVD-opnamen.
De resterende NDFF-/LVD-beoordeling, fysieke verplaatsing en importborging
zijn niet door die deelmigratie uitgevoerd. De oude beschrijving van
achtergebleven bronlagen is een feitelijke tussenstand, geen blijvende
opslaguitzondering. `TODO.md`, sectie `Volledige PQ-opslag uitsluitend onder
pq_*`, beschrijft het resterende werk en de afsluitende controle.

### Eerder uitgevoerde deelmigratie

De opgedragen migratie verbindt de 53.122 provinciale taxonregels uit
1981–2025 rechtstreeks met `taxa_bronkoppeling`, en via die koppeling met
`taxa` en `taxon_groepen`. De 714 oorspronkelijke taxonvermeldingen zijn
volledig bewaard in de bronmetadata van het register. Na de behoudscontrole
vervalt de afzonderlijke tabel `pq_vegetatie_taxon`. De naam van die
oorspronkelijke catalogus blijft als historische datasetidentificatie in het
register staan; dat is geen verwijzing naar een nog bestaande tabel.

Ton heeft ook opname van vermoedelijke PQ-bronvarianten toegestaan. De
LVD-selectie omvat 644 volledige opnamen en 16.627 taxonregels uit 1981–2015.
Zij krijgen 652 mogelijke relaties met provinciale opnamen. De relaties
blijven `vermoedelijk`; bij meerdere kandidaten wordt niet willekeurig één
gekozen. Alle bronwaarden, oorspronkelijke opname- en resultaat-IDs,
bedekkingsschalen, metadata en 32.657 bestaande overlapbesluiten blijven
bewaard in `pq_vegetatie_bronopname`, `pq_vegetatie_bronresultaat` en
`pq_vegetatie_bronoverlap`. De tabel `pq_vegetatie_opname_bronkoppeling`
bewaart de opnamevergelijking en de status. Deze bronopnamen tellen niet
zelfstandig mee. De provinciale meetreeks blijft de primaire reeks.

De bronresultaten krijgen een centrale taxonbronkoppeling op basis van de
volledige broncontext, niet alleen de naam. Dit verandert bestaande
kandidaatbesluiten niet in bevestigde taxonconceptgelijkheid. Event,
Occurrence en de afzonderlijke opname-relatie blijven gescheiden van de
taxonidentificatie, overeenkomstig [Darwin Core](https://dwc.tdwg.org/terms/)
en de scheiding tussen naamgebruik en concept in
[TDWG TCS](https://tcs.tdwg.org/terms/). De foutief als `taxonrang`
opgeslagen LVD-bronstatus heet bij de verplaatste regels
`taxonomische_status_aangeleverd`; de oorspronkelijke waarde blijft gelijk.

De bestaande LVD-analyseview blijft alle 81.310 resultaten uit 1959–2015
ontsluiten, met uitsluiting van zelfstandig meetellen voor de verplaatste
bronopnamen. Er komt geen nieuwe presentatielaag bij. De overige 2.793
LVD-opnamen en 64.683 resultaten blijven op hun bestaande plek. Daarom
blijven de gedeelde datasetmetadata daar eveneens staan. NDFF-protocolnamen
zonder aantoonbare opnamekoppeling en de 488 nog niet gegeorefereerde
duinvalleiopnamen uit 2001, 2008 en 2018 worden niet als PQ-opnamen verplaatst.

### Uitvoering en herstel

De lokale migratie van 27 september 2026 is op 28 september om 15:33 CEST
ook gepubliceerd op de VPS, vanaf commit
`829eebda2d3f4eb66acef0b10b1d1039bcf1963f`. PQ-behoud, volledige
catalogusoverdracht, exact productieschema, behoud van de negen
productie-eigen objecten en de verplichte Shiny-cache zijn gecontroleerd.
Publicatiebewijs: `outputs/pq-integratie/productie_20260928_cachevast.log`.
De levende lokale database is daarbij niet opnieuw geïmporteerd.

De actuele uitvoeringsstatus staat in `TODO.md`. Het bestaande script
`gis/scripts/import_external_ecology_sources.py --pq-integratie` bereidt
zonder `--apply` alleen een plan voor. Het vereist een gecontroleerd
back-upmanifest en een nieuwe bewijsdirectory. Met `--apply` voert het
achtereenvolgens schema, terugdraaiproef, bronverplaatsing, opruiming en
volledige behoudscontrole uit. Voor de levende database is bovendien
`--pq-proefbewijs` verplicht: een geslaagde proef met dezelfde broninhoud,
dezelfde code, dezelfde back-up en dezelfde uitgangscontroles.

Het bewijs staat lokaal buiten Git onder `outputs/pq-integratie`: volledige
databaseback-up, herstelbewijs, plan, uitgangscontrole en nacontrole. De
transactionele proef draait bronwijzigingen terug. Schemawijzigingen en
catalogusverwijdering zijn niet transactioneel; het volledige herstel is
daarom afzonderlijk op de eigen proefdatabase beproefd. Een onderbroken
schemawijziging wordt niet blind opnieuw uitgevoerd. Herstel eerst de exact
geraakte tabellen uit de gecontroleerde back-up, of herstel de hele database
alleen als is vastgesteld dat er sinds de back-up geen andere wijzigingen
zijn gedaan. Controleer daarna de bewaarde uitgangscontroles.

De historische bulkimport blokkeert zodra het PQ-migratieschema aanwezig is.
Zo kan zij verplaatste bronregels niet opnieuw aanmaken of de bestaande
analyseview terugzetten. Een volgende levering vereist een gerichte
bronbewuste aanvulling volgens de vaste importafspraak hierboven.

De afnemende VPS-database wordt met een dump bijgewerkt. Een gewone
dumpimport verwijdert geen tabellen die lokaal zijn opgeheven. Daarom
verwijdert de releasehelper `pq_vegetatie_taxon` afzonderlijk na back-up,
import en vergelijking van alle acht oorspronkelijke velden van alle 714
rijen met de centrale bronmetadata. Ook historische ingetrokken
bronversies kunnen behoud bewijzen. Extra bronvelden, afwijkende waarden,
foreign keys, viewafnemers of triggers blokkeren verwijdering. Daarna
moeten alle objectnamen en typen gelijk zijn aan de export, aangevuld met
uitsluitend de negen bestaande productie-eigen objecten:
`vogelstand_1924`, `website_plot_mapping`, `website_species_mapping` en de
views `website_plot_mapping_public`, `website_plot_species_totals`,
`website_plot_year_totals`, `website_species_mapping_public`,
`website_species_territoria`, `website_species_trends`.
Dezelfde vergelijking wordt vóór import tegen de actieve export uitgevoerd.
De kandidaat mag deze beschermde objecten niet bevatten; hun tabelinhoud en
definities moeten vóór en na import dezelfde controlehash opleveren. Een
afwijking na import activeert volledig herstel. De tabel `vogelstand_1924`
is historische context en wordt door dit behoud niet analytisch toegelaten.
De echte MySQL-proef hiervoor is herhaalbaar met
`python3 gis/scripts/test_import_external_ecology_sources.py --pq-release-opruiming`.
Deze proef maakt en verwijdert uitsluitend een eigen tijdelijke database.
De aanvullende object- en behoudscontrole heeft een eigen echte MySQL-proef:
`python3 gis/scripts/test_import_external_ecology_sources.py --pq-release-schema`.

## Naamcontrole en bronverbinding uitgevoerd op 27 september 2026

Na de uitleg over de overdracht van uitsluitend wetenschappelijke namen
heeft Ton opgedragen de noodzakelijke controles en veilige verwerking uit
te voeren, zonder opnieuw om taakbevestiging te vragen. De naamcontrole bij
GBIF is daarom uitgevoerd. Alleen naamteksten en vaste zoekopties verlaten
de iMac; bronrecords, locaties, tellingen en persoonsgegevens niet.

Uitvoering op de bestaande taakbranch `codex/taxa-inhoudelijk-verbinden`.
Bewijs, testcode en nieuwe momentopnamen staan lokaal onder
`outputs/taxa-gbif-20260927.HFKsNg/`. De eerdere uitgevoerde manifesten
blijven ongewijzigd. Alle geregistreerde naamteksten zijn vergeleken en
groepsindelingen en uitzonderingen beoordeeld. De onderbouwde aanvulling
is onafhankelijk beoordeeld, met terugdraaien beproefd en opgeslagen.
Daarna zijn de behoudscontrole, beide vormen van het bronregister en de
projectstatus bijgewerkt.

### Wat nu is opgeslagen

Op 27 september 2026 om 21:53 uur is de aanvulling definitief opgeslagen.
Alle 12.173 verschillende wetenschappelijke naamteksten van de 14.663
bestaande registraties zijn opgezocht. De registerstand heeft geen eigen
waarnemingsperiode; de perioden van de afzonderlijke bronreeksen veranderen niet.

- Nog eens 1.226 bestaande registraties hebben een onderbouwde primaire
  soortgroep gekregen. Samen met de eerdere aanvulling van 1.283 zijn nu
  2.509 van de aanvankelijk 2.787 ontbrekende groepen ingevuld.
- Er zijn 917 gedeelde naamreferenties toegevoegd: 909 op soortniveau en
  acht op ondersoortniveau. Daardoor zijn 1.819 bestaande brongebonden
  registraties via hun vaste UUID verbonden met een gemeenschappelijke
  referentie. Iedere referentie brengt minstens twee oorspronkelijke
  datasets bijeen. Dat is een zoekverbinding, geen bewijs dat hun historische
  soortafbakening gelijk is.
- `taxon_groepen` blijft 27 rijen bevatten. `taxa` bevat nu 15.580 rijen:
  14.663 brongebonden naamgebruiken en 917 externe naamreferenties.
  `taxa_bronkoppeling` bevat 18.437 besluiten, waarvan 18.350 actief:
  18.348 kandidaten en twee onbeoordeelde vermeldingen zonder doel.
  De overige 87 besluiten blijven als ingetrokken historie bewaard.

De 2.736 toegevoegde bronbesluiten bestaan uit 1.819 verwijzingen van lokale
taxon-UUIDs en 917 verwijzingen naar de externe referentielijst. Alle blijven
`kandidaat/onbekend`. De externe referenties dragen de status `accepted`
uitsluitend volgens de geraadpleegde lijst; lokale namen krijgen daardoor
geen andere status. Er zijn geen concept-IDs verzonnen en geen metingen
samengevoegd. De 138 nieuwe vogelreferenties zijn aanvullend: de oorspronkelijke
263 vogeltaxa, hun bronkoppelingen en de tabel `soorten` zijn niet gewijzigd.

De koppellijn is: oorspronkelijke bronvermelding → brongebonden taxon →
UUID-verwijzing → gedeelde naamreferentie. De tussenstap wordt in de bestaande
`taxa_bronkoppeling` bewaard met bronsysteem `Meijendel`, dataset `taxa` en
de oorspronkelijke `taxon_uuid` als bronsleutel. Geen nieuwe tabel of view.
Voor bestaande bronselecties blijven bronsysteem, dataset en bronversie
verplicht; de aanvullende verwijzingen mogen niet als meetrecords worden geteld.

### Welke uitzonderingen blijven staan en waarom

Alle 278 resterende registraties zonder primaire groep zijn beoordeeld.
Zij blijven in het register; er verdwijnt geen informatie. Dit zijn de
redenen om nu geen verdere groepsindeling af te dwingen:

| Aantal registraties | Wat ontbreekt voor een verantwoorde indeling |
| ---: | --- |
| 116 | De referentie noemt Fungi, maar onderbouwt niet de praktische scheiding tussen schimmels en korstmossen. Daarvoor is gerichte mycologische of lichenologische classificatie nodig. |
| 53 | Een gelijknamige alternatieve referentie heeft onvolledige of afwijkende groepsinformatie. Eerst die naamcontext onderscheiden. |
| 50 | Geen exacte referentienaam gevonden. Eerst spelling, historische naam of broncode onderbouwen; niet de dichtstbijzijnde treffer overnemen. |
| 39 | De referentieclassificatie past nog niet eenduidig in de huidige praktische groepen, waaronder diverse waterorganismen. Eerst die indeling onderbouwen. |
| 8 | Verzamelnaam of onvolledige determinatie. Alleen zo specifiek indelen als de bron werkelijk toelaat. |
| 5 | Slijmzwammen met rijk Protozoa en stam Amoebozoa botsen met de huidige omschrijving van de groep schimmels. Geen stilzwijgende verruiming van die groep. |
| 4 | Naamnotatie bevat extra aanduidingen die een eenduidige vergelijking verhinderen. De oorspronkelijke tekst blijft behouden. |
| 3 | De precieze indeling in dagvlinders, nachtvlinders of microvlinders is met de toegepaste familieonderbouwing niet vastgesteld. |

Deze aantallen betreffen registraties, niet noodzakelijk verschillende soorten.
De rest is verdeeld over Naturalis Botany (129), STOWA Limnodata (82),
ENDURE (40), provinciale PQ (9), NDFF (8), `soorten` (6), SOVON/AVIMAP (2)
en LVD (2). Zij gebruiken de bronperioden uit het bronregister; het zijn geen
278 nieuwe waarnemingen. De lijst per registratie met reden en geraadpleegd
bewijs staat in het bewaarde uitvoeringsmanifest, onderdeel `groepsbeoordeling`.

Ook de twee eerdere bronvermeldingen zonder doeltaxon blijven behouden:
Naturalis-`Indet.` benoemt geen taxon; bij Toendrarietgans ontbreekt de
wetenschappelijke bronnaam en strookt lokale code 1582 niet met de actuele
EURING-code 01574. Deze taak verandert de oorspronkelijke vogeltabel niet.
De veilige registeraanvulling is hiermee uitgevoerd. Nauwkeuriger indeling
van deze uitzonderingen of bevestiging van historische conceptgelijkheid
vereist aanvullend inhoudelijk bewijs, niet nogmaals toestemming voor
de reeds uitgevoerde naamcontrole.

### Bronnen en vastlegging

De externe referentie is [Catalogue of Life via GBIF](https://www.gbif.org/dataset/7ddf754f-d193-4cc9-b351-99906754a03b),
uitgegeven door de Catalogue of Life Foundation, met geregistreerde licentie
CC BY 4.0 en gerapporteerde DOI `10.48580/dgyy9`. De metadata bevatten
verschillende versielabels. Daarom wordt niet beweerd dat de zoekdienst
een onveranderlijke COL-release is. Het bewijs is de bewaarde verzameling
feitelijke antwoorden van 27 september 2026, met naam, URL, ophaaltijd,
lijst-ID en SHA-256 per bestand. Snapshotidentiteit:
`gbif-responssnapshot-20260927-6725193893040bc3`.
Dit is naam- en classificatiebewijs, geen nieuwe waarnemingsbron.

Voor de groepsindeling zijn daarnaast de eerder gecontroleerde
Floranld_2020-lijst en expliciete NDFF-brongroepen gebruikt. Ondersteunende
NDFF-rijen zijn met taxon- en bronbesluit-ID vastgelegd. Bij tegenstrijdig
bewijs blijft de indeling achterwege. Het uitvoeringsmanifest controleert
12.179 bronbestanden op hun hash, inclusief Floranld en de oorspronkelijke
registermomentopnamen. Alle 30 gerichte regressietests slagen.

De echte ROLLBACK-proef, definitieve invoer en onafhankelijke nacontrole
gebruiken hetzelfde manifest en dezelfde scripts. Alle oorspronkelijke
14.663 taxonrijen zijn over alle velden vergeleken: alleen de 1.226 vooraf
aangewezen groepsvelden en bijbehorende bewijsmetadata veranderen.
Alle 15.701 oorspronkelijke bronbesluiten zijn volledig identiek gebleven.
De 263 oorspronkelijke vogeltaxa zijn bovendien afzonderlijk vergeleken;
de bestaande vogelacceptatiepoort slaagt. De volledige deterministische
export van alle 249 overige tabellen en bijbehorende databaseobjecten is
vóór en na deze aanvulling byte-identiek, met SHA-256
`907d30aa737a4f417e7a3b1305fcfad263de4fb0c265c0eabd2d4f74ce713d09`.
Een herhaalde invoerpoging blokkeert aantoonbaar vóór de databaseverbinding.
Het bronregister is in Markdown en Word bijgewerkt; de zes gewijzigde
alinea's zijn inhoudelijk gelijk en alle overige tekst en tabellen zijn
behouden. Alle 20 gerenderde Wordpagina's zijn visueel gecontroleerd.

Bewijs en herstelbestanden staan lokaal onder
`outputs/taxa-gbif-20260927.HFKsNg/`. Manifest-SHA-256:
`2942b2fa24d5bbab7c507f791688b4be77ab278723a4328f44a212872c0c7a45`.
Vóórback-up van de twee gewijzigde registertabellen:
`fbe1055d7b6f8a827dcfd1ee914a8d47a8b21c8860f1494693a62a763f86d89f`.
Terugdraaien na COMMIT kan uitsluitend gericht op dit manifest, na controle
dat later werk de nieuwe rijen niet gebruikt: verwijder de nieuwe
bronbesluiten vóór de nieuwe referentietaxa en herstel alleen de betrokken
groepsvelden en metadata vanuit de beginsituatie. Geen volledige database
terugzetten. De oorspronkelijke bronlagen, publicatiedump, caches,
website, dashboard, Shiny en VPS worden niet gewijzigd.

Darwin Core en TCS zijn opnieuw geraadpleegd op 27 september 2026:
`scientificName`, `taxonID`, `scientificNameID`, `nameAccordingToID`,
`acceptedNameUsageID`, `taxonRank` en het onderscheid tussen een naamgebruik
en een conceptrelatie blijven leidend. GBIF v2 wordt bevraagd met de expliciete
checklist-ID `7ddf754f-d193-4cc9-b351-99906754a03b`. De feitelijke reactie,
raadpleegdatum en lijstcontext worden bewaard. Een referentienaamtreffer is
geen bevestiging dat twee historische bronnen dezelfde afbakening hanteren.
Schema, oorspronkelijke bronvelden en applicaties blijven ongewijzigd.

De volgende secties zijn het historische uitvoeringsverslag van eerdere
stappen. De actuele aantallen en resterende uitzonderingen staan hierboven.

## Groepen en PQ-namen aangevuld, 27 september 2026

Opdracht Ton: ontbrekende groepen aanvullen, onduidelijke namen oplossen en
aantoonbaar overeenkomstige taxa tussen bronnen verbinden. Uitvoering in
`codex/taxa-inhoudelijk-verbinden`; bronlagen en applicaties blijven gelijk.
De bestaande taakdocumentatie blijft de hoofdlocatie; geen tweede planbestand.

Op 27 september om 20:53 uur is de onderbouwde aanvulling opgeslagen in de
levende lokale database. Het resultaat:

- **Soortgroepen:** 1.283 bestaande naamgebruiken hebben een primaire groep
  gekregen: 607 uit de overeenkomst van PQ-code, wetenschappelijke naam en
  Nederlandse naam met Floranld_2020; 674 uit expliciete familie- of
  ordegegevens in de bron; twee NDFF-naamgebruiken uit hun bestaande
  aanduiding als kreeftachtige. Er blijven 1.504 naamgebruiken zonder groep.
- **PQ-namen:** alle 87 eerder onopgeloste naamteksten uit de PQ-reeks
  1981–2025 zijn onderbouwd met de officiële Floranld_2020-lijst. Code,
  wetenschappelijke naam én Nederlandse naam moesten passen. De volledige
  namen zijn als 87 nieuwe, voorlopige brongebonden naamgebruiken toegevoegd,
  ieder met een groep. De oorspronkelijke 87 bronbesluiten zijn behouden
  en vervangen door een nieuwe besluitversie, niet overschreven.
- **Verbinding tussen bronnen:** overeenkomstige spelling bewijst nog niet
  dat bronnen dezelfde soortafbakening gebruiken. Er zijn daarom geen
  bevestigde conceptgelijkstellingen toegevoegd en geen waarnemingen
  samengevoegd. Dit deel van de opdracht is nog niet afgerond.

De registerstand is nu 27 groepen, 14.663 voorlopige naamgebruiken en
15.701 bronbesluiten, waarvan 15.614 actief. Dit zijn geen 14.663 unieke
biologische soorten en geen telling van lokale aanwezigheid; het register
heeft zelf geen waarnemingsperiode. Er zijn nog twee actieve bronvermeldingen
zonder doeltaxon:

- Naturalis Botany bevat één `Indet.` binnen de bronreeks 1875–2025. Die tekst
  benoemt geen taxon; er wordt geen soort bij verzonnen.
- `soorten.id=647` bevat Toendrarietgans zonder wetenschappelijke naam en met
  `euring_code=1582`. De officiële EURING-lijst van februari 2026 gebruikt
  `01574` voor `Anser serrirostris`; code `01582` komt daarin niet voor.
  Dat rechtvaardigt geen wijziging van de oorspronkelijke vogeltabel.
  De herkomst van de lokale code moet eerst worden vastgesteld.

Voor verdere groepsindeling en naamvergelijking is toestemming gevraagd om
uitsluitend wetenschappelijke namen naar de openbare GBIF-zoekdienst te
sturen. Die grootschalige opvraging is door de uitvoeringsbeveiliging
tegengehouden en niet uitgevoerd. Locaties, datums, tellingen en
persoonsgegevens zijn niet aangeboden. Ook na toestemming geldt: een
naamtreffer ondersteunt naamgeving en classificatie, niet vanzelf
gelijkheid van historische taxonconcepten.

### Onderbouwing en controle

De openbare [Floranld_2020-lijst](https://www.synbiosys.alterra.nl/turboveg/)
is gedownload uit de door de uitgever aangeboden ZIP van 10 maart 2026.
De soortenlijst bevat 17.468 unieke codes. Zij is een referentielijst, geen
nieuwe waarnemingsbron, en bewijst niet dat alle historische PQ-opnamen
dezelfde lijstversie gebruikten. De oorspronkelijke PQ-tekst, code en
metadata blijven daarom bewaard. Bij combinaties is de hele gecombineerde
naam vastgelegd, zonder die als auteursnaam te misbruiken. De 87 aanvullingen
blijven kandidaat; hun conceptrelatie blijft `onbekend`.

Voor de vlinderindeling zijn de officiële familieoverzichten van
[De Vlinderstichting](https://vlinderstichting.nl/vlinders-en-libellen/alles-over-vlinders/vlinders-herkennen/families/)
en [microvlinders](https://vlinderstichting.nl/vlinders-en-libellen/alles-over-vlinders/vlinders-herkennen/microvlinders/)
gebruikt; alleen expliciet ondersteunde familie-indelingen zijn toegepast.
De vogelcode is gecontroleerd in de volledige openbare
[EURING-codelijst](https://www.euring.org/data-and-codes/euring-codes), versie
IOC 15.1.2, gepubliceerd op 12 februari 2026.

De onafhankelijke beoordeling, zeven naam-/groepstests en zes uitvoeringstests
slagen. Een tijdens de eerste proef gevonden fout in de rijtelling is
hersteld met een regressietest; die proef is volledig teruggedraaid.
De daaropvolgende volledige ROLLBACK-proef en de definitieve invoer gebruikten
hetzelfde manifest en dezelfde gecontroleerde scripts. Alle bestaande velden
zijn vergeleken, zowel binnen de schrijftransactie als na COMMIT: uitsluitend
de bedoelde groepsaanvullingen, hun onderbouwing en de intrekking van de
87 vervangen bronbesluiten zijn gewijzigd. De 263 bestaande vogelregistraties
en hun koppelingen blijven identiek; de afzonderlijke vogelcontrole slaagt.

De volledige deterministische export van alle 249 overige tabellen en
bijbehorende databaseobjecten is vóór en na de aanvulling byte-identiek:
`907d30aa737a4f417e7a3b1305fcfad263de4fb0c265c0eabd2d4f74ce713d09`.
Dat omvat ook de oorspronkelijke vogel-, PQ-, NDFF-, Vangblik- en externe
bronlagen. De historische acceptatiepoort `--fase overige` beschrijft de
eerste invoer; voor deze vervolgstap is de afzonderlijke volledige
veldvergelijking in `uitvoering.py` leidend, naast `--fase vogels`.

Uitvoeringsbewijs, scripts, manifest en herstelback-ups staan lokaal onder
`outputs/taxa-verbinden-20260927.m7fxBO/`; deze gegevens gaan niet naar GitHub.
Manifest-SHA-256:
`70ae1187276c206583914e41670895301550d65b71959b4347f4e6a9fd23836f`.
De vóórback-up van de twee gewijzigde registertabellen heeft SHA-256
`ac3793346f63e21bc2f8ec6011aeda1be8d71ecba2060647f8632e3206bc1428`.
Terugdraaien na COMMIT vereist een gerichte hersteltransactie voor uitsluitend
dit manifest, met voorafgaande controle op later gebruik. Een volledige
database terugzetten is daarvoor niet toegestaan. De publicatiedump,
applicatiecode, caches en VPS zijn niet vernieuwd.
Het bronregister is in Markdown en Word bijgewerkt; de gewijzigde alinea is
inhoudelijk gelijk en alle overige alineatekst is behouden. Alle 20
gerenderde Wordpagina's zijn visueel gecontroleerd.

Normbasis opnieuw geraadpleegd op 27 september 2026:
[Darwin Core](https://dwc.tdwg.org/terms/) (`scientificName`, `taxonID`,
`nameAccordingToID`, `acceptedNameUsageID`, `taxonRank`) en
[TCS](https://tcs.tdwg.org/terms/) (naam, brongebonden concept en relatie).
De lokale groep blijft een gebruiksindeling; `taxonrelatie=gelijk` betreft
afbakening, niet alleen spelling. De officiële Turboveg-lijst is verkrijgbaar
via https://www.synbiosys.alterra.nl/turboveg/. GBIF-documentatie over
naamgebruik en classificatie: https://techdocs.gbif.org/en/openapi/v1/species.
Geen afwijking van de standaarden of schemawijziging toegestaan.

De volgende secties beschrijven de eerdere stappen op dezelfde dag. Hun
aantallen en open punten zijn historisch; de actuele stand staat hierboven.

## Toevoegende invoer overige naamgebruiken op 27 september 2026

Ton heeft de categoriebeoordeling en aansluitende invoer goedgekeurd.
De uitvoering blijft beperkt tot het nieuwe register in de levende lokale
database. Geen hernoeming, broncorrectie, verhuizing van meetgegevens,
bevestigde conceptkoppeling of wijziging aan website, dashboard en Shiny.
De bestaande 27 groepen volstaan; er worden geen groepen bij verzonnen.

Manifest v3 is op 27 september 2026 om 19:40 uur toevoegend uitgevoerd:
14.313 nieuwe naamgebruiken en alle 15.351 bronkoppelingen. De database bevat
nu 27 groepen, 14.576 naamgebruiken en 15.614 bronkoppelingen: 15.525
kandidaten en 89 onbeoordeelde vermeldingen zonder doel. Dit zijn geen
14.576 unieke biologische soorten. Bij 2.787 naamgebruiken is de primaire
groep nog niet vastgesteld; naamgebaseerde groepssuggesties zijn niet
automatisch overgenomen. De primaire bronidentiteiten en behouden UUIDs
uit v2 blijven gelijk.
87 PQ-vermeldingen uit de bronreeks 1981–2025 krijgen voorlopig geen doel:
hun naamtekst is niet voldoende onderbouwd. Dit zijn niet 87 bewezen
afkappingen. Bij 70 van de 157 lengtesignalen is de exacte tekst in andere
lokale broncatalogi aanwezig; dat ondersteunt alleen registratie van die
tekst, niet conceptgelijkheid. Ook één `Indet.`-vermelding uit Naturalis
Botany (bronreeks 1875–2025) en Toendrarietgans uit de referentietabel
`soorten` blijven zonder doel. Alle 89 vermeldingen blijven volledig
herleidbaar in `taxa_bronkoppeling`.

De 998 LVD-naamgebruiken uit 1959–2015 krijgen geen status als rang;
bij 122 daarvan blijft het centrale auteursveld leeg omdat de bron daar de
hele naam bevat. De oorspronkelijke metadata blijven letterlijk behouden.
Combinaties worden operationele eenheden, hybriden blijven herkenbaar,
expliciete verzamelbegrippen worden aggregaten. Een ruime of enge
naamaanduiding alleen bepaalt geen formele rang of conceptrelatie.

Uitvoeringspoort: lokale back-up, ongewijzigde broncatalogi, vaste manifest-
en scriptvingerafdruk, echte ROLLBACK-proef, volledige rijvergelijking vóór
COMMIT en nacontrole. Python-optimalisatie is verboden omdat zij assertions
uitschakelt. Herhaalde invoer moet vóór schrijven blokkeren. De broncontroles
en toevoegingen gebeuren binnen dezelfde SERIALIZABLE-transactie.
De acceptatiepoort `--fase overige --manifest <lokaal manifest>` vergelijkt
alle ingevoerde velden en behoudt de afzonderlijke controles van de 263 vogels.

Beide volledige ROLLBACK-proeven slaagden. De tweede gebruikte dezelfde
ASCII-UUID-vergelijking en exact hetzelfde invoerrecept als de definitieve
toevoeging. Daardoor bleef de unieke UUID-index bruikbaar. Na beide proeven
resteerden de oorspronkelijke 263 taxa en 263 koppelingen, over alle velden
identiek. De controles vóór en na COMMIT bevestigen de nieuwe aantallen,
alle manifestvelden en ongewijzigde oude registerrijen. Een opzettelijk
verkeerde bronhash en een herhaalde invoerpoging worden vóór INSERT
geblokkeerd; een SQL-fout beëindigt de sessie zonder vervolg of reconnect.

Manifest-SHA-256:
`6bb5b6d0df6e07b289b850adc7141da141d097e9a6e66084ec888f297662c603`.
De vóórback-up bevat de twee registertabellen plus alle 249 overige tabellen.
De deterministische export van die 249 overige tabellen en bijbehorende
databaseobjecten is vóór en na invoer byte-identiek:
`907d30aa737a4f417e7a3b1305fcfad263de4fb0c265c0eabd2d4f74ce713d09`.
De productiedump `Meijendel.sql`, caches en VPS zijn niet vernieuwd.
De uitgebreide live-acceptatiepoort en afzonderlijke veldnacontrole slagen.
De vogelproef behoudt rijtellingen, sommen, nullen en expliciete nullen in
71.155 territoriumregels (1958–2025), 600.959 BMP-regels (2007–2025) en
105.712 wintertelregels (2000–2025), zonder ontbrekend koppeldoel of fan-out.
Zes gerichte manifestregressies slagen. Het bronregister is in Markdown en
Word bijgewerkt; alle 20 gerenderde Wordpagina's zijn visueel gecontroleerd.
Terugdraaien na COMMIT vereist een gecontroleerde verwijdering van uitsluitend
deze manifest-UUIDs en bronbesluiten, na controle op nieuw gebruik; herstel
van de hele database is hiervoor niet toegestaan.

Uitvoeringsbewijs en back-ups staan uitsluitend lokaal onder
`outputs/taxa-invoer-20260927.JTFh3v/`. Brondata en SQL-uitvoer gaan niet naar
GitHub. De volgende secties blijven als historische voorbereidingsstappen
behouden; hun aantallen en open vervolgstappen beschrijven de stand vóór v3.
Darwin Core en TDWG TCS zijn op 27 september opnieuw geraadpleegd; er is
geen afwijking van de vastgelegde basisstructuur toegepast.

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
