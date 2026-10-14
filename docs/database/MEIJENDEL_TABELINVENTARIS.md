# Meijendel ingedeeld naar soortgroepen

Tabelinventaris en voorstel voor herinrichting. Stand van de controles: 14 oktober 2026. De aantallen volgen de levende lokale database. Voor HNS zijn v1 en v2 beide opgenomen: v2 is actueel; v1 blijft als auditspoor bewaard.

## Hoofdkeuze

De hoofdindeling wordt de soortgroep. Libelleninformatie hoort herkenbaar onder `libellen_*`, keverinformatie onder `kevers_*`, enzovoort. De organisatie die gegevens levert en het moment waarop bestanden gezamenlijk zijn geïmporteerd, bepalen niet langer de indeling. Rechtstreekse leveringen moeten dezelfde tabelfamilies kunnen aanvullen als de informatie die via NDFF is ontvangen.

Ik adviseer 26 soortgroepen als vertrekpunt. Ze zijn alle in de huidige database vertegenwoordigd. Binnen een groep onderscheiden we soorten, waarnemingen en, waar aanwezig, routes, bezoeken, monsters of collectiestukken. Geen afzonderlijke tabel voor iedere biologische soort.

Vogels blijven volledig onaangetast. `pq_*` blijft de gezamenlijke structuur voor PQ-informatie: de provinciale reeks én passende PQ-gegevens die nu elders zijn opgeslagen. PQ-resultaten worden dus niet verdeeld over bijvoorbeeld `vaatplanten_waarneming` en `mossen_waarneming`.

Ook het eerder afgesproken behoud van `vangblik*` blijft gelden. De vangst en het bijbehorende event blijven daar bijeen. Een fysieke koppeltabel onder de soortgroep, bijvoorbeeld `kevers_vangblik_koppeling`, maakt die informatie vanuit de groep herkenbaar zonder de vangst dubbel op te slaan. Hetzelfde kan voor PQ, bijvoorbeeld `vaatplanten_pq_koppeling`. Dit zijn relaties naar de bestaande resultaten, geen nieuwe views.

Het eerdere voorstel om alleen `ndff_` te schrappen en `externe_ecologie_*` in `ecologie_*` te veranderen, vervalt. Dat zou de verspreide opslag grotendeels laten bestaan. De nieuwe richting vraagt naast hernoemen ook gerichte verdeling van gegevens en aanpassing van sleutels en importprocedures.

## Welke soortgroepen ik adviseer

Onderstaande tabel geeft de voorgestelde voorvoegsels en de huidige NDFF-basis. De aantallen zijn soortgroeplidmaatschappen, gecontroleerd via `ndff_open_soortgroep_koppeling` en `ndff_open_waarneming`. Het zijn geen totalen over alle bronnen en geen aantallen onafhankelijke metingen. De periode is het werkelijk opgeslagen minimum- en maximumjaar.

| Voorgestelde tabelfamilie | Records in NDFF-basis | Opgeslagen jaren |
|---|---:|---|
| `amfibieen_*` | 12.982 | 1951–2025 |
| `dagvlinders_*` | 129.238 | 1700–2025 |
| `eencelligen_*` | 156 | 2006–2025 |
| `geleedpotigen_overig_*` | 426 | 2006–2025 |
| `insecten_overig_*` | 1.888 | 1955–2025 |
| `kevers_*` | 8.079 | 1992–2025 |
| `korstmossen_*` | 28.643 | 1936–2025 |
| `kranswieren_wieren_algen_*` | 555 | 1974–2025 |
| `kreeftachtigen_*` | 2.052 | 1971–2025 |
| `libellen_*` | 32.325 | 1950–2025 |
| `microvlinders_*` | 22.849 | 1850–2025 |
| `mossen_*` | 32.353 | 1940–2025 |
| `nachtvlinders_*` | 72.978 | 1850–2025 |
| `ongewervelden_overig_*` | 1.760 | 2004–2025 |
| `reptielen_*` | 3.347 | 1950–2025 |
| `schimmels_*` | 77.724 | 1950–2025 |
| `snavelinsecten_*` | 7.819 | 1991–2025 |
| `spinachtigen_*` | 2.480 | 1992–2025 |
| `sprinkhanen_en_krekels_*` | 9.163 | 1951–2025 |
| `vaatplanten_*` | 277.812 | 1895–2025 |
| `vissen_*` | 1.280 | 1981–2025 |
| `vleermuizen_*` | 9.912 | 1968–2025 |
| `vliegen_en_muggen_*` | 10.495 | 1986–2025 |
| `vliesvleugeligen_*` | 12.365 | 1952–2025 |
| `weekdieren_*` | 13.043 | 1950–2025 |
| `zoogdieren_overig_*` | 39.339 | 1950–2025 |

Dagvlinders, microvlinders en nachtvlinders blijven afzonderlijk herkenbaar. Ook vleermuizen blijven apart; `zoogdieren_overig_*` omvat de overige zoogdieren. Bijen, wespen en mieren vallen voorlopig onder `vliesvleugeligen_*`. De drie families met `overig` voorkomen dat aanwezige gegevens zonder passende fijnere indeling worden weggedrukt. Dit is een praktische gegevensindeling, geen nieuwe taxonomische classificatie.

De 26 groepen bevatten samen 811.063 lidmaatschappen van 810.830 bronwaarnemingen. Er zijn 179 waarnemingen uit 2006–2025 met zowel het label overige geleedpotigen als kreeftachtigen, en 54 uit 1991–2025 met zowel korstmossen als schimmels. Die 233 extra lidmaatschappen mogen geen extra onafhankelijke waarnemingen worden. Bewaar de bronlabels; wijs vóór de verdeling één primaire opslaggroep toe en leg eventuele nevenindelingen apart vast.

Ook de jaartallen worden niet stilzwijgend aangepast. De NDFF-basis bevat 5.336 regels met een opgeslagen jaar vóór 1950: 17 dagvlinderregels uit 1700–1937, drie korstmosregels uit 1936, 162 microvlinderregels uit 1850–1939, twee mosregels uit 1940, 144 nachtvlinderregels uit 1850–1947 en 5.008 vaatplantregels uit 1895–1949. De tabel toont de opslag, niet een gevalideerde historische dekking of een ononderbroken meetreeks. Deze herinrichting beoordeelt die dateringen niet opnieuw.

## Hoe de tabelfamilies eruit kunnen zien

`libellen_waarneming` wordt een echte, bronoverstijgende waarnemingstabel, met biologische gegevens en verwijzingen naar taxon, bron en eventueel bezoek. De huidige tabel `ndff_libellen` bevat alleen een `waarneming_id`; die enkelkolomsindex hernoemen zou niet volstaan.

Voor libellen ligt deze familie voor de hand:

- `libellen_taxon` voor de bij deze groep gebruikte taxonreferenties;
- `libellen_waarneming` voor de waarnemingen uit alle toegelaten bronnen;
- `libellen_routefamilie` en `libellen_routegeometrie` voor routes en hun geometrieversies;
- `libellen_bezoek` en `libellen_bezoek_taxon` voor bezoeken en het bijbehorende taxonbereik;
- `libellen_bronkoppeling` voor oorspronkelijke bron-ID's en hun relatie met de gemeenschappelijke objecten.

