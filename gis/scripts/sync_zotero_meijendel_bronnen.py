#!/usr/bin/env python3
"""Synchroniseer Zotero-metadata naar Meijendel_bronnen, zonder bijlagen of paden."""

from __future__ import annotations

import argparse
import html
import json
import re
import sys
from datetime import date
from html.parser import HTMLParser
from typing import Iterable
from urllib.error import URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


DEFAULT_BASE_URL = "http://127.0.0.1:23119"
STYLE = "chicago-fullnote-bibliography"
RULE_VERSION = "meijendel-bronnen-v1"
EXCLUDED_ITEM_TYPES = {"attachment", "note", "annotation"}


class _TextExtractor(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.parts: list[str] = []

    def handle_data(self, data: str) -> None:
        self.parts.append(data)


def citation_text(value: str | None) -> str:
    parser = _TextExtractor()
    parser.feed(value or "")
    return re.sub(r"\s+", " ", html.unescape("".join(parser.parts))).strip()


def api_json(base_url: str, route: str, params: dict | None = None):
    query = f"?{urlencode(params, doseq=True)}" if params else ""
    request = Request(
        f"{base_url.rstrip('/')}{route}{query}",
        headers={"Accept": "application/json", "Zotero-API-Version": "3"},
    )
    try:
        with urlopen(request, timeout=15) as response:
            return json.load(response)
    except (URLError, OSError, TimeoutError) as exc:
        raise RuntimeError("Zotero Local API niet bereikbaar") from exc


def fetch_pages(base_url: str, route: str, params: dict | None = None) -> list[dict]:
    start = 0
    collected: list[dict] = []
    while True:
        query = dict(params or {})
        query.update({"limit": 100, "start": start})
        page = api_json(base_url, route, query)
        if not isinstance(page, list):
            raise ValueError(f"Onverwacht Zotero-antwoord voor {route}")
        collected.extend(page)
        if len(page) < 100:
            return collected
        start += len(page)


def unique_exact_collection(collections: list[dict], name: str) -> str:
    matches = [
        row for row in collections
        if (row.get("data") or {}).get("name") == name or row.get("name") == name
    ]
    if not matches:
        raise ValueError(f"Zotero-collectie met exacte naam {name!r} ontbreekt")
    if len(matches) > 1:
        raise ValueError(f"Meer dan één Zotero-collectie heet exact {name!r}")
    return str(matches[0].get("key") or (matches[0].get("data") or {}).get("key"))


def find_collection(base_url: str, name: str) -> tuple[str, list[dict]]:
    collections = fetch_pages(base_url, "/api/users/0/collections")
    return unique_exact_collection(collections, name), collections


def collection_tree_keys(collections: list[dict], root_key: str) -> list[str]:
    children: dict[str, list[str]] = {}
    for row in collections:
        data = row.get("data") or row
        parent = data.get("parentCollection")
        key = row.get("key") or data.get("key")
        if parent and key:
            children.setdefault(str(parent), []).append(str(key))
    result: list[str] = []
    queue = [root_key]
    while queue:
        key = queue.pop(0)
        if key in result:
            continue
        result.append(key)
        queue.extend(sorted(children.get(key, [])))
    return result


def fetch_top_items(base_url: str, collection_key: str) -> list[dict]:
    return fetch_pages(
        base_url,
        f"/api/users/0/collections/{collection_key}/items/top",
        {"include": "data,bib", "style": STYLE},
    )


def fetch_chicago_citation(base_url: str, item_key: str) -> str:
    item = api_json(
        base_url,
        f"/api/users/0/items/{item_key}",
        {"include": "data,bib", "style": STYLE},
    )
    return citation_text(item.get("bib"))


def deduplicate_items(items: Iterable[dict]) -> list[dict]:
    unique: dict[str, dict] = {}
    for item in items:
        key = str(item.get("key") or (item.get("data") or {}).get("key") or "")
        if not key:
            raise ValueError("Zotero-item zonder item key")
        unique[key] = item
    return list(unique.values())


def is_bibliographic(item: dict) -> bool:
    return (item.get("data") or {}).get("itemType") not in EXCLUDED_ITEM_TYPES


def _year(value: str | None) -> int | None:
    match = re.search(r"(?<!\d)(1[0-9]{3}|20[0-9]{2}|2100)(?!\d)", value or "")
    return int(match.group(1)) if match else None


def _citation_key(data: dict) -> str | None:
    if data.get("citationKey"):
        return str(data["citationKey"]).strip() or None
    match = re.search(r"(?im)^citation key:\s*(\S+)\s*$", data.get("extra") or "")
    return match.group(1) if match else None


def _doi(value: str | None) -> str | None:
    cleaned = (value or "").strip()
    cleaned = re.sub(r"^https?://(?:dx\.)?doi\.org/", "", cleaned, flags=re.I)
    return cleaned or None


def _https_url(value: str | None) -> str | None:
    cleaned = (value or "").strip()
    return cleaned if cleaned.startswith("https://") else None


def _access_date(value: str | None) -> str | None:
    cleaned = (value or "").strip()[:10]
    try:
        return date.fromisoformat(cleaned).isoformat() if cleaned else None
    except ValueError:
        return None


def fallback_chicago(data: dict) -> str:
    """Maak alleen bij een lege Zotero-CSL-uitvoer een leesbare verwijzing."""
    title = str(data.get("title") or "Zonder titel").strip() or "Zonder titel"
    creators = []
    for creator in data.get("creators") or []:
        literal = (creator.get("name") or "").strip()
        first = (creator.get("firstName") or "").strip()
        last = (creator.get("lastName") or "").strip()
        name = literal or ", ".join(part for part in (last, first) if part)
        if name:
            creators.append(name)
    lead = f"{'; '.join(creators)}. {title}." if creators else f"{title}."
    publisher = str(data.get("publisher") or data.get("institution") or "").strip()
    year = _year(data.get("date"))
    publication = ", ".join(part for part in (publisher, str(year) if year else "") if part)
    identifier = _doi(data.get("DOI"))
    url = _https_url(data.get("url"))
    tail = f" https://doi.org/{identifier}." if identifier else (f" {url}." if url else "")
    return f"{lead}{f' {publication}.' if publication else ''}{tail}"


def normalize_item(item: dict) -> dict:
    if not is_bibliographic(item):
        raise ValueError("Niet-bibliografisch Zotero-item")
    data = item.get("data") or {}
    key = str(item.get("key") or data.get("key") or "").strip()
    if not key:
        raise ValueError("Zotero-item zonder item key")
    title = str(data.get("title") or "Zonder titel").strip() or "Zonder titel"
    container = next(
        (
            str(data[field]).strip()
            for field in (
                "publicationTitle", "bookTitle", "proceedingsTitle", "websiteTitle",
                "repository", "institution",
            )
            if data.get(field)
        ),
        None,
    )
    authors = []
    for creator in data.get("creators") or []:
        literal = (creator.get("name") or "").strip() or None
        first = (creator.get("firstName") or "").strip() or None
        last = (creator.get("lastName") or "").strip() or None
        if literal or first or last:
            authors.append(
                {"familienaam": last, "voornamen": first, "naam_letterlijk": literal}
            )
    tags = sorted(
        {str(row.get("tag") or "").strip() for row in data.get("tags") or []}
        - {""}
    )
    citation = citation_text(item.get("bib")) or fallback_chicago(data)
    return {
        "zotero_item_key": key,
        "citation_key": _citation_key(data),
        "item_type": str(data.get("itemType") or "document"),
        "titel": title,
        "jaar": _year(data.get("date")),
        "container_titel": container,
        "uitgever": (str(data.get("publisher") or "").strip() or None),
        "volume": (str(data.get("volume") or "").strip() or None),
        "nummer": (str(data.get("issue") or "").strip() or None),
        "paginas": (str(data.get("pages") or "").strip() or None),
        "doi": _doi(data.get("DOI")),
        "url": _https_url(data.get("url")),
        "geraadpleegd_op": _access_date(data.get("accessDate")),
        "trefwoorden": tags,
        "citation_chicago": citation,
        "auteurs": authors,
    }


def collect_items(base_url: str, collection_name: str) -> tuple[list[dict], list[str], int]:
    root_key, collections = find_collection(base_url, collection_name)
    keys = collection_tree_keys(collections, root_key)
    raw = deduplicate_items(
        item for collection_key in keys for item in fetch_top_items(base_url, collection_key)
    )
    included = [normalize_item(item) for item in raw if is_bibliographic(item)]
    return included, keys, len(raw) - len(included)


def sync_items(connection, items: list[dict]) -> dict[str, int]:
    current_keys = [item["zotero_item_key"] for item in items]
    with connection.cursor() as cursor:
        for item in items:
            cursor.execute(
                """
                INSERT INTO bron
                  (bron_sleutel,bron_type,titel,omschrijving,bronorganisatie,jaar_van,jaar_tot,
                   geografische_status,geografische_toelichting,analyse_status,rechten_status,
                   regelversie)
                VALUES (%s,'literatuur',%s,%s,%s,%s,%s,'nvt',%s,'context_alleen',
                        'open_metadata',%s)
                ON DUPLICATE KEY UPDATE titel=VALUES(titel),omschrijving=VALUES(omschrijving),
                  bronorganisatie=VALUES(bronorganisatie),jaar_van=VALUES(jaar_van),
                  jaar_tot=VALUES(jaar_tot),geografische_status='nvt',
                  geografische_toelichting=VALUES(geografische_toelichting),
                  analyse_status='context_alleen',rechten_status='open_metadata',
                  regelversie=VALUES(regelversie)
                """,
                (
                    f"zotero:{item['zotero_item_key']}", item["titel"],
                    item["citation_chicago"], item["container_titel"], item["jaar"],
                    item["jaar"], "Bibliografische metadata; geen waarnemingslocatie van toepassing.",
                    RULE_VERSION,
                ),
            )
            cursor.execute(
                "SELECT bron_id FROM bron WHERE bron_sleutel=%s",
                (f"zotero:{item['zotero_item_key']}",),
            )
            bron_id = cursor.fetchone()[0]
            cursor.execute(
                """
                INSERT INTO literatuur
                  (bron_id,zotero_item_key,citation_key,item_type,publicatiejaar,container_titel,
                   uitgever,volume,nummer,paginas,doi,url,geraadpleegd_op,trefwoorden,
                   citation_chicago,citation_style,zotero_status)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,'actueel')
                ON DUPLICATE KEY UPDATE citation_key=VALUES(citation_key),
                  item_type=VALUES(item_type),publicatiejaar=VALUES(publicatiejaar),
                  container_titel=VALUES(container_titel),uitgever=VALUES(uitgever),
                  volume=VALUES(volume),nummer=VALUES(nummer),paginas=VALUES(paginas),
                  doi=VALUES(doi),url=VALUES(url),geraadpleegd_op=VALUES(geraadpleegd_op),
                  trefwoorden=VALUES(trefwoorden),citation_chicago=VALUES(citation_chicago),
                  citation_style=VALUES(citation_style),zotero_status='actueel',
                  gesynchroniseerd_op=CURRENT_TIMESTAMP(6)
                """,
                (
                    bron_id, item["zotero_item_key"], item["citation_key"], item["item_type"],
                    item["jaar"], item["container_titel"], item["uitgever"], item["volume"],
                    item["nummer"], item["paginas"], item["doi"], item["url"],
                    item["geraadpleegd_op"], json.dumps(item["trefwoorden"], ensure_ascii=False),
                    item["citation_chicago"], STYLE,
                ),
            )
            cursor.execute("DELETE FROM literatuur_auteur WHERE bron_id=%s", (bron_id,))
            for position, author in enumerate(item["auteurs"], start=1):
                cursor.execute(
                    """
                    INSERT INTO literatuur_auteur
                      (bron_id,volgnummer,familienaam,voornamen,naam_letterlijk)
                    VALUES (%s,%s,%s,%s,%s)
                    """,
                    (
                        bron_id, position, author["familienaam"], author["voornamen"],
                        author["naam_letterlijk"],
                    ),
                )
        if current_keys:
            placeholders = ",".join(["%s"] * len(current_keys))
            cursor.execute(
                f"UPDATE literatuur SET zotero_status='niet_meer_in_export' "
                f"WHERE zotero_item_key NOT IN ({placeholders})",
                tuple(current_keys),
            )
            marked_stale = cursor.rowcount
        else:
            raise ValueError("Volledige Zotero-export bevat nul bibliografische items")
    connection.commit()
    return {"actueel": len(items), "niet_meer_in_export_gemarkeerd": marked_stale}


def connect_mysql(options):
    try:
        import pymysql
    except ImportError as exc:
        raise RuntimeError("PyMySQL ontbreekt; gebruik de projectruntime met PyMySQL") from exc
    return pymysql.connect(
        host=options.host,
        port=options.port,
        user=options.user,
        password=options.password,
        database=options.database,
        charset="utf8mb4",
        autocommit=False,
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL)
    parser.add_argument("--collection", default="Meijendel")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=3306)
    parser.add_argument("--database", default="Meijendel_bronnen")
    parser.add_argument("--user")
    parser.add_argument("--password")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--dry-run", action="store_true")
    mode.add_argument("--execute", action="store_true")
    options = parser.parse_args()
    try:
        items, collection_keys, filtered = collect_items(options.base_url, options.collection)
    except (RuntimeError, ValueError) as exc:
        print(str(exc), file=sys.stderr)
        return 2
    report = {
        "status": "VALID",
        "collection": options.collection,
        "collection_count": len(collection_keys),
        "bibliographic_items": len(items),
        "excluded_attachments_notes_annotations": filtered,
        "citation_style": STYLE,
        "local_paths_exported": 0,
    }
    if options.dry_run:
        print(json.dumps(report, indent=2, ensure_ascii=False))
        return 0
    if not options.user or options.password is None:
        parser.error("--execute vereist --user en --password")
    connection = connect_mysql(options)
    try:
        report["database"] = sync_items(connection, items)
    except Exception:
        connection.rollback()
        raise
    finally:
        connection.close()
    report["status"] = "PASS"
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
