#!/usr/bin/env python3
"""Synchroniseer het actuele toegankelijkheidsgebiedsmodel naar het bronregister-DOCX."""

from pathlib import Path
import re

from docx import Document
from docx.oxml import OxmlElement
from docx.text.paragraph import Paragraph


ROOT = Path(__file__).resolve().parents[1]
DOCX = ROOT / "docs" / "MEIJENDEL_BRONREGISTER.docx"
MARKDOWN = ROOT / "docs" / "MEIJENDEL_BRONREGISTER.md"

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
    "uit versies van omsloten gebieden. Twaalf actuele gebiedsversies leveren samen "
    "91 positieve doorsnijdingen met kavels. Gebruik de afgeleide oppervlakteaandelen als ruimtelijke context, "
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

SECTION_TITLE = "Toegankelijkheid als gebiedsversies, bijgewerkt 10 november 2026"
OSM_SECTION_TITLE = "OpenStreetMap lijninfrastructuur en parkeerplaatsen op 8 november 2026"


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


def markdown_section(title: str) -> list[str]:
    """Lees één H2-sectie uit de leidende Markdown-versie als gewone alinea's."""
    lines = MARKDOWN.read_text(encoding="utf-8").splitlines()
    heading = f"## {title}"
    starts = [index for index, line in enumerate(lines) if line == heading]
    if len(starts) != 1:
        raise RuntimeError(f"Markdown-sectie {title!r} niet uniek: {len(starts)}")
    start = starts[0] + 1
    end = next(
        (index for index in range(start, len(lines)) if lines[index].startswith("## ")),
        len(lines),
    )
    blocks = re.split(r"\n\s*\n", "\n".join(lines[start:end]).strip())
    return [re.sub(r"`([^`]*)`", r"\1", " ".join(block.splitlines())) for block in blocks]


def main() -> None:
    document = Document(DOCX)
    section = markdown_section(SECTION_TITLE)
    osm_section = markdown_section(OSM_SECTION_TITLE)
    rename_once(document, "Toegankelijkheid als gebiedsversies, bijgewerkt 9 november 2026", SECTION_TITLE)
    replace_paragraph(document, "Stand:", "Stand: 10 november 2026.")
    replace_paragraph(document, "Aanvullende verklarende gegevens.", ENVIRONMENT)
    replace_paragraph(document, "Garmin-QField-veldbron", GARMIN)
    replace_paragraph_any(
        document,
        ("De levende lokale database bevat nu drie toegestane gebiedsstatussen", "De levende lokale database bevat nu vier toegestane gebiedsstatussen"),
        section[1],
    )
    replace_paragraph_any(document, ("De eerste invoer bestaat", "De levende database bevat twee afgesloten gebieden", "De levende database bevat vier actuele gebieden", "De levende database bevat acht actuele gebieden", "De levende database bevat zes actuele gebieden", "De levende database bevat negen actuele gebieden", "De levende database bevat tien actuele gebieden", "De levende database bevat elf actuele gebieden", "De levende database bevat twaalf actuele gebieden"), section[2])
    replace_paragraph_any(
        document,
        (
            "Shiny en de statische browser gebruiken parser/cacheversie 16",
            "Shiny en de statische browser gebruiken parser/cacheversie 17",
            "Shiny en de statische browser gebruiken voor de volgende integrale cachebouw parser/cacheversie 18",
        ),
        section[4],
    )
    replace_paragraph_any(document, ("De volledige herstelkopie van vóór de omzetting", "De herstelkopie van vóór deze geometriecorrectie", "De herstelkopie direct vóór de toevoeging van 9 november", "De herstelkopie direct vóór de toevoeging van het dagkaartvlak", "De herstelkopie direct vóór deze correctie", "De herstelkopie direct vóór de definitieve correctie", "De herstelkopie direct vóór deze vervanging", "De primaire herstelkopie direct vóór de invoer van het M4-5-vlak"), section[5])
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
        for index, text in enumerate(section):
            insert_before(anchor, text, "First Paragraph" if index == 0 else "Body Text")
    replace_section(document, SECTION_TITLE, section)
    if not any(p.text == OSM_SECTION_TITLE for p in document.paragraphs):
        anchors = [p for p in document.paragraphs if p.text == "Historische rechtstreekse aansluiting zonder compatibiliteitsviews"]
        if len(anchors) != 1:
            raise RuntimeError("Anker voor OSM-fietspadsectie niet uniek")
        anchor = anchors[0]
        insert_before(anchor, OSM_SECTION_TITLE, "Heading 2")
        for index, text in enumerate(osm_section):
            insert_before(anchor, text, "First Paragraph" if index == 0 else "Body Text")
    replace_section(document, OSM_SECTION_TITLE, osm_section)
    document.save(DOCX)

    check = Document(DOCX)
    if sum(p.text == SECTION_TITLE for p in check.paragraphs) != 1:
        raise RuntimeError("Nieuwe sectie niet exact eenmaal opgeslagen")
    if not any("parser/cacheversie 18" in p.text for p in check.paragraphs):
        raise RuntimeError("Parserversie 18 ontbreekt in DOCX")
    if not any("harstenhoek_afgesloten_1955" in p.text for p in check.paragraphs):
        raise RuntimeError("Harstenhoek-gebied ontbreekt in DOCX")
    if sum(p.text == OSM_SECTION_TITLE for p in check.paragraphs) != 1:
        raise RuntimeError("OSM-fietspadsectie niet exact eenmaal opgeslagen")
    if not any("De GeoJSON bevat 1.325 objecten" in p.text for p in check.paragraphs):
        raise RuntimeError("Publieke VWG_M-levering ontbreekt in DOCX")
    print(f"Bijgewerkt: {DOCX}")


if __name__ == "__main__":
    main()
