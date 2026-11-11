#!/usr/bin/env python3
"""Synchroniseer de aanvullende kervenbron naar het bestaande bronregister-DOCX."""

from pathlib import Path

from docx import Document
from docx.oxml import OxmlElement
from docx.text.paragraph import Paragraph


ROOT = Path(__file__).resolve().parents[1]
DOCX = ROOT / "docs" / "MEIJENDEL_BRONREGISTER.docx"
ANCHOR = "Daarbij zijn vijftien officiële of institutionele internetbronnen geraadpleegd:"
TEXT = (
    "Aanvullende Zotero-broncontrole kerven, 11 november 2026. Het OBN-tussenrapport "
    "Kerven in de Zeereep van Wegman, Arens, De Lange en Van den Berg (2025; Zotero-item "
    "8WBM6HGR) analyseert 58 Nederlandse kerven, waaronder de vijf in 2015 aangelegde "
    "Meijendelse kerven MEY1–MEY5. Het rapport gebruikt vlakdekkende hoogtegegevens, "
    "luchtfoto's, satellietbeelden, de suppletiedatabase en de momentane kustlijn van 2023. "
    "Voor Meijendel vermeldt het per kerf geometrische kenmerken en beschrijft het verschillen "
    "in functioneren: MEY5 functioneert van de vijf het best en MEY1 het minst; de auteurs "
    "schrijven dit niet toe aan onderlinge zandafvang, maar waarschijnlijk aan de van noord "
    "naar zuid afnemende ontwikkeling van embryonale duinen. MEY1 en MEY2 behoren in de "
    "landelijke vergelijking tot de kerven met de grootste gemiddelde jaarlijkse "
    "hoogteverandering van het actieve kerfgebied: respectievelijk 15 en 14 cm, met 2,5 en "
    "2,3 maal de netto aanzanding van het referentievlak. Tegelijk zijn voor Meijendel geen "
    "eenduidige suppletietrends aangetoond en behandelt dit tussenrapport nog niet de "
    "ecologische effecten. De bron is statistisch en geomorfologisch bruikbaar als aanvullende "
    "kerfmonitoring, maar is op 11 november 2026 nog niet als afzonderlijke bron of uitvoering "
    "in de levende database opgenomen. De Zotero-metadata bevatten een niet bij dit rapport "
    "passende DOI; de bronidentificatie berust daarom op titel, auteurs, rapportnummer "
    "OBN-2023-141-EA, uitgever OBN Natuurkennis en de gekoppelde PDF."
)


def main() -> None:
    doc = Document(DOCX)
    if any(p.text.startswith("Aanvullende Zotero-broncontrole kerven, 11 november 2026.")
           for p in doc.paragraphs):
        raise RuntimeError("Kervenbron staat al in het DOCX; niets overschreven")
    anchor = next((p for p in doc.paragraphs if p.text.startswith(ANCHOR)), None)
    if anchor is None:
        raise RuntimeError("Anker voor de broncontrole niet gevonden")
    element = OxmlElement("w:p")
    anchor._p.addprevious(element)
    paragraph = Paragraph(element, anchor._parent)
    paragraph.style = doc.styles["Normal"]
    run = paragraph.add_run(TEXT)
    run.bold = False
    doc.save(DOCX)
    check = Document(DOCX)
    if sum(p.text == TEXT for p in check.paragraphs) != 1:
        raise RuntimeError("DOCX-kervenbron niet exact eenmaal teruggelezen")
    print(f"Bijgewerkt: {DOCX}")


if __name__ == "__main__":
    main()