Andere groepen volgen dezelfde naamregel. Maak alleen de tabellen die de gegevens vergen. Collectiestukken blijven herkenbaar, bijvoorbeeld onder `kevers_collectiestuk`; bedekkingswaarden blijven onderscheiden van aantallen dieren. Methode kan achter de groepsnaam staan, zoals `schimmels_zeereep_bezoek` of `vaatplanten_florbase_inventarisatie`.

Gemeenschappelijke ondersteuning mag gemeenschappelijk blijven: bronregistratie, gecontroleerde taxonvertaling en een register voor gedeelde metingen of gemengde bezoeken. Voorgestelde namen zijn `bron_dataset`, `bron_record`, `taxon_bronkoppeling` en `meting_register`. Hergebruik en verbreed bestaande registraties waar dat kan. Die ondersteuning wordt geen nieuwe centrale biologische verzameltabel waarin alle resultaten opnieuw verdwijnen.

Een stabiel meet-ID in `meting_register` kan overlapbesluiten, bronrecords en ruimtelijke beoordelingen verbinden. De biologische inhoud staat in de passende groep, of in de behouden PQ- en Vangblikfamilies. Daarmee blijven gedeelde verwijzingen controleerbaar met echte sleutels. Bestaande vogelgegevens hoeven hiervoor geen nieuwe sleutel te krijgen.

Een gemengd bezoek wordt niet per soortgroep een nieuw onafhankelijk bezoek. Bewaar het event één keer, met groepsspecifieke resultaten en telbereik eronder. Dat is onder meer van belang voor STOWA, ENDURE, LiveAtlas en tuintellingen. Een niet-getelde groep mag bij de verdeling geen nullen krijgen.

## Waar de huidige informatie naartoe gaat

### Herkenbare meetstructuren

Het hernoemen van een al afgebakende meetfamilie is het eenvoudigste deel. Gebruik consequent de meervoudige groepsnaam, niet afwisselend `libel_` en `libellen_`.

| Huidige familie | Voorgestelde richting |
|---|---|
| `ndff_libel_*` | `libellen_*` |
| `ndff_vlinder_*` | `dagvlinders_*` |
| `ndff_nachtvlinder_*` | `nachtvlinders_*`; taxonbereik toetsen bij aansluiting van microvlinders |
| `ndff_amfibie_*`, `ndff_reptiel_*` | `amfibieen_*`, `reptielen_*` |
| `ndff_vleermuis_*` | `vleermuizen_*` |
| `ndff_braakbal_*`, `ndff_konijn_*`, `ndff_otter_bever_*` | `zoogdieren_overig_braakbal_*`, `zoogdieren_overig_konijn_*`, `zoogdieren_overig_otter_bever_*` |
| `ndff_mos_*`, `ndff_korstmos_*` | `mossen_*`, `korstmossen_*` |
| `ndff_bospaddenstoel_*`, `ndff_zeereep_*` | `schimmels_bospaddenstoel_*`, `schimmels_zeereep_*` |
| `florbase_*`, `hns_*`, `lmfa_*` | `vaatplanten_florbase_*`, `vaatplanten_hns_*`, `vaatplanten_lmfa_*` |
| `ndff_vliesvleugel_*` | `vliesvleugeligen_*` |
| `ndff_poldervis_*`, `ndff_habslak_*` | `vissen_poldervis_*`, `weekdieren_habslak_*` |
| `ndff_ravon_n2000_*` | Amfibieën en vissen; gedeelde monsterlocatie eenmaal bewaren |
| `ndff_tuintelling_*`, `ndff_liveatlas_*`, `ndff_kwartiertelling_*` | Resultaten en taxonbereik per groep; gemengde events gemeenschappelijk |
| `daz_bmp_*` | Niet-vogelgegevens naar passende groepen; primaire AVIMAP-laag en vogelketen beschermen |

De indeling mag niet op de afkorting worden geraden. De 5.980 geselecteerde LMFa-records uit 2000–2025 bevatten uitsluitend vaatplanten. De 67 RAVON-N2000-records uit 2025 bestaan uit 41 amfibieën- en 26 visrecords. Een volledige RAVON-tabel onder één van die groepen schuiven zou de andere groep verhullen.

### De zes datasets onder externe ecologie

`externe_ecologie_*` is een importverzameling, geen inhoudelijke hoofdcategorie. De zes datasets omvatten 98.916 resultaten uit 1875–2025 in 10.994 events. Verdeel de resultaten naar de juiste groep of naar PQ; behoud dataset, event, bron-ID's, eenheden, rechten en overlapbesluiten.

| Dataset en huidige omvang | Bestemming en noodzakelijke controle |
|---|---|
| STOWA/Limnodata — 1.036 resultaten, 44 events, 1992–2010 | Naar passende watergebonden flora- en faunagroepen; gezamenlijk monster behouden. Alle 1.036 resultaat-JSON's missen kingdom, phylum, class en order en hebben geen exacte naamovereenkomst met de huidige NDFF-taxonnamen. Eerst aanwezige bronmetadata en taxoncodes vertalen; niet alles als insecten behandelen. |
| ENDURE — 9.072 resultaten, 15 events, 2018 | Naar onder meer insecten, spinachtigen en weekdieren. De 9.001 expliciete afwezigheden blijven gekoppeld aan de 14 volledige matrices; het vijftiende meetpunt krijgt geen verzonnen matrix. Taxonomische verdeling vraagt aanvulling uit aanwezige metadata. |
| LVD — 81.310 resultaten, 3.437 opnamen, 1959–2015 | Het aantoonbare PQ-deel naar `pq_*`. Overige vegetatieopnamen blijven samenhangende opnamen, met resultaten onder de passende soortgroep. Niet iedere LVD-opname is een permanent quadraat. |
| NMR-vlinders — 4.748 collectierecords, 1955–2015 | Naar dagvlinders, nachtvlinders en microvlinders op basis van taxon. Exacte naamvergelijking geeft 4.663 nachtvlinder-, twee dagvlinder- en zes microvlinderkandidaten; 77 records hebben geen exacte naammatch. Dit zijn kandidaten, geen voltooide taxonomische validatie. |
| Naturalis Botany — 1.881 collectierecords, 1875–2025 | Niet als geheel naar vaatplanten: aanwezige classificaties en naamovereenkomsten tonen ook mossen, korstmossen, schimmels en algen. Per taxon toewijzen; oorspronkelijke determinatie bewaren. |
| Naturalis Coleoptera — 869 collectierecords, 1906–2023 | Naar `kevers_*`: bij alle 869 staat Coleoptera in de opgeslagen orde. Daarna taxonidentiteiten koppelen; 255 records uit 1913–2023 hebben geen exacte NDFF-naammatch. |

De NDFF-naamlijst is geen verplichte toelatingslijst. Een taxon zonder overeenkomst kan geldige aanvullende broninformatie zijn. Omgekeerd bewijst een gelijke naam nog niet dat taxonconcept en rang gelijk zijn. Naamvergelijking is een hulpmiddel, geen reden om gegevens weg te laten. Nog niet eenduidig ingedeelde bronrecords blijven met die status bewaard; ze worden niet geforceerd in een groep gezet. Een proef kan pas volledig worden overgenomen wanneer ieder betrokken record een verklaarde bestemming heeft.

### Vangblik blijft bijeen

