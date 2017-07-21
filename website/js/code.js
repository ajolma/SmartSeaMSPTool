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
/*global $, jQuery, alert, ol, getConfig, projection, MSP, MSPView, MSPController*/

(function () {
    var config = getConfig(),
        proj = projection(config),
        bg = /bg=(\w+)/.exec(window.location.href),
        map,
        model,
        view,
        controller;
    $('body').addClass('stop-scrolling');
    $(".menu").hide();
    $(document).click(function (e) {
        if ($(".menu").has(e.target).length === 0) {
            $(".menu").hide();
        }
    });
    if (bg && bg[1]) {
        config.bg = bg[1];
        if (config.bg === "osm") {
            config.epsg = 3857;
            config.matrixSet = 'EPSG:3857';
            config.center = [2671763, 8960514];
            config.zoom = 6;
        }
    }
    map = new ol.Map({
        layers: [],
        target: 'map',
        controls: ol.control.defaults({
            attributionOptions: {
                collapsible: false
            }
        }),
        view: proj.view
    });
    map.addControl(new ol.control.ScaleLine());
    model = new MSP({
        server: config.server,
        user: config.user,
        proj: proj,
        map: map,
        firstPlan: 14,
        auth: config.auth
    });
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
        color_scale: $('#color-scale')
    }, {
        uses: "#useslist",
        rules: "#rules"
    });
    controller = new MSPController(model, view);

    if (config.bg === 'osm') {
        map.addLayer(new ol.layer.Tile({
            source: new ol.source.OSM()
        }));
    } else {
        map.addLayer(new ol.layer.Tile({
            opacity: 1,
            extent: projection.extent,
            source: new ol.source.TileWMS({
                attributions: [new ol.Attribution({
                    html: 'Map: Ministry of Education and Culture, Data: OpenStreetMap contributors'
                })],
                url: 'http://avaa.tdata.fi/geoserver/osm_finland/wms',
                params: {'LAYERS': 'osm-finland', 'TILED': true},
                serverType: 'geoserver',
                matrixSet: 'ETRS-TM35FIN',
                projection: proj.projection,
                tileGrid: new ol.tilegrid.WMTS({
                    origin: ol.extent.getTopLeft(proj.extent),
                    resolutions: proj.resolutions,
                    matrixIds: proj.matrixIds
                })
            })
        }));
    }

    $("#reload").click((function reload() {
        controller.loadPlans();
        return reload;
    }()));

    $(window).resize(function () {
        view.windowResize();
    });
    view.windowResize();

}());
