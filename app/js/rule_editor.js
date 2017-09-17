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
/*global $, alert, element, Widget, MSPController*/

MSPController.prototype.datasetValueWidget = function (args) {
    var self = this,
        attr = {
            container_id: self.editor_id,
            id: args.id,
            pretext: args.pretext || '',
        },
        attr2,
        widget = null;
    if (!args.elem_pre) {
        args.elem_pre = '';
    }
    if (!args.dataset) {
        args.elem.html('');
    } else if (args.dataset.binary) {
        $(self.editor_id + ' #descr').html(args.dataset.descr);
        args.elem.html(args.elem_pre);
    } else {
        $(self.editor_id + ' #descr').html(args.dataset.descr);
        attr.newValue = args.newValue;
        if (args.dataset.semantics) {
            attr.type = 'select';
            attr.list = args.dataset.semantics;
        } else if (args.dataset.data_type === 'integer') {
            attr.type = 'spinner';
        } else if (args.dataset.data_type === 'real') {
            attr.type = 'slider';
            attr.slider_value_id = args.id + '-value';
        }
        if (args.rule) {
            if (args.dataset.semantics) {
                attr.selected = args.dataset.semantics[args.rule.value];
            } else {
                attr2 = args.rule.getMinMax();
                attr.min = attr2.min;
                attr.max = attr2.max;
                attr.value = args.rule.value;
            }
        } else {
            if (args.dataset.semantics) {
                attr.selected = undefined;
            } else {
                attr.min = args.dataset.min_value;
                attr.max = args.dataset.max_value;
                attr.value = args.dataset.min_value;
            }
        }
        widget = new Widget(attr);
        args.elem.html(args.elem_pre + element('p', {}, widget.html()));
        widget.prepare();
    }
    return widget;
};

MSPController.prototype.editBooleanRule = function (plan, use, layer, rule, dataset) {
    var self = this,
        owner = layer.owner === self.model.user,
        value,
        html = '',
        make_op = function (dataset) {
            return new Widget({
                container_id: self.editor_id,
                id: 'rule-op',
                type: 'select',
                list: self.klasses.op,
                includeItem: function (item) {
                    if (dataset.binary) {
                        return item.name === '==' || item.name === 'NOT';
                    }
                    return true;
                },
                selected: rule ? rule.op : null,
                pretext: 'Define the operator:<br/>'
            });
        },
        op = rule ? make_op(rule.dataset) : null,
        threshold,
        pretext = 'Define the threshold:<br/>',
        regex;

    value = new Widget({
        container_id: self.editor_id,
        id: 'rule-defs',
        type: 'para',
    });
    if (rule) {
        html += rule.getCriteria().name;
        regex = new RegExp('==');
        html = html
            .replace(/^- If/, 'Do not allocate if')
            .replace(regex, 'equals:');
        if (!owner) {
            html += element('p', {}, 'Et ole tämän tason omistaja. Muutokset ovat tilapäisiä.');
        }
        html += element('p', {}, 'Rule is based on ' + dataset.name);
    } else {
        html += element('p', {}, dataset.html());
    }
    html += element('p', {id: 'descr'}, '');
    html += value.html();

    self.editor.html(html);

    if (rule) {
        threshold = self.datasetValueWidget({
            id: 'thrs',
            dataset: dataset,
            rule: rule,
            elem: value,
            elem_pre: element('p', {}, op.html()),
            pretext: pretext
        });
    } else {
        dataset.changed((function changed() {
            var dataset2 = dataset.getSelected();
            op = make_op(dataset2);
            threshold = self.datasetValueWidget({
                id: 'thrs',
                dataset: dataset2,
                elem: value,
                elem_pre: element('p', {}, op.html()),
                pretext: pretext
            });
            return changed;
        }()));
    }

    return function () {
        var retval = {};
        if (!rule) {
            dataset = dataset.getSelected();
            retval.dataset = dataset.id;
        }
        if (dataset.binary) {
            retval.op = op.getSelected().id;
        } else {
            retval.op = op.getSelected().id;
            retval.value = threshold.getValue();
            if (dataset.semantics) {
                retval.value = parseInt(retval.value, 10);
            }
        }
        return retval;
    };
};

