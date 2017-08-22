MSPController.prototype.datasetValueWidget = function(id, dataset, rule, elem, pre, newValue) {
    var self = this,
        args = {
            container_id: self.editor_id,
            id: id
        },
        attr,
        widget = null;
    if (!dataset) {
        elem.html('');
    } else if (dataset.classes === 1) {
        $(self.editor_id + ' #descr').html(dataset.descr);
        elem.html('Binary rule');
    } else {
        $(self.editor_id + ' #descr').html(dataset.descr);
        args.newValue = newValue;
        if (dataset.semantics) {
            args.type = 'select';
            args.list = dataset.semantics;
        } else if (dataset.data_type === 'integer') {
            args.type = 'spinner';
        } else if (dataset.data_type === 'real') {
            args.type = 'slider';
            args.slider_value_id = id + '-value';
        }
        if (rule) {
            attr = rule.getMinMax();
            args.min = attr.min;
            args.max = attr.max;
            args.value = rule.value;
        } else {
            args.min = dataset.min_value;
            args.max = dataset.max_value;
            args.value = dataset.min_value;
        }
        widget = new Widget(args);
        elem.html(pre + widget.html());
        widget.prepare();
    }
    return widget;
};

MSPController.prototype.editBooleanRule = function (plan, use, layer, rule, dataset) {
    // the rule can be binary, if dataset has only one class
    // otherwise the rule needs operator and threshold
    var self = this,
        owner = layer.owner === self.model.user,
        value,
        html = '',
        op,
        threshold,
        regex;
    
    op = new Widget({
        container_id: self.editor_id,
        id: 'rule-op',
        type: 'select',
        list: self.klasses['op'],
        pretext: 'Define the operator and the threshold:<br/>'
    });
    value = new Widget({
        container_id: self.editor_id,
        id: 'rule-defs',
        type: 'para'
    });
    if (rule) {
        html += rule.getCriteria().name;
        regex = new RegExp("==");
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
        threshold = self.datasetValueWidget('thrs', dataset, rule, value, op.html() + '&nbsp;');
    } else {
        dataset.changed((function changed() {
            threshold = self.datasetValueWidget('thrs', dataset.getSelected(), rule, value, op.html() + '&nbsp;');
            return changed;
        }()));
    }

    return function () {
        var retval = {};
        if (!rule) {
            dataset = dataset.getSelected();
            retval.dataset = dataset.id;
        }
        if (dataset.classes > 1) {
            retval.op = op.getSelected().id;
            retval.value = threshold.getValue();
        }
        return retval;
    };
};

MSPController.prototype.editBoxcarRule = function (plan, use, layer, rule, dataset) {
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
    
    newValue = function(value) {
        console.log(this.id + ' ' + value);
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
        x0Widget = self.datasetValueWidget('x0', dataset, rule, x0, '', newValue);
        x1Widget = self.datasetValueWidget('x1', dataset, rule, x1, '', newValue);
        x2Widget = self.datasetValueWidget('x2', dataset, rule, x2, '', newValue);
        x3Widget = self.datasetValueWidget('x3', dataset, rule, x3, '', newValue);
        x0Widget.setValue(rule.boxcar_x0);
        x1Widget.setValue(rule.boxcar_x1);
        x2Widget.setValue(rule.boxcar_x2);
        x3Widget.setValue(rule.boxcar_x3);
    } else {
        dataset.changed((function changed() {
            x0Widget = self.datasetValueWidget('x0', dataset.getSelected(), rule, x0, '', newValue);
            x1Widget = self.datasetValueWidget('x1', dataset.getSelected(), rule, x1, '', newValue);
            x2Widget = self.datasetValueWidget('x2', dataset.getSelected(), rule, x2, '', newValue);
            x3Widget = self.datasetValueWidget('x3', dataset.getSelected(), rule, x3, '', newValue);
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

MSPController.prototype.editBayesianRule = function (plan, use, layer, rule, dataset) {
    // rule is a node in a Bayesian network
    // for now we assume it is a (hard) evidence node, i.e.,
    // the dataset must be integer, and its value range the same as the node's
    
    var self = this,
        dataset_list = [],
        dataset,
        network = null,
        nodes = [],
        node,
        offset,
        html = '';
    
    if (!rule) {
        /*jslint unparam: true*/
        $.each(self.model.datasets.layers, function (i, dataset) {
            if (dataset.data_type === "integer") {
                dataset_list.push(dataset);
            }
        });
        /*jslint unparam: false*/
        dataset = new Widget({
            container_id: self.editor_id,
            id: 'rule-dataset',
            type: 'select',
            list: dataset_list,
            selected: dataset_list[0],
            pretext: 'Base the rule on dataset: '
        });
    }
    
    self.getNetworks();
    /*jslint unparam: true*/
    $.each(self.networks, function (i, network2) {
        if (network2.id === layer.network_file) {
            network = network2;
            return false;
        }
    });
    $.each(network.nodes, function (i, node) {
        var used = node.id === layer.output_node;
        if (!used) {
            $.each(layer.rules, function (i, rule) {
                if (node.id === rule.node_id) {
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
    /*jslint unparam: false*/
    node = new Widget({
        container_id: self.editor_id,
        id: 'rule-node',
        type: 'select',
        list: nodes,
        selected: rule ? rule.node_id : nodes[0],
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
    
    html = element('p', {id: 'dataset-states'}, '') +
        element('p', {id: 'descr'}, '') +
        element('p', {}, offset.html()) +
        node.html() +
        element('p', {id: 'node-states'}, '');
    
    self.editor.html(html);
    offset.prepare();
    
    if (rule) {
    } else {
        dataset.changed((function changed() {
            var set = dataset.getSelected(),
                states = set.min_value + '..' + set.max_value + '<p>',
                j = 0;
            $(self.editor_id + ' #descr').html(set.descr);
            if (set.semantics) {
                $.each(set.semantics, function (i, value) {
                    if (j > 0) {
                        states += ', ';
                    }
                    states += i + ': ' + value;
                    j += 1;
                });
            }
            states += '</p>';
            $(self.editor_id + ' #dataset-states').html('States: ' + states);
            return changed;
        }()));
    }
    
    node.changed((function changed() {
        var n = node.getSelected(),
            states = '',
            desc = '';
        if (n) {
            $.each(n.values, function (i, value) {
                if (i > 0) {
                    states += ', ';
                }
                states += i + ': ' + value;
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
        retval.node_id = node.getSelected().id;
        return retval;
    };
};
