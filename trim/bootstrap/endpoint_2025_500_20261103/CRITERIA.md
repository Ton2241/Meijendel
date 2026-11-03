# Voorafcontract voor de 500 validatie tot en met 2025

Opdracht3november2026:500trekkingen, alle156soorten, bewaarde1958–2025bron,
resultaten/beperkingen vastleggen en adviseren over2000. Geen2000run of
productiepublicatie. Eén lokale worker; geenNAS/VPS, dump/cache of2026.

De gekozen maat en alle poorten uit endpoint_all_2025_50_20261103/CRITERIA.md
blijven gelden: primair1958–1962/2021–2025, drie/zeven jaar gevoeligheid,
experimentele vijfjaarsbrug, alle156in de uitvoer, ontbrekend is geen nul.
Geen soort-, jaar-, brug- of modelherselectie. Nuleinde blijft−100%; nulbegin
ongedefinieerd. Geen interval uit een eindige subset of constante verdeling.

Er komt één nieuwe500run-identiteit op dezelfde bewaarde broncontext en
seed20260920. Alle500replicaties worden zelfstandig opnieuw berekend;
de eerste50trekkingen moeten identiek zijn aan de50pilot. Replicaties1/2
moeten de opgeslagen soorten/indices numeriek reproduceren. Geen heretikettering
van oudebatches als nieuwe500output. Gebruik bestaande bundle- en batchhelpers,
nieuwe enginehashes en checkpoints in batches van5. Bewaar bronherkomst,
rekentijd/geheugendiagnostiek en fouten. Geen verse baselinefit.

Na afloop: beoordeel500met de aparte2025intervalroute. Bij elke ongeldige
replicatie blijft de diagnostische band leeg. Alle formele95%-kolommen blijven
leeg;500isvalidatie. Ook nulgrens, schaarse eindsteun, imputatieafhankelijkheid,
venstergevoeligheid en gebiedsinterpretatie blijven zichtbaar.

Poort naar2000 (geen opdracht om2000te starten):
- Schatbare baseline,500/500eindig en nietconstant: kandidaat voor2000validatie.
- Enige uitval: geen2000intervalvrijgave voor die maat; toon oorzaak/aantal.
- Geen baseline/constanteverdeling: geen lange-intervalvalidatie.
De oude95%-rekengrens blijft diagnostiek; zij verandert dit niet. Alle156
blijven ook na deze indeling in het overzicht staan.

Vergelijk diagnostische percentielgrenzen bij250,375en500. Gebruik de reeds
vastgelegde grensregel: beide verschuivingen<0,10procentpunt netto én<5% van
de actuele bandbreedte. Rapporteer dit expliciet. Op500is dit een maat voor
Monte-Carlo-onrust; onrust op zichzelf is geen structurele onschatbaarheid
en kan juist verdere precisie met2000rechtvaardigen. Geen stabiele marge
claimen als de test faalt. Geen vrijgave van formele95%-dekking door alleen
deze vergelijking, ook niet als zij slaagt.
