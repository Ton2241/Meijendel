# Projectinstructies Meijendel

Hou rekening met de volgende IT-infrastructuur:

1. iMac M1 8GB Tahoe 26.4 of later Opstart Macintosh HD
2. Samsung Portable SSD T7 2 terrabyte
3. NAS DS225+ met 6 GB geheugen
4. MySQL 9.7.1 op iMac en VPS

Op de lokale iMac staat `innodb_redo_log_capacity` persistent op 512 MiB. De
eerdere standaardwaarde van 100 MiB liet de server bij omvangrijke lokale
NDFF-bewerkingen vastlopen. Verlaag deze waarde niet zonder nieuwe meting.

Antwoord in het Nederlands, compact en praktisch.

Werk standaard op de lokale iMac M1 in mijn thuismap/projectmap. Ga ervan uit dat projecten lokaal staan tenzij ik expliciet zeg dat bestanden op de Samsung Portable SSD T7, op de NAS DS225+ of op de VPS staan. Vraag eerst om bevestiging voordat je paden op externe opslag of NAS gebruikt. Gebruik voor de NAS standaard Synology DSM via de browser.

## Lokale uitvoercontext is verplicht

- Voer `/Users/ton/Documents/GitHub/VWG_Project/scripts/workspace_preflight.sh`
  vanaf de eerste poging rechtstreeks uit in de lokale uitvoercontext op de
  iMac, met toegang tot `.git`, het netwerk en schrijfbare macOS-mappen voor
  tijdelijke bestanden en caches.
- Hetzelfde geldt voor Git-controles zoals `git status`, `git fetch`,
  `git worktree` en upstreamcontroles, en voor repositoryscripts, tests,
  R/Python-generatie en validatie die tijdelijke bestanden of caches kunnen
  maken.
- Probeer zulke opdrachten niet eerst in de beperkte Codex-sandbox. Mappen
  onder `/var/folders/.../T`, `/tmp` en `/var/tmp` en caches van macOS-tools
  kunnen daar onschrijfbaar zijn; die bekende uitvoerbeperking is geen
  project-, Git- of testresultaat.
- Gebruik de beperkte sandbox alleen voor zuivere bestandslezingen, zoals een
  gerichte `sed`- of `rg`-inspectie, waarvan vaststaat dat zij geen tijdelijke
  bestanden of caches maken.

Bij codewerk:
- bepaal bij iedere wijziging die gevolgen heeft voor de VWG-M-website welke
  gebruikers- en beheerhandleidingen geraakt worden; werk via `VWG_M` in
  dezelfde wijziging generatorbron, DOCX, HTML, eventuele PDF en e-mailbijlage
  bij en controleer ook verwijzingen, inhoudsopgaven, versiedatum,
  beheerhandleiding en regressietests; rond de wijziging niet af zolang deze
  teksten inhoudelijk verschillen
- onderzoek eerst kort de bestaande code en volg de bestaande patronen, naamgeving en structuur
- zoek eerst naar bestaande helpers of utilities voordat je nieuwe toevoegt
- lever standaard een werkende wijziging op in plaats van alleen een plan, tenzij ik expliciet om analyse of brainstorm vraag
- creëer geen nieuwe bestanden in de repo tenzij ik daar expliciet om vraag; uitzondering: bestanden die noodzakelijk zijn om bij een crash van de VPS de volledige omgeving op `app.vwg-m.nl` te herstellen mogen wel in de repo worden gezet
- wees voorzichtig met bestaande niet-door-jou-gemaakte wijzigingen en draai die nooit terug zonder expliciete instructie
- benoem aannames, risico's en blockers kort en concreet
- houd wijzigingen zo klein mogelijk, maar wel volledig genoeg om het probleem echt op te lossen
- voorkom regressies: laat bij wijzigingen aan dashboard, Shiny-app of VPS-website geen bestaande onderdelen, tekstblokken, grafieken, filters of toelichtingen verdwijnen tenzij daar expliciet om is gevraagd; controleer relevante bestaande UI-elementen na afloop
- voeg tests of verificatiestappen toe als dat logisch is; als je iets niet kon verifiëren, zeg dat expliciet
- voer tests, R/Python-generatie en andere controles die tijdelijke bestanden
  of caches maken vanaf de eerste poging uit in een lokale uitvoercontext met
  schrijfbare tijdelijke macOS-mappen; gebruik altijd een bestaande
  repositoriespecifieke controle- of generatiescript als dat beschikbaar is
- gebruik vóór fetch, lokale generatie en deploy
  `scripts/check_local_workspace.sh`; de vaste deploy- en generatiescripts
  roepen deze controle zelf aan
