#!/usr/bin/env python3
"""Importeer openbare FFV- en GBIF-bronnen en koppel de beveiligde NDFF-laag.

De import schrijft openbare data uitsluitend naar Meijendel. Alleen de
hashkoppeling wordt in Meijendel_ndff_secure vastgelegd. De bronbestanden
blijven ongewijzigd op de T7.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import re
import subprocess
import tempfile
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path
from typing import Iterable

from osgeo import ogr

ogr.UseExceptions()


DEFAULT_OPEN = Path("/Volumes/T7 Data/Home_Ton/Meijendel data/NDFF/open_ffv/staging/ndff_meijendel_staging_1950_2025.gpkg")
DEFAULT_GBIF = Path("/Volumes/T7 Data/Home_Ton/Meijendel data/NDFF/external_gbif/meijendel_vangblikken_1953_1960/derived/dwca_v1.7")
DEFAULT_PLOTS = Path("/Volumes/T7 Data/Home_Ton/Meijendel data/NDFF/correspondentie/bijlagen_antwoord_58679/meijendel_sovon_plots_rd_versie_2025.gpkg")
DEFAULT_MANIFEST = Path("/Volumes/T7 Data/Home_Ton/Meijendel data/NDFF/manifests/full_mysql_import_manifest.json")
SCHEMA = Path(__file__).parents[1] / "database" / "ndff_public_schema.sql"
SECURE_SCHEMA = Path(__file__).parents[1] / "database" / "ndff_secure_schema.sql"

GROUP_CODES = {
    "Amfibieën": "amfibieen",
    "Dagvlinders": "dagvlinders",
    "Eencelligen": "eencelligen",
    "Geleedpotigen (overig)": "geleedpotigen_overig",
    "Insecten (overig)": "insecten_overig",
    "Kevers": "kevers",
    "Korstmossen": "korstmossen",
    "Kranswieren, wieren en algen": "kranswieren_wieren_algen",
    "Kreeftachtigen": "kreeftachtigen",
    "Libellen": "libellen",
    "Microvlinders": "microvlinders",
    "Mossen": "mossen",
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


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def sha256_text(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def ffv_species_key(group: object | None, common_name: object | None, scientific_name: object | None) -> str:
    return sha256_text("\x1f".join(str(value or "") for value in (group, common_name, scientific_name)))


def open_identity_hash(identity: str) -> str:
    """Behoud de reeds gehashte FFV-identiteit; hash alleen een ruwe URI."""
    if re.fullmatch(r"[0-9a-fA-F]{64}", identity):
        return identity.casefold()
    return sha256_text(identity)


def mysql_field(value: object | None) -> str:
    if value is None:
        return r"\N"
    text = str(value)
    return text.replace("\\", r"\\").replace("\t", r"\t").replace("\n", r"\n").replace("\r", r"\r")


def write_tsv_row(handle, values: Iterable[object | None]) -> None:
    handle.write("\t".join(mysql_field(value) for value in values) + "\n")


def group_codes(raw: str) -> tuple[str, ...]:
    parts = tuple(part.strip() for part in raw.split("|") if part.strip())
    unknown = [part for part in parts if part not in GROUP_CODES]
    if unknown:
        raise ValueError(f"Onbekende FFV-soortgroep(en): {unknown}")
    return tuple(GROUP_CODES[part] for part in parts)


def trap_number(location_id: str) -> int:
    match = re.fullmatch(r"pf(\d+)", location_id)
    if not match:
        raise ValueError(f"Onverwacht vangbliknummer: {location_id}")
    return int(match.group(1))


def parse_gbif_date(value: str) -> datetime:
    return datetime.strptime(value, "%d/%m/%Y")


def gbif_event_flags(row: dict[str, str]) -> dict[str, int]:
    number = trap_number(row["locationID"])
    year = parse_gbif_date(row["eventDate"]).year
    remarks = row.get("eventRemarks", "").casefold()
    return {
        "is_verplaatst_blok_7_18": int(7 <= number <= 18 and year >= 1955),
        "is_vergelijkingsblik_1959": int(number > 100 and year >= 1959),
        "heeft_predatie_of_zoogdierrisico": int("mammal" in remarks),
        "geen_harde_nul": 1,
    }


def gbif_occurrence_status(source_event_id: str, valid_events: set[str]) -> dict[str, object]:
    valid = source_event_id in valid_events
    return {
        "event_id": source_event_id if valid else None,
        "is_verweesd": int(not valid),
        "referentieel_geldig": int(valid),
    }


def mysql_connection_args(login_path: str, host: str, port: int) -> list[str]:
    return [
        f"--login-path={login_path}",
        "--protocol=tcp",
        f"--host={host}",
        f"--port={port}",
        "--local-infile=1",
        "--binary-mode",
    ]


def run_mysql(client: Path, args: list[str], sql: str, capture: bool = False) -> str:
    result = subprocess.run(
        [str(client), *args],
        input=sql,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode:
        raise RuntimeError(f"MySQL-fout ({result.returncode}): {result.stderr.strip()}")
    return result.stdout.strip() if capture else ""


def mysql_scalar(client: Path, args: list[str], sql: str) -> str:
    output = run_mysql(client, args + ["--batch", "--skip-column-names", "--raw"], sql, capture=True)
    return output.splitlines()[-1] if output else ""


def sql_path(path: Path) -> str:
    return str(path).replace("\\", "\\\\").replace("'", "''")


def standardized_datetime(value: object | None) -> str | None:
    if value in (None, ""):
        return None
    text = str(value).replace("/", "-").replace("T", " ")
    return text[:19]


def create_open_tsv(gpkg: Path, temp_root: Path) -> dict[str, object]:
    dataset = ogr.Open(str(gpkg), 0)
    if dataset is None:
        raise ValueError(f"GeoPackage niet leesbaar: {gpkg}")
    taxa_layer = dataset.GetLayerByName("ndff_soorten")
    obs_layer = dataset.GetLayerByName("ndff_waarnemingen")
    if taxa_layer is None or obs_layer is None:
        raise ValueError("Vereiste FFV-lagen ontbreken")

    taxa_path = temp_root / "ndff_taxa.tsv"
    obs_path = temp_root / "ndff_observations.tsv"
    groups_path = temp_root / "ndff_groups.tsv"
    taxon_count = 0
    with taxa_path.open("w", encoding="utf-8", newline="") as handle:
        for feature in taxa_layer:
            write_tsv_row(handle, [
                feature["soort_key"], feature["Soortgroep"], feature["Naam soort"],
                feature["Wetenschappelijke naam"], feature["waarneming_aantal"],
            ])
            taxon_count += 1

    fields = [obs_layer.GetLayerDefn().GetFieldDefn(index).GetName() for index in range(obs_layer.GetLayerDefn().GetFieldCount())]
    record_count = 0
    group_links = 0
    group_counts: Counter[str] = Counter()
    with obs_path.open("w", encoding="utf-8", newline="") as obs_handle, groups_path.open("w", encoding="utf-8", newline="") as group_handle:
        for feature in obs_layer:
            values = {name: feature.GetField(name) for name in fields}
            identity = str(values["Identiteit"])
            species_key = ffv_species_key(
                values.get("Soortgroep"), values.get("Naam soort"), values.get("Wetenschappelijke naam")
            )
            geometry = feature.GetGeometryRef()
            if geometry is None or geometry.IsEmpty():
                raise ValueError(f"FFV-record zonder geometrie: {feature.GetFID()}")
            geometry_wkb = bytes(geometry.ExportToWkb())
            raw_payload = json.dumps(values, ensure_ascii=False, separators=(",", ":"), default=str)
            start = standardized_datetime(values.get("Periode start"))
            stop = standardized_datetime(values.get("Periode stop"))
            write_tsv_row(obs_handle, [
                feature.GetFID(), identity, open_identity_hash(identity), species_key,
                values.get("Soortgroep"), values.get("Naam soort"), values.get("Wetenschappelijke naam"),
                start, stop, start[:4] if start else None,
                values.get("Vervaging"), values.get("vervaagd"), values.get("vervagingsniveau_km"),
                values.get("Hoknummer"), values.get("Hok grootte"), values.get("Telonderwerp"),
                values.get("Beleidsstatus"), values.get("Aantal"), values.get("Schaal (telmethode)"),
                values.get("Bronhouder"), values.get("Protocol"), values.get("Stadium"), values.get("Sekse"),
                values.get("Gedrag"), values.get("Doodsoorzaak"), values.get("Determinatiemethode"),
                values.get("Zoek- of vangmethode"), values.get("Apparatuur"), values.get("Oorsprong"),
                values.get("Biotoop"), values.get("Substraat"), values.get("Verblijfplaats"),
                values.get("ontdubbel_sleutel"), values.get("bronbestand_eerste"),
                values.get("bronbestand_aantal"), values.get("bronrecord_aantal"), values.get("payload_conflict"),
                values.get("bouwversie"), geometry_wkb.hex(), hashlib.sha256(geometry_wkb).hexdigest(), raw_payload,
            ])
            for code in group_codes(str(values["Soortgroep"])):
                write_tsv_row(group_handle, [feature.GetFID(), code, values["Soortgroep"]])
                group_counts[code] += 1
                group_links += 1
            record_count += 1
    dataset = None
    return {
        "taxa_path": taxa_path,
        "obs_path": obs_path,
        "groups_path": groups_path,
        "taxa": taxon_count,
        "records": record_count,
        "group_links": group_links,
        "group_counts": dict(sorted(group_counts.items())),
    }


def create_gbif_tsv(gbif_root: Path, temp_root: Path) -> dict[str, object]:
    event_path = gbif_root / "event.txt"
    occurrence_path = gbif_root / "occurrence.txt"
    with event_path.open(encoding="utf-8", newline="") as handle:
        events = list(csv.DictReader(handle, delimiter="\t"))
    with occurrence_path.open(encoding="utf-8", newline="") as handle:
        occurrences = list(csv.DictReader(handle, delimiter="\t"))
    event_ids = {row["eventID"] for row in events}
    occurrence_counts = Counter(row["eventID"] for row in occurrences if row["eventID"] in event_ids)

    versions: dict[tuple[str, str, str], list[dict[str, str]]] = defaultdict(list)
    for row in events:
        versions[(row["locationID"], row["verbatimLatitude"], row["verbatimLongitude"])].append(row)

    locations_tsv = temp_root / "vangblik_locations.tsv"
    events_tsv = temp_root / "vangblik_events.tsv"
    species_tsv = temp_root / "vangblik_species.tsv"
    occurrences_tsv = temp_root / "vangblik_occurrences.tsv"

    with locations_tsv.open("w", encoding="utf-8", newline="") as handle:
        for (location_id, x, y), rows in sorted(versions.items()):
            dates = [parse_gbif_date(row["eventDate"]) for row in rows]
            flags = [gbif_event_flags(row) for row in rows]
            first = rows[0]
            write_tsv_row(handle, [
                location_id, x, y, first["decimalLatitude"], first["decimalLongitude"],
                first["coordinateUncertaintyInMeters"], min(dates).date().isoformat(),
                max(dates).date().isoformat(), max(flag["is_verplaatst_blok_7_18"] for flag in flags),
            ])

    with events_tsv.open("w", encoding="utf-8", newline="") as handle:
        for row in events:
            flags = gbif_event_flags(row)
            write_tsv_row(handle, [
                row["eventID"], row["locationID"], row["verbatimLatitude"], row["verbatimLongitude"],
                parse_gbif_date(row["eventDate"]).date().isoformat(), row["startDayOfYear"],
                row["samplingProtocol"], row["sampleSizeValue"], row["sampleSizeUnit"],
                row["samplingEffort"], row["eventRemarks"], row["ownerInstitutionCode"],
                row["country"], row["countryCode"], row["locality"], row["geodeticDatum"],
                flags["is_vergelijkingsblik_1959"], flags["heeft_predatie_of_zoogdierrisico"],
                flags["geen_harde_nul"], occurrence_counts[row["eventID"]],
                json.dumps(row, ensure_ascii=False, separators=(",", ":")),
            ])

    species = {
        (row["scientificName"], row["kingdom"], row["phylum"], row["class"], row["order"], row["family"], row["taxonRank"])
        for row in occurrences
    }


def create_plot_tsv(plot_gpkg: Path, temp_root: Path) -> dict[str, object]:
    dataset = ogr.Open(str(plot_gpkg), 0)
    layer = dataset.GetLayerByName("sovon_plots_meijendel_2025") if dataset else None
    if layer is None:
        raise ValueError("Geversioneerde SOVON-plotlaag ontbreekt")
    output = temp_root / "sovon_plots.tsv"
    count = 0
    with output.open("w", encoding="utf-8", newline="") as handle:
        for feature in layer:
            geometry = feature.GetGeometryRef()
            if geometry is None or geometry.IsEmpty():
                raise ValueError(f"SOVON-plot zonder geometrie: {feature.GetFID()}")
            wkb = bytes(geometry.ExportToWkb())
            write_tsv_row(handle, [
                feature["plot_id"], feature["sovon_projectid"], feature["plotnummer"],
                feature["plotnaam"], feature["bron_oppervlakte_ha"], wkb.hex(),
                hashlib.sha256(wkb).hexdigest(),
            ])
            count += 1
    dataset = None
    return {"path": output, "count": count}


def plot_import_sql(files: dict[str, object], plot_gpkg: Path, source_hash: str) -> str:
    return f"""