De Vangblikreeks omvat 60.560 resultaatregels bij 37.770 events uit 1953–1960. Daarvan horen 56.360 regels bij 271 kevertaxa en 4.200 bij vier zoogdiertaxa. De gekoppelde keverevents lopen van 8 maart 1953 tot en met 16 maart 1960; de zoogdierevents van 1 juli 1953 tot en met 16 maart 1960. Twee keverregels missen een gekoppeld event en blijven afzonderlijk gemarkeerd.

Behoud de zes bestaande `vangblik*`-tabellen. Voeg gecontroleerde relaties toe vanuit `kevers_*` en `zoogdieren_overig_*`, op taxon- en vangstniveau. Die verwijzen naar de bestaande vangst-ID's en mogen niet als een tweede verzameling vangsten worden opgeteld.

### Ook de overige soortgroepen uit AVIMAP meenemen

De huidige AVIMAP-laag bevat 19.960 niet-vogelwaarnemingen: 19.877 zoogdierregels uit 2009–2026, 75 regels in de gecombineerde groep amfibieën en reptielen uit 2009–2026, vier dagvlinderregels uit 2015–2017 en vier mierenregels uit 2017–2019. Gebruik deze aanwezige primaire bron; beperk het ontwerp niet tot de drie onderzochte voorvoegsels.

Splits gecombineerde groepen op taxon. Behoud de primaire positie van AVIMAP ten opzichte van de NDFF-DAZ/BMP-reconstructie. De bestaande SOVON-tabellen en hun koppeling met de vogelverwerking blijven tijdens de eerste migraties onaangetast; groepskoppelingen geven toegang tot de niet-vogelrecords. Eventuele latere verplaatsing vereist een afzonderlijk bewezen scheiding van de vogelketen.

## PQ als gezamenlijke opslag

`pq_*` blijft behouden en wordt bronoverstijgend gemaakt. De provinciale basis bevat 254 PQ-locaties, 2.007 opnamen en 53.122 taxonresultaten uit 1981–2025. De afleiding naar vogelplots bevat 513 plot-jaarregels uit dezelfde periode. Deze bestaande ID's en uitkomsten vormen de controlebasis.

Aanvullen kan extra metadata bij een bekende opname betekenen, een nieuwe opname van een bestaande PQ, of een nog niet aanwezige, aantoonbaar gelokaliseerde PQ. Alle drie horen onder `pq_*`, maar vragen verschillende identiteitscontroles.

### Welke verspreide PQ informatie nu aanwezig is

LVD bevat de concreetste aansluiting. Bij 13.169 verschillende LVD-resultaten uit 1981–2015 zijn al relaties met provinciale PQ vastgelegd: 8.006 met status exact en 5.163 met status waarschijnlijk. Daarachter zitten 13.247 relaties, omdat een resultaat meerdere relaties kan hebben. Gebruik deze bestaande relaties als beginpunt en controleer de opname als geheel voordat resultaten worden toegevoegd of samengevoegd.

De resterende 68.141 LVD-resultaten uit de selectie van 81.310 resultaten over 1959–2015 zijn niet automatisch nieuwe PQ-informatie. Uit de aanwezige opnamegegevens moet blijken welke locatie permanent is, of verschillende broncodes dezelfde locatie aanduiden en welke opnamen werkelijk nieuw zijn. Het ontbreken van een overlaprelatie bewijst geen onafhankelijkheid.

Bij NDFF ligt dat anders. `ndff_open_pq_koppeling` bevat 1.621.660 beoordelingsregels voor 810.830 waarnemingen, verdeeld over twee regelversies. Dat zijn geen 1,6 miljoen PQ-metingen. De versie `ndff-open-pq-poort-v2` onderscheidt 6.326 regels uit 1952–1980 als historische vegetatiecontext, 90.992 uit 1981–2025 als niet beoordeelbaar voor gelijkheid met PQ, en 713.512 uit 1700–2025 als niet van toepassing. Deze tabel bevat geen concrete opname-ID-koppeling en kan dus niet rechtstreeks als PQ-resultaat worden geïmporteerd.

Voor die 90.992 NDFF-regels betekent niet beoordeelbaar dat de huidige registratie nog geen bewezen relatie met een bepaalde PQ-opname levert. Vergelijk aanwezige datum, brontaxon, protocol, bronhouder, locatiekwaliteit en soortenlijst met LVD en de provinciale opnamen. Voeg pas informatie toe wanneer de relatie is onderbouwd. Een vervaagde ruimtelijke overlap is geen bewijs van dezelfde PQ.

Daarnaast staan in `Meijendel_bronnen` de gedocumenteerde duinvalleigegevens: 488 opnamen en 101.504 bedekkingsregels uit 2001, 2008 en 2018. Volgens het actuele bronregister ontbreken betrouwbare geometrieën bij de vaste Site-codes. Het model moet deze reeks later onder `pq_*` kunnen opnemen, maar de naamherziening geeft geen toestemming om haar nu naar de analytische database te promoveren. De bestaande uitsluiting van opname 18I01 blijft gelden. Deze contextreeks is hier op basis van het bronregister betrokken, niet opnieuw integraal geteld.

### Wat het PQ schema daarvoor nodig heeft

De huidige sleutels zijn ingericht op de provinciale levering. Eén globaal `pq_nummer` is onvoldoende wanneer verschillende organisaties hetzelfde nummer gebruiken. Behoud bestaande interne ID's en voeg brongebonden identificaties toe, bijvoorbeeld in `pq_bronkoppeling`, `pq_opname_bronkoppeling` en `pq_resultaat_bronkoppeling`.

Leg bron, versie, oorspronkelijk locatie- of opname-ID, intern ID, koppelmethode en bewijs vast. Meerdere broncodes mogen naar dezelfde PQ verwijzen wanneer die gelijkheid is vastgesteld. Nieuwe PQ's krijgen een eigen interne identiteit. Nieuwe broncodes worden nooit blind als bestaande provinciale nummers geïnterpreteerd.

Ook de resultaatvelden vragen aanpassing. Het huidige schema verlangt onder meer provinciale abundantie- en indicatorvelden bij iedere taxonregel. Een andere bron kan een andere bedekkingsschaal of vegetatielaag hebben. Bewaar oorspronkelijke waarde, schaal, eenheid en laag; leg een omzetting afzonderlijk vast. Ontbrekende indicatoren blijven onbekend en worden geen nul. Een LVD-boomlaag en kruidlaag met dezelfde soort mogen niet door een te grove opname–taxonsleutel worden samengevoegd.

Onderscheid aanvullende metadata, een nieuw resultaat, een tweede levering van hetzelfde resultaat en een conflict. Bewaar conflicterende waarden en het besluit over de primaire waarde. De provinciale selectie blijft reproduceerbaar, ook nadat andere bronnen zijn toegevoegd.

`pq_vegetatie_opname`, `pq_vegetatie_waarneming` en de overige bestaande PQ-tabellen blijven de inhoudelijke bestemming. Een soortenfamilie kan daar naar verwijzen; zij krijgt geen zelfstandige kopie van dezelfde bedekking. Algemene vegetatieopnamen zonder bewijs van een permanente locatie blijven buiten de PQ-familie.

## Hoe ingewikkeld is dit

Het volledige voorstel is een gegevensmigratie. De complexiteit zit vooral in identiteit, gemengde meetstructuren en behoud van de bestaande betekenis.