- commit afgeronde wijzigingen standaard met een korte, beschrijvende commitmelding en push de commit daarna naar GitHub, tenzij expliciet is gevraagd om niet te committen of niet te pushen.
- beheer vanaf nu de volledige Git-repository als onderdeel van het werk: controleer `git status`, houd wijzigingen logisch gegroepeerd, commit afgeronde wijzigingen, en laat niet-door-jou-gemaakte wijzigingen ongemoeid tenzij ik expliciet anders vraag
- als ik vraag een wijziging door te voeren voor `app.vwg-m.nl` of de VPS-site, voer die wijziging zowel lokaal als op de VPS door, inclusief passende verificatie na deploy

Bij iedere nieuwe opdrachtdraad en productiedeploy:
- controleer aan het begin én einde `VWG_Project`, `VWG_M` en `Meijendel`: haal remote refs op, meld de actieve branch en eis dat iedere lokale branch gelijkloopt met haar upstream; buiten een expliciet actieve taak hoort iedere werkboom schoon te zijn
- behandel een vooraf aangetroffen vuile werkboom niet als een normale toestand: stel eerst eigenaar en oorzaak vast; rond de wijziging veilig af en commit/push haar, of vraag de gebruiker als de bedoeling niet betrouwbaar is vast te stellen
- neem gegenereerde caches, tijdelijke bestanden en runtime-output nooit op in Git; als zo'n bestand al gevolgd wordt, haal het gecontroleerd uit Git en voeg het patroon toe aan `.gitignore`
- controleer `git worktree list --porcelain` op verwijzingen naar niet-bestaande tijdelijke worktrees en ruim alleen aantoonbaar `prunable` metadata op
- controleer eerst werkboom, actieve branch en lokale/remote branches; ga niet automatisch verder op de toevallig actieve branch
- gebruik een bestaande branch alleen als die aantoonbaar bij de taak past; maak anders vanaf de juiste actuele basis een taakgerichte branch
- ontwikkel en test op die taakbranch, maar merge vóór productie eerst naar `main`
- deploy uitsluitend vanaf een schone lokale `main` die exact gelijkloopt met `origin/main`; deploy nooit rechtstreeks vanaf een feature- of fixbranch
- gebruik uitsluitend het repositoriespecifieke deployscript; geen losse rsync-, SSH-, Docker- of databasewijzigingen als vervanging van de preflight
- de preflight moet controleren dat de op de VPS geregistreerde Meijendel-productiecommit een voorouder is van de nieuwe `main`, en moet een exclusieve VPS-deploy-lock gebruiken
- deploy één samenhangende release of een expliciet volledig manifest van afhankelijke SQL-, R-, dashboard-, CSV- en Shiny-bestanden; overschrijf geen gedeeld kernbestand los vanuit een andere branch
- wacht na herstart met begrensde retries op Shiny/dashboardgereedheid en voer daarna alle relevante rook- en inhoudscontroles uit
- registreer de nieuwe productiecommit pas na volledig groene nacontrole
- als het deployscript deze beveiligingen nog niet afdwingt, implementeer ze eerst en voer tot die tijd geen nieuwe productiedeploy uit
- gebruik herstelmodus alleen na expliciete bevestiging wanneer productie al defect is; ancestrycontrole, deploy-lock, manifest en volledige nacontrole blijven verplicht
- rond iedere geslaagde productiedeploy af door `/Users/ton/Documents/GitHub/VWG_Project/RELEASE_MANIFEST.yml` bij te werken: lees beide VPS-statebestanden, voeg een nieuwe release toe met exact de geregistreerde `VWG_M`- en `Meijendel`-commits, valideer ancestry en YAML, en commit/push/merge naar `VWG_Project/main`; hergebruik de bestaande commit van een ongewijzigde component en wijzig historische releases nooit
- meld een opdracht pas als volledig gesynchroniseerd wanneer `main == origin/main` in alle drie repositories, alle actieve taakbranches gelijklopen met hun upstream, de drie werkbomen schoon zijn en het productie-release-manifest overeenkomt met beide VPS-statebestanden
- rond imagebuilds en containerwissels pas af nadat alle in die taak gemaakte
  kandidaat-, test-, `previous`- en mislukte containers, tags en images exact
  zijn beoordeeld en na groene nacontrole zijn verwijderd; behoud uitsluitend
  actieve productie en de expliciet gedocumenteerde rollback
- bouw het Shiny-image altijd multi-stage: compilers, headers,
  `linux-libc-dev` en overige `*-dev`-pakketten horen uitsluitend in de
  builder; de runtime bevat alleen aantoonbaar gekoppelde uitvoerbibliotheken