USE Meijendel;
START TRANSACTION;
INSERT INTO ndff_sovon_plotversie (versie,bronbestand,bronbestand_sha256,crs_epsg,objectaantal)
VALUES ('2025','{sql_path(plot_gpkg)}','{source_hash}',28992,{files['count']});
SET @plotversie_id=LAST_INSERT_ID();
CREATE TEMPORARY TABLE tmp_sovon_plot (plot_id INT, sovon_projectid BIGINT, plotnummer INT, plotnaam VARCHAR(500), oppervlakte DECIMAL(14,6), geom_hex LONGTEXT, geom_sha CHAR(64));
LOAD DATA LOCAL INFILE '{sql_path(files['path'])}' INTO TABLE tmp_sovon_plot CHARACTER SET utf8mb4 FIELDS TERMINATED BY '\\t' ESCAPED BY '\\\\' LINES TERMINATED BY '\\n';
INSERT INTO ndff_sovon_plot (plotversie_id,plot_id,sovon_projectid,plotnummer,plotnaam,bron_oppervlakte_ha,plot_geometrie,plot_geometrie_sha256)
SELECT @plotversie_id,t.plot_id,t.sovon_projectid,t.plotnummer,t.plotnaam,t.oppervlakte,ST_GeomFromWKB(UNHEX(t.geom_hex),28992),t.geom_sha
FROM tmp_sovon_plot t JOIN plots p ON p.plot_id=t.plot_id;
COMMIT;
"""


def gbif_plot_link_sql() -> str:
    return """
