"use strict";

/*global $, ol, XMLSerializer, btoa*/

function PlannerMaps(options) {
    var self = this;

    self.config = options.config;
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
        if (parseInt(feature.get('use'),10) === 1) {
            return self.style1;
        }
        if (parseInt(feature.get('use'),10) === 2) {
            return self.style2;
        }
        return self.style3;
    };

    self.sourceWFS = new ol.source.Vector({
        loader: function (extent) {
            var url = self.config.protocol + '://' + self.config.wfs_server;
            $.ajax(url, {
                beforeSend: function (xhr) {
                    var auth = self.config.wfs_username + ":" + self.config.wfs_password;
                    xhr.setRequestHeader("Authorization", "Basic " + btoa(auth));
                },
                type: 'GET',
                data: {
                    service: 'WFS',
                    version: '1.1.0',
                    request: 'GetFeature',
                    typename: self.config.wfs_user_type,
                    srsname: 'EPSG:3857',
                    bbox: extent.join(',') + ',EPSG:3857'
                }
            }).done(function (response) {
                var f = self.formatWFS.readFeatures(response),
                    myFeatures = [];
                /*jslint unparam: true*/
                $.each(f, function (i, feature) {
                    if (feature.get('username') === self.config.user) {
                        myFeatures.push(feature);
                    }
                });
                /*jslint unparam: false*/
                self.sourceWFS.addFeatures(myFeatures);
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
            var url = self.config.protocol + '://' + self.config.wfs_server;
            $.ajax(url, {
                type: 'GET',
                data: {
                    service: 'WFS',
                    version: '1.1.0',
                    request: 'GetFeature',
                    typename: self.config.wfs_comparison_type,
                    srsname: 'EPSG:3857',
                    bbox: extent.join(',') + ',EPSG:3857'
                }
            }).done(function (response) {
                var f = self.formatWFS.readFeatures(response);
                self.sourceWFS2.addFeatures(f);
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

    self.chart({layer: 'left'}, self.config);
    self.chart({layer: 'right'}, self.config);
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
