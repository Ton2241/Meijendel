# QField-veldproject Afscheidingen Meijendel

## Pakket

Het gebouwde pakket staat lokaal onder:

`outputs/qfield_afscheidingen/meijendel_afscheidingen`

Kopieer steeds de **hele map**. De map bevat het QGIS-project, de vaste
PDOK-luchtfoto 2025, de 55 onderzoekskavels, `veldwerk.gpkg` met drie
meetlagen, `routes.gpkg` met `paden_en_wegen` en de fotomap.
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
6. Registreer één testpolygoon in `gebieden` en sluit de omtrek.
7. Vul `offset_m` in als positieve geschatte afstand tussen de GNS 3000 en de
   werkelijke afscheiding. Noteer links of rechts van de looprichting in
   `opmerking`.
8. Sluit QField, open het project opnieuw en controleer of punt, lijn,
   polygoon en foto nog aanwezig zijn.

Kies het definitieve tijd- of afstandsinterval voor GPS-tracking pas na deze
proef. Een kleiner interval geeft meer punten, maar corrigeert de
positiefout van de ontvanger niet.

## Veldinvoer

- `afscheidingen`: hekwerk, hoge en lage draad, wildroosters, muren en
  poorten/doorgangen. Leg een poort of doorgang vast als een kort eigen
  lijnsegment tussen de aansluitende afscheidingssegmenten.
- `bijzonderheden`: hoeken, onderbrekingen,
  typewijzigingen, borden, schade, losse foto's en dierenverzamelplekken.
- `gebieden`: inclosure, exclosure, openbaar, beperkt toegankelijk,
  afgesloten en bedrijventerrein. Polygonen mogen elkaar overlappen of
  geheel binnen elkaar liggen; ieder gebied blijft een afzonderlijk object.
- `paden_en_wegen`: voetpad, fietspad of weg. Kies per lijn daarnaast
  `openbaar`, `beperkt toegankelijk` of `afgesloten`. Naam en opmerking zijn
  optioneel.
- Een opgeslagen polygoon kan later opnieuw worden geselecteerd. Met
  geometrie- of hoekpuntbewerking kun je grenspunten verplaatsen, toevoegen of
  verwijderen; categorie en formuliergegevens blijven behouden.
- De puntsymbolen worden bij uitzoomen kleiner en blijven door een onder- en
  bovengrens zowel op overzichtsschaal als dichtbij leesbaar.
- `nauwkeurigheid_m`: wordt gevuld met de horizontale nauwkeurigheid die
  QField/iPadOS meldt. Noteer het in `opmerking` als dit veld tijdens een
  waarneming leeg blijft.
- `ontvanger`: staat standaard op `GNS 3000 via iPadOS`.

De ingemeten lijn is een veldwaarneming. Zij stelt geen juridische grens
vast.

## Een voetpad, fietspad of weg volgen

1. Schakel de GNS 3000 in en wacht tot QField een stabiele positie toont.
2. Open de **Side Dashboard**.
3. Druk lang op **Paden en wegen** en kies **Setup tracking**.
4. Stel de afstand in op `2 m` en de tijd op `1 s`.
5. Kies **Start tracking**.
6. Vul in het formulier `type` en `toegankelijkheid` in. `naam` en
   `opmerking` zijn optioneel.
7. Loop of ren het routedeel. QField slaat ieder opgenomen meetpunt direct in
   dezelfde lijn op.
8. Druk in de **Side Dashboard** lang op de tracking badge naast
   **Paden en wegen** en kies **Stop tracking**.

Verandert onderweg het routetype of de toegankelijkheid, stop dan de huidige
tracking en start een nieuw lijnobject. Eén object krijgt altijd één type en
één toegankelijkheidsstatus.

## Veilige upgrade van het bestaande iPad-project

Gebruik `meijendel_routes_upgrade.zip` wanneer op de iPad al waarnemingen in
het project staan. Sluit QField, pak de ZIP uit en plaats alleen
`meijendel.qgz` en `routes.gpkg` in de bestaande projectmap. Vervang
`meijendel.qgz`; laat `veldwerk.gpkg`, `referentie.gpkg`, de luchtfoto en
`photos/` staan. Daarmee blijven bestaande afscheidingen, bijzonderheden,
gebieden en foto's behouden.

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

Door de hele map terug te kopiëren blijven de relatieve fotopaden en alle
drie meetlagen intact.
