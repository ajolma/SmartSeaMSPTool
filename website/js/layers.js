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
/*global $, jQuery, alert, ol, Event, MSPRule*/

function MSPLayer(args) {
    var self = this;

    self.id = args.id;
    self.use_id = args.use_id;
    self.name = args.name;
    self.owner = args.owner;
    
    // mapping
    self.model = args.MSP;
    self.server = 'http://' + args.MSP.server + '/WMTS';
    self.map = args.MSP.map;
    self.projection = args.MSP.proj;

    // the subclass id
    // 0 = dataset
    // 1 = ecosystem component (computed)
    // 2 = other computed
    self.use_class_id = args.use_class_id;

    if (self.use_class_id === 0) {
    
        // subclass dataset
        self.min_value = args.min_value;
        self.max_value = args.max_value;
        self.data_type = args.data_type; // integer or real
        self.semantics = args.semantics;
        self.descr = args.descr;
        self.provenance = args.provenance;

        self.binary =
            self.data_type === 'integer' &&
            self.min_value === 0 &&
            self.max_value === 1;

    } else {

        // subclass computed layer
        self.class_id = args.class_id;
        self.rule_class = args.rule_class;

        if (self.rule_class === 'Bayesian network') {
            self.network_file = args.network_file;
            self.output_node = args.output_node;
            self.output_state = args.output_state;
        }
        
        self.rules = [];

        if (args.rules) {
            /*jslint unparam: true*/
            $.each(args.rules, function (i, rule) {
                rule.rule_class = self.rule_class;
                rule.dataset = self.model.getDataset(parseInt(rule.dataset, 10));
                rule.active = true;
                self.rules.push(new MSPRule(rule));
            });
            /*jslint unparam: false*/
        }
        
    }
        
    // visualization but not used
    self.color_scale = args.color_scale;

    if (self.layer) {
        self.map.removeLayer(self.layer);
    }
}

MSPLayer.prototype = {
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
            n = self.use_class_id + '_' + self.id;
        if (self.rules && self.rules.length > 0) {
            /*jslint unparam: true*/
            $.each(self.rules, function (i, rule) {
                if (rule.active) {
                    n += '_' + rule.id; // add rules
                }
            });
            /*jslint unparam: false*/
        }
        return n;
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
                style: self.color_scale
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
    addToMap: function () {
        var self = this;
        if (self.layer) {
            self.map.removeLayer(self.layer);
        }
        self.newLayer();
        self.map.addLayer(self.layer);
    },
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
    refresh: function () {
        var self = this,
            ind,
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
    addRule: function (rule) {
        var self = this;
        self.rules.push(rule);
        self.refresh();
    },
    getRule: function (id) {
        var self = this,
            retval = null;
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
        /*jslint unparam: true*/
        $.each(self.rules, function (i, rule) {
            if (!rules[rule.id]) {
                rules2.push(rule);
            }
        });
        /*jslint unparam: false*/
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

function MSPRule(args) {
    var self = this;
    self.id = args.id;
    self.rule_class = args.rule_class;
    self.dataset = args.dataset;
    self.active = args.active;
    self.edit(args);
}

MSPRule.prototype = {
    edit: function(rule) {
        var self = this;
        if (self.rule_class.match(/clusive/)) {
            self.op = rule.op;
            if (!self.dataset.binary) {
                self.value = rule.value;
            }
        } else if (self.rule_class === 'boxcar') {
            self.boxcar = rule.boxcar;
            self.boxcar_x0 = rule.boxcar_x0;
            self.boxcar_x1 = rule.boxcar_x1;
            self.boxcar_x2 = rule.boxcar_x2;
            self.boxcar_x3 = rule.boxcar_x3;
            self.weight = rule.weight;
        } else if (self.rule_class === 'bayes') {
            self.state_offset = rule.state_offset;
            self.node_id = rule.node_id;
        }
    },
    getCriteria: function () {
        var self = this;
        return self.dataset;
    },
    getName: function () {
        var self = this,
            name,
            value;
        name = self.dataset.name;
        if (self.rule_class.match(/clusive/)) {
            if (self.dataset.binary) {
                name = self.op + ' ' + name;
            } else {
                value = self.value;
                if (self.dataset.semantics) {
                    value = self.dataset.semantics[value];
                }
                name += ' ' + self.op + ' ' + value;
            }
        /*} else if (self.rule_class.match(/tive/)) {*/
        } else if (self.rule_class === 'boxcar') {
            if (self.boxcar) {
                name += ' _/¯\\_ ';
            } else {
                name += ' ¯\\_/¯ ';
            }
            name += self.boxcar_x0 + ', ' + self.boxcar_x1 + ', ' + self.boxcar_x2 + ', ' + self.boxcar_x3;
            name += ' weight ' + self.weight;
        }
        return name;
    },
    getMinMax: function () {
        var self = this;
        return {
            min: self.dataset.min_value,
            max: self.dataset.max_value,
            classes: self.dataset.classes,
            data_type: self.dataset.data_type,
            semantics: self.dataset.semantics
        };
    },
    description: function () {
        var self = this;
        return self.dataset.description;
    }
};
