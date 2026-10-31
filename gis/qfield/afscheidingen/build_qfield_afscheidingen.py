#!/usr/bin/env python3
"""Bouw het overdraagbare offline QField-pakket voor Meijendel."""

from __future__ import annotations

import json
import shutil
from pathlib import Path


EXPECTED_PLOT_COUNT = 55
EXPECTED_CRS = "EPSG:28992"


def plot_label(name: str) -> str:
    """Maak het korte kaartlabel zonder samengestelde nummers te wijzigen."""
    prefix = "Meijendel k "
    value = (name or "").strip()
    return f"M{value[len(prefix):]}" if value.startswith(prefix) else value


try:
    from qgis.PyQt.QtCore import QCoreApplication, QVariant
    from qgis.PyQt.QtGui import QColor
    from qgis.core import (
        Qgis,
        QgsCategorizedSymbolRenderer,
        QgsCoordinateReferenceSystem,
        QgsDefaultValue,
        QgsEditorWidgetSetup,
        QgsFeatureRequest,
        QgsField,
        QgsFieldConstraints,
        QgsFillSymbol,
        QgsLineSymbol,
        QgsMarkerSymbol,
        QgsPalLayerSettings,
        QgsProject,
        QgsRasterLayer,
        QgsProcessing,
        QgsProcessingAlgorithm,
        QgsProcessingException,
        QgsProcessingOutputNumber,
        QgsProcessingOutputString,
        QgsProcessingParameterFile,
        QgsProcessingParameterFolderDestination,
        QgsProcessingParameterVectorLayer,
        QgsRelation,
        QgsRendererCategory,
        QgsSingleSymbolRenderer,
        QgsTextBufferSettings,
        QgsTextFormat,
        QgsVectorFileWriter,
        QgsVectorLayer,
        QgsVectorLayerSimpleLabeling,
        QgsWkbTypes,
    )
except ModuleNotFoundError:  # Pure Python unit tests only need plot_label().
    QgsProcessingAlgorithm = object
