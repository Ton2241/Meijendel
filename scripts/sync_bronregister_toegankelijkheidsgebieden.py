#!/usr/bin/env python3
"""Synchroniseer het actuele toegankelijkheidsgebiedsmodel naar het bronregister-DOCX."""

from pathlib import Path

from docx import Document
from docx.oxml import OxmlElement
from docx.text.paragraph import Paragraph


ROOT = Path(__file__).resolve().parents[1]
DOCX = ROOT / "docs" / "MEIJENDEL_BRONREGISTER.docx"

ENVIRONMENT = (
    "Aanvullende verklarende gegevens. De bronvaste beheer-jaarview bevat nu 355 "
    "uitvoering-kavel-jaarrelaties voor 68 uitvoeringen, 52 kavels en 282 unieke "
    "kavel-jaren uit 1966–2025. Daarvan overlappen 293 relaties in 43 kavels met "
    "territoriumgegevens. doorsnijding_pct is in alle 355 relaties leeg: een "
    "kavelkoppeling bewijst niet de behandelde oppervlakte; ontbreken van een "
    "registratie bewijst evenmin dat geen beheer plaatsvond. De OSM-infrastructuurstand "
    "van 8 november 2026 bevat 1.319 lijnversies en 16 parkeerplaatsversies die "
    "minstens één van de 55 kavels raken. Daaruit "
    "zijn met de voorlopig geschatte ingangsdatum 1 januari 1955 automatisch 165 "
    "kavelwaarden afgeleid: drie variabelen voor elk van 55 kavels. "
    "Toegankelijkheid wordt sinds "
    "7 november 2026 niet meer als kavelkenmerk opgeslagen, maar ruimtelijk afgeleid "
    "uit versies van omsloten gebieden. Zes actuele gebiedsversies leveren samen "
    "46 positieve doorsnijdingen met kavels. Gebruik de afgeleide oppervlakteaandelen als ruimtelijke context, "
    "niet als historische drukreeks. Binnen de 52 vogelkavels zijn 13.902 "
    "BMP-bezoeken uit 1984–2025 beschikbaar voor controle van telinspanning. De "
    "kenmerkenlaag bevat 3.607 goedgekeurde voorkeurswaarden voor 159 vogelsoorten; "
    "3.555 waarden betreffen 156 positief geregistreerde soorten binnen de "
    "standaardselectie. Kenmerkwaarden zijn soortmetadata, geen nieuwe waarnemingen "
    "door de tijd."
)

GARMIN = (
    "Garmin-QField-veldbron opgenomen en gecorrigeerd op 7 november 2026. De lokale QField-werkset "
    "bevat één door Ton Lansink gelopen Garmin Connect-activiteit uit 7 november "
    "2026: 5.624 GPS-punten in één spoor, 12.328 meter lijngeometrie en één daarvan "
    "afgeleide gebiedspolygoon. Ton bevestigde de volledige route als openbaar "
    "voetpad en het daadwerkelijk omsloten gebied als formeel afgesloten. De route "
    "staat als één object in paden_en_wegen. Het heen-en-weer gelopen toegangsspoor "
    "naar de feitelijke gebiedsgrens is geen grens en is bij de correctie van 7 november "
    "2026 uitgesloten. De gesloten lus gebruikt routepunten 160 tot en met 5470; de "
    "resterende sluitafstand bedraagt 4,815 meter. Alleen het grootste geldige vlak is "
    "overgenomen; kleine kruisingsvlakken door lokale GPS-overlap zijn uitgesloten. "
    "De ruwe GPX blijft bij het overdraagbare QField-pakket. Garmin rapporteert in "
    "deze export geen horizontale nauwkeurigheid; dat veld blijft daarom leeg. De "
    "afgesloten polygoon is als één gebiedsversie in Meijendel opgenomen; de "
    "berekende oppervlakte in Rijksdriehoeksstelsel is 4.483.613,185 m². Vier interne "
    "artefactringen zijn verwijderd; de bronhash is "
    "789f8ee1c6eb7ca27667000b775de8f9ef7bb4aabb0d29b98f85d820b06b490c. Dit is een "
    "lokaal gelokaliseerde veldbron voor toegankelijkheidsinventarisatie, geen "
    "ecologische soortwaarneming en geen bron voor Meijendel_bronnen. De gegevens "
    "vallen onder beheer van Ton Lansink; extern hergebruik is niet beoordeeld."
)