- gebruik voor iedere Shiny-rebuild de vaste kandidaatpoort: verse no-cache
  build met exacte image-ID, 0 `CRITICAL`/0 `HIGH`, geïsoleerde proefcontainer
  op localhostpoort 3839 met productiemounts, package/cache/readinesscontrole,
  automatische rollback en daarna de volledige multi-hostrooktest
- gebruik gestopte containers niet als herstelbewijs: bewaar bewijs in exacte
  image-ID's, scanuitvoer, checksums, back-ups en het release-manifest; iedere
  rollback heeft een doel, laatste test en verwijdercriterium of beoordelingsdatum
- controleer vóór verwijdering altijd containerstatus, imageverwijzingen en
  mounts; bestaande rollbackdata verwijderen blijft een afzonderlijk expliciet
  beoordeelde handeling en een ongerichte Docker-prune is niet toegestaan

Bij communicatie:
- wees direct, feitelijk en beknopt
- behandel de gebruiker primair als vogelteller, voorzitter van de groep
  vogeltellers en systeembeheerder, niet als student of wetenschappelijk
  medewerker
- richt antwoorden op praktische toepasbaarheid, heldere conclusies,
  beheerkeuzes, communicatie en technische uitvoering, met als belangrijk doel
  dat de beheerder de verzamelde vogelgegevens vaker en intensiever gebruikt
- werk alleen op expliciet verzoek of bij strikte noodzaak een uitgebreide
  onderzoeksopzet of voorstellen voor vervolgonderzoek uit, en houd dit dan zo
  beknopt mogelijk
- voeg aan verhalen niet uit eigen beweging een methodologische
  onderzoeksagenda toe
- toets ieder nieuw of gewijzigd Meijendel-verhaal aan het actuele
  Natuurbeheerplan Zuid-Holland, het Natura 2000-beheerplan voor Meijendel &
  Berkheide en de nadere beleids- en beheerinvulling van Dunea; raadpleeg
  hiervoor de lokale Zotero-bibliotheek en daarnaast altijd actuele
  internetbronnen, met voorkeur voor primaire en officiële bronnen, onderscheid
  vastgesteld beleid, ontwerpplannen, beheerambities en concrete maatregelen,
  en gebruik alleen aantoonbaar relevante informatie
- geef bij grotere wijzigingen een korte samenvatting van wat is aangepast en hoe het is gecontroleerd
- stel alleen vragen als dat echt nodig is om veilig verder te kunnen

MySQL:
- gebruik voor lokale database-acties standaard de lokale MySQL-client
- voor inloggen is `-u root -p` nodig
- koppel ieder NDFF-record via een afzonderlijke recordkoppeling aan precies één
  interne `protocol_id`; gebruik `ndff_open_waarneming_protocol` voor openbare
  records en `Meijendel_ndff_secure.ndff_waarneming_protocol` voor beveiligde
  records
- behandel `protocol_sleutel` als de stabiele betekenisvolle identificatie en
  het numerieke `protocol_id` uitsluitend als foreign key
- registreer een aangeleverde protocolcode als `expliciete_code` en uitsluitend
  de letterlijke bronwaarde `Losse waarnemingen` als
  `expliciet_losse_waarneming` met sleutel `LOS`; leid `LOS` nooit af uit een
  lege of onbekende waarde
- houd protocolkwalificatie strikt gescheiden van analysetoelating:
  `analyse_status` is geen protocolstatus en beveiligde verspreidings-, trend-
  en innamevelden mogen hiervoor niet worden hergebruikt
- gebruik voor nieuwe NDFF-analyses uitsluitend regelversie
  `ndff-analysebesluit-v4` en doelbereikversie `ndff-protocolbereik-v2`; oudere
  versies zijn alleen historische auditlagen
- behandel `ndff_analysebesluit.eindbesluit = voorlopig_toegelaten` als
  toestemming voor uitsluitend verkennend gebruik op basis van
  protocolgeschiktheid; houd `gegevensgeschiktheid = niet_beoordeeld` totdat
  telobjecten, bezoeken, inspanning, nulwaarnemingen en meeteenheden zijn
  onderzocht en toon bij ieder resultaat verplicht de kwaliteitsvermelding uit
  `ndff_analysebesluit.reden`
