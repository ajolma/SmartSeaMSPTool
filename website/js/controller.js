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
            
            self.view.ruleSelected.attach(function (sender, args) {
                var rule = self.model.selectRule(args.id);
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
                var plans = [], ecosystem, datasets;
                /*jslint unparam: true*/
                $.each(data, function (i, plan) {
                    if (!plan.uses) {
                        plan.uses = [];
                    }
                    $.each(plan.uses, function (j, use) {
                        var layers = [];
                        $.each(use.layers, function (k, layer) {
                            layer.model = self.model;
                            layer.server = 'http://' + self.model.server + '/WMTS';
                            layer.map = self.model.map;
                            layer.projection = self.model.proj;
                            layer.use_class_id = use.class_id;
                            layers.push(new MSPLayer(layer));
                        });
                        use.layers = layers;
                    });
                });
                // pseudo uses, note reserved use class id's
                $.each(data, function (i, plan) {
                    if (plan.id === 0) { // a pseudo plan Data
                        datasets = plan.uses[0];
                    } else if (plan.id === 1) { // a pseudo plan Ecosystem
                        ecosystem = plan.uses[0];
                    } else {
                        plans.push(plan);
                    }
                });
                /*jslint unparam: false*/
                self.model.setPlans(plans, ecosystem, datasets);
                self.getKlasses();
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
                + element('p', {}, activities.content());
            
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

        html = element('p', {}, datasets.content());
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
    editLayer: function (plan, use, layer) {
        // add new if no layer
        var self = this,
            class_list,
            rule_class_list,
            rule_class_extra,
            network,
            node,
            state,
            color_list,
            html;

        self.editor.dialog('option', 'title', 'Layer for ' + use.name);
        self.editor.dialog('option', 'width', 500);
        self.editor.dialog('option', 'height', 600);
        self.setEditorOkCancel();

        /*jslint unparam: true*/
        class_list = self.klasses['layer_class'];
        /*jslint unparam: false*/

        rule_class_list = self.klasses['rule_class'];
        
        rule_class_extra = new Widget({
            container_id: self.editor_id,
            id: 'rule-class-extra',
            type: 'para'
        });

        color_list = new Widget({
            container_id: self.editor_id,
            id: 'layer-color',
            type: 'select',
            list: self.klasses['color_scale'],
            selected: (layer ? layer.color_scale : null),
            pretext: 'Layer color scheme: '
        });

        html = '';
        if (layer) {
            html += element('p', {}, 'This layer attempts to depict ' + class_list[layer.class_id].name + '.');
        } else {
            class_list = new Widget({
                container_id: self.editor_id,
                id: 'layer-class',
                type: 'select',
                list: class_list,
                selected: (layer ? layer.class_id : null),
                includeItem: function (i, item) {
                    if (layer && layer.class_id === item.id) {
                        return true;
                    }
                    if (item.id === 5) {
                        return false; // Impact layer
                    }
                    var retval = true;
                    $.each(use.layers, function (j, layer2) {
                        if (layer2.class_id === item.id) { // used already
                            retval = false;
                            return false;
                        }
                    });
                    return retval;
                },
                pretext: 'The layer class: '
            });
            html += element('p', {}, class_list.content());
        }
        html += element('p', {}, 'This layer is computed by rules.');
        if (layer) {
            html += element('p', {}, 'Rule system is ' + layer.rule_class + '.');
        } else {
            rule_class_list = new Widget({
                container_id: self.editor_id,
                id: 'layer-rule-class',
                type: 'select',
                list: rule_class_list,
                selected: (layer ? layer.rule_class : null),
                pretext: 'Select the rule system for the new layer: '
            });
            html += element('p', {}, rule_class_list.content());
            html += element('p', {}, rule_class_extra.content());
        }
        if (use.id === 0) {
            html += element('p', {}, 'The color setting is temporary for datasets.');
        }
        html += element('p', {}, color_list.content());
        self.editor.html(html);

        if (!layer) {
            rule_class_list.changed((function changed() {
                var klass = rule_class_list.getSelected();
                if (klass && klass.name === 'Bayesian network') {
                    
                    self.getNetworks();
                    network = new Widget({
                        container_id: self.editor_id,
                        id: 'layer-network',
                        type: 'select',
                        list: self.networks,
                        selected: self.networks[0],
                        pretext: 'Select the Bayesian network: '
                    });
                    rule_class_extra.html(element('p', {}, network.content()));
                    
                    network.changed((function changed() {
                        var net = network.getSelected(); // net is not null since we have set selected above
                        node = new Widget({
                            container_id: self.editor_id,
                            id: 'layer-node',
                            type: 'select',
                            list: net.nodes,
                            selected: net.nodes[0],
                            pretext: 'Select the node to use for this layer: '
                        });
                        rule_class_extra.html(element('p', {}, network.content()) +
                                              element('p', {}, node.content()));
                        
                        node.changed((function changed() {
                            var nod = node.getSelected(); // nod is not null since we have set selected above
                            var desc = '';
                            if (nod.attributes) {
                                desc = nod.attributes.HR_Desc;
                            }
                            state = new Widget({
                                container_id: self.editor_id,
                                id: 'layer-state',
                                type: 'select',
                                list: nod.values,
                                selected: nod.values[0],
                                pretext: 'Select the state for the layer value: '
                            });
                            rule_class_extra.html(element('p', {}, network.content()) +
                                                  element('p', {}, node.content()) +
                                                  element('p', {}, 'Description: ' + desc) +
                                                  element('p', {}, state.content()));
                            return changed;
                        }()));
                        
                        return changed;
                    }()));
                    
                } else {
                    rule_class_extra.html('');
                }
                return changed;
            }()));
        }

        if (layer) {
            // edit
            self.ok = function () {
                var color = color_list.getSelected(),
                    payload = {
                        color_scale: color.id
                    },
                    url;
                if (rule_class.name === "Bayesian network") {
                    payload.network_file = network.getSelected().id;
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
                            layer.refresh();
                            self.model.selectLayer({use: use.id, layer: layer.id});
                        }
                    });
                }
                return true;
            };
        } else {
            // new
            self.ok = function () {
                var klass = class_list.getSelected(),
                    rule_class = rule_class_list.getSelected(),
                    color = color_list.getSelected(),
                    payload = {
                        layer_class: klass.id,
                        color_scale: color.id,
                        rule_class: rule_class.id
                    },
                    url;
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
                        layer = new MSPLayer({
                            model: self.model,
                            server: 'http://' + self.model.server + '/WMTS',
                            map: self.model.map,
                            projection: self.model.proj,
                            id: data.id.value,
                            class_id: data.layer_class.value,
                            owner: data.owner.value,
                            rules: [],
                            use_class_id: use.class_id,
                            color_scale: color.name,
                            name: klass.name,
                            rule_class: rule_class.name
                        });
                        self.model.addLayer(use, layer);
                    }
                });
                return true;
            };
        }
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
            dataset,
            settings,
            html = '',
            op,
            threshold,
            regex;

        self.editor.dialog('option', 'title', 'Sääntö tasossa ' + layer.name);
        self.editor.dialog('option', 'height', 500);
        if (rule) {
            self.setEditorApplyClose();
        } else {
            self.setEditorOkCancel();
        }

        if (layer.rule_class === 'Bayesian network') {
            self.editBayesianRule(plan, use, layer, rule);
            self.editor.dialog('open');
            return;
        }

        dataset = new Widget({
            container_id: self.editor_id,
            id: 'rule-dataset',
            type: 'select',
            list: self.model.datasets.layers,
            pretext: 'Rule is based on the dataset: '
        });
        settings = new Widget({
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
        }
        html +=
            element('p', {}, dataset.content()) +
            element('p', {id: 'descr'}, '') +
            settings.content();

        // the rule can be binary, if dataset has only one class
        // otherwise the rule needs operator and threshold
        op = new Widget({
            container_id: self.editor_id,
            id: 'rule-op',
            type: 'select',
            list: self.klasses['op'],
            pretext: 'Define the operator and the threshold:<br/>'
        });
        self.editor.html(html);

        dataset.changed((function changed() {
            var set = dataset.getSelected(),
                args = {
                    container_id: self.editor_id,
                    id: 'threshold'
                },
                attr;
            $(self.editor_id + ' #descr').html(set.descr);
            if (!set) {
                settings.html('');
            } else if (set.classes === 1) {
                settings.html('Binary rule');
            } else {
                if (set.semantics) {
                    args.type = 'select';
                    args.list = set.semantics;
                } else if (set.data_type === 'integer') {
                    args.type = 'spinner';
                } else if (set.data_type === 'real') {
                    args.type = 'slider';
                }
                if (rule) {
                    attr = rule.getMinMax();
                    args.min = attr.min;
                    args.max = attr.max;
                    args.value = rule.value;
                } else {
                    args.min = set.min_value;
                    args.max = set.max_value;
                    args.value = set.min_value;
                }
                threshold = new Widget(args);
                settings.html(op.content() + '&nbsp;' + threshold.content());
                threshold.prepare();
            }
            return changed;
        }()));

        self.ok = function () { // save
            var set = dataset.getSelected(),
                operator = op.getSelected(),
                value = (set.classes === 1 ? 0 : threshold.getValue()),
                payload = {dataset: set.id};
            if (operator) {
                payload.op = operator.id;
                payload.value = value;
            }
            self.post({
                url: self.server + 'plan:' + plan.id + '/uses:' + use.id + '/layers:' + layer.id + '/rules?request=save',
                payload: payload,
                atSuccess: function (data) {
                    self.model.addRule({
                        id: data.id.value,
                        dataset: data.dataset.value,
                        op: (operator ? operator.name : null),
                        value: data.value.value,
                        active: true
                    });
                }
            });
            return true;
        };
        self.apply = function () { // modify
            var value = threshold.getValue(),
                request = owner ? 'update' : 'modify';
            self.post({
                url: self.server + 'rule:' + rule.id + '?request=' + request,
                payload: { value: value },
                atSuccess: function () {
                    self.model.editRule({value: value});
                }
                // if (xhr.status === 403)
                // self.error('Rule modification requires cookies. Please enable cookies and reload this app.');
            });
        };
        self.editor.dialog('open');
    },
    editBayesianRule: function (plan, use, layer, rule) {
        var self = this,
            dataset_list = [],
            dataset,
            network = null,
            nodes = [],
            node,
            offset,
            html;

        // rule is a node in a Bayesian network
        // for now we assume it is a (hard) evidence node, i.e.,
        // the dataset must be integer, and its value range the same as the node's

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
            selected: rule ? rule.dataset : dataset_list[0],
            pretext: 'Base the rule on dataset: '
        });

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

        html = element('p', {}, dataset.content()) +
            element('p', {id: 'dataset-states'}, '') +
            element('p', {id: 'descr'}, '') +
            element('p', {}, offset.content()) +
            node.content() +
            element('p', {id: 'node-states'}, '');

        self.editor.html(html);
        offset.prepare();

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

        self.ok = function () {
            var set = dataset.getSelected(),
                off = offset.getValue(),
                nd = node.getSelected(),
                payload = {
                    dataset: set.id,
                    state_offset: off,
                    node_id: nd.id
                };
            self.post({
                url: self.server + 'plan:' + plan.id + '/uses:' + use.id + '/layers:' + layer.id + '/rules?request=save',
                payload: payload,
                atSuccess: function (data) {
                    self.model.addRule({
                        id: data.id.value,
                        dataset: data.dataset.value,
                        state_offset: data.state_offset.value,
                        node_id: data.node_id.value,
                        active: true
                    });
                }
            });
            return true;
        };
        self.apply = function () { // modify
            var request = owner ? 'update' : 'modify',
                set = dataset.getSelected(),
                off = offset.getValue(),
                nd = node.getSelected(),
                payload = {
                    dataset: set.id,
                    state_offset: off,
                    node_id: nd.id
                };
            self.post({
                url: self.server + 'rule:' + rule.id + '?request=' + request,
                payload: payload,
                atSuccess: function () {
                    self.model.editRule({value: value});
                }
                // if (xhr.status === 403)
                // self.error('Rule modification requires cookies. Please enable cookies and reload this app.');
            });
        };
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

        html = element('p', {}, 'Select rules to delete:') + rules.content();

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