SECTION_TITLE = "Toegankelijkheid als gebiedsversies op 7 november 2026"
SECTION = [
    "De voorlopige toegankelijkheid per kavel is volledig vervangen. De 55 "
    "registraties uit 2024 zijn verwijderd uit maatregel_toegankelijkheid_registratie; "
    "ook de 55 bijbehorende doelen in maatregel_registratie_herkomst, de kolom "
    "toegang_registratie_id en de tabel zelf zijn verwijderd. De oude CSV's en "
    "migratiebestanden blijven uitsluitend als historische audit- en herstelbron "
    "herkenbaar. Zij vormen geen actieve invoerroute meer. Bron 101 blijft bestaan "
    "omdat daaraan daarnaast 139 beheerregistraties uit 1991–1999 zijn gekoppeld.",
    "De levende lokale database bevat nu drie toegestane gebiedsstatussen: afgesloten, "
    "toegankelijk en toegankelijk_met_toegangskaart. De tabellen "
    "toegankelijkheidsgebied en toegankelijkheidsgebied_versie bewaren respectievelijk "
    "de identiteit van een vlak en zijn opeenvolgende geometrische en inhoudelijke "
    "versies. Voor iedere bestaande en later ingevoerde versie geldt standaard "
    "geldig_vanaf = 1955-01-01; deze datum berust op Tons inschatting. geldig_tot = "
    "NULL betekent dat de versie actueel blijft totdat een einddatum wordt ingevoerd. "
    "De view v_toegankelijkheidsgebied_actueel selecteert alleen versies die op de "
    "huidige datum geldig zijn.",
    "De levende database bevat zes actuele gebieden: twee afgesloten en vier toegankelijk. Het "
    "gecorrigeerde Garmin-vlak heeft bronhash 789f8ee1c6eb7ca27667000b775de8f9ef7bb4aabb0d29b98f85d820b06b490c "
    "en een oppervlakte van 4.483.613,185 m². Het tweede vlak is de geometrische "
    "vereniging van de volledige kavels M13, M13s, M14, M15, M16, M16s en M17a. Dit vlak heeft "
    "bronhash bfbfe2ea2931b2ec085aec5c5d261387f0637ab8d59295457b175382e0ddd69c en een "
    "oppervlakte van 2.504.846,307 m². Twintig interne artefactringen zijn verwijderd. "
    "Daarnaast zijn uitsluitend topologische naden van minder dan 4 meter gesloten "
    "waar een aanvulling ten minste twee kavels binnen ditzelfde statusgebied verbindt. "
    "Daarmee is 52,356 m² toegevoegd; de overige buitencontour is niet gebufferd. M66 en M105 zijn als twee afzonderlijke "
    "toegankelijke gebieden opgenomen, exact volgens hun kavelgrenzen; hun oppervlakten "
    "zijn respectievelijk 576.909,232 en 155.796,244 m². Ook M77, M78/79, M75a en M31 "
    "zijn opgenomen. M77, M78/79 en M75a vormen één toegankelijk gebied volgens hun "
    "gezamenlijke buitencontour; veertien interne artefactringen zijn verwijderd. Dit "
    "vlak heeft bronhash 80405f7198be8a2e46e405e8aa0fa8ccbd94356766ebf26eda0061fdd7993746 "
    "en een oppervlakte van 899.464,823 m². M31 blijft een afzonderlijk toegankelijk "
    "gebied van 391.788,486 m². De drie vervangen losse gebiedsrecords zijn verwijderd. "
    "toegankelijkheidsgebied_plot_afleiding bevat 46 actuele positieve doorsnijdingen; "
    "voor de dertien bevestigde kavels is het aandeel 100%. De Garmin-veldregistratie en de handmatig bevestigde plotselectie hebben "
    "ieder een eigen bronregel; maatregel_bron bevat na deze invoer 57 regels. Dit zijn "
    "afgeleide relaties: een vlak kan door een kavel lopen "
    "en een kavel kan verschillende statusvlakken bevatten. De status van een "
    "volledige kavel wordt daarom niet meer als bronfeit opgeslagen.",
    "Shiny en de statische browser gebruiken parser/cacheversie 17 en leiden per kavel "
    "en jaar oppervlakteaandelen af voor afgesloten, toegankelijk, toegankelijk met "
    "toegangskaart en niet door een gebied gedekt. Alleen wanneer één status 100% van "
    "de kavel bedekt, krijgt de gehele kavel die enkele status; anders blijft de "
    "uitkomst gemengd of onbekend. De geldigheid wordt bepaald door de overlap tussen "
    "analysejaar en geldig_vanaf/geldig_tot. De zware SQL-export, proefimport, volledige "
    "cachebouw en VPS-publicatie zijn nog niet uitgevoerd.",
    "De herstelkopie van vóór deze geometriecorrectie staat op /Volumes/T7 Data/"
    "Home_Ton/Meijendel data/Backups-archief/Meijendel/"
    "meijendel-toegankelijkheid-voor-migratie-20261107-233643.sql. Omvang: 348.474 "
    "bytes. SHA-256: 45478a3f51e90a198984be0d02d839332d8bd402257694addc4d0c4f463c0b8d. "
    "De bijbehorende metadata legt de vier betrokken tabellen, de zes actuele "
    "bronhashes en 139 behouden beheerregistraties vast. Herstel is een afzonderlijk "
    "besluit.",
]

