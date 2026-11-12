#!/usr/bin/env python3
"""Actualiseer het levende begrazingsdocument na heranalyse van Zotero."""

from pathlib import Path

from docx import Document
from docx.oxml import OxmlElement
from docx.text.paragraph import Paragraph


ROOT = Path(__file__).resolve().parents[1]
DOCX = ROOT / "docs" / "Begrazing_in_Meijendel.docx"


def set_text(paragraph: Paragraph, text: str) -> bool:
    if paragraph.text == text:
        return False
    for run in list(paragraph.runs):
        run._element.getparent().remove(run._element)
    paragraph.add_run(text)
    return True


def find_prefix(document: Document, prefix: str) -> Paragraph:
    return next(p for p in document.paragraphs if p.text.startswith(prefix))


def find_prefixes(document: Document, *prefixes: str) -> Paragraph:
    return next(
        p
        for p in document.paragraphs
        if any(p.text.startswith(prefix) for prefix in prefixes)
    )


def insert_before(anchor: Paragraph, text: str, style: str) -> Paragraph:
    element = OxmlElement("w:p")
    anchor._p.addprevious(element)
    paragraph = Paragraph(element, anchor._parent)
    paragraph.style = style
    paragraph.add_run(text)
    return paragraph


def main() -> None:
    document = Document(DOCX)
    changed = False

    changed |= set_text(
        find_prefix(document, "Chronologisch overzicht van beheerbegrazing"),
        "Chronologisch overzicht van beheerbegrazing met vee · stand 12 november 2026",
    )

    start = find_prefix(document, "29 september 1990 · Kijfhoek/Bierlap")
    changed |= set_text(
        start,
        "29 september 1990 · Kijfhoek/Bierlap  Noorse fjordenpaarden werden uitgezet; "
        "Gallowayrunderen volgden kort daarna. Het in 1990 geadviseerde maximum was één "
        "grootvee-eenheid per 10 ha, of 27 dieren op 270 ha. Feitelijk werd aanvankelijk "
        "circa één dier per 12 ha toegepast; in 1995 werd de bezetting in Kijfhoek/Bierlap "
        "verlaagd naar circa één dier per 18 ha. De begrazing was jaarrond. Bronnen noemen "
        "circa 270 of 275 ha. De kaart uit 1992 begrenst het toen onderzochte begrazingsgebied; "
        "die grens is nog niet als digitale geometrie over de huidige kavels gelegd. [1–6, 19, 21–22]",
    )

    announcement = find_prefix(document, "26 juli 1990 · Aankondiging")
    if not any(p.text.startswith("Rond 1900 · einde traditionele veehouderij") for p in document.paragraphs):
        insert_before(
            announcement,
            "Rond 1900 · einde traditionele veehouderij  De langjarige vegetatiestudies plaatsen de "
            "moderne herintroductie in een langere geschiedenis: veehouderij en begrazing verdwenen "
            "rond 1900 uit Meijendel. De precieze laatste gebruiksjaren en historische begrenzingen "
            "zijn in de geraadpleegde bronnen niet per kavel gereconstrueerd. [21–22]",
            "Event",
        )
        changed = True

    pallantsduin = find_prefixes(
        document,
        "Startjaar open · Pallantsduin",
        "Startjaar niet zelfstandig vastgesteld · Pallantsduin",
    )
    changed |= set_text(
        pallantsduin,
        "Startjaar niet zelfstandig vastgesteld · Pallantsduin  De luchtfotostudie uit 2020 "
        "behandelt Pallantsduin als begraasd onderzoeksgebied van 43 ha en gebruikt eind 1990 "
        "als gemeenschappelijk startpunt voor de statistische vergelijking. Zij documenteert "
        "echter niet afzonderlijk wanneer daar voor het eerst vee is uitgezet. Daarom blijft "
        "het uitvoeringsstartjaar voor Pallantsduin open; 1990 is hier een onderzoeksaanname, "
        "geen zelfstandig veldbewijs. [11, 21]",
    )

    geo = find_prefix(document, "Geografische en inhoudelijke grenzen")
    if not any(p.text == "Wat de effectstudies wel en niet laten zien" for p in document.paragraphs):
        effect_paragraphs = [
            (
                "Heading 2",
                "Wat de effectstudies wel en niet laten zien",
            ),
            (
                "Event",
                "1990–1995 · vegetatie op korte schaal  In 19 permanente vegetatieplots en drie "
                "transecten namen Duinriet en Zandzegge meestal af. Het gemiddelde aantal soorten "
                "per plot steeg na de daling tot 1990 van 24 naar 30, maar die stijging was niet "
                "statistisch significant. In de begraasde transecten werd het patroon fijner en "
                "namen open zand en korte vegetatie toe; de onbegraasde Noorderpan werd juist "
                "grover. Dit is sterk lokaal bewijs voor structuurverandering, niet voor een "
                "gebiedsdekkend langetermijneffect. [4–5, 19]",
            ),
            (
                "Event",
                "1985–1999 · broedvogels  De vergelijking omvatte de 35 talrijkste soorten in "
                "begraasde en onbegraasde kavels. Tussen 1991 en 1999 ontwikkelden Kauw, Ekster, "
                "Wilde eend, Houtduif en Vlaamse gaai zich significant positiever in het begraasde "
                "gebied; Kleine karekiet, Kneu, Nachtegaal en Fitis significant negatiever. Het "
                "aantal soorten nam niet significant toe. De onderzoeksopzet toont verschillen "
                "tussen gebieden, maar geen causaal begrazingseffect; 73 minder talrijke soorten "
                "vielen buiten de toetsing. [6, 18]",
            ),
            (
                "Event",
                "1991–1996 · dagvlinders  De Meijendel-evaluatie over 1991–1994 vond bij vijf van "
                "zeven geselecteerde, voldoende talrijke soorten een positieve reactie, maar had "
                "geen metingen van vóór de begrazing. De bredere studie over 1992–1996 omvatte "
                "22 routes, waaronder zes in Meijendel, en vond vooral voordelen voor soorten van "
                "open pionier- en grasland. Zij waarschuwt tegelijk dat hoge druk ongunstig kan "
                "zijn voor soorten van hoger gras en dat routes geen gecontroleerd experiment "
                "vormden. [6, 20]",
            ),
            (
                "Event",
                "1975–2009 · luchtfotovergelijking  Zes onderzoeksgebieden van samen 302 ha "
                "vergeleken drie begraasde gebieden met drie onbegraasde controles. Elf en "
                "negentien jaar na 1990 was geen significant effect van vee aantoonbaar op het "
                "oppervlak open zand, grasland of struweel. Tijd en afstand tot de kust verklaarden "
                "meer. De studie behandelt Helmduinen, Kijfhoek/Bierlap en Pallantsduin als de "
                "begraasde onderzoeksgroep. [21]",
            ),
            (
                "Event",
                "1953–2012 · permanente vegetatieplots  De langste analyse omvatte 41 droge plots "
                "en 479 vegetatieopnamen in Helmduinen, Kijfhoek en Bierlap. Na 1990 was 90% van "
                "de geregistreerde veranderingen progressieve successie en 10% regressief, ondanks "
                "begrazing. De auteurs verbinden de voortgaande uitbreiding van struweel en bos "
                "vooral met de instorting van de konijnenstand na virusuitbraken; klimaat en "
                "stikstof vormen aanvullende verklaringen. [22]",
            ),
            (
                "Normal",
                "De studies spreken elkaar niet eenvoudig tegen. Zij meten andere ruimtelijke "
                "schalen, perioden en uitkomsten. Begrazing kan lokaal Duinriet terugdringen en "
                "een fijner mozaïek maken, terwijl op landschapsschaal toch geen zelfstandig effect "
                "op de oppervlakte van zand, grasland en struweel aantoonbaar is. Voor vogels en "
                "vlinders zijn soortenreacties bovendien niet gelijkgericht. Begrazing is dus een "
                "beheerfactor binnen een configuratie van konijnenstand, stikstof, klimaat, "
                "waterhuishouding en aanvullend beheer; geen enkelvoudige verklaring. [6, 18–22]",
            ),
        ]
        for style, text in effect_paragraphs:
            insert_before(geo, text, style)
        changed = True

    open_points = find_prefix(document, "De foto en het bijschrift in het Algemeen Dagblad")
    if not any(p.text.startswith("Honden en terreingebruik van grazers") for p in document.paragraphs):
        insert_before(
            open_points,
            "Honden en terreingebruik van grazers. Een in 2026 aan Zotero toegevoegd OBN-stageadvies "
            "beschrijft op basis van literatuur een mogelijke keten: honden kunnen het terreingebruik "
            "van grazers beïnvloeden, waardoor de begrazingsdruk ruimtelijk ongelijker wordt. Het "
            "rapport toont dit proces niet in Meijendel aan. Het is daarom een onderzoekshypothese, "
            "geen historische beheerregistratie en geen grond voor een databasewijziging. [23]",
            "Normal",
        )
        changed = True

    database = find_prefix(document, "De levende lokale database is op 11 november 2026")
    changed |= set_text(
        database,
        "De levende lokale database is op 11 november 2026 met de bronvaste begrazingsinformatie "
        "bijgewerkt. De actuele lokale stand van 12 november 2026 bevat 74 maatregelbronnen, 97 "
        "uitvoeringen, 135 expliciete jaarbeoordelingen, 149 uitvoering–bronrelaties, 286 "
        "uitvoering–kavelrelaties en 12 uitvoeringsgeometrieën. De bronvaste kavel-jaarlaag bevat "
        "366 regels. De heranalyse in dit document verandert die database niet: de nieuwe informatie "
        "betreft effectinterpretatie en bronduiding, niet een nieuw bronvast uitvoeringsjaar of een "
        "nieuwe kavelgrens.",
    )

    source_status = find_prefixes(
        document,
        "Bronstatus. Zotero-sleutels",
        "Bronstatus. De lokale Zotero-volledige-tekstindex",
    )
    changed |= set_text(
        source_status,
        "Bronstatus. De lokale Zotero-volledige-tekstindex is op 12 november 2026 doorzocht op "
        "begrazingstermen in combinatie met Meijendel en de relevante naamgebieden. Dat leverde "
        "135 bijlagen onder 129 bibliografische hoofditems op. Alle 135 geselecteerde "
        "tekstbijlagen en hun contexttreffers zijn op relevante begrazingspassages beoordeeld; "
        "57 bijlagen zijn volledige nummers van Holland’s Duinen "
        "en 19 volledige afleveringen van Meijendel Mededelingen. Zulke tijdschriftnummers tellen "
        "als documenttreffer, maar niet iedere vermelding vormt zelfstandig bewijs voor uitvoering. "
        "Zotero-sleutels hieronder verwijzen naar de geraadpleegde lokale bibliotheek. Online "
        "bronnen zonder Zotero-item blijven afzonderlijk herkenbaar.",
    )

    delpher = find_prefix(document, "Delpher. Algemeen Dagblad")
    if not any(p.text.startswith("[18] Van der Niet") for p in document.paragraphs):
        additions = [
            "[18] Van der Niet, T. (2001). Voorzichtigheid motto bij begrazingsevaluatie van broedvogels. Holland’s Duinen 38, 57–65. Zotero C7RG5ADR.",
            "[19] De Bonte, A.J. & Boosten, A. (1996). Changes in the Vegetation of Meijendel Influenced by Grazing. Zotero KLYS24B8.",
            "[20] WallisDeVries, M.F. & Raemakers, I. (2001). Does Extensive Grazing Benefit Butterflies in Coastal Dunes? Restoration Ecology 9(2), 179–188. Zotero WULG249S.",
            "[21] Van der Hagen, H.G.J.M. e.a. (2020). Is livestock grazing a key factor for changing vegetation patterns in lime rich coastal dunes in the Netherlands? Journal of Coastal Conservation 24:15. Zotero IVRJVABT.",
            "[22] Van der Hagen, H.G.J.M. e.a. (2023). The role of livestock grazing in long-term vegetation changes in coastal dunes: a case study from the Netherlands. Plant Sociology 60(1), 1–12. Zotero XJFRZYF8.",
            "[23] Van Hasselt, Y. (2026). Pootafdruk in de natuur. Advies over de effecten van honden in de natuur. Stageopdracht, OBN-45-FA. Zotero PGT9J6Z3.",
        ]
        for text in additions:
            insert_before(delpher, text, "Source")
        changed = True

    changed |= set_text(
        delpher,
        "Delpher. Algemeen Dagblad (26 juli 1990). Paarden moeten gras maaien. Zotero JXGCWLIM. "
        "https://resolver.kb.nl/resolve?urn=KBPERS01:003088022:mpeg21:a00063",
    )
    changed |= set_text(
        find_prefix(document, "Delpher-foto. Algemeen Dagblad"),
        "Delpher-foto. Algemeen Dagblad (27 september 1990). Drinkwaterduinen van Meijendel "
        "gekortwiekt. Foto Bram Gebuys. Zotero 6QMZXGJM. "
        "https://resolver.kb.nl/resolve?urn=KBPERS01:003081023:mpeg21:a00076",
    )
    changed |= set_text(
        find_prefix(document, "Delpher 1991. Hans Schmit"),
        "Delpher 1991. Hans Schmit, Dynamisch duin en waterwinning, Trouw, 24 juli 1991. "
        "Zotero UBJVF8X4. https://resolver.kb.nl/resolve?urn=ABCDDD:010824398:mpeg21:a0056",
    )

    if changed:
        document.save(DOCX)

    check = Document(DOCX)
    required = [
        "Wat de effectstudies wel en niet laten zien",
        "Rond 1900 · einde traditionele veehouderij",
        "Honden en terreingebruik van grazers.",
        "[22] Van der Hagen, H.G.J.M. e.a. (2023).",
    ]
    for prefix in required:
        if sum(p.text.startswith(prefix) for p in check.paragraphs) != 1:
            raise RuntimeError(f"Alinea niet exact eenmaal teruggelezen: {prefix}")
    print(f"Bijgewerkt: {DOCX}")


if __name__ == "__main__":
    main()
