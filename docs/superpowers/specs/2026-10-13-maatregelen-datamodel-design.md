# Bronvast datamodel voor werkzaamheden en maatregelen

## Doel

Leg werkzaamheden in Meijendel vast zonder plannen, onderzoek, reguliere uitvoering en ruimtelijke afleidingen door elkaar te halen. De levende lokale database `Meijendel` blijft de canonieke schrijfbron. `plot_jaar_maatregel` blijft voorlopig een historische invoerlaag; nieuwe plot-jaarrijen ontstaan uitsluitend uit expliciete, controleerbare koppelingen.

## Reikwijdte

De eerste versie omvat natuurbeheer, waterwinning, infrastructuur, recreatie en onderzoek/monitoring. Alleen werkzaamheden die aantoonbaar in Meijendel liggen worden opgenomen. Maatregelen die uitsluitend Berkheide, Solleveld of een ander gebied betreffen blijven buiten de eerste invoer.

## Gegevensmodel

- `maatregel_project`: overkoepelend project of beheerprogramma, met werkcategorie, verantwoordelijke partij, programma, planperiode en bestuurlijke status.
- `maatregel_uitvoering`: concrete deelhandeling, gekoppeld aan een bestaande lokale maatregelklasse, een landelijke maatregelactiviteit, uitvoeringsstatus, datum- en locatienauwkeurigheid, cycliciteit, uitvoerder en gerealiseerde hoeveelheid.
- `maatregel_uitvoering_jaar`: uitsluitend jaren waarvoor de bron letterlijk uitvoering, geen uitvoering of onbekende uitvoering vastlegt. Een periode of het woord `jaarlijks` wordt niet automatisch uitgeklapt.
- `maatregel_bron`: één bronrecord per Zotero-item of officiële webbron, inclusief bronsoort, titel, datum, URL, Zotero-itemcode en raadpleegdatum.
- `maatregel_uitvoering_bron`: koppeling met bronrol, pagina/paragraaf en een korte zakelijke bewijsnotitie.
- `maatregel_geometrie`: uitsluitend daadwerkelijk beschikbare geometrie, met type zoek-, plan-, uitvoerings- of effectgebied en EPSG:28992.
- `maatregel_plot_koppeling`: uitsluitend expliciete of geometrisch aantoonbare relaties met een bestaande plot, inclusief methode, doorsnijdingspercentage en verificatiestatus.
- `v_plot_jaar_maatregel_bronvast`: afgeleide view uit geverifieerde plotkoppelingen en expliciete uitvoeringsjaren. De bestaande tabel `plot_jaar_maatregel` wordt niet automatisch aangevuld.

Referentietabellen leggen werkcategorieën, maatregeltypen, activiteiten, uitvoeringsstatussen, ruimtelijke typen en brontypen vast. De codering sluit waar mogelijk aan bij Datamodel Natuurmaatregelen 1.2 van 13 juni 2026; lokale uitbreidingen voor `niet_uitgevoerd` en `onbekend` blijven herkenbaar.

## Bewijsregels

- `uitgevoerd` vereist een bron die feitelijke uitvoering beschrijft.
- Een beleidsvoornemen, subsidie-openstelling of ontwerpplan krijgt `gepland`, nooit `uitgevoerd`.
- Onderzoek en monitoring worden als eigen werkcategorie geregistreerd, niet als natuurmaatregel.
- Een onbekend jaar blijft `onbekend`; ontbrekende informatie wordt nooit als `niet_uitgevoerd` geïnterpreteerd.
- Tegenstrijdige bronnen worden beide gekoppeld. De recentste bron mag de actuele status bepalen, maar wist het oudere bewijs niet.
- Een gebiedsnaam levert zonder betrouwbare geometrie geen plotkoppeling op.

## Eerste veilige invoer

De eerste invoer bevat alleen bronvaste Meijendel-records uit de volledig geraadpleegde Zotero-bibliotheek en officiële webbronnen. Daaronder vallen Pan 13, Kikkervalleien/Pan 26.1, de vijf kerven, PAS-uitvoering in Meijendel, watercrassulabestrijding, recente verwijdering van bomen/struweel/exoten, de konijnenproef en duidelijk als operationeel of gepland herkenbare waterwinnings- en infrastructuurprojecten. Zuiver Berkheidse maatregelen en niet gelokaliseerde Programma Natuur-ambities vallen buiten de invoer.

## Migratie en afnemers

Het schema is idempotent. Eerst wordt het contract in een tijdelijke MySQL-database getest, daarna worden de bestaande maatregelentabellen lokaal geback-upt en pas dan wordt de migratie op de levende database toegepast. Bestaande dashboard- en Shiny-contracten blijven ongewijzigd. De zware `Meijendel.sql`-export, proefimport en cachebouw vallen buiten deze opdracht en vereisen afzonderlijk akkoord.

## Documentatie

De tabelinventaris, het handboek en beide versies van het bronregister worden in dezelfde wijziging bijgewerkt. De DOCX-bestanden worden opnieuw opgebouwd, gerenderd en visueel gecontroleerd.
