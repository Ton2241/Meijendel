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

## Stap 3 vervolg: samenstelling, IPI en landbedekking

Voer de aanvullende vegetatieanalyse uit met:

```bash
analyses/broedvogel_vegetatie_power/scripts/run_broedvogel_vegetatiesamenstelling.sh
```

De runner gebruikt de volledige taxonbedekking uit de provinciale PQ-reeks,
de IPI-indeling en Online Resource 2 van Schmidt-Tauscher, Häger en Van der
Hagen (2025). De laatste bron bevat zeven landbedekkingsklassen voor 25
BMP-plots in 2001 en 2022. De bron-Excel wordt bij iedere formele uitvoering
opnieuw opgehaald en met SHA256 vastgelegd; zij wordt niet als ruwe bronkopie
in Git opgeslagen.

De taxonomische samenstelling wordt met een Hellinger-transformatie en drie
compositieassen samengevat. IPI wordt vooraf tot open duin, nat/water,
struweel en bos gegroepeerd. De landbedekking wordt zonder jaarlijkse
interpolatie gekoppeld aan vogelvensters 1997–2001 en 2018–2022. Aalscholver
blijft uit deze vogel–vegetatiemodellen, omdat de PQ's de kolonienestplaats
niet meten.

De geblokkeerde `glmmTMB`-validatie draait sequentieel. Een parallelle proef
met twee gevorkte R-processen bleek op de 8GB-iMac technisch onveilig. Een
onderbroken run kan vanuit de opgeslagen modelcheckpoints worden hervat:

```bash
analyses/broedvogel_vegetatie_power/scripts/run_broedvogel_vegetatiesamenstelling.sh --resume ABSOLUTE_RUNMAP
```

De tests zijn:

```bash
Rscript analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_vegetatiesamenstelling.R
Rscript analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_vegetatiesamenstelling_fit.R
Rscript analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_vegetatiesamenstelling_pipeline.R
```

## Stap 3 vervolg: dekking van langere PQ-vertragingen

De lichte dekkingsrunner wordt uitgevoerd met:

```bash
analyses/broedvogel_vegetatie_power/scripts/run_pq_vertragingsdekking.sh
```

De runner leest de actuele vogel- en PQ-tabellen uit de lokale database,
gebruikt dezelfde Natura 2000-scope, nulregels, teller/tellerteamselectie en
Aalscholveruitsluiting als het bestaande vegetatiemodel en koppelt
PQ-meetjaren aan vogeljaren met vertraging nul tot en met vijftien jaar. Er
worden geen modellen geschat en geen databasewaarden gewijzigd. De volledige
run blijft onder `resultaten/runs/`; CSV en manifest worden compact als
`pq_vertragingsdekking_laatste.*` bewaard.

De zuivere regressietest is:

```bash
Rscript analyses/broedvogel_vegetatie_power/scripts/test_pq_vertragingsdekking.R
```

## Gerichte habitatmodellen met AHN en weer

Leid eerst voor AHN2 tot en met AHN5 de geharmoniseerde structuurmaten af:

```bash
analyses/broedvogel_vegetatie_power/scripts/run_ahn_vegetatiestructuur.sh
```

De runner selecteert per officieel DSM- en DTM-product de 34 relevante
kilometertegels, controleert de gepubliceerde SHA256, middelt iedere cyclus naar
hetzelfde tweemetergrid en schrijft een controleerbare CSV voor 55 plots en
vier cycli. AHN2 gebruikt voor Meijendel het officiële regionale
inwinningsjaar 2008; voor AHN3–AHN5 worden de vlieglijnen gebruikt. Voer daarna
de gerichte modellen uit met het absolute of repository-relatieve pad naar die
CSV:

```bash
analyses/broedvogel_vegetatie_power/scripts/run_broedvogel_habitatgericht.sh \
  PAD/NAAR/ahn_vegetatiestructuur.csv
```

De R-runner bouwt tien vooraf vastgelegde vogelgroep–habitatcombinaties,
voegt teller/tellerteam, ervaring, telinspanning en vier seizoensmaten uit
`weer_analyse` toe en valideert volledige plots in vijf ruimtelijke blokken.
Een tijdstoets wordt alleen uitgevoerd als minstens drie onafhankelijke
structuurmetingen beschikbaar zijn. De landbedekking heeft twee momenten en
blijft `niet_uitvoerbaar`; AHN2–AHN5 leveren vier momenten en worden in vaste,
niet-overlappende responsvensters getoetst.
Er wordt niets naar Shiny, dashboard of VPS geschreven.

AHN1 wordt bewust afzonderlijk onderzocht:

```bash
analyses/broedvogel_vegetatie_power/scripts/run_ahn1_historische_haalbaarheid.sh \
  PAD/NAAR/UITVOERMAP
```

Deze runner controleert de oorspronkelijke MD5's van tien grond- en
niet-grondbestanden, bouwt twee verdedigbare 5-meterrasters en kwantificeert de
methodegevoeligheid. De uitvoer wordt niet stilzwijgend aan AHN2–AHN5
toegevoegd.

De beperkte luchtfoto-classificatieproef is herhaalbaar met:

```bash
analyses/broedvogel_vegetatie_power/scripts/run_luchtfoto_classificatieproef.sh \
  PAD/NAAR/AHN3-AHN5-RASTERMAP
```

