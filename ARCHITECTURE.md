# Architectuur

Dit project bestaat uit twee nauw gekoppelde repositories en een VPS-productieomgeving.

## Repositories

- `/Users/ton/Documents/GitHub/Meijendel` bevat `meijendel.sql`, R-analyses, Shiny, dashboard/HTML-output, GIS-data en analysemiddelen.
- `/Users/ton/Documents/GitHub/VWG_M/website/vwg-m-linux-app` bevat de FastAPI/Jinja-site voor `app.vwg-m.nl` en straks `www.vwg-m.nl`.
- Projectbrede afspraken staan in `/Users/ton/Documents/GitHub/VWG_Project`.
- Wijzigingen worden lokaal gemaakt en na controle standaard gecommit in de betreffende repository met een korte, beschrijvende commitmelding.

## Productie

- VPS: `45.87.43.90`.
- App-pad: `/srv/vwgm/vwg-m-linux-app`.
- Runtime-data: onder meer `/srv/vwgm/www`, uploads, archiefdocumenten, dashboard/grafiekoutput en back-ups.
- Canonieke SQL: `/srv/vwgm/data/Meijendel.sql`.
- Caddy verzorgt TLS, reverse proxy en `forward_auth` naar de ledenlogin.

## Applicaties

- Publieke site: Start, Meijendel, Vogels, Groepen, Tellingen, Nieuws en Werkgroep.
- Ledenomgeving: dashboard, nieuws toevoegen, mediabibliotheek, archief, contentbeheer, administratie, kavelbeheer, systeembeheer, auditlogboek, back-ups en bezoekersstatistiek.
- Dashboard en Shiny blijven onderdeel van dezelfde productieomgeving, maar zijn afgeschermd via Caddy.

## Databases

- Lokale live Meijendel-database op iMac: MySQL 9.5.0.
- Lokale MySQL is bron voor historische/controlerende gegevens zoals `tellers`, `plots` en `plot_jaar_teller`.
- VPS PostgreSQL is operationele bron voor ledenadministratie, CMS, nieuws, archief, kavelbeheer, auditlogging en back-upmetadata.
- `meijendel.sql` is data-/importbron en back-upformaat, niet bedoeld voor snelle webrequests.

## Functionele vogelgroepen en traits

De bestaande tabellen `soorten_kenmerken`, `soorten_kenmerken_datadictionary` en
`soorten_kenmerken_hoofdcategorien` blijven tijdens de migratie de ongewijzigde
legacybron. Hun codes worden niet hernoemd: bestaand `F` betekent functionele
habitat/foerageerwijze en bestaand `V` betekent voedsel van volwassen vogels.

De in fase B geïmplementeerde traitlaag bestaat uit de volgende onderdelen:

- `trait_definition`: versieerbare definitie, domein, datatype, eenheid,
  levensfase en standaardseizoen van één trait;
- `trait_category`: toegestane categorieën voor categorische traits;
- `trait_source`: volledige bron, datasetversie, DOI/URL, licentie en
  raadpleegdatum;
- `trait_import_batch`: reproduceerbare import met bronversie, bestands-SHA en
  gebruikte taxonomie;
- `trait_taxon_mapping`: expliciete koppeling tussen bronnaam en Meijendel-soort;
- `trait_analysis_scope` en `trait_analysis_scope_species`: versieerbare
  afbakening van de 95 soorten met een bruikbare TRIM-reeks;
- `species_trait_value`: één soortwaarde met afzonderlijke velden voor numeriek,
  boolean of categorie, plus seizoen, levensfase, geografische/populatiecontext,
  kwaliteitsstatus en voorkeursstatus;
- `species_trait_value_source`: één of meer bronnen per soortwaarde;
- `legacy_trait_mapping`: expliciete, beoordeelde vertaling van een bestaande
  code naar nul, één of meer nieuwe traits;
