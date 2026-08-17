#!/usr/bin/env python3
"""Audit NDFF-protocollen per FFV-soortgroep zonder de life-database te wijzigen.

De audit beoordeelt wat uit de FFV-waarnemingsregels zelf kan worden afgeleid.
Een protocolnaam maakt een losse waarnemingsregel niet automatisch geschikt voor
trendberekening: daarvoor zijn ook volledige bezoeken, inspanning en afleidbare
nulwaarnemingen nodig.
"""

from __future__ import annotations

import argparse
import csv
import html
import json
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from osgeo import ogr


SOURCE_URLS = {
    "ndff_bijsluiter": "https://ndff.nl/natuurdata/bijsluiter/",
    "ndff_ffv": "https://ndff.nl/natuurdata/afnemen-en-gebruiken/flora-fauna-verkenner/",
    "ndff_protocollen": "https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/",
    "ndff_protocolaantallen": "https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/overzicht-waarnemingen-via-protocol/",
    "cbs_nem_2025": "https://longreads.cbs.nl/meetprogrammas-flora-en-fauna-2025/meetprogrammas/",
    "cbs_nem_beoordeling": "https://longreads.cbs.nl/meetprogrammas-flora-en-fauna-2025/kwaliteitsbeoordeling/",
    "ndff_amfibieen_01_201": "https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/1-201-monitoring-van-amfibieen-in-nederland-2001-nem/",
    "ndff_vlinders_03_201": "https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/03-201-vlinderstichting-handleiding-landelijk-meetnet-vlinders/",
    "ndff_libellen_07_201": "https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/7-201-landelijk-meetnet-libellen-nem/",
    "ndff_vegetatie_12_007": "https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/12-007-vegetatieopname/",
    "ndff_flora_12_202": "https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/12-202-landelijk-meetnet-flora-milieu-en-natuurkwaliteit/",
    "ndff_flora_12_211": "https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/12-211-landelijk-meetnet-flora-aandachtssoorten-lmf-a/",
    "ndff_vleermuizen_17_208": "https://ndff.nl/natuurdata/waarnemen-en-aanleveren/protocollen/17-208-vleermuistransecttelling-nem/",
    "ndff_zoogdieren_17_204": "https://ndff.nl/?p=868",
}


# Protocollen waarvan de beheerder een herhaald, doelgericht meetnet beschrijft.
# De FFV-export bevat echter niet de volledige bezoek-/inspanningstabel; daarom
# zijn dit kandidaten om de oorspronkelijke meetnetdata op te vragen, geen
# direct trendklare FFV-records.
TARGET_MONITORING: dict[str, set[str]] = {
    "Amfibieen": {"01.201", "13.202"},
    "Dagvlinders": {"03.201"},
    "Korstmossen": {"02.202", "02.203"},
    "Libellen": {"07.201"},
    "Mossen": {"02.203", "02.204"},
    "Nachtvlinders": {"03.203"},
    "Reptielen": {"10.201"},
    "Schimmels": {"11.201", "11.202", "11.204"},
    "Vaatplanten": {"12.202", "12.204", "12.211"},
    "Vissen": {"13.201", "13.202"},
    "Vleermuizen": {"17.201", "17.202", "17.208", "17.210"},
    "Weekdieren": {"04.006"},
    "Zoogdieren (overig)": {"17.204", "17.207", "17.209"},
}

PQ_RISK_PREFIXES = {"12.007", "12.202"}
AREA_MONITORING_PREFIXES = {"12.205"}
HISTORICAL_PREFIXES = {"12.004", "104.000", "105.000", "17.005", "17.006"}
OPPORTUNISTIC_PREFIXES = {"102.004", "102.006"}


def protocol_code(protocol: str) -> str:
    return protocol.split(maxsplit=1)[0] if protocol and protocol != "(leeg)" else ""


def ogr_rows(dataset: ogr.DataSource, sql: str) -> list[dict[str, Any]]:
    layer = dataset.ExecuteSQL(sql, dialect="SQLITE")
    if layer is None:
        raise RuntimeError("OGR-SQL leverde geen resultaat op")
    try:
        definition = layer.GetLayerDefn()
        fields = [definition.GetFieldDefn(i).GetName() for i in range(definition.GetFieldCount())]
        return [{field: feature.GetField(field) for field in fields} for feature in layer]
    finally:
        dataset.ReleaseResultSet(layer)


