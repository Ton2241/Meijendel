# Lange indexsamenvatting vergeleken met begin en einde

Afgerond op 3 november 2026. Meijendel-ontwikkelbron 1958–2025: vier soorten,
52 oorspronkelijke kavelclusters, exact dezelfde 50 trekkingen en bestaande
jaarindices. Geen TRIM- of vogeltelmodel opnieuw geschat.

De nulvriendelijke helling is berekenbaar, maar beschrijft een andere grootheid
dan de verandering tussen begin en einde. Vooral Tapuit en Koolmees tonen
een groot verschil. Eén gemiddeld jaarpercentage vertelt onvoldoende hoe de
populatie zich door de tijd heeft ontwikkeld. Dit onderzoek kiest geen nieuwe
hoofdindex of algemene productiemethode.

## Vooraf gekozen vergelijking

[CRITERIA.md](CRITERIA.md), commit `58a093ba`, is vóór deze berekening vastgelegd.
De hoofdvensters zijn 1958–1962 en 2021–2025. De driejaarscontrole vergelijkt
1958–1960 met 2023–2025; de zevenjaarscontrole 1958–1964 met 2019–2025.
Geen gunstige jaren gezocht, geen nuljaar verwijderd en geen ontbrekend jaar
als nul ingevuld. Alle 68 vaste jaren horen in iedere geldige reeks aanwezig
te zijn. De oorspronkelijke vijfjaarsbrug blijft gelijk.

De exponentiële samenvatting past de eerder verkende quasi-Poisson-regressie
met loglink toe op de bestaande index. Dit is geen telmodel van ruwe
vogelaantallen. Zij gebruikt alle 68 jaren om één percentage te berekenen;
de getekende exponentiële lijn laat zien welk constant verloop daarbij hoort.
Deze lijn is geen gevalideerde tijdcurve. GLM-standaardfouten en p-waarden
worden niet gebruikt.

De venstermaat vergelijkt de rekenkundige gemiddelden aan begin en einde.
De nettoverandering is 100 ×(eind/begin −1). Alleen als beide gemiddelden positief
zijn wordt ook een jaarlijks equivalent berekend. Voor vijfjaarsvensters
liggen de middelpunten 63 jaar uit elkaar. Bij een nuleinde is de nettoverandering
−100%,  zonder jaarlijks percentage; bij een nulbegin is een procentuele
verhouding niet gedefinieerd. Zulke gevallen worden niet met een pseudowaarde
opgelost. In deze vier soorten zijn alle geldige primaire venstergemiddelden
positief.

De vooraf gekozen verschillen van maximaal 1 procentpunt of 20% van de absolute primaire helling en richtingafwijkingen zijn
aandachtssignalen. Het zijn geen eisen dat verschillende samenvattingen
dezelfde betekenis of uitkomst moeten hebben.

## Uitgangsbron per soort

Onderstaande percentages beschrijven de bestaande gekoppelde jaarindex,
geen direct opgetelde ruwe tellingen.

| Soort | Nulvriendelijke helling per jaar | Netto begin/einde | Jaarlijks equivalent begin/einde | Geldig in 50 trekkingen |
|---|---:|---:|---:|---:|
| Veldleeuwerik | −4,57% | −93,02% | −4,14% | 50/50 |
| Torenvalk | −2,75% | −90,72% | −3,70% | 49/50 |
| Tapuit | −4,13% | −99,65% | −8,58% | 50/50 |
| Koolmees | +2,29% | +710,67% | +3,38% | 50/50 |

**Veldleeuwerik.** De primaire twee jaarpercentages liggen dicht bij elkaar.
De afzonderlijke indexsamenvattingen zijn echter +3,12% vóór 1984 en −7,40%
vanaf 1984: aanvankelijke groei en latere afname worden samengevouwen.
De begin/eindafname is bij drie-, vijf- en zevenjaarsvensters respectievelijk
91,98%, 93,02% en 94,49%. In trekking 11 geeft de primaire venstermaat
+109,17%,  terwijl de exponentiële samenvatting −2,32% per jaar is. Deze
uitkomst blijft staan. De andere 49 trekkingen geven een nettoafname; dit is
geen formele kansuitspraak. De richting van een gemiddeld jaarpercentage
is dus niet in iedere trekking hetzelfde als de begin/eindverandering.

