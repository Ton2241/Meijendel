#!/usr/bin/env python3
"""Bouw het bronoverzicht over de vijf kerven in Meijendel."""

from pathlib import Path

from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT, WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs" / "Kerven_in_Meijendel.docx"
BLUE = "1F4E79"
LIGHT_BLUE = "D9EAF7"
LIGHT_GREY = "F2F2F2"
TEXT_GREY = RGBColor(89, 89, 89)


def set_cell_shading(cell, fill: str) -> None:
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = tc_pr.find(qn("w:shd"))
    if shd is None:
        shd = OxmlElement("w:shd")
        tc_pr.append(shd)
    shd.set(qn("w:fill"), fill)


def set_cell_margins(cell, top=80, start=100, bottom=80, end=100) -> None:
    tc = cell._tc
    tc_pr = tc.get_or_add_tcPr()
    tc_mar = tc_pr.first_child_found_in("w:tcMar")
    if tc_mar is None:
        tc_mar = OxmlElement("w:tcMar")
        tc_pr.append(tc_mar)
    for margin, value in (("top", top), ("start", start), ("bottom", bottom), ("end", end)):
        node = tc_mar.find(qn(f"w:{margin}"))
        if node is None:
            node = OxmlElement(f"w:{margin}")
            tc_mar.append(node)
        node.set(qn("w:w"), str(value))
        node.set(qn("w:type"), "dxa")


def set_repeat_table_header(row) -> None:
    tr_pr = row._tr.get_or_add_trPr()
    tbl_header = OxmlElement("w:tblHeader")
    tbl_header.set(qn("w:val"), "true")
    tr_pr.append(tbl_header)


def add_table(doc, headers, rows, widths=None):
    table = doc.add_table(rows=1, cols=len(headers))
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.style = "Table Grid"
    header = table.rows[0]
    set_repeat_table_header(header)
    for idx, value in enumerate(headers):
        cell = header.cells[idx]
        set_cell_shading(cell, BLUE)
        set_cell_margins(cell)
        cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
        run = cell.paragraphs[0].add_run(value)
        run.bold = True
        run.font.color.rgb = RGBColor(255, 255, 255)
        run.font.size = Pt(8.5)
        if widths:
            cell.width = widths[idx]
    for row_index, values in enumerate(rows):
        cells = table.add_row().cells
        for idx, value in enumerate(values):
            cell = cells[idx]
            set_cell_margins(cell)
            cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.TOP
            if row_index % 2:
                set_cell_shading(cell, LIGHT_GREY)
            p = cell.paragraphs[0]
            p.paragraph_format.space_after = Pt(0)
            run = p.add_run(str(value))
            run.font.size = Pt(8.5)
            if widths:
                cell.width = widths[idx]
    doc.add_paragraph().paragraph_format.space_after = Pt(0)
    return table


def add_bullet(doc, text: str) -> None:
    p = doc.add_paragraph(style="List Bullet")
    p.paragraph_format.space_after = Pt(3)
    p.add_run(text)


def add_number(doc, text: str) -> None:
    p = doc.add_paragraph(style="List Number")
    p.paragraph_format.space_after = Pt(3)
    p.add_run(text)


def add_source(doc, text: str) -> None:
    p = doc.add_paragraph()
    p.paragraph_format.left_indent = Inches(0.25)
    p.paragraph_format.first_line_indent = Inches(-0.25)
    p.paragraph_format.space_after = Pt(5)
    p.add_run(text)


def add_footer(section) -> None:
    footer = section.footer
    p = footer.paragraphs[0]
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = p.add_run("Kerven in Meijendel · bronoverzicht 12 november 2026 · ")
    run.font.size = Pt(8)
    run.font.color.rgb = TEXT_GREY
    fld_char1 = OxmlElement("w:fldChar")
    fld_char1.set(qn("w:fldCharType"), "begin")
    instr_text = OxmlElement("w:instrText")
    instr_text.set(qn("xml:space"), "preserve")
    instr_text.text = "PAGE"
    fld_char2 = OxmlElement("w:fldChar")
    fld_char2.set(qn("w:fldCharType"), "end")
    run._r.append(fld_char1)
    run._r.append(instr_text)
    run._r.append(fld_char2)


