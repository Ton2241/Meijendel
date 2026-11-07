#!/usr/bin/env python3
"""Synchroniseer het actuele toegankelijkheidsgebiedsmodel naar het bronregister-DOCX."""

from pathlib import Path

from docx import Document
from docx.oxml import OxmlElement
from docx.text.paragraph import Paragraph


ROOT = Path(__file__).resolve().parents[1]
DOCX = ROOT / "docs" / "MEIJENDEL_BRONREGISTER.docx"

ENVIRONMENT = (
    "Aanvullende verklarende gegevens. De bronvaste beheer-jaarview bevat nu 355 "
    "uitvoering-kavel-jaarrelaties voor 68 uitvoeringen, 52 kavels en 282 unieke "
    "kavel-jaren uit 1966–2025. Daarvan overlappen 293 relaties in 43 kavels met "
    "territoriumgegevens. doorsnijding_pct is in alle 355 relaties leeg: een "
    "kavelkoppeling bewijst niet de behandelde oppervlakte; ontbreken van een "
    "registratie bewijst evenmin dat geen beheer plaatsvond. Infrastructuur bevat "
    "vier indicatoren voor elk van 55 kavels in 2024. Toegankelijkheid wordt sinds "
    "7 november 2026 niet meer als kavelkenmerk opgeslagen, maar ruimtelijk afgeleid "
    "uit versies van omsloten gebieden. Vier actuele gebiedsversies leveren samen "
    "33 positieve doorsnijdingen met kavels. Gebruik de afgeleide oppervlakteaandelen als ruimtelijke context, "
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
    "berekende oppervlakte in Rijksdriehoeksstelsel is 4.483.573,104 m². De bronhash "
    "is aa7a6733e1bf8363df63dce66c17582956641db5aae57d0ec4bfe6b95e84c063. Dit is een "
    "lokaal gelokaliseerde veldbron voor toegankelijkheidsinventarisatie, geen "
    "ecologische soortwaarneming en geen bron voor Meijendel_bronnen. De gegevens "
    "vallen onder beheer van Ton Lansink; extern hergebruik is niet beoordeeld."
)