MSPController.prototype.editBoxcarRule = function (rule, dataset) {
    // boxcar rule converts data value into range [0..weight] or [weight..0] if weight is negative
    // the rule consists of four values (x0, x1, x2, x3) and a boolean form parameter in addition to weight
    // the data value is first mapped to a value (y) between 0 and 1
    // if data value (x) is <= x0, y = 0, (1 if form is false)
    // if data value (x) is between x0 and x1, y increases linearly from 0 to 1, (1 to 0 if form is false)
    // if data value (x) is between x1 and x2, y = 1, (0 if form is false)
    // if data value (x) is between x2 and x3, y decreases linearly from 1 to 0, (0 to 1 if form is false)
    // if data value (x) is >= x3, y = 0, (1 if form is false)
    // final rule value is then y*weight
    var self = this,
        html = '',
        form = new Widget({
            container_id: self.editor_id,
            id: 'form',
            type: 'checkbox',
            selected: rule ? 1 - rule.boxcar : 0,
            label: 'Turn the function upside down ¯¯\\__/¯¯'
        }),
        x0 = new Widget({
            container_id: self.editor_id,
            id: 'x0p',
            type: 'para'
        }),
        x1 = new Widget({
            container_id: self.editor_id,
            id: 'x1p',
            type: 'para'
        }),
        x2 = new Widget({
            container_id: self.editor_id,
            id: 'x2p',
            type: 'para'
        }),
        x3 = new Widget({
            container_id: self.editor_id,
            id: 'x3p',
            type: 'para'
        }),
        weight = new Widget({
            container_id: self.editor_id,
            id: 'weight',
            type: 'text',
            value: rule ? rule.weight : 1,
            pretext: 'Weight: '
        }),
        x0Widget,
        x1Widget,
        x2Widget,
        x3Widget,
        x0v,
        x1v,
        x2v,
        x3v,
        newValue;

    if (rule) {
        html += element('p', {}, 'Rule is based on ' + dataset.name);
    } else {
        html += element('p', {}, dataset.html());
    }

    html += element('p', {id: 'descr'}, '');
    html += form.html();
    html += x0.html();
    html += x1.html();
    html += x2.html();
    html += x3.html();
    html += weight.html();
    self.editor.html(html);

    newValue = function (value) {
        x0v = x0Widget.getValue();
        x1v = x1Widget.getValue();
        x2v = x2Widget.getValue();
        x3v = x3Widget.getValue();
        if (this.id === 'x0') {
            if (x1v < value) {
                x1Widget.setValue(value);
            }
            if (x2v < value) {
                x2Widget.setValue(value);
            }
            if (x3v < value) {
                x3Widget.setValue(value);
            }
        } else if (this.id === 'x1') {
            if (x0v > value) {
                x0Widget.setValue(value);
            }
            if (x2v < value) {
                x2Widget.setValue(value);
            }
            if (x3v < value) {
                x3Widget.setValue(value);
            }
        } else if (this.id === 'x2') {
            if (x0v > value) {
                x0Widget.setValue(value);
            }
            if (x1v > value) {
                x1Widget.setValue(value);
            }
            if (x3v < value) {
                x3Widget.setValue(value);
            }
        } else if (this.id === 'x3') {
            if (x0v > value) {
                x0Widget.setValue(value);
            }
            if (x1v > value) {
                x1Widget.setValue(value);
            }
            if (x2v > value) {
                x2Widget.setValue(value);
            }
        }
    };

    if (rule) {
        x0Widget = self.datasetValueWidget({id: 'x0', dataset: dataset, rule: rule, elem: x0, newValue: newValue});
        x1Widget = self.datasetValueWidget({id: 'x1', dataset: dataset, rule: rule, elem: x1, newValue: newValue});
        x2Widget = self.datasetValueWidget({id: 'x2', dataset: dataset, rule: rule, elem: x2, newValue: newValue});
        x3Widget = self.datasetValueWidget({id: 'x3', dataset: dataset, rule: rule, elem: x3, newValue: newValue});
        x0Widget.setValue(rule.boxcar_x0);
        x1Widget.setValue(rule.boxcar_x1);
        x2Widget.setValue(rule.boxcar_x2);
        x3Widget.setValue(rule.boxcar_x3);
    } else {
        dataset.changed((function changed() {
            var set = dataset.getSelected();
            x0Widget = self.datasetValueWidget({id: 'x0', dataset: set, rule: rule, elem: x0, newValue: newValue});
            x1Widget = self.datasetValueWidget({id: 'x1', dataset: set, rule: rule, elem: x1, newValue: newValue});
            x2Widget = self.datasetValueWidget({id: 'x2', dataset: set, rule: rule, elem: x2, newValue: newValue});
            x3Widget = self.datasetValueWidget({id: 'x3', dataset: set, rule: rule, elem: x3, newValue: newValue});
            return changed;
        }()));
    }

    return function () {
        var retval = {};
        if (!rule) {
            dataset = dataset.getSelected();
            retval.dataset = dataset.id;
        }
        retval.boxcar = form.getValue();
        retval.boxcar_x0 = x0Widget.getValue();
        retval.boxcar_x1 = x1Widget.getValue();
        retval.boxcar_x2 = x2Widget.getValue();
        retval.boxcar_x3 = x3Widget.getValue();
        retval.weight = weight.getValue();
        return retval;
    };

};

