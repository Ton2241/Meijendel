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
