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

// after https://alexatnet.com/articles/model-view-controller-mvc-javascript

function MSPController(model, view) {
    var self = this;
    self.model = model;
    self.view = view;

    self.view.planSelected.attach(function(sender, args) {
        self.changePlan(args.id);
    });
    self.view.newLayerOrder.attach(function(sender, args) {
        self.model.setLayerOrder(args.order);
    });
    self.view.ruleEdited.attach(function(sender, args) {
        self.model.applyToRuleInEdit(args.value);
    });
}

MSPController.prototype = {
    changePlan: function(id) {
        this.model.changePlan(id);
    }
};

function MSPView(model, elements, id) {
    var self = this;
    self.model = model;
    self.elements = elements;
    self.id = id;
    // elements are plans, layers, rule_info, rules, rule_dialog, site_type, site_info, ...
    // ids are rules, rule_dialog

    self.elements.layers.sortable({
        stop: function () {
            var newOrder = [];
            var uses = self.model.plan.uses;
            var ul = self.elements.layers.children();
            for (var i = 0; i < ul.length; ++i) {
                var n = ul[i].id;
                n = n.replace(/use/, '');
                newOrder.push(n);
            }
            self.newLayerOrder.notify({ order : newOrder });
        }
    });

    self.elements.rule_dialog.dialog({
        autoOpen: false,
        height: 400,
        width: 350,
        modal: false,
        buttons: {
            Apply: function() {
                var value = self.getRuleEditValue();
                self.ruleEdited.notify({ value : value });
            },
            Close: function() {
                self.elements.rule_dialog.dialog("close");
            }
        },
        close: function() {
        }
    });

    self.planSelected = new Event(self);
    self.newLayerOrder = new Event(self);
    self.ruleEdited = new Event(self);

    // attach model listeners
    self.model.newPlans.attach(function(sender, args) {
        self.buildPlans();
    });
    self.model.planChanged.attach(function(sender, args) {
        self.elements.plans.val(args.plan.id);
        self.buildPlan(args.plan);
    });
    self.model.newLayerList.attach(function(sender, args) {
        self.buildLayers();
    });
    self.model.layerSelected.attach(function(sender, args) {
        self.selectLayer();
        self.fillRulesPanel();
    });
    self.model.layerUnselected.attach(function(sender, args) {
        self.unselectLayer(args.use, args.layer);
    });
    self.model.ruleEdited.attach(function(sender, args) {
        self.fillRulesPanel(self.model.layer);
    });
    self.model.siteInitialized.attach(function(sender, args) {
        self.siteInteraction(args.source);
    });
    self.model.siteInformationReceived.attach(function(sender, args) {
        self.elements.site_info.html(args.report);
    });

    // attach listeners to HTML controls
    self.elements.plans.change(function(e) {
        self.planSelected.notify({ id : self.elements.plans.val() });
    });
}

