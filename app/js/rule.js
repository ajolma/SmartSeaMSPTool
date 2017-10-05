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
/*global msp*/

// these must match what the server uses:
msp.enum = {
    INTEGER: 'integer',
    REAL: 'real',
    BOOLEAN: 'boolean',
    BAYESIAN_NETWORK: 'Bayesian network',
    BOXCAR: 'boxcar',
    EXCLUSIVE: 'exclusive',
    INCLUSIVE: 'inclusive',
    ADDITIVE: 'additive',
    MULTIPLICATIVE: 'multiplicative',
    DATA: 'Data',
    ECOSYSTEM: 'Ecosystem'    
};

/**
 * Options for creating a rule.
 * @typedef {Object} MSPRuleOptions
 * @property {number} id - .
 * @property {MSPLayer} layer - .
 * @property {MSPLayer} dataset - .
 * @property {boolean} active - .
 * @property {string} op - .
 * @property {number} value - .

 */
/**
 * A rule in a layer.
 * @constructor
 * @param {MSPRuleOptions} options - Options.
 */
msp.Rule = function (args) {
    var self = this;
    self.id = args.id;
    self.layer = args.layer;
    self.dataset = args.dataset;
    self.active = args.active;
    self.edit(args);
};

msp.Rule.prototype = {
    edit: function (rule) {
        var self = this;
        if (self.layer.rule_class === msp.enum.EXCLUSIVE || self.layer.rule_class === msp.enum.INCLUSIVE) {
            self.op = rule.op;
            if (self.dataset.data_type !== msp.enum.BOOLEAN) {
                self.value = rule.value;
            }
        } else if (self.layer.rule_class === msp.enum.BOXCAR) {
            self.boxcar_type = rule.boxcar_type;
            self.boxcar_x0 = rule.boxcar_x0;
            self.boxcar_x1 = rule.boxcar_x1;
            self.boxcar_x2 = rule.boxcar_x2;
            self.boxcar_x3 = rule.boxcar_x3;
            self.weight = rule.weight;
        } else if (self.layer.rule_class === msp.enum.BAYESIAN_NETWORK) {
            self.state_offset = rule.state_offset;
            self.node = rule.node;
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
        if (self.layer.rule_class === msp.enum.EXCLUSIVE || self.layer.rule_class === msp.enum.INCLUSIVE) {
            if (self.dataset.data_type === msp.enum.BOOLEAN) {
                if (self.op !== '==') {
                    name = self.op + ' ' + name;
                }
            } else {
                value = self.value;
                if (self.dataset.semantics) {
                    value = self.dataset.semantics[value];
                }
                name += ' ' + self.op + ' ' + value;
            }
        } else if (self.layer.rule_class === msp.enum.BOXCAR) {
            name += ': Boxcar ' + self.boxcar_type + ' ';
            name += self.boxcar_x0 + ', ' + self.boxcar_x1 + ', ' + self.boxcar_x2 + ', ' + self.boxcar_x3;
            name += ' weight ' + self.weight;
        } else if (self.layer.rule_class === msp.enum.BAYESIAN_NETWORK) {
            if (self.layer.network) {
                value = self.layer.network.nodes.find(function (node) {
                    return node.name === self.node;
                });
                name = (value ? value.name : '?') + '=' + name;
            } else {
                name = 'Bayesian networks are not available.';
            }
        } else {
            name = 'unknown';
        }
        return name;
    },
    getMinMax: function () {
        var self = this;
        return {
            min: self.dataset.min_value,
            max: self.dataset.max_value,
            data_type: self.dataset.data_type,
            semantics: self.dataset.semantics
        };
    },
    description: function () {
        var self = this;
        return self.dataset.description;
    }
};
