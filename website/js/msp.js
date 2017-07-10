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
    self.proj = args.proj;
    self.map = args.map;
    self.firstPlan = args.firstPlan;
    self.auth = args.auth;
    
    self.site = null; // layer showing selected location or area
    self.plans = null;
    // pseudo uses
    self.ecosystem = null;
    self.datasets = null;
    // selected things, i.e., where the users focus is
    self.plan = null;
    self.layer = null;
    self.rule = null;

    // events

    self.error = new Event(self);
    self.newPlans = new Event(self);
    self.planChanged = new Event(self);
    self.newLayerList = new Event(self);
    self.layerSelected = new Event(self);
    self.layerUnselected = new Event(self);
    self.rulesChanged = new Event(self);
    self.ruleEdited = new Event(self);
    self.siteInitialized = new Event(self);
    self.siteInformationReceived = new Event(self);

}

MSP.prototype = {
    setPlans: function(plans, ecosystem, datasets) {
        var self = this;
        if (self.plan) self.firstPlan = self.plan.id;
        self.removeLayers();
        self.removeSite();
        self.plans = plans;
        self.ecosystem = ecosystem;
        self.datasets = datasets;
        self.newPlans.notify();
        self.changePlan(self.firstPlan);
        self.initSite();
    },
    getPlan: function(id) {
        var self = this;
        for (var i = 0; i < self.plans.length; ++i) {
            if (self.plans[i].id == id) return this.plans[i];
        }
    },
    planNameOk: function(name) {
        var self = this;
        var ok = true;
        for (var i = 0; i < self.plans.length; ++i) {
            if (self.plans[i].name == name) {
                ok = false;
                break;
            }
        }
        return ok;
    },
    addPlan: function(plan) {
        var self = this;
        if (!plan.uses) plan.uses = [];
        if (!plan.data) plan.data = {};
        self.plans.unshift(plan);
        self.changePlan(plan.id);
        self.newPlans.notify();
        self.initSite();
    },
    editPlan: function(plan) {
        var self = this;
        var plan = self.getPlan(plan.id);
        if (plan) {
            plan.owner = plan.owner;
            plan.name = plan.name;
        }
        self.changePlan(plan.id);
        self.newPlans.notify();
        self.initSite();
    },
    setPlanData: function(data) {
        var self = this;
        self.plan.data = [];
        $.each(data, function(i, dataset) {
            self.plan.data[dataset.id] = 1;
        });
        // todo: add datasets to Data plan?
        self.changePlan(self.plan.id);
    },
    deletePlan: function(id) {
        var self = this;
        self.removeLayers();
        self.removeSite();
        var plans = [];
        for (var i = 0; i < self.plans.length; ++i) {
            if (self.plans[i].id != id) {
                plans.push(self.plans[i]);
            }
        }
        if (id == self.firstPlan) self.firstPlan = plans[0].id;
        self.plans = plans;
        self.newPlans.notify();
        self.changePlan(self.firstPlan);
        self.initSite();
    },
    datasetsInRules: function() {
        var self = this;
        var datasets = {};
        $.each(self.plan.uses, function(i, use) {
            if (use.id > 1) {
                $.each(use.layers, function(i, layer) {
                    $.each(layer.rules, function(i, rule) {
                        var d = self.getDataset(rule.dataset);
                        if (d) datasets[rule.dataset] = d;
                    });
                });
            }
        });
        return datasets;
    },
    changePlan: function(id) {
        var self = this;
        // remove extra uses
        if (self.plan) {
            var newUses = [];
            $.each(self.plan.uses, function(i, use) {
                if (use.id > 1) newUses.push(use);
            });
            this.plan.uses = newUses;
        }
        self.plan = null;
        self.layer = null;
        $.each(self.plans, function(i, plan) {
            if (id == plan.id) {
                self.plan = plan;
                return false;
            }
        });
        if (!self.plan) {
            if (self.plans.length > 0)
                self.plan = self.plans[0];
            else
                self.plan = {id:2, name:'No plan', data:[], uses:[]};
        }
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
        var by_name = function (a, b) {
            if (a.name < b.name) return -1;
            if (a.name > b.name) return 1;
            return 0;
        };
        var array = []
        $.each(layers, function(i, layer) {
            array.push(layer);
        });
        datasets.layers = array.sort(by_name);
        var uses = self.plan.uses.sort(by_name);
        self.plan.uses = uses;

        // add datasets and ecosystem as an extra use
        self.plan.uses.push(self.ecosystem);
        self.plan.uses.push(datasets);
        self.createLayers();
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
        self.createLayers();
    },
    addUse: function(use) {
        var self = this;
        self.plan.uses.unshift(use);
        self.createLayers();
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
    deleteUse: function(id) {
        var self = this;
        var uses = [];
        $.each(self.plan.uses, function(i, use) {
            if (use.id != id) {
                uses.push(use);
            }
        });
        self.plan.uses = uses;
        self.createLayers();
    },
    createLayers: function() {
        var self = this;
        self.removeSite();
        // reverse order to show in correct order, slice to not to mutate
        $.each(self.plan.uses.slice().reverse(), function(i, use) {
            $.each(use.layers.slice().reverse(), function(j, layer) {
                if (layer)
                    layer.addToMap();
                else
                    console.log("Layer undefined in use "+use.id+" "+j);
            });
        });
        self.newLayerList.notify();
        self.addSite();
    },
    addLayer: function(use, layer) {
        var self = this;
        use.layers.unshift(layer);
        self.createLayers();
    },
    deleteLayer: function(use_id, layer_id) {
        var self = this;
        $.each(self.plan.uses, function(i, use) {
            if (use.id = use_id) {
                var layers = [];
                $.each(use.layers, function(j, layer) {
                    if (layer.id == layer_id) {
                        layer.removeFromMap();
                    } else {
                        layers.push(layer);
                    }
                });
                use.layers = layers;
                return false;
            }
        });
        self.createLayers();
    },
    removeLayers: function() {
        var self = this;
        if (!self.plan) return;
        $.each(self.plan.uses, function(i, use) {
            $.each(use.layers, function(j, layer) {
                layer.removeFromMap();
            });
        });
        self.newLayerList.notify();
    },
    getLayer: function(id) {
        var self = this;
        var retval = null;
        $.each(self.plan.uses, function(i, use) {
            if (use.id == id.use) {
                $.each(use.layers, function(i, layer) {
                    if (layer.id == id.layer) {
                        retval = layer;
                        return false;
                    }
                });
                return false;
            }
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
    getDataset: function(id) {
        var self = this;
        var dataset;
        $.each(self.datasets.layers, function(i, layer) {
            if (layer.id == id) {
                dataset = layer;
                return false;
            }
        });
        return dataset;
    },
    addRule: function(rule) {
        var self = this;
        self.layer.addRule(rule);
        // todo: add rule.dataset to use 'Data'
        self.rulesChanged.notify();
    },
    deleteRules: function(rules) {
        var self = this;
        self.layer.deleteRules(rules);
        // todo: remove rule.dataset(s) from use 'Data'
        self.rulesChanged.notify();
    },
    selectRule: function(id) {
        var self = this;
        self.rule = self.layer.selectRule(id);
        return self.rule;
    },
    selectedRule: function() {
        var self = this;
        return self.rule;
    },
    editRule: function(rule) {
        var self = this;
        self.rule.value = rule.value;
        self.layer.refresh();
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
