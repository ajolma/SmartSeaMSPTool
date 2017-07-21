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
    var self = this,
        key,
        rules = [];
    for (key in args) {
        if (args.hasOwnProperty(key)) {
            self[key] = args[key];
        }
    }
    if (self.rules) {
        /*jslint unparam: true*/
        $.each(self.rules, function (i, rule) {
            rule.model = self.model;
            rule.layer = self;
            rule.active = true;
            rule = new MSPRule(rule);
            rules.push(rule);
        });
        /*jslint unparam: false*/
    }
    self.rules = rules;
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
        rule.model = self.model;
        rule.layer = self;
        rule = new MSPRule(rule);
        self.rules.push(rule);
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
    selectRule: function (id) {
        var self = this,
            retval = null;
        /*jslint unparam: true*/
        $.each(self.rules, function (i, rule) {
            if (rule.id.toString() === id.toString()) {
                retval = rule;
                return false;
            }
        });
        /*jslint unparam: false*/
        return retval;
    },
    setRuleActive: function (id, active) {
        var self = this;
        /*jslint unparam: true*/
        $.each(self.rules, function (i, rule) {
            if (rule.id === id) {
                rule.active = active;
                return false;
            }
        });
        /*jslint unparam: false*/
        self.refresh();
    }
};

function MSPRule(args) {
    var self = this,
        key;
    for (key in args) {
        if (args.hasOwnProperty(key)) {
            self[key] = args[key];
        }
    }
}

MSPRule.prototype = {
    getCriteria: function () {
        var self = this;
        return self.model.getDataset(self.dataset);
    },
    getName: function () {
        var self = this,
            dataset = self.model.getDataset(self.dataset),
            name,
            value;
        if (!dataset) {
            return "Dataset " + self.dataset + " is missing.";
        }
        name = dataset.name;
        if (self.layer.rule_class.match(/clusive/)) {
            if (dataset.classes > 1) {
                value = self.value;
                if (dataset.semantics) {
                    value = dataset.semantics[value];
                }
                name += ' ' + self.op + ' ' + value;
            }
        /*} else if (self.layer.rule_class.match(/tive/)) {*/
        } else if (self.layer.rule_class === 'boxcar') {
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
        var self = this,
            dataset = self.model.getDataset(self.dataset);
        if (!dataset) {
            return {
                min: null,
                max: null,
                classes: null,
                data_type: null,
                semantics: null
            };
        }
        return {
            min: dataset.min_value,
            max: dataset.max_value,
            classes: dataset.classes,
            data_type: dataset.data_type,
            semantics: dataset.semantics
        };
    },
    description: function () {
        var self = this,
            dataset = self.model.getDataset(self.dataset);
        if (!dataset) {
            return "Dataset " + self.dataset + " is missing. Its database entry is probably incomplete.";
        }
        return dataset.description;
    }
};