USE Meijendel;
INSERT IGNORE INTO vangblik_event_plot (event_id,plot_id,koppelregel_versie,is_eenduidig)
SELECT event_id,plot_id,'sovon-plots-2025-volledig-binnen-punt',IF(match_count=1,1,0) FROM (
  SELECT e.event_id,p.plot_id,COUNT(*) OVER (PARTITION BY e.event_id) AS match_count
  FROM vangblik_event e
  JOIN vangblik_locatieversie l ON l.locatieversie_id=e.locatieversie_id
  JOIN ndff_sovon_plot p ON ST_Intersects(p.plot_geometrie,l.locatiepunt)
) matches;
"""
    with species_tsv.open("w", encoding="utf-8", newline="") as handle:
        for values in sorted(species):
            write_tsv_row(handle, [sha256_text("\u241f".join(values)), *values])

    orphan_count = 0
    individual_count = 0
    with occurrences_tsv.open("w", encoding="utf-8", newline="") as handle:
        for row in occurrences:
            status = gbif_occurrence_status(row["eventID"], event_ids)
            taxon_values = (row["scientificName"], row["kingdom"], row["phylum"], row["class"], row["order"], row["family"], row["taxonRank"])
            taxon_key = sha256_text("\u241f".join(taxon_values))
            orphan_count += status["is_verweesd"]
            individual_count += int(row["individualCount"])
            write_tsv_row(handle, [
                row["occurrenceID"], status["event_id"], row["eventID"], taxon_key, row["scientificName"],
                row["kingdom"], row["phylum"], row["class"], row["order"], row["family"], row["taxonRank"],
                row["ownerInstitutionCode"], row["basisOfRecord"], row["recordedBy"], row["individualCount"],
                row["lifeStage"], row["occurrenceStatus"], row["occurrenceRemarks"],
                status["is_verweesd"], status["referentieel_geldig"], 1,
                "uitgesloten" if status["is_verweesd"] else "bronregistratie_niet_toegelaten",
                json.dumps(row, ensure_ascii=False, separators=(",", ":")),
            ])
    return {
        "event_source": event_path,
        "occurrence_source": occurrence_path,
        "locations_path": locations_tsv,
        "events_path": events_tsv,
        "species_path": species_tsv,
        "occurrences_path": occurrences_tsv,
        "events": len(events),
        "locations": len(versions),
        "occurrences": len(occurrences),
        "taxa": len(species),
        "orphans": orphan_count,
        "individuals": individual_count,
        "empty_events": len(events) - len(occurrence_counts),
    }


def open_import_sql(files: dict[str, object], gpkg: Path, source_hash: str) -> str:
    columns = """staging_fid BIGINT, identiteit TEXT, identiteit_sha256 CHAR(64), soort_key CHAR(64), soortgroep_raw VARCHAR(255), nederlandse_naam VARCHAR(500), wetenschappelijke_naam VARCHAR(500), periode_start DATETIME, periode_stop DATETIME, jaar SMALLINT, vervaging_raw VARCHAR(255), vervaagd TINYINT, vervagingsniveau_km SMALLINT, hoknummer VARCHAR(64), hok_grootte VARCHAR(64), telonderwerp VARCHAR(500), beleidsstatus VARCHAR(500), aantal_raw VARCHAR(255), schaal_telmethode VARCHAR(500), bronhouder VARCHAR(500), protocol VARCHAR(500), stadium VARCHAR(255), sekse VARCHAR(255), gedrag VARCHAR(500), doodsoorzaak VARCHAR(500), determinatiemethode VARCHAR(500), zoek_of_vangmethode VARCHAR(500), apparatuur VARCHAR(500), oorsprong VARCHAR(500), biotoop VARCHAR(500), substraat VARCHAR(500), verblijfplaats VARCHAR(500), ontdubbel_sleutel VARCHAR(128), bronbestand_eerste VARCHAR(500), bronbestand_aantal INT, bronrecord_aantal INT, payload_conflict TINYINT, bouwversie VARCHAR(32), geom_hex LONGTEXT, geom_sha CHAR(64), raw_payload LONGTEXT"""
    group_inserts = "\n".join(
        f"INSERT INTO ndff_{code} (waarneming_id) SELECT w.waarneming_id FROM ndff_open_waarneming w JOIN tmp_ndff_group g ON g.staging_fid=w.staging_fid AND g.soortgroep_code='{code}' WHERE w.batch_id=@batch_id;"
        for code in GROUP_CODES.values()
    )
    return f"""
