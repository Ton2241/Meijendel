#!/usr/bin/env python3
"""Synchroniseer de Zotero-heranalyse van begrazing naar het bronregister-DOCX."""

from pathlib import Path

from docx import Document
from docx.oxml import OxmlElement
from docx.text.paragraph import Paragraph


ROOT = Path(__file__).resolve().parents[1]
DOCX = ROOT / "docs" / "MEIJENDEL_BRONREGISTER.docx"

PARAGRAPH = (
    "Zotero-heranalyse begrazing, 12 november 2026. De lokale volledige-tekstindex is doorzocht "
    "op begrazingstermen in combinatie met Meijendel en de relevante naamgebieden. De selectie "
    "omvat 135 tekstbijlagen onder 129 bibliografische hoofditems: 57 volledige nummers van "
    "Holland’s Duinen, 19 volledige afleveringen van Meijendel Mededelingen en 59 overige "
    "bijlagen. Alle 135 geselecteerde tekstbijlagen en hun contexttreffers zijn op relevante "
    "begrazingspassages beoordeeld. De effectliteratuur is "
    "toegevoegd aan docs/Begrazing_in_Meijendel.docx. Zij toont lokale structuurverandering in "
    "1990–1995, uiteenlopende vogel- en vlinderreacties, geen zelfstandig aantoonbaar effect op "
    "landschapsdekkingen in de luchtfotoanalyse 1975–2009 en voortgaande progressieve successie "
    "in 41 permanente plots over 1953–2012. Een OBN-stageadvies uit 2026 noemt verstoring van "
    "grazers door honden uitsluitend als mogelijke causale keten; voor Meijendel is die niet "
    "aangetoond. De heranalyse levert geen nieuw bronvast uitvoeringsjaar of nieuwe kavelgrens op. "
    "De lokale database en VPS-publicatiestand zijn daarom niet gewijzigd. De actuele openbare "
    "Dunea-informatie bevestigt Gallowayrunderen, Konikpaarden en Drentse heideschapen in "
    "begrazingsgebieden; het provinciale beheerplan 2026–2032 blijft een planbron, geen bewijs "
    "van jaarlijkse uitvoering."
)


def insert_before(anchor: Paragraph, text: str) -> None:
    element = OxmlElement("w:p")
    anchor._p.addprevious(element)
    paragraph = Paragraph(element, anchor._parent)
    paragraph.style = anchor.style
    paragraph.add_run(text)


def set_text(paragraph: Paragraph, text: str) -> None:
    for run in list(paragraph.runs):
        run._element.getparent().remove(run._element)
    paragraph.add_run(text)


def main() -> None:
    document = Document(DOCX)
    changed = False
    existing = next(
        (
            p
            for p in document.paragraphs
            if p.text.startswith("Zotero-heranalyse begrazing, 12 november 2026.")
        ),
        None,
    )
    if existing is None:
        anchor = next(p for p in document.paragraphs if p.text.startswith("Gebruik en grens."))
        insert_before(anchor, PARAGRAPH)
        changed = True
    elif existing.text != PARAGRAPH:
        set_text(existing, PARAGRAPH)
        changed = True
    if changed:
        document.save(DOCX)

    check = Document(DOCX)
    if sum(p.text == PARAGRAPH for p in check.paragraphs) != 1:
        raise RuntimeError("Begrazingsheranalyse niet exact eenmaal teruggelezen")
    print(f"Bijgewerkt: {DOCX}")


if __name__ == "__main__":
    main()
