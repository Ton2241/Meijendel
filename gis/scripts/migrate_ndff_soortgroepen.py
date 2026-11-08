#!/usr/bin/env python3
"""Bouw het doelmodel voor fysieke openbare soortgroepwaarnemingen."""

import re
import subprocess
import json
import argparse


GROUP_CODES = (
    "amfibieen", "dagvlinders", "eencelligen", "geleedpotigen_overig",
    "insecten_overig", "kevers", "kranswieren_wieren_algen",
    "kreeftachtigen", "libellen", "microvlinders", "nachtvlinders",
    "ongewervelden_overig", "reptielen", "schimmels",
    "snavelinsecten", "spinachtigen", "sprinkhanen_en_krekels",
    "vaatplanten", "vissen", "vleermuizen", "vliegen_en_muggen",
    "vliesvleugeligen", "weekdieren", "zoogdieren_overig",
)

LABEL_CODES = {
    "Amfibieën": "amfibieen",
    "Dagvlinders": "dagvlinders",
    "Eencelligen": "eencelligen",
    "Geleedpotigen (overig)": "geleedpotigen_overig",
    "Insecten (overig)": "insecten_overig",
    "Kevers": "kevers",
    "Kranswieren, wieren en algen": "kranswieren_wieren_algen",
    "Kreeftachtigen": "kreeftachtigen",
    "Libellen": "libellen",
    "Microvlinders": "microvlinders",
    "Nachtvlinders": "nachtvlinders",
    "Ongewervelden (overig)": "ongewervelden_overig",
    "Reptielen": "reptielen",
    "Schimmels": "schimmels",
    "Snavelinsecten": "snavelinsecten",
    "Spinachtigen": "spinachtigen",
    "Sprinkhanen en krekels": "sprinkhanen_en_krekels",
    "Vaatplanten": "vaatplanten",
    "Vissen": "vissen",
    "Vleermuizen": "vleermuizen",
    "Vliegen en muggen": "vliegen_en_muggen",
    "Vliesvleugeligen": "vliesvleugeligen",
    "Weekdieren": "weekdieren",
    "Zoogdieren (overig)": "zoogdieren_overig",
}


def identifier(value: str) -> str:
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", value):
        raise ValueError(f"Ongeldige SQL-identificatie: {value!r}")
    return f"`{value}`"


def destination_for(raw_group: str, primary_group: str | None) -> str:
    labels = raw_group.split("|")
    try:
        source_groups = {LABEL_CODES[label] for label in labels}
    except KeyError as exc:
        raise ValueError(f"Onbekend brongroepslabel: {exc.args[0]}") from exc
    if primary_group not in source_groups or primary_group not in GROUP_CODES:
        raise ValueError(
            f"Primaire centrale groep {primary_group!r} past niet bij {raw_group!r}"
        )
    return f"{primary_group}_waarneming"


def new_table_sql(schema: str = "Meijendel") -> list[str]:
    """Maak brongetrouwe groepstabellen met bestaande register- en bron-FK's."""
    target = identifier(schema)
    source = f"{target}.`ndff_open_waarneming`"
    register = f"{target}.`ndff_open_waarneming_register`"
    statements = []
    for group in GROUP_CODES:
        table = f"{target}.{identifier(group + '_waarneming')}"
        statements.append(f"CREATE TABLE {table} LIKE {source};")
        statements.append(
            f"ALTER TABLE {table} MODIFY `waarneming_id` BIGINT UNSIGNED NOT NULL, "
            f"ADD CONSTRAINT {identifier('fk_' + group + '_waarneming_register')} "
            f"FOREIGN KEY (`waarneming_id`) REFERENCES {register} (`waarneming_id`) "
            "ON UPDATE NO ACTION ON DELETE NO ACTION, "
            f"ADD CONSTRAINT {identifier('fk_' + group + '_waarneming_batch')} "
            f"FOREIGN KEY (`batch_id`) REFERENCES {target}.`ndff_open_import_batch` (`batch_id`) "
            "ON UPDATE NO ACTION ON DELETE NO ACTION, "
            f"ADD CONSTRAINT {identifier('fk_' + group + '_waarneming_soort')} "
            f"FOREIGN KEY (`soort_key`) REFERENCES {target}.`ndff_soorten` (`soort_key`) "
            "ON UPDATE NO ACTION ON DELETE NO ACTION;"
        )
    return statements


def query(sql: str) -> list[list[str]]:
    """Gebruik uitsluitend de bestaande lokale MySQL-loginconfiguratie."""
    result = subprocess.run(
        ["/usr/local/mysql/bin/mysql", "--login-path=meijendel_root",
         "--protocol=tcp", "--host=127.0.0.1", "--port=3306",
         "--batch", "--raw", "--skip-column-names", "-e", sql],
        capture_output=True, text=True, check=False,
    )
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "MySQL-query mislukt")
    return [line.split("\t") for line in result.stdout.splitlines() if line]


def preflight() -> dict:
    """Lees de fysieke bron- en taxonverdeling zonder databasewijzigingen."""
    rows = query("""SELECT o.soortgroep_raw,g.groep_code,COUNT(*)
        FROM Meijendel.ndff_open_waarneming o
        JOIN Meijendel.ndff_soorten s ON s.soort_key=o.soort_key
        JOIN Meijendel.taxa_bronkoppeling b
          ON b.koppeling_id=s.taxon_bronkoppeling_id
        JOIN Meijendel.taxa t ON t.taxon_id=b.taxon_id
        JOIN Meijendel.taxon_groepen g ON g.groep_id=t.groep_id
        GROUP BY o.soortgroep_raw,g.groep_code
        ORDER BY o.soortgroep_raw,g.groep_code""")
    groups = {code: 0 for code in GROUP_CODES}
    dual_labels = 0
    for raw, code, count_raw in rows:
        destination_for(raw, code)
        groups[code] += int(count_raw)
        if "|" in raw:
            dual_labels += int(count_raw)
    parent = int(query("SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming")[0][0])
    if sum(groups.values()) != parent:
        raise RuntimeError("Niet alle bronwaarnemingen hebben precies één centrale groep")
    targets = query("SELECT TABLE_NAME FROM information_schema.TABLES "
                    "WHERE TABLE_SCHEMA='Meijendel' AND TABLE_NAME REGEXP "
                    "'(_waarneming)$'")
    existing_targets = {row[0] for row in targets} & {
        f"{code}_waarneming" for code in GROUP_CODES
    }
    if existing_targets:
        raise RuntimeError(f"Doeltabellen bestaan al: {sorted(existing_targets)}")
    return {"bronregels": parent, "periode": "1700-2025",
            "dubbel_bronlabel": dual_labels, "per_groep": groups,
            "levende_database_gewijzigd": False}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preflight", action="store_true",
                        help="alleen-lezen nulmeting; geen migratie")
    args = parser.parse_args()
    if not args.preflight:
        parser.error("Alleen --preflight is nu beschikbaar; migratie vereist herstelproef")
    print(json.dumps(preflight(), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
