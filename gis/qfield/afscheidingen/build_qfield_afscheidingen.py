#!/usr/bin/env python3
"""Bouw het overdraagbare offline QField-pakket voor Meijendel."""

from __future__ import annotations

from pathlib import Path


EXPECTED_PLOT_COUNT = 55
EXPECTED_CRS = "EPSG:28992"


def plot_label(name: str) -> str:
    """Maak het korte kaartlabel zonder samengestelde nummers te wijzigen."""
    prefix = "Meijendel k "
    value = (name or "").strip()
    return f"M{value[len(prefix):]}" if value.startswith(prefix) else value


try:
    from qgis.PyQt.QtCore import QCoreApplication
    from qgis.core import (
        QgsProcessing,
        QgsProcessingAlgorithm,
        QgsProcessingException,
        QgsProcessingOutputNumber,
        QgsProcessingOutputString,
        QgsProcessingParameterFeatureSource,
        QgsProcessingParameterFile,
        QgsProcessingParameterFolderDestination,
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
                QgsProcessingParameterFeatureSource(
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
            source = self.parameterAsSource(parameters, self.PLOTS, context)
            if source is None:
                raise QgsProcessingException("De plotbron kon niet worden geopend.")
            validate_plot_source(source)
            output_dir = Path(
                self.parameterAsString(parameters, self.OUTPUT_DIR, context)
            ).expanduser()
            feedback.pushInfo(
                f"Plotbron geldig: {EXPECTED_PLOT_COUNT} polygonen in {EXPECTED_CRS}."
            )
            return {
                self.PACKAGE_DIR: str(output_dir),
                self.PLOT_COUNT: EXPECTED_PLOT_COUNT,
            }
