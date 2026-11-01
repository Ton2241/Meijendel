# Actualisatie Meijendel_bronnen

**Doel.** Breng de lokale en gepubliceerde broncatalogus weer gelijk met de
actuele Zotero-collectie en maak de drie eerder vastgestelde contexttellingen
ondubbelzinnig.

**Reikwijdte.** Alleen `Meijendel_bronnen`, de bijbehorende dump,
bronregisterdocumentatie en de begrensde broncatalogusrelease. Geen wijziging
van `Meijendel`, Shiny, websitecode of analysetoelating.

## Uitvoering

1. Leg eerst testcontracten vast voor 336 jachtspinmatrixregels, 19 aquatische
   methodeperioden en de uitgesplitste duinvalleitelling; controleer RED.
2. Pas de bestaande reproduceerbare importhelpers minimaal aan; controleer
   GREEN en de relevante regressies.
3. Maak na bevestigde T7-beschikbaarheid een herstelbare dump van de levende
   lokale `Meijendel_bronnen`, synchroniseer Zotero en pas uitsluitend de drie
   catalogusregistraties transactioneel aan.
4. Actualiseer bronregister Markdown en DOCX, maak en hersteltest de afzonderlijke
   bron-dump, commit/push en integreer naar schone `main`.
5. Publiceer uitsluitend via `deploy/deploy_meijendel_bronnen_vps.sh` en voer
   de bestaande broncatalogus- en repositorynacontroles uit.

**Afrondcriteria.** 596 actieve Zotero-items; contexttellingen 336, 19 en
101.992 met juiste toelichting; dump herstelbaar; tests en bronrelease groen;
alle drie repositories schoon op `main == origin/main`.
