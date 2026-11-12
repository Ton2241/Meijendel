#!/usr/bin/env python3
"""Synchroniseer de kervenkernvlakken naar de Word-tabelinventaris."""

from pathlib import Path

from docx import Document
from docx.oxml import OxmlElement
from docx.text.paragraph import Paragraph


ROOT = Path(__file__).resolve().parents[1]
DOCX = ROOT / "docs/database/MEIJENDEL_TABELINVENTARIS.docx"

CURRENT = (
    "Actualisering 12 november 2026. De levende lokale database bevat 22 projecten, 74 "
    "bronnen, 97 uitvoeringen, 135 expliciete jaarbeoordelingen, 149 uitvoering–bronrelaties "
    "en 286 uitvoering–kavelrelaties. v_plot_jaar_maatregel_bronvast bevat 366 regels. De vijf "
    "handmatig op de PDOK-luchtfoto 2025 gepositioneerde kervenkernen MEY1–MEY5 zijn als "
    "afzonderlijke TG03_uitvoeringsgebied-polygonen geregistreerd. Ieder gereconstrueerd "
    "kernvlak is 30 × 30 meter en 900 m²; samen 4.500 m². Zij lokaliseren de kerfkernen, maar "
    "verdelen of vervangen niet het gepubliceerde gezamenlijke afgegraven oppervlak van "
    "109.434 m². De bestaande uitvoeringsjaren 2014–2015 en kavelrelaties M15, M16 en M17a "
    "zijn ongewijzigd. Herhaalbare invoer: Ruimtelijke data/"
    "19_registreer_kerven_kernvlakken_20261112.sql; contracttest: "
    "gis/scripts/test_kerven_kernvlakken_20261112.py."
)


def set_text(paragraph: Paragraph, text: str) -> None:
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
    old = next(
        p for p in document.paragraphs
        if p.text.startswith("Actualisering 11 november 2026.")
    )
    old_prefix = (
        "Actualisering 11 november 2026. De levende lokale database bevat 22 projecten, 73 "
        "bronnen, 97 uitvoeringen, 135 expliciete jaarbeoordelingen, 148 uitvoering–bronrelaties "
        "en 286 uitvoering–kavelrelaties. v_plot_jaar_maatregel_bronvast bevat 366 regels. "
    )
    if old.text.startswith(old_prefix):
        set_text(old, "Actualisering 11 november 2026. " + old.text[len(old_prefix):])
    if not any(p.text == CURRENT for p in document.paragraphs):
        insert_before(old, CURRENT)

    rows = {
        row.cells[0].text.strip(): row
        for table in document.tables
        for row in table.rows
        if row.cells
    }
    updates = {
        "maatregel_bron": (
            "74",
            "Bronrecords met type, datum, status en raadpleegdatum. De nieuwe handmatige bron "
            "beschrijft de reconstructie van MEY1–MEY5 op de PDOK-luchtfoto 2025.",
        ),
        "maatregel_uitvoering_bron": (
            "149",
            "Relaties tussen uitvoering en bewijsbron, met bronrol en bewijsnotitie. "
            "Tegenstrijdige bronwaarden blijven als zodanig herkenbaar.",
        ),
        "maatregel_geometrie": (
            "12",
            "Bronvaste of benaderde uitvoeringsgeometrieën in RD New, met expliciete "
            "geometrieklasse, objectcode en herkomst. Vijf regels zijn de gereconstrueerde "
            "kervenkernen MEY1–MEY5.",
        ),
    }
    for key, (count, meaning) in updates.items():
        row = rows[key]
        row.cells[1].text = count
        row.cells[2].text = meaning

    document.save(DOCX)
    check = Document(DOCX)
    if sum(p.text == CURRENT for p in check.paragraphs) != 1:
        raise RuntimeError("Actuele inventarisstand niet exact eenmaal teruggelezen")
    print(f"Bijgewerkt: {DOCX}")


if __name__ == "__main__":
    main()
