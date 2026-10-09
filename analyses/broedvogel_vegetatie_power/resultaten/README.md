# Resultaten

Deze map bevat later de compacte, inhoudelijk beoordeelde uitkomsten die nodig
zijn om conclusies en figuren te controleren. Iedere resultaatset vermeldt het
uitvoer-ID en verwijst naar een manifest met gegevensselectie, aantallen,
Git-commit, modelvariant, validatie en waarschuwingen.

Op te nemen eindproducten zijn onder meer:

- dekking en ontbrekende gegevens;
- invloed van teller en tellerervaring;
- vergelijking van basis-, PQ- en verrijkte modellen;
- voorspelprestaties voor achtergehouden jaren en plots;
- effecten per soort, functionele groep, ecologische groep en habitattype;
- veranderingen in continue functionele kenmerken;
- powercurven en benodigde toekomstige meetduur.

Grote modelobjecten, proefuitvoer en caches horen in `runs/` en blijven buiten
Git. Een getal wordt pas in het hoofddocument of artikel overgenomen nadat de
bijbehorende resultaatset is gecontroleerd.

De bestanden `analysematrix_laatste_samenvatting.csv` en
`analysematrix_laatste_manifest.json` zijn de compacte, gevolgde weergave van
de laatste formele matrixbouw. Het manifest bevat bronregelaantallen en
SHA256-controlesommen; de bijbehorende volledige matrix staat lokaal in de
genoemde `run_id` onder `runs/`.

De bestanden `teller_model_laatste_dekking.csv`,
`teller_model_laatste_samenvatting.csv`, `teller_model_laatste_soorten.csv`,
`teller_model_laatste_diagnostiek.csv` en
`teller_model_laatste_manifest.json` behoren bij run
`20261009T171423Z-8888e94f0aab` van 9 oktober 2026. Deze run is volledig
uitgevoerd met commit `8888e94f0aab0ecff6c9245bc3a7bcf31443987e`.

De gegevens omvatten 52 Natura 2000-plots en 2.106 voor de telleranalyse
geldige plotjaren over 1958–2025; 2.007 daarvan hebben een bekende teller of
een bekend tellerteam en 99 niet. De primaire modelpopulatie bevat 203.628
soort–plot–jaarrijen van 156 soorten; 121 soorten voldoen aan de vooraf
vastgelegde criteria voor een afzonderlijk soortmodel.

Alle achttien gezamenlijke modellen zijn convergent en gebruiken binnen iedere
vergelijking exact dezelfde responsrijen. In de primaire soortanalyse zijn 90
M2-uitkomsten negatief-binomiaal en 31 na gedocumenteerde NB-uitval met
Poisson geschat. De GEE-controle slaagde voor 105 soorten. Acht soorten
bereikten de vaste grens van zestig seconden; acht andere soorten voldeden
niet aan de aanvullende eis van foutcode nul en volledig eindige
coëfficiënten en robuuste standaardfouten. Alle zestien blijven zichtbaar als
modeluitval.

De gevoeligheidsanalyses leverden 117 bruikbare soortuitkomsten uit 118
kandidaten voor uitsluitend één-teller-plotjaren, 109 uit 111 voor totale
bezoekduur en 108 uit 111 voor aantal bezoeken. De overige zes uitkomsten zijn
als modeluitval met reden bewaard.

Het soortenbestand bevat zowel de primaire lange reeks als de één-teller- en
beide inspanningsanalyses. Voor de lange reeks staan de GEE-status,
foutcodes, coëfficiënten en robuuste standaardfouten in dezelfde rij.
`nbinom2` en `poisson_na_nb_uitval` blijven afzonderlijk herkenbaar. Grote
RDS-fits en de per-soort GEE-checkpoints staan uitsluitend in de bij het
manifest genoemde, door Git genegeerde runmap.
