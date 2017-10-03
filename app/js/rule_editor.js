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
/*global $, msp*/

msp.Controller.prototype.datasetValueWidget = function (args) {
    var self = this,
        attr = {
            container: self.selector,
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
    } else if (args.dataset.data_type === msp.enum.BOOLEAN) {
        $(self.selector + ' #descr').html(args.dataset.descr);
        args.elem.html(args.elem_pre);
    } else {
        $(self.selector + ' #descr').html(args.dataset.descr);
        attr.newValue = args.newValue;
        if (args.dataset.semantics) {
            attr.type = 'select';
            attr.list = args.dataset.semantics;
        } else if (args.dataset.data_type === msp.enum.INTEGER) {
            attr.type = 'spinner';
        } else if (args.dataset.data_type === msp.enum.REAL) {
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
        widget = new msp.Widget(attr);
        args.elem.html(args.elem_pre + msp.e('p', {}, widget.html()));
        widget.prepare();
    }
    return widget;
};

msp.Controller.prototype.editBooleanRule = function (args) {
    var self = this,
        owner = self.model.layer.owner === self.model.config.config.user,
        value,
        html = '',
        make_op = function (dataset) {
            return dataset ? new msp.Widget({
                container: self.selector,
                id: 'rule-op',
                type: 'select',
                list: self.klasses.op,
                includeItem: function (item) {
                    if (dataset.data_type === msp.enum.BOOLEAN) {
                        return item.name === '==' || item.name === 'NOT';
                    }
                    return true;
                },
                nameForItem: function (item) {
                    if (dataset.data_type === msp.enum.BOOLEAN) {
                        if (item.name === '==') {
                            return 'IS';
                        }
                        return 'IS NOT';
                    }
                    return item.name;
                },
                selected: args.rule ? args.rule.op : null,
                pretext: 'Define the operator:<br/>'
            }) : new msp.Widget({
                container: self.selector,
                pretext: 'No datasets available.',
                id: 'rule-op',
                type: 'paragraph'                    
            });
        },
        op = args.rule ? make_op(args.rule.dataset) : null,
        threshold,
        pretext = 'Define the threshold:<br/>',
        regex;

    value = new msp.Widget({
        container: self.selector,
        id: 'rule-defs',
        type: 'paragraph',
    });
    if (args.rule) {
        html += args.rule.getCriteria().name;
        regex = new RegExp('==');
        html = html
            .replace(/^- If/, 'Do not allocate if')
            .replace(regex, 'equals:');
        if (!owner) {
            html += msp.e('p', {}, 'Et ole tämän tason omistaja. Muutokset ovat tilapäisiä.');
        }
        html += msp.e('p', {}, 'Rule is based on ' + args.dataset.name);
    } else {
        html += msp.e('p', {}, args.dataset.html());
    }
    html += msp.e('p', {id: 'descr'}, '');
    html += value.html();

    self.editor.html(html);

    if (args.rule) {
        threshold = self.datasetValueWidget({
            id: 'thrs',
            dataset: args.dataset,
            rule: args.rule,
            elem: value,
            elem_pre: msp.e('p', {}, op.html()),
            pretext: pretext
        });
    } else {
        args.dataset.changed((function changed() {
            var dataset2 = args.dataset.getSelected();
            op = make_op(dataset2);
            threshold = self.datasetValueWidget({
                id: 'thrs',
                dataset: dataset2,
                elem: value,
                elem_pre: msp.e('p', {}, op.html()),
                pretext: pretext
            });
            return changed;
        }()));
    }

    return function () {
        var retval = {},
            dataset = args.rule ? args.dataset : args.dataset.getSelected();
        if (!args.rule) {
            retval.dataset = dataset ? dataset.id : undefined;
        }
        retval.op = op.getSelected();
        if (retval.op) {
            retval.op = retval.op.id;
        }
        if (dataset.data_type === msp.enum.BOOLEAN) {
            retval.value = 1; // the semantics of binary datasets are 0: false, 1: true
        } else {
            retval.value = threshold ? threshold.getValue() : 0;
            if (dataset.semantics) {
                retval.value = parseInt(retval.value, 10);
            }
        }
        return retval;
    };
};

msp.Controller.prototype.editBoxcarRule = function (args) {
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
        form = new msp.Widget({
            container: self.selector,
            id: 'form',
            type: 'select',
            list: {1: 'Normal _/¯\\_', 2: 'Inverted ¯\\_/¯'},
            selected: args.rule ? args.rule.boxcar_type : 'Normal _/¯\\_',
        }),
        x0 = new msp.Widget({
            container: self.selector,
            id: 'x0p',
            type: 'paragraph'
        }),
        x1 = new msp.Widget({
            container: self.selector,
            id: 'x1p',
            type: 'paragraph'
        }),
        x2 = new msp.Widget({
            container: self.selector,
            id: 'x2p',
            type: 'paragraph'
        }),
        x3 = new msp.Widget({
            container: self.selector,
            id: 'x3p',
            type: 'paragraph'
        }),
        weight = new msp.Widget({
            container: self.selector,
            id: 'weight',
            type: 'text',
            value: args.rule ? args.rule.weight : 1,
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

    if (args.rule) {
        html += msp.e('p', {}, 'Rule is based on ' + args.dataset.name);
    } else {
        html += msp.e('p', {}, args.dataset.html());
    }

    html += msp.e('p', {id: 'descr'}, '');
    html += form.html();
    html += x0.html();
    html += x1.html();
    html += x2.html();
    html += x3.html();
    html += weight.html();
    self.editor.html(html);

    newValue = function (value) {
        x0v = x0Widget.getFloatValue();
        x1v = x1Widget.getFloatValue();
        x2v = x2Widget.getFloatValue();
        x3v = x3Widget.getFloatValue();
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

    if (args.rule) {
        x0Widget = self.datasetValueWidget({id: 'x0', dataset: args.dataset, rule: args.rule, elem: x0, newValue: newValue});
        x1Widget = self.datasetValueWidget({id: 'x1', dataset: args.dataset, rule: args.rule, elem: x1, newValue: newValue});
        x2Widget = self.datasetValueWidget({id: 'x2', dataset: args.dataset, rule: args.rule, elem: x2, newValue: newValue});
        x3Widget = self.datasetValueWidget({id: 'x3', dataset: args.dataset, rule: args.rule, elem: x3, newValue: newValue});
        x0Widget.setValue(args.rule.boxcar_x0);
        x1Widget.setValue(args.rule.boxcar_x1);
        x2Widget.setValue(args.rule.boxcar_x2);
        x3Widget.setValue(args.rule.boxcar_x3);
    } else {
        args.dataset.changed((function changed() {
            var set = args.dataset.getSelected();
            x0Widget = self.datasetValueWidget({id: 'x0', dataset: set, rule: args.rule, elem: x0, newValue: newValue});
            x1Widget = self.datasetValueWidget({id: 'x1', dataset: set, rule: args.rule, elem: x1, newValue: newValue});
            x2Widget = self.datasetValueWidget({id: 'x2', dataset: set, rule: args.rule, elem: x2, newValue: newValue});
            x3Widget = self.datasetValueWidget({id: 'x3', dataset: set, rule: args.rule, elem: x3, newValue: newValue});
            return changed;
        }()));
    }

    return function () {
        var retval = {
            boxcar_type: {value:form.getValue(), selected: form.getSelected()},
            boxcar_x0: x0Widget.getFloatValue(),
            boxcar_x1: x1Widget.getFloatValue(),
            boxcar_x2: x2Widget.getFloatValue(),
            boxcar_x3: x3Widget.getFloatValue(),
            weight: weight.getValue()
        };
        if (!args.rule) {
            retval.dataset = args.dataset.getSelected().id;
        }
        return retval;
    };

};

msp.Controller.prototype.editBayesianRule = function (args) {
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
            if (!dataset) {
                return {
                    descr: msp.e('font', {color: 'red'}, 'No suitable datasets available.'),
                    states: ''
                };
            }
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
                states: 'States: ' + dataset.min_value + '..' + dataset.max_value + msp.e('p', {}, states)
            };
        };

    if (!args.rule) {
        $.each(self.model.datasets.layers, function (i, dataset) {
            if (dataset.data_type === msp.enum.INTEGER) {
                dataset_list.push(dataset);
            }
        });
        args.dataset = new msp.Widget({
            container: self.selector,
            id: 'rule-dataset',
            type: 'select',
            list: dataset_list,
            selected: dataset_list[0],
            pretext: 'Base the rule on dataset: '
        });
    }

    network = self.networks.find(function (network) {
        return network.name === self.model.layer.network.name;
    });
    $.each(network.nodes, function (i, node) {
        var used = node.name === self.model.layer.output_node.name;
        if (args.rule && node.name === args.rule.node) {
            // current
            nodes.push(node);
            return true;
        }
        if (!used) {
            $.each(self.model.layer.rules, function (i, rule) {
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
    node = new msp.Widget({
        container: self.selector,
        id: 'rule-node',
        type: 'select',
        list: nodes,
        selected: args.rule ? args.rule.node : nodes[0],
        pretext: 'Link the dataset to node: '
    });
    offset = new msp.Widget({
        container: self.selector,
        id: 'rule-offset',
        type: 'spinner',
        value: args.rule ? args.rule.state_offset : 0,
        min: -10,
        max: 10,
        pretext: 'Offset (to match states): '
    });

    if (args.rule) {
        html += msp.e('p', {}, 'Rule is based on ' + args.dataset.name);
    } else {
        html += msp.e('p', {}, args.dataset.html());
    }

    html += msp.e('p', {id: 'dataset-states'}, '') +
        msp.e('p', {id: 'descr'}, '') +
        msp.e('p', {}, offset.html()) +
        node.html() +
        msp.e('p', {id: 'node-states'}, '');

    self.editor.html(html);
    offset.prepare();

    if (args.rule) {
        html = dataset_info(args.dataset);
        $(self.selector + ' #descr').html(html.descr);
        $(self.selector + ' #dataset-states').html(html.states);
    } else {
        args.dataset.changed((function changed() {
            html = dataset_info(args.dataset.getSelected());
            $(self.selector + ' #descr').html(html.descr);
            $(self.selector + ' #dataset-states').html(html.states);
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
        $(self.selector + ' #node-states').html('Description: ' + desc + '<br/>' + 'States: ' + states);
        return changed;
    }()));

    return function () {
        var retval = {};
        if (!args.rule) {
            retval.dataset = args.dataset.getSelected().id;
        }
        retval.state_offset = offset.getValue();
        retval.node = node.getSelected().name;
        return retval;
    };
};