- `functional_group_definition`: versie, onderzoeksvraag, drempels en
  machineleesbare selectieregel van een afgeleide groep;
- `functional_group_membership`: reproduceerbare materialisatie per
  groepsversie met binair lidmaatschap, gewicht, onderbouwing en generatiecommit.
- `v_trait_gap_v1`: controleweergave voor alle 95 × 14 verplichte
  soort-traitcombinaties en de benodigde vervolgactie.

Belangrijke constraints:

- precies één waardetype per niet-onbekende `species_trait_value`; een expliciete
  `unknown` heeft juist geen numerieke, boolean- of categoriewaarde;
- onbekend is `NULL` met status `unknown`, nooit automatisch `FALSE` of `0`;
- proporties liggen tussen 0 en 1;
- maximaal één voorkeurswaarde per soort, trait, levensfase, seizoen en context
  bij scalaire traits;
- bij meerkeuzetraits maximaal één voorkeurswaarde per soort, trait, categorie,
  levensfase, seizoen en context;
- een publiceerbare waarde heeft minimaal één controleerbare bron;
- soorten mogen in meerdere functionele groepen voorkomen;
- afgeleide groepen lezen uitsluitend goedgekeurde voorkeurswaarden van een
  vastgelegde traitversie.

De nieuwe tabellen staan sinds fase B naast de ongewijzigde legacytabellen. Naast
de 14 verplichte doeltraits bevat `TR1` acht ondersteunende brontraits. De
bronhiërarchie voor de doelcontext is: Nederlandse soortbron, Europese fallback,
mondiale fallback. Het Nederlands Soortenregister en de Vogelbescherming-
vogelgids dekken elk alle 95 scopesoorten; Europese en mondiale waarden behouden
hun oorspronkelijke context en worden niet stilzwijgend lokaal gemaakt.

Voor alle 95 × 14 doelcontexten is een goedgekeurde voorkeurswaarde vastgelegd.
Kwalitatieve Nederlandse feiten zijn met vaste klassen omgezet in
semikwantitatieve analyseproxies. De omzettingsregel is zelf als bron
`TR1_DERIVATION_RULES_V1` geregistreerd; iedere eindwaarde verwijst daarnaast
naar minimaal twee inhoudelijke bronnen. `confidence_score` en `evidence_note`
maken onderscheid tussen directe classificatie en grovere proxy. Categorie
`not_applicable` maakt bij niet-holenbroeders expliciet onderscheid tussen
"niet van toepassing" en onbekend. De gapview aggregeert meerkeuzecategorieën en
rapporteert alle 1.330 verplichte cellen als `gereed`.

Dashboard, Shiny en website schakelen pas om nadat de inhoudelijke beoordeling,
groepsafleiding en pariteitscontroles groen zijn. De legacytabellen blijven tot na
die omschakeling read-only beschikbaar.

## Grafieken

Alle grafieken op de FastAPI/Jinja-site moeten overeenkomen met het dashboard. Het dashboard is leidend voor brondata, berekening, schaal, labels, legenda, kleuren en onzekerheidsweergave.

Webgrafieken gebruiken vooraf gegenereerde dashboard-output/CSV. Parse `meijendel.sql` niet per webrequest.

## Toegang

- Toegang tot dashboard, SQL, Shiny en dashboard-output loopt via Caddy `forward_auth` naar de VWG-M ledenlogin.
- Er is geen Appsmith-, PWA- of magic-link-login voor de actuele productie-inrichting.
- Appsmith- en PWA-documentatie is historische context, niet leidend voor productie.

## Back-up

Er is een bare-metal back-uproutine op de VPS. De NAS DS225+ haalt de nieuwste back-up rechtstreeks vanaf de VPS naar de gedeelde map `VWG-M-Backups`.

Runtime-data hoort in back-ups. Secrets, SSH keys en wachtwoorden horen niet plaintext in Git, maar moeten wel herstelbaar zijn via de afgesproken beheer- en herstelprocedure.
