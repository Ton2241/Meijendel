#!/usr/bin/env python3
"""Bouw het afzonderlijke offline Mergin Maps-project voor Meijendel."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path


BASE_BUILDER = (
    Path(__file__).resolve().parents[2]
    / "qfield"
    / "afscheidingen"
    / "build_qfield_afscheidingen.py"
)
SKETCH_COLORS = [
    "#25a244",
    "#f4a261",
    "#d62828",
    "#8b5a2b",
    "#277da1",
    "#111111",
    "#ffffff",
]


def _load_base_builder():
    spec = importlib.util.spec_from_file_location("meijendel_qfield_builder", BASE_BUILDER)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Basisbuilder kon niet worden geladen: {BASE_BUILDER}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


try:
    from qgis.PyQt.QtCore import QCoreApplication, QVariant
    from qgis.PyQt.QtGui import QColor
    from qgis.core import (
        Qgis,
        QgsCoordinateReferenceSystem,
        QgsCoordinateTransformContext,
        QgsDefaultValue,
        QgsEditorWidgetSetup,
        QgsField,
        QgsFields,
        QgsLineSymbol,
        QgsMapLayer,
        QgsProcessing,
        QgsProcessingAlgorithm,
        QgsProcessingException,
        QgsProcessingOutputNumber,
        QgsProcessingOutputString,
        QgsProcessingParameterFile,
        QgsProcessingParameterFolderDestination,
        QgsProcessingParameterVectorLayer,
        QgsProject,
        QgsProperty,
        QgsSingleSymbolRenderer,
        QgsSymbol,
        QgsSymbolLayer,
        QgsSymbolLayerUtils,
        QgsVectorFileWriter,
        QgsVectorLayer,
        QgsWkbTypes,
    )
except ModuleNotFoundError:
    QgsProcessingAlgorithm = object
else:
    BASE = _load_base_builder()

    def _assert_empty_layer(path: Path, layer_name: str) -> None:
        if not path.exists():
            return
        layer = QgsVectorLayer(f"{path}|layername={layer_name}", layer_name, "ogr")
        if not layer.isValid():
            raise QgsProcessingException(
                f"Bestaand veldwerkbestand is niet leesbaar; herbouw is gestopt: {path}"
            )
        if layer.featureCount() > 0:
            raise QgsProcessingException(
                "De pakketmap bevat bestaande veldwerkgegevens; kies een lege "
                "uitvoermap om overschrijven te voorkomen."
            )


    def _ensure_rebuild_is_safe(output_dir: Path) -> None:
        BASE._ensure_rebuild_is_safe(
            output_dir / "veldwerk.gpkg", output_dir / "photos"
        )
        _assert_empty_layer(output_dir / "map_sketches.gpkg", "Map sketches")
        _assert_empty_layer(output_dir / "tracking_layer.gpkg", "tracking_layer")


    def _create_gpkg(
        path: Path, layer_name: str, fields: QgsFields, geometry_type
    ) -> QgsVectorLayer:
        options = QgsVectorFileWriter.SaveVectorOptions()
        options.driverName = "GPKG"
        options.layerName = layer_name
        writer = QgsVectorFileWriter.create(
            str(path),
            fields,
            geometry_type,
            QgsCoordinateReferenceSystem("EPSG:4326"),
            QgsCoordinateTransformContext(),
            options,
        )
        if writer.hasError() != QgsVectorFileWriter.NoError:
            message = writer.errorMessage()
            del writer
            raise QgsProcessingException(
                f"Schrijven van {layer_name} is mislukt: {message}"
            )
        del writer
        layer = QgsVectorLayer(f"{path}|layername={layer_name}", layer_name, "ogr")
        if not layer.isValid():
            raise QgsProcessingException(f"Laag {layer_name} kon niet worden geopend.")
        layer.setReadOnly(False)
        layer.setFlags(
            QgsMapLayer.LayerFlag(
                QgsMapLayer.Identifiable
                + QgsMapLayer.Searchable
                + QgsMapLayer.Removable
            )
        )
        return layer


    def _create_map_sketches(path: Path) -> QgsVectorLayer:
        fields = QgsFields()
        for name, field_type in (
            ("color", QVariant.String),
            ("author", QVariant.String),
            ("created_at", QVariant.DateTime),
            ("width", QVariant.Double),
            ("attr1", QVariant.Double),
            ("attr2", QVariant.Double),
            ("attr3", QVariant.String),
            ("attr4", QVariant.String),
        ):
            fields.append(QgsField(name, field_type))
        layer = _create_gpkg(
            path, "Map sketches", fields, QgsWkbTypes.MultiLineStringZM
        )
        layer.setEditorWidgetSetup(
            layer.fields().indexFromName("fid"), QgsEditorWidgetSetup("Hidden", {})
        )
        layer.setDefaultValueDefinition(
            layer.fields().indexFromName("author"), QgsDefaultValue("@mm_username")
        )
        layer.setDefaultValueDefinition(
            layer.fields().indexFromName("created_at"), QgsDefaultValue("now()")
        )
        layer.setDefaultValueDefinition(
            layer.fields().indexFromName("width"), QgsDefaultValue("0.6")
        )
        symbol = QgsLineSymbol.createSimple(
            {
                "line_width": "0.6",
                "line_color": QgsSymbolLayerUtils.encodeColor(QColor("#ffffff")),
            }
        )
        symbol_layer = symbol.takeSymbolLayer(0)
        symbol_layer.setDataDefinedProperty(
            QgsSymbolLayer.PropertyStrokeColor, QgsProperty.fromExpression('"color"')
        )
        symbol_layer.setDataDefinedProperty(
            QgsSymbolLayer.PropertyStrokeWidth, QgsProperty.fromExpression('"width"')
        )
        symbol.appendSymbolLayer(symbol_layer)
        layer.setRenderer(QgsSingleSymbolRenderer(symbol))
        return layer


    def _create_tracking_layer(path: Path) -> QgsVectorLayer:
        fields = QgsFields()
        for name, field_type in (
            ("tracking_start_time", QVariant.DateTime),
            ("tracking_end_time", QVariant.DateTime),
            ("total_distance", QVariant.Double),
            ("tracked_by", QVariant.String),
        ):
            fields.append(QgsField(name, field_type))
        layer = _create_gpkg(
            path, "tracking_layer", fields, QgsWkbTypes.LineStringZM
        )
        layer.setEditorWidgetSetup(
            layer.fields().indexFromName("fid"), QgsEditorWidgetSetup("Hidden", {})
        )
        defaults = {
            "tracking_start_time": "@tracking_start_time",
            "tracking_end_time": "@tracking_end_time",
            "total_distance": "round($length, 2)",
            "tracked_by": "@mm_username",
        }
        for field_name, expression in defaults.items():
            layer.setDefaultValueDefinition(
                layer.fields().indexFromName(field_name), QgsDefaultValue(expression)
            )
        layer.setDisplayExpression(
            '"tracked_by" ||\' on \'|| format_date("tracking_end_time", '
            "'dd MMM yyyy') ||' at '|| format_date(\"tracking_end_time\", 'H:mm (t)')"
        )
        symbol = QgsLineSymbol.createSimple(
            {
                "capstyle": "square",
                "joinstyle": "bevel",
                "line_style": "solid",
                "line_width": "0.35",
                "line_width_unit": "MM",
                "line_color": QgsSymbolLayerUtils.encodeColor(QColor("#ffa500")),
            }
        )
        layer.setRenderer(QgsSingleSymbolRenderer(symbol))
        return layer


    def _build_mergin_project(
        plot_layer: QgsVectorLayer,
        output_dir: Path,
        raster_source: Path | None = None,
    ) -> Path:
        output_dir.mkdir(parents=True, exist_ok=True)
        _ensure_rebuild_is_safe(output_dir)
        for path in (
            output_dir / "map_sketches.gpkg",
            output_dir / "tracking_layer.gpkg",
        ):
            if path.exists():
                path.unlink()

        project_path = BASE._build_vector_package(
            plot_layer, output_dir, raster_source
        )
        project = QgsProject.instance()
        project.setFilePathStorage(Qgis.FilePathType.Relative)
        sketches = _create_map_sketches(output_dir / "map_sketches.gpkg")
        tracking = _create_tracking_layer(output_dir / "tracking_layer.gpkg")
        project.addMapLayer(sketches)
        project.addMapLayer(tracking)

        project.writeEntry("Mergin", "MapSketching/Enabled", True)
        project.writeEntry("Mergin", "MapSketching/Layer", sketches.id())
        project.writeEntry("Mergin", "MapSketching/Colors", SKETCH_COLORS)
        project.writeEntry("Mergin", "PositionTracking/Enabled", True)
        project.writeEntry("Mergin", "PositionTracking/TrackingLayer", tracking.id())
        project.writeEntry("Mergin", "PositionTracking/UpdateFrequency", 1)
        project.writeEntry("Mergin", "SortLayersMethod/Method", 0)
        if not project.write(str(project_path)):
            raise QgsProcessingException(
                f"Mergin Maps-project kon niet worden geschreven: {project_path}"
            )

        manifest_path = output_dir / "pakket_manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        manifest.update(
            {
                "platform": "Mergin Maps",
                "map_sketching": True,
                "position_tracking": True,
                "sketch_colors": SKETCH_COLORS,
            }
        )
        manifest_path.write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        return project_path


    class BuildMeijendelMergin(QgsProcessingAlgorithm):
        """Valideer de bron en bouw het afzonderlijke Mergin Maps-project."""

        PLOTS = "PLOTS"
        OUTPUT_DIR = "OUTPUT_DIR"
        RASTER = "RASTER"
        PACKAGE_DIR = "PACKAGE_DIR"
        PLOT_COUNT = "PLOT_COUNT"

        def tr(self, text: str) -> str:
            return QCoreApplication.translate("BuildMeijendelMergin", text)

        def createInstance(self):
            return BuildMeijendelMergin()

        def name(self) -> str:
            return "build_meijendel_mergin"

        def displayName(self) -> str:
            return self.tr("Bouw Mergin Maps-project Meijendel")

        def group(self) -> str:
            return self.tr("Meijendel")

        def groupId(self) -> str:
            return "meijendel"

        def shortHelpString(self) -> str:
            return self.tr(
                "Bouwt een afzonderlijk offline Mergin Maps-project met 55 kavels."
            )

        def initAlgorithm(self, config=None) -> None:
            self.addParameter(
                QgsProcessingParameterVectorLayer(
                    self.PLOTS,
                    self.tr("Onderzoekskavels"),
                    types=[QgsProcessing.TypeVectorPolygon],
                )
            )
            self.addParameter(
                QgsProcessingParameterFolderDestination(
                    self.OUTPUT_DIR, self.tr("Pakketmap")
                )
            )
            raster = QgsProcessingParameterFile(
                self.RASTER,
                self.tr("Bestaande offline luchtfoto (optioneel)"),
                optional=True,
                fileFilter=self.tr("GeoTIFF (*.tif *.tiff)"),
            )
            self.addParameter(raster)
            self.addOutput(
                QgsProcessingOutputString(self.PACKAGE_DIR, self.tr("Pakketmap"))
            )
            self.addOutput(
                QgsProcessingOutputNumber(self.PLOT_COUNT, self.tr("Aantal plots"))
            )

        def processAlgorithm(self, parameters, context, feedback):
            source = self.parameterAsVectorLayer(parameters, self.PLOTS, context)
            if source is None or not source.isValid():
                raise QgsProcessingException("De plotbron kon niet worden geopend.")
            BASE.validate_plot_source(source)
            output_dir = Path(
                self.parameterAsString(parameters, self.OUTPUT_DIR, context)
            ).expanduser().resolve()
            raster_value = self.parameterAsString(
                parameters, self.RASTER, context
            ).strip()
            raster_source = Path(raster_value).expanduser() if raster_value else None
            project_path = _build_mergin_project(
                source, output_dir, raster_source
            )
            feedback.pushInfo(f"Mergin Maps-project gebouwd: {project_path}")
            return {
                self.PACKAGE_DIR: str(output_dir),
                self.PLOT_COUNT: BASE.EXPECTED_PLOT_COUNT,
            }
