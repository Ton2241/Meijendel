from __future__ import annotations

import csv
import re
import unicodedata
from pathlib import Path

from docx import Document


DOCX = Path("/Users/ton/Desktop/kavels en tellers BMP 2026.docx")
CSV = Path("/Users/ton/Documents/GitHub/Meijendel/kavels_en_tellers_BMP_2026.csv")
CSV_PER_TELLER = Path("/Users/ton/Documents/GitHub/Meijendel/kavels_en_tellers_BMP_2026_per_teller.csv")
CSV_BANDNUMMER_CONTROLE = Path(
    "/Users/ton/Documents/GitHub/Meijendel/kavels_en_tellers_BMP_2026_bandnummer_controle.csv"
)

TELLERS_DB = [
    ("Leo Snellink", "167", "LSLK00", "603"),
    ("Reinder de Boer", "185", "RBOR00", "742"),
    ("Tim den Outer", "190", "TOTR02", "1169"),
    ("Andre Leegwater", "37", "ALGR00", "1188"),
    ("Marianne Geboers", "171", "MGBS00", "1172"),
    ("Tosca Koster", "189", "TKSR03", "1686"),
    ("Jennie Schouten", "159", "JSTN14", "1187"),
    ("Hans van As", "156", "JASQ00", "1511"),
    ("Frank Regeer", "150", "FRGR00", "1510"),
    ("Ron Ousen", "187", "ROSN01", "1176"),
    ("Wim Calame", "194", "WCLE00", "1508"),
    ("Nora Kösters", "177", "NKRS00", "1175"),
    ("Krijn Leeuwis", "164", "KLWS00", ""),
    ("Bart Dijkstra", "35", "ADKA00", "1161"),
    ("Ton Lansink", "38", "ALNK00", "1199"),
    ("Paul Willem Wirtz", "183", "PWRZ00", "813"),
    ("Frans Hooijmans", "149", "FHMS00", "1185"),
    ("Pamela Rijks", "181", "PRKS04", "1213"),
    ("Lis Stolp", "168", "LSLP00", "1505"),
    ("Michan Biesbroek", "170", "MBSK04", ""),
    ("Vincent van der Spek", "193", "VSEK00", ""),
    ("Jesse Zwart", "163", "JZRT04", ""),
    ("Yolande de Kok", "197", "YKOK00", "1500"),
    ("Huib van der Velde", "155", "HVLE00", "1134"),
    ("Renee Lankhorst", "186", "RLNT02", "1506"),
    ("Arja Zandstra", "43", "AZNA00", "1502"),
    ("Bart Habraken", "143", "BHBN01", ""),
    ("Reinoud van Bemmelen", "184", "RBMN02", "1504"),
    ("Floriaan van Bemmelen", "147", "FBMN01", "1503"),
    ("Frank Brouwer", "148", "FBWR00", "1018"),
    ("Jo van Buggenum", "198", "JBGM00", "1637"),
    ("Hanne Kunnen", "153", "HKNN03", "1168"),
    ("Wim Kooij", "196", "WKOY01", "1184"),
    ("Michiel van Nesselrooy", "199", "MNSY00", "1639"),
    ("Hanneke Oltheten", "154", "HOLN00", "1162"),
    ("Dini Thibaudier", "146", "DTBR00", "1163"),
    ("Jeroen van der Zwan", "162", "JZAN02", "1670"),
    ("Nastja van Strien", "180", "NSIN00", "1174"),
    ("Ton van Strien", "42", "ASIN00", "1173"),
    ("Ton Schijvens", "192", "TSVS01", "1294"),
    ("Gert-Jan Spierenburg", "152", "GSRG01", "1298"),
    ("Dennis van den Bergen", "145", "DBRN01", "719"),
    ("Wim van der Ham", "195", "WHAM03", "1164"),
    ("Amy van Nobelen", "40", "ANBN01", ""),
    ("Lucas Gans", "166", "LGNS00", ""),
    ("Martin Koole", "172", "MKLE00", "1165"),
    ("Annemarie Leeuwenburg", "39", "ALWH01", "1671"),
]

