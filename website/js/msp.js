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

function MSP(args) {
    var self = this;
    self.firstPlan = args.firstPlan;
    self.auth = args.auth;
    self.proj = null;
    self.map = null;
    self.site = null; // layer showing selected location or area
    self.plans = null;
    // pseudo uses
    self.ecosystem = null;
    self.datasets = null;
    // selected things, i.e., where the users focus is
    self.plan = null;
    self.layer = null;
    self.rule = null;

    self.newPlans = new Event(self);
    self.planChanged = new Event(self);
    self.newLayerList = new Event(self);
    self.layerSelected = new Event(self);
    self.layerUnselected = new Event(self);
    self.ruleEdited = new Event(self);
    self.siteInitialized = new Event(self);
    self.siteInformationReceived = new Event(self);

    self.dialog = $('#error');
    self.dialog.dialog({
        autoOpen: false,
        height: 400,
        width: 350,
        modal: true,
        buttons: {
            Ok: function() {
                self.dialog.dialog('close');
            },
        },
        close: function() {
        }
    });
}

MSP.prototype = {
    error: function(msg) {
        var self = this;
        self.dialog.html(msg)
        self.dialog.dialog('open');
    },
    getPlans: function() {
        var self = this;
        self.removeLayers();
        self.removeSite();
        // the planning system is a tree: root->plans->uses->layers->rules
        $.ajax({
            url: 'http://'+server+'/plans',
            xhrFields: {
                withCredentials: true
            }
        }).done(function(plans) {
            self.plans = plans;
            // pseudo uses, note reserved use class id's
            $.each(self.plans, function(i, plan) {
                if (plan.id == 0) { // a pseudo plan Data
                    self.datasets = plan.uses[0];
                } else if (plan.id == 1) { // a pseudo plan Ecosystem
                    self.ecosystem = plan.uses[0];
                }
            });
            self.newPlans.notify();
            self.changePlan(self.firstPlan);
            self.initSite();
        }).fail(function(xhr, textStatus, errorThrown) {
            var msg = 'The configured SmartSea MSP server at '+server+' is not responding.';
            self.error(msg);
        });
    },
    getPlan: function(plan_id) {
        for (var i = 0; i < this.plans.length; ++i) {
            if (this.plans[i].id == plan_id) return this.plans[i];
        }
    },
    addPlan: function(plan) {
        var self = this;
        self.plans.unshift(plan);
        self.newPlans.notify();
        self.changePlan(plan.id);
        self.initSite();
    },
    datasetsInRules: function() {
        var self = this;
        var datasets = {};
        $.each(self.plan.uses, function(i, use) {
            if (use.id > 1) {
                $.each(use.layers, function(i, layer) {
                    $.each(layer.rules, function(i, rule) {
                        $.each(self.datasets.layers, function(i, layer) {
                            if (layer.id == rule.dataset_id) {
                                datasets[layer.id] = layer;
                                return false;
                            }
                        });
                    });
                });
            }
        });
        return datasets;
    },
    changePlan: function(id) {
        var self = this;
        // remove extra use
        if (self.plan) {
            var newUses = [];
            for (var i = 0; i < this.plan.uses.length; ++i) {
                if (this.plan.uses[i].id > 1) // not a pseudo plan
                    newUses.push(this.plan.uses[i]);
            }
            this.plan.uses = newUses;
        }
        self.plan = null;
        self.layer = null;
        $.each(self.plans, function(i, plan) {
            if (id == plan.id) self.plan = plan;
        });
        if (!self.plan) {
            $.each(self.plans, function(i, plan) {
                if (plan.id > 1) {
                    self.plan = plan;
                    return false;
                }
            });
            if (!self.plan) self.plan = {id:2, name:'No plan', data:[], uses:[]};
        }
        $.each(self.plans, function(i, plan) {
            $.each(plan.uses, function(i, use) {
                $.each(use.layers, function(j, layer) {
                    if (layer.object) self.map.removeLayer(layer.object);
                });
            });
        });
        // pseudo use
        var datasets = {
            id:self.datasets.id,
            class_id:self.datasets.class_id,
            owner:self.datasets.owner,
            name:self.datasets.name
        };
        // add to datasets those that have dataset_id in any rule
        var layers = self.datasetsInRules();
        // add to datasets those that have dataset_id in data
        $.each(self.plan.data, function(key, id) {
            $.each(self.datasets.layers, function(i, layer) {
                if (layer.id == key) {
                    layers[key] = layer;
                    return false;
                }
            });
        });
        var array = []
        $.each(layers, function(i, layer) {
            array.push(layer);
        });
        datasets.layers = array.sort(function (a, b) {
            if (a.name < b.name) {
                return -1;
            }
            if (a.name > b.name) {
                return 1;
            }
            return 0;
        });

        // add datasets and ecosystem as an extra use
        self.plan.uses.push(self.ecosystem);
        self.plan.uses.push(datasets);
        if (self.plan) self.planChanged.notify({ plan: self.plan });
    },
    setUseOrder: function(order) {
        var self = this;
        var newUses = [];
        $.each(order, function(i, id) {
            $.each(self.plan.uses, function(j, use) {
                if (use.id == id) {
                    newUses.push(use);
                    return false;
                }
            });
        });
        self.plan.uses = newUses;
        self.createLayers(false);
    },
    hasUse: function(class_id) {
        var self = this;
        var retval = false;
        $.each(self.plan.uses, function(i, use) {
            if (use.class_id == class_id) {
                retval = true;
                return false;
            }
        });
        return retval;
    },
    createLayers: function(boot) {
        var self = this;
        self.removeSite();
        // reverse order to add to map in correct order
        $.each(self.plan.uses.reverse(), function(i, use) {
            var redo_layers = false;
            $.each(use.layers.reverse(), function(j, layer) {
                if (layer.object) self.map.removeLayer(layer.object);
                if (boot || !layer.wmts) {
                    // initial boot or new plan
                    var wmts = layer.use_class_id + '_' + layer.id;
                    if (layer.rules && layer.rules.length > 0) {
                        var rules = '';
                        // add rules
                        $.each(layer.rules, function(i, rule) {
                            if (rule.active) rules += '_'+rule.id;
                        });
                        if (rules == '') rules = '_0'; // avoid no rules = all rules
                        wmts += rules;
                        // needs to be updated
                        if (layer.object) layer.object = null;
                    }
                    layer.wmts = wmts;
                }
                if (layer.delete) {
                    redo_layers = true;
                    return true;
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
            if (redo_layers) {
                var layers = [];
                $.each(use.layers, function(j, layer) {
                    if (layer.delete) return true;
                    layers.push(layer);
                });
                use.layers = layers;
            }
        });
        self.newLayerList.notify();
        self.addSite();
    },
    addLayer: function(use, layer) {
        var self = this;
        use.layers.unshift(layer);
        self.createLayers(false);
    },
    removeLayers: function() {
        var self = this;
        if (!self.plan) return;
        $.each(self.plan.uses, function(i, use) {
            $.each(use.layers, function(j, layer) {
                if (layer.object) self.map.removeLayer(layer.object);
            });
        });
        self.newLayerList.notify();
    },
    getLayer: function(id) {
        var self = this;
        var retval = null;
        $.each(self.plan.uses, function(i, use) {
            $.each(use.layers, function(i, layer) {
                if (layer.id == id) {
                    retval = layer;
                    return false;
                }
            });
            if (retval) return false;
        });
        return retval;
    },
    selectLayer: function(id) {
        var self = this;
        self.layer = null;
        var layer = self.getLayer(id);
        if (layer) {
            self.layer = layer;
            self.layerSelected.notify();
        }
    },
    unselectLayer: function() {
        var self = this;
        var layer = null;
        var unselect = 0;
        if (self.layer) {
            layer = self.layer;
            unselect = 1;
        }
        self.layer = null;
        if (unselect) self.layerUnselected.notify(layer);
        return layer;
    },
    deleteLayer: function(id) {
        var self = this;
        if (self.layer && self.layer.id == id) self.layer = null;
        var layer = self.getLayer(id);
        if (layer) {
            layer.delete = true;
            self.createLayers(false);
        }
    },
    selectRule: function(id) {
        var self = this;
        self.rule = null;
        $.each(self.layer.rules, function(i, rule) {
            if (rule.id == id) {
                self.rule = rule;
                return false;
            }
        });
        return self.rule;
    },
    selectedRule: function() {
        var self = this;
        return self.rule;
    },
    setRuleActive: function(id, active) {
        var self = this;
        $.each(self.layer.rules, function(i, rule) {
            if (rule.id == id) {
                rule.active = active;
                return false;
            }
        });
    },
    modifyRule: function(object) {
        var self = this;
        self.rule.value = object.value;
        self.createLayers(true);
        self.ruleEdited.notify();
    },
    initSite: function() {
        var self = this;
        var source = new ol.source.Vector({});
        source.on('addfeature', function(evt){
            var feature = evt.feature;
            var geom = feature.getGeometry();
            var type = geom.getType();
            var query = 'plan='+self.plan.id;
            if (self.layer && self.layer.visible)
                query += '&use='+self.layer.use_class_id+'&layer='+self.layer.id;
            if (type == 'Polygon') {
                var format  = new ol.format.WKT();
                query += '&wkt='+format.writeGeometry(geom);
            } else if (type == 'Point') {
                var coordinates = geom.getCoordinates();
                query += '&easting='+coordinates[0]+'&northing='+coordinates[1];
            }
            query += '&srs='+self.proj.projection.getCode();
            $.ajax({
                url: 'http://'+server+'/explain?'+query
            }).done(function(data) {
                self.siteInformationReceived.notify(data);
            });
        });
        if (self.site) self.map.removeLayer(self.site);
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
    },
    removeInteraction: function(draw) {
        if (draw.key) this.map.unByKey(draw.key);
        if (draw.draw) this.map.removeInteraction(draw.draw);
    },
    addInteraction: function(draw) {
        if (draw.draw) this.map.addInteraction(draw.draw);
        if (draw.source) {
            return this.map.on('click', function(evt) {
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
                        src: 'img/Map-Marker-Marker-Outside-Pink-icon.png'
                    })
                });
                f.setStyle(iconStyle);
                draw.source.clear();
                draw.source.addFeature(f);
            });
        }
    }
};

