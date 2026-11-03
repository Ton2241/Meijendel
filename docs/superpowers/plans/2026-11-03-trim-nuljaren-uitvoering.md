# Uitvoering nuljarenbeleid vóór invoer van 2026

> Uitvoering: superpowers:executing-plans; noodzakelijke code eerst RED→GREEN.

**Doel:** overgenomen advies uitvoeren op de bestaande bron 1958–2025:
45 overall-uitkomsten beveiligen en vier soorten inhoudelijk vergelijken.
**Spec:** `trim/bootstrap/pilot_2025_50_20261102/main_index_zeros/README.md`
en het uitdrukkelijke uitvoeringsakkoord van Ton op 3 november 2026.
**Architectuur:** gedeelde trendcontractfunctie blokkeert onbeoordeelde
nulcorrectie; historische trendtabellen krijgen dezelfde status. Een
aparte vergelijking gebruikt de bewaarde bron en dezelfde 50 trekkingen.
**Techniek:** native R, rtrim 2.3.1, mgcv 1.9.4; één worker.

## Begrenzing en beslissingen

Geen 2026, MySQL-wijziging, nieuwe dump/cache, VPS-publicatie of nieuwe
soortselectie. Geen automatische vervanging van de jaarindex door een
verwachtingscurve. Historische pilotbestanden blijven bewijs van de
uitgevoerde methode. CSV-statuscorrecties veranderen geen telling, index,
modelkeuze of brug. Contractschema v2 blijft gelijk; nieuwe statuswaarden
zijn een beveiliging binnen dat schema. Bestaande bronbundles worden door
de gewijzigde enginehash terecht ongeschikt voor een nieuwe batch.

De vergelijking omvat Veldleeuwerik, Torenvalk, Tapuit en Koolmees. Per
periode: direct telmodel met kaveleffect en lineaire tijd versus dezelfde
structuur met een beperkte tijdsspline (k=5, REML). Daarnaast de bestaande
jaarindex en nulvriendelijke indexsamenvatting. De kalibratieverhouding
blijft die uit de pilot; modelcurven krijgen hun eigen ankerschaal.
De tellingen zijn oppervlaktegecorrigeerd en kunnen fracties bevatten;
daarom quasi-Poisson. Modelstandaardfouten worden geen bootstrapinterval.
Vaste tijdsvormen, geen zoektocht naar een toevallig gunstig model.

## Review focus

- Nul en positieve waarden onder rtrim-grens 1e-6 mogen geen formele helling krijgen.
- Een ontbrekende of ongeldige totaalvector mag niet ongemerkt formeel worden.
- Statuscorrectie behoudt alle niet-inferentiële CSV-velden en beide indexbestanden.
- Zelfde bron, kalenderjaren, trekkingen en kalibratie bij modelvergelijking.
- Modelverwachting, waargenomen index en onvolledige voorspelvalidatie blijven onderscheiden.

### Task 1: Beveilig gedeeld periodecontract

- [x] Voeg echte model2-nulfixture en grens-/ongeldige-totalentests toe in `R/test_trim_trend_contract.R`; zie tests falen.
- [x] Pas alleen `trim_overall_contract()` aan; verwijder inferentie bij nul/te klein/ongeldig totaal, behoud model en tijdsbereik.
- [x] Draai contract- en relevante bron-/uitvoer-/bootstrapcontroles; commit.

### Task 2: Corrigeer historische periodestatus

- [x] Herbereken contractstatussen voor alle 228 geslaagde perioden uit de bewaarde context; verwacht 45 geblokkeerd en 183 overig.
- [x] Corrigeer uitsluitend de inferentievelden van betrokken perioden in de twee bestaande hoofdtrendtabellen; bewaar oorspronkelijke waarden in het nieuwe auditbewijs.
- [x] Verifieer dezelfde tellingen, indices, modellen, bruggen en niet-betrokken inferentie; breid uitvoercontractcontrole uit.

### Task 3: Vier-soortenvergelijking en afronding

- [x] Reproduceerbare countmodelhelpers en controle met bekende exponentiële tellingen; nul blijft modelinvoer.
- [x] Baseline, dezelfde 50 trekkingen, beperkte tijdsvormgevoeligheid en geblokkeerde tijdsvalidatie (vaste jaarblokken) uitvoeren. Onvoldoende trainingssteun niet weglaten uit de beoordeling.
- [x] Bewaar curven, status, diagnostiek, kalibratie en conclusies; beoordeel wat vóór 2026 klaar is en wat een werkelijk methodebesluit vraagt.
- [x] Eén onafhankelijke code-/resultaatreview; bronregister MD/DOCX synchroniseren, renderen en controleren; commit/push en eindpreflight.