def classify_protocol(group: str, protocol: str) -> tuple[str, str]:
    code = protocol_code(protocol)
    if code in PQ_RISK_PREFIXES and group in {
        "Vaatplanten", "Mossen", "Korstmossen", "Kranswieren, wieren en algen"
    }:
        return (
            "PQ-overlap eerst uitsluiten",
            "Mogelijk dezelfde bronopname als de bestaande PQ-reeks; niet als zelfstandige telling gebruiken.",
        )
    if code in TARGET_MONITORING.get(group, set()):
        return (
            "Doelgericht meetnet - brondata opvragen",
            "Protocol is inhoudelijk kansrijk, maar FFV mist volledige bezoeken, inspanning en afleidbare nullen.",
        )
    if code in AREA_MONITORING_PREFIXES:
        return (
            "Gebiedsmonitoring - brondata opvragen",
            "Kansrijk voor periodieke toestand/beheeranalyse; niet zonder meetronde- en inspanningsmetadata als jaartrend gebruiken.",
        )
    if protocol == "Losse waarnemingen" or code in OPPORTUNISTIC_PREFIXES or protocol == "(leeg)":
        return (
            "Alleen verspreidingscontext",
            "Aanwezigheidssignaal zonder gestandaardiseerde afwezigheid of inspanningsnoemer.",
        )
    if code in HISTORICAL_PREFIXES:
        return (
            "Historische context",
            "Geschikt voor historische verspreidingscontext, niet voor vergelijkbare populatietrends.",
        )
    return (
        "Gestructureerde context",
        "Protocol geeft meer herkomstinformatie, maar trendgeschiktheid is uit de FFV-regel alleen niet aantoonbaar.",
    )


def group_advice(group: str, class_counts: dict[str, int], records: int) -> tuple[str, str]:
    target = class_counts.get("Doelgericht meetnet - brondata opvragen", 0)
    area = class_counts.get("Gebiedsmonitoring - brondata opvragen", 0)
    pq = class_counts.get("PQ-overlap eerst uitsluiten", 0)
    if pq:
        return (
            "Voorwaardelijk; PQ-blokkade",
            "Houd PQ-gerelateerde regels buiten de life-tabellen. Audit eerst opname-identiteit; vraag voor andere meetnetten volledige brondata op.",
        )
    if target:
        return (
            "Kansrijk na brondata",
            "Vraag de complete meetbezoeken, inspanning, telobjecten en nullen op; importeer pas na volledigheids- en ruimtelijke controle.",
        )
    if area:
        return (
            "Kansrijk voor periodieke gebiedstoestand",
            "Vraag volledige SNL-meetronden en telobjecten op; niet als jaarlijkse populatietrend behandelen.",
        )
    return (
        "Niet opnemen voor trends",
        "Bewaar uitsluitend in externe staging als verspreidingscontext; geen opname in de wetenschappelijke life-analysetabellen.",
    )