| Onderdeel | Zwaarte | Wat het vergt |
|---|---|---|
| Een afgebakende meetfamilie hernoemen | Beperkt tot middelgroot | Schema, verwijzingen, import en tests samen aanpassen. De vier huidige `ndff_libel_*`-tabellen zijn een afgebakend voorbeeld. |
| NDFF-waarnemingen naar echte groepsfamilies verdelen | Groot | Stabiele ID's, ruimtelijke beoordeling, protocollen, analysebesluiten en de 233 dubbele lidmaatschappen correct meenemen. |
| De zes externe datasets aansluiten | Middelgroot tot groot | 98.916 resultaten uit 1875–2025 per taxon en meetvorm toewijzen. Coleoptera is eenvoudiger af te bakenen dan STOWA. |
| Vangblik vanuit soortgroepen bereikbaar maken | Middelgroot | Taxonkoppelingen en gecontroleerde verwijzingen voor 60.560 resultaten uit 1953–1960, zonder dubbele telling. |
| Verspreide PQ-informatie samenbrengen | Groot | Bronsleutels, opnamen, lagen, bedekkingsschalen en overlap vergelijken. Bovendien leest Shiny de huidige PQ-afleiding al. |
| Vogels en bestaande toepassingen beschermen | Harde voorwaarde | Vogel-ID's, tabellen, berekeningen en scherminhoud gelijk houden; niet alleen controleren of een pagina opent. |

Een betrouwbare urenraming volgt pas uit een proef op een databasekopie. Het aantal nieuwe tabellen staat evenmin vast: sommige structuren worden hernoemd, andere verdeeld, en gedeelde ondersteuning blijft bijeen. De oude rekensom van 149 hernoemingen en veertien behouden namen geldt dus niet meer.

Taxonvertaling is noodzakelijk. `ndff_soorten` heeft 9.828 bronreferenties, Vangblik 275 bij de reeks 1953–1960, PQ 714 bij 1981–2025 en AVIMAP 35 bij 2009–2026. Externe ecologie heeft 2.894 verschillende opgeslagen wetenschappelijke naamwaarden bij de 98.916 resultaten uit 1875–2025, zonder gemeenschappelijke taxon-foreign-key. Behoud bronnamen, rang en versie en leg gecontroleerde overeenkomsten naast de bronidentiteit vast. De vogelgerichte tabel `soorten` blijft onaangetast.

## Bronvast werkzaamhedenmodel

De levende lokale database bevat naast de bestaande classificatie een afzonderlijke laag voor projecten, feitelijke of geplande uitvoeringen, expliciete jaarstatussen en bewijsbronnen. Op 14 oktober 2026 is deze laag aangevuld na controle van alle 807 actieve Zotero-bijlagen. De bestaande tabellen `maatregelen`, `maatregelen_kernwoorden` en `plot_jaar_maatregel` blijven bestaan. De vier algemene kernwoorden voor recreatiebeheer zijn onder de nieuwe hoofdklasse `rust_en_recreatiebeheer` geplaatst; `strandreservaat` blijft als specifiek kernwoord onder `strandreservaten` herkenbaar.

| Tabel of view | Records | Betekenis |
|---|---:|---|
| `maatregel_project` | 18 | Samenhangend project of programma; een project kan meerdere uitvoeringen bevatten. |
| `maatregel_bron` | 29 | 22 lokaal geraadpleegde Zotero-bronnen en zeven officiële webbronnen, ieder met type, datum, status en raadpleegdatum. |
| `maatregel_uitvoering` | 61 | Afzonderlijke werkzaamheden of expliciet niet-uitgevoerde, onbekende of geplande activiteiten. |
| `maatregel_uitvoering_jaar` | 100 | Letterlijk onderbouwde jaarstatussen uit 1967–2025: 84 uitgevoerd, 9 niet uitgevoerd en 7 onbekend. |
| `maatregel_uitvoering_bron` | 82 | Relaties tussen uitvoering en bewijsbron, met bronrol en bewijsnotitie. |
| `maatregel_geometrie` | 0 | Alleen voor later verkregen, bronvaste geometrieën in RD New. |
| `plot_gebied` | 8 | Vijf Meijendel-deelgebieden en drie speciale gebieden. |
| `plot_gebiedsindeling` | 1 | Vastgestelde indeling `vogelplot-gebiedsindeling-v1`, gekoppeld aan SOVON-plotversie 2025. |
| `plot_gebied_lidmaatschap` | 69 | Alle 55 actuele en 14 historische plots hebben precies één gebied. |
| `plot_gebied_geometrie` | 8 | Topologisch samengevoegde actuele kavelgeometrieën in RD New; samen afgeleid uit 55 plots. |
| `maatregel_uitvoering_gebied` | 2 | Voorlinden als locatie binnen M91 en begrazing vanaf 1990 voor Kijfhoek en Bierlap als volledig benoemd gebied. |
| `maatregel_plot_koppeling` | 95 | 36 eerder onderbouwde relaties, 32 geometrische naam–kavelrelaties voor zes uitvoeringen, 11 aanvullende relaties voor de volledige systemen Pan 13 en Plas 20, 3 relaties voor de sinds 1991 doorlopende begrazing van Helmduinen, 3 relaties voor de sinds eind 1997 doorlopende begrazing van de Kikkervalleien, 3 relaties voor het eenmalige bodem- en vegetatieherstel in 1997, 3 relaties voor het verwijderen van leidingen en putten van Sprang PI en I in 1997, 3 relaties voor Watercrassulabestrijding in de Kikkervallei en 1 gebruikersvastgestelde relatie voor Parnassiapad 2 in M15; het exacte werkoppervlak per kavel en dus het doorsnijdingspercentage blijven onbekend. |
| `v_plot_gebied_actueel` | 69 | Actuele leeslaag van de volledige vastgestelde gebiedsindeling. |
| `v_plot_gebied_geometrie_actueel` | 8 | Actuele leeslaag van de afgeleide gebiedsgeometrieën. |
| `v_plot_jaar_maatregel_bronvast` | 145 | Bronvaste plot-jaarregels voor expliciet benoemde kavels en gevalideerde gebiedsnamen in 1967–1969, 1972–1975, 1988–1991, 1993, 1997, 2005–2006 en 2017–2025. Voor doorlopende begrazing bevat de view het expliciet onderbouwde startjaar; voortzetting tot en met 2026 staat in status, open einddatum en cycliciteit. |

De referentietabellen `maatregel_werkcategorie`, `maatregel_type`, `maatregel_activiteit_type`, `maatregel_uitvoering_status` en `maatregel_brontype` scheiden categorie, activiteit, feitelijke status en brontype. Waar passend zijn de Natura 2000-codes MT01–MT07 en activiteitcodes A–G gebruikt; lokale aanvullingen hebben een eigen code. Een subsidie-openstelling, ontwerpplan of actuele werkzaamhedenpagina wordt niet als uitvoering behandeld zolang de feitelijke uitvoering niet is bevestigd.

De 144 bestaande regels in `plot_jaar_maatregel` blijven de historische dashboardlaag voor begrazing in 16 plots uit 1991–1999. Hun aantal en checksum `306480715648` zijn vóór en na de invoer op 14 oktober 2026 gelijk gebleven. Zij worden niet achteraf als bronvaste projectuitvoering geïnterpreteerd. Nieuwe werkzaamheden gaan pas naar een plot-jaarselectie nadat locatie, jaar en bron voldoende precies zijn vastgesteld.

