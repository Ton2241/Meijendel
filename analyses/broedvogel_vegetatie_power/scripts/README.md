# Scripts

Hier staan uitsluitend scripts die specifiek zijn voor de integrale
broedvogel-, vegetatie- en poweranalyse. De matrixbouw, telleranalyse en het
eerste PQ-vegetatiemodel met geblokkeerde validatie zijn uitgevoerd. De
groepsafleiding, aanvullende verklarende lagen en powerstap volgen nog.

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

## Stap 1: vogelmatrix

Voer vanuit de repository uit:

```bash
analyses/broedvogel_vegetatie_power/scripts/run_broedvogel_model_data.sh
```

De runner leest de levende lokale MySQL-database uitsluitend read-only,
controleert eerst de lokale werkruimte en verwijdert de tijdelijke TSV-extracten
na afloop. `broedvogel_model_data.R` past daarna de centrale scope-, nul- en
afkeurregels toe. De test kan afzonderlijk worden uitgevoerd met:

```bash
Rscript analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_data.R
```

## Stap 2: tellerdata en modelpopulaties

`broedvogel_model_teller_data.R` maakt uit `plot_jaar_teller` de canonieke
registraties van teller/tellerteam en uitsluitend de vóór ieder teljaar
geregistreerde ervaring.
`broedvogel_model_teller_prepare.R` koppelt die laag aan de vogelmatrix en
maakt drie vaste populaties: de lange reeks met bekende teller, alleen
één-teller-plotjaren en de periode 1984–2025 met BMP-bezoekinspanning.

De bijbehorende zuivere tests zijn:

```bash
Rscript analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_teller_data.R
Rscript analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_teller_prepare.R
```

## Technische stap 3: teller- en ervaringsmodellen

De zelfstandige telleranalyse wordt lokaal en sequentieel uitgevoerd met:

```bash
analyses/broedvogel_vegetatie_power/scripts/run_broedvogel_teller_model.sh
```

De runner leest negen tabellen uit de levende lokale database, waaronder
`dagbezoeken_bmp`, en schrijft volledige matrices en modelcheckpoints alleen
onder `resultaten/runs/`. Na een volledig afgeronde uitvoering worden vijf
compacte `teller_model_laatste_*`-bestanden bijgewerkt. Er wordt niets naar
Shiny, dashboard of VPS geschreven.

De runner verandert geen territoriumaantallen. M0 schat de vogelontwikkeling
zonder tellerinformatie, M1 voegt de systematische spreiding die samenhangt
met teller/tellerteam toe en M2 voegt eerdere geregistreerde ervaring in
dezelfde plot en elders toe. In volgende ecologische modellen wordt deze M2-structuur
opnieuw geschat; de nu gevonden coëfficiënten worden niet als vaste
nabewerking op de gegevens gezet.

Een onderbroken run kan worden voortgezet met:

```bash
analyses/broedvogel_vegetatie_power/scripts/run_broedvogel_teller_model.sh --resume ABSOLUTE_RUNMAP
```

Een checkpoint wordt alleen hergebruikt als de vastgelegde SHA256-hash van de
responsrijen gelijk is. Ontbrekende of niet-passende checkpoints worden opnieuw
berekend. De pijplijntest is:

```bash
Rscript analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_teller_pipeline.R
```

## Inhoudelijke stap 3: PQ-vegetatiemodel

De zelfstandige vegetatieanalyse wordt lokaal en sequentieel uitgevoerd met:

```bash
analyses/broedvogel_vegetatie_power/scripts/run_broedvogel_vegetatie_model.sh
```

De runner koppelt uitsluitend werkelijke PQ-meetjaren aan geldige
vogelplotjaren met bekende teller/tellerteam. De technische velden
`tellerteam_factor` en `tellerteam_sleutel` kunnen zowel één teller als een
tellerteam van twee of meer tellers aanduiden. Soortenrijkdom, Shannon en
totale bedekking worden elk gesplitst in een verschil tussen plots en een
afwijking binnen dezelfde plot. De primaire voorspellingstoets houdt vijfmaal
volledige plots en tweemaal volledige latere perioden achter.

Een onderbroken run kan met de bestaande checkpoints worden hervat:

```bash
analyses/broedvogel_vegetatie_power/scripts/run_broedvogel_vegetatie_model.sh --resume ABSOLUTE_RUNMAP
```

De vier zuivere tests zijn:

```bash
Rscript analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_vegetatie_data.R
Rscript analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_vegetatie_fit.R
Rscript analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_vegetatie_validate.R
Rscript analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_vegetatie_pipeline.R
```
