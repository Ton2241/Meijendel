# Uitvoering teller- en ervaringsmodel

**Ontwerp vastgesteld:** 9 oktober 2026

**Uitvoering afgerond:** 9 oktober 2026

**Formele run:** `20261009T171423Z-8888e94f0aab`

**Codebasis van de run:** `8888e94f0aab0ecff6c9245bc3a7bcf31443987e`

Dit document legt vast hoe de afgeronde telleranalyse kan worden herhaald. De
inhoudelijke uitkomst staat in
[`ANALYSE_HOOFDLIJNEN_EN_UITKOMSTEN.md`](ANALYSE_HOOFDLIJNEN_EN_UITKOMSTEN.md);
de vooraf vastgestelde methode in
[`ONTWERP_TELLER_EN_ERVARINGSMODEL.md`](ONTWERP_TELLER_EN_ERVARINGSMODEL.md).

## Wat is uitgevoerd

De analyseketen leest de levende lokale MySQL-database `Meijendel` uitsluitend
read-only. Zij past eerst de centrale Natura 2000-, bron-, nul- en afkeurregels
uit `R/meijendel_cache_contract.R` toe. M66 en M91 vallen buiten de scope.
M62/2016 blijft als bronwaarde in de algemene vogelmatrix staan, maar telt niet
mee in de telleranalyse of in de ervaringshistorie.

Uit `plot_jaar_teller` is voor ieder plotjaar een canonieke tellerteamsleutel
gemaakt. Ervaring telt alleen geregistreerde jaren vóór het betreffende
teljaar. Zij wordt gesplitst in eerdere jaren in dezelfde plot en eerdere jaren
in andere Meijendelplots. Bij een team wordt het gemiddelde van de
`log(1 + jaren)`-waarden gebruikt. Minimum en maximum zijn uitsluitend als
gevoeligheidsvarianten doorgerekend.

Het hoofdmodel is negatief-binomiaal en gebruikt territoriumaantallen per
soort, plot en jaar, met plotoppervlakte als offset. Het basismodel M0 verwerkt
tijd, analysebron en de hiërarchische structuur van soort, soort–plot, jaar en
plotjaar. M1 voegt tellerteam toe. M2 voegt ervaring in dezelfde plot,
ervaring elders en soortspecifieke afwijkingen van beide ervaringseffecten toe.
M0, M1 en M2 gebruiken binnen iedere vergelijking exact dezelfde
responsrijen.

Naast de lange reeks 1958–2025 zijn drie gevoeligheidsanalyses uitgevoerd:
alleen plotjaren met één teller, de periode 1984–2025 met totale bezoekduur en
dezelfde periode met aantal bezoeken. Voor 121 voldoende gedekte soorten zijn
M0–M2 ook afzonderlijk geschat. Alleen na gedocumenteerde uitval van het
negatief-binomiale model was de vooraf bepaalde, zichtbaar gelabelde
Poisson-terugval toegestaan. De GEE gebruikt dezelfde soortselectie en rijen,
maar dient alleen als tweede controle op de richting van de ervaringseffecten.

## Herhaalbaarheid en beveiliging tegen stille uitval

Iedere fit wordt sequentieel uitgevoerd, passend bij de iMac M1 met 8 GB
geheugen, en onmiddellijk als checkpoint bewaard. Hervatten is alleen
toegestaan wanneer gegevenshash, Git-commit, formule, familie,
analysevariant en relevante pakketversies gelijk zijn. Eén mislukt soortmodel
stopt de overige soorten niet en blijft met reden in de uitkomst staan.

De tests controleren onder meer dat tellerteam niet afhangt van de volgorde
van teller-ID's, dat ervaring in dezelfde plot en elders niet overlapt, dat
onbekende tellers niet worden geïmputeerd, dat alle modellen binnen een
vergelijking dezelfde rijen gebruiken en dat mislukte modellen niet uit de
rapportage verdwijnen. De formele uitvoering schreef pas na deze controles de
compacte resultaatbestanden en het manifest.

## Opnieuw uitvoeren

Vanuit de repository:

```bash
analyses/broedvogel_vegetatie_power/scripts/run_broedvogel_teller_model.sh
```

Een aantoonbaar passende, onderbroken run kan worden hervat met:

```bash
analyses/broedvogel_vegetatie_power/scripts/run_broedvogel_teller_model.sh \
  --resume ABSOLUTE_RUNMAP
```

De gerichte controleketen is:

```bash
Rscript analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_data.R
Rscript analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_teller_data.R
Rscript analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_teller_prepare.R
Rscript analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_model_teller_fit.R
Rscript analyses/broedvogel_vegetatie_power/scripts/test_broedvogel_teller_pipeline.R
Rscript R/test_meijendel_cache_contract.R
bash -n analyses/broedvogel_vegetatie_power/scripts/run_broedvogel_teller_model.sh
```

Volledige matrices, modelobjecten en checkpoints blijven onder de door Git
genegeerde map `resultaten/runs/`. Alleen de compacte uitkomsten en het
manifest worden gevolgd. De keten schrijft niets naar Shiny, dashboard, de
levende database of de VPS.