De gebiedsindeling gebruikt de 55 geldige SOVON-kavelpolygonen uit plotversie 2025, in EPSG:28992. Daaruit zijn vijf geometrieën voor Buitenduin Noord, Buitenduin Zuid, Kijfhoek en Bierlap, Vallei Meijendel en Zuid-oosthoek en drie geometrieën voor Haagsche Golfclub, Voorlinden en Hertenkamp afgeleid. Interne overlap van telplots wordt bij de topologische samenvoeging niet dubbel als gebiedsoppervlak geteld. De 14 historische plots zijn inhoudelijk ingedeeld, maar hebben in plotversie 2025 geen afzonderlijke historische geometrie en worden daarom niet als geometriebron gebruikt.

De actuele aantallen bronplots per geometrie zijn respectievelijk 9, 7, 16, 9 en 11 voor de vijf Meijendel-deelgebieden en 1 voor ieder speciaal gebied. De indeling normaliseert de aangeleverde aanduiding M54q naar het bestaande plot M54a. Historisch M17 volgt M17a en ligt in Buitenduin Noord; M8/11, M8/9, M9 en M11 liggen in Kijfhoek en Bierlap.

## Nameninventaris en plotgeometrie

Versie `meijendel_nameninventaris_2026-10-14` is op 14 oktober 2026 in de levende lokale database opgenomen. De korrel is één naamobject, één bronvermelding of één brongeometrie; naamgeometrie bewijst niet automatisch de exacte grens van een uitgevoerde maatregel.

| Tabel of view | Records | Betekenis |
|---|---:|---|
| `nameninventaris_import` | 1 | Herkomst, hash, regelversie en verwachte aantallen van de levering. |
| `nameninventaris_bron` | 8 | Beekman 2021, twee historische artikelen, Neefjes 2010, TOP10NL, OSM en twee Dunea-bronnen. |
| `nameninventaris_object` | 182 | Onderscheiden gebieds-, functionele, pad-, weg- en routeobjecten. |
| `nameninventaris_vermelding` | 299 | Gedateerde naamvermeldingen uit 1602–2026. |
| `nameninventaris_geometrie` | 71 | Brongeometrieën in EPSG:28992 voor 71 objecten. |
| `nameninventaris_geometrie_bronobject` | 107 | Herleidbaarheid van samengevoegde geometrieën naar afzonderlijke bronobjecten. |
| `nameninventaris_beoordeling` | 111 | Actuele, expliciete geometrieleemten; deze namen worden niet ruimtelijk afgeleid. |
| `plot_geometrie_import` | 1 | Actuele SOVON-kavelgeometrie van 55 plots, versie `sovon-avimap-2025-download-2026-10-02`. |
| `nameninventaris_plot_koppeling` | 377 | Alle geometrische doorsnijdingen tussen 66 naamobjecten en 55 actuele kavels. |
| `v_nameninventaris_plot_actueel` | 365 | Actuele leeslaag voor 53 kavels binnen `meijendel_natura2000`; M66 en M91 zijn uitgesloten. |

De maatregelactualisering gebruikt deze laag alleen wanneer de maatregellocatie volledig en letterlijk overeenkomt met één of meer geometriseerde naamobjecten. Daarmee zijn 32 relaties voor zes uitvoeringen toegevoegd. Uitvoeringen met een brede locatie, een niet-geometriseerde naam, een gedeeltelijk geometriseerde samengestelde locatie of een afwijkende naam blijven buiten de automatische koppeling.

## Website dashboard en Shiny beschermen

De eerdere inventarisatie vond geen rechtstreeks gebruik van de 146 `ndff_*`-, vier `externe_ecologie_*`- en zes `vangblik*`-tabellen in de publieke website, reguliere Shiny-cache of openbare dashboardketen. Dat geeft ruimte, maar betekent niet dat die 156 tabellen losstaan. Imports, audits, ruimtelijke verwerking, bestaande views en exportvalidatie gebruiken ze wel. Voor deze herschrijving zijn de relevante cache- en exportcontracten opnieuw gecontroleerd; er is geen productieproef uitgevoerd.

PQ is wel aangesloten. Shiny leest `pq_plot_jaar_vegetatie` en gebruikt soortenrijkdom, bedekkingssom en Shannon in model- en omgevingsgegevens. De website leest de bestaande `website_plot_vegetatie_jaar`, die naar dezelfde PQ-afleiding verwijst. Foutafhandeling kan een leeg vegetatieonderdeel opleveren terwijl de pagina gewoon opent. Vergelijk daarom de 513 plot-jaarregels uit 1981–2025, waarden, ontbrekende waarden en bronvermelding vóór en na de structurele migratie.

Nieuwe PQ-opnamen mogen bij een afzonderlijk inhoudelijk besluit later doorwerken in de toepassingen. Het toevoegen van bronnen mag echter niet ongemerkt de provinciale controlebasis of bestaande vogelmodellen veranderen. Scheid structureel verplaatsen met gelijke uitkomsten van inhoudelijk verrijken met expliciet beoordeelde nieuwe uitkomsten.

Verder moeten deze afhankelijkheden mee:

- foreign keys, indexes, rechten en eventuele routines of triggers;
- bestaande views en beveiligde onderzoeksviews die naar openbare NDFF-tabellen verwijzen, met behoud van de beveiligingsgrens;
- dynamische tabelnamen in imports en audits, naast letterlijk geschreven namen;
- tabelnamen die als gegevens zijn opgeslagen, waaronder `analyse_datareeks.bron_object` en ruimtelijke bronverwijzingen;
- de exportcontrole die nu expliciet `ndff_open_waarneming` verlangt, plus de dump- en Shiny-cachecontracten.

Bronbestanden, bron-ID's, hashes en historische regelversies worden niet cosmetisch herschreven. Er komen geen nieuwe overzichts- of compatibiliteitsviews. Bestaande noodzakelijke views moeten bij een daadwerkelijke migratie correct blijven verwijzen.

## Veilige uitvoervolgorde

Eerst werken we één volledige familie uit op een geïsoleerde databasekopie. Libellen is daarvoor geschikt: 32.325 bronwaarnemingen uit 1950–2025, plus de bestaande route-, geometrie-, bezoek- en taxonbereikstructuur. De proef omvat meer dan vier namen veranderen. Zij moet bewijzen dat de groepsfamilie ook een tweede bron kan ontvangen zonder dubbele metingen, verlies van herkomst of wijziging van nulbetekenis. Een technische testlevering wordt als test gemarkeerd en wordt geen nieuwe ecologische bron.

Daarna volgt de PQ-uitwerking: brongebonden locatie- en opname-identiteit toevoegen en een afgebakende, reeds gekoppelde LVD-selectie vergelijken met de provinciale reeks. Begin met bevestigde overeenkomsten; behandel waarschijnlijke koppelingen afzonderlijk. Voor iedere kandidaat staat vast of deze verrijkt, toevoegt, dubbel is of conflicteert. De eerste acceptatie-eis is behoud van de bestaande 513 plot-jaaruitkomsten uit 1981–2025.

Vervolgens volgen de overige soortenfamilies in samenhangende groepen. Kevers zijn een bruikbare tweede soortproef omdat NDFF, Naturalis en Vangblik daar samenkomen. Gemengde monsters en de algemene beslis- en bronlaag gaan pas over wanneer hun volledige verwijzingsketen is uitgewerkt.

