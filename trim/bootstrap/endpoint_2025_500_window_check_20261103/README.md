# 500 herbeoordeeld: controle op werkelijk gebruikte indexjaren

Alle 156 soorten uit de bewaarde Meijendel-ontwikkelbron 1958–2025 zijn opnieuw beoordeeld met exact dezelfde 500 gestratificeerde trekkingen van 52 kavelgeschiedenissen. Criteria vooraf gecommit: f238f144. De oorspronkelijke strikte beoordeling blijft in `../endpoint_2025_500_20261103` staan.

**Uitkomst: 32 soorten hebben 500/500 geldige, niet-constante uitkomsten en kunnen door naar een afgebakende 2.000-validatie van de begin/eindmaat. 5 soorten houden een schatbare baseline met uitval; 119 hebben geen schatbare baseline voor deze vaste lange maat.** Geen formele 95%-marges vrijgegeven. Geen 2.000-trekkingen gestart.

## Wat is aangepast

De begin/eindmaat blijft `100 × (gemiddelde index 2021–2025 / gemiddelde index 1958–1962 − 1)`. Beide bruikbare periodemodellen en een eindige positieve vijfjaarsbrug blijven vereist. De controle verlangt precies één eindige, niet-negatieve index voor ieder begin-, eind- en brugjaar: 1958–1962, 2021–2025, 1979–1983 en 1986–1990. Drie- en zevenjaarsgevoeligheidsvensters gebruiken hun eigen begin/eindjaren met dezelfde vijfjaarsbrug.

Voor deze maat is een volledige jaarreeks buiten die vensters geen rekenvereiste. Ontbrekende, dubbele of ongeldige overige indexjaren worden afzonderlijk geregistreerd. Er is niets aangevuld, nul gemaakt of verschoven. De betrokken jaarreeks blijft op die jaren onvolledig. De regel is voor alle 156 soorten toegepast, zonder uitzonderingen op naam of voor alleen 1984/1985.

## Verschil met de strikte beoordeling

| Soort | Geldig strikt | Geldig nu | Besluit |
|---|---:|---:|---|
| Dodaars | 499 | 500 | kandidaat 2.000 |
| Wintertaling | 330 | 333 | uitval; geen band |
| Slobeend | 498 | 500 | kandidaat 2.000 |
| Kuifeend | 499 | 500 | kandidaat 2.000 |
| Veldleeuwerik | 496 | 497 | uitval; geen band |
| Rietgors | 499 | 500 | kandidaat 2.000 |

De negen soort-trekkinggevallen met twaalf ontbrekende indexjaarregels worden nu bruikbaar voor de begin/eindmaat. De jaren 1984/1985 liggen buiten de gebruikte vensters. De bewaarde gap-audit toont dat getelde nullen aanwezig zijn, maar na het verwijderen van kavels die de hele modelperiode nul waren geen modelcellen voor die jaren overbleven. Die bronwaarden en modelselectie zijn behouden. Zie `index_gaps.csv` (twaalf jaarregels), `usable_with_outside_gaps.csv` (negen bruikbare gevallen) en `changed_estimates.csv` (alle veranderde uitkomsten, inclusief gevoeligheidsvensters).

Dodaars, Slobeend, Kuifeend en Rietgors gaan van uitval naar 500/500. Veldleeuwerik wint één uitkomst maar houdt drie onschatbare bruggen. Wintertaling wint drie uitkomsten maar houdt 160 onschatbare bruggen en zeven mislukte postmodellen. Torenvalk (481/500), Ransuil (389/500) en Witte Kwikstaart (490/500) houden respectievelijk negentien, 111 en tien onschatbare bruggen. Voor alle vijf is de band geweigerd: een band uit alleen succesvolle trekkingen zou de uitval verbergen. De bruguitval betreft volledig nulgetelde brugvensters; er is geen pseudo-aantal toegevoegd.

Alle 37 schatbare baselines blijven gelijk. Bij de overige 119 ontbreekt voor 45 een deel van het vaste beginindexvenster in de bestaande modeljaarselectie, voor elf een schatbare brug en voor 63 minstens één bruikbaar periodemodel (42 één, 21 geen). Dit is geen verwijdering van soorten en betekent niet dat brontellingen ontbreken. Jaarindices en afzonderlijke periode-uitkomsten vragen hun eigen onzekerheidsbeoordeling; deze taak behandelt uitsluitend de vaste lange begin/eindmaat.

## Numerieke precisie en beperkingen