- behandel protocollen `04.004` en `07.001` als gemengde positieve leveringen.
  Gebruik `V` voorwaardelijk na de ruimtelijke en PQ-poort. Gebruik `I` en `TV`
  uitsluitend voor indicatieve verandering in geregistreerde aanwezigheid met
  `gegevensgeschiktheid='onvoldoende'`; gebruik ze niet als gevalideerde trend.
  `TA` en `TK` zijn uitgesloten. Reconstrueer geen bezoeken, complete lijsten of
  nullen en aggregeer aangeleverde aantallen niet over records. Raadpleeg voor
  de status per analysetype altijd `ndff_analysebesluit`; de algemene
  `gegevensgeschiktheid` in `v_ndff_analyse_record` volgt de V-beslissing
- gebruik bij `alleen_na_doelsoortselectie` verplicht
  `ndff_protocol_soort_geschiktheid` en selecteer uitsluitend
  `doelrelatie='doelsoort'`; behandel iedere overige soort als bijvangst en dus
  alleen als positieve voorkomensinformatie (`V`)
- behandel `doelrelatie='onbepaald'` eveneens uitsluitend als `V`; deze klasse
  betekent dat de aangeleverde taxonnaam zowel een doelsoort als een
  niet-doelsoort kan omvatten
- gebruik combinaties met `wacht_op_doelsoortafbakening` voorlopig uitsluitend
  voor `V`; een protocolcode alleen bewijst daar niet dat het record een
  doelsoort betreft
- behandel SNL-protocol `12.205` als beoordelings- en subsidiecontext, niet als
  bewijs van een onafhankelijke bron. Gebruik recordstatussen uit
  `ndff_snl_waarneming_context`: `overlap_bevestigd`, `overlap_mogelijk`,
  `geen_overlap_gevonden` en `onvoldoende_onderzocht`. Alleen
  `overlap_bevestigd` betekent aangetoonde dubbeling; `geen_overlap_gevonden`
  betekent nadrukkelijk niet dat onafhankelijkheid bewezen is
- gebruik voor gecombineerde lokale NDFF-analyse uitsluitend
  `Meijendel_ndff_secure.v_ndff_canonieke_waarneming`: beveiligde matches
  vervangen daarin hun openbare tegenhanger en mogen nooit als extra record
  worden geteld. Deze interne view bevat exacte geometrie en mag niet aan
  gewone accounts, Shiny, VPS of webexports worden toegekend
- laat iedere nieuwe selectie voor inhoudelijke analyse vervolgens via
  `Meijendel_ndff_secure.v_ndff_analyse_record` lopen. Selecteer alleen records
  met `record_selectiestatus = 'voorlopig_bruikbaar'`; behandel
  `voorlopig_met_overlapwaarschuwing` afzonderlijk en sluit alle
  `uitgesloten_*`-statussen uit. Gebruik alleen een analysetype dat voorkomt in
  `protocol_kandidaattypen`, behoud `gegevensgeschiktheid` als afzonderlijke
  validatiestatus en toon bij ieder resultaat de `kwaliteitsmelding`. De view
  bevat geen geometrie of exacte datum maar blijft intern en krijgt geen
  gewone of Shiny-rechten
- gebruik voor positieve verspreidingssignalen de reeds gefilterde view
  `Meijendel_ndff_secure.v_ndff_verspreiding_plot_jaar_taxon` en voor selectie
  van protocolmatige trendkandidaten
  `Meijendel_ndff_secure.v_ndff_trendkandidaat_plot_jaar_taxon`. Interpreteer
  `bronrecords_ter_controle` uitsluitend als herkomstcontrole, nooit als
  abundantie of trend. Neem de velden `gegevensgeschiktheid` en
  `kwaliteitsmelding` zichtbaar mee in iedere afgeleide uitvoer. Verleen deze
  views niet aan extra accounts zonder afzonderlijke beoordeling
- raadpleeg vóór iedere nieuwe NDFF-analyse
  `Meijendel_ndff_secure.v_ndff_gebruiksdekking_soortgroep_protocol` voor de
  sluitende omvang per soortgroep, protocol, kandidaat-analysetype,
  uitsluitingsreden, beveiligingsstatus en resterende validatiebehoefte
- gebruik voor beschrijvende jaarniveau-analyses uitsluitend de views
  `v_ndff_soortenrijkdom_plot_jaar`, `v_ndff_eerste_laatste_plot_taxon`,
  `v_ndff_verspreidingsverandering_taxon_jaar` en
  `v_ndff_dekking_intensiteit_plot_jaar_soortgroep`. Interpreteer eerste/laatste
  registratie nooit als vestiging/verdwijning, gebruik voor jaar-op-jaar alleen
  `aansluitend_jaar = 1` en behandel ontbrekende jaren nooit als nul of
  afwezigheid