MSPController.prototype.editBayesianRule = function (layer, rule, dataset) {
    // rule is a node in a Bayesian network
    // for now we assume it is a (hard) evidence node, i.e.,
    // the dataset must be integer, and its value range the same as the node's

    var self = this,
        dataset_list = [],
        network = null,
        nodes = [],
        node,
        offset,
        html = '',
        dataset_info = function (dataset) {
            var states = '',
                j = 0;
            if (dataset.semantics) {
                $.each(dataset.semantics, function (i, value) {
                    if (j > 0) {
                        states += ', ';
                    }
                    states += i + ': ' + value;
                    j += 1;
                });
            }
            return {
                descr: dataset.descr,
                states: 'States: ' + dataset.min_value + '..' + dataset.max_value + element('p', {}, states)
            };
        };

    if (!rule) {
        $.each(self.model.datasets.layers, function (i, dataset) {
            if (dataset.data_type === 'integer') {
                dataset_list.push(dataset);
            }
        });
        dataset = new Widget({
            container_id: self.editor_id,
            id: 'rule-dataset',
            type: 'select',
            list: dataset_list,
            selected: dataset_list[0],
            pretext: 'Base the rule on dataset: '
        });
    }

    network = self.networks.find(function (network) {
        return network.name === layer.network.name;
    });
    $.each(network.nodes, function (i, node) {
        var used = node.name === layer.output_node.name;
        if (rule && node.name === rule.node) {
            // current
            nodes.push(node);
            return true;
        }
        if (!used) {
            $.each(layer.rules, function (i, rule) {
                if (node.name === rule.node) {
                    // already used
                    used = true;
                    return false;
                }
            });
        }
        if (!used) {
            nodes.push(node);
        }
    });
    node = new Widget({
        container_id: self.editor_id,
        id: 'rule-node',
        type: 'select',
        list: nodes,
        selected: rule ? rule.node : nodes[0],
        pretext: 'Link the dataset to node: '
    });
    offset = new Widget({
        container_id: self.editor_id,
        id: 'rule-offset',
        type: 'spinner',
        value: rule ? rule.state_offset : 0,
        min: -10,
        max: 10,
        pretext: 'Offset (to match states): '
    });

    if (rule) {
        html += element('p', {}, 'Rule is based on ' + dataset.name);
    } else {
        html += element('p', {}, dataset.html());
    }

    html += element('p', {id: 'dataset-states'}, '') +
        element('p', {id: 'descr'}, '') +
        element('p', {}, offset.html()) +
        node.html() +
        element('p', {id: 'node-states'}, '');

    self.editor.html(html);
    offset.prepare();

    if (rule) {
        html = dataset_info(dataset);
        $(self.editor_id + ' #descr').html(html.descr);
        $(self.editor_id + ' #dataset-states').html(html.states);
    } else {
        dataset.changed((function changed() {
            html = dataset_info(dataset.getSelected());
            $(self.editor_id + ' #descr').html(html.descr);
            $(self.editor_id + ' #dataset-states').html(html.states);
            return changed;
        }()));
    }

    node.changed((function changed() {
        var n = node.getSelected(),
            states = '',
            desc = '';
        if (n) {
            $.each(n.states, function (i, state) {
                if (i > 0) {
                    states += ', ';
                }
                states += i + ': ' + state;
            });
            if (n.attributes) {
                desc = n.attributes.HR_Desc;
            }
        }
        $(self.editor_id + ' #node-states').html('Description: ' + desc + '<br/>' + 'States: ' + states);
        return changed;
    }()));

    return function () {
        var retval = {};
        if (!rule) {
            dataset = dataset.getSelected();
            retval.dataset = dataset.id;
        }
        retval.state_offset = offset.getValue();
        retval.node = node.getSelected().name;
        return retval;
    };
};
