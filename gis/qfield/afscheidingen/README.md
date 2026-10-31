# QField-veldproject Afscheidingen Meijendel

## Pakket

Het gebouwde pakket staat lokaal onder:

`outputs/qfield_afscheidingen/meijendel_afscheidingen`

Kopieer steeds de **hele map**. De map bevat het QGIS-project, de vaste
PDOK-luchtfoto 2025, de 55 onderzoekskavels, `veldwerk.gpkg` en de fotomap.
De bestanden gebruiken relatieve paden en moeten bij elkaar blijven.

Het pakket wordt opnieuw gebouwd met:

```bash
gis/qfield/afscheidingen/download_pdok_luchtfoto.sh
```

Daarvoor is internet nodig. In het veld niet.

## Eenmalig op de iPad

1. Installeer QField uit de App Store voordat je het veld ingaat.
2. Laad de GNS 3000 op en schakel hem buiten in.
3. Open op de iPad `Instellingen` → `Bluetooth` en verbind de GNS 3000.
4. Open een kaartapp en controleer of de positie meebeweegt. QField gebruikt
   daarna de locatie die iPadOS doorgeeft; kies in QField geen afzonderlijke
   NMEA-verbinding.

## Overzetten zonder cloud

Gebruik AirDrop of een kabel met Finder. Bewaar de ontvangen projectmap in de
Bestanden-app onder `Op mijn iPad`. Open daarna
`meijendel.qgz` vanuit QField.

QFieldCloud is voor dit project niet nodig. Verplaats nooit alleen het
`.qgz`-bestand: zonder de GeoPackages, luchtfoto en fotomap is het project
onvolledig.

## Eerste offlineproef

Voer deze proef uit voordat je een volledige veldronde begint:

1. Zet de iPad in vliegtuigmodus en schakel Bluetooth daarna weer in.
2. Open het project in QField. Controleer dat luchtfoto en kavels zichtbaar
   blijven; daarmee is de offlinewerking vastgesteld.
3. Wacht buiten tot de GNS 3000 een stabiele positie levert. Controleer in
   QField de weergegeven horizontale nauwkeurigheid.
4. Registreer één testpunt in `bijzonderheden`, inclusief foto.
5. Registreer één testlijn van enkele honderden meters in `afscheidingen`.
6. Vul `offset_m` in als positieve geschatte afstand tussen de GNS 3000 en de
   werkelijke afscheiding. Noteer links of rechts van de looprichting in
   `opmerking`.
7. Sluit QField, open het project opnieuw en controleer of punt, lijn en foto
   nog aanwezig zijn.

Kies het definitieve tijd- of afstandsinterval voor GPS-tracking pas na deze
proef. Een kleiner interval geeft meer punten, maar corrigeert de
positiefout van de ontvanger niet.

## Veldinvoer

- `afscheidingen`: hekwerk, hoge en lage draad, veeroosters, muren en
  regelgebaseerde afscheidingen.
- `bijzonderheden`: hoeken, poorten/doorgangen, onderbrekingen,
  typewijzigingen, borden, schade, losse foto's, inclosures, exclosures en
  dierenverzamelplekken.
- `nauwkeurigheid_m`: wordt gevuld met de horizontale nauwkeurigheid die
  QField/iPadOS meldt. Noteer het in `opmerking` als dit veld tijdens een
  waarneming leeg blijft.
- `ontvanger`: staat standaard op `GNS 3000 via iPadOS`.

De ingemeten lijn is een veldwaarneming. Zij stelt geen juridische grens
vast.

## Veilig terugkopiëren naar de iMac

1. Sluit het project in QField.
2. Kopieer de hele projectmap via AirDrop of Finder terug naar de iMac.
3. Geef de terugontvangen map eerst een datum, bijvoorbeeld
   `meijendel_afscheidingen_2026-11-01`; overschrijf de oorspronkelijke lege
   veldwerkmap nog niet.
4. Open het teruggekopieerde `.qgz`-bestand in QGIS.
5. Controleer aantallen, geometrieën en foto's. Vergelijk de lijn uitsluitend
   met de luchtfoto waar de veldwaarneming dat ondersteunt.
6. Neem `veldwerk.gpkg` pas na deze controle als nieuwe werkversie over.

Door de hele map terug te kopiëren blijven de relatieve fotopaden en beide
meetlagen intact.