## Uitvoeringsresultaat

Voor de historische ontwikkelbron 1958–2025 is de gedeelde overall-berekening beveiligd tegen de impliciete nul→één-vervanging. Van de 228 geslaagde periodemodellen behouden 183 formele inferentie; 45 perioden voor 40 soorten krijgen nuljaartotaal_herbeoordelen zonder helling, interval, p-waarde of trendklasse. Dezelfde correctie is aangebracht in de twee historische hoofdtrendtabellen. Tellingen, beide jaarindexbestanden, modelkeuzen, brugfactoren en soortselecties zijn behouden. Veldleeuwerik, Torenvalk, Tapuit en Koolmees zijn vergeleken met dezelfde 50 trekkingen en directe telmodellen met lineaire tijd en een beperkte tijdsspline. De lineaire telmodellen leveren respectievelijk 50, 49, 50 en 50 berekenbare uitkomsten; de spline 50, 49, 48 en 50. Twee niet volledig geoptimaliseerde Tapuit-berekeningen zijn afgekeurd. De trendpercentages verschillen per rekenwijze en de toets met achtergehouden jaarblokken heeft in geen van de acht soort-perioden volledige dekking. Er is daarom geen algemene vervanger of geforceerde positieve jaarindex ingesteld. De 2026-cijfers, MySQL, dump/cache, dashboard en VPS zijn niet gewijzigd. Een algemene 500/2.000-run is niet gestart; de methodische vraag wordt niet door meer herhalingen opgelost. Uitvoering, controles en figuren staan in trim/bootstrap/zero_policy_20261103/README.md.

Aanvulling: de volledige convergentie van de gladheidsoptimalisatie wordt gecontroleerd; de twee Tapuit-fouten zijn als uitval bewaard. De plots zijn op een gemeenschappelijk anker geijkt en tonen ook 2005–2025. De laatste commit bundelt bronregister Markdown/Word en de gecorrigeerde historische tabellen.

## Afrondcontrole en afwegingen

De onafhankelijke eindreview vond geen blokkerende fout. De 45 en 25
overlappende periodecorrecties zijn rechtstreeks tegen de Git-basis
gecontroleerd: uitsluitend de bedoelde inferentie/statusvelden veranderden.
Alle vier beschermde bronuitvoerbestanden zijn bytegelijk. Alle 59
Wordpagina's zijn afzonderlijk visueel gecontroleerd, zonder layoutdefecten.
De gerichte contract-, bron-, presentatie-, Sandra- en bootstrapcontroles
zijn groen. Beide optimalisatielagen van het splinefitproces zijn bewaakt.

Afwegingen uit de uitvoering:

- Het expliciete uitvoeringsakkoord gold als akkoord op deze uitwerking;
  geen herhaalde goedkeuringsvraag. Werk blijft niet-gepubliceerd op de
  ontwikkelbranch; een verkeerde scope-inschatting zou daar zichtbaar zijn.
- Geen automatische 500/2.000-run of algemene nieuwe trendmaat: de proef
  onderbouwt die keuze niet. Gevolg is dat een definitieve lange-trendmarge
  nog niet is vrijgegeven.
- Historische pilotbewijzen blijven behouden; alleen de twee huidige
  hoofdtrendtabellen zijn beschermd. Daardoor blijven eerdere uitkomsten
  als historische methode-uitvoer herleidbaar.
- Onvolledige voorspelvalidatie krijgt geen modelrangorde. Daardoor wordt
  geen winnaar gekozen op basis van een gunstig overgebleven deel.
- Figuren zijn op één anker geijkt; numerieke hellingen veranderen niet.
- Code, resultaten en beide bronregistervormen gaan in één samenhangende
  commit, op de bestaande bootstrapbranch. Geen mainmerge of publicatie;
  eventuele integratie is nog een afzonderlijke stap.

Niet-blokkerend restpunt uit de review: het auditgereedschap controleert
selectie en perioden, maar geen volledige inhoudsfingerprint van een later
opnieuw gemaakte tabel over dezelfde jaren. De huidige correctie is exact
tegen de Git-basis gecontroleerd. Voor hergebruik op vernieuwde 2025-uitvoer
is eerst een nieuwe broncontrole nodig; anders kan een herbeoordelingslabel
bij een inmiddels gewijzigde periode terechtkomen. Dit raakt geen telling.