De runner downloadt RGB en CIR voor 2016, 2020, 2022, 2023 en 2024 via de
officiële PDOK-WMS, bouwt tien GeoTIFFs op het gedeelde tweemetergrid en voert
zowel de ruwe als de radiometrisch genormaliseerde Random-Forest-proef uit.
M66 en M91 worden uitgesloten. De grote beelden en runuitvoer blijven lokaal
en door Git genegeerd; alleen compact beoordeelde uitkomsten worden blijvend
opgenomen. De lokale `.venv_ahn` moet NumPy, Rasterio, GeoPandas, SciPy en
scikit-learn bevatten; de uitgevoerde proef gebruikte scikit-learn 1.6.1.

De later ontvangen classificatierasters voor 2001 en 2022 worden afzonderlijk
gecontroleerd en ontsloten met:

```bash
.venv_ahn/bin/python \
  analyses/broedvogel_vegetatie_power/scripts/schmidt_tauscher_landbedekking.py \
  --source-dir Landgebruik/schmidt_tauscher_2025/bron \
  --published analyses/broedvogel_vegetatie_power/resultaten/vegetatiesamenstelling_laatste_landbedekking.csv \
  --output-dir analyses/broedvogel_vegetatie_power/resultaten
```

Deze stap controleert iedere rasterklasse en plottoewijzing, vergelijkt de
oppervlakten met het openbare supplement en berekent per plot en klasse
oppervlakte, vlakken, grootste-vlakaandeel en randdichtheid. De twee
kaartjaren worden niet geïnterpoleerd.

De tests zijn:

```bash
.venv_ahn/bin/python analyses/broedvogel_vegetatie_power/scripts/test_ahn_vegetatiestructuur.py
.venv_ahn/bin/python analyses/broedvogel_vegetatie_power/scripts/test_ahn_selecteer_kaartbladen.py
.venv_ahn/bin/python analyses/broedvogel_vegetatie_power/scripts/test_controleer_ahn_harmonisatie.py
.venv_ahn/bin/python analyses/broedvogel_vegetatie_power/scripts/test_analyseer_ahn_harmonisatie.py
.venv_ahn/bin/python analyses/broedvogel_vegetatie_power/scripts/test_ahn1_historische_rasters.py
.venv_ahn/bin/python analyses/broedvogel_vegetatie_power/scripts/test_analyseer_ahn1_gevoeligheid.py
bash analyses/broedvogel_vegetatie_power/scripts/test_ahn_vegetatiestructuur_pipeline.sh
.venv_ahn/bin/python analyses/broedvogel_vegetatie_power/scripts/test_luchtfoto_download.py
.venv_ahn/bin/python analyses/broedvogel_vegetatie_power/scripts/test_luchtfoto_classificatie.py
.venv_ahn/bin/python analyses/broedvogel_vegetatie_power/scripts/test_schmidt_tauscher_landbedekking.py
Rscript analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_habitatgericht.R
bash analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_habitatgericht_pipeline.sh
```

## Stikstof en CBS-landgebruik

De aanvullende omgevingsmodellen zijn herhaalbaar met:

```bash
analyses/broedvogel_vegetatie_power/scripts/run_broedvogel_omgeving.sh
```

De runner leest `plot_jaar_stikstof`, `plot_jaar_landgebruik`, de vogelmatrix,
teller/tellerteam, bezoekinspanning, weer en de vastgelegde groepsindelingen
rechtstreeks uit de lokale canonieke database. M66 en M91 worden via de
centrale analysescope uitgesloten. De kaartcodes uit 1996 worden niet aan de
latere CBS-klassen gelijkgesteld; de modellen gebruiken 2010, 2015, 2017 en
2022. Getoetst worden stikstof, open natuurlijk terrein, bos, water, de drie
landklassen gezamenlijk en hun combinatie met stikstof.

Iedere combinatie vergelijkt hetzelfde basis- en omgevingsmodel op de exacte
zelfde rijen, met vijf achtergehouden plotblokken en één tijdstoets. Een
afgebroken uitvoering kan zonder opnieuw schatten van voltooide checkpoints
worden hervat met:

```bash
analyses/broedvogel_vegetatie_power/scripts/run_broedvogel_omgeving.sh \
  --resume PAD/NAAR/RUNMAP
```

De afzonderlijke test is:

```bash
Rscript analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_omgeving.R
```

## Niet-lineaire PQ-route: gradiënten en intervallen

De ecologische PQ-gradiënten worden lokaal opgebouwd met:

```bash
analyses/broedvogel_vegetatie_power/scripts/run_pq_ecologische_gradienten.sh
```

De runner haalt EcoDbase rechtstreeks van SynBioSys en controleert de vaste
SHA256 voordat de bron wordt gebruikt. Hij koppelt de PQ-taxa herleidbaar aan
open/pionier, duingrasland/mos/korstmos, nat/riet, struweel/ruigte en
bomen/bos. Een taxon met meerdere gradiënten verdeelt zijn bedekking daarover.
De database blijft ongewijzigd. Volledige runbestanden staan onder `runs/`;
compacte mappings, plotjaarscores, intervallen, dekkingssamenvattingen en het
manifest staan in `resultaten/`.

De regressietest is:

```bash
Rscript analyses/broedvogel_vegetatie_power/scripts/test_pq_ecologische_gradienten.R
```
