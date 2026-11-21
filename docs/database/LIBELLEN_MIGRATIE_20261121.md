# Libellenmeetnet en EIS-levering

## Toetsingsbasis 21 november 2026

[Darwin Core](https://dwc.tdwg.org/terms/) gebruikt `occurrenceID` voor de
waarneming en `eventID` voor het meetevent. De bestaande `waarneming_id` en
`bezoek_sleutel` behouden hun eigen betekenis. Het meetnetprotocol 07.201
behoudt zijn reconstructieversie, telbereik en bronverwijzingen. De EIS-URI
uit de levering van 20 november is een bronidentificatie van een occurrence
en biedt geen bezoekidentificatie voor protocol 07.001.

[TDWG TCS, versie 2025-12-11](https://tcs.tdwg.org/terms/) onderscheidt
`TaxonName` van `TaxonConcept` en de bron daarvan (`accordingTo`).
De migratie behoudt de koppeling naar `taxa_bronkoppeling`, `taxa` en
`taxon_groepen`. Een gelijk gespelde soortnaam is onvoldoende bewijs
voor een waarnemingskoppeling.

## Migratie

Gebruik `gis/database/libellen_meetnet_hernoemen_20261121.sql` na een
gecontroleerde herstelkopie. Controleer dat de vier brontabellen bestaan en
de vier bestemmingsnamen vrij zijn. Bewaar de vergelijking van rijen en
foreign keys vóór en na de operatie. Na hernoeming verplaatst `central_derived_rename_sql()` de 29 bestaande
versiegebonden bronidentiteiten. De 13.173 bezoek-soortregels houden
hun `taxon_bronkoppeling_id`. Installeer daarna de drie relevante
definities uit `central_query_triggers_sql()` voor de nieuwe toestand.
Voor herstel worden eerst de vier tabelnamen teruggezet en daarna de
29 bronidentiteiten en oorspronkelijke triggers. Bewaar de herstelkopie
op de vaste T7-back-uplocatie.

## Controle van de EIS-levering

De originele bijlage uit Thunderbird heeft SHA-256
`b7122078f417a459afe69370733ff5cea2bcf93e9e2f509aec40403de2f0be8d`.
De werkmap op T7 bevat de gecontroleerde bronkopie en de resultaten van de
datum-, hok- en soortvergelijking. Zie het bronregister voor de beslisstand.

De proef met echte bronrijen onder MySQL 9.7.4 geeft gelijke SHA-256-waarden
voor de vier meetnettabellen en hun 3.280 bronkoppelingen. De libellenaudit
vindt 461 bezoeken, 13.173 bezoek-soortregels, 9 routefamilies en 18
routegeometrieën in 2007–2021 en nul inhoudelijke afwijkingen. De drie
taxontriggers moeten bij live hernoeming mee over naar de nieuwe tabelnaam.
De twee tabelgebonden triggernamen volgen `central_trigger_name()`; de
centrale trigger `cq_registry_bu` houdt zijn naam en verwijst naar de nieuwe
bezoek-soorttabel. De proef bevestigt dat alle 13.173 bezoek-soortregels
via het bestaande taxonregister en hun taxongroep bereikbaar blijven.

Herstelkopie van de betrokken tabellen in de vaste T7-back-upmap:
`Meijendel-voor-libellen-meetnet-20261121.sql.gz`, SHA-256
`91652e08e6fc6c2ee755eb4a3b97f8f20276160f2c02290e2f0ba2644483321f`.
De oorspronkelijke triggerdefinities staan in
`Meijendel-voor-libellen-meetnet-triggers-20261121.sql`, SHA-256
`7d446b19dd7ec8630bd9563dcff7c554eb537822c8094ccd848d06efeeba97c0`.

De levende uitkomst is op 21 november 2026 gecontroleerd met rijhashes, de
libellenaudit en een vergelijking van de volledige TV- en TA-selecties
vóór en na hernoeming. Beide selecties omvatten 98 bezoeken uit 2010–2021,
515 bronregels en 2.842 bezoek-soortregels. De uitkomsten zijn gelijk.

De databasebrede eindcontrole vond 335 tabellen en 132 taxonroutes,
met nul fouten. De volledige NDFF-contracttest stopt ook op de
ongewijzigde uitgangscommit 43d88485 bij een bestaande Sovon-assertie
over `sovon_bmp_bezoek`. De afzonderlijke libellentests en de centrale
taxoncontracttest slagen.

## Invoer van de EIS-levering

Na herbeoordeling van het volledige profiel zijn 2.247 bronverrijkingen
en twee nieuwe besloten waarnemingen verwerkt. De twee nieuwe regels uit
1998 hebben bestaande centrale soortidentiteit via de NDFF-catalogus en
behouden hun oorspronkelijke hok, EIS-URI en protocol 07.001. De oude
periodecontrole in het besloten batchregister is uitsluitend voor deze
levering aangevuld met eindjaar 2008. De oorspronkelijke bron, de
invoerscriptuitvoer, het besluit over de 343 onbesliste regels en de
herstelbestanden zijn op T7 geregistreerd. Twee opeenvolgende invoeren
op de proefserver leverden 2.247 verrijkingen en twee nieuwe regels,
gevolgd door nul toevoegingen. Dezelfde controle is lokaal herhaald.

## Nadere bronkoppeling

De 2.247 eerste koppelingen bevestigen dat de openbare FFV-identiteit
exact SHA-256 is van de letterlijke EIS-waarnemings-URI. Van de 343
resterende regels hebben 321 diezelfde unieke identiteit bij een
bestaand libellenrecord uit 1958–2007. Ook periode, hokgeometrie, aantal
en protocol 07.001 komen overeen. Die koppelingen zijn toegevoegd aan
`ndff_open_leveringsverrijking` onder methode `eis_uri_sha256_identiteit`.
De eerder ingevoerde koppelingen zijn eveneens exact bevestigd.

De herstelproef begon met 2.247 koppelingen, voegde er 321 toe en vond bij
herhaling nul nieuwe regels. Een gerichte terugdraaiing herstelde het
oorspronkelijke aantal. De levende database telt 2.568 unieke gekoppelde
EIS-URI's. Voor 22 EIS-regels uit 1971–2006 ontbreekt een overeenkomstige
identiteit in beide NDFF-registers. Er zijn in deze taak geen nieuwe
waarnemingen geregistreerd.

De herstelkopie van de verrijkingstabel staat op T7 als
`Meijendel-voor-EIS-bronkoppelingen-20261121.sql.gz` met SHA-256
`36021d85a9e077a61391eea583d8167b8741be4cbc3fa462f19c1dddf3bd7720`.
Import-, herstel- en selectiebestanden staan in de geregistreerde
T7-proefmap met voorvoegsel `eis-nader-`.
