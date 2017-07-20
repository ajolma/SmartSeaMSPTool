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

// after https://alexatnet.com/articles/model-view-controller-mvc-javascript

function MSPController(model, view) {
    var self = this;
    self.server = 'http://'+server+'/browser/';
    self.model = model;
    self.view = view;
    self.msg = $('#error');
    self.editor_id = '#editor';
    self.editor = $(self.editor_id);
    self.rule_editor_id = '#rule-editor';
    self.rule_editor = $(self.rule_editor_id);
    self.klasses = {};

    self.use_classes = null;
    self.layer_classes = null;

    self.view.planCommand.attach(function(sender, args) {
        if (args.cmd == 'add')
            self.addPlan();
        else if (args.cmd == 'edit')
            self.editPlan(self.model.plan);
        else if (args.cmd == 'delete')
            self.deletePlan(self.model.plan);
        else if (args.cmd == 'add_use')
            self.addUse(self.model.plan);
    });
    
    self.view.useCommand.attach(function(sender, args) {
        if (args.cmd == 'edit') {
            if (args.use.id == 0) // "Data"
                self.editDatasetList(self.model.plan, args.use);
            else
                self.editUse(self.model.plan, args.use);
        } else if (args.cmd == 'delete')
            self.deleteUse(self.model.plan, args.use);
        else if (args.cmd == 'add_layer')
            self.addLayer(self.model.plan, args.use);
    });
    
    self.view.layerCommand.attach(function(sender, args) {
        if (args.cmd == 'edit')
            self.editLayer(self.model.plan, args.use, args.layer);
        else if (args.cmd == 'delete')
            self.deleteLayer(self.model.plan, args.use, args.layer);
        else if (args.cmd == 'add_rule')
            self.addRule(self.model.plan, args.use, args.layer);
        else if (args.cmd == 'delete_rule')
            self.deleteRule(self.model.plan, args.use, args.layer);
    });
    
    self.view.ruleSelected.attach(function(sender, args) {
        self.editRule(args);
    });

    self.model.newPlans.attach(function(sender, args) {
        self.editor.dialog('close');
    });

    self.model.error.attach(function(sender, args) {
        self.error(args.msg);
    });

    self.view.error.attach(function(sender, args) {
        self.error(args.msg);
    });

    self.msg.dialog({
        autoOpen: false,
        height: 400,
        width: 350,
        modal: true,
        buttons: {
            Ok: function() {
                self.msg.dialog('close');
            },
        },
        close: function() {
        }
    });

    self.editor.dialog({
        autoOpen: false,
        height: 400,
        width: 350,
        modal: true,
        buttons: {
            Ok: function() {
                if (self.ok()) self.editor.dialog('close');
            },
            Cancel: function() {
                self.editor.dialog('close');
            }
        },
        close: function() {
        }
    });

    self.rule_editor.dialog({
        autoOpen: false,
        height: 400,
        width: 350,
        modal: false,
        buttons: {
            Apply: function() {
                self.apply();
            },
            Close: function() {
                self.rule_editor.dialog('close');
            }
        },
        close: function() {
        }
    });
}