**Torenvalk.** Beide hoofdmaten tonen afname. De nulvriendelijke
periodehellingen zijn −8,62% en −8,23%. De jaarreeks heeft wel grote
schommelingen; een gladde exponentiële lijn mist die structuur.
De begin/eindafname varieert van 97,19% bij driejaarsvensters naar 89,22%
bij zevenjaarsvensters; primair 90,72%. De jaarlijkse equivalenten zijn
−5,35%, −3,70% en −3,59%. De korte eindperiode wordt sterk door incidentele
positieve jaren beïnvloed. Trekking 28 heeft de reeds bekende onschatbare
nulvensterbrug: beide lange samenvattingen blijven daar onberekenbaar.

**Tapuit.** De primaire begin/eindafname van 99,65% is helder, maar
−4,13% als gemiddeld jaarpercentage geeft een ander beeld dan het
jaarlijkse equivalent van −8,58%. Alle 50 gepaarde trekkingen overschrijden
de vooraf gekozen praktische verschilmarge. De periodehellingen zijn
+5,36% vóór 1984 en −24,80% vanaf 1984. De lange exponentiële lijn ligt in
2005–2025 duidelijk boven de bestaande vrijwel nul zijnde index. Zij
beschrijft de tussenliggende groei en daaropvolgende sterke afname dus
slecht als één constant pad. De nettoafname blijft bij alle drie
vensterbreedten 99,25–99,75%. Dit ondersteunt een beschrijvende vergelijking
van begin en einde, geen gevalideerde constante jaarlijkse afname.

**Koolmees.** De index groeit aanvankelijk sterk; de periodehellingen zijn
+9,69% vóór 1984 en +0,06% vanaf 1984. Een lange exponentiële lijn suggereert
daarentegen voortgaande groei. De begin/eindtoename is 710,67%; bij drie en
zeven jaar 795,38% en 775,10%. Het jaarlijkse equivalent van +3,38% is
merkbaar hoger dan de samenvatting van +2,29%. In 31 van 50 gepaarde trekkingen
wordt de praktische verschilmarge overschreden. Dat Koolmees in de vorige
proef het flexibele telmodel doorstond, betekent niet dat deze rechte
exponentiële indexsamenvatting hetzelfde beschrijft.

## Dezelfde 50 trekkingen en hun beperkingen

| Soort | Mediaan nulvriendelijke helling | Mediaan netto begin/einde | Kleinste–grootste nettoverandering | Gepaard jaarlijks verschil* |
|---|---:|---:|---:|---:|
| Veldleeuwerik | −4,75% | −91,40% | −99,14 tot +109,17% | −0,86 procentpunt; 50 paren |
| Torenvalk | −2,55% | −91,49% | −99,85 tot −19,90% | +0,98 procentpunt; 49 paren |
| Tapuit | −4,04% | −99,73% | −99,99997 tot −97,57% | +4,59 procentpunt; 50 paren |
| Koolmees | +2,30% | +708,35% | +430,42 tot +1161,56% | −1,10 procentpunt; 50 paren |

*Mediaan van nulvriendelijke helling minus het jaarlijkse jaarlijkse equivalent
binnen dezelfde geldige trekking. Geen verschil van los berekende medianen.
De nulvriendelijke aantallen en medianen reproduceren de eerdere verkenning
exact. De ruwe tabellen bewaren meer decimalen dan de leesbare tabellen.

De kleinste en grootste uitkomst zijn beschrijvend. Dit zijn geen 95%-grenzen.
Vijftig trekkingen zijn onvoldoende voor formele staarten of dekkingscontrole.
Een geldige berekening is geen bewijs van een goed gekozen samenvatting.
De bootstrap kan de systematische keuze tussen deze grootheden niet oplossen.

## Kaveldekking afzonderlijk beoordeeld

De eerste vijf jaar bevatten voor iedere soort 69 getelde kaveljaarcellen op
15 kavels. In 2021–2025 zijn dat voor Veldleeuwerik 111 cellen op 24 kavels,
Torenvalk 202 op 46, Tapuit 191 op 42 en Koolmees 222 op 51. Dit zijn de
soortspecifieke getelde cellen in de bewaarde ontwikkelcontext, geen nieuwe
inventarisatie van de database. [coverage.csv](coverage.csv) bewaart ook
positieve cellen en oppervlaktegecorrigeerde sommen. Ruwe sommen uit deze
vensters zijn door de verschillende teldekking geen rechtstreekse trendmaat.

