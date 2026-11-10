#!/usr/bin/env python3
"""Inventariseer NDFF-groepen en onderbouwde trendreeksen, uitsluitend lezend."""

import subprocess
import json
import argparse

# Bestaande bronlabels zijn alleen nuttig voor een taxonomische dekkingscontrole.
# Deze lijst is geen tabelindeling of migratieselectie.
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


def source_group_matches(raw_group: str, primary_group: str | None) -> bool:
    """Controleer bronlabels tegen de centrale groep, zonder opslagbestemming."""
    labels = raw_group.split("|")
    try:
        source_groups = {LABEL_CODES[label] for label in labels}
    except KeyError as exc:
        raise ValueError(f"Onbekend brongroepslabel: {exc.args[0]}") from exc
    return primary_group in source_groups


def trend_candidate(series: dict) -> bool:
    """Laat alleen gedocumenteerd complete, toegelaten herhaalde reeksen door."""
    try:
        first_year = int(series["jaar_van"])
        last_year = int(series["jaar_tot"])
    except (TypeError, ValueError, KeyError):
        return False
    return (
        bool(series.get("deelreeks_sleutel"))
        and series.get("analyse_type_code") in {"TV", "TA", "TK"}
        and series.get("eindbesluit") == "toegelaten"
        and series.get("bezoekstructuur_status") == "volledig"
        and series.get("methode_status") == "volledig"
        and series.get("ruimtelijke_status") == "exact_of_eenduidig"
        and first_year < last_year
        and (series.get("analyse_type_code") != "TV" or
             series.get("nulwaarneming_status") in {"expliciet", "betrouwbaar_afleidbaar"})
    )


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
    """Lees bronverdeling en vastgelegde reeksbesluiten zonder migratieplan."""
    rows = query("""SELECT o.soortgroep_raw,g.groep_code,COUNT(*)
        FROM Meijendel.ndff_open_waarneming o
        JOIN Meijendel.ndff_soorten s ON s.soort_key=o.soort_key
        JOIN Meijendel.taxa_bronkoppeling b
          ON b.koppeling_id=s.taxon_bronkoppeling_id
        JOIN Meijendel.taxa t ON t.taxon_id=b.taxon_id
        JOIN Meijendel.taxon_groepen g ON g.groep_id=t.groep_id
        GROUP BY o.soortgroep_raw,g.groep_code
        ORDER BY o.soortgroep_raw,g.groep_code""")
    groups = {}
    dual_labels = 0
    for raw, code, count_raw in rows:
        if not source_group_matches(raw, code):
            raise RuntimeError(f"Centrale groep {code!r} past niet bij bronlabel {raw!r}")
        groups[code] = groups.get(code, 0) + int(count_raw)
        if "|" in raw:
            dual_labels += int(count_raw)
    parent_raw, first_year, last_year = query(
        "SELECT COUNT(*),MIN(jaar),MAX(jaar) FROM Meijendel.ndff_open_waarneming"
    )[0]
    parent = int(parent_raw)
    if sum(groups.values()) != parent:
        raise RuntimeError("Niet alle bronwaarnemingen hebben precies één centrale groep")
    decisions = query("""SELECT deelreeks_sleutel,analyse_type_code,eindbesluit,
        bezoekstructuur_status,nulwaarneming_status,methode_status,
        ruimtelijke_status,jaar_van,jaar_tot
        FROM Meijendel.v_analyse_catalogus
        WHERE datareeks_sleutel='ndff-canoniek'
          AND analyse_type_code IN ('TV','TA','TK')""")
    fields = ("deelreeks_sleutel", "analyse_type_code", "eindbesluit",
              "bezoekstructuur_status", "nulwaarneming_status", "methode_status",
              "ruimtelijke_status", "jaar_van", "jaar_tot")
    candidates = []
    for values in decisions:
        series = dict(zip(fields, values, strict=True))
        if trend_candidate(series):
            candidates.append({"deelreeks_sleutel": series["deelreeks_sleutel"],
                               "analyse_type_code": series["analyse_type_code"]})
    return {"bronregels": parent, "periode": f"{first_year}-{last_year}",
            "dubbel_bronlabel": dual_labels, "per_centrale_groep": groups,
            "mogelijke_trendreeksen": candidates,
            "betekenis": "Alleen reeksbeoordeling; geen selectie van bronrecords of doeltabellen",
            "levende_database_gewijzigd": False}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preflight", action="store_true",
                        help="alleen-lezen reeksinventarisatie; geen migratie")
    parser.add_argument("--apply", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.apply:
        parser.error("De brede NDFF-soortgroepmigratie is vervallen; dit script wijzigt geen database")
    if not args.preflight:
        parser.error("Alleen --preflight is beschikbaar; er bestaat geen breed migratieplan")
    print(json.dumps(preflight(), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