- gebruik uitsluitend de vaste lokale ketenversie `ndff-analyseketen-v1` en
  voer vóór formele analyserapportage de alleen-lezen controle uit met
  `python3 gis/scripts/import_ndff_protocolkwaliteit.py --audit-live`. Een
  geslaagde audit bewijst technische reproduceerbaarheid voor verkennende
  verspreidingsanalyse, niet dat protocolkandidaten al trendklaar zijn. Leg
  iedere latere inhoudelijke wijziging vast onder een nieuwe ketenversie
- verkennende berekeningen zijn toegestaan met de voorgeselecteerde views,
  mits `gegevensgeschiktheid` en `kwaliteitsmelding` zichtbaar blijven. Benoem
  resultaten als geregistreerde aanwezigheid, verandering in registraties,
  meldingsintensiteit of associatie. Gebruik zonder aanvullende validatie nooit
  de kwalificaties gevalideerde populatietrend, abundantie, afwezigheid of
  causaal beheereffect
- behandel een expliciete NEM-protocolcode als bewijs dat de positieve regel
  uit een protocolgeldig bezoek komt. Reconstrueer vóór trendanalyse wel de
  native meeteenheid en de bezoekmatrix. Leid echte nullen uitsluitend af voor
  de doelsoorten en bezochte meeteenheden die het betreffende NEM-protocol
  volledig bestrijkt; leid nooit nullen af voor bijvangsten
- gebruik voor dagvlinderprotocol `03.201` de lokale reconstructieversie
  `ndff-vlinderroute-v1`. De tabellen in `Meijendel`, te beginnen met
  `Meijendel.ndff_vlinder_routefamilie`,
  `ndff_vlinder_routegeometrie`, `ndff_vlinder_bezoek` en
  `ndff_vlinder_bezoek_taxon` bevatten de afgeleide route-, bezoek- en
  doelsoortmatrix. Sluit `geen_route` uit van routeanalyses en behandel
  `handmatige_controle` afzonderlijk. Controleer de laag vóór gebruik met
  `python3 gis/scripts/import_ndff_protocolkwaliteit.py --audit-vlinders`
- behandel de binnen `03.201` geregistreerde Vliesvleugeligen als een
  zelfstandige NEM-deelreeks, niet als bijvangst. Gebruik reconstructieversie
  `ndff-vliesvleugelroute-v1` en de vier tabellen
  `Meijendel.ndff_vliesvleugel_*`. Een bezoek telt voor deze deelreeks alleen
  als op dat tijdstip minstens één vliesvleugelige is geregistreerd; alleen
  binnen die bezoeken mogen nullen voor de zes gevolgde taxa worden afgeleid.
  Controleer met `--audit-vliesvleugelen`
- gebruik voor libellenprotocol `07.201` reconstructieversie
  `ndff-libellenroute-v1` en de vier openbare tabellen
  `Meijendel.ndff_libel_*`. Gebruik uitsluitend `doelbereikstatus =
  'algemene_route'` voor afgeleide nullen. Bij `onbepaald` blijft alleen de
  positieve telling staan. Grove geometrie zonder routefamilie mag een geldig
  bezoek blijven, maar niet als exacte route worden geïnterpreteerd. Controleer
  vóór gebruik met `--audit-libellen`
- gebruik voor reptielenprotocol `10.201` reconstructieversie
  `ndff-reptielroute-v1` en de vier openbare tabellen
  `Meijendel.ndff_reptiel_*`. Een bezoek is routefamilie plus kalenderdatum;
  gebruik de ruwe begin- en eindtijd niet als inspanning. De FFV-laag bevat
  alleen bezoeken met minstens één positieve reptielenwaarneming. Gebruik de
  afgeleide echte nullen uitsluitend voor Hazelworm binnen deze bevestigde
  bezoeken; leid geen Zandhagedisnullen of geheel ontbrekende bezoeken af.
  Sluit `geen_route` uit van routeanalyse en controleer vóór gebruik met
  `--audit-reptielen`
- gebruik voor amfibieënprotocol `01.201` reconstructieversie
  `ndff-amfibiewater-v1` en de vijf openbare tabellen
  `Meijendel.ndff_amfibie_*`. Een telgebiedbezoek kan meerdere bevestigde
  waterbezoeken bevatten. Leid echte nullen alleen af voor de zeven openbare
  analysetaxa binnen een water met minstens één positieve 01.201-registratie;
  interpreteer zo'n nul als niet aangetroffen tijdens dat bezoek, niet als
  biologische afwezigheid. Houd exacte aantallen, presentieklassen,
  minimumaantallen, schattingen en gemengde waarden gescheiden. Leid geen
  waterkoppeling of nul af voor de 80 vervaagde, jaarlijks geaggregeerde
  Kamsalamanderrecords. Controleer vóór gebruik met `--audit-amfibieen`