De jaarindex bevat correcties en aanvulling door de bestaande modelroute;
de venstervergelijking erft de beperkingen daarvan. Zij maakt niet alsnog
alle 52 kavels in 1958 waargenomen. De eerder uitgevoerde proef met 17 historische
kernkavels verandert de kavelpopulatie ten opzichte van het volledige netwerk.
Het grote verschil bij Tapuit kan daarom ook ruimtelijke verschillen in
ontwikkeling weerspiegelen. Die proef is een aandachtspunt voor het
geografische bereik, geen zelfstandige afkeurtest voor deze samenvatting.
Een gelijkblijvende geografische populatie is hiermee niet aangetoond.

## Inhoudelijk advies en afgerond werk

Voor een leesbare beschrijving van de lange verandering heeft de
begin/eindvergelijking naast de volledige jaarreeks hier de voorkeur boven
één gemiddeld jaarlijks percentage. Zij zegt concreet wat wordt vergeleken.
Toon de vaste vensters en gevoeligheid voor drie/zeven jaar erbij. Gebruik
het jaarlijkse equivalent alleen als rekensamenvatting, niet als werkelijk
gevolgd groeipad. De twee afzonderlijke perioden blijven daarnaast zichtbaar.
Dit is een advies uit deze vier-soortenproef, geen algemene vrijgave voor
alle 156 soorten of wijziging van de gekozen productie-index.

De nulvriendelijke helling blijft als beschrijvende vergelijking beschikbaar.
De grote verschillen zijn geen rekenfout die met meer trekkingen verdwijnt.
Een soort met onschatbare brug krijgt geen geforceerde lange trend. Ook
onzekerheid rond de begin/eindmaat vraagt verdere validatie; die wordt
niet door deze 50 uitkomsten geleverd. De vraag welke kavelpopulatie de
lange index beoogt te vertegenwoordigen blijft inhoudelijk open.

Geen nieuwe telmodellen, bruggen, trekkingen, 2026-gegevens, database-,
cache- of productiewijzigingen; geen 500/2.000-run. De opzet en de feitelijke
beoordeling zijn afgerond. Een algemene methodekeuze is niet uitgevoerd.

## Bewijs en reproductie

- [summary.csv](summary.csv), [estimates.csv](estimates.csv): vier
  soortoverzichten en 612 soort-trekking-vensterregels, inclusief de baseline.
- [curves.csv](curves.csv): 544 jaarwaarden voor bronindex en exponentiële
  vergelijking; [coverage.csv](coverage.csv): acht dekkingsoverzichten.
- [Veldleeuwerik](curve_150.png), [Torenvalk](curve_64.png),
  [Tapuit](curve_173.png), [Koolmees](curve_214.png).
- [manifest.json](manifest.json): bron-, criteria-, code- en inputchecksums,
  de 50 ongewijzigde draw-identiteiten en nul nieuwe vogeltelmodelfits.

Reproduceerbaar met R/compare_trim_index_summaries.R REPO PILOTRUN UITVOER.
De helpercheck R/check_trim_index_summaries.R controleert exact exponentieel
en constant verloop, schaalinvariantie, behoud van nullen, nul begin/einde,
vaste vensters en afwijzing van ontbrekende/dubbele kalenderjaren.

## Verificatie

De voorafcriteria zijn bytegelijk aan commit `58a093ba` en de codechecksum
komt overeen met het manifest. De bestaande nulvriendelijke aantallen en
medianen zijn gereproduceerd. Onafhankelijke herberekening op alle 50bewaarde
trekkingen en drie vensterbreedten bevestigt 612 regels, 544 curvewaarden,
vier samenvattingen en alle gepaarde aantallen; maximale numerieke
vensterafwijking 5,0×10⁻¹². De 50 draw-identiteiten zijn exact gelijk.
De gerichte R-check slaagt voor exponentieel/constant verloop, schaal,
nullen en ontbrekende/dubbele jaren. Vier bestaande hoofd-CSV's hebben
hun eerdere checksum behouden. De vier figuren zijn afzonderlijk bekeken.
De nieuwe registerparagraaf is inhoudelijk gelijk in Markdown en Word;
alle 60gerenderde Wordpagina's zijn visueel gecontroleerd zonder defecten.