else:

    def validate_plot_source(source) -> None:
        """Stop bij een andere plotpopulatie, projectie of ongeldige geometrie."""
        count = source.featureCount()
        if count != EXPECTED_PLOT_COUNT:
            raise QgsProcessingException(
                f"De plotbron moet precies 55 polygonen bevatten; aangetroffen: {count}."
            )
        if source.sourceCrs().authid() != EXPECTED_CRS:
            raise QgsProcessingException(
                f"De plotbron moet {EXPECTED_CRS} gebruiken; aangetroffen: "
                f"{source.sourceCrs().authid() or 'onbekend'}."
            )
        if QgsWkbTypes.geometryType(source.wkbType()) != QgsWkbTypes.PolygonGeometry:
            raise QgsProcessingException("De plotbron moet polygoongeometrie bevatten.")
        invalid = []
        for feature in source.getFeatures():
            geometry = feature.geometry()
            if geometry is None or geometry.isEmpty() or not geometry.isGeosValid():
                invalid.append(feature.id())
        if invalid:
            raise QgsProcessingException(
                "De plotbron bevat lege of ongeldige geometrieën: "
                + ", ".join(map(str, invalid[:10]))
            )


    def _write_layer(layer, destination: Path, layer_name: str, append=False) -> None:
        options = QgsVectorFileWriter.SaveVectorOptions()
        options.driverName = "GPKG"
        options.layerName = layer_name
        options.fileEncoding = "UTF-8"
        options.actionOnExistingFile = (
            QgsVectorFileWriter.CreateOrOverwriteLayer
            if append
            else QgsVectorFileWriter.CreateOrOverwriteFile
        )
        result = QgsVectorFileWriter.writeAsVectorFormatV3(
            layer,
            str(destination),
            QgsProject.instance().transformContext(),
            options,
        )
        if result[0] != QgsVectorFileWriter.NoError:
            raise QgsProcessingException(
                f"Schrijven van {layer_name} is mislukt: {result[1]}"
            )


    def _empty_field_layer(name: str, geometry: str, field_specs) -> QgsVectorLayer:
        layer = QgsVectorLayer(f"{geometry}?crs={EXPECTED_CRS}", name, "memory")
        if not layer.isValid():
            raise QgsProcessingException(f"Tijdelijke laag {name} kon niet worden gemaakt.")
        fields = []
        for field_name, field_type, length in field_specs:
            fields.append(QgsField(field_name, field_type, len=length))
        layer.dataProvider().addAttributes(fields)
        layer.updateFields()
        return layer


    def _value_map(values) -> QgsEditorWidgetSetup:
        return QgsEditorWidgetSetup("ValueMap", {"map": [{value: value} for value in values]})


    def _configure_common_fields(layer: QgsVectorLayer) -> None:
        defaults = {
            "id": "uuid()",
            "datum_tijd": "now()",
            "ontvanger": "'GNS 3000 via iPadOS'",
            "nauwkeurigheid_m": "@position_horizontal_accuracy",
        }
        for field_name, expression in defaults.items():
            index = layer.fields().indexOf(field_name)
            layer.setDefaultValueDefinition(index, QgsDefaultValue(expression))
        id_index = layer.fields().indexOf("id")
        layer.setFieldConstraint(
            id_index,
            QgsFieldConstraints.ConstraintNotNull,
            QgsFieldConstraints.ConstraintStrengthHard,
        )
        layer.setFieldConstraint(
            id_index,
            QgsFieldConstraints.ConstraintUnique,
            QgsFieldConstraints.ConstraintStrengthHard,
        )
        photo_index = layer.fields().indexOf("foto")
        layer.setEditorWidgetSetup(
            photo_index,
            QgsEditorWidgetSetup(
                "ExternalResource",
                {
                    "DefaultRoot": "photos",
                    "DocumentViewer": 1,
                    "FileWidget": True,
                    "RelativeStorage": 1,
                    "StorageMode": 0,
                },
            ),
        )
        notes_index = layer.fields().indexOf("opmerking")
        layer.setEditorWidgetSetup(
            notes_index,
            QgsEditorWidgetSetup("TextEdit", {"IsMultiline": True, "UseHtml": False}),
        )


    def _configure_afscheidingen(layer: QgsVectorLayer) -> None:
        _configure_common_fields(layer)
        layer.setEditorWidgetSetup(
            layer.fields().indexOf("type"),
            _value_map(("hek", "raster", "sloot", "wal", "haag", "anders")),
        )
        layer.setEditorWidgetSetup(
            layer.fields().indexOf("bron"),
            _value_map(("GNSS-track", "handmatig meetpunt", "luchtfoto")),
        )
        symbol = QgsLineSymbol.createSimple(
            {"line_color": "255,60,0,255", "line_width": "1.2"}
        )
        layer.setRenderer(QgsSingleSymbolRenderer(symbol))


    def _configure_bijzonderheden(layer: QgsVectorLayer) -> None:
        _configure_common_fields(layer)
        values = (
            "hoek",
            "poort/doorgang",
            "onderbreking",
            "typewijziging",
            "bord",
            "schade",
            "foto",
            "anders",
        )
        layer.setEditorWidgetSetup(layer.fields().indexOf("soort"), _value_map(values))
        layer.setEditorWidgetSetup(
            layer.fields().indexOf("bron"),
            _value_map(("GNSS", "handmatig", "luchtfoto")),
        )
        colors = (
            "255,215,0,255",
            "0,220,255,255",
            "255,0,170,255",
            "160,80,255,255",
            "255,255,255,255",
            "220,0,0,255",
            "0,255,110,255",
            "180,180,180,255",
        )
        categories = []
        for value, color in zip(values, colors):
            symbol = QgsMarkerSymbol.createSimple(
                {
                    "name": "circle",
                    "color": color,
                    "outline_color": "30,30,30,255",
                    "size": "4.2",
                }
            )
            categories.append(QgsRendererCategory(value, symbol, value))
        layer.setRenderer(QgsCategorizedSymbolRenderer("soort", categories))


    def _configure_plot_style(layer: QgsVectorLayer) -> None:
        symbol = QgsFillSymbol.createSimple(
            {
                "color": "0,0,0,0",
                "outline_color": "255,235,0,255",
                "outline_width": "0.7",
            }
        )
        layer.setRenderer(QgsSingleSymbolRenderer(symbol))
        settings = QgsPalLayerSettings()
        settings.fieldName = "concat('M', regexp_replace(\"naam\", '^Meijendel k ', ''))"
        settings.isExpression = True
        text_format = QgsTextFormat()
        text_format.setColor(QColor("#fff000"))
        text_format.setSize(10)
        buffer = QgsTextBufferSettings()
        buffer.setEnabled(True)
        buffer.setSize(1)
        buffer.setColor(QColor("#202020"))
        text_format.setBuffer(buffer)
        settings.setFormat(text_format)
        layer.setLabelsEnabled(True)
        layer.setLabeling(QgsVectorLayerSimpleLabeling(settings))
        layer.setReadOnly(True)


    def _reload_vector(path: Path, layer_name: str, title: str) -> QgsVectorLayer:
        layer = QgsVectorLayer(f"{path}|layername={layer_name}", title, "ogr")
        if not layer.isValid():
            raise QgsProcessingException(f"Laag {layer_name} kon niet worden heropend.")
        return layer


    def _ensure_rebuild_is_safe(fieldwork_path: Path, photos_path: Path) -> None:
        if fieldwork_path.exists():
            for layer_name in ("afscheidingen", "bijzonderheden"):
                layer = QgsVectorLayer(
                    f"{fieldwork_path}|layername={layer_name}", layer_name, "ogr"
                )
                if not layer.isValid():
                    raise QgsProcessingException(
                        "Bestaand veldwerkbestand is niet leesbaar; herbouw is gestopt: "
                        f"{fieldwork_path}"
                    )
                if layer.featureCount() > 0:
                    raise QgsProcessingException(
                        "De pakketmap bevat bestaande veldwerkgegevens; kies een lege "
                        "uitvoermap om overschrijven te voorkomen."
                    )
        if photos_path.exists() and any(path.is_file() for path in photos_path.rglob("*")):
            raise QgsProcessingException(
                "De pakketmap bevat bestaande veldwerkgegevens in photos/; kies een "
                "lege uitvoermap om overschrijven te voorkomen."
            )


    def _build_vector_package(
        plot_layer: QgsVectorLayer, output_dir: Path, raster_source: Path | None = None
    ) -> Path:
        output_dir.mkdir(parents=True, exist_ok=True)
        reference_path = output_dir / "referentie.gpkg"
        fieldwork_path = output_dir / "veldwerk.gpkg"
        project_path = output_dir / "meijendel_afscheidingen.qgz"
        photos_path = output_dir / "photos"
        _ensure_rebuild_is_safe(fieldwork_path, photos_path)
        photos_path.mkdir(exist_ok=True)
        for generated in (reference_path, fieldwork_path, project_path):
            if generated.exists():
                generated.unlink()

        _write_layer(plot_layer, reference_path, "onderzoekskavels")
        line_specs = (
            ("id", QVariant.String, 36),
            ("type", QVariant.String, 32),
            ("materiaal", QVariant.String, 80),
            ("datum_tijd", QVariant.DateTime, 0),
            ("bron", QVariant.String, 32),
            ("ontvanger", QVariant.String, 80),
            ("nauwkeurigheid_m", QVariant.Double, 0),
            ("offset_m", QVariant.Double, 0),
            ("foto", QVariant.String, 255),
            ("opmerking", QVariant.String, 1000),
        )
        point_specs = (
            ("id", QVariant.String, 36),
            ("afscheiding_id", QVariant.String, 36),
            ("soort", QVariant.String, 32),
            ("datum_tijd", QVariant.DateTime, 0),
            ("bron", QVariant.String, 32),
            ("ontvanger", QVariant.String, 80),
            ("nauwkeurigheid_m", QVariant.Double, 0),
            ("offset_m", QVariant.Double, 0),
            ("foto", QVariant.String, 255),
            ("opmerking", QVariant.String, 1000),
        )
        lines_memory = _empty_field_layer("afscheidingen", "LineString", line_specs)
        points_memory = _empty_field_layer("bijzonderheden", "Point", point_specs)
        _write_layer(lines_memory, fieldwork_path, "afscheidingen")
        _write_layer(points_memory, fieldwork_path, "bijzonderheden", append=True)

        plots = _reload_vector(reference_path, "onderzoekskavels", "Onderzoekskavels")
        lines = _reload_vector(fieldwork_path, "afscheidingen", "Afscheidingen")
        points = _reload_vector(fieldwork_path, "bijzonderheden", "Bijzonderheden")
        _configure_plot_style(plots)
        _configure_afscheidingen(lines)
        _configure_bijzonderheden(points)

        raster = None
        if raster_source:
            if not raster_source.is_file():
                raise QgsProcessingException(f"Offline luchtfoto ontbreekt: {raster_source}")
            packaged_raster = output_dir / "luchtfoto_pdok_2025_25cm.tif"
            if raster_source.resolve() != packaged_raster.resolve():
                shutil.copy2(raster_source, packaged_raster)
            raster = QgsRasterLayer(str(packaged_raster), "PDOK luchtfoto 2025 — 25 cm")
            if not raster.isValid():
                raise QgsProcessingException(
                    f"Offline luchtfoto kon niet door QGIS worden geopend: {packaged_raster}"
                )

        project = QgsProject.instance()
        project.clear()
        project.setCrs(QgsCoordinateReferenceSystem(EXPECTED_CRS))
        project.setFilePathStorage(Qgis.FilePathType.Relative)
        project.setPresetHomePath(".")
        project.setTitle("Meijendel — Afscheidingen veldwerk")
        project.setFileName(str(project_path))
        if raster is not None:
            project.addMapLayer(raster)
        project.addMapLayer(plots)
        project.addMapLayer(lines)
        project.addMapLayer(points)
        relation = QgsRelation()
        relation.setId("bijzonderheid_afscheiding")
        relation.setName("Bijzonderheden bij afscheiding")
        relation.setReferencedLayer(lines.id())
        relation.setReferencingLayer(points.id())
        relation.addFieldPair("afscheiding_id", "id")
        if relation.isValid():
            project.relationManager().addRelation(relation)
        if not project.write(str(project_path)):
            raise QgsProcessingException(f"QGIS-project kon niet worden geschreven: {project_path}")

        extent = plot_layer.extent()
        manifest = {
            "project": "meijendel_afscheidingen.qgz",
            "crs": EXPECTED_CRS,
            "plot_count": EXPECTED_PLOT_COUNT,
            "buffer_m": 100,
            "aerial_layer": "2025_ortho25",
            "aerial_source": "PDOK Landelijke Voorziening Beeldmateriaal WMS",
            "bbox_rd_buffered": [
                round(extent.xMinimum() - 100, 3),
                round(extent.yMinimum() - 100, 3),
                round(extent.xMaximum() + 100, 3),
                round(extent.yMaximum() + 100, 3),
            ],
        }
        (output_dir / "pakket_manifest.json").write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        return project_path


    class BuildQFieldAfscheidingen(QgsProcessingAlgorithm):
        """Valideer de bron en bouw vervolgens het offline veldwerkpakket."""

        PLOTS = "PLOTS"
        OUTPUT_DIR = "OUTPUT_DIR"
        RASTER = "RASTER"
        PACKAGE_DIR = "PACKAGE_DIR"
        PLOT_COUNT = "PLOT_COUNT"

        def tr(self, text: str) -> str:
            return QCoreApplication.translate("BuildQFieldAfscheidingen", text)

        def createInstance(self):
            return BuildQFieldAfscheidingen()

        def name(self) -> str:
            return "build_qfield_afscheidingen"

        def displayName(self) -> str:
            return self.tr("Bouw offline QField-pakket Afscheidingen")

        def group(self) -> str:
            return self.tr("Meijendel")

        def groupId(self) -> str:
            return "meijendel"

        def shortHelpString(self) -> str:
            return self.tr(
                "Valideert de 55 onderzoekskavels en bouwt een lokaal QField-pakket."
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
                    self.OUTPUT_DIR,
                    self.tr("Pakketmap"),
                )
            )
            raster = QgsProcessingParameterFile(
                self.RASTER,
                self.tr("Bestaande offline luchtfoto (optioneel)"),
                optional=True,
                fileFilter=self.tr("GeoTIFF (*.tif *.tiff)"),
            )
            self.addParameter(raster)
            self.addOutput(QgsProcessingOutputString(self.PACKAGE_DIR, self.tr("Pakketmap")))
            self.addOutput(QgsProcessingOutputNumber(self.PLOT_COUNT, self.tr("Aantal plots")))

        def processAlgorithm(self, parameters, context, feedback):
            source = self.parameterAsVectorLayer(parameters, self.PLOTS, context)
            if source is None or not source.isValid():
                raise QgsProcessingException("De plotbron kon niet worden geopend.")
            validate_plot_source(source)
            output_dir = Path(
                self.parameterAsString(parameters, self.OUTPUT_DIR, context)
            ).expanduser().resolve()
            raster_value = self.parameterAsString(parameters, self.RASTER, context).strip()
            raster_source = Path(raster_value).expanduser() if raster_value else None
            feedback.pushInfo(
                f"Plotbron geldig: {EXPECTED_PLOT_COUNT} polygonen in {EXPECTED_CRS}."
            )
            project_path = _build_vector_package(source, output_dir, raster_source)
            feedback.pushInfo(f"Vectorpakket gebouwd: {project_path}")
            return {
                self.PACKAGE_DIR: str(output_dir),
                self.PLOT_COUNT: EXPECTED_PLOT_COUNT,
            }
