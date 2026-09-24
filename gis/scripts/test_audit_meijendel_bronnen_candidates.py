#!/usr/bin/env python3
"""Unitchecks voor de audit van niet-geolokaliseerde brongegevens."""

from __future__ import annotations

import importlib.util
from pathlib import Path


SCRIPT = Path(__file__).with_name("audit_meijendel_bronnen_candidates.py")


def load_module():
    spec = importlib.util.spec_from_file_location("audit_meijendel_bronnen", SCRIPT)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    module = load_module()
    rows = module.classify_rows(
        [
            {
                "bron_tabel": "duinvallei_opname",
                "recordaantal": 488,
                "jaar_van": 2001,
                "jaar_tot": 2018,
                "locatiemethode": "benoemde_locatie",
                "ruimtelijke_status": "geen_lokalisatie",
            },
            {
                "bron_tabel": "vogelstand_1924",
                "recordaantal": 204,
                "jaar_van": 1924,
                "jaar_tot": 1924,
                "locatiemethode": "geen",
                "ruimtelijke_status": "context_alleen",
            },
        ]
    )
    assert [row["migratieadvies"] for row in rows] == ["verplaatsen", "verplaatsen"]

    unknown = module.classify_rows(
        [
            {
                "bron_tabel": "onbekende_tabel",
                "recordaantal": 2,
                "jaar_van": 1970,
                "jaar_tot": 1971,
                "locatiemethode": "geen",
                "ruimtelijke_status": "geen_lokalisatie",
            }
        ]
    )
    assert unknown[0]["migratieadvies"] == "afzonderlijk_besluit_nodig"

    reference = module.classify_rows(
        [
            {
                "bron_tabel": "soorten",
                "recordaantal": 500,
                "jaar_van": None,
                "jaar_tot": None,
                "locatiemethode": "nvt",
                "ruimtelijke_status": "nvt",
                "tabelrol": "referentie",
            }
        ]
    )
    assert reference[0]["migratieadvies"] == "nvt_referentietabel"

    try:
        module.validate_known_sources(rows[:1])
    except ValueError as exc:
        assert "vogelstand_1924" in str(exc)
    else:
        raise AssertionError("ontbrekende bekende bronfamilie werd niet geblokkeerd")

    print("OK: auditclassificatie Meijendel_bronnen")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
