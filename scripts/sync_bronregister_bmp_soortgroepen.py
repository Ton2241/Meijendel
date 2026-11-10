#!/usr/bin/env python3
"""Neem de BMP-soortgroepverplaatsing uit het leidende bronregister over in Word."""

from pathlib import Path

from docx import Document
from docx.oxml import OxmlElement
from docx.text.paragraph import Paragraph


ROOT = Path(__file__).resolve().parents[1]
MARKDOWN = ROOT / "docs" / "MEIJENDEL_BRONREGISTER.md"
DOCX = ROOT / "docs" / "MEIJENDEL_BRONREGISTER.docx"


def md_line(prefix: str) -> str:
    matches = [line for line in MARKDOWN.read_text(encoding="utf-8").splitlines()
               if line.startswith(prefix)]
    if len(matches) != 1:
        raise RuntimeError(f"Markdown-anker ontbreekt of is dubbel: {prefix}")
    return matches[0].replace("**", "").replace("`", "").removeprefix("### ")


def paragraph(document, prefix: str):
    matches = [item for item in document.paragraphs if item.text.startswith(prefix)]
    if len(matches) != 1:
        raise RuntimeError(f"Word-anker ontbreekt of is dubbel: {prefix}")
    return matches[0]


def main() -> None:
    document = Document(DOCX)
    if paragraph(document, "Stand: ").text != "Stand: 8 november 2026.":
        raise RuntimeError("Onverwachte standdatum van het bronregister")
    replacements = (
        ("1.3. Zoogdieren tijdens SOVON- en VWG-bezoeken", "### 1.3. Niet-vogels"),
        ("Omvang en periode. De SOVON-levering bevat 19.877", "**Omvang en periode.** De afgeronde reeks"),
        ("Gebruik. Voor de tijdens deze bezoeken gevolgde zoogdieren", "**Gebruik.** De vijf soortgroeptabellen"),
        ("Status. Analyseklaar binnen deze afbakening", "**Status.** Lokaal analyseklaar"),
        ("De 7.552 eerder uit ndff-daz-bmp-v1", "De 7.552 eerder uit `ndff-daz-bmp-v1`"),
        ("Aanvullende bezoektotalen 2005–2022, 3 oktober 2026.",
         "**Historische tussenstand, 3 oktober 2026.**"),
    )
    for old, new in replacements:
        target = md_line(new)
        matches = [item for item in document.paragraphs
                   if item.text.startswith(old) or item.text.startswith(target[:35])]
        if len(matches) != 1:
            raise RuntimeError(f"Word-anker ontbreekt of is dubbel: {old}")
        matches[0].text = target
    anchor = paragraph(document, "Opslagbeoordeling van 8 november 2026.")
    current = [item for item in document.paragraphs
               if item.text.startswith("BMP-verplaatsing van 8 november 2026.")]
    if len(current) > 1:
        raise RuntimeError("BMP-verplaatsing staat dubbel in Word")
    if current:
        item = current[0]
    else:
        element = OxmlElement("w:p")
        anchor._p.addnext(element)
        item = Paragraph(element, anchor._parent)
        item.style = document.styles["Normal"]
    item.text = md_line("**BMP-verplaatsing van 8 november 2026.**")
    document.save(DOCX)
    check = Document(DOCX)
    for _, new in replacements:
        if sum(item.text == md_line(new) for item in check.paragraphs) != 1:
            raise RuntimeError(f"Word wijkt van Markdown af: {new}")
    if sum(item.text == md_line("**BMP-verplaatsing van 8 november 2026.**")
           for item in check.paragraphs) != 1:
        raise RuntimeError("BMP-paragraaf wijkt van Markdown af")
    print(f"Gesynchroniseerd: {DOCX}")


if __name__ == "__main__":
    main()
