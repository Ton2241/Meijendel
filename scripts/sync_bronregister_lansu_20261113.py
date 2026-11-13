#!/usr/bin/env python3
"""Synchroniseer Lansu's kustduinhabitatkaart naar het Word-bronregister."""

from pathlib import Path

from docx import Document
from docx.oxml import OxmlElement
from docx.text.paragraph import Paragraph


ROOT = Path(__file__).resolve().parents[1]
DOCX = ROOT / "docs" / "MEIJENDEL_BRONREGISTER.docx"

PARAGRAPHS = [
    (
        "Landelijke kustduinhabitatkaart 2020: dit is een expliciet product van hoofdstuk 4 "
        "van Eva Lansu's dissertatie Squeezed sands: Human footprints in coastal lands (2025; "
        "Zotero-item F3EP7REZ) en van het artikel Habitat mapping of coastal dunes with deep "
        "learning (2025; Zotero-item BQACM7L2). De openbare Earth Engine-app toont model 1 voor "
        "562 km² Nederlandse kustduinen op 25 cm-resolutie, met zes klassen: kaal zand, "
        "struweel, zoet water, gras, loofbomen en naaldbomen. Het model combineert RGB- en "
        "nabij-infraroodluchtfoto's uit 2020, afstand tot zee, AHN4-maaiveld- en "
        "oppervlaktehoogte en daarvan afgeleide vegetatiehoogte; LGN19 is gebruikt om "
        "niet-natuur en zee uit te sluiten. De beste modelvariant behaalde op de testset 95,0% "
        "totale nauwkeurigheid, gemiddeld 87,7% recall en 80,1% precisie per klasse. "
        "Vergelijking met 499 veldwaarnemingen verspreid over de Nederlandse kustduinen gaf "
        "88% totale nauwkeurigheid, 74% gemiddelde recall en 62% gemiddelde precisie. Dit zijn "
        "landelijke validatiewaarden, geen afzonderlijke validatie voor Meijendel."
    ),
    (
        "De viewer maakt de classificatie zichtbaar en doorzoekbaar, maar toont geen tijdreeks "
        "en biedt voor zover vastgesteld geen gedocumenteerde rasterexport, modelgewichten, "
        "trainingspolygonen of Meijendel-specifieke foutmatrix. De openbare raadpleegbaarheid "
        "bewijst evenmin welke hergebruikslicentie voor het kaartproduct geldt. De kaart is "
        "daarom nu een geïdentificeerde kandidaat-omgevingslaag en een onafhankelijke ruimtelijke "
        "referentie voor 2020, niet al een analysetabel in Meijendel of Meijendel_bronnen. Na "
        "ontvangst van het getrainde classificatiemodel of een herbruikbaar raster wordt voor de "
        "Natura 2000-selectie per vogelplot de oppervlakte van de zes klassen, randlengte, "
        "versnippering en habitatheterogeniteit berekend. Die uitkomsten worden eerst vergeleken "
        "met de PQ-samenstelling, de landbedekkingskaarten van 2001 en 2022 en de reeds "
        "geharmoniseerde luchtfoto-, AHN- en LGN-bronnen. Pas na lokale validatie wordt bepaald "
        "of de laag als ijkpunt kan worden gebruikt en of hetzelfde model verantwoord op andere "
        "beeldjaren kan worden toegepast. De kaart van 2020 alleen kan geen vegetatieverandering "
        "of vertraagde vogelreactie aantonen."
    ),
]


def replace_text(paragraph: Paragraph, text: str) -> None:
    for run in paragraph.runs:
        run._element.getparent().remove(run._element)
    paragraph.add_run(text)


def insert_before(anchor: Paragraph, text: str, bold_prefix: str | None = None) -> None:
    element = OxmlElement("w:p")
    anchor._p.addprevious(element)
    paragraph = Paragraph(element, anchor._parent)
    paragraph.style = anchor.style
    if bold_prefix and text.startswith(bold_prefix):
        paragraph.add_run(bold_prefix).bold = True
        paragraph.add_run(text[len(bold_prefix):])
    else:
        paragraph.add_run(text)


def remove_paragraph(paragraph: Paragraph) -> None:
    parent = paragraph._p.getparent()
    parent.remove(paragraph._p)


def main() -> None:
    document = Document(DOCX)
    stand = next(p for p in document.paragraphs if p.text.startswith("Stand:"))
    replace_text(stand, "Stand: 13 november 2026.")

    anchor = next(
        p for p in document.paragraphs
        if p.text.startswith("Landbedekking in vogelplots:")
    )
    for paragraph in list(document.paragraphs):
        if paragraph.text in PARAGRAPHS:
            remove_paragraph(paragraph)
    for index, text in enumerate(PARAGRAPHS):
        prefix = "Landelijke kustduinhabitatkaart 2020:" if index == 0 else None
        insert_before(anchor, text, prefix)

    document.save(DOCX)

    check = Document(DOCX)
    texts = [p.text for p in check.paragraphs]
    if texts.count("Stand: 13 november 2026.") != 1:
        raise RuntimeError("Standdatum niet exact eenmaal teruggelezen")
    for text in PARAGRAPHS:
        if texts.count(text) != 1:
            raise RuntimeError("Lansu-alinea niet exact eenmaal teruggelezen")
    indices = [texts.index(text) for text in PARAGRAPHS]
    if indices != sorted(indices):
        raise RuntimeError("Lansu-alinea's staan niet in de bedoelde volgorde")
    print(f"Bijgewerkt: {DOCX}")


if __name__ == "__main__":
    main()
