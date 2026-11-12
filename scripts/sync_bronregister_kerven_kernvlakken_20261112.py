#!/usr/bin/env python3
"""Synchroniseer de kervenkernvlakken naar het bestaande bronregister-DOCX."""

from pathlib import Path

from docx import Document
from docx.oxml import OxmlElement
from docx.text.paragraph import Paragraph


ROOT = Path(__file__).resolve().parents[1]
DOCX = ROOT / "docs" / "MEIJENDEL_BRONREGISTER.docx"

NEW_PARAGRAPH = (
    "Gereconstrueerde kervenkernvlakken, 12 november 2026. Ton heeft vijf 30 × 30 meter "
    "grote kernvlakken handmatig gepositioneerd op de witte kerfdelen in de PDOK-luchtfoto "
    "2025. De GeoPackage-bron kerven-kandidaatpolygonen-2025-v4-handmatig-polygon.gpkg heeft "
    "SHA-256 0682038ab1b6bc031ec63a6e0b2a173176f00a91640cce22b63ca9312dd66784. "
    "MEY1–MEY5 zijn als vijf afzonderlijke TG03_uitvoeringsgebied-polygonen met geometriejaar "
    "2015 in maatregel_geometrie opgeslagen. Ieder vlak is 900 m²; samen 4.500 m². Het zijn "
    "gereconstrueerde kerfkernen, geen exacte volledige werkgrenzen. Zij verdelen of vervangen "
    "daarom niet het gepubliceerde gezamenlijke afgegraven oppervlak van 109.434 m². De "
    "uitvoering, de twee jaarregels 2014 en 2015 en de drie geverifieerde kavelrelaties M15, "
    "M16 en M17a zijn ongewijzigd. Herhaalbare invoer: Ruimtelijke data/"
    "19_registreer_kerven_kernvlakken_20261112.sql."
)


def replace_prefix(paragraph: Paragraph, prefix: str, replacement: str) -> None:
    if not paragraph.text.startswith(prefix):
        raise RuntimeError(f"Alinea begint niet met {prefix!r}")
    text = replacement + paragraph.text[len(prefix):]
    for run in paragraph.runs:
        run._element.getparent().remove(run._element)
    paragraph.add_run(text)


def insert_before(anchor: Paragraph, text: str) -> None:
    element = OxmlElement("w:p")
    anchor._p.addprevious(element)
    paragraph = Paragraph(element, anchor._parent)
    paragraph.style = anchor.style
    paragraph.add_run(text)


def main() -> None:
    document = Document(DOCX)

    inventory = next(
        p for p in document.paragraphs
        if p.text.startswith("maatregel_geometrie bevat nog nul exacte uitvoeringsgeometrieën.")
        or p.text.startswith("Bij deze inventarisstand bevatte maatregel_geometrie")
    )
    if inventory.text.startswith("maatregel_geometrie"):
        replace_prefix(
            inventory,
            "maatregel_geometrie bevat nog nul exacte uitvoeringsgeometrieën.",
            "Bij deze inventarisstand bevatte maatregel_geometrie nog nul exacte "
            "uitvoeringsgeometrieën; de vijf gereconstrueerde kervenkernvlakken van "
            "12 november 2026 zijn hieronder als latere aanvulling beschreven.",
        )

    status = next(
        p for p in document.paragraphs
        if p.text.startswith("Status per 11 november 2026.")
        or p.text.startswith("Status per 12 november 2026.")
    )
    if status.text.startswith("Status per 11 november 2026."):
        old = (
            "Status per 11 november 2026. De levende lokale database bevat 73 maatregelbronnen, "
            "97 uitvoeringen, 135 expliciete jaarbeoordelingen (122 uitgevoerd, 10 niet uitgevoerd "
            "en 3 onbekend), 148 uitvoering–bronrelaties en 286 uitvoering–kavelrelaties."
        )
        new = (
            "Status per 12 november 2026. De levende lokale database bevat 74 maatregelbronnen, "
            "97 uitvoeringen, 135 expliciete jaarbeoordelingen (122 uitgevoerd, 10 niet uitgevoerd "
            "en 3 onbekend), 149 uitvoering–bronrelaties, 286 uitvoering–kavelrelaties en 12 "
            "geometrieën. Vijf geometrieën zijn de gereconstrueerde kervenkernen MEY1–MEY5."
        )
        replace_prefix(status, old, new)

    if not any(p.text == NEW_PARAGRAPH for p in document.paragraphs):
        anchor = next(
            p for p in document.paragraphs
            if p.text.startswith("De 286 plotkoppelingen en 122 uitgevoerde jaarregels")
        )
        insert_before(anchor, NEW_PARAGRAPH)

    document.save(DOCX)

    check = Document(DOCX)
    if sum(p.text == NEW_PARAGRAPH for p in check.paragraphs) != 1:
        raise RuntimeError("Nieuwe kervenkernalinea niet exact eenmaal teruggelezen")
    if not any(p.text.startswith("Status per 12 november 2026.") for p in check.paragraphs):
        raise RuntimeError("Nieuwe bronregisterstand niet teruggelezen")
    print(f"Bijgewerkt: {DOCX}")


if __name__ == "__main__":
    main()
