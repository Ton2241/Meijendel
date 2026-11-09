#!/usr/bin/env python3
"""Render actuele toegankelijkheidsgebieden boven de onderzoekskavels."""

from __future__ import annotations

import argparse
import html
from pathlib import Path

from osgeo import ogr

from migrate_toegankelijkheidsgebieden import Client, _polygon_parts


STATUS_STYLE = {
    "afgesloten": ("#e3342f", "Afgesloten"),
    "toegankelijk": ("#00a651", "Toegankelijk"),
    "toegankelijk_buiten_broedseizoen": ("#f59e0b", "Toegankelijk buiten broedseizoen"),
    "toegankelijk_met_toegangskaart": ("#2563eb", "Toegankelijk met toegangskaart"),
}


def exterior_xy(polygon: ogr.Geometry) -> list[tuple[float, float]]:
    ring = polygon.GetGeometryRef(0)
    return [(ring.GetX(index), ring.GetY(index)) for index in range(ring.GetPointCount())]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database", default="Meijendel")
    parser.add_argument("--output", type=Path, required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    client = Client(args.database)

    plots = []
    for line in client.sql(
        "SELECT kavel_nummer,HEX(ST_AsBinary(geom)) FROM plots "
        "WHERE geom IS NOT NULL AND ST_IsValid(geom) ORDER BY kavel_nummer"
    ).splitlines():
        kavel, geometry_hex = line.split("\t")
        plots.append((kavel, ogr.CreateGeometryFromWkb(bytes.fromhex(geometry_hex))))

    areas = []
    for line in client.sql(
        "SELECT g.gebied_code,v.status_code,HEX(ST_AsBinary(v.geometrie)) "
        "FROM v_toegankelijkheidsgebied_actueel v "
        "JOIN toegankelijkheidsgebied g USING(gebied_id) ORDER BY g.gebied_code"
    ).splitlines():
        code, status, geometry_hex = line.split("\t")
        if status not in STATUS_STYLE:
            raise RuntimeError(f"Geen kaartstijl voor status {status}")
        areas.append((code, status, ogr.CreateGeometryFromWkb(bytes.fromhex(geometry_hex))))

    xmin = min(geometry.GetEnvelope()[0] for _, geometry in plots)
    xmax = max(geometry.GetEnvelope()[1] for _, geometry in plots)
    ymin = min(geometry.GetEnvelope()[2] for _, geometry in plots)
    ymax = max(geometry.GetEnvelope()[3] for _, geometry in plots)
    width, height = 1100, 1350
    margin, title_space, legend_space = 55, 150, 25
    scale = min((width - 2 * margin) / (xmax - xmin), (height - title_space - legend_space - margin) / (ymax - ymin))
    map_width = (xmax - xmin) * scale
    map_height = (ymax - ymin) * scale
    x_offset = (width - map_width) / 2
    y_offset = title_space + (height - title_space - legend_space - map_height) / 2

    def point_xy(x: float, y: float) -> tuple[float, float]:
        return x_offset + (x - xmin) * scale, y_offset + (ymax - y) * scale

    def polygon_points(polygon: ogr.Geometry) -> str:
        return " ".join(f"{px:.2f},{py:.2f}" for px, py in (point_xy(x, y) for x, y in exterior_xy(polygon)))

    svg = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        '<style>text{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}.label{font-size:17px;font-weight:600;paint-order:stroke;stroke:white;stroke-width:4px;stroke-linejoin:round}.legend{font-size:17px}.title{font-size:25px;font-weight:700}</style>',
        f'<text class="title" x="{width / 2}" y="34" text-anchor="middle">Meijendel: kavels en {len(areas)} actuele toegankelijkheidsgebieden</text>',
    ]
    for _, geometry in plots:
        for polygon in _polygon_parts(geometry):
            svg.append(f'<polygon points="{polygon_points(polygon)}" fill="#f4f4f4"/>')
    for _, status, geometry in areas:
        color, _ = STATUS_STYLE[status]
        for polygon in _polygon_parts(geometry):
            svg.append(f'<polygon points="{polygon_points(polygon)}" fill="{color}" fill-opacity="0.34" stroke="{color}" stroke-width="4.2" stroke-linejoin="round"/>')
    for kavel, geometry in plots:
        for polygon in _polygon_parts(geometry):
            svg.append(f'<polygon points="{polygon_points(polygon)}" fill="none" stroke="#333333" stroke-width="1.1" stroke-linejoin="round"/>')
        point = geometry.PointOnSurface()
        px, py = point_xy(point.GetX(), point.GetY())
        svg.append(f'<text class="label" x="{px:.2f}" y="{py:.2f}" text-anchor="middle" dominant-baseline="middle">{html.escape(kavel)}</text>')

    used = [status for status in STATUS_STYLE if any(area_status == status for _, area_status, _ in areas)]
    legend_x, legend_y = 60, 75
    for index, status in enumerate(used):
        color, label = STATUS_STYLE[status]
        x = legend_x + (index % 2) * 520
        y = legend_y + (index // 2) * 38
        svg.append(f'<rect x="{x}" y="{y - 18}" width="28" height="22" rx="2" fill="{color}" fill-opacity="0.5" stroke="{color}" stroke-width="2"/>')
        svg.append(f'<text class="legend" x="{x + 40}" y="{y}" dominant-baseline="middle">{html.escape(label)}</text>')
    svg.append('</svg>')
    args.output.write_text("\n".join(svg) + "\n", encoding="utf-8")
    print(args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
