#!/usr/bin/env python3
import importlib.util
from pathlib import Path
from urllib.parse import parse_qs, urlparse


SCRIPT = Path(__file__).with_name("luchtfoto_download.py")
SPEC = importlib.util.spec_from_file_location("luchtfoto_download", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def test_tile_grid_covers_shared_extent_without_gaps():
    tiles = MODULE.tile_grid((79596, 458356, 86476, 464392), 3440, 3018, 2, 2)
    assert len(tiles) == 4
    assert tiles[0]["bbox"] == (79596.0, 461374.0, 83036.0, 464392.0)
    assert tiles[-1]["bbox"] == (83036.0, 458356.0, 86476.0, 461374.0)
    assert all(tile["width"] == 1720 and tile["height"] == 1509 for tile in tiles)


def test_wms_url_uses_supported_jpeg_and_rd_coordinates():
    url = MODULE.wms_url("https://example.test/wms", "2020_ortho25", (1, 2, 3, 4), 100, 200)
    query = parse_qs(urlparse(url).query)
    assert query["LAYERS"] == ["2020_ortho25"]
    assert query["SRS"] == ["EPSG:28992"]
    assert query["FORMAT"] == ["image/jpeg"]
    assert query["BBOX"] == ["1,2,3,4"]


if __name__ == "__main__":
    for name, value in sorted(globals().items()):
        if name.startswith("test_") and callable(value):
            value()
    print("OK: luchtfoto-downloadcontracten")