TELLER_NAME_ALIASES = {
    "André Leegwater": "Andre Leegwater",
    "Renée Lankhorst": "Renee Lankhorst",
    "Huib van de Velde": "Huib van der Velde",
    "Michiel van Nesselrooij": "Michiel van Nesselrooy",
    "Diny Thibaudier": "Dini Thibaudier",
    "Gert Spierenburg": "Gert-Jan Spierenburg",
    "Wim van de Ham": "Wim van der Ham",
    "Annemarie Leeuwenburgh": "Annemarie Leeuwenburg",
}

PLOTS_DB = [
    ("999991", "M1"),
    ("999998", "M10"),
    ("3502", "M10-12-76"),
    ("3499", "M105"),
    ("999990", "M11"),
    ("999987", "M12"),
    ("3519", "M12a"),
    ("3511", "M13"),
    ("3506", "M13s"),
    ("3512", "M14"),
    ("3524", "M15"),
    ("3525", "M16"),
    ("29456", "M16s"),
    ("999995", "M17"),
    ("3513", "M17a"),
    ("3529", "M17b"),
    ("3534", "M1a"),
    ("3505", "M1b"),
    ("3523", "M2"),
    ("3504", "M3"),
    ("29459", "M31"),
    ("3508", "M32"),
    ("3490", "M33"),
    ("3496", "M34"),
    ("3515", "M35"),
    ("3533", "M36"),
    ("999989", "M4"),
    ("3581", "M4-5"),
    ("100425", "M41"),
    ("29457", "M42"),
    ("10626", "M43"),
    ("3507", "M45"),
    ("3500", "M46"),
    ("999988", "M5"),
    ("9917", "M51"),
    ("20247", "M52"),
    ("27371", "M53"),
    ("999992", "M54"),
    ("12381", "M54a"),
    ("12382", "M54b"),
    ("29455", "M55"),
    ("3521", "M6"),
    ("3522", "M61"),
    ("3520", "M62"),
    ("3509", "M63"),
    ("3516", "M64"),
    ("3518", "M65"),
    ("3503", "M66"),
    ("3498", "M7"),
    ("3501", "M71"),
    ("3526", "M72"),
    ("3527", "M73"),
    ("3528", "M74"),
    ("3531", "M75"),
    ("3583", "M75a"),
    ("999996", "M76"),
    ("3532", "M77"),
    ("999994", "M78"),
    ("20758", "M78/79"),
    ("999993", "M79"),
    ("3530", "M8"),
    ("999997", "M8/11"),
    ("999999", "M8/9"),
    ("3497", "M83"),
    ("3517", "M84"),
    ("112100", "M84s"),
    ("3510", "M85"),
    ("999986", "M9"),
    ("3514", "M91"),
]


def clean_text(value: str) -> str:
    value = value.replace("\u00a0", " ")
    value = re.sub(r"\s+", " ", value)
    return value.strip()


def normalize_name(value: str) -> str:
    value = clean_text(value)
    value = unicodedata.normalize("NFKD", value)
    value = "".join(char for char in value if not unicodedata.combining(char))
    value = value.lower().replace("’", "'")
    value = re.sub(r"[^a-z0-9]+", " ", value)
    return clean_text(value)


def normalize_kavel(value: str) -> str:
    value = clean_text(value).lower()
    if value.startswith("m"):
        value = value[1:]
    value = value.replace("/", "-")
    return value


def starts_with_kavel(text: str) -> bool:
    return bool(re.match(r"^\s*\d+[A-Z]?(?:[/-]\d+[A-Z]?)*\b", text))


def paragraph_cells(text: str) -> list[str]:
    return [clean_text(cell) for cell in re.split(r"\t+", text) if clean_text(cell)]


def split_list(value: str, split_en: bool = False) -> list[str]:
    if not value:
        return []
    pattern = r"\s*,\s*"
    if split_en:
        pattern = r"\s*,\s*|\s+en\s+"
    return [clean_text(part) for part in re.split(pattern, value) if clean_text(part)]


def split_bandnummers(value: str) -> list[str]:
    if not value:
        return []
    return [clean_text(part) for part in re.split(r"\s*,\s*", value) if clean_text(part)]


def underlined_words(paragraph) -> list[str]:
    words: list[str] = []
    current: list[str] = []

    for run in paragraph.runs:
        text = run.text.replace("\t", " ")
        if run.font.underline and re.search(r"[A-Za-zÀ-ÿ]", text):
            current.append(text)
        elif current:
            words.append(clean_text("".join(current)))
            current = []

    if current:
        words.append(clean_text("".join(current)))

    return [word for word in words if word]