USE Meijendel;
START TRANSACTION;
INSERT INTO ndff_open_import_batch (bronbestand,bronbestand_sha256,bouwversie,periode_start,periode_einde,recordaantal,taxonaantal,bronstatus,opmerkingen)
VALUES ('{sql_path(gpkg)}','{source_hash}','staging-v1',1950,2025,{files['records']},{files['taxa']},'openbaar','Geintegreerde, ontdubbelde openbare FFV-staging; positieve bronregistratie zonder automatische analysetoelating');
SET @batch_id=LAST_INSERT_ID();
CREATE TEMPORARY TABLE tmp_ndff_taxon (soort_key CHAR(64), soortgroep_raw VARCHAR(255), nederlandse_naam VARCHAR(500), wetenschappelijke_naam VARCHAR(500), waarneming_aantal BIGINT);
LOAD DATA LOCAL INFILE '{sql_path(files['taxa_path'])}' INTO TABLE tmp_ndff_taxon CHARACTER SET utf8mb4 FIELDS TERMINATED BY '\\t' ESCAPED BY '\\\\' LINES TERMINATED BY '\\n';
INSERT INTO ndff_soorten (soort_key,soortgroep_raw,nederlandse_naam,wetenschappelijke_naam,waarneming_aantal_bron)
SELECT soort_key,soortgroep_raw,nederlandse_naam,wetenschappelijke_naam,waarneming_aantal FROM tmp_ndff_taxon;
CREATE TEMPORARY TABLE tmp_ndff_obs ({columns});
LOAD DATA LOCAL INFILE '{sql_path(files['obs_path'])}' INTO TABLE tmp_ndff_obs CHARACTER SET utf8mb4 FIELDS TERMINATED BY '\\t' ESCAPED BY '\\\\' LINES TERMINATED BY '\\n';
INSERT INTO ndff_open_waarneming (batch_id,staging_fid,identiteit,identiteit_sha256,soort_key,soortgroep_raw,nederlandse_naam,wetenschappelijke_naam,periode_start,periode_stop,jaar,vervaging_raw,vervaagd,vervagingsniveau_km,hoknummer,hok_grootte,telonderwerp,beleidsstatus,aantal_raw,schaal_telmethode,bronhouder,protocol,stadium,sekse,gedrag,doodsoorzaak,determinatiemethode,zoek_of_vangmethode,apparatuur,oorsprong,biotoop,substraat,verblijfplaats,ontdubbel_sleutel,bronbestand_eerste,bronbestand_aantal,bronrecord_aantal,payload_conflict,bouwversie,openbare_geometrie,openbare_geometrie_sha256,raw_payload)
SELECT @batch_id,staging_fid,identiteit,identiteit_sha256,soort_key,soortgroep_raw,nederlandse_naam,wetenschappelijke_naam,periode_start,periode_stop,jaar,vervaging_raw,vervaagd,vervagingsniveau_km,hoknummer,hok_grootte,telonderwerp,beleidsstatus,aantal_raw,schaal_telmethode,bronhouder,protocol,stadium,sekse,gedrag,doodsoorzaak,determinatiemethode,zoek_of_vangmethode,apparatuur,oorsprong,biotoop,substraat,verblijfplaats,ontdubbel_sleutel,bronbestand_eerste,bronbestand_aantal,bronrecord_aantal,payload_conflict,bouwversie,ST_GeomFromWKB(UNHEX(geom_hex),28992),geom_sha,CAST(raw_payload AS JSON) FROM tmp_ndff_obs;
CREATE TEMPORARY TABLE tmp_ndff_group (staging_fid BIGINT, soortgroep_code VARCHAR(64), soortgroep_raw VARCHAR(255));
LOAD DATA LOCAL INFILE '{sql_path(files['groups_path'])}' INTO TABLE tmp_ndff_group CHARACTER SET utf8mb4 FIELDS TERMINATED BY '\\t' ESCAPED BY '\\\\' LINES TERMINATED BY '\\n';
INSERT INTO ndff_open_soortgroep_koppeling (waarneming_id,soortgroep_code,soortgroep_raw)
SELECT w.waarneming_id,g.soortgroep_code,g.soortgroep_raw FROM tmp_ndff_group g JOIN ndff_open_waarneming w ON w.batch_id=@batch_id AND w.staging_fid=g.staging_fid;
{group_inserts}
COMMIT;
"""


def gbif_import_sql(files: dict[str, object], event_hash: str, occurrence_hash: str) -> str:
    return f"""
