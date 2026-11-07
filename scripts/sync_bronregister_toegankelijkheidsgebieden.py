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
    "uit versies van omsloten gebieden. De eerste actuele gebiedsversie doorsnijdt "
    "18 kavels. Gebruik de afgeleide oppervlakteaandelen als ruimtelijke context, "
    "niet als historische drukreeks. Binnen de 52 vogelkavels zijn 13.902 "
    "BMP-bezoeken uit 1984–2025 beschikbaar voor controle van telinspanning. De "
    "kenmerkenlaag bevat 3.607 goedgekeurde voorkeurswaarden voor 159 vogelsoorten; "
    "3.555 waarden betreffen 156 positief geregistreerde soorten binnen de "
    "standaardselectie. Kenmerkwaarden zijn soortmetadata, geen nieuwe waarnemingen "
    "door de tijd."
)

GARMIN = (
    "Garmin-QField-veldbron opgenomen op 7 november 2026. De lokale QField-werkset "
    "bevat één door Ton Lansink gelopen Garmin Connect-activiteit uit 7 november "
    "2026: 5.624 GPS-punten in één spoor, 12.328 meter lijngeometrie en één daarvan "
    "afgeleide gebiedspolygoon. Ton bevestigde de volledige route als openbaar "
    "voetpad en het daadwerkelijk omsloten gebied als formeel afgesloten. De route "
    "staat als één object in paden_en_wegen; het grootste omsloten vlak staat als "
    "één object in gebieden. Voor de polygoon is de afstand van 40,3 meter tussen "
    "begin- en eindpunt met een rechte lijn gesloten; zestien kleine kruisingsvlakken "
    "door lokale GPS-overlap zijn uitgesloten en artefactgaten zijn niet overgenomen. "
    "De ruwe GPX blijft bij het overdraagbare QField-pakket. Garmin rapporteert in "
    "deze export geen horizontale nauwkeurigheid; dat veld blijft daarom leeg. De "
    "afgesloten polygoon is als één gebiedsversie in Meijendel opgenomen; de "
    "berekende oppervlakte in Rijksdriehoeksstelsel is 4.484.502,353 m². Dit is een "
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
    "De eerste invoer bestaat uit één afgesloten gebied en één versie, afgeleid uit "
    "de Garmin-QField-veldregistratie van 7 november 2026. De geometrie heeft bronhash "
    "2e709cf102d860e65c5c0b403660a1acfcb8e8ca2f5370c2686d6205cb868e48 en een "
    "berekende oppervlakte van 4.484.502,353 m². "
    "toegankelijkheidsgebied_plot_afleiding bevat 18 actuele doorsnijdingen met "
    "onderzoekskavels. Dit zijn afgeleide relaties: een vlak kan door een kavel lopen "
    "en een kavel kan verschillende statusvlakken bevatten. De status van een "
    "volledige kavel wordt daarom niet meer als bronfeit opgeslagen.",
    "Shiny en de statische browser gebruiken parser/cacheversie 16 en leiden per kavel "
    "en jaar oppervlakteaandelen af voor afgesloten, toegankelijk, toegankelijk met "
    "toegangskaart en niet door een gebied gedekt. Alleen wanneer één status 100% van "
    "de kavel bedekt, krijgt de gehele kavel die enkele status; anders blijft de "
    "uitkomst gemengd of onbekend. De geldigheid wordt bepaald door de overlap tussen "
    "analysejaar en geldig_vanaf/geldig_tot. De zware SQL-export, proefimport, volledige "
    "cachebouw en VPS-publicatie zijn nog niet uitgevoerd.",
    "De volledige herstelkopie van vóór de omzetting staat op /Volumes/T7 Data/"
    "Home_Ton/Meijendel data/Backups-archief/Meijendel/"
    "meijendel-toegankelijkheid-voor-migratie-20261107-193506.sql. Omvang: 85.868 "
    "bytes. SHA-256: 0bb4fe5297272f05f08b86e8891f7900e756a647e0d49065cf40af31209ffa50. "
    "De bijbehorende metadata legt 55 oude toegankelijkheidsregels, 55 "
    "herkomstkoppelingen en 139 beheerregistraties vast. Herstel is een afzonderlijk "
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
