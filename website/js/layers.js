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

function MSPLayer(args) {
    var self = this;
    for (var key in args){
        self[key] = args[key];
    }
    var rules = [];
    if (self.rules) {
        $.each(self.rules, function(i, rule) {
            rule.model = self.model;
            rule.layer = self;
            rule.active = true;
            rule = new MSPRule(rule);
            rules.push(rule);
        });
    }
    self.rules = rules;
    if (self.layer) self.map.removeLayer(self.layer);
}

MSPLayer.prototype = {
    getOpacity: function() {
        var self = this;
        return self.layer.getOpacity();
    },
    setOpacity: function(opacity) {
        var self = this;
        self.layer.setOpacity(opacity);
    },
    layerName: function() {
        var self = this;
        var name = self.use_class_id + '_' + self.id;
        if (self.rules && self.rules.length > 0) {
            var rules = '';
            $.each(self.rules, function(i, rule) {
                if (rule.active) rules += '_'+rule.id; // add rules
            });
            if (rules == '') rules = '_0'; // avoid no rules = all rules
            name += rules;
        }
        return name;
    },
    newLayer: function() {
        var self = this;
        self.layer = new ol.layer.Tile({
            opacity: 0.6,
            extent: self.projection.extent,
            visible: false,
            source: new ol.source.WMTS({
                url: self.server,
                layer: self.layerName(),
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
        self.layer.on('change:visible', function () {this.visible = !this.visible}, self);
        var visible = self.visible;
        self.layer.setVisible(visible); // restore visibility
        self.visible = visible;
    },
    addToMap: function(boot) {
        var self = this;
        if (self.layer) self.map.removeLayer(self.layer);
        self.newLayer();
        self.map.addLayer(self.layer);
    },
    removeFromMap: function() {
        var self = this;
        if (self.layer) self.map.removeLayer(self.layer);
    },
    setVisible: function(visible) {
        var self = this;
        self.layer.setVisible(visible);
    },
    refresh: function() {
        var self = this;
        var ind;
        var coll = self.map.getLayers();
        coll.forEach(function (elem, i, arr) {
            var id = elem.get('msp_id');
            if (id == self.id) {
                ind = i;
            }
        });
        self.newLayer();
        coll.setAt(ind, self.layer);
        self.map.render();
    },
    addRule: function(rule) {
        var self = this;
        rule.model = self.model;
        rule.layer = self;
        rule = new MSPRule(rule);
        self.rules.push(rule);
        self.refresh();
    },
    deleteRules: function(rules) {
        var self = this;
        var rules2 = [];
        $.each(self.rules, function(i, rule) {
            if (!rules[rule.id]) {
                rules2.push(rule);
            }
        });
        self.rules = rules2;
        self.refresh();
    },
    selectRule: function(id) {
        var self = this;
        var retval = null;
        $.each(self.rules, function(i, rule) {
            if (rule.id == id) {
                retval = rule;
                return false;
            }
        });
        return retval;
    },
    setRuleActive: function(id, active) {
        var self = this;
        $.each(self.rules, function(i, rule) {
            if (rule.id == id) {
                rule.active = active;
                return false;
            }
        });
        self.refresh();
    }
};

function MSPRule(args) {
    var self = this;
    for (var key in args){
        self[key] = args[key];
    }
}

MSPRule.prototype = {
    getName: function() {
        var self = this;
        var dataset = self.model.getDataset(self.dataset);
        if (!dataset) return "Dataset "+self.dataset+" is missing.";
        var name = dataset.name;
        if (dataset.classes > 1) {
            var value = self.value;
            if (dataset.semantics) value = dataset.semantics[value];
            name += ' '+self.op+' '+value;
        }
        return name;
    },
    getMinMax: function() {
        var self = this;
        var dataset = self.model.getDataset(self.dataset);
        if (!dataset) return {
            min:null,
            max:null,
            classes:null,
            data_type:null,
            semantics:null
        };
        return {
            min:dataset.min_value,
            max:dataset.max_value,
            classes:dataset.classes,
            data_type:dataset.data_type,
            semantics:data_type.semantics
        };
    },
    description: function() {
        var self = this;
        var dataset = self.model.getDataset(self.dataset);
        if (!dataset) return "Dataset "+self.dataset+" is missing. Its database entry is probably incomplete.";
        return dataset.description;
    }
};
