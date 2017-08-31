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

"use strict";
/*jslint browser: true*/
/*global $, jQuery, alert, ol, element, getConfig, projection, MSP, MSPView, MSPController*/

function makeConfig() {
    var config = window.location.href.replace(/app.*/, 'config'),
        epsg = /epsg=([\d]+)/.exec(window.location.href);
    if (epsg && epsg[1]) {
        epsg = parseInt(epsg[1], 10);
    } else {
        // default projection
        epsg = 3857;
    }
    $.ajax({
        url: config,
        success: function (result) {
            config = result;
        },
        fail: function (xhr, textStatus) {
            msg += xhr.responseText || textStatus;
            alert(msg);
        },
        async: false
    });
    config.bg = [];

    if (epsg === 3857) {
        config.epsg = 3857;
        config.matrixSet = 'EPSG:3857';
        config.center = [2671763, 8960514];
        config.zoom = 6;
        config.proj = projection(config);
        config.bg.push({
            title: "ESRI World Ocean Base",
            layer: new ol.layer.Tile({
                source: new ol.source.XYZ({
                    attributions: [new ol.Attribution({
                        html: 'Background map © Esri, DeLorme, GEBCO, NOAA NGDC, and other contributors'
                    })],
                    url: config.protocol + '://services.arcgisonline.com/arcgis/rest/services/Ocean/World_Ocean_Base/MapServer/tile/{z}/{y}/{x}'
                })
            })
        });
        config.bg.push({
            title: 'MML taustakartta',
            layer: new ol.layer.Tile({
                extent: config.proj.extent,
                source: new ol.source.XYZ({
                    attributions: [new ol.Attribution({
                        html: 'Sisältää Maanmittauslaitoksen aineistoa <a href="http://www.maanmittauslaitos.fi/avoindata_lisenssi_versio1_20120501">(lisenssi)</a>'
                    })],
                    url: 'http://tile1.kartat.kapsi.fi/1.0.0/taustakartta/{z}/{x}/{y}.png'
                })
            })
        });
        config.bg.push({
            title: "OSM",
            layer: new ol.layer.Tile({
                source: new ol.source.OSM()
            })
        });
    } else if (epsg === 3067) {
        config.epsg = 3067;
        config.matrixSet = 'ETRS-TM35FIN';
        config.center = [346735, 6943420];
        config.zoom = 3;
        config.proj = projection(config);
        config.bg.push({
            title: 'MML taustakartta',
            layer: new ol.layer.Tile({
                opacity: 1,
                extent: config.proj.extent,
                source: new ol.source.WMTS({
                    attributions: [new ol.Attribution({
                        html: 'Tiles &copy; <a href="http://www.maanmittauslaitos.fi/avoindata_lisenssi">MML</a>'
                    })],
                    url: 'http://avoindata.maanmittauslaitos.fi/mapcache/wmts',
                    layer: 'taustakartta',
                    matrixSet: 'ETRS-TM35FIN',
                    format: 'image/png',
                    projection: config.proj.projection,
                    tileGrid: new ol.tilegrid.WMTS({
                        origin: ol.extent.getTopLeft(config.proj.extent),
                        resolutions: config.proj.resolutions,
                        matrixIds: config.proj.matrixIds
                    }),
                    style: 'default'
                })
            })
        });
        config.bg.push({
            title: 'OSM Suomi',
            layer: new ol.layer.Tile({
                opacity: 1,
                extent: config.proj.extent,
                source: new ol.source.TileWMS({
                    attributions: [new ol.Attribution({
                        html: 'Map: Ministry of Education and Culture, Data: OpenStreetMap contributors'
                    })],
                    url: 'http://avaa.tdata.fi/geoserver/osm_finland/wms',
                    params: {'LAYERS': 'osm-finland', 'TILED': true},
                    serverType: 'geoserver',
                    matrixSet: 'ETRS-TM35FIN',
                    projection: config.proj.projection,
                    tileGrid: new ol.tilegrid.WMTS({
                        origin: ol.extent.getTopLeft(config.proj.extent),
                        resolutions: config.proj.resolutions,
                        matrixIds: config.proj.matrixIds
                    })
                })
            })
        });
    } else {
        window.alert("EPSG " + epsg + " is not a supported projection!");
    }

    return config;
}

(function () {
    var config = makeConfig(),
        map = new ol.Map({
            layers: [],
            target: 'map',
            controls: ol.control.defaults({
                attributionOptions: {
                    collapsible: false
                }
            }),
            view: config.proj.view
        }),
        model = new MSP({
            protocol: config.protocol,
            server: config.server,
            user: config.user,
            proj: config.proj,
            map: map,
            firstPlan: 30,
            auth: config.auth
        }),
        view = new MSPView(model, {
            map: $("#map"),
            user: $("#user"),
            plan: $("#plan"),
            plan_menu: $("#plan-menu"),
            plans: $("#plans"),
            layers: $("#layers"),
            rule_header: $("#rule-header"),
            rule_info: $("#rule-info"),
            rules: $("#rules"),
            site: $('#explain-site'),
            site_type: $('#site-type'),
            site_info: $('#site-info'),
            legend: $('#legend')
        }, {
            uses: "#useslist",
            rules: "#rules"
        }),
        controller = new MSPController(model, view);

    $('body').addClass('stop-scrolling');
    $('.menu').hide();
    $(document).click(function (e) {
        if ($(".menu").has(e.target).length === 0) {
            $(".menu").hide();
        }
    });
    map.addControl(new ol.control.ScaleLine());

    $.each(config.bg, function (i, bg) {
        bg.layer.setVisible(false);
        map.addLayer(bg.layer);
        $('#bg-map').append(element('option', {value: i}, bg.title));
    });
    config.base = config.bg[0].layer;
    config.base.setVisible(true);
    $('#bg-map').change(function () {
        config.base.setVisible(false);
        config.base = config.bg[parseInt($('#bg-map').val(), 10)].layer;
        config.base.setVisible(true);
    });

    $("#reload").click((function reload() {
        controller.loadPlans();
        return reload;
    }()));

    $(window).resize(function () {
        view.windowResize();
    });
    view.windowResize();

}());