USE Meijendel;
START TRANSACTION;
INSERT INTO vangblik_import_batch (dataset_titel,dataset_versie,dataset_doi,licentie,eventbestand_sha256,occurrencebestand_sha256,eventaantal,occurrenceaantal)
VALUES ('Meijendel research 1953-1960','1.7','10.15468/adsbxs','CC BY-NC 4.0','{event_hash}','{occurrence_hash}',{files['events']},{files['occurrences']});
SET @batch_id=LAST_INSERT_ID();
CREATE TEMPORARY TABLE tmp_vangblik_locatie (location_id VARCHAR(64), x_rd INT, y_rd INT, latitude DECIMAL(10,7), longitude DECIMAL(10,7), onzekerheid DECIMAL(10,2), geldig_vanaf DATE, geldig_tot DATE, verplaatst TINYINT);
LOAD DATA LOCAL INFILE '{sql_path(files['locations_path'])}' INTO TABLE tmp_vangblik_locatie CHARACTER SET utf8mb4 FIELDS TERMINATED BY '\\t' ESCAPED BY '\\\\' LINES TERMINATED BY '\\n';
INSERT INTO vangblik_locatieversie (batch_id,location_id,verbatim_x_rd,verbatim_y_rd,decimal_latitude,decimal_longitude,onzekerheid_meter,geldig_vanaf,geldig_tot_en_met,locatiepunt,is_verplaatst_blok_7_18)
SELECT @batch_id,location_id,x_rd,y_rd,latitude,longitude,onzekerheid,geldig_vanaf,geldig_tot,ST_PointFromText(CONCAT('POINT(',x_rd,' ',y_rd,')'),28992),verplaatst FROM tmp_vangblik_locatie;
CREATE TEMPORARY TABLE tmp_vangblik_event (event_id VARCHAR(255), location_id VARCHAR(64), x_rd INT, y_rd INT, eventdatum DATE, start_day SMALLINT, protocol VARCHAR(128), size_value DECIMAL(10,2), size_unit VARCHAR(64), effort VARCHAR(255), remarks TEXT, owner_code VARCHAR(500), country VARCHAR(128), country_code CHAR(2), locality VARCHAR(255), datum VARCHAR(64), vergelijking TINYINT, risico TINYINT, geen_nul TINYINT, occurrenceaantal INT, raw_payload LONGTEXT);
LOAD DATA LOCAL INFILE '{sql_path(files['events_path'])}' INTO TABLE tmp_vangblik_event CHARACTER SET utf8mb4 FIELDS TERMINATED BY '\\t' ESCAPED BY '\\\\' LINES TERMINATED BY '\\n';
INSERT INTO vangblik_event (event_id,batch_id,locatieversie_id,eventdatum,start_day_of_year,sampling_protocol,sample_size_value,sample_size_unit,sampling_effort,event_remarks,owner_institution_code,country,country_code,locality,geodetic_datum,is_vergelijkingsblik_1959,heeft_predatie_of_zoogdierrisico,geen_harde_nul,occurrenceaantal,raw_payload)
SELECT e.event_id,@batch_id,l.locatieversie_id,e.eventdatum,e.start_day,e.protocol,e.size_value,e.size_unit,e.effort,e.remarks,e.owner_code,e.country,e.country_code,e.locality,e.datum,e.vergelijking,e.risico,e.geen_nul,e.occurrenceaantal,CAST(e.raw_payload AS JSON) FROM tmp_vangblik_event e JOIN vangblik_locatieversie l ON l.batch_id=@batch_id AND l.location_id=e.location_id AND l.verbatim_x_rd=e.x_rd AND l.verbatim_y_rd=e.y_rd;
CREATE TEMPORARY TABLE tmp_vangblik_soort (taxon_key CHAR(64), scientific_name VARCHAR(500), kingdom VARCHAR(128), phylum VARCHAR(128), class_name VARCHAR(128), order_name VARCHAR(128), family VARCHAR(255), taxon_rank VARCHAR(64));
LOAD DATA LOCAL INFILE '{sql_path(files['species_path'])}' INTO TABLE tmp_vangblik_soort CHARACTER SET utf8mb4 FIELDS TERMINATED BY '\\t' ESCAPED BY '\\\\' LINES TERMINATED BY '\\n';
INSERT INTO vangblik_soorten (taxon_key,scientific_name,kingdom,phylum,class_name,order_name,family,taxon_rank) SELECT * FROM tmp_vangblik_soort;
CREATE TEMPORARY TABLE tmp_vangblik_vangst (occurrence_id VARCHAR(500), event_id VARCHAR(255), bron_event_id VARCHAR(255), taxon_key CHAR(64), scientific_name VARCHAR(500), kingdom VARCHAR(128), phylum VARCHAR(128), class_name VARCHAR(128), order_name VARCHAR(128), family VARCHAR(255), taxon_rank VARCHAR(64), owner_code VARCHAR(500), basis_record VARCHAR(128), recorded_by VARCHAR(500), individual_count INT, life_stage VARCHAR(128), occurrence_status VARCHAR(64), remarks TEXT, verweesd TINYINT, geldig TINYINT, minimumvangst TINYINT, analyse_status VARCHAR(64), raw_payload LONGTEXT);
LOAD DATA LOCAL INFILE '{sql_path(files['occurrences_path'])}' INTO TABLE tmp_vangblik_vangst CHARACTER SET utf8mb4 FIELDS TERMINATED BY '\\t' ESCAPED BY '\\\\' LINES TERMINATED BY '\\n';
INSERT INTO vangblik_vangst (occurrence_id,batch_id,event_id,bron_event_id,vangblik_soort_id,owner_institution_code,basis_of_record,recorded_by,individual_count,life_stage,occurrence_status,occurrence_remarks,is_verweesd,referentieel_geldig,minimumvangst_mogelijk,analyse_status,raw_payload)
SELECT v.occurrence_id,@batch_id,v.event_id,v.bron_event_id,s.vangblik_soort_id,v.owner_code,v.basis_record,v.recorded_by,v.individual_count,v.life_stage,v.occurrence_status,v.remarks,v.verweesd,v.geldig,v.minimumvangst,v.analyse_status,CAST(v.raw_payload AS JSON) FROM tmp_vangblik_vangst v JOIN vangblik_soorten s ON s.taxon_key=v.taxon_key;
COMMIT;
"""


def secure_link_sql() -> str:
    return """
