from __future__ import annotations

import csv
import os
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

TELLER_MAPPING_ENV = "MEIJENDEL_TELLER_MAPPING_CSV"

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
    mapping_value = os.environ.get(TELLER_MAPPING_ENV)
    if not mapping_value:
        raise RuntimeError(
            f"Stel {TELLER_MAPPING_ENV} in op een afgeschermd CSV-bestand; "
            "persoonsgegevens worden niet meer in dit script opgeslagen."
        )

    mapping_path = Path(mapping_value).expanduser()
    by_name: dict[str, dict[str, str]] = {}
    with mapping_path.open(newline="", encoding="utf-8-sig") as handle:
        reader = csv.DictReader(handle)
        required = {"naam", "teller_id", "tellercode", "bandnummer"}
        missing = required.difference(reader.fieldnames or [])
        if missing:
            raise ValueError(f"Ontbrekende kolommen in tellermapping: {', '.join(sorted(missing))}")
        for source in reader:
            by_name[normalize_name(source["naam"])] = {
                "teller_id": clean_text(source["teller_id"]),
                "tellercode": clean_text(source["tellercode"]),
                "bandnummer_db": clean_text(source["bandnummer"]),
            }

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
