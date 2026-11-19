#!/usr/bin/env python3
"""Build the shared local group preview from a verified, frozen candidate."""
import argparse
import csv
import hashlib
import html
import json
from collections import Counter
from pathlib import Path

PERIODS = {"pre": "1958–1983", "post": "1984–2026"}
STATUSES = {
    "buiten_deze_gerichte_validatie": "Geen afzonderlijke trend beoordeeld in deze proef",
    "voldoet_aan_lokale_validatie": "Periodetrend voldoet aan de lokale toets",
    "onvoldoende_steun_voor_periodetrend": "Onvoldoende steun voor een periodetrend",
}
EXPECTED = {
    ("100", "pre"): ("kaveltoets", "stabiel_bootstrapteken"),
    ("400", "pre"): ("kaveltoets", "stabiel_bootstrapteken", "stabiel_zonder_een_soort"),
    ("900", "pre"): ("kaveltoets",),
    ("100", "post"): ("kaveltoets",),
    ("700", "post"): ("kaveltoets", "stabiel_zonder_een_soort"),
    ("800", "post"): ("kaveltoets", "stabiel_zonder_een_soort"),
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_rows(path):
    with path.open(encoding="utf-8", newline="") as stream:
        return list(csv.DictReader(stream))


def key(row):
    return row["groep"], row["periode"]


def table(table_id, headings, rows):
    cells = "".join(f"<th scope=\"col\">{html.escape(name)}</th>" for name in headings)
    return f'<div class="table-scroll"><table id="{table_id}"><thead><tr>{cells}</tr></thead><tbody>{"".join(rows)}</tbody></table></div>'


def td(value):
    return f"<td>{html.escape(value)}</td>"


def percentage(value):
    return f"{float(value):+.1f}%".replace(".", ",").replace("-", "−")


def make_preview(source, output):
    candidate_file = source / "kandidaatmanifest.json"
    candidate = json.loads(candidate_file.read_text())
    source_hash = candidate["bron_sha256"]
    if candidate["hoofdindex"] != "aantalsindex" or candidate["productievrijgave"] is not False:
        raise ValueError("Een diagnostische aantalsindexkandidaat is vereist.")
    names = ("hoofdindex-per-jaar.csv", "groepen-18.csv", "soorten-156.csv", "groepsleden-per-periode.csv")
    for name in names:
        if sha(source / name) != candidate["bestanden"][name]:
            raise ValueError(f"Controlegetal wijkt af voor {name}.")
    annual, groups, species, members = (read_rows(source / name) for name in names)
    group_names = {row["groep"]: row["naam"] for row in groups}
    ids = {row["soort_id"] for row in species}
    group_keys = {(g, period) for g in group_names for period in PERIODS}
    group_rows = {key(row): row for row in groups}
    failure = {key(row): tuple(row["redenen"].split(" | ")) for row in groups if row["redenen"]}
    member_keys = {(r["groep"], r["periode"], r["soort_id"]) for r in members}
    species_keys = {(group, period, r["soort_id"]) for r in species
                    for group in r["evg_hoofdcodes"].split(" | ") if group for period in PERIODS}
    expected_years = {(group, period, year) for group, period in group_keys
                      for year in (range(1958, 1984) if period == "pre" else range(1984, 2027))}
    if (len(group_names) != 9 or len(groups) != 18 or set(group_rows) != group_keys
            or len(annual) != 621 or {(r["groep"], r["periode"], int(r["jaar"])) for r in annual} != expected_years
            or len(species) != 156 or len(ids) != 156 or sum(not r["evg_hoofdcodes"] for r in species) != 9
            or len(member_keys) != len(members) or member_keys != species_keys or failure != EXPECTED
            or any(r["volledig"] != "2000" for r in groups)):
        raise ValueError("De inventaris, dekking of groepsstatus wijkt af van de gevalideerde kandidaat.")
    status = {k: "Onvoldoende steun voor de richting" if k in failure else "Richting ondersteund" for k in group_keys}
    reasons = {}
    for group_id, row in group_rows.items():
        if row["richtingstatus"] != ("richting_onvoldoende_ondersteund" if group_id in failure else "richting_ondersteund"):
            raise ValueError("Richtingstatus wijkt af van de toetsredenen.")
        messages = {
            "kaveltoets": f"Beter dan een vlakke lijn in {row['kaveltoets_beter']} van 5 kaveltoetsen. Vereist zijn er minstens 4.",
            "stabiel_bootstrapteken": "Het centrale bootstrapbereik van de verandering bevat nul.",
            "stabiel_zonder_een_soort": "De richting draait om bij het afzonderlijk weglaten van één soort.",
        }
        reasons[group_id] = " ".join(messages[code] for code in failure.get(group_id, ()))
    overview = table("groups", ("Ecologische groep", "Periode", "Verandering", "Beoordeling"), [
        f'<tr data-group="{g}" data-period="{p}" data-supported="{str((g,p) not in failure).lower()}">'
        + td(group_names[g]) + td(PERIODS[p]) + td(percentage(row["netto_pct"]))
        + f'<td><strong>{status[g,p]}</strong>{html.escape(" " + reasons[g,p])}</td></tr>'
        for (g, p), row in sorted(group_rows.items(), key=lambda item: (item[0][1] == "post", item[0][0]))
    ])
    roster = table("birds", ("Soort", "Ecologische indeling", *PERIODS.values()), [
        f'<tr data-species="{int(r["soort_id"])}">'
        + td(r["soort_naam"]) + td(r["ecologische_groepen"] or "Geen ecologische groep toegewezen")
        + td(STATUSES[r["pre_status"]]) + td(STATUSES[r["post_status"]]) + "</tr>"
        for r in species
    ])
    chart = {}
    for row in annual:
        g, p = key(row)
        chart.setdefault(f"{g}-{p}", []).append([int(row["jaar"]), float(row["index_aantal"])])
    embedded = json.dumps(chart, allow_nan=False, separators=(",", ":"))
    options = "".join(f'<option value="{g}">{html.escape(name)}</option>' for g, name in group_names.items())
    period_options = "".join(f'<option value="{p}">{PERIODS[p]}</option>' for p in ("post", "pre"))
    document = f"""<!doctype html>
<html lang="nl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Aantalsindex</title>
<style>
:root{{font:16px system-ui,sans-serif;color:#25343b;background:#fff}}body{{margin:0;padding:clamp(12px,3vw,28px)}}h1{{margin:0;font-size:1.55rem}}h2{{font-size:1.12rem;margin-top:1.5rem}}p{{line-height:1.5}}label{{display:inline-block;margin:0 1rem .5rem 0}}select,input{{display:block;font:inherit;padding:.35rem;max-width:100%}}canvas{{display:block;width:100%;height:auto;max-width:850px}}.table-scroll{{overflow:auto}}table{{border-collapse:collapse;width:100%;font-size:.92rem}}th,td{{padding:.55rem;text-align:left;border-bottom:1px solid #dbe4e6;vertical-align:top}}th{{background:#edf4f2}}tr[data-supported=false] td:last-child{{background:#fff6e7}}tr[hidden]{{display:none}}summary{{cursor:pointer}}
html.group-embed{{overflow:hidden}}.group-embed body{{padding:0}}
</style></head><body>
<main id="index-panel">
<h1>Aantalsindex</h1>
<p>Op basis van 2.000 kaveltrekkingen. Per periode is de gemiddelde index over de eerste vijf jaar 100. De verandering vergelijkt dit begin met het gemiddelde van de laatste vijf jaar.</p>
<label>Ecologische groep<select id="group">{options}</select></label>
<label>Periode<select id="period">{period_options}</select></label>
<canvas id="series" width="820" height="245" role="img" aria-label="Aantalsindex per jaar. De exacte waarden staan in de tabel Jaarwaarden."></canvas>
<p id="chart-start">De grafiek begint in 1985. De waarde voor 1984 staat bij Jaarwaarden en telt mee in de referentie over 1984–1988.</p>
<details><summary>Jaarwaarden voor de gekozen groep</summary><div id="years"></div></details>
<details><summary>Richting per periode</summary>{overview}</details>
</main>
<section id="species-roster">
<h2>Alle 156 soorten</h2>
<label>Zoek een soort<input id="search" type="search" autocomplete="off"></label>
<p id="visible-species" aria-live="polite">156 soorten</p>{roster}
</section>
<script>
const series={embedded};
const group=document.getElementById("group"),period=document.getElementById("period");
const codes=(new URLSearchParams(location.search).get("groepen")||"").split(",");
const available=new Set(Array.from(group.options,option=>option.value));
if(codes.every(code=>available.has(code))){{
  for(const option of Array.from(group.options))if(!codes.includes(option.value))option.remove();
  group.value=codes[0];
  if(group.options.length===1)group.parentElement.hidden=true;
  for(const row of document.querySelectorAll("#groups tr[data-group]")){{
    if(!codes.includes(row.dataset.group))row.hidden=true;
  }}
  const frame=window.frameElement;
  if(frame){{
    document.getElementById("species-roster").hidden=true;
    document.documentElement.classList.add("group-embed");
    const panel=document.getElementById("index-panel");
    const fitFrame=()=>{{frame.style.height=Math.ceil(panel.getBoundingClientRect().bottom)+"px";}};
    new ResizeObserver(fitFrame).observe(panel);
    fitFrame();
  }}
}}
const canvas=document.getElementById("series"),ctx=canvas.getContext("2d");
const number=new Intl.NumberFormat("nl-NL",{{maximumFractionDigits:2}});
function draw(){{
  const annualRows=series[group.value+"-"+period.value];
  const isPost=period.value==="post";
  const rows=isPost?annualRows.filter(([year])=>year>=1985):annualRows;
  document.getElementById("chart-start").hidden=!isPost;
  const max=Math.max(100,...rows.map(r=>r[1]))*1.1;
  const x=i=>63+i*(canvas.width-82)/(rows.length-1), y=v=>208-v*180/max;
  ctx.clearRect(0,0,canvas.width,canvas.height);
  ctx.font="15px system-ui";
  for(const value of [0,100,max]){{
    ctx.fillStyle="#405660";ctx.fillText(number.format(value),4,y(value)+5);
    ctx.strokeStyle="#c5d2d6";ctx.beginPath();ctx.moveTo(x(0),y(value));ctx.lineTo(x(rows.length-1),y(value));ctx.stroke();
  }}
  ctx.strokeStyle="#12674f";ctx.lineWidth=2.5;ctx.beginPath();
  rows.forEach((row,i)=>i?ctx.lineTo(x(i),y(row[1])):ctx.moveTo(x(i),y(row[1])));ctx.stroke();ctx.lineWidth=1;
  ctx.fillStyle="#405660";ctx.fillText(rows[0][0],x(0),232);ctx.fillText(rows.at(-1)[0],x(rows.length-1)-35,232);
  const table=document.createElement("table");
  table.innerHTML="<thead><tr><th scope='col'>Jaar</th><th scope='col'>Aantalsindex</th></tr></thead>";
  const body=table.createTBody();
  for(const [year,index] of annualRows){{const row=body.insertRow();row.insertCell().textContent=year;row.insertCell().textContent=number.format(index);}}
  document.getElementById("years").replaceChildren(table);
}}
group.addEventListener("change",draw);period.addEventListener("change",draw);draw();
const birds=Array.from(document.querySelectorAll("#birds tbody tr"));
document.getElementById("search").addEventListener("input",event=>{{
  const text=event.target.value.toLocaleLowerCase("nl").trim();
  let visible=0;
  for(const row of birds){{row.hidden=!row.cells[0].textContent.toLocaleLowerCase("nl").includes(text);if(!row.hidden)visible++;}}
  document.getElementById("visible-species").textContent=visible===1?"1 soort":visible+" soorten";
}});
</script></body></html>
"""
    output.mkdir(parents=True, exist_ok=True)
    destination = output / "bootstrap.html"
    destination.write_text(document, encoding="utf-8")
    meta = {
        "schema": "trim-bootstrap-presentation-v1",
        "presentation_kind": "ecologische_aantalsindex",
        "publication_status": "diagnostisch",
        "html_sha256": sha(destination),
        "source_hash": source_hash,
        "candidate_sha256": sha(candidate_file),
        "year_from": 1958,
        "year_to": 2026,
        "group_periods": len(groups),
        "unsupported_periods": len(failure),
        "annual_rows": len(annual),
        "species_count": len(species),
        "checks": dict(Counter(status.values())),
    }
    (output / "manifest.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    make_preview(args.candidate, args.output)
