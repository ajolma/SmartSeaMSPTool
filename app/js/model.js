/*
Copyright (c) 2016-2017, Finnish Environment Institute SYKE All rights
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
/*global $, ol, msp*/

// after https://alexatnet.com/articles/model-view-controller-mvc-javascript

/**
 * Options for creating a MSP model.
 * @typedef {Object} msp.Model.Options
 * @property {msp.Config} config - Configuration.
 * @property {ol.Map} map - The map view.
 * @property {number=} firstPlan - The id of the plan to select initially.
 */
/**
 * A singleton for maintaining the plans.
 * @constructor
 * @param {msp.Model.Options} options - Options.
 */
msp.Model = function (args) {
    var self = this;
    self.config = args.config;
    self.map = args.map;
    self.firstPlan = args.firstPlan;

    self.site = null; // layer showing selected location or area
    self.plans = null;
    // pseudo uses
    self.ecosystem = null;
    self.datasets = null;
    // selected things, i.e., where the users focus is
    self.plan = null;
    self.layer = null;

    // events

    self.error = new msp.Event(self);
    self.newPlans = new msp.Event(self);
    self.planChanged = new msp.Event(self);
    self.usesChanged = new msp.Event(self);
    self.newLayerList = new msp.Event(self);
    self.layerSelected = new msp.Event(self);
    self.layerUnselected = new msp.Event(self);
    self.rulesChanged = new msp.Event(self);
    self.siteInitialized = new msp.Event(self);
    self.siteInformationReceived = new msp.Event(self);

};