def build() -> None:
    doc = Document()
    section = doc.sections[0]
    section.page_width = Inches(8.5)
    section.page_height = Inches(11)
    section.top_margin = Inches(0.7)
    section.bottom_margin = Inches(0.65)
    section.left_margin = Inches(0.75)
    section.right_margin = Inches(0.75)
    add_footer(section)

    styles = doc.styles
    normal = styles["Normal"]
    normal.font.name = "Aptos"
    normal.font.size = Pt(9.2)
    normal.paragraph_format.space_after = Pt(4)
    normal.paragraph_format.line_spacing = 1.05
    for style_name, size, color in (
        ("Title", 26, RGBColor(0, 0, 0)),
        ("Subtitle", 11, TEXT_GREY),
        ("Heading 1", 16, RGBColor.from_string(BLUE)),
        ("Heading 2", 12, RGBColor.from_string(BLUE)),
        ("Heading 3", 10, RGBColor.from_string(BLUE)),
    ):
        style = styles[style_name]
        style.font.name = "Aptos Display" if style_name != "Normal" else "Aptos"
        style.font.size = Pt(size)
        style.font.color.rgb = color
        style.font.bold = style_name != "Subtitle"
        style.paragraph_format.keep_with_next = True
        style.paragraph_format.space_before = Pt(10 if style_name != "Title" else 0)
        style.paragraph_format.space_after = Pt(5)

    title = doc.add_paragraph(style="Title")
    title.add_run("De vijf kerven in Meijendel")
    subtitle = doc.add_paragraph(style="Subtitle")
    subtitle.add_run("Levende database en lokale Zotero-bibliotheek · stand 12 november 2026")

    box = doc.add_table(rows=1, cols=1)
    box.alignment = WD_TABLE_ALIGNMENT.CENTER
    cell = box.cell(0, 0)
    set_cell_shading(cell, LIGHT_BLUE)
    set_cell_margins(cell, top=140, start=160, bottom=140, end=160)
    p = cell.paragraphs[0]
    p.paragraph_format.space_after = Pt(0)
    r = p.add_run(
        "Kern. De vijf kerven zijn in de winters 2013/2014 en 2014/2015 aangelegd en in 2015 "
        "voltooid. Over 750 meter zeereep is op vijf plekken vegetatie verwijderd, samen met "
        "10–20 cm bodem; 109.434 m² is feitelijk afgegraven. De levende database koppelt de aanleg "
        "aan M15, M16 en M17a en bewaart MEY1–MEY5 als vijf gereconstrueerde kernvlakken van "
        "ieder 30 × 30 meter. Nabeheer is vastgelegd voor 2016 en 2024, gekoppeld aan M16 en "
        "M17a. Nieuw in deze broncontrole is het OBN-rapport uit 2025: het onderscheidt MEY1–MEY5 "
        "en laat zien dat de vijf kerven geomorfologisch verschillend functioneren."
    )
    r.bold = True
    r.font.size = Pt(10)
    doc.add_paragraph()

    doc.add_heading("1. Wat nu vaststaat", level=1)
    add_bullet(doc, "De uitgevoerde zone is de zuidelijke variant bij het Parnassiapad. De noordelijke variant is niet uitgevoerd vanwege het ontbreken van een voldoende hoge, gesloten duinenrij achter de zeereep.")
    add_bullet(doc, "De vijf ingrepen zijn over circa 750 meter verdeeld. Vier zijn tot het strand doorgetrokken; daarnaast is een oude stuifkuil in de zeereep gereactiveerd zonder verbinding met het strand.")
    add_bullet(doc, "Het werk begon in winter 2013/2014, werd na de vondst van granaten stilgelegd en is in winter 2014/2015 afgerond. Dunea noemt september 2014 als aanvang en 2015 als voltooiingsjaar.")
    add_bullet(doc, "De evaluatie van 2025 en het ontwerpbeheerplan van 2026 registreren nabeheer in 2016 en 2024. De open verbinding met het strand vraagt blijvend toezicht en zo nodig open spitten of vegetatie verwijderen.")
    add_bullet(doc, "De ecologische werking wordt aannemelijk gemaakt via meer doorstuiving van kalkrijk zand. Een oorzakelijk effect op soorten of populaties is met de geraadpleegde bronnen niet vastgesteld.")

    doc.add_heading("2. Wat de levende database bevat", level=1)
    p = doc.add_paragraph()
    p.add_run("Gegevensverzameling. ").bold = True
    p.add_run(
        "In de lokale database Meijendel staan voor project zeereep_kerven één project, twee "
        "uitvoeringen, vier expliciete jaarbeoordelingen over 2014, 2015, 2016 en 2024, vier "
        "uitvoering–bronrelaties, vijf uitvoering–kavelrelaties, vijf gereconstrueerde "
        "uitvoeringsgeometrieën en tien regels in v_plot_jaar_maatregel_bronvast."
    )
    add_table(
        doc,
        ["Uitvoering", "Periode / jaren", "Kavels", "Hoeveelheid en betekenis"],
        [
            [
                "Vijf kerven aanleggen",
                "1 dec. 2013–31 mrt. 2015; uitgevoerd in 2014 en 2015",
                "M15, M16, M17a",
                "10,9434 ha / 109.434 m². Gezamenlijk totaal; niet verdeeld per kavel of jaar.",
            ],
            [
                "Nabeheer kerven en stuifkuilen",
                "Vanaf 1 jan. 2016, open einde; uitgevoerd in 2016 en 2024",
                "M16, M17a",
                "Open houden en vegetatie verwijderen waar nodig. Geen oppervlakte vastgelegd.",
            ],
        ],
        [Inches(1.35), Inches(1.65), Inches(1.05), Inches(3.0)],
    )
    p = doc.add_paragraph()
    p.add_run("Ruimtelijke opslag. ").bold = True
    p.add_run(
        "De database bewaart de vijf handmatig op de PDOK-luchtfoto 2025 gepositioneerde "
        "kernvlakken als TG03-polygonen, met objectcodes MEY1–MEY5 en geometriejaar 2015. "
        "Ieder vlak is 900 m²; samen 4.500 m². Het zijn gereconstrueerde kerfkernen, geen exacte "
        "begrenzing van het volledige werk. Daarom verdelen of vervangen zij het gezamenlijke "
        "ontgravingsoppervlak van 109.434 m² niet. De kaveltoedelingen M15, M16 en M17a blijven "
        "afzonderlijke relaties zonder doorsnijdingspercentage."
    )
    p = doc.add_paragraph()
    p.add_run("Bronspanning. ").bold = True
    p.add_run(
        "Van der Hagen, Ten Napel en Arens schreven in november 2017 dat tot dan geen nazorg "
        "nodig was. De definitieve Natura 2000-evaluatie uit 2025 registreert achteraf nabeheer "
        "in 2016 en 2024. De database gebruikt de publicatie uit 2017 daarom voor aanleg en "
        "ruimtelijke context, en de officiële evaluatie voor de nabeheerjaren. De bronnen gebruiken "
        "mogelijk niet exact dezelfde betekenis van nazorg en nabeheer; de beschikbare teksten "
        "lossen dat verschil niet verder op."
    )

    doc.add_heading("3. Wat de Zotero-bronnen toevoegen", level=1)
    doc.add_heading("Aanleg en eerste ontwikkeling — 2017", level=2)
    p = doc.add_paragraph()
    p.add_run("Van der Hagen, Ten Napel en Arens (2017) ").bold = True
    p.add_run(
        "is de primaire uitvoeringsbron. De auteurs beschrijven vijf plekken van 50–70 meter breed, "
        "het verwijderen van vegetatie en 10–20 cm bodem, de totale 109.434 m² en de onderbreking "
        "door munitievondsten. Een drone-opname uit voorjaar 2015 is in voorjaar 2017 herhaald. "
        "De verschilkaart toont erosie in alle vijf stuifgaten en afzetting in het achterliggende duin. "
        "De auteurs vonden het toen nog te vroeg voor stevige conclusies, maar zagen duidelijk meer "
        "dynamiek en landwaartse verplaatsing van zand."
    )

    doc.add_heading("Uitvoering, nabeheer en habitatcontext — 2025/2026", level=2)
    p = doc.add_paragraph()
    p.add_run("De definitieve evaluatie (Royal HaskoningDHV, 2025) ").bold = True
    p.add_run(
        "noemt de pilot uitgevoerd in 2014 en 2015. Anders dan in het eerste beheerplan was "
        "aangenomen, bleken de kerven nabeheer nodig te hebben; dat is volgens de evaluatie in "
        "2016 en 2024 uitgevoerd. De evaluatie ziet doorstuiving van kalkrijk zand ter hoogte van "
        "de kerven, maar noemt voor structuur en functie ook ontbrekende meetgegevens."
    )
    p = doc.add_paragraph()
    p.add_run("Het ontwerpbeheerplan 2026–2032 ").bold = True
    p.add_run(
        "herhaalt deze uitvoeringsgeschiedenis. Het stelt dat de bestaande kerven functioneren "
        "waarvoor zij zijn aangelegd, dat nabij de kerven meer zand stuift en dat voortgezet "
        "toezicht en eventueel open spitten of vegetatie verwijderen nodig blijven. Omdat dit een "
        "ontwerp is, is het in de database alleen gebruikt voor historische bevestiging en plancontext."
    )

    doc.add_heading("Vijf afzonderlijke kerven — OBN 2025", level=2)
    p = doc.add_paragraph()
    p.add_run("Wegman, Arens, De Lange en Van den Berg (2025) ").bold = True
    p.add_run(
        "plaatsen MEY1–MEY5 in een landelijke analyse van 58 kerven. Alle vijf zijn aangelegd, "
        "dateren in het rapport uit 2015 en verkeren in de eerste ontwikkelingsfase. De analyse "
        "gebruikt hoogtegegevens, luchtfoto's, satellietbeelden, suppletiegegevens en de momentane "
        "kustlijn van 2023."
    )
    add_table(
        doc,
        ["Kerf", "Kerngegeven uit OBN 2025", "Duiding"],
        [
            ["MEY1", "15 cm gemiddelde jaarlijkse hoogteverandering; 2,5× netto aanzanding t.o.v. referentie", "Noordelijk; functioneert van de vijf het minst."],
            ["MEY2", "14 cm gemiddelde jaarlijkse hoogteverandering; 2,3× netto aanzanding t.o.v. referentie", "Behoort landelijk tot de sterkste waarden in deze vergelijking."],
            ["MEY3", "Afzonderlijke geometrische kenmerken opgenomen", "Geen gelijkwaardige samenvattende effectmaat uitgelicht."],
            ["MEY4", "Afzonderlijke geometrische kenmerken opgenomen", "Minder embryonale duinontwikkeling dan noordelijker."],
            ["MEY5", "Afzonderlijke geometrische kenmerken opgenomen", "Functioneert van de vijf het best."],
        ],
        [Inches(0.7), Inches(3.55), Inches(2.8)],
    )
    p = doc.add_paragraph()
    p.add_run("Belangrijkste interpretatie. ").bold = True
    p.add_run(
        "Het verschil tussen MEY1 en MEY5 is volgens de auteurs waarschijnlijk geen gevolg van "
        "het wegvangen van zand door naastgelegen kerven. De groei van embryonale duinen neemt "
        "van noord naar zuid af; daardoor groeien de noordelijke kerven eerder dicht. Voor "
        "Meijendel is geen duidelijke suppletietrend zichtbaar. Kerven die dicht bij elkaar liggen "
        "kunnen elkaar juist versterken wanneer hun depositiezones samengroeien."
    )
    p = doc.add_paragraph()
    p.add_run("Reikwijdte. ").bold = True
    p.add_run(
        "De landelijke studie vindt gemiddeld circa 40% meer dynamiek bij kerven dan in ongekerfde "
        "zeereep en in 93% van de gevallen sterkere groei van de tweede duinenrij. Het zichtbare "
        "beïnvloedingsgebied varieert landelijk van 0,36 tot 4,30 hectare. Deze waarden zijn geen "
        "afzonderlijke effectschatting voor Meijendel. Het rapport behandelt nog niet de ecologische "
        "effecten; die zijn voor een volgende kennisvraag gereserveerd."
    )

    doc.add_heading("Historische context — één oudere stuifkuil", level=2)
    p = doc.add_paragraph()
    p.add_run("Arens en Van der Hagen (2010) ").bold = True
    p.add_run(
        "beschrijven een afzonderlijke stuifkuil bij Rijksstrandpaal 96, ontstaan in 1993 en gemeten "
        "van 1994 tot en met 2008. In 2008 was de dynamiek nog groot en was geen stabilisatie "
        "zichtbaar. Dit is relevante voorgeschiedenis van dynamisch zeereepbeheer, maar niet een "
        "van de vijf in 2013–2015 aangelegde kerven. Het Zotero-item vermeldt ten onrechte 1993 als "
        "publicatiejaar; de gekoppelde PDF komt uit Holland's Duinen 55 van april 2010."
    )

    doc.add_heading("4. Tijdlijn", level=1)
    add_table(
        doc,
        ["Jaar / periode", "Gebeurtenis", "Bronbasis"],
        [
            ["1993–2008", "Vrij ontwikkelende stuifkuil bij Rijksstrandpaal 96 gemonitord; afzonderlijk historisch object.", "Arens & Van der Hagen, 2010"],
            ["Winter 2013/2014", "Aanleg gestart; stilgelegd na vondst van granaten.", "Van der Hagen et al., 2017"],
            ["Winter 2014/2015", "Werk hervat en voltooid; vijf kerven gereed in 2015.", "Van der Hagen et al., 2017; Dunea, 2024"],
            ["2015", "Drone-opname en begin van de morfologische vergelijking.", "Van der Hagen et al., 2017"],
            ["2016", "Nabeheer volgens de latere Natura 2000-evaluatie.", "Royal HaskoningDHV, 2025"],
            ["Voorjaar 2017", "Herhaalde hoogtemeting; publicatie meldt dat tot dan geen nazorg nodig was.", "Van der Hagen et al., 2017"],
            ["2024", "Tweede expliciet geregistreerde nabeheeruitvoering.", "Royal HaskoningDHV, 2025"],
            ["2025", "OBN vergelijkt MEY1–MEY5 afzonderlijk binnen 58 Nederlandse kerven.", "Wegman et al., 2025"],
        ],
        [Inches(1.1), Inches(3.85), Inches(2.1)],
    )

    doc.add_heading("5. Wat nog niet is vastgelegd", level=1)
    add_number(doc, "De exacte volledige werkpolygonen van MEY1–MEY5. De database bewaart vijf gereconstrueerde kernvlakken van 900 m²; deze zijn niet gelijk aan de volledige ontgravingsvoetafdruk.")
    add_number(doc, "Een verdeling van 109.434 m² over kerven, kavels en uitvoeringsjaren. De bronnen geven alleen het gezamenlijke totaal.")
    add_number(doc, "De precieze werkvoetafdruk van het nabeheer in 2016 en 2024. Daarom blijven doorsnijdingspercentages leeg.")
    add_number(doc, "Een bronvaste verdeling van de kerfcodes MEY1–MEY5 over M15, M16 en M17a. De uitvoering is aan de drie kavels gekoppeld; per kerf is geen afzonderlijke kavelrelatie geconstrueerd.")
    add_number(doc, "Een causale ecologische effectschatting. De bronnen ondersteunen meer zanddynamiek en lokale doorstuiving, maar niet dat een waargenomen verandering in vogels, konijnen of vegetatie uitsluitend door de kerven is veroorzaakt.")

    doc.add_heading("6. Bronnen", level=1)
    add_source(doc, "Arens, S.M. & H. van der Hagen (2010). Een stuifkuil in de zeereep in Meijendel: 1993–2008. Holland's Duinen 55, 39–43. Zotero-item 22E2VJ5W. [Zotero vermeldt 1993 als jaar; de PDF dateert uit april 2010.]")
    add_source(doc, "Dunea (18 december 2024). Dynamiek in het duin. Officiële webpublicatie; in de levende database broncode dunea_dynamiek_2024.")
    add_source(doc, "Royal HaskoningDHV (25 april 2025). Evaluatie Natura 2000-beheerplan Meijendel & Berkheide. Zotero-item DUNY3DCC.")
    add_source(doc, "Haskoning (13 januari 2026). Ontwerp Natura 2000-beheerplan Meijendel & Berkheide 2026–2032. Zotero-item LAW9SJXC.")
    add_source(doc, "Van der Hagen, H., G. ten Napel & B. Arens (2017). Grenzen slechten in Meijendel: stuifgaten in de zeereep. Holland's Duinen 70, 15–20. Zotero-item C224J22K.")
    add_source(doc, "Wegman, C., S.M. Arens, S. de Lange & K. van den Berg (2025). Kerven in de Zeereep: tussenproduct beantwoording kennisvraag 1 en 2. Rapport OBN-2023-141-EA. OBN Natuurkennis. Zotero-item 8WBM6HGR. [De DOI in Zotero past niet bij dit rapport en is daarom niet gebruikt.]")

    doc.add_heading("Verantwoording", level=1)
    p = doc.add_paragraph()
    p.add_run(
        "Dit overzicht is gebaseerd op een directe uitlezing van de lokale levende database "
        "Meijendel op 12 november 2026 en op de gekoppelde volledige PDF's in de lokale "
        "Zotero-bibliotheek op /Volumes/T7 Data/Zotero. De database is voor deze opdracht niet "
        "alleen inhoudelijk gecontroleerd, maar ook aangevuld met vijf gereconstrueerde "
        "kervenkernvlakken. De bestaande uitvoering, jaren, hoeveelheid en kavelrelaties zijn "
        "daarbij ongewijzigd gebleven."
    )

    doc.core_properties.title = "De vijf kerven in Meijendel"
    doc.core_properties.subject = "Samenvatting levende database en Zotero-bronnen"
    doc.core_properties.author = "Levende Database Meijendel"
    doc.core_properties.keywords = "Meijendel, kerven, zeereep, verstuiving, nabeheer, Zotero"
    doc.save(OUTPUT)
    print(f"Gemaakt: {OUTPUT}")


if __name__ == "__main__":
    build()
