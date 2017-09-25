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
/*global $, alert, element, Widget, mspEnum, MSPRule, MSPLayer*/

// after https://alexatnet.com/articles/model-view-controller-mvc-javascript

/**
 * A singleton for communicating with the server about plans, uses,
 * layers, and rules.
 * @constructor
 * @param {MSPModel} model - Model.
 * @param {MSPView} view - View.
 */
function MSPController(options) {
    var self = this;
    self.model = options.model;
    self.server = self.model.serverURL() + '/browser/';
    self.view = options.view;
    self.dialog = options.dialog;
    self.selector = '#' + self.dialog;
    self.editor = $(self.selector);
    self.klasses = {};

    self.editor.dialog({
        autoOpen: false,
        modal: true
    });
}

MSPController.prototype = {
    /**
     * Get some lists from the server.
     */
    getKlasses: function () {
        var self = this,
            klasses = {
                use_class: '',
                layer_class: '',
                rule_class: '',
                activity: '',
                palette: '',
                op: '',
            },
            calls = [];
        $.each(klasses, function (klass) {
            calls.push(
                $.ajax({
                    headers: {
                        Accept: 'application/json'
                    },
                    url: self.server + klass,
                    success: function (result) {
                        var msg;
                        if (result.isOk === false) {
                            msg = result.message + '\n';
                        } else if (result.error) {
                            msg = result.error + '\n';
                        }
                        if (msg) {
                            self.error('Calling SmartSea MSP server failed: ' + msg);
                        } else {
                            self.klasses[klass] = result;
                        }
                    },
                    fail: function (xhr, textStatus) {
                        var msg = xhr.responseText || textStatus;
                        self.error('Calling SmartSea MSP server failed: ' + msg);
                    }
                })
            );
        });
        $.when.apply($, calls).then(function () {

            self.view.planCommand.attach(function (ignore, args) {
                if (args.cmd === 'add') {
                    self.editPlan(args);
                } else if (args.cmd === 'edit') {
                    self.editPlan(args);
                } else if (args.cmd === 'delete') {
                    self.deletePlan(args);
                }
            });

            self.view.useCommand.attach(function (ignore, args) {
                if (args.cmd === 'add') {
                    self.addUse(args);
                } else if (args.cmd === 'edit') {
                    if (args.use.id === 0) { // "Data"
                        self.editDatasetList(args);
                    } else {
                        self.editUse(args);
                    }
                } else if (args.cmd === 'delete') {
                    self.deleteUse(args);
                }
            });

            self.view.layerCommand.attach(function (ignore, args) {
                if (args.cmd === 'add') {
                    self.editLayer(args);
                } else if (args.cmd === 'edit') {
                    self.editLayer(args);
                } else if (args.cmd === 'delete') {
                    self.deleteLayer(args);
                }
            });

            self.view.ruleCommand.attach(function (ignore, args) {
                if (args.cmd === 'add') {
                    self.editRule(args);
                } else if (args.cmd === 'edit') {
                    self.editRule(args);
                } else if (args.cmd === 'delete') {
                    self.deleteRule(args);
                }
            });

            self.model.newPlans.attach(function () {
                self.editor.dialog('close');
            });

            self.model.error.attach(function (sender, args) {
                self.error(args.msg);
            });

            self.view.error.attach(function (sender, args) {
                self.error(args.msg);
            });
        }, function (a) {
            self.error('Calling SmartSea MSP server failed: ' + a.statusText);
        });
    },
    setEditorButtons: function (buttons) {
        var self = this,
            b = {};
        if (buttons.includes('ok')) {
            b.Ok = function () {
                if (self.ok()) {
                    self.editor.dialog('close');
                }
            };
        }
        if (buttons.includes('cancel')) {
            b.Cancel = function () {
                self.editor.dialog('close');
            };
        }
        if (buttons.includes('apply')) {
            b.Apply = function () {
                self.apply();
            };
        }
        if (buttons.includes('close')) {
            b.Close = function () {
                self.editor.dialog('close');
            };
        }
        self.editor.dialog('option', 'buttons', b);
    },
    setEditor: function (options) {
        var self = this;
        if (options.title) {
            self.editor.dialog('option', 'title', options.title);
        }
        self.editor.dialog('option', 'width', options.width || 350);
        self.editor.dialog('option', 'height', options.height || 400);
        if (options.html) {
            self.editor.html(options.error
                ? element('p', {style: 'color:red;'}, options.error) + options.html
                : options.html);
        }
        if (options.buttons) {
            self.setEditorButtons(options.buttons);
        } else if (options.applyClose) {
            self.setEditorButtons('apply close');
        } else {
            self.setEditorButtons('ok cancel');
        }
    },
    error: function (msg) {
        var self = this;
        self.setEditor({
            title: 'Error',
            html: msg,
            buttons: 'close'
        });
        self.editor.dialog('open');
    },
    post: function (args) {
        var self = this;
        $.ajaxSetup({
            headers: {
                Accept : 'application/json'
            },
            crossDomain: true,
            xhrFields: {
                withCredentials: true
            }
        });
        $.post(args.url, args.payload, function (data) {
            if (data.error) {
                self.error(data.error);
            } else {
                args.atSuccess(data);
            }
        }).fail(function (xhr, textStatus) {
            var msg = xhr.responseText || textStatus;
            self.error('Calling SmartSea MSP server failed. The error message is: ' + msg);
        });
    },
    getData: function (query, atSuccess) {
        var self = this,
            msg = 'Calling SmartSea MSP server failed: ';
        $.ajax({
            headers: {
                Accept: 'application/json'
            },
            url: self.server + query,
            success: function (result) {
                if (result.isOk === false) {
                    self.error(msg + result.message);
                } else if (result.error) {
                    self.error(msg + result.error);
                } else {
                    atSuccess(result);
                }
            },
            fail: function (xhr, textStatus) {
                self.error(msg + xhr.responseText || textStatus);
            }
        });
    },
    /**
     * Get the list of Bayesian Networks from the server.
     */
    getNetworks: function (when_done) {
        var self = this;
        if (!self.networks) {
            $.ajax({
                headers: {Accept: 'application/json'},
                url: self.model.serverURL() + '/networks',
                success: function (result) {
                    self.networks = result;
                    when_done();
                }
            });
        } else {
            when_done();
        }
    },
    /**
     * Get the plans from the server. This is the main bootstrap function.
     */
    loadPlans: function (when_done) {
        var self = this;
        self.post({
            url: self.model.serverURL() + '/plans',
            payload: {},
            atSuccess: function (data) {
                self.getNetworks(function () {
                    self.model.setPlans(data, self.networks);
                    self.getKlasses();
                    if (when_done) {
                        when_done();
                    }
                });
            }
        });
    },
    /**
     * Open a plan editor dialog.
     */
    editPlan: function (args) {
        var self = this,
            plan = args.cmd === 'add' ? null : self.model.plan,
            name = 'plans-name';
        self.setEditor({
            title: 'Suunnitelma',
            html: element('p', {}, 'Suunnitelman nimi: ' +
                          element('input', {type: 'text', id: name, value: plan ? plan.name : ''}, '')),
            error: args.error
        });
        self.ok = function () {
            var request = plan ? 'plan:' + plan.id + '?request=update' : 'plan?request=save';
            name = $(self.selector + ' #' + name).val();
            if (!self.model.planByName(name)) {
                self.post({
                    url: self.server + request,
                    payload: { name: name },
                    atSuccess: function (data) {
                        var plan_data = {
                            id: data.id.value,
                            owner: data.owner.value,
                            name: data.name.value
                        };
                        if (plan) {
                            self.model.editPlan(plan_data);
                        } else {    
                            self.model.addPlan(plan_data);
                        }
                    }
                });
            } else {
                args.error = 'Suunnitelma \'' + name + '\' on jo olemassa.';
                self.editPlan(args);
                return false;
            }
            return true;
        };
        self.editor.dialog('open');
    },
    /**
     * Confirm and delete a plan.
     */
    deletePlan: function () {
        var self = this;
        self.setEditor({
            title: 'Poista suunnitelma?',
            html: 'Haluatko varmasti poistaa koko suunnitelman \'' + self.model.plan.name + '\'?'
        });
        self.ok = function () {
            self.post({
                url: self.server + 'plan:' + self.model.plan.id + '?request=delete',
                atSuccess: function () {
                    self.model.deletePlan(self.model.plan.id);
                }
            });
            return true;
        };
        self.editor.dialog('open');
    },
    /**
     * Open add use dialog.
     */
    addUse: function () {
        var self = this,
            id = 'use-id',
            list = '';

        $.each(self.klasses.use_class, function (i, klass) {
            if (!self.model.hasUse(klass.id)) {
                list += element('option', {value: klass.id}, klass.name);
            }
        });

        self.setEditor({
            title: 'Uusi käyttömuoto',
            html: 'Select the class for the new use: ' + element('select', {id: id}, list)
        });

        self.ok = function () {
            id = $(self.selector + ' #' + id).val();
            self.post({
                url: self.server + 'plan:' + self.model.plan.id + '/uses?request=create',
                payload: {use_class: id},
                atSuccess: function (data) {
                    var use = {
                        id: data.id.value,
                        owner: data.owner.value,
                        plan: data.plan.value,
                        class_id: data.use_class.value,
                        layers: []
                    };
                    $.each(self.klasses.use_class, function (i, klass) {
                        if (klass.id === data.use_class.value) {
                            use.name = klass.name;
                            return false;
                        }
                    });
                    self.model.addUse(use);
                }
            });
            return true;
        };
        self.editor.dialog('open');
    },
    /**
     * Open edit use dialog.
     */
    editUse: function (args) {
        var self = this;
        self.getData('use_class:' + args.use.class_id + '/activities', function (activities) {
            $.each(activities, function (i, item) {
                activities[item.id] = item;
            });
            activities = new Widget({
                container: self.selector,
                id: 'activities_list',
                type: 'checkbox-list',
                list: self.klasses.activity,
                selected: activities,
                pretext: ''
            });
            self.setEditor({
                title: args.use.name,
                html: element('p', {}, 'Activities in this use. Sorry, not editable.')
                    + element('p', {}, activities.html())
            });
            self.ok = function () {
                return true;
            };
            self.editor.dialog('open');
        });
    },
    /**
     * Open a dialog for managing the list of datasets in a plan.
     */
    editDatasetList: function () {
        var self = this,
            inRules = self.model.datasetsInRules(),
            notInRules = [],
            datasets;

        // put into the list those datasets that are not in rules
        // selected are those in plan.data
        $.each(self.model.datasets.layers, function (i, layer) {
            if (!inRules[layer.id]) {
                notInRules.push(layer);
            }
        });
        datasets = new Widget({
            container: self.selector,
            id: 'dataset_list',
            type: 'checkbox-list',
            list: notInRules,
            selected: self.model.plan.data,
            pretext: 'Select the extra datasets for this plan: '
        });

        self.setEditor({
            title: 'Dataset list',
            html: element('p', {}, datasets.html())
        });

        self.ok = function () {
            var selected = datasets.getSelectedIds(),
                update = '';
            $.each(selected, function (id) {
                if (update) {
                    update += '&';
                }
                update += 'dataset=' + id;
            });
            self.post({
                url: self.server + 'plan:' + self.model.plan.id + '/extra_datasets?request=update',
                payload: update,
                atSuccess: function (data) {
                    self.model.setPlanData(data);
                }
            });
            return true;
        };
        self.editor.dialog('open');
    },
    /**
     * Confirm and delete a use from a plan.
     */
    deleteUse: function (args) {
        var self = this;
        self.setEditor({
            title: 'Poista käyttömuoto?',
            html: 'Haluatko varmasti poistaa käyttömuodon \'' + args.use.name +
                '\' suunnitelmasta \'' + self.model.plan.name + '\'?'
        });
        self.ok = function () {
            self.post({
                url: self.server + 'use:' + args.use.id + '?request=delete',
                atSuccess: function () {
                    self.model.deleteUse(args.use.id);
                }
            });
            return true;
        };
        self.editor.dialog('open');
    },
    availableLayerClasses: function (use) {
        var self = this,
            list = [];
        if (use.id <= 1) {
            return list;
        }
        $.each(self.klasses.layer_class, function (i, klass) {
            if (klass.id === 5) {
                return false; // Impact layer
            }
            var test = use.layers.find(function (element) {
                return element.class_id === klass.id;
            });
            if (!test) {
                list.push(klass);
            }
        });
        return list;
    },
    /**
     * Open a dialog for adding or editing a layer in a use of a plan.
     */
    editLayer: function (args) {
        var self = this,
            layer = args.cmd === 'add' ? undefined : self.model.layer,

            available_layer_classes = self.availableLayerClasses(args.use),

            class_list = layer
                ? null
                : new Widget({
                    container: self.selector,
                    id: 'layer-class',
                    type: 'select',
                    list: self.klasses.layer_class,
                    includeItem: function (klass) {
                        return available_layer_classes.find(function (element) {
                            return element.id === klass.id;
                        });
                    },
                    pretext: available_layer_classes.length ? 'The layer class: ' : ''
                }),

            klass = layer
                ? self.klasses.layer_class.find(function (element) {
                    return element.id === layer.class_id;
                })
                : null,

            rule_class_list = layer
                ? self.klasses.rule_class
                : new Widget({
                    container: self.selector,
                    id: 'layer-rule-class',
                    type: 'select',
                    list: self.klasses.rule_class,
                    pretext: 'The rule system: '
                }),

            rule_class_extra = new Widget({
                container: self.selector,
                id: 'rule-class-extra',
                type: 'paragraph'
            }),
            rule_class_extra2 = new Widget({
                container: self.selector,
                id: 'rule-class-extra2',
                type: 'paragraph'
            }),
            rule_class_extra3 = new Widget({
                container: self.selector,
                id: 'rule-class-extra3',
                type: 'paragraph'
            }),
            palette = new Widget({
                container: self.selector,
                id: 'layer-color',
                type: 'select',
                list: self.klasses.palette,
                selected: (layer && layer.style ? layer.style.palette : null),
                pretext: 'Layer color scheme: '
            }),
            network,
            node,
            state,
            select_network_node = function (network, selected, extra) {
                node = new Widget({
                    container: self.selector,
                    id: 'layer-node',
                    type: 'select',
                    list: network.nodes,
                    selected: selected,
                    pretext: 'Select the node whose value to use for this layer: '
                });
                rule_class_extra2.html(element('p', {}, extra) +
                                       element('p', {}, node.html()));

                node.changed((function changed() {
                    var node2 = node.getSelected(), // node2 is not null since we have set selected above
                        desc = '';
                    if (node2.attributes) {
                        desc = node2.attributes.HR_Desc;
                    }
                    state = new Widget({
                        container: self.selector,
                        id: 'layer-state',
                        type: 'select',
                        list: node2.states,
                        selected: node2.states[0],
                        pretext: 'Select the state for the layer value: '
                    });
                    rule_class_extra3.html(element('p', {}, 'Description: ' + desc) +
                                           element('p', {}, state.html()));
                    return changed;
                }()));
            },

            html = layer
                ? element('p', {}, 'This layer attempts to depict ' + klass.name + '.') +
                  element('p', {}, 'Rule system is ' + layer.rule_class + '.')
                : element('p', {}, class_list.html()) +
                  element('p', {}, rule_class_list.html()),

            value_from = function (obj) {
                return obj ? obj.value : null;
            };

        if (!layer && available_layer_classes.length === 0) {
            self.error('No more slots for layers in this use.');
            return;
        }

        html = element('p', {}, 'This layer is computed by rules.') + html;
        html += element('p', {}, rule_class_extra.html());
        html += element('p', {}, rule_class_extra2.html());
        html += element('p', {}, rule_class_extra3.html());
        if (args.use.id === 0) {
            html += element('p', {}, 'The color setting is temporary for datasets.');
        }
        html += element('p', {}, palette.html());

        self.setEditor({
            title: 'Layer for ' + args.use.name,
            width: 500,
            height: 600,
            applyClose: layer,
            html: html
        });

        if (layer) {
            if (layer.rule_class === mspEnum.BAYESIAN_NETWORK) {
                select_network_node(
                    self.networks.find(function (network) {
                        return network.name === layer.network.name;
                    }),
                    layer.output_node,
                    'The layer is based on Bayesian network <b>' + layer.network.name + '</b>'
                );
            }
        } else {
            rule_class_list.changed((function changed() {
                var klass2 = rule_class_list.getSelected();
                if (klass2 && klass2.name === mspEnum.BAYESIAN_NETWORK) {

                    network = new Widget({
                        container: self.selector,
                        id: 'layer-network',
                        type: 'select',
                        list: self.networks,
                        selected: self.networks[0],
                        pretext: 'Select the Bayesian network: '
                    });
                    rule_class_extra.html(element('p', {}, network.html()));

                    network.changed((function changed() {
                        // net is not null since we have set selected above
                        var net = network.getSelected();
                        select_network_node(net, net.nodes[0], '');
                        return changed;
                    }()));

                } else {
                    rule_class_extra.html('');
                    rule_class_extra2.html('');
                    rule_class_extra3.html('');
                }
                return changed;
            }()));
        }

        self.ok = function () { // save new layer
            var klass2 = class_list.getSelected(),
                rule_class = rule_class_list.getSelected(),
                color = palette.getSelected(),
                payload = {
                    layer_class: klass2 ? klass2.id : null,
                    palette: color.id,
                    rule_class: rule_class.id
                },
                url;
            if (!klass2) {
                return true;
            }
            if (rule_class.name === mspEnum.BAYESIAN_NETWORK) {
                payload.network = network.getSelected().name;
                payload.output_node = node.getSelected().name;
                payload.output_state = state.getSelected();
            }
            url = self.server + 'plan:' + self.model.plan.id + '/uses:' + args.use.id + '/' + 'layers?request=create';
            self.post({
                url: url,
                payload: payload,
                atSuccess: function (response) {
                    var data = {
                        id: response.id.value,
                        name: klass2.name,
                        owner: response.owner.value,

                        model: self.model,
                        use: args.use,
                        style: {
                            palette: color.name
                        },

                        // can't create new datasets

                        class_id: response.layer_class.value,
                        rule_class: rule_class.name,

                        rules: []
                    };
                    if (rule_class.name === mspEnum.BAYESIAN_NETWORK) {
                        data.network = network.getSelected();
                        data.output_node = node.getSelected();
                        data.output_state = value_from(response.rule_system.columns.output_state);
                    }
                    self.model.addLayer(new MSPLayer(data));
                }
            });
            return true;
        };

        self.apply = function () { // modify existing layer
            var color = palette.getSelected(),
                payload = {
                    palette: color.id
                },
                url;
            if (layer.rule_class === mspEnum.BAYESIAN_NETWORK) {
                payload.output_node = node.getSelected().name;
                payload.output_state = state.getSelected();
            }
            if (args.use.id === 0) {
                // layer is dataset
                layer.style = {
                    palette: color.name
                };
                layer.refresh();
                self.model.selectLayer(layer);
            } else {
                url = self.server + 'plan:' + self.model.plan.id + '/uses:' + args.use.id +
                    '/layers:' + self.model.layer.id + '?request=update';
                self.post({
                    url: url,
                    payload: payload,
                    atSuccess: function (response) {
                        // only editable data to args
                        var data = {
                            style: {
                                palette: color.name
                            }
                        };
                        if (layer.rule_class === mspEnum.BAYESIAN_NETWORK) {
                            data.output_node = node.getSelected();
                            data.output_state = value_from(response.rule_system.columns.output_state);
                        }
                        layer.edit(data);
                        layer.refresh();
                        self.model.selectLayer(layer);
                    }
                });
            }
            return true;
        };

        self.editor.dialog('open');
    },
    /**
     * Confirm and delete a layer from a use of a plan.
     */
    deleteLayer: function (args) {
        var self = this;
        self.setEditor({
            title: 'Poista taso?',
            html: 'Haluatko varmasti poistaa tason \'' + self.model.layer.name +
                '\' käyttömuodosta \'' + args.use.name + '\'?'
        });
        self.ok = function () {
            self.post({
                url: self.server + 'layer:' + self.model.layer.id + '?request=delete',
                atSuccess: function () {
                    self.model.deleteLayer(args.use.id, self.model.layer.id);
                }
            });
            return true;
        };
        self.editor.dialog('open');
    },
    /**
     * Open a dialog for adding or editing a rule in a layer in a use of a plan.
     */
    editRule: function (args) {
        var self = this,
            owner = self.model.layer.owner === self.model.config.config.user,
            getPayload,
            value_from = function (obj) {
                return obj ? obj.value : null;
            };

        self.setEditor({
            title: 'Sääntö tasossa ' + self.model.layer.name,
            height: 500,
            applyClose: args.rule
        });

        if (args.rule) {
            args.dataset = args.rule.dataset;
        } else {
            args.dataset = new Widget({
                container: self.selector,
                id: 'rule-dataset',
                type: 'select',
                list: self.model.datasets.layers,
                pretext: 'Rule is based on the dataset: '
            });
        }
        
        if (self.model.layer.rule_class === mspEnum.EXCLUSIVE) {
            getPayload = self.editBooleanRule(args);
        } else if (self.model.layer.rule_class === mspEnum.INCLUSIVE) {
            getPayload = self.editBooleanRule(args);
        } else if (self.model.layer.rule_class === mspEnum.BOXCAR) {
            self.editor.dialog('option', 'width', 470);
            self.editor.dialog('option', 'height', 700);
            getPayload = self.editBoxcarRule(args);
        } else if (self.model.layer.rule_class === mspEnum.BAYESIAN_NETWORK) {
            getPayload = self.editBayesianRule(args);
        } else {
            self.error('Editing ' + self.model.layer.rule_class + ' rules not supported yet.');
            return;
        }

        self.ok = function () { // save new rule
            var path = 'plan:' + self.model.plan.id + '/uses:' + args.use.id + '/layers:' + self.model.layer.id,
                payload = getPayload();
            self.post({
                url: self.server + path + '/rules?request=save',
                payload: payload,
                atSuccess: function (response) {
                    self.model.addRule(new MSPRule({
                        id: response.id.value,
                        layer: self.model.layer,
                        dataset: self.model.getDataset(response.dataset.value),
                        active: true,
                        op: response.op ? self.klasses.op.find(function (element) {
                            return element.id === response.op.value;
                        }).name : null,
                        value: value_from(response.value),
                        boxcar_type: payload.boxcar_type ? payload.boxcar_type.selected : null,
                        boxcar_x0: value_from(response.boxcar_x0),
                        boxcar_x1: value_from(response.boxcar_x1),
                        boxcar_x2: value_from(response.boxcar_x2),
                        boxcar_x3: value_from(response.boxcar_x3),
                        weight: value_from(response.weight),
                        state_offset: value_from(response.state_offset),
                        node: value_from(response.node),
                    }));
                }
            });
            return true;
        };
        self.apply = function () { // update or modify existing rule
            var request = owner ? 'update' : 'modify',
                payload = getPayload(),
                data = {id: args.rule.id};
            $.each(payload, function (key, value) {
                if (typeof value === 'object') {
                    payload[key] = value.value;
                    data[key] = value.selected;
                } else {
                    data[key] = value;
                }
            });
            if (data.op) {
                data.op = self.klasses.op.find(function (element) {
                    return element.id === data.op;
                }).name;
            }
            self.post({
                url: self.server + 'rule:' + args.rule.id + '?request=' + request,
                payload: payload,
                atSuccess: function () {
                    self.model.layer.editRule(data); // edit the rule and refresh the layer (includes map render)
                    self.model.ruleEdited.notify(); // update view
                }
                // if (xhr.status === 403)
                // self.error('Rule modification requires cookies. Please enable cookies and reload this app.');
            });
        };

        self.editor.dialog('open');
    },
    /**
     * Confirm and delete a rule from a layer in a use of a plan.
     */
    deleteRule: function (args) {
        var self = this;
        self.setEditor({
            title: 'Poista sääntö?',
            html: 'Haluatko varmasti poistaa säännön \'' + args.rule.getName() +
                '\' tasosta \'' + self.model.layer.name + '\'?'
        });
        self.ok = function () {
            self.post({
                url: self.server + 'rule:' + args.rule.id + '?request=delete',
                atSuccess: function () {
                    var del = {};
                    del[args.rule.id] = 1;
                    self.model.deleteRules(del);
                }
            });
            return true;
        };
        self.editor.dialog('open');
    }
};