def parse_status_line(text: str) -> dict[str, str]:
    m = re.match(r"^\s*(\d+[A-Z]?(?:[/-]\d+[A-Z]?)*)\s+(.+?)\s*$", text)
    if not m:
        return {
            "kavel": "",
            "status": "opmerking",
            "tellers": "",
            "hoofdtellers": "",
            "armband_nrs": "",
            "opmerking": clean_text(text),
        }

    return {
        "kavel": clean_text(m.group(1)),
        "status": clean_text(m.group(2)),
        "tellers": "",
        "hoofdtellers": "",
        "armband_nrs": "",
        "opmerking": "",
    }


def parse_assignment_line(text: str, hoofdtellers: list[str]) -> dict[str, str]:
    cells = paragraph_cells(text)
    kavel = cells[0].rstrip() if cells else ""
    tellers = cells[1] if len(cells) > 1 else ""
    armband_nrs = cells[2] if len(cells) > 2 else ""
    opmerking = " ".join(cells[3:]) if len(cells) > 3 else ""

    if len(cells) == 2 and cells[1].startswith("beschikbaar"):
        return {
            "kavel": kavel,
            "status": "beschikbaar",
            "tellers": "",
            "hoofdtellers": "",
            "armband_nrs": "",
            "opmerking": cells[1],
        }

    if " NB " in f" {armband_nrs} ":
        armband_nrs, opmerking2 = re.split(r"\s+NB\s+", armband_nrs, maxsplit=1)
        opmerking = clean_text(f"{opmerking} NB {opmerking2}")

    return {
        "kavel": clean_text(kavel),
        "status": "bezet",
        "tellers": clean_text(tellers),
        "hoofdtellers": "; ".join(dict.fromkeys(hoofdtellers)),
        "armband_nrs": clean_text(armband_nrs),
        "opmerking": clean_text(opmerking),
    }


def merge_continuation(row: dict[str, str], text: str, hoofdtellers: list[str]) -> None:
    cells = paragraph_cells(text)
    if not cells:
        return

    teller_extra = cells[0]
    if teller_extra.lower().startswith("en "):
        teller_extra = teller_extra[3:]

    if teller_extra:
        if row["tellers"].lower().endswith(" en"):
            row["tellers"] = clean_text(f"{row['tellers']} {teller_extra}")
        else:
            row["tellers"] = clean_text(f"{row['tellers']} en {teller_extra}")

    if len(cells) > 1:
        if row["armband_nrs"]:
            row["armband_nrs"] = clean_text(f"{row['armband_nrs']}, {cells[-1]}")
        else:
            row["armband_nrs"] = clean_text(cells[-1])

    if hoofdtellers:
        existing = row["hoofdtellers"].split("; ") if row["hoofdtellers"] else []
        row["hoofdtellers"] = "; ".join(dict.fromkeys([*existing, *hoofdtellers]))


def load_tellers_from_database_extract() -> dict[str, dict[str, str]]:
    by_name: dict[str, dict[str, str]] = {}
    for naam, teller_id, tellercode, bandnummer in TELLERS_DB:
        row = {
            "teller_id": teller_id,
            "tellercode": tellercode,
            "bandnummer_db": bandnummer,
        }
        by_name[normalize_name(naam)] = row

    for alias, canonical in TELLER_NAME_ALIASES.items():
        if normalize_name(canonical) in by_name:
            by_name[normalize_name(alias)] = by_name[normalize_name(canonical)]

    return by_name


def load_plots_from_database_extract() -> dict[str, dict[str, str]]:
    return {
        normalize_kavel(kavel_nummer): {
            "Kavel_Nummer": kavel_nummer,
            "plot_id": plot_id,
        }
        for plot_id, kavel_nummer in PLOTS_DB
    }


def bandnummer_status(armband_nr: str, bandnummer_db: str, teller_id: str) -> str:
    armband_nr = clean_text(armband_nr)
    bandnummer_db = clean_text(bandnummer_db)

    if not armband_nr or armband_nr in {"?", "n.v.t", "n.v.t."}:
        return "niet te controleren"
    if not teller_id:
        return "geen match teller"
    if not bandnummer_db:
        return "bandnummer ontbreekt in database"
    if armband_nr == bandnummer_db:
        return "ok"
    if bandnummer_db in re.findall(r"\d+", armband_nr):
        return "ok"
    return "wijkt af"


