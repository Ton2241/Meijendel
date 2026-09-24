# Jachtspinnen Meijendel 1969-1970

## Inhoud

Deze kandidaatbron bevat de gereduceerde openbare matrix die wordt toegeschreven
aan Van der Aart en Smeenk-Enserink. Zij omvat:

- 28 genummerde onderzoekslocaties;
- twaalf jachtspinnensoorten;
- 3.337 gevangen exemplaren, geaggregeerd over zestig weken;
- zes getransformeerde milieuvariabelen per locatie.

`jachtspinnen_28_locaties.csv` is een leesbare afleiding van de bron in
`mvabund/spider.RData`. De bestanden uit `VGAM` vormen een onafhankelijke
controle: de soortenmatrix en de zes milieuvariabelen zijn exact gelijk aan die
uit `mvabund`. De later aan `mvabund` toegevoegde soortkenmerken zijn niet in de
CSV opgenomen, omdat zij niet uit het oorspronkelijke Meijendel-onderzoek
afkomstig zijn.

## Herkomst

- R-package `mvabund` 4.2.8, licentie LGPL (>= 2.1);
- R-package `VGAM` 1.1-14, licentie GPL-3;
- oorspronkelijke publicatie: P.J.M. van der Aart en N. Smeenk-Enserink,
  *Correlations between distributions of hunting spiders (Lycosidae, Ctenidae)
  and environmental characteristics in a dune area*, Netherlands Journal of
  Zoology 25, 1-45.

De packagebestanden zijn ongewijzigd overgenomen uit de officiële CRAN-
bronpakketten. `SHA256SUMS` legt hun hashes en die van de afgeleide CSV vast.

## Waarom geen database-import

De openbare matrix bevat alleen locatienummers 1-28. Coördinaten, geometrieën
of een betrouwbare vertaaltabel naar herkenbare plekken in Meijendel ontbreken.
Daarom is niet per waarneming vast te stellen waar zij in Meijendel is gedaan.
De bron voldoet niet aan de ruimtelijke toelatingsregel en blijft buiten MySQL.

Import kan pas opnieuw worden beoordeeld wanneer de oorspronkelijke publicatie,
bijlagen of een Leids archief de 28 locaties betrouwbaar geografisch ontsluiten.
