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
/*global $, alert, ol, Event, MSPLayer*/

// after https://alexatnet.com/articles/model-view-controller-mvc-javascript

function MSP(args) {
    var self = this;
    self.protocol = args.protocol;
    self.server = args.server;
    self.user = args.user;
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
    isAuthorized: function (object) {
        var self = this,
            user = self.user;
        if (!self.auth) {
            return false;
        }
        if (object.use) {
            if (object.use.owner === user) {
                if (object.use.id === 0 || object.use.id > 1) {
                    return true;
                }
            }
            if (self.plan.owner === user) {
                if (object.use.id === 0) {
                    return true;
                }
            }
        }
        if (object.layer) {
            return object.layer.owner === user;
        }
        return false;
    },
    setPlans: function (data, networks) {
        var self = this,
            plan;
        if (self.plan) {
            self.firstPlan = self.plan.id;
        }
        self.removeLayers();
        self.removeSite();
        self.initSite();

        // parse pseudo uses, note reserved use class id's

        self.datasets = {layers: []};
        plan = data.find(function (plan) {
            return plan.id === 0;
        });
        if (plan && plan.uses) {
            self.datasets = plan.uses[0];
            $.each(self.datasets.layers, function (i, layer) {
                layer.MSP = self;
                layer.use = self.datasets;
                self.datasets.layers[i] = new MSPLayer(layer);
            });
        }

        self.ecosystem = {layers: []};
        plan = data.find(function (plan) {
            return plan.id === 1;
        });
        if (plan && plan.uses) {
            self.ecosystem = plan.uses[0];
            $.each(self.ecosystem.layers, function (i, layer) {
                layer.MSP = self;
                layer.use = self.ecosystem;
                self.ecosystem.layers[i] = new MSPLayer(layer);
            });
        }

        self.plans = [];
        $.each(data, function (i, plan) {
            if (plan.id < 2) {
                return true;
            }
            if (!plan.uses) {
                plan.uses = [];
            }
            $.each(plan.uses, function (j, use) {
                $.each(use.layers, function (k, layer) {
                    layer.MSP = self;
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
                    use.layers[k] = new MSPLayer(layer);
                });
            });
            self.plans.push(plan);
        });

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
        self.newPlans.notify();
        self.changePlan(plan.id);
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
        self.newPlans.notify();
        self.changePlan(self.firstPlan);
        self.initSite();
    },
    datasetsInRules: function () {
        var self = this,
            datasets = {};
        $.each(self.plan.uses, function (i, use) {
            if (use.id > 1) {
                $.each(use.layers, function (i, layer) {
                    $.each(layer.rules, function (i, rule) {
                        datasets[rule.dataset.id] = rule.dataset;
                    });
                });
            }
        });
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
        return array.sort(self.by_name);
    },
    resetPlan: function () {
        var self = this,
            uses = self.plan.uses.slice();
        self.plan.uses = [];
        $.each(uses, function (i, use) {
            if (use.id > 1) {
                self.plan.uses.push(use);
            }
        });
    },
    changePlan: function (id) {
        var self = this,
            dataUse = { // pseudo use
                id: self.datasets.id,
                class_id: self.datasets.class_id,
                owner: self.datasets.owner,
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
            } else {
                self.plan = {
                    id: 2,
                    name: 'No plan',
                    data: [],
                    uses: []
                };
            }
        }
        self.layer = null;

        dataUse.layers = self.datasetsForDataUse();

        self.plan.uses.sort(self.by_name);
        // add dataUse and ecosystem as an extra use
        self.plan.uses.push(self.ecosystem);
        self.plan.uses.push(dataUse);
        self.createLayers();
        if (self.plan) {
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
    },
    hasUse: function (class_id) {
        var self = this,
            retval = false;
        $.each(self.plan.uses, function (i, use) {
            if (use.class_id === class_id) {
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
    getLayer: function (id) {
        var self = this,
            retval = null;
        $.each(self.plan.uses, function (i, use) {
            if (use.id === id.use) {
                $.each(use.layers, function (i, layer) {
                    if (layer.id === id.layer) {
                        retval = layer;
                        return false;
                    }
                });
                return false;
            }
        });
        return retval;
    },
    selectLayer: function (id) {
        var self = this,
            layer = self.getLayer(id);
        self.layer = null;
        if (layer) {
            self.layer = layer;
            self.layerSelected.notify();
        }
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
                return use.name === 'Data';
            }),
            dataset = dataUse.layers.find(function (layer) {
                return layer.id === rule.dataset.id;
            });
        self.layer.addRule(rule);
        if (!dataset) {
            dataUse.layers = self.datasetsForDataUse();
            self.createLayers();
        }
        self.selectLayer({use: self.layer.use.id, layer: self.layer.id});
    },
    getRule: function (id) {
        var self = this;
        return self.layer.getRule(id);
    },
    deleteRules: function (rules) {
        var self = this,
            dataUse = self.plan.uses.find(function (use) {
                return use.name === 'Data';
            });
        self.layer.deleteRules(rules);
        dataUse.layers = self.datasetsForDataUse();
        self.createLayers();
        self.selectLayer({use: self.layer.use.id, layer: self.layer.id});
    },
    initSite: function () {
        var self = this,
            source = new ol.source.Vector({});
        source.on('addfeature', function (evt) {
            var feature = evt.feature,
                geom = feature.getGeometry(),
                type = geom.getType(),
                query = 'plan=' + self.plan.id,
                format,
                coordinates;
            if (self.layer && self.layer.visible) {
                query += '&use=' + self.layer.use.class_id + '&layer=' + self.layer.id;
            }
            if (type === 'Polygon') {
                format = new ol.format.WKT();
                query += '&wkt=' + format.writeGeometry(geom);
            } else if (type === 'Point') {
                coordinates = geom.getCoordinates();
                query += '&easting=' + coordinates[0] + '&northing=' + coordinates[1];
            }
            query += '&srs=' + self.proj.projection.getCode();
            $.ajax({
                url: self.protocol + '://' + self.server + '/explain?' + query
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
