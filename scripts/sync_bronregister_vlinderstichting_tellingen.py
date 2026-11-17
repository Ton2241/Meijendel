#!/usr/bin/env python3
"""Neem de geverifieerde Tove-import uit het leidende Markdown-register over in Word."""

from __future__ import annotations

import html
import re
import shutil
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MARKDOWN = ROOT / "docs/MEIJENDEL_BRONREGISTER.md"
DOCX = ROOT / "docs/MEIJENDEL_BRONREGISTER.docx"
T7_OUTPUT = Path("/Volumes/T7 Data/Home_Ton/Proefomgevingen/"
                 "tove-tellingen-import-2026-11-17/outputs/MEIJENDEL_BRONREGISTER.docx")


def source_paragraph(prefix: str) -> tuple[str, str]:
    matches = [line for line in MARKDOWN.read_text(encoding="utf-8").splitlines()
               if line.startswith(f"**{prefix}**")]
    if len(matches) != 1:
        raise ValueError(f"Markdown-anker ontbreekt of is dubbel: {prefix}")
    match = re.fullmatch(r"\*\*(.*?)\*\*\s*(.*)", matches[0])
    if not match:
        raise ValueError(f"Onverwachte alinea-opmaak: {prefix}")
    body = re.sub(r"\[([^]]+)\]\([^)]+\)", r"\1", match.group(2)).replace("`", "")
    return match.group(1), body


def paragraph(xml: str, prefix: str) -> re.Match[str]:
    matches = [match for match in re.finditer(r"<w:p(?:\s[^>]*)?>.*?</w:p>", xml, re.S)
               if f"<w:t>{html.escape(prefix)}</w:t>" in match.group(0)]
    if len(matches) != 1:
        raise ValueError(f"Word-anker ontbreekt of is dubbel: {prefix}")
    return matches[0]


def set_body(xml: str, prefix: str, body: str) -> str:
    match = paragraph(xml, prefix)
    old = match.group(0)
    if len(re.findall(r'<w:t xml:space="preserve">.*?</w:t>', old, re.S)) != 1:
        raise ValueError(f"Word heeft geen eenduidige tekstbody: {prefix}")
    new = re.sub(r'(<w:t xml:space="preserve">).*?(</w:t>)',
                 lambda m: m.group(1) + " " + html.escape(body, quote=False) + m.group(2),
                 old, count=1, flags=re.S)
    return xml[:match.start()] + new + xml[match.end():]


def add_import_paragraph(xml: str, title: str, body: str) -> str:
    if f"<w:t>{html.escape(title)}</w:t>" in xml:
        return set_body(xml, title, body)
    anchor = paragraph(xml, "Lokale locatie-import, 17 november 2026.")
    new = ('<w:p><w:pPr/><w:r><w:rPr><w:b/></w:rPr><w:t>'
           + html.escape(title, quote=False)
           + '</w:t></w:r><w:r><w:t xml:space="preserve"> '
           + html.escape(body, quote=False)
           + '</w:t></w:r></w:p>')
    return xml[:anchor.end()] + new + xml[anchor.end():]


def main() -> None:
    if not T7_OUTPUT.parent.is_dir() or not T7_OUTPUT.parent.resolve().is_relative_to(
            Path("/Volumes/T7 Data/Home_Ton/Proefomgevingen").resolve()):
        raise ValueError("Geregistreerde T7-uitvoermap ontbreekt")
    location_title, location_body = source_paragraph("Lokale locatie-import, 17 november 2026.")
    import_title, import_body = source_paragraph("Import van Toves jaargegevens, 17 november 2026.")
    link_title, link_body = source_paragraph("Koppeling en resterende toets.")
    with zipfile.ZipFile(DOCX) as source:
        original = source.read("word/document.xml").decode("utf-8")
        changed = set_body(original, location_title, location_body)
        changed = add_import_paragraph(changed, import_title, import_body)
        changed = set_body(changed, link_title, link_body)
        changed = changed.replace('<w:t xml:space="preserve">4. Verwachte aanvullingen</w:t>',
                                  '<w:t xml:space="preserve">4. Ontvangen leveringen en verwachte aanvullingen</w:t>')
        with zipfile.ZipFile(T7_OUTPUT, "w") as output:
            for entry in source.infolist():
                output.writestr(entry, changed.encode("utf-8")
                                if entry.filename == "word/document.xml"
                                else source.read(entry.filename))
    with zipfile.ZipFile(T7_OUTPUT) as check:
        if check.testzip() is not None:
            raise ValueError("Wordarchief is beschadigd")
        document = check.read("word/document.xml").decode("utf-8")
        for title, body in ((location_title, location_body),
                            (import_title, import_body), (link_title, link_body)):
            if document.count(f"<w:t>{html.escape(title)}</w:t>") != 1:
                raise ValueError(f"Word-alinea ontbreekt: {title}")
            if " " + html.escape(body, quote=False) not in paragraph(document, title).group(0):
                raise ValueError(f"Word-alinea wijkt af van Markdown: {title}")
        if '<w:t xml:space="preserve">4. Ontvangen leveringen en verwachte aanvullingen</w:t>' not in document:
            raise ValueError("Titel van sectie 4 wijkt af van Markdown")
    shutil.copy2(T7_OUTPUT, DOCX)
    print(f"Word gesynchroniseerd: {DOCX}")


if __name__ == "__main__":
    main()
