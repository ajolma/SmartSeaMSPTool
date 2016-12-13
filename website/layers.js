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

var plan = null;

function addLayers(map, proj, boot, new_plan) {
    // called in three cases: initial boot, new order for uses, new plan

    // end to beginning to maintain overlay order
    $.each(plan.uses.reverse(), function(i, use) {
        use.index = plan.uses.length - 1 - i;
        $.each(use.layers.reverse(), function(j, layer) {
            layer.index = use.layers.length - 1 - j;
            layer.wmts = true;

            if (layer.object) map.removeLayer(layer.object);

            if (boot || new_plan) {
                // initial boot or new plan
                var name = plan.id + '_' + use.id + '_' + layer.id;
                if (layer.title === 'Allocation') {

                    // add rules
                    $.each(layer.rules, function(i, rule) {
                        if (rule.active) name += '_'+rule.id;
                    });

                    if (layer.object) layer.object = null;
                }
                layer.name = name;
            }

            if (!layer.object) layer.object = createLayer(layer, proj);
            layer.object.on('change:visible', function () {
                this.visible = !this.visible;
            }, layer);
            // restore visibility:
            var visible = layer.visible;
            layer.object.setVisible(visible);
            layer.visible = visible;

            map.addLayer(layer.object);
        });
    });

    var useslist = $("#useslist ul");
    useslist.html('');
    $.each(plan.uses.reverse(), function(i, use) {
        useslist.append(usesItem(use));
    });
    if (!(boot || new_plan)) selectLayer(-1); // restore selected
    $.each(plan.uses, function(i, use) {
        var b = $('li#use'+use.index+' button.visible');
        b.on('click', null, {use:use}, function(event) {
            $('li#use'+event.data.use.index+' div.use').toggle();
            if (!arguments.callee.flipflop) {
                arguments.callee.flipflop = 1;
                $(this).html('&dtrif;');
                event.data.use.open = true;
            } else {
                arguments.callee.flipflop = 0;
                $(this).html('&rtrif;');
                event.data.use.open = false;
            }
        });
        $('li#use'+use.index+' div.use').hide();

        var must_click = false;
        if (boot) {
            use.open = false;
        } else {
            if (use.open) must_click = true;
        }
        $.each(use.layers, function(j, layer) {
            var cb = $('li#use'+use.index+' input.visible'+layer.index);
            cb.on('change', null, {use:use, layer:layer}, function(event) {
                $('li#use'+event.data.use.index+' div.opacity'+event.data.layer.index).toggle();
                event.data.layer.object.setVisible(this.checked);
            });

            var slider = $('li#use'+use.index+' input.opacity'+layer.index);
            if (layer.visible) {
                cb.prop('checked', true);
            } else {
                $('li#use'+use.index+' div.opacity'+layer.index).hide();
            }
            slider.on('input change', null, {layer:layer}, function(event) {
                event.data.layer.object.setOpacity(parseFloat(this.value));
            });
            slider.val(String(layer.object.getOpacity()));

        });
        if (must_click) b.trigger('click');  // triggers b.on('click'... above
    });
}

function layer_of_current_plan(use_id, layer_id) {
    var ret;
    $.each(plan.uses, function(i, use) {
        if (use.id == use_id) {
            $.each(use.layers, function(i, layer) {
                if (layer.id == layer_id) {
                    ret = layer;
                    return false;
                }
            });
            return false;
        }
    });
    return ret;
}

function forEachLayerGroup(groups, fArg) {
    var ul = $("#useslist ul").children();
    for (var i = 0; i < ul.length; ++i) {
        var n = $(ul[i]).children().attr('title');
        for (var j = 0; j < groups.length; j++) {
            if (n == groups[j].title) {
                fArg(groups[j]);
                break;
            }
        }
    }
}

function selectLayer(use, layer) {
    if (typeof selectLayer.use != 'undefined') {
        if (use < 0) {
            $("#l"+selectLayer.use+'_'+selectLayer.layer).css("background-color","yellow");
            return;
        }
        $("#l"+selectLayer.use+'_'+selectLayer.layer).css("background-color","white");
    }
    $("#l"+use+'_'+layer).css("background-color","yellow");
    if (layer == 3) 
        $("#layer_rule_info").html("Default is to allocate.");
    else 
        $("#layer_rule_info").html("Default is no value.");
    selectLayer.use = use;
    selectLayer.layer = layer;
    fill_rules_panel(layer_of_current_plan(use, layer));
}

function usesItem(use) {
    var b = element('button', {class:"visible", type:'button'}, '&rtrif;');
    var cb = element('label', {title:use.title}, b+' '+use.title);

    var subs = '';
    $.each(use.layers.reverse(), function(j, layer) {
        var attr = {type:"checkbox", class:"visible"+layer.index};
        var lt = element('div', {
            onclick:"selectLayer("+use.id+','+layer.id+");", 
            style:'display:inline;',
            id:'l'+use.id+'_'+layer.id}, layer.title+'<br/>');

        subs += element('input', attr, lt);
        attr = {class:"opacity"+layer.index, type:"range", min:"0", max:"1", step:"0.01"}
        subs += element('div', {class:"opacity"+layer.index}, element('input', attr, '<br/>'));
    });

    subs = element('div', {class:'use'}, subs);

    var attr = {id:'use'+use.index, tabindex:use.index+1};
    return element('li', attr, cb + subs);
}

function createLayer(template, projection) {
    if (template.bg && template.bg == 'mml') {
        return new ol.layer.Tile({
            opacity: 1,
            extent: projection.extent,
            source: new ol.source.WMTS({
                attributions: [new ol.Attribution({
                    html: 'Tiles &copy; <a href="http://www.maanmittauslaitos.fi/avoindata_lisenssi">MML</a>'
                })],
                url: 'http://avoindata.maanmittauslaitos.fi/mapcache/wmts',
                layer: 'taustakartta',
                matrixSet: 'ETRS-TM35FIN',
                format: 'image/png',
                projection: projection.projection,
                tileGrid: new ol.tilegrid.WMTS({
                    origin: ol.extent.getTopLeft(projection.extent),
                    resolutions: projection.resolutions,
                    matrixIds: projection.matrixIds
                }),
                style: 'default'
            })
        });
    }
    if (template.wmts) {
        return new ol.layer.Tile({
            opacity: 0.6,
            extent: projection.extent,
            visible: false,
            source: new ol.source.WMTS({
                url: 'http://' + server + '/WMTS',
                layer: template.name,
                matrixSet: 'ETRS-TM35FIN',
                format: 'image/png',
                projection: projection.projection,
                tileGrid: new ol.tilegrid.WMTS({
                    origin: ol.extent.getTopLeft(projection.extent),
                    resolutions: projection.resolutions,
                    matrixIds: projection.matrixIds
                }),
                style: 'default'
            })
        });
    }
}
