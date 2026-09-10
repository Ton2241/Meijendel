#!/usr/bin/env python3
"""Importeer een gevalideerde NDFF-levering in een afzonderlijk lokaal schema.

De importeur leest de originele GeoPackage en de eerder afgeleide audit-CSV's.
Hij wijzigt de life-database Meijendel niet en schrijft geen gevoelige waarden
naar stdout of het importmanifest.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import subprocess
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

from osgeo import ogr


RULE_VERSION = "ndff-secure-58679-v1"
DATABASE = "Meijendel_ndff_secure"
PQ_PROTOCOLS = {
    "12.007 Vegetatieopnamen",
    "12.202 Landelijk Meetnet Flora- Milieu- en Natuurkwaliteit (NEM)",
}
GROUP_TABLES = {
    "Amfibieen": "ndff_amfibieen",
    "Dagvlinders": "ndff_dagvlinders",
    "Eencelligen": "ndff_eencelligen",
    "Geleedpotigen (overig)": "ndff_geleedpotigen_overig",
    "Insecten (overig)": "ndff_insecten_overig",
    "Kevers": "ndff_kevers",
    "Korstmossen": "ndff_korstmossen",
    "Kranswieren, wieren en algen": "ndff_kranswieren_wieren_algen",
    "Kreeftachtigen": "ndff_kreeftachtigen",
    "Libellen": "ndff_libellen",
    "Microvlinders": "ndff_microvlinders",
    "Mossen": "ndff_mossen",
    "Nachtvlinders": "ndff_nachtvlinders",
    "Ongewervelden (overig)": "ndff_ongewervelden_overig",
    "Reptielen": "ndff_reptielen",
    "Schimmels": "ndff_schimmels",
    "Snavelinsecten": "ndff_snavelinsecten",
    "Spinachtigen": "ndff_spinachtigen",
    "Sprinkhanen en krekels": "ndff_sprinkhanen_en_krekels",
    "Vaatplanten": "ndff_vaatplanten",
    "Vissen": "ndff_vissen",
    "Vleermuizen": "ndff_vleermuizen",
    "Vliegen en muggen": "ndff_vliegen_en_muggen",
    "Vliesvleugeligen": "ndff_vliesvleugeligen",
    "Weekdieren": "ndff_weekdieren",
    "Zoogdieren (overig)": "ndff_zoogdieren_overig",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def csv_index(path: Path) -> dict[int, dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return {int(row["secure_fid"]): row for row in csv.DictReader(handle)}


def csv_groups(path: Path) -> dict[int, list[dict[str, str]]]:
    result: dict[int, list[dict[str, str]]] = {}
    with path.open(encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            result.setdefault(int(row["secure_fid"]), []).append(row)
    return result


def source_fields(feature: ogr.Feature) -> dict[str, Any]:
    return {
        feature.GetFieldDefnRef(index).GetName(): feature.GetField(index)
        for index in range(feature.GetFieldCount())
    }


def normalized_date(value: Any) -> str:
    return str(value or "")[:10].replace("/", "-")


def prepare_import_model(
    gpkg: Path,
    gate_csv: Path,
    spatial_csv: Path,
    pq_csv: Path,
    plot_matches_csv: Path,
) -> dict[str, Any]:
    gate = csv_index(gate_csv)
    spatial = csv_index(spatial_csv)
    pq = csv_index(pq_csv)
    plot_matches = csv_groups(plot_matches_csv)
    if not (set(gate) == set(spatial) == set(pq)):
        raise ValueError("Gate-, ruimtelijke en PQ-bestanden bevatten niet dezelfde secure_fid-set.")

    ogr.UseExceptions()
    dataset = ogr.Open(str(gpkg), 0)
    if dataset is None or dataset.GetLayerCount() != 1:
        raise ValueError("De beveiligde GeoPackage moet exact één leesbare laag bevatten.")
    layer = dataset.GetLayer(0)
    records: list[dict[str, Any]] = []
    seen_fids: set[int] = set()
    seen_uris: set[str] = set()
    for feature in layer:
        fid = int(feature.GetFID())
        if fid not in gate:
            raise ValueError(f"GeoPackage-record {fid} ontbreekt in de analysepoort.")
        attrs = source_fields(feature)
        uri = str(attrs.get("obs_uri") or "")
        if not uri or uri in seen_uris:
            raise ValueError("Lege of dubbele obs_uri in de beveiligde GeoPackage.")
        geometry = feature.GetGeometryRef()
        if geometry is None or geometry.IsEmpty() or not geometry.IsValid():
            raise ValueError(f"Ongeldige geometrie voor secure_fid {fid}.")
        gate_row = gate[fid]
        spatial_row = spatial[fid]
        pq_row = pq[fid]
        group = gate_row["groep"]
        if group not in GROUP_TABLES:
            raise ValueError(f"Geen toegestane soortgroeptabel voor {group!r}.")
        protocol = str(attrs.get("protocol") or gate_row["protocol"])
        owner = str(attrs.get("dataeigenr") or "")
        pq_risk_source = protocol in PQ_PROTOCOLS or "provincie/zuid-holland" in owner.casefold()
        pq_status = pq_row["pq_status"]
        if pq_risk_source and pq_status == "niet_van_toepassing":
            raise ValueError(f"PQ-bronrecord {fid} is ten onrechte niet_van_toepassing.")
        distribution_status = gate_row["verspreidingscontext_status"]
        admitted = (
            distribution_status == "kandidaat_verspreidingscontext"
            and pq_status in {"onafhankelijk", "niet_van_toepassing"}
            and not pq_risk_source
        )
        trend_status = (
            "trendkandidaat_wacht_op_brondata"
            if admitted and gate_row["trend_status"] == "brondata_opvragen"
            else "niet_trendklaar"
        )
        start = normalized_date(attrs.get("datm_start"))
        stop = normalized_date(attrs.get("datm_stop"))
        if len(start) != 10 or len(stop) != 10:
            raise ValueError(f"Ongeldige datum voor secure_fid {fid}.")
        matches = plot_matches.get(fid, [])
        expected_match_count = int(spatial_row.get("plot_match_count") or 0)
        if len(matches) != expected_match_count:
            raise ValueError(f"Aantal plotmatches wijkt af voor secure_fid {fid}.")
        record = {
            "secure_fid": fid,
            "attrs": attrs,
            "ndff_identity": uri,
            "open_identity": gate_row["open_identity"],
            "group": group,
            "group_table": GROUP_TABLES[group],
            "scientific_name": str(attrs.get("soort_wet") or ""),
            "dutch_name": str(attrs.get("soort_ned") or ""),
            "start": start,
            "stop": stop,
            "year": int(start[:4]),
            "protocol": protocol,
            "owner": owner,
            "geometry_wkb_hex": bytes(geometry.ExportToWkb()).hex(),
            "geometry_sha256": hashlib.sha256(bytes(geometry.ExportToWkb())).hexdigest(),
            "spatial_class": gate_row["ruimtelijke_klasse"],
            "assignment_quality": gate_row["toewijzingskwaliteit"],
            "plot_matches": matches,
            "protocol_class": gate_row["protocol_auditklasse"],
            "distribution_status": distribution_status,
            "trend_status": trend_status,
            "rule_version": gate_row["beslisregel_versie"],
            "inname_status": "toegelaten" if admitted else "uitgesloten",
            "inname_reason": (
                "positieve_verspreidingscontext"
                if admitted
                else "ndff_pq_secundaire_bron"
                if pq_risk_source
                else distribution_status
            ),
            "pq": pq_row,
            "is_pq_bronrecord": pq_risk_source,
            "pq_is_primaire_bron": False,
        }
        records.append(record)
        seen_fids.add(fid)
        seen_uris.add(uri)
    dataset = None
    if seen_fids != set(gate):
        raise ValueError("Niet alle auditrecords zijn in de GeoPackage aangetroffen.")

    counts = Counter()
    counts["records"] = len(records)
    counts["taxa"] = len({row["scientific_name"].casefold() for row in records})
    counts["distribution_candidates"] = sum(row["inname_status"] == "toegelaten" for row in records)
    counts["trend_candidates"] = sum(row["trend_status"] == "trendkandidaat_wacht_op_brondata" for row in records)
    counts["pq_exact"] = sum(row["pq"]["pq_status"] == "exact" for row in records)
    counts["pq_not_assessable"] = sum(row["pq"]["pq_status"] == "niet_beoordeelbaar" for row in records)
    counts["pq_risk_source_records"] = sum(
        row["protocol"] in PQ_PROTOCOLS or "provincie/zuid-holland" in row["owner"].casefold()
        for row in records
    )
    return {"records": records, "counts": dict(counts)}


def safe_manifest(model: dict[str, Any], gpkg: Path) -> dict[str, Any]:
    return {
        "manifest_version": "1.0",
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "database": DATABASE,
        "source_filename": gpkg.name,
        "source_sha256": sha256(gpkg),
        "rule_version": RULE_VERSION,
        "counts": model["counts"],
        "source_hierarchy": (
            "Provincie Zuid-Holland is de primaire en gezaghebbende PQ-bron; "
            "NDFF-PQ is uitsluitend een secundaire controlebron."
        ),
        "contains_sensitive_values": False,
        "life_database_modified": False,
    }


def sql_text(value: Any) -> str:
    if value is None or value == "":
        return "NULL"
    encoded = str(value).encode("utf-8").hex()
    return f"CONVERT(0x{encoded} USING utf8mb4)"


def sql_number(value: Any) -> str:
    if value is None or value == "":
        return "NULL"
    return str(value)


def sql_statements(
    model: dict[str, Any],
    gpkg: Path,
    analysis_manifest: Path,
    citation: str,
    plot_gpkg: Path,
) -> Iterable[str]:
    records = model["records"]
    yield "SET SESSION sql_mode = 'STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION';"
    yield "START TRANSACTION;"
    yield (
        "INSERT INTO ndff_import_batch "
        "(batch_id,ticketnummer,ontvangen_op,periode_start,periode_einde,origineel_bestand,origineel_formaat,origineel_bestand_sha256,manifest_sha256,standaardcitatie,gebruiksstatus,gevalideerd_op,opmerkingen) VALUES "
        f"(1,'58679','2026-09-10 10:30:00',1950,2025,{sql_text(gpkg.name)},'gpkg','{sha256(gpkg)}','{sha256(analysis_manifest)}',{sql_text(citation)},'toegelaten',CURRENT_TIMESTAMP(6),{sql_text('Lokale beveiligde contextlaag; geen populatietrend zonder volledige bron-surveys.')});"
    )

    taxa = sorted({(row["scientific_name"], row["dutch_name"], row["group"]) for row in records}, key=lambda item: item[0].casefold())
    taxon_ids = {scientific.casefold(): index for index, (scientific, _, _) in enumerate(taxa, 1)}
    for taxon_id, (scientific, dutch, group) in enumerate(taxa, 1):
        identity = hashlib.sha256(scientific.casefold().encode("utf-8")).hexdigest()
        yield (
            "INSERT INTO ndff_soorten (ndff_soort_id,ndff_taxon_identity,wetenschappelijke_naam,nederlandse_naam,oorspronkelijke_ffv_soortgroep,kwetsbare_data_status) VALUES "
            f"({taxon_id},'{identity}',{sql_text(scientific)},{sql_text(dutch)},{sql_text(group)},'beveiligde_levering');"
        )

    plot_dataset = ogr.Open(str(plot_gpkg), 0)
    plot_layer = plot_dataset.GetLayerByName("sovon_plots_meijendel_2025")
    plots = []
    for feature in plot_layer:
        geometry = feature.GetGeometryRef()
        plots.append((str(feature.GetField("plot_id")), bytes(geometry.ExportToWkb())))
    overlaps = 0
    for left in range(len(plots)):
        g_left = ogr.CreateGeometryFromWkb(plots[left][1])
        for right in range(left + 1, len(plots)):
            if g_left.Intersects(ogr.CreateGeometryFromWkb(plots[right][1])):
                overlaps += 1
    yield (
        "INSERT INTO ndff_sovon_plotversie (plotversie_id,versie,bronbestand,bronbestand_sha256,crs_epsg,objectaantal,overlap_plotparen,aangemaakt_op) VALUES "
        f"(1,'2025',{sql_text(plot_gpkg.name)},'{sha256(plot_gpkg)}',28992,{len(plots)},{overlaps},'2025-01-01');"
    )
    for plot_id, wkb in plots:
        digest = hashlib.sha256(wkb).hexdigest()
        yield (
            "INSERT INTO ndff_sovon_plot (plotversie_id,plot_id,plot_geometrie,plot_geometrie_sha256) VALUES "
            f"(1,{sql_text(plot_id)},ST_GeomFromWKB(UNHEX('{wkb.hex()}'),28992),'{digest}');"
        )
    plot_dataset = None

    for row in records:
        fid = row["secure_fid"]
        attrs = row["attrs"]
        taxon_id = taxon_ids[row["scientific_name"].casefold()]
        public_blur = attrs.get("vervaagd")
        blur_level = None
        yield (
            "INSERT INTO ndff_waarneming_register "
            "(waarneming_id,batch_id,ndff_soort_id,ndff_identity,open_identity_sha256,bron_record_id,periode_start,periode_stop,jaar,bronhouder,validatiestatus,protocol,bron_locatietype,bron_centrum_x_rd,bron_centrum_y_rd,bron_oppervlakte_m2,publieke_vervaging_raw,publieke_vervagingsniveau_km,exacte_geometrie,exacte_geometrie_sha256,ruimtelijke_klasse,toewijzingskwaliteit,plot_match_count,protocol_auditklasse,verspreidingscontext_status,trend_status,analyse_poort_versie,is_pq_bronrecord,inname_status,inname_reden) VALUES "
            f"({fid},1,{taxon_id},{sql_text(row['ndff_identity'])},'{row['open_identity']}',NULL,'{row['start']}','{row['stop']}',{row['year']},{sql_text(row['owner'])},{sql_text(attrs.get('kwliteit'))},{sql_text(row['protocol'])},{sql_text(attrs.get('loc_type'))},{sql_number(attrs.get('centrumx'))},{sql_number(attrs.get('centrumy'))},{sql_number(attrs.get('area_m2'))},{sql_text(public_blur)},{sql_number(blur_level)},ST_GeomFromWKB(UNHEX('{row['geometry_wkb_hex']}'),28992),'{row['geometry_sha256']}','{row['spatial_class']}','{row['assignment_quality']}',{len(row['plot_matches'])},{sql_text(row['protocol_class'])},'{row['distribution_status']}','{row['trend_status']}',{sql_text(row['rule_version'])},{int(row['is_pq_bronrecord'])},'{row['inname_status']}',{sql_text(row['inname_reason'])});"
        )
        raw_json = json.dumps(attrs, ensure_ascii=False, separators=(",", ":"), default=str)
        raw_hash = hashlib.sha256((row["ndff_identity"] + raw_json).encode("utf-8")).hexdigest()
        yield (
            "INSERT INTO ndff_waarneming_bron (waarneming_id,batch_id,bronbestand,bronlaag,bron_fid,bronrecord_sha256,raw_payload) VALUES "
            f"({fid},1,{sql_text(gpkg.name)},{sql_text('ndff_mwl_z58679_Meijendel')},{fid},'{raw_hash}',{sql_text(raw_json)});"
        )
        group_payload = {
            key: attrs.get(key)
            for key in ("orig_aant", "telondrwrp", "telmethode", "stadium", "geslacht", "gedrag", "detmethode", "biotoop", "substraat", "verblfplts")
        }
        group_status = (
            "trendkandidaat" if row["trend_status"] == "trendkandidaat_wacht_op_brondata"
            else "verspreidingscontext" if row["inname_status"] == "toegelaten"
            else "uitgesloten"
        )
        yield (
            f"INSERT INTO {row['group_table']} (waarneming_id,aantal_raw,telonderwerp,schaal_telmethode,protocol,stadium,sekse,gedrag,determinatiemethode,biotoop,substraat,verblijfplaats,analyse_toelating,toelatingsregel_versie,raw_payload) VALUES "
            f"({fid},{sql_text(attrs.get('orig_aant'))},{sql_text(attrs.get('telondrwrp'))},{sql_text(attrs.get('telmethode'))},{sql_text(row['protocol'])},{sql_text(attrs.get('stadium'))},{sql_text(attrs.get('geslacht'))},{sql_text(attrs.get('gedrag'))},{sql_text(attrs.get('detmethode'))},{sql_text(attrs.get('biotoop'))},{sql_text(attrs.get('substraat'))},{sql_text(attrs.get('verblfplts'))},'{group_status}',{sql_text(row['rule_version'])},{sql_text(json.dumps(group_payload, ensure_ascii=False, separators=(',', ':'), default=str))});"
        )
        for match in row["plot_matches"]:
            presence = int(row["inname_status"] == "toegelaten" and len(row["plot_matches"]) == 1)
            yield (
                "INSERT INTO ndff_waarneming_plot (waarneming_id,plotversie_id,plot_id,match_volgnummer,overlap_oppervlak_m2,overlap_aandeel,centroid_binnen,is_aanwezigheid_per_plot,koppelregel_versie) VALUES "
                f"({fid},1,{sql_text(match['plot_id'])},{int(match['match_volgnummer'])},{sql_number(match.get('overlap_oppervlak_m2'))},{sql_number(match.get('overlap_aandeel'))},{sql_number(match.get('centroid_binnen'))},{presence},{sql_text(match['koppelregel_versie'])});"
            )
        pq_row = row["pq"]
        pq_ids = [value for value in pq_row.get("pq_opname_ids", "").split(";") if value]
        pq_id = int(pq_ids[0]) if len(pq_ids) == 1 else None
        yield (
            "INSERT INTO ndff_pq_koppeling (ndff_waarneming_id,pq_opname_id,classificatie,datum_match,taxon_match,afstand_meter,soortenlijst_overlap,abundantie_compatibel,bronhouder_match,ndff_bronrol,primaire_pq_bron,beslisregel_versie,beoordeeld_op,toelichting) VALUES "
            f"({fid},{sql_number(pq_id)},'{pq_row['pq_status']}',NULL,NULL,NULL,NULL,NULL,{int('provincie/zuid-holland' in row['owner'].casefold())},'{('secundaire_controlebron' if row['is_pq_bronrecord'] else 'niet_van_toepassing')}','{('provincie_zuid_holland' if row['is_pq_bronrecord'] else 'niet_van_toepassing')}',{sql_text(pq_row['beslisregel_versie'])},CURRENT_TIMESTAMP(6),{sql_text(pq_row.get('toelichting'))});"
        )
        for analysis_type, excluded, reason in (
            ("verspreidingscontext", int(row["inname_status"] != "toegelaten"), row["inname_reason"]),
            ("trend", 1, "positieve_waarneming_zonder_volledige_surveystructuur"),
        ):
            yield (
                "INSERT INTO ndff_waarneming_uitsluiting (waarneming_id,analysetype,uitgesloten,reden_code,toelichting,beslisregel_versie,beoordeeld_op,beoordeeld_door) VALUES "
                f"({fid},{sql_text(analysis_type)},{excluded},{sql_text(reason)},NULL,{sql_text(row['rule_version'])},CURRENT_TIMESTAMP(6),'geautomatiseerde_import');"
            )
    yield "COMMIT;"


def mysql_connection_args(login_path: str, host: str, port: int) -> list[str]:
    return [
        f"--login-path={login_path}",
        "--protocol=tcp",
        f"--host={host}",
        f"--port={port}",
        "--binary-mode",
    ]


def run_mysql(
    client: Path,
    login_path: str,
    host: str,
    port: int,
    statements: Iterable[str],
) -> None:
    process = subprocess.Popen(
        [str(client), *mysql_connection_args(login_path, host, port), "--database", DATABASE],
        stdin=subprocess.PIPE,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
    )
    assert process.stdin is not None
    try:
        for statement in statements:
            process.stdin.write(statement)
            process.stdin.write("\n")
    finally:
        process.stdin.close()
    stderr = process.stderr.read() if process.stderr else ""
    returncode = process.wait()
    if returncode:
        raise RuntimeError(f"MySQL-import is afgebroken (code {returncode}): {stderr[-2000:]}")


def execute_schema(client: Path, login_path: str, host: str, port: int, schema: Path) -> None:
    with schema.open(encoding="utf-8") as handle:
        result = subprocess.run(
            [str(client), *mysql_connection_args(login_path, host, port)],
            stdin=handle,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            text=True,
        )
    if result.returncode:
        raise RuntimeError(f"Schema-uitvoering is afgebroken: {result.stderr[-2000:]}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--secure", type=Path, required=True)
    parser.add_argument("--gate", type=Path, required=True)
    parser.add_argument("--spatial", type=Path, required=True)
    parser.add_argument("--pq", type=Path, required=True)
    parser.add_argument("--plot-matches", type=Path, required=True)
    parser.add_argument("--plots", type=Path, required=True)
    parser.add_argument("--analysis-manifest", type=Path, required=True)
    parser.add_argument("--citation-file", type=Path, required=True)
    parser.add_argument("--schema", type=Path, required=True)
    parser.add_argument("--output-manifest", type=Path, required=True)
    parser.add_argument("--mysql-client", type=Path, default=Path("/usr/local/mysql/bin/mysql"))
    parser.add_argument("--login-path", default="meijendel_root")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=3306)
    parser.add_argument("--prepare-only", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    model = prepare_import_model(args.secure, args.gate, args.spatial, args.pq, args.plot_matches)
    manifest = safe_manifest(model, args.secure)
    if not args.prepare_only:
        execute_schema(args.mysql_client, args.login_path, args.host, args.port, args.schema)
        citation = args.citation_file.read_text(encoding="utf-8").strip()
        run_mysql(
            args.mysql_client,
            args.login_path,
            args.host,
            args.port,
            sql_statements(model, args.secure, args.analysis_manifest, citation, args.plots),
        )
        manifest["database_imported"] = True
    else:
        manifest["database_imported"] = False
    args.output_manifest.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": "PASS", "database_imported": manifest["database_imported"], "counts": model["counts"]}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
