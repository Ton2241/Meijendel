#!/usr/bin/env python3
"""Maak reproduceerbare soortdiagrammen voor Meijendel, 1950-2025."""

from __future__ import annotations

import argparse
import csv
import html
import json
import subprocess
from collections import defaultdict
from pathlib import Path


MYSQL = "/usr/local/mysql/bin/mysql"
GROEP_VOLGORDE = [
    "vogels",
    "Vaatplanten",
    "(korst)mossen",
    "vlinders",
    "libellen",
    "amfibieën",
    "zoogdieren",
    "vleermuizen",
    "paddenstoelen",
    "weekdieren",
]
KLEUREN = {
    "vogels": "#315d8a",
    "Vaatplanten": "#3f8f55",
    "(korst)mossen": "#789c4a",
    "vlinders": "#d4862b",
    "libellen": "#3b9bb7",
    "amfibieën": "#6b9e3e",
    "zoogdieren": "#875b3c",
    "vleermuizen": "#6c5b8f",
    "paddenstoelen": "#a85f72",
    "weekdieren": "#7a8793",
}


def vogelbronnen_voor_jaar(jaar: int) -> tuple[str, ...]:
    if jaar <= 1999:
        return ("territoria",)
    if jaar <= 2008:
        return ("territoria", "winterdagwaarnemingen")
    return ("broedvogeldagwaarnemingen", "winterdagwaarnemingen")


def normaliseer_soortgroep(soortgroep: str | None) -> str | None:
    mapping = {
        "Vaatplanten": "Vaatplanten",
        "Mossen": "(korst)mossen",
        "Korstmossen": "(korst)mossen",
        "Korstmossen|Schimmels": "(korst)mossen",
        "Dagvlinders": "vlinders",
        "Microvlinders": "vlinders",
        "Nachtvlinders": "vlinders",
        "Libellen": "libellen",
        "Amfibieën": "amfibieën",
        "Zoogdieren (overig)": "zoogdieren",
        "Zoogdieren": "zoogdieren",
        "Vleermuizen": "vleermuizen",
        "Schimmels": "paddenstoelen",
        "Weekdieren": "weekdieren",
    }
    return mapping.get(soortgroep or "")


def is_mogelijke_trendwaarneming(codes: str | None) -> bool:
    return bool({"I", "TV", "TA", "TK"} & set((codes or "").split(",")))


def sorteer_soorten(rows: list[dict], veld: str = "aantal") -> list[dict]:
    return sorted(rows, key=lambda row: (-int(row[veld]), row["soort"].casefold()))


