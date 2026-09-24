#!/usr/bin/env python3
"""Contracttests voor de Zotero-naar-bronnen-synchronisatie."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path


SCRIPT = Path(__file__).with_name("sync_zotero_meijendel_bronnen.py")
FIXTURE = Path(__file__).with_name("fixtures") / "zotero_meijendel_items.json"


def load_module():
    spec = importlib.util.spec_from_file_location("sync_zotero_meijendel_bronnen", SCRIPT)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    module = load_module()
    assert module.mysql_text_literal("O'Brien") == "CONVERT(0x4f27427269656e USING utf8mb4)"
    assert module.mysql_text_literal(None) == "NULL"
    items = json.loads(FIXTURE.read_text(encoding="utf-8"))
    assert module.is_bibliographic(items[0]) is True
    assert module.is_bibliographic(items[2]) is False

    minimal = module.normalize_item(items[1])
    assert minimal["titel"] == "Ongetitelde reeks"
    assert minimal["jaar"] is None
    assert minimal["auteurs"] == []
    assert minimal["citation_chicago"] == "Ongetitelde reeks."
    assert module.fallback_chicago(
        {"title": "Jaarverslag", "date": "2024", "publisher": "VWG Meijendel"}
    ) == "Jaarverslag. VWG Meijendel, 2024."

    article = module.normalize_item(items[0])
    assert article["zotero_item_key"] == "ABCD1234"
    assert article["citation_key"] == "teller_vlinders_2024"
    assert article["doi"] == "10.1234/voorbeeld"
    assert article["url"] == "https://example.org/vlinders"
    assert article["auteurs"] == [
        {"familienaam": "Teller", "voornamen": "A.", "naam_letterlijk": None}
    ]
    cli_sql = module.build_cli_sync_sql([article])
    assert "START TRANSACTION" in cli_sql
    assert "COMMIT" in cli_sql
    assert "niet_meer_in_export" in cli_sql
    assert module.mysql_text_literal("zotero:ABCD1234") in cli_sql

    serialized = json.dumps([minimal, article], ensure_ascii=False).casefold()
    assert "/users/" not in serialized
    assert "zotero/storage" not in serialized
    assert "attachment" not in serialized
    assert "path" not in serialized

    assert module.unique_exact_collection(
        [{"key": "ONE", "data": {"name": "Meijendel"}}], "Meijendel"
    ) == "ONE"
    try:
        module.unique_exact_collection(
            [
                {"key": "ONE", "data": {"name": "Meijendel"}},
                {"key": "TWO", "data": {"name": "Meijendel"}},
            ],
            "Meijendel",
        )
    except ValueError as exc:
        assert "meer dan één" in str(exc).casefold()
    else:
        raise AssertionError("Dubbele exacte collectie werd niet geblokkeerd")

    deduplicated = module.deduplicate_items([items[0], items[1], items[0]])
    assert [item["key"] for item in deduplicated] == ["ABCD1234", "MINI0001"]

    print("OK: Zotero-synchronisatiecontract Meijendel_bronnen")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