- gebruik voor vleermuistransectprotocol `17.208` reconstructieversie
  `ndff-vleermuistransect-v1` en de vijf openbare tabellen
  `Meijendel.ndff_vleermuis_*`. Houd de NEM-VTT-autoroute en vleerMUS-fietsroute
  als afzonderlijke meetreeksen. Gebruik alleen de doelsoortenlijst van de
  betreffende methodevariant voor afgeleide nullen; overige positieve taxa
  zijn bijvangst. Interpreteer `detectieaantal` als akoestische detecties en
  nooit als aantallen individuen. Behoud de 73 onderdrukte dubbele
  vleerMUS-aanleveringen uit 2019 in de recordselectie voor het auditspoor.
  Controleer vóór gebruik met `--audit-vleermuizen`
- gebruik voor konijnentelprotocol `17.209` reconstructieversie
  `ndff-konijnentelling-v1` en de twee openbare tabellen
  `Meijendel.ndff_konijn_*`. De FFV-export bevat exacte positieve
  sectietellingen maar geen route- of sectie-id. Behandel een kilometerhok,
  kalenderdatum of hok-datum-taxonaggregaat nooit als native route, sectie of
  bezoek. Onderdruk gelijke telwaarden niet als dubbel en leid geen nul af.
  Sluit de 11 als `mogelijke_overlap_17_204` gemarkeerde regels niet zonder
  aanvullende bronkoppeling samen met DAZ-BMP in één telling. Controleer vóór
  gebruik met `--audit-konijnen`
- gebruik voor DAZ-BMP-protocol `17.204` reconstructieversie
  `ndff-daz-bmp-v1` en de vier openbare tabellen
  `Meijendel.ndff_daz_bmp_*`. Dit zijn zoogdierregistraties door het deel van
  de BMP-vogeltellers dat aan DAZ deelnam; het zijn geen vogelwaarnemingen.
  Beschouw een BMP-bezoek alleen als deelnemend wanneer minstens één
  17.204-record eenduidig op datum en SOVON-plot aan dat bezoek is gekoppeld.
  Leid alleen binnen zo'n bevestigd bezoek echte nullen af voor de zeven
  DAZ-doelsoorten. Een meervoudig koppelbaar record van hetzelfde taxon
  blokkeert die nul. Leid nooit nullen af voor bijvangsten of voor overige
  BMP-bezoeken. Controleer vóór gebruik met `--audit-daz-bmp`
- behandel `ndff-daz-bmp-v1` als tijdelijke reconstructie totdat na afronding
  van alle NDFF-protocolbewerkingen een nieuw volledig BMP/SAP-bestand met
  zoogdierbijvangst per telling is ontvangen. Geef dan de primaire BMP/SAP-
  registratie voor bezoekdeelname, telling, nul en eventuele exacte locatie
  voorrang; behoud NDFF als secundaire controlebron en voer de verbetering uit
  onder een nieuwe reconstructieversie
- gebruik voor zeereeppaddenstoelenprotocol `11.202` reconstructieversie
  `ndff-zeereep-v1` en de drie openbare tabellen `Meijendel.ndff_zeereep_*`.
  De native meeteenheid is het RD-kilometerhok en een bezoek is hok plus
  kalenderdatum. Gebruik alleen onvervaagde records voor de bezoekmatrix en
  leid nullen uitsluitend af voor de zes typische doelsoorten. Behoud
  NMV-aantalsklassen als vindplaatsklassen; tel ze nooit op als aantallen
  vruchtlichamen. Markeer bezoeken buiten oktober-december en vermeld bij
  analyse dat bezoektijd en waarnemersbekwaamheid nog niet uit de NDFF-export
  zijn gevalideerd. Controleer vóór gebruik met
  `--audit-zeereeppaddenstoelen`
- gebruik voor het historische bospaddenstoelenprotocol `11.201`
  reconstructieversie `ndff-bospaddenstoel-v1` en de zeven openbare tabellen
  `Meijendel.ndff_bospaddenstoel_*`. Gebruik de recordselectie om 473 parallelle
  presentieregels niet naast hun exacte vruchtlichaamtelling mee te tellen.
  Leid bezoeknullen alleen af voor telsoorten die op hetzelfde vaste meetpunt
  ooit positief zijn gemeld; dit is het conservatief aantoonbare minimum van het
  oorspronkelijke doelbereik. Een nul betreft vruchtlichamen op één bezoek,
  niet afwezigheid van mycelium of geschiktheid van de habitat. Gebruik voor een
  jaar het hoogste dagtotaal uit `ndff_bospaddenstoel_jaar_taxon`, nooit de som
  van bezoeken, en vul geen volledig negatieve ontbrekende bezoeken aan. Houd
  `11.201` gescheiden van `11.204` en controleer vóór gebruik met
  `--audit-bospaddenstoelen`