def analyse(staging: Path) -> dict[str, Any]:
    ogr.UseExceptions()
    dataset = ogr.Open(str(staging), 0)
    if dataset is None:
        raise RuntimeError(f"Kon stagingdataset niet openen: {staging}")

    protocol_rows = ogr_rows(
        dataset,
        r'''
        WITH first_group AS (
          SELECT p.staging_fid,b.aanvraag_soortgroep
          FROM ndff_waarneming_bron p JOIN ndff_bronbestanden b USING(bestand_id)
          WHERE p.is_eerste=1
        )
        SELECT f.aanvraag_soortgroep AS soortgroep,
               COALESCE(NULLIF(TRIM(w.Protocol),''),'(leeg)') AS protocol,
               COUNT(*) AS records,
               COUNT(DISTINCT w."Wetenschappelijke naam") AS taxa,
               SUM(w.vervaagd) AS vervaagd,
               SUM(CASE WHEN w.vervaagd=0 AND ST_Area(w.geom)<1000000 THEN 1 ELSE 0 END) AS plotkandidaat,
               SUM(CASE WHEN julianday(w."Periode stop")-julianday(w."Periode start")<=1 THEN 1 ELSE 0 END) AS korte_datum,
               SUM(CASE WHEN CAST(substr(w."Periode start",1,4) AS INT)<1950 THEN 1 ELSE 0 END) AS voor_1950,
               MIN(CAST(substr(w."Periode start",1,4) AS INT)) AS eerste_jaar,
               MAX(CAST(substr(w."Periode start",1,4) AS INT)) AS laatste_jaar,
               COUNT(DISTINCT w.Bronhouder) AS bronhouders
        FROM ndff_waarnemingen w JOIN first_group f USING(staging_fid)
        GROUP BY f.aanvraag_soortgroep,protocol
        ORDER BY f.aanvraag_soortgroep,records DESC
        ''',
    )
    dataset = None

    grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in protocol_rows:
        category, reason = classify_protocol(row["soortgroep"], row["protocol"])
        row["auditklasse"] = category
        row["motivering"] = reason
        grouped[row["soortgroep"]].append(row)

    group_rows: list[dict[str, Any]] = []
    for group, rows in sorted(grouped.items()):
        total = sum(row["records"] for row in rows)
        classes: dict[str, int] = defaultdict(int)
        for row in rows:
            classes[row["auditklasse"]] += row["records"]
            row["aandeel_groep_pct"] = round(100 * row["records"] / total, 2)
            row["vervaagd_pct"] = round(100 * row["vervaagd"] / row["records"], 2)
            row["plotkandidaat_pct"] = round(100 * row["plotkandidaat"] / row["records"], 2)
            row["korte_datum_pct"] = round(100 * row["korte_datum"] / row["records"], 2)
        decision, action = group_advice(group, classes, total)
        dominant = sorted(rows, key=lambda row: row["records"], reverse=True)[:3]
        group_rows.append(
            {
                "soortgroep": group,
                "records": total,
                "protocollen": len(rows),
                "doelgericht_meetnet_records": classes.get("Doelgericht meetnet - brondata opvragen", 0),
                "doelgericht_meetnet_pct": round(100 * classes.get("Doelgericht meetnet - brondata opvragen", 0) / total, 2),
                "gebiedsmonitoring_records": classes.get("Gebiedsmonitoring - brondata opvragen", 0),
                "pq_risico_records": classes.get("PQ-overlap eerst uitsluiten", 0),
                "context_records": total
                - classes.get("Doelgericht meetnet - brondata opvragen", 0)
                - classes.get("Gebiedsmonitoring - brondata opvragen", 0)
                - classes.get("PQ-overlap eerst uitsluiten", 0),
                "dominante_protocollen": "; ".join(
                    f'{row["protocol"]} ({row["aandeel_groep_pct"]:.2f}%)' for row in dominant
                ),
                "advies": decision,
                "vervolgactie": action,
            }
        )

    totals = {
        "records": sum(row["records"] for row in group_rows),
        "groepen": len(group_rows),
        "protocolnamen": len({row["protocol"] for row in protocol_rows}),
        "doelgericht_meetnet_records": sum(row["doelgericht_meetnet_records"] for row in group_rows),
        "gebiedsmonitoring_records": sum(row["gebiedsmonitoring_records"] for row in group_rows),
        "pq_risico_records": sum(row["pq_risico_records"] for row in group_rows),
        "voor_1950_records": sum(row["voor_1950"] for row in protocol_rows),
    }
    totals["doelgericht_meetnet_pct"] = round(
        100 * totals["doelgericht_meetnet_records"] / totals["records"], 2
    )
    totals["gebiedsmonitoring_pct"] = round(
        100 * totals["gebiedsmonitoring_records"] / totals["records"], 2
    )
    totals["pq_risico_pct"] = round(100 * totals["pq_risico_records"] / totals["records"], 2)
    return {
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "staging_file": staging.name,
        "scope": "FFV-aanvragen 1950-2025, alle niet-vogelsoortgroepen, unieke Identiteit",
        "sources": SOURCE_URLS,
        "totals": totals,
        "groups": group_rows,
        "protocols": protocol_rows,
        "decision_rule": (
            "Geen enkele afzonderlijke FFV-waarnemingsregel is direct trendklaar. "
            "Doelgerichte meetnetprotocollen zijn alleen kandidaten voor opname nadat "
            "de volledige brondata met telobject, bezoek, inspanning en afleidbare nullen "
            "zijn verkregen en gevalideerd."
        ),
    }