Iedere proef levert een concrete oude–nieuwe objectkaart, sleutelvertaling, importaanpassing en herstelprocedure op. Vergelijk volledige sleutelsets, aantallen, inhoudshashes, bronverwijzingen, nulstatussen en toegelaten selecties. Een verschil is verklaard of blokkeert de overgang. Controleer tevens herhaalde import: hetzelfde bestand mag geen extra metingen opleveren.

Pas na goedkeuring volgt uitvoering in de levende lokale database, met gecontroleerde back-up en zonder gelijktijdige imports. Daarna volgt de normale gevalideerde dump-, cache- en releaseketen. Productie blijft afnemer van de lokale canonieke database. Herstel bestaat uit een geteste schema- en gegevensherstelroute met de bijpassende codeversie; een algemene transactie-rollback is onvoldoende voor DDL-wijzigingen.

De aanbevolen eerstvolgende stap is een concreet libellenproefontwerp, inclusief fysieke tabellen en migratiecontroles. Geen brede live-hernoeming. PQ blijft een eigen, bronoverstijgende familie en wordt expliciet als volgende migratieproef uitgewerkt.

## Onderbouwing en grenzen

Groepen, rijtellingen en bronverdelingen zijn read-only gecontroleerd in de levende lokale database op 26 september 2026. Van de 248 fysieke tabellen staan er 163 in de bijlage: 146 NDFF, vier externe ecologie, zes Vangblik en zeven PQ. Ook de niet-vogelgegevens in AVIMAP zijn onderzocht.

De bijlage geeft bestemmingsrichtingen, geen uitvoerbare naamskaart. Rijtellingen stammen uit de nulmeting van dezelfde datum. Niet alle reconstructietabellen hebben een afzonderlijk gecontroleerde meetperiode; hun technische rijaantallen zijn geen zelfstandige meetreeks.

Geraadpleegd zijn de projectinstructies, README, TODO, DECISIONS, architectuur, eerdere inventaris en `docs/MEIJENDEL_BRONREGISTER.md`; de openbare NDFF-, protocolkwaliteit- en externe-ecologieschema's; import- en overlapdefinities; Shiny `helpers.R`, cachecontracttest, exportvalidator en websitequery voor plotvegetatie.

Bronrechten, toelating en bruikbaarheid zijn niet opnieuw vastgesteld; het bronregister blijft leidend. Geen T7- of NAS-bestanden geopend, nieuwe bronnen aangevraagd of database, dump, cache en productie gewijzigd.

## Bijlage huidige tabellen en bestemmingsrichting

Alle 163 tabelnamen blijven hier terugvindbaar. De aantallen zijn technische rijtellingen van 26 september 2026, geen optelbare onafhankelijke waarnemingen. Een richting met meerdere bestemmingen vereist gegevensverdeling; zij is geen RENAME-opdracht. Definitieve doelnamen en sleutelvertalingen worden in de migratieproef getoetst.

### Soortgroepindexen

Voor elk van deze 26 indexen geldt: de bestemming wordt een volwaardige bronoverstijgende familie. Alleen de huidige enkelkolomsindex hernoemen is niet het eindbeeld.

| Huidige tabel | Records | Bestemmingsrichting |
|---|---:|---|
| `ndff_amfibieen` | 12.982 | `amfibieen_*` |
| `ndff_dagvlinders` | 129.238 | `dagvlinders_*` |
| `ndff_eencelligen` | 156 | `eencelligen_*` |
| `ndff_geleedpotigen_overig` | 426 | `geleedpotigen_overig_*` |
| `ndff_insecten_overig` | 1.888 | `insecten_overig_*` |
| `ndff_kevers` | 8.079 | `kevers_*` |
| `ndff_korstmossen` | 28.643 | `korstmossen_*` |
| `ndff_kranswieren_wieren_algen` | 555 | `kranswieren_wieren_algen_*` |
| `ndff_kreeftachtigen` | 2.052 | `kreeftachtigen_*` |
| `ndff_libellen` | 32.325 | `libellen_*` |
| `ndff_microvlinders` | 22.849 | `microvlinders_*` |
| `ndff_mossen` | 32.353 | `mossen_*` |
| `ndff_nachtvlinders` | 72.978 | `nachtvlinders_*` |
| `ndff_ongewervelden_overig` | 1.760 | `ongewervelden_overig_*` |
| `ndff_reptielen` | 3.347 | `reptielen_*` |
| `ndff_schimmels` | 77.724 | `schimmels_*` |
| `ndff_snavelinsecten` | 7.819 | `snavelinsecten_*` |
| `ndff_spinachtigen` | 2.480 | `spinachtigen_*` |
| `ndff_sprinkhanen_en_krekels` | 9.163 | `sprinkhanen_en_krekels_*` |
| `ndff_vaatplanten` | 277.812 | `vaatplanten_*` |
| `ndff_vissen` | 1.280 | `vissen_*` |
| `ndff_vleermuizen` | 9.912 | `vleermuizen_*` |
| `ndff_vliegen_en_muggen` | 10.495 | `vliegen_en_muggen_*` |
| `ndff_vliesvleugeligen` | 12.365 | `vliesvleugeligen_*` |
| `ndff_weekdieren` | 13.043 | `weekdieren_*` |
| `ndff_zoogdieren_overig` | 39.339 | `zoogdieren_overig_*` |

### Soortgerichte meetstructuren

