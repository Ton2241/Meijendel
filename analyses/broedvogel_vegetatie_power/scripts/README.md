# Scripts

Hier komen uitsluitend scripts die specifiek zijn voor de integrale
broedvogel-, vegetatie- en poweranalyse.

De verwachte keten bestaat uit afzonderlijke stappen voor:

1. opbouw en controle van de analysematrix;
2. teller en tellerervaring;
3. modelschatting;
4. ruimtelijk en temporeel geblokkeerde validatie;
5. afleiding van soort-, groep- en traituitkomsten;
6. simulatie van detecteerbaarheid en toekomstige meetduur;
7. aanmaak van compacte resultaatbestanden en figuren.

Algemene selectie- en nulregels worden hergebruikt uit
`../../../R/meijendel_cache_contract.R`. Een script dat die regels dupliceert
of afwijkend interpreteert wordt niet aan deze keten toegevoegd.

Ieder uitvoerscript moet een uitvoermanifest schrijven zoals beschreven in het
hoofddocument. Scripts schrijven niet rechtstreeks naar Shiny, dashboard of
VPS.
