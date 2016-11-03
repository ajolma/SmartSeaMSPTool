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

var right_width = 220; // from layout.css

var map = null;
var proj = null;
var uses = null;
var plan = null;
var analysisSite = null;

(function() {
    $("#sortable").sortable({
        stop: function () {
            map.removeLayer(analysisSite);
            var newOrder = [];
            forEachLayerGroup(uses, function(use){
                newOrder.push(use);
            });
            uses = newOrder;
            addLayers(map, proj, uses, null, false);
            map.addLayer(analysisSite);
        }
    });
    $('body').addClass('stop-scrolling');
    boot_map({});
    $(window).resize(window_resize);
    window_resize();
    return;
    // from http://jsfiddle.net/kCduV/10/
    $('.right').resizable({
        handles       : 'e,w', 
        resize        : function (event,ui){
            ui.position.left = ui.originalPosition.left;
            ui.size.width    = ( ui.size.width
                                 - ui.originalSize.width )*2
        }
    });     
}());

function window_resize() {
    var h = $(window).height() -  $('.header').height() - $('.plot').height();
    var w = $(window).width() - right_width - 15;
    $('#map')
        .height(h)
        .width(w);
    $('.right').css('max-height', h);
    if (map) map.updateSize();
}

function boot_map(options) {
    proj = projection(3067);

    map = new ol.Map({
        layers: [],
        target: 'map',
        controls: ol.control.defaults({
            attributionOptions:{
                collapsible: false
            }
        }),
        view: proj.view
    });

    var scaleline = new ol.control.ScaleLine();
    map.addControl(scaleline);
    
    map.addLayer(createLayer({bg: 'mml'}, proj));

    $.ajax({
        url: 'http://'+server+'/core/plans'
    }).done(function(plans) {

        var planlist = $("#plans");
        $.each(plans, function(i, plan) {
            planlist.append(element('option',{value:plan.my_id},plan.title));
        });
        planlist.change(function () {
            plan = {my_id:$("#plans").val()};
            $.each(plans, function(i, p) {
                if (p.my_id == plan.my_id) {
                    plan.rules = p.rules;
                    plan.title = p.title;
                    return false;
                }
            });
            fill_rules_panel();
            if (uses) new_plan();
        }).change();
        
        plan = plans[0];
        $.ajax({
            url: 'http://'+server+'/core/uses'
        }).done(function(ret) {
            uses = ret;
            addLayers(map, proj, uses, plan, true);
            var rule_use_menu = $("#rule_use_menu");
            $.each(uses, function(i, use) {
                rule_use_menu.append(element('option',{value:use.my_id},use.title));
            });
            rule_use_menu.change(fill_rules_panel).change();
            addExplainTool(uses);
        });
    });
    
}

function new_plan() {
    map.removeLayer(analysisSite);
    addLayers(map, proj, uses, plan, false);
    map.addLayer(analysisSite);
}

function fill_rules_panel() {
    var use = $("#rule_use_menu").val();
    // clear rule list, fill it with new
    var r = $("#rules");
    r.empty();
    $.each(plan.rules, function(i, u) {
        if (u.id == use) {
            $.each(u.rules, function(i, rule) {
                r.append(element('input', {
                    type:"checkbox",
                    use: use, 
                    rule:rule.id,
                    checked:"checked"
                }, rule.text));
                rule.active = true;
                r.append(element('br'));
            });
            return false;
        }
    });
    $("#rules :checkbox").change(function() {
        var use_id = $(this).attr('use');
        var rule_id = $(this).attr('rule');
        var active = this.checked;
        $.each(plan.rules, function(i, u) {
            if (u.id == use_id) {
                $.each(u.rules, function(i, rule) {
                    if (rule.id == rule_id) {
                        rule.active = active;
                        return false;
                    }
                });
                return false;
            }
        });
        new_plan();
    });
}

function addExplainTool(uses) {

    var source = new ol.source.Vector({});

    var iconStyle = new ol.style.Style({
        image: new ol.style.Icon(/** @type {olx.style.IconOptions} */ ({
            anchor: [16, 32],
            anchorXUnits: 'pixels',
            anchorYUnits: 'pixels',
            opacity: 1,
            src: 'Map-Marker-Marker-Outside-Pink-icon.png'
        }))
    });

    source.on('addfeature', function(evt){
        var feature = evt.feature;
        var geom = feature.getGeometry();
        var type = geom.getType();
        var query = 'plan='+plan.my_id+'&';
        $.each(uses, function(i, use) {
            $.each(use.layers, function(j, layer) {
                if (layer.visible) query += 'layer='+layer.name+'&';
            });
        });
        if (type == 'Polygon') {
            var format  = new ol.format.WKT();
            query += 'wkt='+format.writeGeometry(geom);
        } else if (type == 'Point') {
            var coordinates = geom.getCoordinates();
            query += 'easting='+coordinates[0]+'&northing='+coordinates[1];
        }
        $.ajax({
            url: 'http://'+server+'/explain?'+query
        }).done(function(ret) {
            $('#info').html(ret.report);
        });
    });

    analysisSite = new ol.layer.Vector({
        source: source,
        style: new ol.style.Style({
            fill: new ol.style.Fill({
                color: 'rgba(255, 255, 255, 0.2)'
            }),
            stroke: new ol.style.Stroke({
                color: '#ffcc33',
                width: 2
            }),
            image: new ol.style.Circle({
                radius: 7,
                fill: new ol.style.Fill({
                    color: '#ffcc33'
                })
            })
        })
    });

    map.addLayer(analysisSite);
    
    var typeSelect = $('#ia_type')[0];

    var draw = {};
    function addInteraction() {
        var value = typeSelect.value;
        if (value == 'Polygon') {
            if (draw.key) {
                map.unByKey(draw.key);
                draw.key = null;
            }
            var geometryFunction, maxPoints;
            draw.draw = new ol.interaction.Draw({
                source: source,
                type: /** @type {ol.geom.GeometryType} */ (value),
                geometryFunction: geometryFunction,
                maxPoints: maxPoints
            });

            map.addInteraction(draw.draw);

            draw.draw.on('drawstart', function() {
                source.clear();
            });

        } else if (value == 'Point') {
            if (draw.draw) {
                map.removeInteraction(draw.draw);
                draw.draw = null;
            }
            draw.key = map.on('click', function(evt) {
                var coordinates = evt.coordinate;
                var f = new ol.Feature({
                    geometry: new ol.geom.Point(coordinates)
                });
                f.setStyle(iconStyle);
                source.clear();
                source.addFeature(f);
            });
        } else {
            if (draw.key) {
                map.unByKey(draw.key);
                draw.key = null;
            }
            if (draw.draw) {
                map.removeInteraction(draw.draw);
                draw.draw = null;
            }
            source.clear();
            $('#info').html('');
        }
    }
    typeSelect.onchange = addInteraction;
    addInteraction();

}