USE Meijendel_ndff_secure;
INSERT IGNORE INTO ndff_open_secure_koppeling (secure_waarneming_id,open_identity_sha256,open_waarneming_id,koppelmethode)
SELECT s.waarneming_id,s.open_identity_sha256,o.waarneming_id,'sha256_publieke_identiteit'
FROM ndff_waarneming_register s
JOIN Meijendel.ndff_open_waarneming o ON o.identiteit_sha256=s.open_identity_sha256;
"""


def repair_open_identity_hash_sql() -> str:
    return """
USE Meijendel;
UPDATE ndff_open_waarneming
SET identiteit_sha256=LOWER(identiteit)
WHERE identiteit REGEXP '^[0-9A-Fa-f]{64}$'
  AND identiteit_sha256<>LOWER(identiteit);
"""


def secure_link_schema_sql() -> str:
    return """
USE Meijendel_ndff_secure;
CREATE TABLE IF NOT EXISTS ndff_open_secure_koppeling (
  secure_waarneming_id BIGINT UNSIGNED NOT NULL,
  open_identity_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
  open_waarneming_id BIGINT UNSIGNED NOT NULL,
  koppelmethode VARCHAR(64) NOT NULL,
  gekoppeld_op DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (secure_waarneming_id),
  UNIQUE KEY uq_ndff_secure_open_hash (open_identity_sha256),
  UNIQUE KEY uq_ndff_secure_open_id (open_waarneming_id),
  CONSTRAINT fk_ndff_secure_open_waarneming FOREIGN KEY (secure_waarneming_id)
    REFERENCES ndff_waarneming_register (waarneming_id)
) ENGINE=InnoDB;
"""


def validation(client: Path, mysql_args: list[str]) -> dict[str, int]:
    queries = {
        "open_records": "SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming",
        "open_taxa": "SELECT COUNT(*) FROM Meijendel.ndff_soorten",
        "open_group_links": "SELECT COUNT(*) FROM Meijendel.ndff_open_soortgroep_koppeling",
        "open_default_excluded": "SELECT COUNT(*) FROM Meijendel.ndff_open_waarneming WHERE analyse_status='bronregistratie_niet_toegelaten'",
        "gbif_events": "SELECT COUNT(*) FROM Meijendel.vangblik_event",
        "gbif_locations": "SELECT COUNT(*) FROM Meijendel.vangblik_locatieversie",
        "gbif_occurrences": "SELECT COUNT(*) FROM Meijendel.vangblik_vangst",
        "gbif_taxa": "SELECT COUNT(*) FROM Meijendel.vangblik_soorten",
        "gbif_individuals": "SELECT SUM(individual_count) FROM Meijendel.vangblik_vangst",
        "gbif_orphans": "SELECT COUNT(*) FROM Meijendel.vangblik_vangst WHERE is_verweesd=1 AND event_id IS NULL AND referentieel_geldig=0",
        "gbif_empty_events": "SELECT COUNT(*) FROM Meijendel.vangblik_event WHERE occurrenceaantal=0 AND geen_harde_nul=1",
        "gbif_events_with_plot": "SELECT COUNT(DISTINCT event_id) FROM Meijendel.vangblik_event_plot",
        "gbif_plot_links": "SELECT COUNT(*) FROM Meijendel.vangblik_event_plot",
        "sovon_plot_count": "SELECT COUNT(*) FROM Meijendel.ndff_sovon_plot",
        "secure_records": "SELECT COUNT(*) FROM Meijendel_ndff_secure.ndff_waarneming_register",
        "secure_open_links": "SELECT COUNT(*) FROM Meijendel_ndff_secure.ndff_open_secure_koppeling",
    }
    return {name: int(mysql_scalar(client, mysql_args, sql)) for name, sql in queries.items()}


def assert_expected(counts: dict[str, int]) -> None:
    expected = {
        "open_records": 810830,
        "open_taxa": 9828,
        "open_group_links": 811063,
        "open_default_excluded": 810830,
        "gbif_events": 37770,
        "gbif_locations": 135,
        "gbif_occurrences": 60560,
        "gbif_taxa": 275,
        "gbif_individuals": 99652,
        "gbif_orphans": 2,
        "gbif_empty_events": 13879,
        "sovon_plot_count": 55,
        "secure_records": 14573,
        "secure_open_links": 14420,
    }
    differences = {name: (counts.get(name), value) for name, value in expected.items() if counts.get(name) != value}
    if differences:
        raise ValueError(f"Importaantallen wijken af: {differences}")
    if counts["gbif_events_with_plot"] == 0:
        raise ValueError("Geen enkel historisch vangblikevent is aan de geversioneerde SOVON-plots gekoppeld")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--open-gpkg", type=Path, default=DEFAULT_OPEN)
    parser.add_argument("--gbif-root", type=Path, default=DEFAULT_GBIF)
    parser.add_argument("--plot-gpkg", type=Path, default=DEFAULT_PLOTS)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--mysql-client", type=Path, default=Path("/usr/local/mysql/bin/mysql"))
    parser.add_argument("--login-path", default="meijendel_root")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=3306)
    parser.add_argument("--execute", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    for path in (args.open_gpkg, args.gbif_root / "event.txt", args.gbif_root / "occurrence.txt", args.plot_gpkg, SCHEMA, SECURE_SCHEMA):
        if not path.is_file():
            raise SystemExit(f"Ontbrekend bestand: {path}")
    open_hash = sha256_file(args.open_gpkg)
    event_hash = sha256_file(args.gbif_root / "event.txt")
    occurrence_hash = sha256_file(args.gbif_root / "occurrence.txt")
    plot_hash = sha256_file(args.plot_gpkg)
    if not args.execute:
        print(json.dumps({"mode": "dry-run", "open_sha256": open_hash, "event_sha256": event_hash, "occurrence_sha256": occurrence_hash, "plot_sha256": plot_hash}, indent=2))
        return 0

    mysql_args = mysql_connection_args(args.login_path, args.host, args.port)
    run_mysql(args.mysql_client, mysql_args, SCHEMA.read_text(encoding="utf-8"))
    run_mysql(args.mysql_client, mysql_args, secure_link_schema_sql())
    old_local_infile = mysql_scalar(args.mysql_client, mysql_args, "SELECT @@GLOBAL.local_infile")
    run_mysql(args.mysql_client, mysql_args, "SET GLOBAL local_infile=ON")
    try:
        with tempfile.TemporaryDirectory(prefix="ndff-public-import-") as tmp:
            temp_root = Path(tmp)
            if mysql_scalar(args.mysql_client, mysql_args, f"SELECT COUNT(*) FROM Meijendel.ndff_open_import_batch WHERE bronbestand_sha256='{open_hash}'") == "0":
                open_files = create_open_tsv(args.open_gpkg, temp_root)
                run_mysql(args.mysql_client, mysql_args, open_import_sql(open_files, args.open_gpkg, open_hash))
            if mysql_scalar(args.mysql_client, mysql_args, f"SELECT COUNT(*) FROM Meijendel.vangblik_import_batch WHERE eventbestand_sha256='{event_hash}' AND occurrencebestand_sha256='{occurrence_hash}'") == "0":
                gbif_files = create_gbif_tsv(args.gbif_root, temp_root)
                run_mysql(args.mysql_client, mysql_args, gbif_import_sql(gbif_files, event_hash, occurrence_hash))
            if mysql_scalar(args.mysql_client, mysql_args, f"SELECT COUNT(*) FROM Meijendel.ndff_sovon_plotversie WHERE bronbestand_sha256='{plot_hash}'") == "0":
                plot_files = create_plot_tsv(args.plot_gpkg, temp_root)
                run_mysql(args.mysql_client, mysql_args, plot_import_sql(plot_files, args.plot_gpkg, plot_hash))
            run_mysql(args.mysql_client, mysql_args, gbif_plot_link_sql())
            run_mysql(args.mysql_client, mysql_args, repair_open_identity_hash_sql())
            run_mysql(args.mysql_client, mysql_args, secure_link_sql())
    finally:
        if old_local_infile == "0":
            run_mysql(args.mysql_client, mysql_args, "SET GLOBAL local_infile=OFF")

    counts = validation(args.mysql_client, mysql_args)
    assert_expected(counts)
    manifest = {
        "manifest_version": 1,
        "created_at": datetime.now().astimezone().isoformat(timespec="seconds"),
        "database_split": {
            "public": "Meijendel",
            "protected": "Meijendel_ndff_secure",
            "existing_bird_and_provincial_pq_tables_modified": False,
        },
        "sources": {
            "open_ffv": {"path": str(args.open_gpkg), "sha256": open_hash},
            "gbif_event": {"path": str(args.gbif_root / "event.txt"), "sha256": event_hash},
            "gbif_occurrence": {"path": str(args.gbif_root / "occurrence.txt"), "sha256": occurrence_hash},
            "sovon_plots": {"path": str(args.plot_gpkg), "sha256": plot_hash},
        },
        "counts": counts,
        "analysis_status": {
            "open_ffv": "bronregistratie_niet_toegelaten",
            "gbif": "bronregistratie_niet_toegelaten; verweesde occurrences uitgesloten",
            "secure_ndff": "uitsluitend volgens bestaande beveiligde analysepoort",
        },
    }
    args.manifest.parent.mkdir(parents=True, exist_ok=True)
    args.manifest.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    os.chmod(args.manifest, 0o600)
    print(json.dumps(manifest, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