def rows_per_teller(rows: list[dict[str, str]]) -> list[dict[str, str]]:
    output: list[dict[str, str]] = []
    tellers_by_name = load_tellers_from_database_extract()
    plots_by_kavel = load_plots_from_database_extract()

    for row in rows:
        if row["status"] != "bezet" or not row["tellers"]:
            continue

        tellers = split_list(row["tellers"], split_en=True)
        hoofdtellers = set(split_list(row["hoofdtellers"]))
        armband_nrs = split_bandnummers(row["armband_nrs"])

        for index, teller in enumerate(tellers):
            db_match = tellers_by_name.get(normalize_name(teller), {})
            plot_match = plots_by_kavel.get(normalize_kavel(row["kavel"]), {})
            armband_nr = armband_nrs[index] if index < len(armband_nrs) else ""
            output.append(
                {
                    "kavel": row["kavel"],
                    "Kavel_Nummer": plot_match.get("Kavel_Nummer", ""),
                    "plot_id": plot_match.get("plot_id", ""),
                    "status": row["status"],
                    "teller": teller,
                    "is_hoofdteller": "ja" if teller in hoofdtellers else "nee",
                    "armband_nr": armband_nr,
                    "teller_id": db_match.get("teller_id", ""),
                    "tellercode": db_match.get("tellercode", ""),
                    "bandnummer_db": db_match.get("bandnummer_db", ""),
                    "bandnummer_status": bandnummer_status(
                        armband_nr,
                        db_match.get("bandnummer_db", ""),
                        db_match.get("teller_id", ""),
                    ),
                    "opmerking": row["opmerking"],
                }
            )

    return output


def main() -> None:
    doc = Document(str(DOCX))
    rows: list[dict[str, str]] = []

    for paragraph in doc.paragraphs:
        text = paragraph.text
        stripped = clean_text(text)
        if not stripped or stripped.startswith("kavel "):
            continue
        if not re.match(r"^\s*(\d|\t|en\b)", text) and not text.startswith(" "):
            continue

        hoofdtellers = underlined_words(paragraph)

        if starts_with_kavel(text):
            if "\t" in text:
                rows.append(parse_assignment_line(text, hoofdtellers))
            else:
                rows.append(parse_status_line(text))
        elif rows:
            merge_continuation(rows[-1], text, hoofdtellers)

    with CSV.open("w", newline="", encoding="utf-8-sig") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["kavel", "status", "tellers", "hoofdtellers", "armband_nrs", "opmerking"],
        )
        writer.writeheader()
        writer.writerows(rows)

    teller_rows = rows_per_teller(rows)
    with CSV_PER_TELLER.open("w", newline="", encoding="utf-8-sig") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "kavel",
                "Kavel_Nummer",
                "plot_id",
                "status",
                "teller",
                "is_hoofdteller",
                "armband_nr",
                "teller_id",
                "tellercode",
                "bandnummer_db",
                "bandnummer_status",
                "opmerking",
            ],
        )
        writer.writeheader()
        writer.writerows(teller_rows)

    aandacht_rows = [
        row
        for row in teller_rows
        if row["bandnummer_status"] in {"wijkt af", "bandnummer ontbreekt in database", "geen match teller"}
    ]
    with CSV_BANDNUMMER_CONTROLE.open("w", newline="", encoding="utf-8-sig") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "kavel",
                "Kavel_Nummer",
                "plot_id",
                "status",
                "teller",
                "is_hoofdteller",
                "armband_nr",
                "teller_id",
                "tellercode",
                "bandnummer_db",
                "bandnummer_status",
                "opmerking",
            ],
        )
        writer.writeheader()
        writer.writerows(aandacht_rows)

    print(f"{CSV}")
    print(f"regels: {len(rows)}")
    print(f"{CSV_PER_TELLER}")
    print(f"regels per teller: {len(teller_rows)}")
    print(f"{CSV_BANDNUMMER_CONTROLE}")
    print(f"regels bandnummer controle: {len(aandacht_rows)}")


if __name__ == "__main__":
    main()
