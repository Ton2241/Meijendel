#!/usr/bin/env python3
"""Gerichte tests voor de openbare FFV- en GBIF-importeur."""

from __future__ import annotations

import importlib.util
from pathlib import Path


SCRIPT = Path(__file__).with_name("import_ndff_public_gbif.py")


def load_module():
    spec = importlib.util.spec_from_file_location("ndff_public_import", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    module = load_module()
    assert module.group_codes("Geleedpotigen (overig)|Kreeftachtigen") == (
        "geleedpotigen_overig",
        "kreeftachtigen",
    )
    assert module.group_codes("Kranswieren, wieren en algen") == (
        "kranswieren_wieren_algen",
    )
    assert module.group_codes("Amfibieën") == ("amfibieen",)
    assert module.ffv_species_key("Amfibieën", "Rugstreeppad", "Epidalea calamita") == module.sha256_text(
        "Amfibieën\x1fRugstreeppad\x1fEpidalea calamita"
    )
    existing_hash = "a" * 64
    assert module.open_identity_hash(existing_hash) == existing_hash
    assert module.open_identity_hash("https://example.test/waarneming/1") == module.sha256_text(
        "https://example.test/waarneming/1"
    )

    moved = module.gbif_event_flags(
        {
            "locationID": "pf12",
            "eventDate": "05/08/1956",
            "eventRemarks": "number of mammals unreliable; state not fully described",
        }
    )
    assert moved == {
        "is_verplaatst_blok_7_18": 1,
        "is_vergelijkingsblik_1959": 0,
        "heeft_predatie_of_zoogdierrisico": 1,
        "geen_harde_nul": 1,
    }
    comparison = module.gbif_event_flags(
        {"locationID": "pf115", "eventDate": "01/06/1959", "eventRemarks": ""}
    )
    assert comparison["is_vergelijkingsblik_1959"] == 1
    assert comparison["heeft_predatie_of_zoogdierrisico"] == 0

    valid = module.gbif_occurrence_status("event-1", {"event-1"})
    orphan = module.gbif_occurrence_status("missing", {"event-1"})
    assert valid == {"event_id": "event-1", "is_verweesd": 0, "referentieel_geldig": 1}
    assert orphan == {"event_id": None, "is_verweesd": 1, "referentieel_geldig": 0}

    assert module.mysql_field(None) == r"\N"
    assert module.mysql_field("a\tb\nc\\d") == r"a\tb\nc\\d"
    assert module.mysql_connection_args("meijendel_root", "127.0.0.1", 3306) == [
        "--login-path=meijendel_root",
        "--protocol=tcp",
        "--host=127.0.0.1",
        "--port=3306",
        "--local-infile=1",
        "--binary-mode",
    ]
    assert "join ndff_sovon_plot p" in module.gbif_plot_link_sql().casefold()
    assert "plots-huidig" not in module.gbif_plot_link_sql().casefold()
    print("OK: openbare FFV/GBIF-importlogica")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