| Huidige tabel | Records | Bestemmingsrichting |
|---|---:|---|
| `ndff_amfibie_bezoek` | 211 | `amfibieen_bezoek` |
| `ndff_amfibie_waterbezoek` | 1.300 | `amfibieen_waterbezoek` |
| `ndff_amfibie_waterbezoek_taxon` | 9.100 | `amfibieen_waterbezoek_taxon` |
| `ndff_amfibie_waterfamilie` | 50 | `amfibieen_waterfamilie` |
| `ndff_amfibie_watergeometrie` | 52 | `amfibieen_watergeometrie` |
| `ndff_bospaddenstoel_bezoek` | 110 | `schimmels_bospaddenstoel_bezoek` |
| `ndff_bospaddenstoel_bezoek_taxon` | 2.934 | `schimmels_bospaddenstoel_bezoek_taxon` |
| `ndff_bospaddenstoel_doelbereik` | 76 | `schimmels_bospaddenstoel_doelbereik` |
| `ndff_bospaddenstoel_geometrie` | 6 | `schimmels_bospaddenstoel_geometrie` |
| `ndff_bospaddenstoel_jaar_taxon` | 977 | `schimmels_bospaddenstoel_jaar_taxon` |
| `ndff_bospaddenstoel_meetpunt` | 3 | `schimmels_bospaddenstoel_meetpunt` |
| `ndff_bospaddenstoel_recordselectie` | 982 | `schimmels_bospaddenstoel_recordselectie` |
| `ndff_bospaddenstoel_verspreiding_bezoek` | 2 | `schimmels_bospaddenstoel_verspreiding_bezoek` |
| `ndff_bospaddenstoel_verspreiding_bezoek_taxon` | 14 | `schimmels_bospaddenstoel_verspreiding_bezoek_taxon` |
| `ndff_bospaddenstoel_verspreiding_recordselectie` | 14 | `schimmels_bospaddenstoel_verspreiding_recordselectie` |
| `ndff_korstmos_bezoek` | 32 | `korstmossen_bezoek` |
| `ndff_korstmos_bezoek_taxon` | 960 | `korstmossen_bezoek_taxon` |
| `ndff_korstmos_doelbereik` | 30 | `korstmossen_doelbereik` |
| `ndff_korstmos_meetlocatie` | 12 | `korstmossen_meetlocatie` |
| `ndff_korstmos_recordselectie` | 364 | `korstmossen_recordselectie` |
| `ndff_mos_datumcluster` | 21 | `mossen_datumcluster` |
| `ndff_mos_doelbereik` | 111 | `mossen_doelbereik` |
| `ndff_mos_inventarisatie` | 7 | `mossen_inventarisatie` |
| `ndff_mos_inventarisatie_taxon` | 777 | `mossen_inventarisatie_taxon` |
| `ndff_mos_recordselectie` | 376 | `mossen_recordselectie` |
| `ndff_braakbal_hokjaar` | 37 | `zoogdieren_overig_braakbal_hokjaar` |
| `ndff_braakbal_hokjaar_taxon` | 226 | `zoogdieren_overig_braakbal_hokjaar_taxon` |
| `ndff_braakbal_recordselectie` | 389 | `zoogdieren_overig_braakbal_recordselectie` |
| `ndff_konijn_hokdatum_taxon` | 5.084 | `zoogdieren_overig_konijn_hokdatum_taxon` |
| `ndff_konijn_recordselectie` | 5.809 | `zoogdieren_overig_konijn_recordselectie` |
| `ndff_otter_bever_hokjaar` | 1 | `zoogdieren_overig_otter_bever_hokjaar` |
| `ndff_otter_bever_hokjaar_taxon` | 1 | `zoogdieren_overig_otter_bever_hokjaar_taxon` |
| `ndff_otter_bever_recordselectie` | 3 | `zoogdieren_overig_otter_bever_recordselectie` |
| `florbase_doelbereik` | 857 | `vaatplanten_florbase_doelbereik` |
| `florbase_inventarisatie` | 183 | `vaatplanten_florbase_inventarisatie` |
| `florbase_inventarisatie_taxon` | 101.126 | `vaatplanten_florbase_inventarisatie_taxon` |
| `florbase_recordselectie` | 21.161 | `vaatplanten_florbase_recordselectie` |
| `hns_doelbereik` | 1.406 | `vaatplanten_hns_doelbereik` |
| `hns_hok_jaar_taxon` | 16.872 | `vaatplanten_hns_hok_jaar_taxon` |
| `hns_inventarisatie` | 52 | `vaatplanten_hns_inventarisatie` |
| `hns_inventarisatie_taxon` | 32.338 | `vaatplanten_hns_inventarisatie_taxon` |
| `hns_recordselectie` | 9.138 | `vaatplanten_hns_recordselectie` |
| `ndff_libel_bezoek` | 461 | `libellen_bezoek` |
| `ndff_libel_bezoek_taxon` | 13.173 | `libellen_bezoek_taxon` |
| `ndff_libel_routefamilie` | 9 | `libellen_routefamilie` |
| `ndff_libel_routegeometrie` | 18 | `libellen_routegeometrie` |
| `lmfa_bezoek` | 124 | `vaatplanten_lmfa_bezoek` |
| `lmfa_bezoek_taxon` | 9.300 | `vaatplanten_lmfa_bezoek_taxon` |
| `lmfa_doelsoort` | 75 | `vaatplanten_lmfa_doelsoort` |
| `lmfa_recordselectie` | 5.980 | `vaatplanten_lmfa_recordselectie` |
| `lmfa_route` | 30 | `vaatplanten_lmfa_route` |
| `ndff_nachtvlinder_hokjaar` | 5 | `nachtvlinders_hokjaar` |
| `ndff_nachtvlinder_hokjaar_taxon` | 84 | `nachtvlinders_hokjaar_taxon` |
| `ndff_nachtvlinder_recordselectie` | 596 | `nachtvlinders_recordselectie` |
| `ndff_vliesvleugel_bezoek` | 217 | `vliesvleugeligen_bezoek` |
| `ndff_vliesvleugel_bezoek_taxon` | 1.302 | `vliesvleugeligen_bezoek_taxon` |
| `ndff_vliesvleugel_routefamilie` | 2 | `vliesvleugeligen_routefamilie` |
| `ndff_vliesvleugel_routegeometrie` | 40 | `vliesvleugeligen_routegeometrie` |
| `ndff_vlinder_bezoek` | 3.126 | `dagvlinders_bezoek` |
| `ndff_vlinder_bezoek_taxon` | 102.489 | `dagvlinders_bezoek_taxon` |
| `ndff_vlinder_route_identificatie` | 11 | `dagvlinders_route_identificatie` |
| `ndff_vlinder_routefamilie` | 11 | `dagvlinders_routefamilie` |
| `ndff_vlinder_routegeometrie` | 455 | `dagvlinders_routegeometrie` |
| `ndff_habslak_hokjaar` | 66 | `weekdieren_habslak_hokjaar` |
| `ndff_habslak_monster` | 251 | `weekdieren_habslak_monster` |
| `ndff_habslak_monster_taxon` | 1.730 | `weekdieren_habslak_monster_taxon` |
| `ndff_habslak_recordselectie` | 2.772 | `weekdieren_habslak_recordselectie` |
| `ndff_poldervis_bezoek` | 6 | `vissen_poldervis_bezoek` |
| `ndff_poldervis_bezoek_taxon` | 19 | `vissen_poldervis_bezoek_taxon` |
| `ndff_poldervis_recordselectie` | 20 | `vissen_poldervis_recordselectie` |
| `ndff_poldervis_waterlocatie` | 3 | `vissen_poldervis_waterlocatie` |
| `ndff_reptiel_bezoek` | 660 | `reptielen_bezoek` |
| `ndff_reptiel_bezoek_taxon` | 1.320 | `reptielen_bezoek_taxon` |
| `ndff_reptiel_routefamilie` | 14 | `reptielen_routefamilie` |
| `ndff_reptiel_routegeometrie` | 71 | `reptielen_routegeometrie` |
| `ndff_vleermuis_bezoek` | 44 | `vleermuizen_bezoek` |
| `ndff_vleermuis_bezoek_taxon` | 242 | `vleermuizen_bezoek_taxon` |
| `ndff_vleermuis_recordselectie` | 2.624 | `vleermuizen_recordselectie` |
| `ndff_vleermuis_routefamilie` | 2 | `vleermuizen_routefamilie` |
| `ndff_vleermuis_routegeometrie` | 2.023 | `vleermuizen_routegeometrie` |
| `ndff_zeereep_bezoek` | 322 | `schimmels_zeereep_bezoek` |
| `ndff_zeereep_bezoek_taxon` | 1.932 | `schimmels_zeereep_bezoek_taxon` |
| `ndff_zeereep_kilometerhok` | 42 | `schimmels_zeereep_kilometerhok` |

### Gemengde meetstructuren