SECTION_TITLE = "Toegankelijkheid als gebiedsversies op 7 november 2026"
SECTION = [
    "De voorlopige toegankelijkheid per kavel is volledig vervangen. De 55 "
    "registraties uit 2024 zijn verwijderd uit maatregel_toegankelijkheid_registratie; "
    "ook de 55 bijbehorende doelen in maatregel_registratie_herkomst, de kolom "
    "toegang_registratie_id en de tabel zelf zijn verwijderd. De oude CSV's en "
    "migratiebestanden blijven uitsluitend als historische audit- en herstelbron "
    "herkenbaar. Zij vormen geen actieve invoerroute meer. Bron 101 blijft bestaan "
    "omdat daaraan daarnaast 139 beheerregistraties uit 1991–1999 zijn gekoppeld.",
    "De levende lokale database bevat nu drie toegestane gebiedsstatussen: afgesloten, "
    "toegankelijk en toegankelijk_met_toegangskaart. De tabellen "
    "toegankelijkheidsgebied en toegankelijkheidsgebied_versie bewaren respectievelijk "
    "de identiteit van een vlak en zijn opeenvolgende geometrische en inhoudelijke "
    "versies. Voor iedere bestaande en later ingevoerde versie geldt standaard "
    "geldig_vanaf = 1955-01-01; deze datum berust op Tons inschatting. geldig_tot = "
    "NULL betekent dat de versie actueel blijft totdat een einddatum wordt ingevoerd. "
    "De view v_toegankelijkheidsgebied_actueel selecteert alleen versies die op de "
    "huidige datum geldig zijn.",
    "De levende database bevat vier actuele gebieden: twee afgesloten en twee toegankelijk. Het "
    "gecorrigeerde Garmin-vlak heeft bronhash aa7a6733e1bf8363df63dce66c17582956641db5aae57d0ec4bfe6b95e84c063 "
    "en een oppervlakte van 4.483.573,104 m². Het tweede vlak is de geometrische "
    "vereniging van de volledige kavels M13, M13s, M14, M15, M16 en M17a. Dit vlak heeft "
    "bronhash 9b80ddd431c7a55b04f7dc1636d8fba49239bfa30f6bd693eb0ff420998efd68 en een "
    "oppervlakte van 2.402.217,706 m². M66 en M105 zijn als twee afzonderlijke "
    "toegankelijke gebieden opgenomen, exact volgens hun kavelgrenzen; hun oppervlakten "
    "zijn respectievelijk 576.909,232 en 155.796,244 m². "
    "toegankelijkheidsgebied_plot_afleiding bevat 33 actuele positieve doorsnijdingen; "
    "voor de acht bevestigde kavels is het aandeel 100%. De Garmin-veldregistratie en de handmatig bevestigde plotselectie hebben "
    "ieder een eigen bronregel; maatregel_bron bevat na deze invoer 57 regels. Dit zijn "
    "afgeleide relaties: een vlak kan door een kavel lopen "
    "en een kavel kan verschillende statusvlakken bevatten. De status van een "
    "volledige kavel wordt daarom niet meer als bronfeit opgeslagen.",
    "Shiny en de statische browser gebruiken parser/cacheversie 16 en leiden per kavel "
    "en jaar oppervlakteaandelen af voor afgesloten, toegankelijk, toegankelijk met "
    "toegangskaart en niet door een gebied gedekt. Alleen wanneer één status 100% van "
    "de kavel bedekt, krijgt de gehele kavel die enkele status; anders blijft de "
    "uitkomst gemengd of onbekend. De geldigheid wordt bepaald door de overlap tussen "
    "analysejaar en geldig_vanaf/geldig_tot. De zware SQL-export, proefimport, volledige "
    "cachebouw en VPS-publicatie zijn nog niet uitgevoerd.",
    "De herstelkopie van vóór deze geometriecorrectie staat op /Volumes/T7 Data/"
    "Home_Ton/Meijendel data/Backups-archief/Meijendel/"
    "meijendel-toegankelijkheid-voor-migratie-20261107-204412.sql. Omvang: 332.476 "
    "bytes. SHA-256: 1470f5f3fa1b66f8966f6191bf8c7f7697f7eb20095aaa2398933440ac4546f5. "
    "De bijbehorende metadata legt de vier betrokken tabellen, de vier actuele "
    "bronhashes en 139 behouden beheerregistraties vast. Herstel is een afzonderlijk "
    "besluit.",
]


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


def main() -> None:
    document = Document(DOCX)
    replace_paragraph(document, "Aanvullende verklarende gegevens.", ENVIRONMENT)
    replace_paragraph(document, "Garmin-QField-veldbron", GARMIN)
    replace_paragraph_any(document, ("De eerste invoer bestaat", "De levende database bevat twee afgesloten gebieden", "De levende database bevat vier actuele gebieden"), SECTION[2])
    replace_paragraph_any(document, ("De volledige herstelkopie van vóór de omzetting", "De herstelkopie van vóór deze geometriecorrectie"), SECTION[4])
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
    if not any(p.text == SECTION_TITLE for p in document.paragraphs):
        anchors = [p for p in document.paragraphs if p.text == "Archivering van herstelkopieën op 23 oktober 2026"]
        if len(anchors) != 1:
            raise RuntimeError("Anker voor actuele toegankelijkheidssectie niet uniek")
        anchor = anchors[0]
        insert_before(anchor, SECTION_TITLE, "Heading 2")
        for index, text in enumerate(SECTION):
            insert_before(anchor, text, "First Paragraph" if index == 0 else "Body Text")
    document.save(DOCX)

    check = Document(DOCX)
    if sum(p.text == SECTION_TITLE for p in check.paragraphs) != 1:
        raise RuntimeError("Nieuwe sectie niet exact eenmaal opgeslagen")
    if not any("parser/cacheversie 16" in p.text for p in check.paragraphs):
        raise RuntimeError("Parserversie 16 ontbreekt in DOCX")
    print(f"Bijgewerkt: {DOCX}")


if __name__ == "__main__":
    main()