OSM_SECTION_TITLE = "OpenStreetMap lijninfrastructuur en parkeerplaatsen op 8 november 2026"
OSM_SECTION = [
    "De levende lokale database bevat een volledige gedateerde OpenStreetMap-snapshot van "
    "de voetpaden, fietspaden en wegen in de ruime Meijendel-bounding box. Het bronmoment is "
    "8 november 2026 10:22:35 UTC. Van 4.475 way-objecten voldoen 4.473 aan de selectie. Na "
    "afsnijding op het actuele Meijendel-basisgebied en selectie op een positieve "
    "doorsnijding met minstens één van de 55 kavels blijven 1.319 lijnsegmenten en "
    "235.264,661 meter over. Daarvan zijn 59 fietspadsegmenten (20.545,201 meter), 872 "
    "voetpadsegmenten (134.378,593 meter) en 388 wegsegmenten (80.340,867 meter). De "
    "OSM-toegangstags leiden tot 680 openbare, 272 beperkt toegankelijke en 367 afgesloten "
    "segmenten. Deze status is bronafgeleid en vormt geen zelfstandige juridische vaststelling.",
    "Alle 1.319 lijnversies hebben voorlopig geldig_vanaf = 1955-01-01, "
    "geldig_vanaf_grondslag = inschatting en geldig_tot = NULL. Ton heeft uitdrukkelijk "
    "bepaald dat deze historisch onjuiste begindatum voorlopig ook voor voetpaden, fietspaden "
    "en wegen wordt gebruikt. Een tweede OSM-snapshot bevat 341 parkeerobjecten met bronmoment "
    "8 november 2026 10:31:51 UTC. Daarvan raken 16 objecten minstens één kavel; ook deze "
    "versies beginnen voorlopig op 1 januari 1955 en hebben "
    "geen einddatum. Het werkelijke OSM-bronmoment blijft voor beide snapshots apart bewaard.",
    "Een volgende snapshot maakt nieuwe versies, sluit de voorafgaande stand op het nieuwe "
    "bronmoment en herberekent automatisch de plotdoorsnijdingen en kavelaggregaten. Oudere "
    "versies worden niet overschreven. De actuele en historische views bestaan afzonderlijk "
    "voor segmenten en parkeerplaatsen. De voorlopige invoer uit 2024 is volledig ingetrokken: "
    "de 220 regels in plot_jaar_infra, de CSV, de oude losse parkeerexport en de bijbehorende "
    "SQL-invoerroute zijn verwijderd. Vanaf de voorlopig geschatte ingangsdatum 1 januari "
    "1955 bevat plot_jaar_infra 165 automatisch afgeleide regels: afstand_pad_m, "
    "padlengte_m_per_ha en afstand_parkeerplaats_m voor elk van 55 kavels. Shiny en de "
    "statische browser gebruiken per analysejaar uitsluitend de laatste aggregaatversie op "
    "of vóór dat jaar; een toekomstige stand werkt niet achterwaarts door.",
    "De vorige lokale OSM-lijnlaag bevat binnen dezelfde kavelselectie 1.320 segmenten en "
    "232.769,401 meter. De nieuwe snapshot bevat 1.319 segmenten en 235.264,669 meter: 1.294 "
    "OSM-way-ID’s komen in beide voor, 25 alleen in de nieuwe snapshot en 26 alleen in de "
    "vorige laag. Bij 94 gemeenschappelijke ID’s is de geometrie gewijzigd, bij 79 de "
    "toegangsclassificatie en bij vier het infrastructuurtype. Het verschil van 2.495,268 "
    "meter bewijst geen fysieke aanleg. Voor de 59 fietspaden ondersteunt de BGT-controle "
    "17.134,499 meter (83,399%) binnen tien meter van een officieel fietspadvlak; 55 segmenten "
    "hebben zulke dekking en vier niet. BGT heeft OSM-geometrie niet automatisch vervangen. "
    "Op 8 november 2026 zijn 913 lijnversies zonder positieve kaveldoorsnijding en 253 "
    "parkeerplaatsversies zonder kavelrelatie verwijderd: 476 wegen, 75 fietspaden, 362 "
    "voetpaden en 253 parkeerplaatsen. Objecten die één of meer kavels raken zijn volledig "
    "behouden en niet op de kavelgrens afgeknipt. De import past deze selectie voortaan bij "
    "iedere herhaling en nieuwe snapshot toe. Beide identiteitstabellen bevatten geen object "
    "zonder versie.",
    "De lijnsnapshot heeft SHA-256 74fba544c4625911aa4fd82e08c8f231b7488fc06258580e9649ea51c3aed320; "
    "de parkeerplaatssnapshot 7deab5d058926c70e08da38ee096c6b971a41072c5b71853c4460adf87cb6e5e. "
    "OpenStreetMap-data valt onder ODbL 1.0 en vereist bronvermelding. Google Maps is niet als "
    "gegevensbron gebruikt. De laatste herstelkopie staat op /Volumes/T7 Data/Home_Ton/"
    "Meijendel data/Backups-archief/Meijendel/meijendel-voor-osm-fietspaden-20261108-124148.sql. "
    "Omvang: 3.576.079 bytes. SHA-256: "
    "5de990ad6efe41ae6b049ccac003e2ee24f96524423304ff83217e94d2fb0710.",
    "De zware meijendel.sql-export, proefimport, volledige Shiny-cachebouw en VPS-publicatie "
    "zijn niet uitgevoerd.",
]