| Huidige tabel | Records | Bestemmingsrichting |
|---|---:|---|
| `ndff_ravon_n2000_monsterlocatieproxy` | 25 | Amfibieën en vissen scheiden; gedeeld monster behouden |
| `ndff_ravon_n2000_recordselectie` | 67 | Amfibieën en vissen scheiden; gedeeld monster behouden |
| `daz_bmp_bezoek` | 1.519 | Niet-vogelgroepen; primaire AVIMAP en vogelketen beschermen |
| `daz_bmp_bezoek_taxon` | 10.453 | Niet-vogelgroepen; primaire AVIMAP en vogelketen beschermen |
| `daz_bmp_recordkandidaat` | 5.404 | Niet-vogelgroepen; primaire AVIMAP en vogelketen beschermen |
| `daz_bmp_recordselectie` | 10.670 | Niet-vogelgroepen; primaire AVIMAP en vogelketen beschermen |
| `ndff_kwartiertelling_interval_soortgroep` | 18 | Gemengde events behouden; groepsresultaten en telbereik herkenbaar verdelen |
| `ndff_kwartiertelling_interval_taxon` | 49 | Gemengde events behouden; groepsresultaten en telbereik herkenbaar verdelen |
| `ndff_kwartiertelling_recordselectie` | 102 | Gemengde events behouden; groepsresultaten en telbereik herkenbaar verdelen |
| `ndff_kwartiertelling_telinterval` | 17 | Gemengde events behouden; groepsresultaten en telbereik herkenbaar verdelen |
| `ndff_liveatlas_bezoek` | 64 | Gemengde events behouden; groepsresultaten en telbereik herkenbaar verdelen |
| `ndff_liveatlas_bezoek_soortgroep` | 87 | Gemengde events behouden; groepsresultaten en telbereik herkenbaar verdelen |
| `ndff_liveatlas_bezoek_taxon` | 169 | Gemengde events behouden; groepsresultaten en telbereik herkenbaar verdelen |
| `ndff_liveatlas_recordselectie` | 231 | Gemengde events behouden; groepsresultaten en telbereik herkenbaar verdelen |
| `ndff_tuintelling_geometrie` | 6 | Gemengde events behouden; groepsresultaten en telbereik herkenbaar verdelen |
| `ndff_tuintelling_periode_soortgroep` | 213 | Gemengde events behouden; groepsresultaten en telbereik herkenbaar verdelen |
| `ndff_tuintelling_periode_soortgroep_taxon` | 1.645 | Gemengde events behouden; groepsresultaten en telbereik herkenbaar verdelen |
| `ndff_tuintelling_recordselectie` | 309 | Gemengde events behouden; groepsresultaten en telbereik herkenbaar verdelen |
| `ndff_tuintelling_telperiode` | 125 | Gemengde events behouden; groepsresultaten en telbereik herkenbaar verdelen |
| `ndff_tuintelling_tuinvakfamilie` | 3 | Gemengde events behouden; groepsresultaten en telbereik herkenbaar verdelen |

### Gedeelde bron en beslislaag

| Huidige tabel | Records | Bestemmingsrichting |
|---|---:|---|
| `ndff_open_import_batch` | 1 | Bronregistratie behouden en bronoverstijgend verbinden |
| `ndff_open_waarneming` | 810.830 | Biologische inhoud per soortgroep; stabiele bron- en meetidentiteit behouden |
| `ndff_soorten` | 9.828 | Bronreferenties behouden; koppelen aan groepsreferenties, nooit vogel-soorten vervangen |
| `ndff_open_soortgroep_koppeling` | 811.063 | Groepsindeling behouden; primaire opslaggroep en nevenlabels onderscheiden |
| `ndff_open_waarneming_protocol` | 810.830 | Protocolrelatie aan stabiele meting; bron- en regelversie behouden |
| `ndff_open_leveringsverrijking` | 14.420 | Verrijking bij dezelfde meting; niet als nieuwe waarneming tellen |
| `ndff_open_ruimtelijke_beoordeling` | 810.830 | Ruimtelijke beoordeling aan meting behouden |
| `ndff_open_pq_koppeling` | 1.621.660 | PQ-beoordeling onder pq_*; pas na bewijs concrete opnamekoppeling |
| `ndff_protocol` | 54 | Gedeeld protocolregister; organisatie niet als hoofdindeling |
| `ndff_protocol_gebruik` | 54 | Gedeelde gebruiksregels; bestaande beslisbetekenis behouden |
| `ndff_protocol_mapping` | 91 | Gedeelde vertaling bronprotocol naar meetmethode |
| `ndff_protocol_soort_geschiktheid` | 664 | Geschiktheid verbinden met taxon en groep |
| `ndff_protocol_soortgroep_geschiktheid` | 228 | Geschiktheid verbinden met groep |
| `ndff_analysebesluit` | 4.160 | Gedeelde beslislaag; referenties en regelversies behouden |
| `ndff_snl_waarneming_context` | 6.273 | Broncontext aan dezelfde meting behouden |
| `ndff_sovon_plot` | 55 | Gedeelde plotreferentie; vogelketen beschermen |
| `ndff_sovon_plotversie` | 1 | Gedeelde plotversie; vogelketen beschermen |

### Externe ecologie

| Huidige tabel | Records | Bestemmingsrichting |
|---|---:|---|
| `externe_ecologie_dataset` | 6 | Naar gedeelde bronregistratie; alle zes datasets herkenbaar houden |
| `externe_ecologie_event` | 10.994 | PQ-opnamen naar pq_*; overige events naar groep of gedeeld gemengd event |
| `externe_ecologie_resultaat` | 98.916 | Per taxon en meetvorm naar soortgroep; PQ-resultaten naar pq_* |
| `externe_ecologie_overlap` | 87.053 | Overlaprelaties behouden aan bronresultaten en stabiele meetidentiteit |

### Vangblik

| Huidige tabel | Records | Bestemmingsrichting |
|---|---:|---|
| `vangblik_import_batch` | 1 | Behouden; vanuit kevers_* en zoogdieren_overig_* koppelen |
| `vangblik_locatieversie` | 135 | Behouden; vanuit kevers_* en zoogdieren_overig_* koppelen |
| `vangblik_event` | 37.770 | Behouden; vanuit kevers_* en zoogdieren_overig_* koppelen |
| `vangblik_event_plot` | 37.770 | Behouden; vanuit kevers_* en zoogdieren_overig_* koppelen |
| `vangblik_soorten` | 275 | Behouden; vanuit kevers_* en zoogdieren_overig_* koppelen |
| `vangblik_vangst` | 60.560 | Behouden; vanuit kevers_* en zoogdieren_overig_* koppelen |

### PQ

| Huidige tabel | Records | Bestemmingsrichting |
|---|---:|---|
| `pq_vegetatie_import` | 1 | Behouden binnen bronoverstijgende PQ-structuur |
| `pq_vegetatie_pq` | 254 | Behouden binnen bronoverstijgende PQ-structuur |
| `pq_vegetatie_opname` | 2.007 | Behouden binnen bronoverstijgende PQ-structuur |
| `pq_vegetatie_opname_plot` | 1.336 | Behouden binnen bronoverstijgende PQ-structuur |
| `pq_vegetatie_taxon` | 714 | Behouden binnen bronoverstijgende PQ-structuur |
| `pq_vegetatie_waarneming` | 53.122 | Behouden binnen bronoverstijgende PQ-structuur |
| `pq_plot_jaar_vegetatie` | 513 | Behouden binnen bronoverstijgende PQ-structuur |
