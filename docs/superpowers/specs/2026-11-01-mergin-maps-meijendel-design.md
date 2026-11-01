# Ontwerp Mergin Maps-project Meijendel

## Doel

Een afzonderlijk, eenvoudig veldproject `meijendel` maken voor gebruik op de
iPad. Het bevat de offline luchtfoto van 2025, de 55 onderzoekskavels en drie
bewerkbare lagen voor punten, lijnen en polygonen. Het bestaande QField-pakket
blijft onaangeroerd als reserve.

## Gekozen aanpak

Er zijn twee routes beoordeeld:

1. een afzonderlijk Mergin Maps-project bouwen op basis van het bestaande
   gegevensmodel;
2. het bestaande QField-pakket ter plaatse ombouwen.

Gekozen is route 1. Daarmee blijven het werkende QField-pakket en eventuele
latere veldgegevens daarvan gescheiden van Mergin Maps. De bestaande builder
wordt waar mogelijk hergebruikt, zodat categorieen, formulieren en stijlen niet
uiteen gaan lopen.

## Inhoud

Het project bevat:

- `afscheidingen`, als lijnlaag met `hekwerk`, `hoge draad`, `lage draad`,
  `wildrooster`, `muur` en `poort/doorgang`;
- `bijzonderheden`, als puntlaag met `hoek`, `onderbreking`, `typewijziging`,
  `bord`, `schade`, `foto`, `anders` en `dierenverzamelplek`;
- `gebieden`, als polygoonlaag met `inclosure`, `exclosure`, `openbaar`,
  `beperkt toegankelijk`, `afgesloten` en `bedrijventerrein`;
- `onderzoekskavels`, als alleen-lezen referentielaag met 55 polygonen;
- de lokale PDOK-luchtfoto 2025 van 25 cm, zodat het project na downloaden
  zonder internet bruikbaar is;
- een fotomap met relatieve paden.

## Vereenvoudigde veldwerkwijze

- Een los object wordt als punt geregistreerd en krijgt direct categorie,
  datum, bron, foto en opmerking.
- Een korte afscheiding of poort wordt als lijn ingetekend.
- Een lange afscheiding wordt bij voorkeur met GPS-streaming gevolgd; de GNS
  3000 levert daarbij via iPadOS de positie.
- Een gebied kan rechtstreeks als polygoon worden vastgelegd.
- Vrij tekenen met de Apple Pencil wordt via Mergin Maps Map Sketching
  ingeschakeld. Een schets is een voorlopige gekleurde lijn en geen definitieve
  polygoon. Gesloten schetsen kunnen later gecontroleerd in QGIS naar de laag
  `gebieden` worden overgenomen.
- Position tracking wordt ingeschakeld voor het bewaren van een gelopen route;
  een track is niet automatisch een afscheiding.

## Opslag en synchronisatie

De lokale projectmap wordt `outputs/mergin_maps/meijendel`. Deze uitvoer blijft
buiten Git; alleen de herhaalbare builder, tests en handleiding worden
versiebeheerd. Voor de eerste upload en latere synchronisatie is een Mergin
Maps-account nodig. Na downloaden blijven de kaart en invoer op de iPad offline
bruikbaar. Niet-gesynchroniseerde wijzigingen blijven lokaal op de iPad en
mogen daarom niet worden verwijderd voordat de synchronisatie is bevestigd.

## Veiligheid en grenzen

- De builder overschrijft geen project met bestaande punten, lijnen,
  polygonen, schetsen, tracks of foto's.
- Deze taak wijzigt de levende Meijendel-database niet.
- De veldregistraties zijn waarnemingen en geen vaststelling van juridische
  grenzen.
- Upload naar Mergin Maps gebeurt pas nadat Ton het account heeft gekoppeld en
  de lokale inhoud is gecontroleerd.

## Afrondcriteria

1. Het afzonderlijke project wordt herhaalbaar gebouwd onder de naam
   `meijendel`.
2. De luchtfoto, 55 kavels en drie meetlagen openen met relatieve paden.
3. Alle afgesproken categorieen staan in formulieren en legenda.
4. Map Sketching en Position Tracking zijn aantoonbaar ingeschakeld.
5. Tests bewaken de inhoud, paden en bescherming van veldgegevens.
6. De handleiding beschrijft accountkoppeling, downloaden, offline invoer,
   synchroniseren en veilig terughalen in QGIS.
