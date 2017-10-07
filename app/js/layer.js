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

msp.strings = {
    THIS_IS_A_LAYER: function (a, b) {
        return 'This is a layer made by ' + a + ' rules and defined by ' + b + '.';
    }
};

msp.useClass = function (use) {
    if (!use) {
        return undefined;
    } else if (use.name === msp.enum.DATA) {
        return msp.enum.DATA;
    } else if (use.name === msp.enum.ECOSYSTEM) {
        return msp.enum.ECOSYSTEM;
    } else {
        return use.class_id;
    }
};

/**
 * Options for creating a layer.
 * @typedef {Object} msp.Layer.Options
 * @property {number} id - .
 * @property {string} name - .
 * @property {string} owner - .
 * @property {msp.Model} model - .
 * @property {Object} use - .
 * @property {Object} style - {palette:string}.
 * @property {number} min_value - Only for datasets. Minimum value.
 * @property {number} max_value - Only for datasets. Maximum value.
 * @property {string} data_type - Only for datasets. integer or real.
 * @property {Object} semantics -  Interpretation of data values {number:string}.
 * @property {string} descr - Only for datasets. Description of the dataset.
 * @property {string} provenance - Only for datasets. Provenance of the dataset.
 * @property {number} class_id - The id of the class to which this layer belongs to.
 * @property {string} rule_class - Only for computed layers. The class
 * of rules used to compute this layer.
 * @property {string} network - For layers computed with Bayesian Networks.
 * @property {string} output_node - For layers computed with Bayesian Networks.
 * @property {string} output_state - For layers computed with Bayesian Networks.
 */
/**
 * A WMTS layer in the map.
 * @constructor
 * @param {msp.Layer.Options} options - Options.
 */
msp.Layer = function (args) {
    var self = this;

    self.id = args.id;
    self.name = args.name;
    self.owner = args.owner;

    // mapping
    self.model = args.model;
    self.server = args.model.serverURL() + '/WMTS';
    self.map = args.model.map;
    self.projection = args.model.config.proj;

    self.use = args.use;
    self.style = args.style;

    // the use class id
    // 0 = dataset
    // 1 = ecosystem component (computed)
    // 2 = other computed

    self.edit(args);

    if (msp.useClass(self.use) !== msp.enum.DATA) {

        self.rules = [];

        if (args.rules) {
            $.each(args.rules, function (i, rule) {
                rule.layer = self;
                rule.dataset = self.model.getDataset(parseInt(rule.dataset, 10));
                rule.active = true;
                self.rules.push(new msp.Rule(rule));
            });
        }

    }

    if (self.layer) {
        self.map.removeLayer(self.layer);
    }
};

