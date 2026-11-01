# Meijendel in Mergin Maps

Dit project is bedoeld voor eenvoudige veldregistratie op de iPad. Het bevat
de luchtfoto van 2025, 55 onderzoekskavels en afzonderlijke lagen voor punten,
lijnen en polygonen. Na het downloaden werkt de kaart zonder internet.

## Eenmalig op de iMac

1. Installeer in QGIS via `Plugins` > `Manage and Install Plugins` de plug-in
   `Mergin Maps`.
2. Maak een Mergin Maps-account aan en meld je in de QGIS-plug-in aan.
3. Open `outputs/mergin_maps/meijendel/meijendel.qgz`.
4. Kies in de Mergin Maps-werkbalk `Create Mergin Maps project` en upload de
   volledige map als project `meijendel`.
5. Controleer na de upload dat `meijendel` in de Mergin Maps-projectenlijst
   staat. Verplaats of verwijder de lokale map niet.

## Eenmalig op de iPad

1. Installeer `Mergin Maps` uit de App Store en meld je met hetzelfde account
   aan.
2. Zoek het project `meijendel` en kies `Download` terwijl internet beschikbaar
   is. De luchtfoto is groot; wacht tot de download volledig is afgerond.
3. Verbind de GNS 3000 in de iPadOS Bluetooth-instellingen.
4. Open het project buiten en controleer met de locatieknop dat de positie
   meebeweegt.
5. Zet de iPad in vliegtuigmodus en schakel Bluetooth daarna weer in. Open het
   project opnieuw. Als luchtfoto en kavels zichtbaar blijven, is het project
   offline beschikbaar.

## Vastleggen

Kies onderaan `Add`. Tik bovenaan op de actieve laag om een andere invoerlaag
te kiezen.

- `Bijzonderheden`: plaats het kruis op de locatie of gebruik de actuele
  GPS-positie. Kies `Record`, vul het formulier in en kies `Save`.
- `Afscheidingen`: voeg voor een korte lijn de opeenvolgende hoekpunten toe.
  Voor een lange afscheiding kies je `Streaming mode`, loop je langs de
  afscheiding en stop je de streaming aan het einde. Kies daarna `Record`, vul
  het type in en sla op. Een poort of doorgang is een kort eigen lijnsegment.
- `Gebieden`: voeg punten langs de grens toe of gebruik `Streaming mode` als
  de grens beloopbaar is. Bij `Record` sluit Mergin Maps het eerste en laatste
  punt tot een polygoon. Polygonen mogen binnen andere polygonen liggen.

De GPS-lijn geeft de positie van de wandelaar weer. Vul `offset_m` en de kant
van de afscheiding in als je niet precies langs de werkelijke grens loopt.

## Apple Pencil en gelopen route

- Met de potloodknop `Map sketching` teken je vrij met de Apple Pencil. Gebruik
  `Undo` of `Eraser` voor correcties. Een schets is een voorlopige gekleurde
  lijn, geen definitieve afscheiding of polygoon.
- Via `More` > `Position tracking` > `Start tracking` bewaar je de gelopen
  route. Stop de track na afloop. Een position track wordt niet automatisch
  een afscheiding.

De schetskleuren betekenen:

| Kleur | Betekenis |
|---|---|
| groen | openbaar |
| oranje | beperkt toegankelijk |
| rood | afgesloten |
| bruin | bedrijventerrein |
| blauw | inclosure |
| zwart | exclosure |
| wit | algemene notitie |

## Synchroniseren en veilig bewaren

1. Werk offline zolang dat nodig is. Alle wijzigingen blijven lokaal op de
   iPad staan.
2. Maak na thuiskomst verbinding met internet en open `meijendel`.
3. Kies `Sync` en wacht tot de synchronisatie is afgerond.
4. Open `More` > `Local changes`. Verwijder het project niet zolang daar nog
   niet-gesynchroniseerde wijzigingen staan.
5. Open het project daarna in QGIS en synchroniseer ook daar. Controleer de
   aantallen, geometrieen en foto's voordat gegevens later naar de levende
   Meijendel-database worden overgenomen.

De veldregistraties zijn waarnemingen. Zij stellen geen juridische grens vast.