msp.Model.prototype = {
    serverURL: function () {
        var self = this;
        if (!self.config.config || !self.config.config.protocol) {
            return undefined;
        }
        return self.config.config.protocol + '://' + self.config.config.server;
    },
    setPlans: function (data, networks) {
        var self = this,
            plan;
        if (!data) {
            data = [];
        }
        if (self.plan) {
            self.firstPlan = self.plan.id;
        }
        self.removeLayers();
        self.removeSite();
        self.initSite();
   
        plan = data.find(function (plan) {
            return plan.name === msp.enum.DATA;
        });
        self.datasets = plan || {name: msp.enum.DATA, layers: []};
        self.datasets.id = msp.enum.DATA;
        $.each(self.datasets.layers, function (i, layer) {
            layer.model = self;
            layer.use = self.datasets;
            self.datasets.layers[i] = new msp.Layer(layer);
        });

        plan = data.find(function (plan) {
            return plan.name === msp.enum.ECOSYSTEM;
        });
        self.ecosystem = plan || {name: msp.enum.ECOSYSTEM, layers: []};
        self.ecosystem.id = msp.enum.ECOSYSTEM;
        $.each(self.ecosystem.layers, function (i, layer) {
            layer.model = self;
            layer.use = self.ecosystem;
            self.ecosystem.layers[i] = new msp.Layer(layer);
        });
        
        self.plans = [];
        $.each(data, function (i, plan) {
            if (plan.name === msp.enum.DATA || plan.name === msp.enum.ECOSYSTEM) {
                return true;
            }
            if (!plan.uses) {
                plan.uses = [];
            }
            if (!plan.data) {
                plan.data = {};
            }
            $.each(plan.uses, function (j, use) {
                $.each(use.layers, function (k, layer) {
                    layer.model = self;
                    layer.use = use;
                    if (layer.network) {
                        layer.network = networks.find(function (network) {
                            return network.name === layer.network;
                        });
                        if (layer.network) {
                            layer.output_node = layer.network.nodes.find(function (node) {
                                return node.name === layer.output_node;
                            }) || {name: '?'};
                        } else {
                            layer.output_node = null;
                        }
                        // bail out if fail here?
                    }
                    use.layers[k] = new msp.Layer(layer);
                });
            });
            self.plans.push(plan);
        });
        
        if (!self.firstPlan && self.plans.length > 0) {
            self.firstPlan = self.plans[0].id;
        }
        
        self.newPlans.notify();
        self.changePlan(self.firstPlan);
    },
    planByName: function (name) {
        var self = this;
        if (!self.plans) {
            return undefined;
        }
        return self.plans.find(function (plan) {
            return plan.name === name;
        });
    },
    addPlan: function (plan) {
        var self = this;
        if (!plan.uses) {
            plan.uses = [];
        }
        if (!plan.data) {
            plan.data = {};
        }
        self.plans.unshift(plan);
        self.changePlan(plan.id);
        self.newPlans.notify();
        self.initSite();
    },
    editPlan: function (data) {
        var self = this,
            plan = self.plans.find(function (plan) {
                if (plan.id === data.id) {
                    plan.owner = data.owner;
                    plan.name = data.name;
                    return true;
                }
                return false;
            });
        if (plan) {
            self.newPlans.notify();
            self.changePlan(plan.id);
            self.initSite();
        }
    },
    setPlanData: function (data) {
        var self = this;
        self.plan.data = {};
        $.each(data, function (i, dataset) {
            self.plan.data[dataset.id] = 1;
        });
        self.changePlan(self.plan.id);
    },
    deletePlan: function (id) {
        var self = this,
            plans = [],
            i;
        self.removeLayers();
        self.removeSite();
        for (i = 0; i < self.plans.length; i += 1) {
            if (self.plans[i].id !== id) {
                plans.push(self.plans[i]);
            }
        }
        if (id === self.firstPlan) {
            self.firstPlan = plans[0].id;
        }
        self.plans = plans;
        if (!self.plan || id === self.plan.id) {
            self.plan = null;
            self.changePlan(self.firstPlan);
        }
        self.newPlans.notify();
        self.initSite();
    },
    datasetsInRules: function () {
        var self = this,
            datasets = {};
        if (self.plan) {
            $.each(self.plan.uses, function (i, use) {
                if (msp.useClass(use) !== msp.enum.DATA && msp.useClass(use) !== msp.enum.ECOSYSTEM) {
                    $.each(use.layers, function (i, layer) {
                        $.each(layer.rules, function (i, rule) {
                            datasets[rule.dataset.id] = rule.dataset;
                        });
                    });
                }
            });
        }
        return datasets;
    },
    by_name: function (a, b) {
        if (a.name < b.name) {
            return -1;
        }
        if (a.name > b.name) {
            return 1;
        }
        return 0;
    },
    datasetsForDataUse: function () {
        var self = this,
            datasets = self.datasetsInRules(),
            array = [];
        if (self.plan) {
            // add to dataUse those that have dataset_id in data
            $.each(self.plan.data, function (id) { // self.plan.data is existence hash
                var dataset = self.datasets.layers.find(function (layer) {
                    return layer.id === parseInt(id, 10); // hash key is always a string
                });
                if (dataset) {
                    datasets[id] = dataset;
                }
            });
            $.each(datasets, function (id, layer) {
                array.push(layer);
            });
        }
        return array.sort(self.by_name);
    },
    resetPlan: function () {
        var self = this,
            uses = self.plan.uses.slice();
        self.plan.uses = [];
        $.each(uses, function (i, use) {
            if (msp.useClass(use) !== msp.enum.DATA && msp.useClass(use) !== msp.enum.ECOSYSTEM) {
                self.plan.uses.push(use);
            }
        });
    },
    changePlan: function (id) {
        var self = this,
            dataUse = {
                id: self.datasets.id,
                name: self.datasets.name
            };

        if (self.plan) {
            self.resetPlan();
        }
        // set the requested plan
        self.plan = self.plans.find(function (plan) {
            return plan.id === id;
        });
        // checks
        if (!self.plan) {
            if (self.plans.length > 0) {
                self.plan = self.plans[0];
            }
        }
        self.layer = null;

        dataUse.layers = self.datasetsForDataUse();

        if (self.plan) {
            self.plan.uses.sort(self.by_name);
            // add ecosystem and data as extra uses
            self.plan.uses.push(self.ecosystem);
            self.plan.uses.push(dataUse);
            self.createLayers();
            self.planChanged.notify({ plan: self.plan });
        }
    },
    setUseOrder: function (order) {
        var self = this,
            newUses = [];
        $.each(order, function (i, id) {
            $.each(self.plan.uses, function (j, use) {
                if (use.id === id) {
                    newUses.push(use);
                    return false;
                }
            });
        });
        self.plan.uses = newUses;
        self.createLayers();
    },
    addUse: function (use) {
        var self = this;
        self.plan.uses.unshift(use);
        self.createLayers();
        self.usesChanged.notify();
    },
    hasUse: function (class_id) {
        var self = this,
            retval = false;
        $.each(self.plan.uses, function (i, use) {
            if (msp.useClass(use) === class_id) {
                retval = true;
                return false;
            }
        });
        return retval;
    },
    deleteUse: function (id) {
        var self = this,
            uses = [];
        $.each(self.plan.uses, function (i, use) {
            if (use.id !== id) {
                uses.push(use);
            }
        });
        self.plan.uses = uses;
        self.createLayers();
        self.usesChanged.notify();
    },
    createLayers: function () {
        var self = this;
        self.removeSite();
        // reverse order to show in correct order, slice to not to mutate
        $.each(self.plan.uses.slice().reverse(), function (i, use) {
            $.each(use.layers.slice().reverse(), function (j, layer) {
                if (layer) {
                    layer.addToMap();
                }
            });
        });
        self.newLayerList.notify();
        self.addSite();
    },
    addLayer: function (layer) {
        var self = this;
        layer.use.layers.unshift(layer);
        self.createLayers();
    },
    deleteLayer: function (use_id, layer_id) {
        var self = this,
            use = self.plan.uses.find(function (u) {
                return u.id === use_id;
            }),
            layers = [];
        $.each(use.layers, function (j, layer) {
            if (layer.id === layer_id) {
                layer.removeFromMap();
            } else {
                layers.push(layer);
            }
        });
        use.layers = layers;
        self.createLayers();
    },
    removeLayers: function () {
        var self = this;
        if (!self.plan) {
            return;
        }
        $.each(self.plan.uses, function (i, use) {
            $.each(use.layers, function (j, layer) {
                layer.removeFromMap();
            });
        });
        self.newLayerList.notify();
    },
    selectLayer: function (layer) {
        var self = this;
        self.layer = layer;
        self.layerSelected.notify();
    },
    unselectLayer: function () {
        var self = this,
            layer = null,
            unselect = 0;
        if (self.layer) {
            layer = self.layer;
            unselect = 1;
        }
        self.layer = null;
        if (unselect) {
            self.layerUnselected.notify(layer);
        }
        return layer;
    },
    getDataset: function (id) {
        var self = this;
        return self.datasets.layers.find(function (layer) {
            return layer.id === id;
        });
    },
    addRule: function (rule) {
        var self = this,
            dataUse = self.plan.uses.find(function (use) {
                return msp.useClass(use) === msp.enum.DATA;
            }),
            dataset = dataUse.layers.find(function (layer) {
                return layer.id === rule.dataset.id;
            });
        self.layer.addRule(rule);
        if (!dataset) {
            dataUse.layers = self.datasetsForDataUse();
            self.createLayers();
        }
        self.selectLayer(self.layer);
        self.rulesChanged.notify();
    },
    getRule: function (id) {
        var self = this;
        return self.layer.getRule(id);
    },
    deleteRules: function (rules) {
        var self = this,
            dataUse = self.plan.uses.find(function (use) {
                return msp.useClass(use) === msp.enum.DATA;
            });
        self.layer.deleteRules(rules);
        dataUse.layers = self.datasetsForDataUse();
        self.createLayers();
        self.selectLayer(self.layer);
        self.rulesChanged.notify();
    },
    initSite: function () {
        var self = this,
            source;
        if (!(self.map && self.plan)) {
            return;
        }
        source = new ol.source.Vector({});
        source.on('addfeature', function (evt) {
            var feature = evt.feature,
                geom = feature.getGeometry(),
                type = geom.getType(),
                query = 'plan=' + self.plan.id,
                format,
                coordinates;
            if (self.layer && self.layer.visible) {
                query += '&use=' + msp.useClass(self.layer.use) + '&layer=' + self.layer.id;
            }
            if (type === 'Polygon') {
                format = new ol.format.WKT();
                query += '&wkt=' + format.writeGeometry(geom);
            } else if (type === 'Point') {
                coordinates = geom.getCoordinates();
                query += '&easting=' + coordinates[0] + '&northing=' + coordinates[1];
            }
            query += '&srs=' + self.config.proj.projection.getCode();
            $.ajax({
                url: self.serverURL() + '/explain?' + query
            }).done(function (data) {
                self.siteInformationReceived.notify(data);
            });
        });
        if (self.site) {
            self.map.removeLayer(self.site);
        }
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
    removeSite: function () {
        var self = this;
        if (self.site) {
            self.map.removeLayer(self.site);
        }
    },
    addSite: function () {
        var self = this;
        if (self.site) {
            self.map.addLayer(self.site);
        }
    },
    removeInteraction: function (draw) {
        var self = this;
        if (draw.key) {
            self.map.unByKey(draw.key);
        }
        if (draw.draw) {
            self.map.removeInteraction(draw.draw);
        }
    },
    addInteraction: function (draw) {
        var self = this;
        if (draw.draw) {
            self.map.addInteraction(draw.draw);
        }
        if (draw.source) {
            return self.map.on('click', function (evt) {
                var coordinates = evt.coordinate,
                    f = new ol.Feature({
                        geometry: new ol.geom.Point(coordinates)
                    }),
                    iconStyle = new ol.style.Style({
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
