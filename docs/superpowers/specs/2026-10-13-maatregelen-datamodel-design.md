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
- `plot_gebied`: de vijf Meijendel-deelgebieden en drie speciale gebieden, met een expliciet onderscheid tussen beide typen.
- `plot_gebiedsindeling`: versie en herkomst van de gebiedsindeling. Versie 1 gebruikt de SOVON-kavelgrenzen uit 2025 en de door Ton op 13 oktober 2026 bevestigde indeling.
- `plot_gebied_lidmaatschap`: precies één gebied per plot binnen een vastgestelde indeling. Alle 55 actuele en 14 historische plots worden opgenomen; historische plots blijven herkenbaar als `historisch_zonder_geometrie`.
- `plot_gebied_geometrie`: reproduceerbare samenvoeging van de actuele kavelpolygonen per deelgebied of speciaal gebied, met plotversie, aantal bronplots, oppervlakte en geometriehash.
- `maatregel_uitvoering_gebied`: bronvaste relatie tussen een uitvoering en een gebied. De relatie betekent dat de uitvoering binnen of voor dat gebied is genoemd; zij wordt niet automatisch naar alle onderliggende plots uitgebreid.
- `maatregel_plot_koppeling`: uitsluitend expliciete of geometrisch aantoonbare relaties met een bestaande plot, inclusief methode, doorsnijdingspercentage en verificatiestatus.
- `v_plot_jaar_maatregel_bronvast`: afgeleide view uit geverifieerde plotkoppelingen en expliciete uitvoeringsjaren. De bestaande tabel `plot_jaar_maatregel` wordt niet automatisch aangevuld.

Referentietabellen leggen werkcategorieën, maatregeltypen, activiteiten, uitvoeringsstatussen, ruimtelijke typen en brontypen vast. De codering sluit waar mogelijk aan bij Datamodel Natuurmaatregelen 1.2 van 13 juni 2026; lokale uitbreidingen voor `niet_uitgevoerd` en `onbekend` blijven herkenbaar.

## Bewijsregels

- `uitgevoerd` vereist een bron die feitelijke uitvoering beschrijft.
- Een beleidsvoornemen, subsidie-openstelling of ontwerpplan krijgt `gepland`, nooit `uitgevoerd`.
- Onderzoek en monitoring worden als eigen werkcategorie geregistreerd, niet als natuurmaatregel.
- Een onbekend jaar blijft `onbekend`; ontbrekende informatie wordt nooit als `niet_uitgevoerd` geïnterpreteerd.
- Tegenstrijdige bronnen worden beide gekoppeld. De recentste bron mag de actuele status bepalen, maar wist het oudere bewijs niet.
- Een gebiedsnaam mag aan een vastgesteld gebied worden gekoppeld, maar levert zonder uitvoeringsgeometrie of afzonderlijk bewijs geen koppeling met alle plots in dat gebied op.
- Een uitvoering met een eenduidige naam die precies overeenkomt met één speciaal plotgebied mag als `benoemd_gebied_gevalideerd` aan dat plot worden gekoppeld. De eerste veilige koppeling is `pas_24c_voorlinden` aan M91; het doorsnijdingspercentage blijft onbekend en de uitvoeringsstatus blijft `onbekend`.

## Gebiedsindeling en geometrie

De actuele indeling omvat 55 plots uit SOVON-plotversie 2025. Alle 55 geometrieën zijn aanwezig, geldig en vastgelegd in RD New (EPSG:28992). Zij worden als volgt verdeeld:

- Buitenduin Noord: 9 actuele plots;
- Buitenduin Zuid: 7 actuele plots;
- Kijfhoek en Bierlap: 16 actuele plots;
- Vallei Meijendel: 9 actuele plots;
- Zuid-oosthoek: 11 actuele plots;
- Haagsche Golfclub, Voorlinden en Hertenkamp: ieder 1 actueel speciaal plotgebied.

De 14 historische plots krijgen dezelfde gebiedscategorie als hun door Ton bevestigde opvolging of historische ligging. M17 hoort bij Buitenduin Noord, gelijk aan M17a. M8/11, M8/9, M9 en M11 horen bij Kijfhoek en Bierlap. Omdat SOVON-plotversie 2025 voor deze 14 plots geen afzonderlijke historische polygonen bevat, worden hun grenzen niet uit de actuele samengestelde plots teruggerekend.

De acht actuele gebiedsgeometrieën worden deterministisch opgebouwd uit de 55 bronpolygonen. Overlap tussen telplots blijft onderdeel van het bronmodel; de afgeleide gebiedsgeometrie wordt wel topologisch samengevoegd, zodat interne plotgrenzen en dubbele oppervlakken niet als afzonderlijk gebiedsoppervlak worden geteld. De bronplotten, plotversie en geometriehash blijven controleerbaar.

Historische gebiedsnamen zoals Meeuwenhoek, Harstenhoek en De Klip vallen buiten deze eerste geometrische indeling. Zij kunnen meerdere plots geheel of gedeeltelijk doorsnijden en krijgen pas een eigen geometrie na afzonderlijke bronvalidatie.

## Eerste veilige invoer

De eerste invoer bevat alleen bronvaste Meijendel-records uit de volledig geraadpleegde Zotero-bibliotheek en officiële webbronnen. Daaronder vallen Pan 13, Kikkervalleien/Pan 26.1, de vijf kerven, PAS-uitvoering in Meijendel, watercrassulabestrijding, recente verwijdering van bomen/struweel/exoten, de konijnenproef en duidelijk als operationeel of gepland herkenbare waterwinnings- en infrastructuurprojecten. Zuiver Berkheidse maatregelen en niet gelokaliseerde Programma Natuur-ambities vallen buiten de invoer. De gebiedsuitbreiding voegt de 69 bevestigde plotlidmaatschappen, acht afgeleide actuele gebiedsgeometrieën en de veilige koppeling Voorlinden–M91 toe. Andere benoemde locaties worden niet stilzwijgend over hele deelgebieden verdeeld.

## Migratie en afnemers

Het schema is idempotent. Eerst wordt het contract in een tijdelijke MySQL-database getest, daarna worden de bestaande maatregelentabellen lokaal geback-upt en pas dan wordt de migratie op de levende database toegepast. Bestaande dashboard- en Shiny-contracten blijven ongewijzigd. De zware `Meijendel.sql`-export, proefimport en cachebouw vallen buiten deze opdracht en vereisen afzonderlijk akkoord.

## Documentatie

De tabelinventaris, het handboek en beide versies van het bronregister worden in dezelfde wijziging bijgewerkt. De DOCX-bestanden worden opnieuw opgebouwd, gerenderd en visueel gecontroleerd.
