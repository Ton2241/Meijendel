#!/usr/bin/env python3
"""Download geselecteerde PDOK-luchtfoto's op het gedeelde 2-meterrooster."""

from __future__ import annotations

import argparse
import hashlib
import json
import urllib.parse
import urllib.request
from pathlib import Path

import numpy as np
import rasterio
from rasterio.io import MemoryFile
from rasterio.transform import from_bounds
from rasterio.windows import Window


RGB_SERVICE = "https://service.pdok.nl/hwh/luchtfotorgb/wms/v1_0"
CIR_SERVICE = "https://service.pdok.nl/hwh/luchtfotocir/wms/v1_0"
YEARS = (2016, 2020, 2022, 2023, 2024)
EXTENT = (79596, 458356, 86476, 464392)
WIDTH = 3440
HEIGHT = 3018


def tile_grid(extent, width, height, columns=2, rows=2):
    xmin, ymin, xmax, ymax = map(float, extent)
    if width % columns or height % rows:
        raise ValueError("Rasterafmetingen moeten exact door het tegelrooster deelbaar zijn.")
    tile_width = width // columns
    tile_height = height // rows
    pixel_x = (xmax - xmin) / width
    pixel_y = (ymax - ymin) / height
    result = []
    for row in range(rows):
        top = ymax - row * tile_height * pixel_y
        bottom = top - tile_height * pixel_y
        for column in range(columns):
            left = xmin + column * tile_width * pixel_x
            right = left + tile_width * pixel_x
            result.append({
                "row": row, "column": column,
                "width": tile_width, "height": tile_height,
                "bbox": (left, bottom, right, top),
            })
    return result


def _coordinate(value):
    return str(int(value)) if float(value).is_integer() else f"{value:.9f}".rstrip("0").rstrip(".")


def wms_url(service, layer, bbox, width, height):
    parameters = {
        "SERVICE": "WMS", "VERSION": "1.1.1", "REQUEST": "GetMap",
        "LAYERS": layer, "STYLES": "", "SRS": "EPSG:28992",
        "BBOX": ",".join(_coordinate(value) for value in bbox),
        "WIDTH": str(width), "HEIGHT": str(height), "FORMAT": "image/jpeg",
    }
    return service + "?" + urllib.parse.urlencode(parameters)


def download_bytes(url):
    request = urllib.request.Request(url, headers={"User-Agent": "Meijendel-onderzoek/1.0"})
    with urllib.request.urlopen(request, timeout=120) as response:
        payload = response.read()
    if payload.lstrip().startswith(b"<?xml") or b"ServiceException" in payload[:500]:
        raise RuntimeError(payload.decode("utf-8", errors="replace"))
    return payload


def download_grid(service, layer, output):
    tiles = tile_grid(EXTENT, WIDTH, HEIGHT)
    profile = {
        "driver": "GTiff", "width": WIDTH, "height": HEIGHT, "count": 3,
        "dtype": "uint8", "crs": "EPSG:28992",
        "transform": from_bounds(*EXTENT, WIDTH, HEIGHT),
        "compress": "jpeg", "jpeg_quality": 90, "tiled": True,
        "blockxsize": 256, "blockysize": 256,
    }
    urls = []
    with rasterio.open(output, "w", **profile) as destination:
        for tile in tiles:
            url = wms_url(service, layer, tile["bbox"], tile["width"], tile["height"])
            urls.append(url)
            payload = download_bytes(url)
            with MemoryFile(payload) as memory:
                with memory.open() as source:
                    values = source.read()
            if values.shape != (3, tile["height"], tile["width"]):
                raise ValueError(f"Onverwachte WMS-tegelvorm voor {layer}: {values.shape}")
            destination.write(values.astype(np.uint8), window=Window(
                tile["column"] * tile["width"], tile["row"] * tile["height"],
                tile["width"], tile["height"],
            ))
    return urls


def file_sha256(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("uitvoer", type=Path)
    args = parser.parse_args()
    args.uitvoer.mkdir(parents=True, exist_ok=True)
    records = []
    for year in YEARS:
        for kind, service, layer in (
            ("rgb", RGB_SERVICE, f"{year}_ortho25"),
            ("cir", CIR_SERVICE, f"{year}_ortho25IR"),
        ):
            output = args.uitvoer / f"{kind}_{year}_2m.tif"
            urls = download_grid(service, layer, output)
            records.append({
                "jaar": year, "type": kind, "laag": layer,
                "bestand": output.name, "sha256": file_sha256(output),
                "aanvragen": urls,
            })
            print(f"OK: {output}", flush=True)
    manifest = {
        "bron": "PDOK Luchtfoto RGB/CIR WMS v1_0",
        "beeldjaren": list(YEARS), "bbox_rd": list(EXTENT),
        "pixelgrootte_m": 2, "width": WIDTH, "height": HEIGHT,
        "records": records,
    }
    (args.uitvoer / "luchtfoto_download_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


if __name__ == "__main__":
    main()
