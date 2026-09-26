#!/usr/bin/env python3
"""Gerichte tests voor de import van fase-1-bronnen."""

import importlib.util
import tempfile
from pathlib import Path


SCRIPT = Path(__file__).with_name("import_external_ecology_sources.py")


def load_module():
    spec = importlib.util.spec_from_file_location("external_import", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    module = load_module()

    stowa = {
        "_core_id": "496163",
        "occurrenceID": "496163",
        "fieldNumber": "HHD-950-010",
        "eventDate": "2007-02-19",
        "_jaar": "2007",
        "decimalLatitude": "52.12383334",
        "decimalLongitude": "4.30933692",
        "coordinateUncertaintyInMeters": "10",
        "locality": "Meijendel, infiltratieplas 13",
        "samplingProtocol": "catch",
        "scientificName": "Asterionella formosa",
        "taxonRank": "species",
        "basisOfRecord": "HumanObservation",
        "catalogNumber": "496163",
    }
    assert module.stowa_event_key(stowa) == "HHD-950-010|2007-02-19|52.12383334|4.30933692"

    explicit_museum = {
        "_binnen_basisgebied": "1",
        "_expliciet_meijendel": "1",
        "eventDate": "1955-07-01",
        "occurrenceID": "NMR1",
    }
    assert module.admit_museum_row(explicit_museum)
    assert not module.admit_museum_row({**explicit_museum, "eventDate": ""})
    assert not module.admit_museum_row({**explicit_museum, "_expliciet_meijendel": "0"})

    assert module.admit_lvd_event({"coordinateUncertaintyInMeters": "50"})
    assert not module.admit_lvd_event({"coordinateUncertaintyInMeters": "100"})
    assert module.event_period("1955-07-", "1955") == ("1955-07-01", "1955-07-31", "maand")
    assert module.event_period("1938-07-01/1938-07-31", "1938") == (
        "1938-07-01", "1938-07-31", "interval"
    )
    assert module.event_period("2018-09-19", "2018") == ("2018-09-19", "2018-09-19", "exact")
    assert module.museum_canonical_name({
        "scientificName": "Agrotis puta (Hübner, 1803)", "taxonRank": "species"
    }) == "Agrotis puta"
    assert module.museum_canonical_name({
        "scientificName": "Cercyon (Cercyon) bifenestratus Küster, 1851",
        "scientificNameAuthorship": "Küster, 1851", "taxonRank": "species"
    }) == "Cercyon bifenestratus"

    with tempfile.TemporaryDirectory(prefix="external-ecology-test-") as tmp:
        target = Path(tmp)
        files = module.write_import_files(
            target,
            stowa_rows=[stowa],
            stowa_measurements={"496163": ("107", "aantal/ml", "occurrenceDensity")},
            endure_events=[{
                "_core_id": "E1", "eventID": "E1", "eventDate": "2018-09-19",
                "_jaar": "2018", "decimalLatitude": "52.15", "decimalLongitude": "4.33",
                "coordinateUncertaintyInMeters": "10", "samplingProtocol": "sweep",
                "sampleSizeValue": "5", "sampleSizeUnit": "minute",
            }],
            endure_results=[{
                "_core_id": "E1", "occurrenceID": "O1", "scientificName": "Acaridae",
                "occurrenceStatus": "absent", "individualCount": "0", "taxonRank": "FAMILY",
                "basisOfRecord": "HumanObservation",
            }],
            museum_sources={"nmr": ([explicit_museum | {
                "_core_id": "NMR1", "_jaar": "1955", "decimalLatitude": "52.13",
                "decimalLongitude": "4.32", "coordinateUncertaintyInMeters": "111",
                "locality": "Wassenaar, Meijendel, Bierlap", "scientificName": "Testus alba",
            }], module.SOURCE_CONFIG["nmr"])},
            lvd_events=[],
            lvd_releves={},
            lvd_occurrences=[],
        )
        assert set(files) == {"datasets", "events", "results"}
        assert files["datasets"].read_text(encoding="utf-8").count("\n") == 4
        assert files["events"].read_text(encoding="utf-8").count("\n") == 4
        assert files["results"].read_text(encoding="utf-8").count("\n") == 4
        sql = module.load_sql(files, database="Meijendel_phase12_test")
        assert "USE Meijendel_phase12_test" in sql
        assert "externe_ecologie_dataset" in sql
        assert "START TRANSACTION" in sql and "COMMIT" in sql

    print("OK: externe ecologie-importlogica")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