def write_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    if not rows:
        return
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def fmt_int(value: int) -> str:
    return f"{value:,}".replace(",", ".")


def render_html(result: dict[str, Any]) -> str:
    totals = result["totals"]
    group_rows = "\n".join(
        "<tr>"
        f"<td><strong>{html.escape(row['soortgroep'])}</strong></td>"
        f"<td class='num'>{fmt_int(row['records'])}</td>"
        f"<td class='num'>{row['doelgericht_meetnet_pct']:.2f}%</td>"
        f"<td>{html.escape(row['dominante_protocollen'])}</td>"
        f"<td><span class='tag'>{html.escape(row['advies'])}</span><br>{html.escape(row['vervolgactie'])}</td>"
        "</tr>"
        for row in result["groups"]
    )
    protocol_rows = "\n".join(
        "<tr>"
        f"<td>{html.escape(row['soortgroep'])}</td>"
        f"<td>{html.escape(row['protocol'])}</td>"
        f"<td class='num'>{fmt_int(row['records'])}</td>"
        f"<td class='num'>{row['aandeel_groep_pct']:.2f}%</td>"
        f"<td class='num'>{row['vervaagd_pct']:.2f}%</td>"
        f"<td>{html.escape(row['auditklasse'])}</td>"
        f"<td>{html.escape(row['motivering'])}</td>"
        "</tr>"
        for row in result["protocols"]
    )
    sources = "\n".join(
        f'<li><a href="{html.escape(url)}">{html.escape(label.replace("_", " ").title())}</a></li>'
        for label, url in result["sources"].items()
    )
    return f"""<!doctype html>
<html lang="nl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>NDFF-protocolaudit Meijendel 1950-2025</title>
<style>
:root{{--ink:#17211d;--muted:#5c6a63;--line:#d8e1dc;--green:#176b4d;--pale:#edf6f1;--amber:#8a5a00}}
*{{box-sizing:border-box}} body{{margin:0;background:#f6f8f6;color:var(--ink);font:15px/1.5 system-ui,-apple-system,sans-serif}}
main{{max-width:1240px;margin:auto;padding:36px 24px 72px}} h1{{font-size:2.25rem;line-height:1.1;margin:.2em 0}} h2{{margin-top:2em}}
.lead{{font-size:1.1rem;max-width:900px}} .notice{{background:#fff5d9;border-left:5px solid #d49300;padding:16px 18px;margin:24px 0}}
.cards{{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px;margin:24px 0}} .card{{background:white;border:1px solid var(--line);border-radius:10px;padding:16px}}
.card b{{display:block;font-size:1.65rem;color:var(--green)}} .card span{{color:var(--muted)}}
.tablewrap{{overflow:auto;background:white;border:1px solid var(--line);border-radius:10px}} table{{width:100%;border-collapse:collapse;min-width:900px}}
th,td{{text-align:left;vertical-align:top;padding:10px;border-bottom:1px solid var(--line)}} th{{position:sticky;top:0;background:var(--pale);z-index:1}} td.num{{text-align:right;white-space:nowrap}}
.tag{{display:inline-block;color:var(--green);font-weight:700}} details{{margin-top:24px}} a{{color:#175e82}} footer{{margin-top:36px;color:var(--muted)}}
@media(max-width:760px){{.cards{{grid-template-columns:1fr 1fr}} main{{padding:22px 14px}}}}
</style></head><body><main>
<p>Vereniging Vogelwerkgroep Meijendel · technische audit</p>
<h1>NDFF-protocolaudit per soortgroep</h1>
<p class="lead">Beoordeling van {fmt_int(totals['records'])} unieke niet-vogelwaarnemingen uit de geïntegreerde FFV-stagingdataset. De audit scheidt aanwezigheidssignalen, historische bronnen, PQ-risico en kansrijke meetnetten.</p>
<div class="notice"><strong>Hoofdconclusie.</strong> Geen enkele FFV-waarnemingsregel is op zichzelf trendklaar. Alleen records uit een passend doelgericht meetnet zijn kandidaat, en pas nadat volledige telbezoeken, telobjecten, inspanning en afleidbare nulwaarnemingen bij de bron zijn verkregen. PQ-gerelateerde records blijven geblokkeerd.</div>
<div class="cards">
<div class="card"><b>{totals['groepen']}</b><span>FFV-soortgroepen</span></div>
<div class="card"><b>{totals['protocolnamen']}</b><span>protocolnamen</span></div>
<div class="card"><b>{totals['doelgericht_meetnet_pct']:.2f}%</b><span>kandidaat-doelmeetnet</span></div>
<div class="card"><b>{totals['pq_risico_pct']:.2f}%</b><span>PQ-overlap eerst auditen</span></div>
</div>
<h2>Advies per soortgroep</h2>
<p>“Kansrijk” betekent: volledige brondata opvragen en opnieuw toetsen. Het betekent niet dat de huidige FFV-regels mogen worden gebruikt voor trends.</p>
<div class="tablewrap"><table><thead><tr><th>Soortgroep</th><th>Records</th><th>Doelmeetnet</th><th>Dominante protocollen</th><th>Besluit en actie</th></tr></thead><tbody>{group_rows}</tbody></table></div>
<h2>Wetenschappelijke toelatingsregel</h2>
<ol><li><strong>Niet rechtstreeks importeren:</strong> losse waarnemingen, ObsIdentify, collecties, literatuur en atlasrecords.</li>
<li><strong>Alleen context:</strong> nauwkeurige gevalideerde aanwezigheid kan buiten de life-analysetabellen als externe verspreidingslaag blijven.</li>
<li><strong>Brondata opvragen:</strong> bij passende NEM-, SNL- of andere doelmeetnetten zijn complete bezoek- en inspanningsgegevens nodig.</li>
<li><strong>PQ-blokkade:</strong> Vegetatieopnamen en LMF-M&amp;N eerst koppelen aan de bestaande PQ-opnamen; geen aanvullende PQ-reeks creëren.</li>
<li><strong>Pas daarna import:</strong> alleen telobjecten binnen de vastgestelde SOVON-plots, met protocolversie, bezoek, inspanning, detectie/nul en ruimtelijke kwaliteitsklasse.</li></ol>
<h2>Waarom protocolnaam alleen onvoldoende is</h2>
<p>De NDFF beschrijft protocollen als gestandaardiseerde telmethoden, maar vermeldt ook dat bruikbare nulwaarnemingen alleen uit sterke protocollen met goede metadata afleidbaar zijn en beperkt toegankelijk zijn. De FFV levert waarnemingsregels, niet automatisch de volledige bemonsteringsgebeurtenis. CBS beoordeelt NEM-kwaliteit bovendien per meetprogramma en meetdoel; landelijke trendkwaliteit kan niet zonder meer worden vertaald naar een lokale Meijendeltrend.</p>
<details><summary><strong>Volledige protocolmatrix ({len(result['protocols'])} combinaties)</strong></summary>
<div class="tablewrap"><table><thead><tr><th>Soortgroep</th><th>Protocol</th><th>Records</th><th>Aandeel groep</th><th>Vervaagd</th><th>Auditklasse</th><th>Motivering</th></tr></thead><tbody>{protocol_rows}</tbody></table></div></details>
<h2>Bronnen</h2><ul>{sources}</ul>
<footer>Gegenereerd {html.escape(result['created_utc'])}. Reproduceerbaar met gis/scripts/analyse_ndff_protocollen.py. Geen wijziging aan de life Meijendel-database.</footer>
</main></body></html>"""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--staging", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    result = analyse(args.staging)
    (args.output_dir / "ndff_protocolaudit_resultaten.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    write_csv(args.output_dir / "ndff_protocolaudit_soortgroepen.csv", result["groups"])
    write_csv(args.output_dir / "ndff_protocolaudit_protocolmatrix.csv", result["protocols"])
    (args.output_dir / "ndff_protocolaudit_meijendel_1950_2025.html").write_text(
        render_html(result), encoding="utf-8"
    )
    print(json.dumps({"output_dir": str(args.output_dir), **result["totals"]}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