MSPView.prototype = {
    windowResize: function() {
        var right_width = 220; // from layout.css
        var h = $(window).height() -  $('.header').height() - $('.plot').height();
        var w = $(window).width() - right_width - 15;
        this.elements.map
            .height(h)
            .width(w);
        $('.right').css('max-height', h);
        if (this.model.map) this.model.map.updateSize();
    },
    buildPlans: function() {
        var self = this;
        $.each(self.model.plans, function(i, plan) {
            if (plan.id > 0)
                self.elements.plans.append(element('option',{value:plan.id},plan.name));
        });
    },
    buildPlan: function(plan) {
        var self = this;
        self.model.removeSite();
        self.model.createLayers(true);
        self.model.addSite();
        self.elements.rules.empty();
        self.fillRulesPanel();
    },
    usesItem: function(use) {
        var b = element('button', {class:"visible", type:'button'}, '&rtrif;');
        var cb = element('label', {title:use.name}, b+' '+use.name);
        var callbacks = [];
        var subs = '';
        $.each(use.layers.reverse(), function(j, layer) {
            var attr = { type: "checkbox", class: "visible"+layer.index };
            var id = 'l'+use.id+'_'+layer.id;
            var lt = element('div', { id: id, style: 'display:inline;' }, layer.name+'<br/>');
            callbacks.push({ selector: '#'+id, use: use.id, layer: layer.id });
            subs += element('input', attr, lt);
            attr = { class:"opacity"+layer.index, type:"range", min:"0", max:"1", step:"0.01" };
            subs += element('div', {class:"opacity"+layer.index}, element('input', attr, '<br/>'));
        });
        subs = element('div', {class:'use'}, subs);
        var attr = { id: 'use'+use.index, tabindex: use.index+1 };
        return { element: element('li', attr, cb + subs), callbacks: callbacks };
    },
    buildLayers: function() {
        var self = this;
        self.elements.layers.html('');
        // all uses with controls: on/off, select/unselect, transparency
        // end to beginning to maintain overlay order
        $.each(self.model.plan.uses.reverse(), function(i, use) {
            var item = self.usesItem(use);
            self.elements.layers.append(item.element);
            $.each(item.callbacks, function(i, callback) {
                $(callback.selector).click(function() {
                    var was_selected = self.model.unselectLayer();
                    if (was_selected.use != callback.use || was_selected.layer != callback.layer)
                        self.model.selectLayer(callback.use, callback.layer);
                });
            });
        });
        self.selectLayer(); // restore selected layer
        $.each(self.model.plan.uses, function(i, use) {
            // open and close a use item
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
            // show/hide layer and set its transparency
            $.each(use.layers, function(j, layer) {
                var cb = $('li#use'+use.index+' input.visible'+layer.index);
                cb.change({use:use, layer:layer}, function(event) {
                    $('li#use'+event.data.use.index+' div.opacity'+event.data.layer.index).toggle();
                    event.data.layer.object.setVisible(this.checked);
                    if (this.checked) {
                        self.model.unselectLayer();
                        var use = self.model.plan.uses[event.data.use.index];
                        var layer = use.layers[event.data.layer.index];
                        self.model.selectLayer(use.id, layer.id);
                    }
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
            if (use.hasOwnProperty("open") && use.open) {
                // restore openness of use
                use.open = true;
                b.trigger('click');  // triggers b.on('click'... above
            } else {
                use.open = false;
            }
        });
    },
    selectLayer: function() {
        if (!this.model.use || !this.model.layer) return;
        var plan = this.model.plan;
        var use = this.model.use;
        var layer = this.model.layer;
        $("#l"+use.id+'_'+layer.id).css("background-color","yellow");
        //this.elements.color_scale.html("Colors are "+layer.style);
        var url = 'http://'+self.server+'/core/legend';
        this.elements.color_scale.html(
            element('img',{src:url+'?layer='+plan.id+'_'+use.id+'_'+layer.id},'')
        );
        if (use.id == 0) {
            this.elements.rule_info.html("");
        } else if (layer.id == 3) 
            this.elements.rule_info.html("Default is to allocate.");
        else 
            this.elements.rule_info.html("Default is no value.");
    },
    unselectLayer: function(use, layer) {
        $("#l"+use+'_'+layer).css("background-color","white");
        this.elements.color_scale.html('');
        this.elements.rules.empty();
    },
    fillRulesPanel: function(layer) {
        var self = this;
        self.elements.rules.empty();
        var layer = self.model.layer;
        if (!layer) return;
        if (layer.descr)
            self.elements.rules.append(layer.descr);
        else
            $.each(layer.rules, function(i, rule) {
                var item;
                if (layer.name == 'Value')
                    item = rule.name;
                else {
                    var attr = {
                        type:"checkbox",
                        use: layer.use,
                        layer: layer.id,
                        rule:rule.id
                    };
                    if (rule.active) attr.checked = "checked";
                    item = element(
                        'input', 
                        attr, 
                        element('a', {id:"rule", rule:rule.id}, rule.name+' '+rule.value)
                    );
                }
                self.elements.rules.append(item);
                rule.active = true;
                self.elements.rules.append(element('br'));
            });
        $(self.id.rules+" :checkbox").change(function() {
            // todo: send message rule activity changed
            var rule_id = $(this).attr('rule');
            var active = this.checked;
            $.each(self.model.layer.rules, function(i, rule) {
                if (rule.id == rule_id) {
                    rule.active = active;
                    return false;
                }
            });
            self.model.removeSite();
            self.model.createLayers(true);
            self.model.addSite();
        });
        $(self.id.rules+" #rule").click(function() {
            var id = $(this).attr('rule');
            $.each(layer.rules, function(i, rule) {
                if (rule.id == id) {
                    self.model.ruleInEdit = rule;
                    return false;
                }
            });
            var rule = self.model.ruleInEdit;
            var html = rule.name;
            html = html
                .replace(/^- If/, "Do not allocate if")
                .replace(/==/, "equals:");
            if (rule.type == 'int') {
                html += element('p',{},element('input', {id:"rule-editor"}));
            } else if (rule.type == 'double') {
                html += element('p',{},element('div', {id:"rule-editor"}));
                html += element('p', {id:"rule-slider-value"}, '');
                self.id.rule_editor_info = self.id.rule_dialog+" #rule-slider-value";
            }
            self.id.rule_editor = self.id.rule_dialog+" #rule-editor";
            html += element('p', {id:"rule-info"}, '');
            self.elements.rule_dialog.html(html);

            $(self.id.rule_dialog+" #rule-info").html(rule.description); 
            if (rule.type == 'int') {
                $(self.id.rule_editor)
                    .spinner({
                        min: rule.min,
                        max: rule.max
                    })
                    .spinner("value", rule.value);
            } else if (rule.type == 'double') {
                var slider = $(self.id.rule_editor).slider({
                    min: parseFloat(rule.min),
                    max: parseFloat(rule.max),
                    step: 0.1, // todo fix this
                    value: parseFloat(rule.value),
                    slide: function (event, ui) {
                        var value = slider.slider("value");
                        $(self.id.rule_editor_info).html(value);
                    }
                });
                $(self.id.rule_editor_info).html(rule.value);
            }
            self.elements.rule_dialog.dialog( "open" );
        });
    },
    getRuleEditValue: function() {
        var self = this;
        if (self.model.ruleInEdit.type == 'int')
            return $(this.id.rule_editor).spinner("value");
        else if (self.model.ruleInEdit.type == 'double')
            return $(this.id.rule_editor).slider("value");
    },
    siteInteraction: function(source) {
        var self = this;
        var typeSelect = self.elements.site_type[0];
        var draw = {};
        function addInteraction() {
            var value = typeSelect.value;
            if (value == 'Polygon') {
                if (draw.key) {
                    self.model.map.unByKey(draw.key);
                    draw.key = null;
                }
                var geometryFunction, maxPoints;
                draw.draw = new ol.interaction.Draw({
                    source: source,
                    type: value,
                    geometryFunction: geometryFunction,
                    maxPoints: maxPoints
                });
                self.model.map.addInteraction(draw.draw);
                draw.draw.on('drawstart', function() {
                    source.clear();
                });
            } else if (value == 'Point') {
                if (draw.draw) {
                    self.model.map.removeInteraction(draw.draw);
                    draw.draw = null;
                }
                draw.key = self.model.map.on('click', function(evt) {
                    var coordinates = evt.coordinate;
                    var f = new ol.Feature({
                        geometry: new ol.geom.Point(coordinates)
                    });
                    var iconStyle = new ol.style.Style({
                        image: new ol.style.Icon({
                            anchor: [16, 32],
                            anchorXUnits: 'pixels',
                            anchorYUnits: 'pixels',
                            opacity: 1,
                            src: 'Map-Marker-Marker-Outside-Pink-icon.png'
                        })
                    });
                    f.setStyle(iconStyle);
                    source.clear();
                    source.addFeature(f);
                });
            } else {
                if (draw.key) {
                    self.model.map.unByKey(draw.key);
                    draw.key = null;
                }
                if (draw.draw) {
                    self.model.map.removeInteraction(draw.draw);
                    draw.draw = null;
                }
                source.clear();
                self.elements.site_info.html('');
            }
        }
        typeSelect.onchange = addInteraction;
        addInteraction();
    }
};

function MSP(server, firstPlan) {
    this.server = server;
    this.firstPlan = firstPlan;
    this.proj = null;
    this.map = null;
    this.site = null; // layer showing selected location or area
    this.plans = null;
    this.plan = null;
    this.use = null;
    this.layer = null;
    this.ruleInEdit = null;

    this.newPlans = new Event(this);
    this.planChanged = new Event(this);
    this.newLayerList = new Event(this);
    this.layerSelected = new Event(this);
    this.layerUnselected = new Event(this);
    this.ruleEdited = new Event(this);
    this.siteInitialized = new Event(this);
    this.siteInformationReceived = new Event(this);
}

MSP.prototype = {
    getPlans: function() {
        var self = this;
        // the planning system is a tree: root->plans->uses->layers->rules
        $.ajax({
            url: 'http://'+self.server+'/core/plans',
            xhrFields: {
                withCredentials: true
            }
        }).done(function(plans) {
            self.plans = plans;
            self.newPlans.notify();
            self.changePlan(self.firstPlan);
            self.initSite();
        });
    },
    changePlan: function(id) {
        var self = this;
        // remove extra use
        if (self.plan) {
            var newUses = [];
            for (var i = 0; i < this.plan.uses.length; ++i) {
                if (this.plan.uses[i].id != 0)
                    newUses.push(this.plan.uses[i]);
            }
            this.plan.uses = newUses;
        }
        self.plan = null;
        self.use = null;
        self.layer = null;
        var datasets;
        $.each(self.plans, function(i, plan) {
            if (id == plan.id) self.plan = plan;
            if (plan.id == 0) datasets = plan.uses[0];
            $.each(plan.uses, function(i, use) {
                $.each(use.layers, function(j, layer) {
                    if (layer.object) self.map.removeLayer(layer.object);
                });
            });
        });
        // add datasets as an extra use
        self.plan.uses.push(datasets);
        if (self.plan) self.planChanged.notify({ plan: self.plan });
    },
    createLayers: function(boot) {
        var self = this;
        // reverse order to add to map in correct order
        $.each(self.plan.uses.reverse(), function(i, use) {
            use.index = self.plan.uses.length - 1 - i;
            $.each(use.layers.reverse(), function(j, layer) {
                layer.index = use.layers.length - 1 - j;
                if (layer.object) self.map.removeLayer(layer.object);
                if (boot) {
                    // initial boot or new plan
                    var wmts = self.plan.id + '_' + use.id + '_' + layer.id;
                    if (layer.name === 'Allocation') {
                        // add rules
                        $.each(layer.rules, function(i, rule) {
                            if (rule.active) wmts += '_'+rule.id;
                        });
                        if (layer.object) layer.object = null;
                    }
                    layer.wmts = wmts;
                }
                if (!layer.object) layer.object = createLayer(layer, self.proj);
                layer.object.on('change:visible', function () {
                    this.visible = !this.visible;
                }, layer);
                // restore visibility:
                var visible = layer.visible;
                layer.object.setVisible(visible);
                layer.visible = visible;
                self.map.addLayer(layer.object);
            });
        });
        self.newLayerList.notify();
    },
    setLayerOrder: function(order) {
        this.removeSite();
        var newUses = [];
        for (var i = 0; i < order.length; ++i) {
            newUses.push(this.plan.uses[order[i]]);
        }
        this.plan.uses = newUses;
        this.createLayers(false);
        this.addSite();
    },
    selectLayer: function(use_id, layer_id) {
        var self = this;
        self.use = null;
        self.layer = null;
        $.each(self.plan.uses, function(i, use) {
            if (use.id == use_id) {
                self.use = use;
                $.each(use.layers, function(i, layer) {
                    if (layer.id == layer_id) {
                        self.layer = layer;
                        return false;
                    }
                });
                return false;
            }
        });
        if (self.layer) self.layerSelected.notify();
    },
    unselectLayer: function() {
        var self = this;
        var use = null, layer = null;
        var unselect = 0;
        if (self.use && self.layer) {
            use = self.use.id;
            layer = self.layer.id;
            unselect = 1;
        }
        self.use = null;
        self.layer = null;
        if (unselect) self.layerUnselected.notify({ use: use, layer: layer });
        return {use: use, layer: layer};
    },
    applyToRuleInEdit: function(value) {
        var self = this;
        $.ajaxSetup({
            crossDomain: true,
            xhrFields: {
                withCredentials: true
            }
        });
        $.post( 'http://'+self.server+'/core/browser/rules/'+self.ruleInEdit.id, 
                { submit: 'Modify', value: value }, 
                function(data) {
                    self.ruleInEdit.value = data.object.value;
                    self.removeSite();
                    self.createLayers(true);
                    self.ruleEdited.notify();
                    self.addSite();
                })
            .fail(function(data) {
                if (data.status == 403)
                    alert("Rule modification requires cookies. Please enable cookies and reload this app.");
                else
                    alert(data.responseText);
            });
        /*
        $.ajax({
            type: 'post',
            url: 'http://'+self.server+'/core/browser/rules/'+self.ruleInEdit.id, 
            crossDomain: true,
            dataType: "json",
            xhrFields: {
                withCredentials: true
            },
            data: { submit: 'Modify', value: value },
            success: function(data) {
                self.ruleInEdit.value = data.object.value;
                self.removeSite();
                self.createLayers(true);
                self.ruleEdited.notify();
                self.addSite();
            },
            error: function(data) {
                alert(data.responseText);
            }
        });
        */
    },
    initSite: function() {
        var self = this;
        var source = new ol.source.Vector({});
        source.on('addfeature', function(evt){
            var feature = evt.feature;
            var geom = feature.getGeometry();
            var type = geom.getType();
            var query = 'plan='+self.plan.id+'&';
            $.each(self.plan.uses, function(i, use) {
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
            query += '&srs='+self.proj.projection.getCode();
            $.ajax({
                url: 'http://'+self.server+'/explain?'+query
            }).done(function(data) {
                self.siteInformationReceived.notify(data);
            });
        });
        self.site = new ol.layer.Vector({
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
        self.map.addLayer(self.site);
        self.siteInitialized.notify({source: source});
    },
    removeSite: function() {
        if (this.site) this.map.removeLayer(this.site);
    },
    addSite: function() {
        if (this.site) this.map.addLayer(this.site);
    }
};

function Event(sender) {
    this.sender = sender;
    this.listeners = [];
}

Event.prototype = {
    attach : function(listener) {
        this.listeners.push(listener);
    },
    notify : function(args) {
        var i;
        for (i = 0; i < this.listeners.length; ++i) {
            this.listeners[i](this.sender, args);
        }
    }
};
