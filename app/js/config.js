/*
Copyright (c) 2016, Finnish Environment Institute SYKE All rights
reserved.

Redistribution and use, with or without modification, are permitted
provided that the following conditions are met:

Redistributions of source code must retain the above copyright notice,
this list of conditions and the following disclaimer.

Neither the name of the Finnish Environment Institute (SYKE) nor the
names of its contributors may be used to endorse or promote products
derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE FINNISH
ENVIRONMENT INSTITUTE (SYKE) BE LIABLE FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
DAMAGE.
*/

'use strict';

/*global $, ol, Projection*/

function Config(options) {
    var self = this,
        url = window.location.href.replace(/app[\w\W]*/, 'config'),
        epsg = /epsg=([\d]+)/.exec(window.location.href);
    
    if (epsg && epsg[1]) {
        epsg = parseInt(epsg[1], 10);
    } else {
        // default projection
        epsg = 3857;
    }
    
    if (epsg === 3857) {
        self.proj = new Projection({
            epsg: epsg,
            matrixSet: 'EPSG:3857',
            center: [2671763, 8960514],
            zoom: 6
        });
    } else if (epsg === 3067) {
        self.proj = new Projection({
            epsg: epsg,
            matrixSet: 'ETRS-TM35FIN',
            center: [346735, 6943420],
            zoom: 3
        });
    } else {
        window.alert('EPSG ' + epsg + ' is not a supported projection!');
    }
    
    $.ajax({
        url: url,
        success: function (result) {
            self.config = result;
            if (epsg === 3857) {
                self.bg = [{
                    title: 'ESRI World Ocean Base',
                    layer: new ol.layer.Tile({
                        source: new ol.source.XYZ({
                            attributions: [new ol.Attribution({
                                html: 'Background map © Esri, DeLorme, GEBCO, NOAA NGDC, and other contributors'
                            })],
                            url: result.protocol + '://services.arcgisonline.com/arcgis/rest/services/Ocean/World_Ocean_Base/MapServer/tile/{z}/{y}/{x}'
                        })
                    })
                },{
                    title: 'MML taustakartta',
                    layer: new ol.layer.Tile({
                        extent: self.proj.extent,
                        source: new ol.source.XYZ({
                            attributions: [new ol.Attribution({
                                html: 'Sisältää Maanmittauslaitoksen aineistoa <a href="http://www.maanmittauslaitos.fi/avoindata_lisenssi_versio1_20120501">(lisenssi)</a>'
                            })],
                            url: 'http://tile1.kartat.kapsi.fi/1.0.0/taustakartta/{z}/{x}/{y}.png'
                        })
                    })
                },{
                    title: 'OSM',
                    layer: new ol.layer.Tile({
                        source: new ol.source.OSM()
                    })
                }];
            } else {
                self.bg = [{
                    title: 'MML taustakartta',
                    layer: new ol.layer.Tile({
                        opacity: 1,
                        extent: self.proj.extent,
                        source: new ol.source.WMTS({
                            attributions: [new ol.Attribution({
                                html: 'Tiles &copy; <a href="http://www.maanmittauslaitos.fi/avoindata_lisenssi">MML</a>'
                            })],
                            url: 'http://avoindata.maanmittauslaitos.fi/mapcache/wmts',
                            layer: 'taustakartta',
                            matrixSet: self.proj.matrixSet,
                            format: 'image/png',
                            projection: self.proj.projection,
                            tileGrid: new ol.tilegrid.WMTS({
                                origin: ol.extent.getTopLeft(self.proj.extent),
                                resolutions: self.proj.resolutions,
                                matrixIds: self.proj.matrixIds
                            }),
                            style: 'default'
                        })
                    })
                },{
                    title: 'OSM Suomi',
                    layer: new ol.layer.Tile({
                        opacity: 1,
                        extent: self.proj.extent,
                        source: new ol.source.TileWMS({
                            attributions: [new ol.Attribution({
                                html: 'Map: Ministry of Education and Culture, Data: OpenStreetMap contributors'
                            })],
                            url: 'http://avaa.tdata.fi/geoserver/osm_finland/wms',
                            params: {'LAYERS': 'osm-finland', 'TILED': true},
                            serverType: 'geoserver',
                            matrixSet: self.matrixSet,
                            projection: self.proj.projection,
                            tileGrid: new ol.tilegrid.WMTS({
                                origin: ol.extent.getTopLeft(self.proj.extent),
                                resolutions: self.proj.resolutions,
                                matrixIds: self.proj.matrixIds
                            })
                        })
                    })
                }];
            }
            options.bootstrap();
        },
        fail: function (xhr, textStatus) {
            alert(xhr.responseText || textStatus);
        }
    });
}

Config.prototype = {
};
