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
/*global $, jQuery, alert, MSPLayer, element, Widget*/

// after https://alexatnet.com/articles/model-view-controller-mvc-javascript

function MSPController(model, view) {
    var self = this;
    self.server = 'http://' + model.server + '/browser/';
    self.model = model;
    self.view = view;
    self.msg = $('#error');
    self.editor_id = '#editor';
    self.editor = $(self.editor_id);
    self.klasses = {};
  
    self.msg.dialog({
        autoOpen: false,
        height: 400,
        width: 350,
        modal: true,
        buttons: {
            Ok: function () {
                self.msg.dialog('close');
            },
        },
    });

    self.editor.dialog({
        autoOpen: false,
        height: 400,
        width: 350,
        modal: true,
        buttons: {
            Ok: function () {
                if (self.ok()) {
                    self.editor.dialog('close');
                }
            },
            Cancel: function () {
                self.editor.dialog('close');
            }
        },
    });
}

MSPController.prototype = {
    getKlasses: function () {
        var self = this,
            classes = {
                use_class: '',
                layer_class: '',
                rule_class: '',
                activity: '',
                color_scale: '',
                op: '',
            },
            calls = [],
            msg = '';
        $.each(classes, function (klass, value) {
            calls.push(
                $.ajax({
                    headers: {
                        Accept: 'application/json'
                    },
                    url: self.server + klass,
                    success: function (result) {
                        if (result.isOk === false) {
                            msg += result.message + "\n";
                        } else if (result.error) {
                            msg += result.error + "\n";
                        } else {
                            self.klasses[klass] = result;
                        }
                    },
                    fail: function (xhr, textStatus) {
                        msg += xhr.responseText || textStatus;
                    }
                })
            );
        });    
        $.when.apply($, calls).then(function() {
            
            /*jslint unparam: true*/
            self.view.planCommand.attach(function (sender, args) {
                if (args.cmd === 'add') {
                    self.addPlan();
                } else if (args.cmd === 'edit') {
                    self.editPlan(self.model.plan);
                } else if (args.cmd === 'delete') {
                    self.deletePlan(self.model.plan);
                } else if (args.cmd === 'add_use') {
                    self.addUse(self.model.plan);
                }
            });
            
            self.view.useCommand.attach(function (sender, args) {
                if (args.cmd === 'edit') {
                    if (args.use.id === 0) { // "Data"
                        self.editDatasetList(self.model.plan);
                    } else {
                        self.editUse(args.use);
                    }
                } else if (args.cmd === 'delete') {
                    self.deleteUse(self.model.plan, args.use);
                } else if (args.cmd === 'add_layer') {
                    self.editLayer(self.model.plan, args.use);
                }
            });
            
            self.view.layerCommand.attach(function (sender, args) {
                if (args.cmd === 'edit') {
                    self.editLayer(self.model.plan, args.use, args.layer);
                } else if (args.cmd === 'delete') {
                    self.deleteLayer(args.use, args.layer);
                } else if (args.cmd === 'add_rule') {
                    self.editRule(self.model.plan, args.use, args.layer);
                } else if (args.cmd === 'delete_rule') {
                    self.deleteRule(self.model.plan, args.use, args.layer);
                }
            });
            
            self.view.ruleClicked.attach(function (sender, args) {
                var rule = self.model.getRule(parseInt(args.id, 10));
                self.editRule(self.model.plan, null, self.model.layer, rule);
            });
            
            self.model.newPlans.attach(function (sender, args) {
                self.editor.dialog('close');
            });
            
            self.model.error.attach(function (sender, args) {
                self.error(args.msg);
            });
            
            self.view.error.attach(function (sender, args) {
                self.error(args.msg);
            });
            /*jslint unparam: false*/
        }, function(a) {
            self.error('Calling SmartSea MSP server failed: ' + a.statusText)
        });
    },
    setEditorOkCancel: function () {
        var self = this;
        self.editor.dialog('option', 'buttons', {
            Ok: function () {
                if (self.ok()) {
                    self.editor.dialog('close');
                }
            },
            Cancel: function () {
                self.editor.dialog('close');
            }
        });
    },
    setEditorApplyClose: function () {
        var self = this;
        self.editor.dialog('option', 'buttons', {
            Apply: function () {
                self.apply();
            },
            Close: function () {
                self.editor.dialog('close');
            }
        });
    },
    error: function (msg) {
        var self = this;
        self.msg.html(msg);
        self.msg.dialog('open');
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
    getNetworks: function () {
        var self = this;
        if (!self.networks) {
            $.ajax({
                headers: {Accept: 'application/json'},
                url: 'http://' + self.model.server + '/networks',
                success: function (result) {
                    self.networks = result;
                },
                async: false
            });
        }
    },
    loadPlans: function () {
        var self = this;
        self.post({
            url: 'http://' + self.model.server + '/plans',
            payload: {},
            atSuccess: function (data) {
                self.model.setPlans(data);
                self.getKlasses();
                self.getNetworks();
            }
        });
    },
    addPlan: function (args) {
        var self = this,
            name = 'plan-name',
            html;
        if (!args) {
            args = {};
        }
        self.editor.dialog('option', 'title', 'Uusi suunnitelma');
        self.editor.dialog('option', 'height', 400);
        self.setEditorOkCancel();

        html = 'Anna nimi suunnitelmalle: ' + element('input', {type: 'text', id: name}, '');
        if (args.error) {
            html = element('p', {style: 'color:red;'}, args.error) + html;
        }
        self.editor.html(html);
        self.ok = function () {
            name = $(self.editor_id + ' #' + name).val();
            if (self.model.planNameOk(name)) {
                self.post({
                    url: self.server + 'plan?request=save',
                    payload: { name: name },
                    atSuccess: function (data) {
                        var plan = {
                            id: data.id.value,
                            owner: data.owner.value,
                            name: data.name.value
                        };
                        self.model.addPlan(plan);
                    }
                });
            } else {
                self.addPlan({error: "Suunnitelma '" + name + "' on jo olemassa."});
                return false;
            }
        };
        self.editor.dialog('open');
    },
    editPlan: function (plan) {
        var self = this,
            name = 'plan-name',
            html;
        self.editor.dialog('option', 'title', 'Suunnitelma');
        self.editor.dialog('option', 'height', 400);
        self.setEditorOkCancel();

        html = element('input', {type: 'text', id: name, value: plan.name}, '');
        html = element('p', {}, 'Suunnitelman nimi: ' + html);
        self.editor.html(html);
        self.ok = function () {
            name = $(self.editor_id + ' #' + name).val();
            if (self.model.planNameOk(name)) {
                self.post({
                    url: self.server + 'plan:' + plan.id + '?request=update',
                    payload: { name: name },
                    atSuccess: function (data) {
                        self.model.editPlan({
                            id: data.id.value,
                            owner: data.owner.value,
                            name: data.name.value
                        });
                    }
                });
            } else {
                self.addPlan({error: "Suunnitelma '" + name + "' on jo olemassa."});
                return false;
            }
            return true;
        };
        self.editor.dialog('open');
    },
    deletePlan: function (plan) {
        var self = this;
        self.editor.dialog('option', 'title', 'Poista suunnitelma?');
        self.editor.dialog('option', 'height', 400);
        self.setEditorOkCancel();

        self.editor.html("Haluatko varmasti poistaa koko suunnitelman '" + plan.name + "'?");
        self.ok = function () {
            self.post({
                url: self.server + 'plan:' + plan.id + '?request=delete',
                atSuccess: function () {
                    self.model.deletePlan(plan.id);
                }
            });
            return true;
        };
        self.editor.dialog('open');
    },
    addUse: function (plan) {
        var self = this,
            id = 'use-id',
            list = '',
            html;
        self.editor.dialog('option', 'title', 'New use');
        self.editor.dialog('option', 'height', 400);
        self.setEditorOkCancel();

        /*jslint unparam: true*/
        $.each(self.klasses['use_class'], function (i, klass) {
            if (!self.model.hasUse(klass.id)) {
                list += element('option', {value: klass.id}, klass.name);
            }
        });
        /*jslint unparam: false*/
        html = 'Select the class for the new use: ' + element('select', {id: id}, list);
        self.editor.html(html);
        self.ok = function () {
            id = $(self.editor_id + ' #' + id).val();
            self.post({
                url: self.server + 'plan:' + plan.id + '/uses?request=create',
                payload: {use_class: id},
                atSuccess: function (data) {
                    var use = {
                        id: data.id.value,
                        owner: data.owner.value,
                        plan: data.plan.value,
                        class_id: data.use_class.value,
                        layers: []
                    };
                    /*jslint unparam: true*/
                    $.each(classes, function (i, klass) {
                        if (klass.id === data.use_class.value) {
                            use.name = klass.name;
                            return false;
                        }
                    });
                    /*jslint unparam: false*/
                    self.model.addUse(use);
                }
            });
            return true;
        };
        self.editor.dialog('open');
    },
    editUse: function (use) {
        var self = this;
        self.getData('use_class:' + use.class_id + '/activities', function (activities) {
            var html;
            
            self.editor.dialog('option', 'title', use.name);
            self.editor.dialog('option', 'height', 400);
            self.setEditorOkCancel();
            
            /*jslint unparam: true*/
            $.each(activities, function (i, item) {
                activities[item.id] = item;
            });
            /*jslint unparam: false*/
            activities = new Widget({
                container_id: self.editor_id,
                id: 'activities_list',
                type: 'checkbox-list',
                list: self.klasses['activity'],
                selected: activities,
                pretext: ''
            });
            html = element('p', {}, "Activities in this use. Sorry, not editable.")
                + element('p', {}, activities.html());
            
            self.editor.html(html);
            self.ok = function () {
                return true;
            };
            self.editor.dialog('open');
        })
    },
    editDatasetList: function (plan) {
        var self = this,
            inRules = self.model.datasetsInRules(),
            notInRules = [],
            datasets,
            html;
        self.editor.dialog('option', 'title', 'Dataset list');
        self.editor.dialog('option', 'height', 400);
        self.setEditorOkCancel();

        // put into the list those datasets that are not in rules
        // selected are those in plan.data
        /*jslint unparam: true*/
        $.each(self.model.datasets.layers, function (i, layer) {
            if (!inRules[layer.id]) {
                notInRules.push(layer);
            }
        });
        /*jslint unparam: false*/
        datasets = new Widget({
            container_id: self.editor_id,
            id: 'dataset_list',
            type: 'checkbox-list',
            list: notInRules,
            selected: plan.data,
            pretext: 'Select the extra datasets for this plan: '
        });

        html = element('p', {}, datasets.html());
        self.editor.html(html);
        self.ok = function () {
            var selected = datasets.getSelectedIds(),
                update = '';
            /*jslint unparam: true*/
            $.each(selected, function (id, i) {
                if (update) {
                    update += '&';
                }
                update += 'dataset=' + id;
            });
            /*jslint unparam: false*/
            self.post({
                url: self.server + 'plan:' + plan.id + '/extra_datasets?request=update',
                payload: update,
                atSuccess: function (data) {
                    self.model.setPlanData(data);
                }
            });
            return true;
        };
        self.editor.dialog('open');
    },
    deleteUse: function (plan, use) {
        var self = this;
        self.editor.dialog('option', 'title', 'Poista käyttömuoto?');
        self.editor.dialog('option', 'height', 400);
        self.setEditorOkCancel();

        self.editor.html("Haluatko varmasti poistaa koko käyttömuodon '" + use.name + "' suunnitelmasta '" + plan.name + "'?");
        self.ok = function () {
            self.post({
                url: self.server + 'use:' + use.id + '?request=delete',
                atSuccess: function () {
                    self.model.deleteUse(use.id);
                }
            });
            return true;
        };
        self.editor.dialog('open');
    },
    availableLayerClasses: function (use) {
        var self = this,
            list = [];
        $.each(self.klasses['layer_class'], function (i, klass) {
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
    editLayer: function (plan, use, layer) {
        // add new if no layer
        var self = this,

            available_layer_classes = self.availableLayerClasses(use),
            
            class_list = layer ?
            null :
            new Widget({
                container_id: self.editor_id,
                id: 'layer-class',
                type: 'select',
                list: self.klasses['layer_class'],
                includeItem: function (i, klass) {
                    return available_layer_classes.find(function (element) {
                        return element.id === klass.id;
                    });
                },
                pretext: available_layer_classes.length ? 'The layer class: ' : ''
            }),
            
            klass = layer ?
            self.klasses['layer_class'].find(function (element) {
                return element.id === layer.class_id;
            }) :
            null,
            
            rule_class_list = layer ?
            self.klasses['rule_class'] :
            new Widget({
                container_id: self.editor_id,
                id: 'layer-rule-class',
                type: 'select',
                list: self.klasses['rule_class'],
                pretext: 'The rule system: '
            }),
            
            rule_class_extra = new Widget({
                container_id: self.editor_id,
                id: 'rule-class-extra',
                type: 'para'
            }),
            rule_class_extra2 = new Widget({
                container_id: self.editor_id,
                id: 'rule-class-extra2',
                type: 'para'
            }),
            rule_class_extra3 = new Widget({
                container_id: self.editor_id,
                id: 'rule-class-extra3',
                type: 'para'
            }),
            color_list = new Widget({
                container_id: self.editor_id,
                id: 'layer-color',
                type: 'select',
                list: self.klasses['color_scale'],
                selected: (layer ? layer.color_scale : null),
                pretext: 'Layer color scheme: '
            }),
            network,
            node,
            state,
            select_network_node = function (network, selected, extra) {
                node = new Widget({
                    container_id: self.editor_id,
                    id: 'layer-node',
                    type: 'select',
                    list: network.nodes,
                    selected: selected,
                    pretext: 'Select the node whose value to use for this layer: '
                });
                rule_class_extra2.html(element('p', {}, extra) +
                                       element('p', {}, node.html()));
                
                node.changed((function changed() {
                    var node2 = node.getSelected(); // node2 is not null since we have set selected above
                    var desc = '';
                    if (node2.attributes) {
                        desc = node2.attributes.HR_Desc;
                    }
                    state = new Widget({
                        container_id: self.editor_id,
                        id: 'layer-state',
                        type: 'select',
                        list: node2.values,
                        selected: node2.values[0],
                        pretext: 'Select the state for the layer value: '
                    });
                    rule_class_extra3.html(element('p', {}, 'Description: ' + desc) +
                                           element('p', {}, state.html()));
                    return changed;
                }()));
            },
            
            html = layer ?
            
            element('p', {}, 'This layer attempts to depict ' + klass.name + '.') +
            element('p', {}, 'Rule system is ' + layer.rule_class + '.') :
            
            element('p', {}, class_list.html()) +
            element('p', {}, rule_class_list.html());

        if (!layer && available_layer_classes.length == 0) {
            self.error('No more slots for layers in this use.');
            return;
        }

        self.editor.dialog('option', 'title', 'Layer for ' + use.name);
        self.editor.dialog('option', 'width', 500);
        self.editor.dialog('option', 'height', 600);
        if (layer) {
            self.setEditorApplyClose();
        } else {
            self.setEditorOkCancel();
        }
        
        html = element('p', {}, 'This layer is computed by rules.') + html;
        html += element('p', {}, rule_class_extra.html());
        html += element('p', {}, rule_class_extra2.html());
        html += element('p', {}, rule_class_extra3.html());
        if (use.id === 0) {
            html += element('p', {}, 'The color setting is temporary for datasets.');
        }
        html += element('p', {}, color_list.html());
        self.editor.html(html);

        if (layer) {
            if (layer.rule_class === 'Bayesian network') {
                select_network_node(
                    self.networks.find(function (net) {return net.id === layer.network_file}),
                    layer.output_node,
                    'The layer is based on Bayesian network <b>' + layer.network_file + '</b>'
                );
            }
        } else {
            rule_class_list.changed((function changed() {
                var klass = rule_class_list.getSelected();
                if (klass && klass.name === 'Bayesian network') {
                    
                    network = new Widget({
                        container_id: self.editor_id,
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
                }
                return changed;
            }()));
        }

        self.ok = function () { // save new layer
            var klass = class_list.getSelected(),
                rule_class = rule_class_list.getSelected(),
                color = color_list.getSelected(),
                payload = {
                    layer_class: klass ? klass.id : null,
                    color_scale: color.id,
                    rule_class: rule_class.id
                },
                url;
            if (!klass) {
                return true;
            }
            if (rule_class.name === "Bayesian network") {
                payload.network_file = network.getSelected().id;
                payload.output_node = node.getSelected().id;
                payload.output_state = state.getValue();
            }
            url = self.server + 'plan:' + plan.id + '/uses:' + use.id + '/' + 'layers?request=create';
            self.post({
                url: url,
                payload: payload,
                atSuccess: function (data) {
                    self.model.addLayer(new MSPLayer({
                        id: data.id.value,
                        name: klass.name,
                        owner: data.owner.value,
                        
                        MSP: self.model,
                        use: use,
                        
                        // can't create new datasets
                        
                        class_id: data.layer_class.value,
                        rule_class: rule_class.name,
                        
                        network_file: data.rule_system.columns.network_file.value,
                        output_node: data.rule_system.columns.output_node.value,
                        output_state: data.rule_system.columns.output_state.value,
                        
                        rules: [],

                        color_scale: color.name
                        
                    }));
                }
            });
            return true;
        };

        self.apply = function () { // modify existing layer
            var color = color_list.getSelected(),
                payload = {
                    color_scale: color.id
                },
                url;
            if (layer.rule_class === "Bayesian network") {
                payload.output_node = node.getSelected().id;
                payload.output_state = state.getValue();
            }
            if (use.id === 0) {
                // layer is dataset
                layer.color_scale = color.name;
                layer.refresh();
                self.model.selectLayer({use: use.id, layer: layer.id});
            } else {
                url = self.server + 'plan:' + plan.id + '/uses:' + use.id + '/layers:' + layer.id + '?request=update';
                self.post({
                    url: url,
                    payload: payload,
                    atSuccess: function (data) {
                        var args = {
                            // can't edit datasets

                            // not editable
                            class_id: layer.class_id,
                            rule_class: layer.rule_class,

                            // editable
                            network_file: data.rule_system.columns.network_file.value,
                            output_node: data.rule_system.columns.output_node.value,
                            output_state: data.rule_system.columns.output_state.value,

                            color_scale: color.name
                        };
                        layer.edit(args);
                        layer.refresh();
                        self.model.selectLayer({use: use.id, layer: layer.id});
                    }
                });
            }
            return true;
        };

        self.editor.dialog('open');
    },
    deleteLayer: function (use, layer) {
        var self = this;
        self.editor.dialog('option', 'title', 'Poista taso?');
        self.editor.dialog('option', 'height', 400);
        self.setEditorOkCancel();

        self.editor.html("Haluatko varmasti poistaa tason '" + layer.name + "' käyttömuodosta '" + use.name + "'?");
        self.ok = function () {
            self.post({
                url: self.server + 'layer:' + layer.id + '?request=delete',
                atSuccess: function () {
                    self.model.deleteLayer(use.id, layer.id);
                }
            });
            return true;
        };
        self.editor.dialog('open');
    },
    editRule: function (plan, use, layer, rule) {
        var self = this,
            owner = layer.owner === self.model.user,
            dataset = rule ? rule.dataset :
            new Widget({
                container_id: self.editor_id,
                id: 'rule-dataset',
                type: 'select',
                list: self.model.datasets.layers,
                pretext: 'Rule is based on the dataset: '
            }),
            getPayload;

        self.editor.dialog('option', 'title', 'Sääntö tasossa ' + layer.name);
        self.editor.dialog('option', 'height', 500);
        
        if (rule) {
            self.setEditorApplyClose();
        } else {
            self.setEditorOkCancel();
        }

        if (layer.rule_class === 'exclusive') {
            getPayload = self.editBooleanRule(plan, use, layer, rule, dataset);
        } else if (layer.rule_class === 'boxcar') {
            self.editor.dialog('option', 'width', 470);
            self.editor.dialog('option', 'height', 700);
            getPayload = self.editBoxcarRule(plan, use, layer, rule, dataset);
        } else if (layer.rule_class === 'Bayesian network') {
            getPayload = self.editBayesianRule(plan, use, layer, rule, dataset);
        } else {
            self.error('Editing ' + layer.rule_class + ' rules not supported yet.');
            return;
        }

        self.ok = function () { // save new rule
            var path = 'plan:' + plan.id + '/uses:' + use.id + '/layers:' + layer.id;
            self.post({
                url: self.server + path + '/rules?request=save',
                payload: getPayload(),
                atSuccess: function (data) {
                    self.model.addRule(new MSPRule({
                        id: data.id.value,
                        layer: layer,
                        dataset: self.model.getDataset(data.dataset.value),
                        active: true,
                        op: data.op ? self.klasses.op.find(function (element) {
                            return element.id === data.op;
                        }).name : null,
                        value: data.value ? data.value.value : null,
                        boxcar: data.boxcar ? data.boxcar.value : null,
                        boxcar_x0: data.boxcar_x0 ? data.boxcar_x0.value : null,
                        boxcar_x1: data.boxcar_x1 ? data.boxcar_x1.value : null,
                        boxcar_x2: data.boxcar_x2 ? data.boxcar_x2.value : null,
                        boxcar_x3: data.boxcar_x3 ? data.boxcar_x3.value : null,
                        weight: data.weight ? data.weight.value : null,
                        state_offset: data.state_offset ? data.state_offset.value : null,
                        node_id: data.node_id ? data.node_id.value : null,
                    }));
                }
            });
            return true;
        };
        self.apply = function () { // update or modify existing rule
            var request = owner ? 'update' : 'modify',
                payload = getPayload(),
                data = {id: rule.id};
            $.each(payload, function (key, value) {
                data[key] = value;
            });
            if (data.op) {
                data.op = self.klasses.op.find(function (element) {
                    return element.id === data.op;
                }).name;
            }
            self.post({
                url: self.server + 'rule:' + rule.id + '?request=' + request,
                payload: payload,
                atSuccess: function () {
                    layer.editRule(data); // edit the rule and refresh the layer (includes map render)
                    self.model.ruleEdited.notify(); // update view
                }
                // if (xhr.status === 403)
                // self.error('Rule modification requires cookies. Please enable cookies and reload this app.');
            });
        };
        
        self.editor.dialog('open');
    },
    deleteRule: function (plan, use, layer) {
        var self = this,
            rules,
            html;
        self.editor.dialog('option', 'title', "Delete rules from layer '" + layer.name + "'");
        self.editor.dialog('option', 'height', 400);
        self.setEditorOkCancel();

        rules = new Widget({
            container_id: self.editor_id,
            id: 'rules-to-delete',
            type: 'checkbox-list',
            list: layer.rules,
            selected: null,
            nameForItem: function (rule) {
                return rule.getName();
            }
        });

        html = element('p', {}, 'Select rules to delete:') + rules.html();

        self.editor.html(html);

        self.ok = function () {
            var selected = rules.getSelectedIds(),
                deletes = '';
            /*jslint unparam: true*/
            $.each(selected, function (id, i) {
                if (deletes) {
                    deletes += '&';
                }
                deletes += 'rule=' + id;
            });
            /*jslint unparam: false*/
            self.post({
                url: self.server + 'plan:' + plan.id + '/uses:' + use.id + '/layers:' + layer.id + '/rules?request=delete',
                payload: deletes,
                atSuccess: function () {
                    self.model.deleteRules(selected);
                }
            });
            return true;
        };
        self.editor.dialog('open');
    }
};