MSPController.prototype = {
    error: function(msg) {
        var self = this;
        self.msg.html(msg)
        self.msg.dialog('open');
    },
    post: function(args) {
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
        $.post(args.url, args.payload,
               function(data) {
                   if (data.error)
                       self.error(data.error);
                    else
                        args.atSuccess(data);
                }
              )
            .fail(function(xhr, textStatus, errorThrown) {
                var msg = xhr.responseText;
                if (msg == '') msg = textStatus;
                msg = 'Calling SmartSea MSP server failed. The error message is: '+msg;
                self.error(msg);
            });  
    },
    simpleObjects: function(klass, query) {
        var self = this;
        if (!query) query = '';
        if (!self.klasses[klass]) {
            $.ajax({
                headers: {
                    Accept: 'application/json'
                },
                url: self.server+klass+query,
                success: function (result) {
                    if (result.isOk == false) self.error(result.message);
                    self.klasses[klass] = result;
                },
                fail: function (xhr, textStatus, errorThrown) {
                    var msg = xhr.responseText;
                    if (msg == '') msg = textStatus;
                    msg = 'Calling SmartSea MSP server failed. The error message is: '+msg;
                    self.error(msg);
                },
                async: false
            });
        }
        return self.klasses[klass];
    },
    getNetworks: function() {
        var self = this;
        if (self.networks) return;
        $.ajax({
            headers: {Accept: 'application/json'},
            url: 'http://'+server+'/networks',
            success: function (result) {
                self.networks = result;
            },
            async: false
        });
    },
    loadPlans: function() {
        var self = this;
        self.post({
            url: 'http://'+server+'/plans',
            payload: {},
            atSuccess: function(data) {
                var plans = [], ecosystem, datasets;
                $.each(data, function(i, plan) {
                    if (!plan.uses) plan.uses = [];
                    $.each(plan.uses, function(j, use) {
                        var layers = [];
                        $.each(use.layers, function(k, layer) {
                            layer.model = self.model;
                            layer.server = 'http://' + server + '/WMTS';
                            layer.map = self.model.map;
                            layer.projection = self.model.proj;
                            layer.use_class_id = use.class_id;
                            layers.push(new MSPLayer(layer));
                        });
                        use.layers = layers;
                    });
                });
                // pseudo uses, note reserved use class id's
                $.each(data, function(i, plan) {
                    if (plan.id == 0) { // a pseudo plan Data
                        datasets = plan.uses[0];
                    } else if (plan.id == 1) { // a pseudo plan Ecosystem
                        ecosystem = plan.uses[0];
                    } else {
                        plans.push(plan);
                    }
                });
                self.model.setPlans(plans, ecosystem, datasets);
            }
        });
    },
    addPlan: function(args) {
        var self = this;
        if (!args) args = {};
        self.editor.dialog('option', 'title', 'Uusi suunnitelma');
        self.editor.dialog('option', 'height', 400);
        var name = 'plan-name';
        var html = 'Anna nimi suunnitelmalle: '+element('input', {type:'text', id:name}, '');
        if (args.error) html = element('p', {style:'color:red;'}, args.error)+html;
        self.editor.html(html);
        self.ok = function() {
            name = $(self.editor_id+' #'+name).val();
            if (self.model.planNameOk(name)) {
                self.post({
                    url: self.server+'plan?request=save',
                    payload: { name: name },
                    atSuccess: function(data) {
                        var plan = {
                            id: data.id.value,
                            owner: data.owner.value,
                            name: data.name.value
                        };
                        self.model.addPlan(plan);
                    }
                });
            } else {
                self.addPlan({error:"Suunnitelma '"+name+"' on jo olemassa."});
                return false;
            }
        };
        self.editor.dialog('open');
    },
    editPlan: function(plan) {
        var self = this;
        self.editor.dialog('option', 'title', 'Suunnitelma');
        self.editor.dialog('option', 'height', 400);
        var name = 'plan-name';
        var html = element('input', {type:'text', id:name, value:plan.name}, '');
        html = element('p', {}, 'Suunnitelman nimi: ' + html);
        self.editor.html(html);
        self.ok = function() {
            name = $(self.editor_id+' #'+name).val();
            if (self.model.planNameOk(name)) {
                self.post({
                    url: self.server+'plan:'+plan.id+'?request=update',
                    payload: { name: name },
                    atSuccess: function(data) {
                        var plan = {
                            id: data.id.value,
                            owner: data.owner.value,
                            name: data.name.value
                        };
                        self.model.editPlan(plan);
                    }
                });
            } else {
                self.addPlan({error:"Suunnitelma '"+name+"' on jo olemassa."});
                return false;
            }
            return true;
        };
        self.editor.dialog('open');
    },
    deletePlan: function(plan) {
        var self = this;
        self.editor.dialog('option', 'title', 'Poista suunnitelma?');
        self.editor.dialog('option', 'height', 400);
        self.editor.html("Haluatko varmasti poistaa koko suunnitelman '"+plan.name+"'?");
        self.ok = function() {
            self.post({
                url: self.server+'plan:'+plan.id+'?request=delete',
                atSuccess: function(data) {self.model.deletePlan(plan.id)}
            });
            return true;
        };
        self.editor.dialog('open');
    },
    addUse: function(plan) {
        var self = this;
        self.editor.dialog('option', 'title', 'New use');
        self.editor.dialog('option', 'height', 400);
        var id = 'use-id';
        var name = 'use-name';
        var classes = self.simpleObjects('use_class');
        var list = '';
        for (var i = 0; i < classes.length; ++i) {
            if (!self.model.hasUse(classes[i].id)) {
                list += element('option', {value:classes[i].id}, classes[i].name);
            }
        }
        var html = 'Select the class for the new use: '+element('select', {id:id}, list);
        self.editor.html(html)
        self.ok = function() {
            id = $(self.editor_id+' #'+id).val();
            self.post({
                url: self.server+'plan:'+plan.id+'/uses?request=create',
                payload: {use_class: id},
                atSuccess: function(data) {
                    var use = {
                        id: data.id.value,
                        owner: data.owner.value,
                        plan: data.plan.value,
                        class_id: data.use_class.value,
                        layers: []
                    };
                    $.each(classes, function(i, klass) {
                        if (klass.id == data.use_class.value) {
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
    editUse: function(plan, use) {
        var self = this;
        self.editor.dialog('option', 'title', use.name);
        self.editor.dialog('option', 'height', 400);

        var activities = {};
        $.each(self.simpleObjects('use_class', ':'+use.class_id+'/activities'), function(i, item) {
            activities[item.id] = item;
        });
        var activities = new Widget({
            container_id:self.editor_id,
            id:'activities_list',
            type:'checkbox-list',
            list:self.simpleObjects('activity'),
            selected:activities,
            pretext:''
        });
        var html = element('p', {}, 'This is now for your information only.')
            + element('p', {}, activities.content());

        self.editor.html(html);
        self.ok = function() {
            var selected = datasets.selected_ids();
            var update = '';
            $.each(selected, function(id, i) {
                if (update) update += '&';
                update += 'dataset='+id;
            });
            return true;
        };
        self.editor.dialog('open');
    },
    editDatasetList: function(plan, use) {
        var self = this;
        self.editor.dialog('option', 'title', 'Dataset list');
        self.editor.dialog('option', 'height', 400);

        // put into the list those datasets that are not in rules
        // selected are those in plan.data
        
        var inRules = self.model.datasetsInRules();
        var notInRules = [];
        $.each(self.model.datasets.layers, function(i, layer) {
            if (!inRules[layer.id]) notInRules.push(layer);
        });
        var datasets = new Widget({
            container_id:self.editor_id,
            id:'dataset_list',
            type:'checkbox-list',
            list:notInRules,
            selected:plan.data,
            pretext:'Select the extra datasets for this plan: '
        });
        var html = element('p', {}, datasets.content());
        
        self.editor.html(html);
        self.ok = function() {
            var selected = datasets.selected_ids();
            var update = '';
            $.each(selected, function(id, i) {
                if (update) update += '&';
                update += 'dataset='+id;
            });
            self.post({
                url: self.server+'plan:'+plan.id+'/extra_datasets?request=update',
                payload: update,
                atSuccess: function(data) {self.model.setPlanData(data)}
            });
            return true;
        };
        self.editor.dialog('open');
    },
    deleteUse: function(plan, use) {
        var self = this;
        self.editor.dialog('option', 'title', 'Poista käyttömuoto?');
        self.editor.dialog('option', 'height', 400);
        self.editor.html("Haluatko varmasti poistaa koko käyttömuodon '"+use.name+"' suunnitelmasta '"+plan.name+"'?");
        self.ok = function() {
            self.post({
                url: self.server+'use:'+use.id+'?request=delete',
                atSuccess: function(data) {self.model.deleteUse(use.id)}
            });
            return true;
        };
        self.editor.dialog('open');
    },
    addLayer: function(plan, use) {
        var self = this;
        self.editor.dialog('option', 'title', 'New layer for '+use.name);
        self.editor.dialog('option', 'width', 500);
        self.editor.dialog('option', 'height', 600);
        
        var klass_list = new Widget({
            container_id:self.editor_id,
            id:'layer-klass',
            type:'select',
            list:self.simpleObjects('layer_class'),
            get_item:function(i, klass) {
                if (klass.id == 5) return null; // TODO: Impact layers
                var retval = klass;
                $.each(use.layers, function(j, layer) {
                    if (klass.id == layer.class_id) {
                        retval = null;
                        return false;
                    }
                });
                return retval;
            },
            pretext:'Select the class for the new layer: '
        });

        var rule_class_list = new Widget({
            container_id:self.editor_id,
            id:'layer-rule-class',
            type:'select',
            selected:'exclusive',
            list:self.simpleObjects('rule_class'),
            pretext:'Select the rule type for the new layer: '
        });

        var rule_class_extra = new Widget({
            container_id:self.editor_id,
            id:'rule-class-extra',
            type:'para'
        });
        var network, node, state;
      
        var color_list = new Widget({
            container_id:self.editor_id,
            id:'layer-color',
            type:'select',
            list:self.simpleObjects('color_scale'),
            pretext:'Select the color for the new layer: '
        });
        
        var name = 'layer-name';
        var html = element('p', {}, klass_list.content());
        html += element('p', {},
                        'The layer will be computed by rules that are based on datasets.'+
                        ' You can add rules after you have created the layer first.');
        html += element('p', {}, rule_class_list.content());
        html += element('p', {}, rule_class_extra.content());
        html += element('p', {}, color_list.content());
        self.editor.html(html);

        rule_class_list.changed((function changed() {
            var klass = rule_class_list.selected();
            if (klass && klass.name == 'Bayesian network') {
                
                self.getNetworks();
                network = new Widget({
                    container_id:self.editor_id,
                    id:'layer-network',
                    type:'select',
                    selected:self.networks[0].name,
                    list:self.networks,
                    pretext:'Select the Bayesian network: '
                });
                rule_class_extra.html(element('p', {}, network.content()));

                network.changed((function changed() {
                    var net = network.selected(); // net is not null since we have set selected above
                    node = new Widget({
                        container_id:self.editor_id,
                        id:'layer-node',
                        type:'select',
                        selected:net.nodes[0].name,
                        list:net.nodes,
                        pretext:'Select the node: '
                    });
                    rule_class_extra.html(element('p', {}, network.content()) +
                                          element('p', {}, node.content()));

                    node.changed((function changed() {
                        var nod = node.selected(); // nod is not null since we have set selected above
                        state = new Widget({
                            container_id:self.editor_id,
                            id:'layer-state',
                            type:'select',
                            selected:nod.values[0],
                            list:nod.values,
                            pretext:'Select the state: '
                        }); 
                        rule_class_extra.html(element('p', {}, network.content()) +
                                              element('p', {}, node.content()) +
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
        
        self.ok = function() {
            var klass = klass_list.selected();
            var rule_class = rule_class_list.selected();
            var color = color_list.selected();
            var payload = {
                layer_class:klass.id,
                color_scale:color.id,
                rule_class:rule_class.id
            };
            if (rule_class.name === "Bayesian network") {
                payload.network_file = network.selected().id;
                payload.output_node = node.selected().id;
                payload.output_state = state.value();
            }
            self.post({
                url: self.server+'plan:'+plan.id+'/uses:'+use.id+'/layers?request=create',
                payload: payload,
                atSuccess: function(data) {
                    var layer = new MSPLayer({
                        model: self.model,
                        server: 'http://' + server + '/WMTS',
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
        self.editor.dialog('open');
    },
    editLayer: function(plan, use, layer) {
        var self = this;
        self.editor.dialog('option', 'title', 'Layer');
        self.editor.dialog('option', 'height', 400);
        
        var color_list = new Widget({
            container_id:self.editor_id,
            id:'layer-color',
            type:'select',
            list:self.simpleObjects('color_scale'),
            selected:layer.color_scale
        });
        
        var html = element('p', {}, 'Set the color for this layer: ') +
            element('p', {}, color_list.content());
        if (use.id == 0) {
            html += element('p', {}, 'The color setting is temporary for datasets.');
        }
        
        self.editor.html(html);
        
        self.ok = function() {
            var color = color_list.selected(); // fixme, when is this set?
            var payload = {
                color_scale: color.id
            };
            var url;
            if (use.id == 0) {
                // layer is dataset
                layer.color_scale = color.name;
                layer.refresh();
                self.model.selectLayer({use:use.id,layer:layer.id});
            } else {
                self.post({
                    url: self.server+'layer:'+layer.id+'?request=update',
                    payload: payload,
                    atSuccess: function(data) {
                        layer.refresh();
                        self.model.selectLayer({use:use.id,layer:layer.id});
                    }
                });
            }
            return true;
        };
        self.editor.dialog('open');
    },
    deleteLayer: function(plan, use, layer) {
        var self = this;
        self.editor.dialog('option', 'title', 'Poista ominaisuus?');
        self.editor.dialog('option', 'height', 400);
        self.editor.html("Haluatko varmasti poistaa ominaisuuden '"+layer.name+"' käyttömuodosta '"+use.name+"'?");
        self.ok = function() {
            self.post({
                url: self.server+'layer:'+layer.id+'?request=delete',
                atSuccess: function(data) {self.model.deleteLayer(use.id, layer.id)}
            });
            return true;
        };
        self.editor.dialog('open');
    },
    addRule: function(plan, use, layer) {
        var self = this;
        self.editor.dialog('option', 'title', 'Lisää sääntö tasoon '+layer.name);
        self.editor.dialog('option', 'height', 500);

        if (layer.rule_class === 'Bayesian network') {
            self.addRuleBayesian(plan, use, layer);
            self.editor.dialog('open');
            return;
        }
        
        var dataset = new Widget({
            container_id:self.editor_id,
            id:'rule-dataset',
            type:'select',
            list:self.model.datasets.layers,
            pretext:'Rule is based on the dataset: '
        });
        var rule = new Widget({
            container_id:self.editor_id,
            id:'rule-defs',
            type:'para'
        });
        var html = element('p', {}, dataset.content()) + element('p', {id:'descr'}, '') + rule.content();

        // the rule can be binary, if dataset has only one class
        // otherwise the rule needs operator and threshold
        var op = new Widget({
            container_id:self.editor_id,
            id:'rule-op',
            type:'select',
            list:self.simpleObjects('op'),
            pretext:'Define the operator and the threshold:<br/>'
        });
        var threshold;
        var args = {
            container_id: self.editor_id,
            id: 'threshold'
        };
        self.editor.html(html);
        
        dataset.changed((function changed() {
            var set = dataset.selected();
            $(self.editor_id+' #descr').html(set.descr);
            if (!set) {
                rule.html('');
            } else if (set.classes == 1) {
                rule.html('Binary rule');
            } else {
                if (set.semantics) {
                    args.type = 'select';
                    args.list = set.semantics;
                } else if (set.data_type == 'integer') {
                    args.type = 'spinner';
                } else if (set.data_type == 'real') {
                    args.type = 'slider';
                }
                args.min = set.min_value;
                args.max = set.max_value;
                args.value = set.min_value;
                threshold = new Widget(args);
                rule.html(op.content() + '&nbsp;' + threshold.content());
                threshold.prepare();
            }
            return changed;
        }()));

        self.ok = function() {
            var set = dataset.selected();
            var operator = op.selected();
            var value = 0;
            if (set.classes != 1) value = threshold.value();
            var payload = {dataset:set.id};
            if (operator) {
                payload.op = operator.id;
                payload.value = value;
            }
            self.post({
                url: self.server+'plan:'+plan.id+'/uses:'+use.id+'/layers:'+layer.id+'/rules?request=save',
                payload: payload,
                atSuccess: function(data) {
                    var rule = {
                        id: data.id.value,
                        dataset: data.dataset.value,
                        value: data.value.value,
                        active: true
                    };
                    if (operator) {
                        rule.op = operator.name;
                    }
                    self.model.addRule(rule);
                }
            });
            return true;
        };
        self.editor.dialog('open');
    },
    addRuleBayesian: function(plan, use, layer) {
        var self = this;
        
        // rule is a node in a Bayesian network
        // for now we assume it is a (hard) evidence node, i.e.,
        // the dataset must be integer, and its value range the same as the node's
        
        var dataset_list = [];
        $.each(self.model.datasets.layers, function(i, dataset) {
            if (dataset.data_type === "integer") {
                dataset_list.push(dataset);
            }
        });
        var dataset = new Widget({
            container_id:self.editor_id,
            id:'rule-dataset',
            type:'select',
            list:dataset_list,
            selected:dataset_list[0],
            pretext:'Base the rule on dataset: '
        });

        self.getNetworks();
        var network = null;
        $.each(self.networks, function(i, network2) {
            if (network2.id === layer.network_file) {
                network = network2;
                return false;
            }
        });
        var nodes = [];
        $.each(network.nodes, function(i, node) {
            var used = node.id === layer.output_node;
            if (!used) {
                $.each(layer.rules, function(i, rule) {
                    if (node.id == rule.node_id) {
                        // already used
                        used = true;
                        return false;
                    }
                });
            }
            if (!used) nodes.push(node);
        });
        var node = new Widget({
            container_id:self.editor_id,
            id:'rule-node',
            type:'select',
            list:nodes,
            selected:nodes[0],
            pretext:'Link the dataset to node: '
        });
        var offset = new Widget({
            container_id:self.editor_id,
            id:'rule-offset',
            type:'spinner',
            value: 0,
            min: -10,
            max: 10,
            pretext:'Offset (to match states): '
        });
        
        var html = element('p', {}, dataset.content()) +
            element('p', {id:'dataset-states'}, '') +
            element('p', {id:'descr'}, '') +
            element('p', {}, offset.content()) +
            node.content() +
            element('p', {id:'node-states'}, '');
        
        self.editor.html(html);
        offset.prepare();
        
        dataset.changed((function changed() {
            var set = dataset.selected();
            $(self.editor_id+' #descr').html(set.descr);
            var states = set.min_value+'..'+set.max_value+'<p>';
            if (set.semantics) {
                var j = 0;
                $.each(set.semantics, function(i, value) {
                    if (j > 0) states += ', ';
                    states += i+': '+value;
                    j += 1;
                });
            }
            states += '</p>';
            $(self.editor_id+' #dataset-states').html('States: '+states);
            return changed;
        }()));

        node.changed((function changed() {
            var n = node.selected();
            var states = '';
            if (n) {
                $.each(n.values, function(i, value) {
                    if (i > 0) states += ', ';
                    states += i+': '+value;
                });
            }
            $(self.editor_id+' #node-states').html('States: '+states);
            return changed;
        }()));

        self.ok = function() {
            var set = dataset.selected();
            var off = offset.value();
            var nd = node.selected();
            var payload = {
                dataset:set.id,
                state_offset:off,
                node_id:nd.id
            };
            self.post({
                url: self.server+'plan:'+plan.id+'/uses:'+use.id+'/layers:'+layer.id+'/rules?request=save',
                payload: payload,
                atSuccess: function(data) {
                    var rule = {
                        id: data.id.value,
                        dataset: data.dataset.value,
                        state_offset: data.state_offset.value,
                        node_id: data.node_id.value,
                        active: true
                    };
                    self.model.addRule(rule);
                }
            });
            return true;
        };
    },
    deleteRule: function(plan, use, layer) {
        var self = this;
        self.editor.dialog('option', 'title', "Delete rules from layer '"+layer.name+"'");
        self.editor.dialog('option', 'height', 400);

        var rules = new Widget({
            container_id:self.editor_id,
            id:'rules-to-delete',
            type:'checkbox-list',
            list:layer.rules,
            selected:{},
            get_item_name:function(rule) {
                return rule.getName();
            }
        });
        
        var html = element('p', {}, 'Select rules to delete:')+rules.content();
        
        self.editor.html(html);
        
        self.ok = function() {
            var selected = rules.selected_ids();
            var deletes = '';
            $.each(selected, function(id, i) {
                if (deletes) deletes += '&';
                deletes += 'rule='+id;
            });
            self.post({
                url: self.server+'plan:'+plan.id+'/uses:'+use.id+'/layers:'+layer.id+'/rules?request=delete',
                payload: deletes,
                atSuccess: function(data) {self.model.deleteRules(selected)}
            });
            return true;
        };
        self.editor.dialog('open');
    },
    editRule: function(args) {
        var self = this;
        self.rule_editor.dialog('option', 'title', 'Edit rule');
        self.rule_editor.dialog('option', 'height', 400);
        
        var rule = self.model.selectRule(args.id);
        var html = rule.getCriteria().name;
        var owner = rule.layer.owner == user;

        if (!owner) html += element('p', {}, 'Et ole tämän tason omistaja. Muutokset ovat tilapäisiä.');
        
        html = html
            .replace(/^- If/, 'Do not allocate if')
            .replace(/==/, 'equals:');

        var threshold;
        var ruleAttr = rule.getMinMax();
        var args = {
            container_id:self.rule_editor_id,
            id:'threshold',
            value: rule.value,
            min: ruleAttr.min,
            max: ruleAttr.max,
        };
        if (ruleAttr.classes == 1) {
            html += element('p', {}, 'Binary rule, nothing to edit.');
        } else {
            if (ruleAttr.semantics) {
                if (self.model.layer.rule_class == 'exclusive') {
                    html = 'Alue ei ole sopiva jos '+html+' on '+rule.op+' kuin';
                }
                args.type = 'select';
                args.list = ruleAttr.semantics;
            } else if (ruleAttr.data_type == 'integer') {
                args.type = 'spinner';
            } else if (ruleAttr.data_type == 'real') {
                args.type = 'slider';
            }
            threshold = new Widget(args);
            html += element('p', {}, threshold.content());
        }
        html += element('p', {}, rule.description());
        self.rule_editor.html(html);

        if (threshold) threshold.prepare();
        self.apply = function() {
            var value = threshold.value();
            var request = owner ? 'update' : 'modify';
            self.post({
                url: self.server+'rule:'+rule.id+'?request='+request,
                payload: { value: value },
                atSuccess: function(data) {
                    self.model.editRule({value: value});
                }
                // if (xhr.status == 403)
                // self.error('Rule modification requires cookies. Please enable cookies and reload this app.');
            });
        };
        self.rule_editor.dialog('open');
    }
};