- gebruik voor Het Nieuwe Strepen-protocol `12.204` reconstructieversie
  `ndff-hns-v1` en de vijf openbare tabellen `Meijendel.ndff_hns_*`. Behandel
  de 1.145 verschillende bronintervallen niet als bezoeken. Leid echte nullen
  uitsluitend af binnen de 23 als `volledige_lijst_aannemelijk`
  geclassificeerde datum/ruimteclusters en het daaruit aantoonbare lokale
  doelbereik. Kleine fragmenten en vervaagde jaarregels blijven uitsluitend
  positieve verspreidingsinformatie. Beschouw herhaalde datumclusters niet als
  bewezen onafhankelijke tellers zolang lijst- en waarnemer-ID ontbreken. Tel
  aantallen of dubbele vindplaatsen nooit als plantenabundantie en controleer
  vóór gebruik met `--audit-hns`
- gebruik voor korstmossenprotocol `02.202` reconstructieversie
  `ndff-korstmos-v1` en de vijf openbare tabellen `Meijendel.ndff_korstmos_*`.
  Leid echte nullen alleen af binnen de 32 bevestigde bezoeken en de dertig
  openbare taxa. Tel 67 gelijke parallelle registraties niet dubbel; sluit de
  tien bezoek-taxoncombinaties met tegenstrijdige bedekkingsklasse uit van
  abundantievergelijking. Behandel de twee FFV-bedekkingsklassen uitsluitend
  ordinaal. Kopieer de twintig vervaagde Saucijs-baardmosrecords niet naar de
  openbare afgeleide tabellen en controleer vóór gebruik met
  `--audit-korstmossen`
- gebruik voor mossenprotocol `02.204` reconstructieversie `ndff-mos-v1` en de
  vijf openbare tabellen `Meijendel.ndff_mos_*`. De native meeteenheid is het
  volledige kilometerhok. Behandel de 21 bronperioden als onderdelen van zeven
  hokinventarisaties, nooit als onafhankelijke herhaaltellingen. Leid echte
  nullen alleen af op hokniveau binnen de 111 openbare taxa; verdeel een
  hokuitkomst niet over geraakte SOVON-plots. Gebruik de drie BLWG-klassen
  uitsluitend ordinaal, houd presentiewaarden en abundantieconflicten apart en
  leid geen lokale tijdtrend af omdat geen hok is herhaald. Kopieer het ene
  vervaagde record niet naar de openbare afgeleide tabellen en controleer vóór
  gebruik met `--audit-mossen`
- gebruik voor FLORBASE-protocol `12.001` reconstructieversie
  `ndff-florbase-v1` en de vier openbare tabellen
  `Meijendel.ndff_florbase_*`. Groepeer per werkelijk RD-kilometerhok en jaar.
  Behandel alleen hok-jaren met minimaal 50 geregistreerde taxa als
  `volledige_lijst_aannemelijk`; dit is een voorlopige reconstructieregel en
  geen officiële FLORON-norm. Leid uitsluitend daar
  `protocolnul_onder_volledigheidsaanname` af. Houd kleinere lijsten als
  positieve fragmenten, aggregeer aantalsinformatie niet, verdeel geen
  hokuitkomsten over SOVON-plots en toon altijd dat volledigheidsvlag,
  bezoekduur en historische checklistversie ontbreken. Kopieer de 213
  vervaagde records niet naar de openbare afgeleide tabellen en controleer vóór
  gebruik met `--audit-florbase`
- gebruik voor HabSlak-protocol `04.006` reconstructieversie
  `ndff-habslak-v1` en uitsluitend de vier openbare tabellen
  `Meijendel.ndff_habslak_*`. Groepeer onvervaagde records per kalenderdatum en
  openbare geometrie; bewaar verschillende telonderwerpen afzonderlijk en tel
  ze niet op. Behandel begeleidende soorten alleen als positieve waarneming.
  Leid voor Nauwe korfslak uitsluitend op kilometerhok-jaar een voorlopige
  `protocolnul_onder_doelbereikaanname` af wanneer minimaal 15 unieke kansrijke
  monsterlocaties zijn gereconstrueerd en geen positieve doelsoortmelding
  aanwezig is. Kopieer geen exacte beveiligde vindplaats naar de openbare
  afgeleide tabellen en controleer vóór gebruik met `--audit-habslak`