def mysql_rows(sql: str) -> list[list[str]]:
    resultaat = subprocess.run(
        [
            MYSQL,
            "--login-path=meijendel_root",
            "--protocol=tcp",
            "--host=127.0.0.1",
            "--batch",
            "--skip-column-names",
            "--raw",
            "-e",
            sql,
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    return [regel.split("\t") for regel in resultaat.stdout.splitlines() if regel]


def sleutel(soort: str, wetenschappelijk: str | None) -> str:
    basis = wetenschappelijk if wetenschappelijk and wetenschappelijk != "NULL" else soort
    return " ".join(basis.casefold().split())


def voeg_toe(
    verzameling: dict,
    groep: str,
    soort: str,
    wetenschappelijk: str | None,
    totaal: int,
    trend: int,
    bron: str,
) -> None:
    if groep not in GROEP_VOLGORDE or not soort:
        return
    key = (groep, sleutel(soort, wetenschappelijk))
    item = verzameling.setdefault(
        key,
        {
            "soortgroep": groep,
            "soort": soort,
            "wetenschappelijke_naam": "" if wetenschappelijk in (None, "NULL") else wetenschappelijk,
            "totaal_waarnemingen": 0,
            "mogelijke_trendwaarnemingen": 0,
            "bronnen": set(),
        },
    )
    item["totaal_waarnemingen"] += int(totaal)
    item["mogelijke_trendwaarnemingen"] += int(trend)
    item["bronnen"].add(bron)


def laad_ndff_catalogus() -> tuple[dict[str, str], dict[str, str]]:
    wetenschappelijk, nederlands = {}, {}
    for groep, nl, sci in mysql_rows(
        "SELECT soortgroep_raw,COALESCE(nederlandse_naam,''),"
        "COALESCE(wetenschappelijke_naam,'') FROM Meijendel.ndff_soorten"
    ):
        if sci:
            wetenschappelijk.setdefault(sci.casefold(), groep)
        if nl:
            nederlands.setdefault(nl.casefold(), groep)
    return wetenschappelijk, nederlands


def resolveer_groep(
    raw: str | None,
    soort: str,
    wetenschappelijk: str | None,
    catalogus: tuple[dict[str, str], dict[str, str]],
) -> str | None:
    groep = normaliseer_soortgroep(raw)
    if groep:
        return groep
    sci_map, nl_map = catalogus
    bron_groep = None
    if wetenschappelijk:
        bron_groep = sci_map.get(wetenschappelijk.casefold())
    bron_groep = bron_groep or nl_map.get(soort.casefold())
    return normaliseer_soortgroep(bron_groep)


def verzamel_data() -> list[dict]:
    data: dict[tuple[str, str], dict] = {}
    catalogus = laad_ndff_catalogus()

    # Vogels: de afgesproken, niet-overlappende tijdvakken. Territoria zijn
    # aantallen territoria; dagwaarnemingen zijn aantallen waarnemingsregels.
    vogel_sql = """
      SELECT s.soort_naam, COALESCE(s.latijnse_naam,''), SUM(x.aantal)
      FROM (
        SELECT soort_id, SUM(territoria) AS aantal
        FROM Meijendel.territoria WHERE jaar BETWEEN 1958 AND 2008 GROUP BY soort_id
        UNION ALL
        SELECT soort_id, COUNT(*) AS aantal
        FROM Meijendel.dagwaarnemingen_bmp
        WHERE jaar BETWEEN 2009 AND 2025 GROUP BY soort_id
        UNION ALL
        SELECT w.soort_id, COUNT(*) AS aantal
        FROM Meijendel.dagwaarnemingen_wv w
        JOIN Meijendel.dagbezoeken_wv b ON b.bezoek_id=w.bezoek_id
        WHERE b.bezoek_datum BETWEEN '2000-09-01' AND '2025-12-31'
          AND (CASE WHEN MONTH(b.bezoek_datum)>=9 THEN YEAR(b.bezoek_datum)
                    ELSE YEAR(b.bezoek_datum)-1 END) BETWEEN 2000 AND 2025
        GROUP BY w.soort_id
      ) x JOIN Meijendel.soorten s ON s.id=x.soort_id
      GROUP BY s.id, s.soort_naam, s.latijnse_naam
    """
    for soort, sci, aantal in mysql_rows(vogel_sql):
        voeg_toe(data, "vogels", soort, sci, int(aantal), int(aantal), "VWG/SOVON")

    # Canonieke NDFF-laag: alleen ruimtelijk bruikbare records, geen PQ-records
    # en geen DAZ-records die door de primaire SOVON-download zijn vervangen.
    ndff_sql = """
      SELECT v.soortgroep_raw,
             COALESCE(NULLIF(v.nederlandse_naam,''),v.wetenschappelijke_naam),
             COALESCE(v.wetenschappelijke_naam,''), COUNT(*),
             SUM(v.protocol_kandidaattypen REGEXP '(^|,)(I|TV|TA|TK)(,|$)')
      FROM Meijendel_ndff_secure.v_ndff_analyse_record v
      WHERE v.jaar BETWEEN 1950 AND 2025
        AND v.record_selectiestatus='voorlopig_bruikbaar'
        AND NOT EXISTS (
          SELECT 1 FROM Meijendel.sovon_avimap_ndff_daz_koppeling k
          WHERE k.ndff_waarneming_id=v.open_waarneming_id
            AND k.koppelstatus IN ('sovon_vervangt_ndff_exact',
                                   'sovon_vervangt_ndff_telconflict')
        )
      GROUP BY v.soortgroep_raw, v.nederlandse_naam, v.wetenschappelijke_naam
    """
    for raw, soort, sci, totaal, trend in mysql_rows(ndff_sql):
        groep = resolveer_groep(raw, soort, sci, catalogus)
        if groep:
            voeg_toe(data, groep, soort, sci, int(totaal), int(trend), "NDFF canoniek")

    # Primaire provinciale PQ-reeks. Alleen vaatplanten, mossen en korstmossen
    # gelden hier als trendinformatie; incidentele fauna en schimmels niet.
    pq_mos_ids = {235, 236, 336, 441, 452, 619}
    pq_alg_ids = {13, 73, 88, 100, 101, 241, 242, 581}
    pq_sql = """
      SELECT t.taxon_id,t.nederlandse_naam,
             COALESCE(t.wetenschappelijke_naam_officieel,t.latijnse_naam_bron,''),
             COUNT(*)
      FROM Meijendel.pq_vegetatie_waarneming w
      JOIN Meijendel.pq_vegetatie_opname o ON o.opname_id=w.opname_id
      JOIN Meijendel.pq_vegetatie_taxon t ON t.taxon_id=w.taxon_id
      WHERE o.jaar BETWEEN 1950 AND 2025
      GROUP BY t.taxon_id,t.nederlandse_naam,
               COALESCE(t.wetenschappelijke_naam_officieel,t.latijnse_naam_bron,'')
    """
    for taxon_id, soort, sci, aantal in mysql_rows(pq_sql):
        groep = resolveer_groep(None, soort, sci, catalogus)
        tid = int(taxon_id)
        if not groep and tid in pq_mos_ids:
            groep = "(korst)mossen"
        elif not groep and tid not in pq_alg_ids:
            # De resterende ongekoppelde PQ-taxa zijn vaatplanttaxa of
            # combinaties daarvan; algen en administratieve lagen vallen weg.
            groep = "Vaatplanten"
        if groep:
            trend = int(aantal) if groep in {"Vaatplanten", "(korst)mossen"} else 0
            voeg_toe(data, groep, soort, sci, int(aantal), trend, "Provincie Zuid-Holland PQ")

    # Primaire SOVON-bijvangsten; doelsoorten van DAZ zijn mogelijke
    # trendwaarnemingen, overige bijvangsten uitsluitend positieve meldingen.
    sovon_sql = """
      SELECT soortgroep_naam,nederlandse_naam,COALESCE(wetenschappelijke_naam,''),
             gegevensrol,COUNT(*)
      FROM Meijendel.v_sovon_avimap_niet_vogel_analyse
      WHERE jaar BETWEEN 1950 AND 2025
      GROUP BY soortgroep_naam,nederlandse_naam,wetenschappelijke_naam,gegevensrol
    """
    for raw, soort, sci, rol, aantal in mysql_rows(sovon_sql):
        groep = resolveer_groep(raw, soort, sci, catalogus)
        if groep:
            trend = int(aantal) if rol == "daz_doelsoort" else 0
            voeg_toe(data, groep, soort, sci, int(aantal), trend, "SOVON Avimap")

    uitvoer = []
    for item in data.values():
        item["bronnen"] = "; ".join(sorted(item["bronnen"]))
        uitvoer.append(item)
    return uitvoer


def schrijf_csv(rows: list[dict], pad: Path) -> None:
    velden = [
        "soortgroep",
        "soort",
        "wetenschappelijke_naam",
        "totaal_waarnemingen",
        "mogelijke_trendwaarnemingen",
        "bronnen",
    ]
    with pad.open("w", encoding="utf-8", newline="") as bestand:
        schrijver = csv.DictWriter(bestand, fieldnames=velden)
        schrijver.writeheader()
        schrijver.writerows(
            sorted(rows, key=lambda r: (GROEP_VOLGORDE.index(r["soortgroep"]), r["soort"].casefold()))
        )


def aggregeer_soortgroepen(rows: list[dict]) -> list[dict]:
    groepen: dict[str, dict] = {}
    for row in rows:
        groep = row["soortgroep"]
        item = groepen.setdefault(
            groep,
            {
                "soortgroep": groep,
                "totaal_waarnemingen": 0,
                "mogelijke_trendwaarnemingen": 0,
                "aantal_taxa": 0,
            },
        )
        item["totaal_waarnemingen"] += int(row["totaal_waarnemingen"])
        item["mogelijke_trendwaarnemingen"] += int(row["mogelijke_trendwaarnemingen"])
        item["aantal_taxa"] += 1
    return [groepen[g] for g in GROEP_VOLGORDE if g in groepen]


def schrijf_groep_csv(rows: list[dict], pad: Path) -> None:
    velden = [
        "soortgroep",
        "totaal_waarnemingen",
        "mogelijke_trendwaarnemingen",
        "aantal_taxa",
    ]
    with pad.open("w", encoding="utf-8", newline="") as bestand:
        schrijver = csv.DictWriter(bestand, fieldnames=velden)
        schrijver.writeheader()
        schrijver.writerows(rows)


def _diagram_svg(rows: list[dict], veld: str) -> str:
    rows = sorted(rows, key=lambda row: (-int(row[veld]), row["soortgroep"].casefold()))
    breedte = 1320
    hoogte, boven, plot_h = 610, 48, 430
    maximum = max(int(row[veld]) for row in rows) if rows else 1
    bar_stap = (breedte - 120) / max(len(rows), 1)
    bar_breedte = min(72, bar_stap * 0.68)
    onderdelen = [
        f'<svg viewBox="0 0 {breedte} {hoogte}" width="100%" height="{hoogte}" '
        'style="min-width:1050px" role="img">'
    ]
    for stap in range(6):
        waarde = maximum * stap / 5
        y = boven + plot_h - (plot_h * stap / 5)
        onderdelen.append(f'<line x1="82" y1="{y:.1f}" x2="{breedte-8}" y2="{y:.1f}" class="grid"/>')
        onderdelen.append(f'<text x="76" y="{y+4:.1f}" text-anchor="end" class="tick">{waarde:,.0f}</text>')
    for index, row in enumerate(rows):
        x = 92 + index * bar_stap + (bar_stap - bar_breedte) / 2
        aantal = int(row[veld])
        bar_h = plot_h * aantal / maximum
        y = boven + plot_h - bar_h
        titel = html.escape(f'{row["soortgroep"]}: {aantal:,}')
        label = html.escape(row["soortgroep"])
        kleur = KLEUREN[row["soortgroep"]]
        onderdelen.append(
            f'<rect x="{x:.2f}" y="{y:.2f}" width="{bar_breedte:.2f}" height="{bar_h:.2f}" fill="{kleur}">'
            f"<title>{titel}</title></rect>"
        )
        onderdelen.append(
            f'<text x="{x + bar_breedte/2:.2f}" y="{max(y-8, 18):.2f}" text-anchor="middle" '
            f'class="value">{aantal:,}</text>'
        )
        onderdelen.append(
            f'<text x="{x + bar_breedte/2:.2f}" y="{boven+plot_h+26}" text-anchor="middle" '
            f'class="group">{label}</text>'
        )
    onderdelen.append("</svg>")
    return "".join(onderdelen)


def maak_html(rows: list[dict]) -> str:
    groepen = aggregeer_soortgroepen(rows)
    totaal = sum(int(r["totaal_waarnemingen"]) for r in groepen)
    trend = sum(int(r["mogelijke_trendwaarnemingen"]) for r in groepen)
    tabel_rows = "".join(
        "<tr>"
        f'<td>{html.escape(r["soortgroep"])}</td>'
        f'<td>{r["aantal_taxa"]:,}</td>'
        f'<td>{r["totaal_waarnemingen"]:,}</td>'
        f'<td>{r["mogelijke_trendwaarnemingen"]:,}</td></tr>'
        for r in sorted(groepen, key=lambda x: -x["totaal_waarnemingen"])
    )
    return f"""<!doctype html>
<html lang="nl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>Waarnemingen per soortgroep in Meijendel, 1950–2025</title>
<style>
body{{font-family:system-ui,-apple-system,sans-serif;margin:0;background:#f5f3ec;color:#20251f}}
main{{max-width:1500px;margin:auto;padding:28px}} h1{{margin-bottom:6px}} h2{{margin-top:34px}}
.note{{max-width:1050px;line-height:1.5}} .summary{{display:flex;gap:14px;flex-wrap:wrap;margin:18px 0}}
.card{{background:white;border:1px solid #d7d5cc;border-radius:10px;padding:12px 16px}}
.scroll{{overflow-x:auto;background:white;border:1px solid #d7d5cc;border-radius:10px}}
.grid{{stroke:#deded8;stroke-width:1}} .tick{{font-size:11px;fill:#555}} .group{{font-size:13px;fill:#292929}} .value{{font-size:12px;fill:#292929}}
table{{border-collapse:collapse;width:100%;background:white;font-size:14px}} th,td{{padding:7px 9px;border-bottom:1px solid #ddd;text-align:left}}
th{{position:sticky;top:0;background:#ecebe4}} td:nth-child(4),td:nth-child(5){{text-align:right}}
.tablewrap{{max-height:560px;overflow:auto;border:1px solid #d7d5cc;border-radius:10px}}
</style></head><body><main>
<h1>Waarnemingen per soortgroep in Meijendel</h1>
<p class="note">Periode 1950–2025. Iedere balk is één van de tien geselecteerde soortgroepen; de balken staan van hoog naar laag. De provinciale PQ-reeks en de primaire SOVON-bijvangsten vervangen hun NDFF-tegenhangers, zodat bekende dubbeltellingen zijn voorkomen.</p>
<div class="summary"><div class="card"><b>{totaal:,}</b><br>waarnemingen in totaal</div><div class="card"><b>{trend:,}</b><br>(mogelijke) trendwaarnemingen</div><div class="card"><b>{len(rows):,}</b><br>soorten/taxa</div></div>
<h2>1. Alle geselecteerde waarnemingen</h2><div class="scroll">{_diagram_svg(groepen, 'totaal_waarnemingen')}</div>
<h2>2. Waarnemingen met classificatie ‘mogelijke trendwaarneming’</h2>
<p class="note">Vogels gelden als gevalideerd. Bij andere soortgroepen betekent dit dat protocol of primaire bron trendanalyse in beginsel ondersteunt; aanvullende validatie van meeteenheid, bezoeken en nullen kan nog nodig zijn.</p>
<div class="scroll">{_diagram_svg(groepen, 'mogelijke_trendwaarnemingen')}</div>
<h2>Exacte aantallen per soortgroep</h2>
<div class="tablewrap"><table><thead><tr><th>Soortgroep</th><th>Soorten/taxa</th><th>Totaal</th><th>Mogelijke trend</th></tr></thead><tbody>{tabel_rows}</tbody></table></div>
</main></body></html>"""


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("outputs/ndff_soortwaarnemingen_1950_2025"),
    )
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    rows = verzamel_data()
    csv_pad = args.output_dir / "waarnemingen_per_soort_1950_2025.csv"
    groep_csv_pad = args.output_dir / "waarnemingen_per_soortgroep_1950_2025.csv"
    html_pad = args.output_dir / "waarnemingen_per_soortgroep_1950_2025.html"
    schrijf_csv(rows, csv_pad)
    groepen = aggregeer_soortgroepen(rows)
    schrijf_groep_csv(groepen, groep_csv_pad)
    html_inhoud = maak_html(rows)
    html_pad.write_text(html_inhoud, encoding="utf-8")
    # Houd de eerder gedeelde bestandslink geldig, maar toon daar eveneens de
    # gecorrigeerde grafieken per soortgroep.
    (args.output_dir / "waarnemingen_per_soort_1950_2025.html").write_text(
        html_inhoud, encoding="utf-8"
    )
    metadata = {
        "periode": "1950-2025",
        "soorten_taxa": len(rows),
        "soortgroepen": len(groepen),
        "totaal_waarnemingen": sum(r["totaal_waarnemingen"] for r in rows),
        "mogelijke_trendwaarnemingen": sum(r["mogelijke_trendwaarnemingen"] for r in rows),
        "vogelregels": {
            "1958-1999": "territoria",
            "2000-2008": "territoria plus winterdagwaarnemingen; winter toegekend aan startjaar",
            "2009-2025": "broedvogeldagwaarnemingen plus winterdagwaarnemingen; geen territoria",
        },
    }
    (args.output_dir / "metadata.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(metadata, ensure_ascii=False))


if __name__ == "__main__":
    main()