Bij 375→500 voldoen 3 van de 32 kandidaten aan de ongewijzigde stabiliteitsregel: Bergeend, Scholekster, Stormmeeuw. Bij beide opeenvolgende controles voldoen 0 kandidaten. Beide bandgrenzen moeten minder dan 0,1 procentpunt én minder dan 5% van de actuele bandbreedte bewegen. Meer trekkingen zijn een precisieproef; 2.000 garandeert geen stabiele of goed dekkende 95%-marge.

Twaalf echte nuleinden blijven −100%: negen bij Wulp, twee bij Stormmeeuw en één bij Tapuit; geen nulbegin is waargenomen. Een nulbegin, ongeldige benodigde index, uitgevallen trekking of constante verdeling levert geen band. Alle formele CI-kolommen blijven leeg. Waarden vlak boven −100% worden in het soortenoverzicht met extra decimalen getoond.

Scholekster, Wulp, Stormmeeuw, Tortelduif en Tapuit hebben hoogstens één positieve bronkavel in het eindvenster 2021–2025. Bij Wulp is de positieve uitgangsindex daar afhankelijk van de bestaande modelaanvulling. Bij zes soorten wisselt de uitgangsrichting tussen drie-, vijf- en zevenjaarsvensters: Kuifeend, Witte Kwikstaart, Gekraagde Roodstaart, Grasmus, Fitis en Kneu. Venstergevoeligheid is geen onderdeel van één bootstrapband. De uitkomst beschrijft de modelgecorrigeerde telnetwerkroute; zij bewijst geen verandering van een gelijk bemonsterde geografische populatie. De brug kan methodeverschillen en echte verandering tussen brugvensters niet volledig scheiden. Een kleine numerieke band neemt deze beperkingen niet weg.

Advies: vervolgvalidatie van de begin/eindmaat met 2.000 trekkingen kan voor de 32 complete soorten, met dezelfde bron tot en met 2025 en ongewijzigde poorten. Alle 156 soorten blijven in de administratie met hun eigen status. Meer trekkingen lossen de resterende vijf gevallen met uitval of de 119 onschatbare baselines niet op. Deze conclusie is geen algemene vrijgave van onzekerheidsmarges voor alle soorten, jaarlijkse indices of afzonderlijke perioden.

## Herkomst en verificatie

`comparison_verification.json` legt de vergelijking van alle 234.468 bron/trekking/vensterregels vast. Alle eerder eindige waarden en hun statussen zijn behouden; gewijzigde uitkomsten betroffen uitsluitend de oude indexvolledigheidspoort. De 500 drawhashes, inputbundel en alle baselines zijn gelijk; vier beschermde hoofd-CSV's zijn ongewijzigd. Geen model opnieuw geschat, geen nieuwe trekking, databasebewerking, dump/cachebouw, 2026-invoer of productiewijziging. De oorspronkelijke batchtijd en geheugenmetingen in `resources.json` zijn historische metingen van de 500-run, geen nieuwe rekentijd voor deze herbeoordeling.

Reproduceerbaar vanaf de taakbranch:

```sh
Rscript R/assess_trim_500_validation.R "$REPO" "$RUN" "$OUT"
Rscript R/check_trim_500_window_reassessment.R "$REPO" "$RUN" "$OUT"
```

`REPO` is de Meijendel-checkout; `RUN` is de canonieke map `outputs/trim-2025-validation-500-20261103`; `OUT` is een nieuwe uitvoermap. De ruwe batches en 234.468 volledige nieuwe regels blijven buiten Git. De compacte controle-uitkomsten staan hier: `per_species.csv` (156), `primary_estimates.csv` (78.156), `window_sensitivity.csv` (468), `coverage.csv` (312), `comparison.csv` (156), `manifest.json`, en [PER_SOORT.md](PER_SOORT.md). De primaire CSV bewaart ook de afzonderlijke problemen buiten gebruikte vensters voor alle soorten en trekkingen. `CRITERIA.md` bewaart de vooraf afgesproken regel.

## Afrondcontrole

De gerichte regressiecontroles zijn groen. De onafhankelijke eindreview heeft de rekenregel, alle 234.468 regels, de 156 soortenregels, poorten, bron-/draw-/code-/criteriahashes en archiefgelijkheid bevestigd; geen inhoudelijke bevindingen. Alle 61 pagina’s van het bijgewerkte bronregister zijn afzonderlijk op renderresolutie gecontroleerd, zonder clipping, overlap of lege pagina’s. De nieuwe beoordelingsalinea op pagina 9 is tekstueel gelijk aan Markdown. De enige redactionele bevinding, enkelvoud bij één trekking, is gecorrigeerd. Werkelijke 95%-dekking, geografische representativiteit en model-/brugaannamen zijn hiermee niet bewezen.