msp.Layer.prototype = {
    edit: function (args) {
        var self = this;
        if (msp.useClass(self.use) === msp.enum.DATA) {

            self.data_type = args.data_type;
            if (self.data_type !== msp.enum.BOOLEAN) {
                self.min_value = args.min_value;
                self.max_value = args.max_value;
                self.semantics = args.semantics;
            }
            self.descr = args.descr;
            self.provenance = args.provenance;

        } else {

            // subclass computed layer
            if (args.class_id) {
                self.class_id = args.class_id;
            }
            if (args.rule_class) {
                self.rule_class = args.rule_class;
            }

            if (self.rule_class === msp.enum.BAYESIAN_NETWORK) {
                if (args.network) {
                    self.network = args.network;
                }
                // assert self.network is not nothing?
                self.output_node = args.output_node;
                self.output_state = args.output_state;
            }

        }

        self.refresh();
    },
    useClass: function () {
        var self = this;
        return msp.useClass(self.use);
    },
    sameAs: function (layer) {
        var self = this;
        return self.id === layer.id && self.useClass() === layer.useClass();
    },
    /**
     * Return information about this layer in an object of type
     * {header:'', body:''}.
     */
    info: function () {
        var self = this,
            url = self.model.serverURL(),
            header,
            body = '';
        if (self.useClass() === msp.enum.DATA) {
            header = 'Dataset.';
            body = self.provenance;
        } else if (self.useClass() === msp.enum.ECOSYSTEM) {
            header = 'Ecosystem component.';
        } else {
            header = msp.strings.THIS_IS_A_LAYER(self.rule_class, self.owner);
            if (self.rule_class === msp.enum.EXCLUSIVE) {
                body = 'Default is YES, rules subtract.';
            } else if (self.rule_class === msp.enum.INCLUSIVE) {
                body = 'Default is NO, rules add.';
            } else if (self.rule_class === msp.enum.MULTIPLICATIVE) {
                body = 'Value is a product of rules.';
            } else if (self.rule_class === msp.enum.ADDITIVE) {
                body = 'Value is a sum of rules.';
            } else if (self.rule_class === msp.enum.BOXCAR) {
                body = 'Value is a product of rules.';
            } else if (self.rule_class === msp.enum.BAYESIAN_NETWORK) {
                if (self.network) {
                    body = msp.e('img', {
                        src: url + '/networks?name=' + self.network.name + '&accept=jpeg',
                        width: msp.layoutRightWidth,
                    }, '') +
                        '<br/>' + 'Output is from node ' + self.output_node.name + ', state ' + self.output_state;
                } else {
                    body = 'Bayesian network rules are not available.';
                }
            }
        }
        return {
            header: header,
            body: body
        };
    },
    getOpacity: function () {
        var self = this;
        return self.layer.getOpacity();
    },
    setOpacity: function (opacity) {
        var self = this;
        self.layer.setOpacity(opacity);
    },
    getName: function () {
        var self = this,
            name;
        if (self.useClass() === msp.enum.DATA) {
            name = self.use.name;
        } else if (self.useClass() === msp.enum.ECOSYSTEM) {
            name = self.use.name;
        } else {
            name = self.use.class_id;
        }
        name += '_' + self.id;
        if (self.rules && self.rules.length > 0) {
            $.each(self.rules, function (i, rule) {
                if (rule.active) {
                    name += '_' + rule.id; // add rules
                }
            });
        }
        return name;
    },
    newLayer: function () {
        var self = this,
            visible;
        self.layer = new ol.layer.Tile({
            opacity: 0.6,
            extent: self.projection.extent,
            visible: false,
            source: new ol.source.WMTS({
                url: self.server,
                layer: self.getName(),
                matrixSet: self.projection.matrixSet,
                format: 'image/png',
                projection: self.projection.projection,
                tileGrid: new ol.tilegrid.WMTS({
                    origin: ol.extent.getTopLeft(self.projection.extent),
                    resolutions: self.projection.resolutions,
                    matrixIds: self.projection.matrixIds
                }),
                // WMTS parameter, server not yet supports this
                // style: self.style.palette + self.scale_min + self.scale_max
            })
        });
        self.layer.set('msp_id', self.id);
        self.layer.on('change:visible', function () {
            this.visible = !this.visible;
        }, self);
        visible = self.visible;
        self.layer.setVisible(visible); // restore visibility
        self.visible = visible;
    },
    /**
     * Add this layer into the map.
     */
    addToMap: function () {
        var self = this;
        if (!self.map) {
            return;
        }
        if (self.layer) {
            self.map.removeLayer(self.layer);
        }
        self.newLayer();
        self.map.addLayer(self.layer);
    },
    /**
     * Remove this layer from the map.
     */
    removeFromMap: function () {
        var self = this;
        if (self.layer) {
            self.map.removeLayer(self.layer);
        }
    },
    setVisible: function (visible) {
        var self = this;
        self.layer.setVisible(visible);
    },
    /**
     * Update this layer in the map. Call after changes to the
     * layer. No need to call after edd, edit, or delete of a rule.
     */
    refresh: function () {
        var self = this,
            ind,
            coll;
        if (!self.map) {
            return;
        }
        coll = self.map.getLayers();
        coll.forEach(function (elem, i) {
            var id = elem.get('msp_id');
            if (id === self.id) {
                ind = i;
            }
        });
        self.newLayer();
        coll.setAt(ind, self.layer);
        self.map.render();
    },
    /**
     * Add a rule to this layer.
     * @param {MSPRule} rule
     */
    addRule: function (rule) {
        var self = this;
        self.rules.push(rule);
        self.refresh();
    },
    getRule: function (id) {
        var self = this;
        return self.rules.find(function (rule) {
            return rule.id === id;
        });
    },
    editRule: function (rule) {
        var self = this;
        self.getRule(rule.id).edit(rule);
        self.refresh();
    },
    deleteRules: function (rules) {
        var self = this,
            rules2 = [];
        $.each(self.rules, function (i, rule) {
            if (!rules[rule.id]) {
                rules2.push(rule);
            }
        });
        self.rules = rules2;
        self.refresh();
    },
    setRuleActive: function (id, active) {
        var self = this;
        self.rules.find(function (rule) {
            return rule.id === id;
        }).active = active;
        self.refresh();
    }
};