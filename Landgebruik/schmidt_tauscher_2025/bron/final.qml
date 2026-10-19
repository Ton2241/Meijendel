<!DOCTYPE qgis PUBLIC 'http://mrcc.com/qgis.dtd' 'SYSTEM'>
<qgis styleCategories="AllStyleCategories" minScale="1e+08" hasScaleBasedVisibilityFlag="0" maxScale="0" version="3.16.10-Hannover">
  <flags>
    <Identifiable>1</Identifiable>
    <Removable>1</Removable>
    <Searchable>1</Searchable>
  </flags>
  <temporal mode="0" enabled="0" fetchMode="0">
    <fixedRange>
      <start></start>
      <end></end>
    </fixedRange>
  </temporal>
  <customproperties>
    <property value="false" key="WMSBackgroundLayer"/>
    <property value="false" key="WMSPublishDataSourceUrl"/>
    <property value="0" key="embeddedWidgets/count"/>
    <property value="Value" key="identify/format"/>
  </customproperties>
  <pipe>
    <provider>
      <resampling maxOversampling="2" enabled="false" zoomedInResamplingMethod="nearestNeighbour" zoomedOutResamplingMethod="nearestNeighbour"/>
    </provider>
    <rasterrenderer nodataColor="" type="paletted" alphaBand="-1" opacity="1" band="1">
      <rasterTransparency/>
      <minMaxOrigin>
        <limits>None</limits>
        <extent>WholeRaster</extent>
        <statAccuracy>Estimated</statAccuracy>
        <cumulativeCutLower>0.02</cumulativeCutLower>
        <cumulativeCutUpper>0.98</cumulativeCutUpper>
        <stdDevFactor>2</stdDevFactor>
      </minMaxOrigin>
      <colorPalette>
        <paletteEntry value="1" alpha="255" label="1" color="#cce6b2"/>
        <paletteEntry value="2" alpha="255" label="2" color="#c0802b"/>
        <paletteEntry value="3" alpha="255" label="3" color="#2d7442"/>
        <paletteEntry value="4" alpha="255" label="4" color="#56e9eb"/>
        <paletteEntry value="5" alpha="255" label="5" color="#f4ee28"/>
        <paletteEntry value="13" alpha="255" label="13" color="#57ba73"/>
        <paletteEntry value="26" alpha="255" label="26" color="#fc54e3"/>
        <paletteEntry value="137" alpha="255" label="137" color="#cce6b2"/>
        <paletteEntry value="138" alpha="255" label="138" color="#cce6b2"/>
        <paletteEntry value="139" alpha="255" label="139" color="#cce6b2"/>
        <paletteEntry value="140" alpha="255" label="140" color="#cce6b2"/>
        <paletteEntry value="2001" alpha="255" label="2001" color="#56e9eb"/>
        <paletteEntry value="2002" alpha="255" label="2002" color="#56e9eb"/>
        <paletteEntry value="2003" alpha="255" label="2003" color="#56e9eb"/>
        <paletteEntry value="2004" alpha="255" label="2004" color="#56e9eb"/>
        <paletteEntry value="2005" alpha="255" label="2005" color="#56e9eb"/>
        <paletteEntry value="8001" alpha="255" label="8001" color="#2d7442"/>
        <paletteEntry value="8002" alpha="255" label="8002" color="#2d7442"/>
        <paletteEntry value="8003" alpha="255" label="8003" color="#2d7442"/>
        <paletteEntry value="8004" alpha="255" label="8004" color="#2d7442"/>
      </colorPalette>
      <colorramp type="randomcolors" name="[source]"/>
    </rasterrenderer>
    <brightnesscontrast contrast="0" brightness="0" gamma="1"/>
    <huesaturation colorizeGreen="128" saturation="0" grayscaleMode="0" colorizeRed="255" colorizeBlue="128" colorizeOn="0" colorizeStrength="100"/>
    <rasterresampler maxOversampling="2"/>
    <resamplingStage>resamplingFilter</resamplingStage>
  </pipe>
  <blendMode>0</blendMode>
</qgis>
