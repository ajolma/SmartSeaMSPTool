"use strict";

/*global $, ol, XMLSerializer, btoa*/

function PlannerMaps(options) {
    var self = this;

    self.username = options.username;
    self.chart = options.chart;

    self.formatWFS = new ol.format.WFS();

    self.view = new ol.View({
        center: [2671763, 8960514],
        zoom: 6
    });

    self.tileSource = new ol.source.XYZ({
        attributions: [new ol.Attribution({
            html: 'Background map © Esri, DeLorme, GEBCO, NOAA NGDC, and other contributors'
        })],
        url: 'https://services.arcgisonline.com/arcgis/rest/services/Ocean/World_Ocean_Base/MapServer/tile/{z}/{y}/{x}'
    });

    self.newStyle = function (color) {
        return new ol.style.Style({
            fill: new ol.style.Fill({
                color: color
            }),
            stroke: new ol.style.Stroke({
                color: '#319FD3',
                width: 1
            }),
            text: new ol.style.Text({
                font: '12px Calibri,sans-serif',
                fill: new ol.style.Fill({
                    color: '#000'
                }),
                stroke: new ol.style.Stroke({
                    color: '#fff',
                    width: 3
                })
            })
        });
    };

    self.style1 = self.newStyle('rgba(0, 228, 255, 0.6)');

    self.style2 = self.newStyle('rgba(255, 255, 0, 0.6)');

    self.style3 = self.newStyle('rgba(0, 255, 0, 0.6)');

    self.style = function (feature) {
        if (feature.get('use') === "1") {
            return self.style1;
        }
        if (feature.get('use') === "2") {
            return self.style2;
        }
        return self.style3;
    };

    self.sourceWFS = new ol.source.Vector({
        loader: function (extent) {
            $.ajax('https://msp.smartsea.fmi.fi/geoserver/ows', {
                type: 'GET',
                data: {
                    service: 'WFS',
                    version: '1.1.0',
                    request: 'GetFeature',
                    typename: 'wfs',
                    srsname: 'EPSG:3857',
                    bbox: extent.join(',') + ',EPSG:3857'
                }
            }).done(function (response) {
                var f = self.formatWFS.readFeatures(response),
                    myFeatures = [];
                /*jslint unparam: true*/
                $.each(f, function (i, feature) {
                    if (feature.get('username') === self.username) {
                        myFeatures.push(feature);
                    }
                });
                /*jslint unparam: false*/
                self.sourceWFS.addFeatures(myFeatures);
                self.chart({layer: 'left', username: self.username });
            });
        },
        strategy: ol.loadingstrategy.bbox,
        projection: 'EPSG:3857'
    });

    self.layerWFS = new ol.layer.Vector({
        source: self.sourceWFS,
        style: self.style
    });

    self.left_map = new ol.Map({
        layers: [
            new ol.layer.Tile({
                source: self.tileSource
            }),
            self.layerWFS
        ],
        controls: ol.control.defaults(),
        view: self.view,
        target: 'left-map'
    });

    self.sourceWFS2 = new ol.source.Vector({
        loader: function (extent) {
            $.ajax('https://msp.smartsea.fmi.fi/geoserver/ows', {
                type: 'GET',
                data: {
                    service: 'WFS',
                    version: '1.1.0',
                    request: 'GetFeature',
                    typename: 'wfs2',
                    srsname: 'EPSG:3857',
                    bbox: extent.join(',') + ',EPSG:3857'
                }
            }).done(function (response) {
                var f = self.formatWFS.readFeatures(response);
                self.sourceWFS2.addFeatures(f);
                self.chart({layer: 'right', username: self.username });
            });
        },
        strategy: ol.loadingstrategy.bbox,
        projection: 'EPSG:3857'
    });

    self.layerWFS2 = new ol.layer.Vector({
        source: self.sourceWFS2,
        style: self.style
    });

    self.right_map = new ol.Map({
        layers: [
            new ol.layer.Tile({
                source: self.tileSource
            }),
            self.layerWFS2
        ],
        controls: ol.control.defaults(),
        view: self.view,
        target: 'right-map'
    });
}

PlannerMaps.prototype = {
    getMap: function (map) {
        var self = this;
        if (map === 'left') {
            return self.left_map;
        }
        return self.right_map;
    },
    getLayer: function (layer) {
        var self = this;
        if (layer === 'left') {
            return self.layerWFS;
        }
        return self.layerWFS2;
    }
};