- sla alle openbare NDFF-brondata en alle daaruit afgeleide tabellen standaard
  op in `Meijendel`. `Meijendel_ndff_secure` is een zeer hoge uitzondering en
  bevat uitsluitend afzonderlijke waarnemingen waarvan de openbare NDFF-locatie
  daadwerkelijk is vervaagd, met de bijbehorende onvervaagde leveringsdetails.
  Iedere nieuwe tabel, view of gegevensklasse in dit beveiligde schema vereist
  voorafgaande uitdrukkelijke toestemming van de eigenaar
- interpreteer NEM-protocolkwaliteit niet als toestemming om willekeurige
  positieve NDFF-regels rechtstreeks aan TRIM te voeren. TRIM krijgt pas een
  matrix nadat meeteenheid, bezoeken, doelsoorten, tellingen en geldige echte
  nullen protocolconform zijn gereconstrueerd
- pas voor openbare NDFF-records altijd `ndff_open_pq_koppeling` met
  regelversie `ndff-open-pq-poort-v1` toe. Protocollen `12.007` en `12.202`
  zijn secundaire PQ-controlebron en mogen niet naast de provinciale PQ-reeks
  meetellen; leid PQ-status nooit uitsluitend uit de bronhouder af
- laat bijvangst en `algemene_bron` nooit een niet-V-analysetype erven van het
  bijbehorende protocol

GIS / R-spatial:
- ga ervan uit dat de lokale iMac native Apple Silicon draait: `uname -m` = `arm64` en R `R.version$arch` = `aarch64`
- gebruik geen Intel/Rosetta-R, oude Intel-builds of oude QGIS-bundels als basis voor nieuw spatial werk
- ga ervan uit dat Homebrew en de spatial libraries `gdal`, `geos`, `proj`, `sqlite`, `udunits`, `netcdf` en `cmake` lokaal beschikbaar zijn
- gebruik voor R-spatial standaard actuele Apple Silicon R/RStudio met o.a. `sf`, `terra`, `stars`, `exactextractr`, `tmap`, `leaflet`, `mapview`, `osmdata`, `tidyverse`, `DBI`, `RPostgres` en `duckdb`
- verifieer spatial wijzigingen waar logisch met een kleine `sf`-test (`st_read(system.file("shape/nc.shp", package="sf"))`) en/of `terra`-test (`rast(nrows=100, ncols=100)`)
- werk script-based en reproduceerbaar; vermijd handmatige QGIS -> Excel -> R workflows en analyses buiten scripts
- gebruik GeoPackage (`.gpkg`) als standaard vectorformaat; vermijd shapefiles als hoofdformaat vanwege kolomnaam-, encoding- en meerbestandsproblemen
- overweeg PostGIS als volgende stap voor centrale ruimtelijke opslag en queries; koppel waar relevant met MySQL, Shiny/PWA en Leaflet
- hanteer voor nieuw GIS-werk bij voorkeur deze projectstructuur: `GIS/data_raw/`, `GIS/data_processed/`, `GIS/rasters/`, `GIS/vectors/`, `GIS/scripts/`, `GIS/outputs/`, `GIS/maps/`, `GIS/shiny/`, `GIS/database/`
- relevante Meijendel-toepassingen zijn o.a. AHN-rasters, stikstofkaarten, beheerpolygonen, afstand tot paden, spatial joins met territoria, NDFF/SOVON-import, plotgewogen indices en interactieve kaarten

VPS / app.vwg-m.nl:
- `app.vwg-m.nl` bevat op productie alleen het dashboard en de Shiny-app
- alle grafieken op `app.vwg-m.nl` moeten qua cijfers en opmaak exact overeenkomen met de grafieken in het dashboard; gebruik daarom dezelfde brondata, berekeningslogica, schaal, labels, legenda, kleuren en onzekerheidsweergave
- de ledenadministratie/PWA staat niet meer op de VPS; containers `leden_pwa_web` en `leden_pwa_mysql` horen daar niet te draaien
- toegang tot dashboard, SQL, Shiny en dashboard-output op `app.vwg-m.nl` loopt via Caddy `forward_auth` naar de VWG-M ledenlogin; er is geen PWA-login of magic-link-login op productie
- bij vragen over toegang tot `app.vwg-m.nl`: kijk eerst naar de Caddy `forward_auth`-configuratie en de routes voor dashboard en Shiny, niet naar de verlaten PWA