def replace_paragraph(document: Document, prefix: str, text: str) -> None:
    matches = [p for p in document.paragraphs if p.text.startswith(prefix)]
    if len(matches) != 1:
        raise RuntimeError(f"Verwacht één alinea met prefix {prefix!r}, gevonden {len(matches)}")
    paragraph = matches[0]
    for run in paragraph.runs:
        run._element.getparent().remove(run._element)
    paragraph.add_run(text)


def replace_paragraph_any(document: Document, prefixes: tuple[str, ...], text: str) -> None:
    matches = [p for p in document.paragraphs if any(p.text.startswith(prefix) for prefix in prefixes)]
    if len(matches) != 1:
        raise RuntimeError(f"Verwacht één alinea met prefix uit {prefixes!r}, gevonden {len(matches)}")
    paragraph = matches[0]
    for run in paragraph.runs:
        run._element.getparent().remove(run._element)
    paragraph.add_run(text)


def insert_before(anchor: Paragraph, text: str, style: str) -> Paragraph:
    element = OxmlElement("w:p")
    anchor._p.addprevious(element)
    paragraph = Paragraph(element, anchor._parent)
    paragraph.style = style
    paragraph.add_run(text)
    return paragraph


def rename_once(document: Document, old: str, new: str) -> None:
    if any(p.text == new for p in document.paragraphs):
        return
    replace_paragraph(document, old, new)


