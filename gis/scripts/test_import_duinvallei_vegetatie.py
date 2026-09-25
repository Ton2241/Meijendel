#!/usr/bin/env python3
"""Gerichte tests voor de openbare duinvalleivegetatie-importeur."""

from __future__ import annotations

import csv
import importlib.util
import tempfile
from pathlib import Path


SCRIPT = Path(__file__).with_name("import_duinvallei_vegetatie.py")


def load_module():
    spec = importlib.util.spec_from_file_location("duinvallei_import", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def write_fixture(root: Path) -> tuple[Path, Path]:
    metadata = root / "Data_Schoon.csv"
    matrix = root / "Table_complete_v3.csv"
    with metadata.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(
            [
                "id", "Year", "Block", "Plot", "Site", "Grouping_Code",
                "OM", "Moist", "pH", "NO3", "NH4", "PO4", "K", "Na",
                "Ntot", "Ptot", "DCA1", "DCA2", "Location", "Location_n",
                "Cluster", "Block_n", "OGCLUST",
            ]
        )
        writer.writerow(["01A01", 2001, "A", 1, "A1", "2001_A", 5, "", 7, 1, 2, 0, 3, 4, 5, 6, 0.1, 0.2, "KV_2001", 1, 1, 1, 1])
        writer.writerow(["18A01", 2018, "A", 1, "A1", "2018_A", 6, 30, 6.8, 0, 1, 0, 2, 3, 4, 5, 0.2, 0.3, "KV-2018", 2, 1, 1, 1])
        writer.writerow(["18I01", 2018, "I", 1, "I1", "2018_I", "", "", "", "", "", "", "", "", "", "", 0.4, -0.4, "LV_2018", 3, 7, 15, 7])
    with matrix.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, delimiter=";")
        writer.writerow(["id", "Ammophila arenaria", "Parnassia palustris"])
        writer.writerow(["01A01", 4, 0])
        writer.writerow(["18A01", 0, 2])
        writer.writerow(["18I01", 6, 9])
    return metadata, matrix


def main() -> int:
    module = load_module()
    with tempfile.TemporaryDirectory(prefix="duinvallei-import-test-") as tmp:
        metadata, matrix = write_fixture(Path(tmp))
        source = module.read_sources(metadata, matrix)
        profile = module.profile_source(source)
        assert profile["metadata_rows"] == 3
        assert profile["matrix_rows"] == 3
        assert profile["stable_plots"] == 2
        assert profile["taxa"] == 2
        assert profile["matrix_cells"] == 6
        assert profile["positive_cells"] == 4
        assert profile["zero_cells"] == 2
        assert profile["excluded_observations"] == 1
        assert profile["analysis_observations"] == 2
        assert profile["analysis_matrix_cells"] == 4
        assert profile["analysis_positive_cells"] == 2
        assert profile["analysis_zero_cells"] == 2

        rows = list(module.iter_matrix_rows(source))
        assert rows[1] == ("01A01", "Parnassia palustris", 0, 0)
        assert rows[-1] == ("18I01", "Parnassia palustris", 9, 1)
        assert module.observation_status("18I01") == (
            "uitgesloten_bronanomalie",
            "159 van 208 taxa positief; vergelijkbare opnamen bevatten maximaal 40 taxa",
        )
        assert module.observation_status("18A01") == ("toegelaten", None)
        assert module.normalized_location("KV-2018") == "KV_2018"
        assert "--skip-column-names" in module.mysql_args("meijendel_root", "127.0.0.1", 3306)

        expected_profile = dict(module.EXPECTED_PROFILE)
        expected_hashes = dict(module.EXPECTED_HASHES)
        module.validate_expected_source(expected_profile, expected_hashes)
        changed_hashes = dict(expected_hashes)
        changed_hashes["metadata"] = "0" * 64
        try:
            module.validate_expected_source(expected_profile, changed_hashes)
        except ValueError as exc:
            assert "SHA-256" in str(exc)
        else:
            raise AssertionError("Een gewijzigd bronbestand werd niet geblokkeerd")

        mysql_calls = []
        original_run_mysql = module.run_mysql
        try:
            def record_mysql(_client, _args, sql):
                mysql_calls.append(sql)
                if sql == "SELECT @@GLOBAL.local_infile":
                    return "0"
                return ""

            module.run_mysql = record_mysql
            module.run_with_local_infile(Path("/usr/local/mysql/bin/mysql"), [], "LOAD TEST")
        finally:
            module.run_mysql = original_run_mysql
        assert mysql_calls == [
            "SELECT @@GLOBAL.local_infile",
            "SET GLOBAL local_infile=ON",
            "LOAD TEST",
            "SET GLOBAL local_infile=OFF",
        ]

        tsv = module.create_import_files(source, Path(tmp) / "staging")
        assert set(tsv) == {"plots", "observations", "taxa", "cover", "soil"}
        assert sum(1 for _ in tsv["cover"].open(encoding="utf-8")) == 7
        assert sum(1 for _ in tsv["soil"].open(encoding="utf-8")) == 20

        load = module.load_sql(
            tsv,
            Path(tmp),
            {"metadata": "a" * 64, "matrix": "b" * 64, "script": "c" * 64},
        )
        assert "USE Meijendel_bronnen" in load
        assert "USE Meijendel;" not in load
        assert "bron_id" in load
        assert "duinvallei-vegetatie-2001-2018" in load
        assert module.DATABASE == "Meijendel_bronnen"

    print("OK: duinvalleivegetatie-importlogica")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