def replace_section(document: Document, title: str, paragraphs: list[str]) -> None:
    all_paragraphs = document.paragraphs
    starts = [i for i, paragraph in enumerate(all_paragraphs) if paragraph.text == title]
    if len(starts) != 1:
        raise RuntimeError(f"Sectie {title!r} niet uniek: {len(starts)}")
    start = starts[0]
    end = next(
        (i for i in range(start + 1, len(all_paragraphs))
         if all_paragraphs[i].style.name.startswith("Heading")),
        None,
    )
    if end is None:
        raise RuntimeError(f"Volgende kop na {title!r} ontbreekt")
    anchor = all_paragraphs[end]
    for paragraph in all_paragraphs[start + 1:end]:
        paragraph._element.getparent().remove(paragraph._element)
    for index, text in enumerate(paragraphs):
        insert_before(anchor, text, "First Paragraph" if index == 0 else "Body Text")


def main() -> None:
    document = Document(DOCX)
    replace_paragraph(document, "Stand:", "Stand: 8 november 2026.")
    replace_paragraph(document, "Aanvullende verklarende gegevens.", ENVIRONMENT)
    replace_paragraph(document, "Garmin-QField-veldbron", GARMIN)
    replace_paragraph_any(document, ("De eerste invoer bestaat", "De levende database bevat twee afgesloten gebieden", "De levende database bevat vier actuele gebieden", "De levende database bevat acht actuele gebieden", "De levende database bevat zes actuele gebieden"), SECTION[2])
    replace_paragraph_any(
        document,
        (
            "Shiny en de statische browser gebruiken parser/cacheversie 16",
            "Shiny en de statische browser gebruiken parser/cacheversie 17",
        ),
        SECTION[3],
    )
    replace_paragraph_any(document, ("De volledige herstelkopie van vóór de omzetting", "De herstelkopie van vóór deze geometriecorrectie"), SECTION[4])
    rename_once(
        document,
        "Integratie begrazing en toegankelijkheid op 16 oktober 2026",
        "Historische integratie begrazing en toegankelijkheid op 16 oktober 2026",
    )
    rename_once(
        document,
        "Rechtstreekse aansluiting zonder compatibiliteitsviews",
        "Historische rechtstreekse aansluiting zonder compatibiliteitsviews",
    )
    rename_once(
        document,
        "OpenStreetMap fietspaden als lijnversies op 8 november 2026",
        OSM_SECTION_TITLE,
    )
    if not any(p.text == SECTION_TITLE for p in document.paragraphs):
        anchors = [p for p in document.paragraphs if p.text == "Archivering van herstelkopieën op 23 oktober 2026"]
        if len(anchors) != 1:
            raise RuntimeError("Anker voor actuele toegankelijkheidssectie niet uniek")
        anchor = anchors[0]
        insert_before(anchor, SECTION_TITLE, "Heading 2")
        for index, text in enumerate(SECTION):
            insert_before(anchor, text, "First Paragraph" if index == 0 else "Body Text")
    if not any(p.text == OSM_SECTION_TITLE for p in document.paragraphs):
        anchors = [p for p in document.paragraphs if p.text == "Historische rechtstreekse aansluiting zonder compatibiliteitsviews"]
        if len(anchors) != 1:
            raise RuntimeError("Anker voor OSM-fietspadsectie niet uniek")
        anchor = anchors[0]
        insert_before(anchor, OSM_SECTION_TITLE, "Heading 2")
        for index, text in enumerate(OSM_SECTION):
            insert_before(anchor, text, "First Paragraph" if index == 0 else "Body Text")
    replace_section(document, OSM_SECTION_TITLE, OSM_SECTION)
    document.save(DOCX)

    check = Document(DOCX)
    if sum(p.text == SECTION_TITLE for p in check.paragraphs) != 1:
        raise RuntimeError("Nieuwe sectie niet exact eenmaal opgeslagen")
    if not any("parser/cacheversie 17" in p.text for p in check.paragraphs):
        raise RuntimeError("Parserversie 17 ontbreekt in DOCX")
    if sum(p.text == OSM_SECTION_TITLE for p in check.paragraphs) != 1:
        raise RuntimeError("OSM-fietspadsectie niet exact eenmaal opgeslagen")
    print(f"Bijgewerkt: {DOCX}")


if __name__ == "__main__":
    main()
