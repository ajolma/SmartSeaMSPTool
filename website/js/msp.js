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
    self.model = model;
    self.view = view;
    self.editor_id = "#editor";
    self.editor = $(self.editor_id);
    self.rule_tool_id = "#rule-tool";
    self.rule_tool = $(self.rule_tool_id);

    self.use_classes = null;
    self.layer_classes = null;

    self.view.planSelected.attach(function(sender, args) {
        self.changePlan(args.id);
    });
    self.view.newLayerOrder.attach(function(sender, args) {
        self.model.setLayerOrder(args.order);
    });
    self.view.addPlan.attach(function(sender, args) {
        self.addPlan();
    });
    self.view.editPlan.attach(function(sender, args) {
        self.editPlan(args);
    });
    self.view.addUse.attach(function(sender, args) {
        self.addUse();
    });
    self.view.editUse.attach(function(sender, args) {
        self.editUse(args);
    });
    self.view.addLayer.attach(function(sender, args) {
        self.addLayer(args);
    });
    self.view.editLayer.attach(function(sender, args) {
        self.editLayer(args);
    });
    self.view.ruleSelected.attach(function(sender, args) {
        self.modifyRule(args);
    });

    self.model.newPlans.attach(function(sender, args) {
        self.editor.dialog('close');
    });

    self.editor.dialog({
        autoOpen: false,
        height: 400,
        width: 350,
        modal: true,
        buttons: {
            Ok: function() {
                self.ok();
                self.editor.dialog('close');
            },
            Cancel: function() {
                self.editor.dialog('close');
            }
        },
        close: function() {
        }
    });

    self.rule_tool.dialog({
        autoOpen: false,
        height: 400,
        width: 350,
        modal: false,
        buttons: {
            Apply: function() {
                self.apply();
            },
            Close: function() {
                self.rule_tool.dialog('close');
            }
        },
        close: function() {
        }
    });
}

MSPController.prototype = {
    post: function(args) {
        $.ajaxSetup({
            headers: { 
                Accept : "application/json"
            },
            crossDomain: true,
            xhrFields: {
                withCredentials: true
            }
        });
        $.post(args.url, args.payload,
               function(data) {
                   if (data.error)
                       alert(data.error);
                    else
                        args.atSuccess(data);
                }
              )
            .fail(function(xhr, textStatus, errorThrown) {
                var msg = xhr.responseText;
                if (msg == '') msg = textStatus;
                msg = "Calling SmartSea MSP server failed. The error message is: "+msg;
                alert(msg);
            });  
    },
    useClasses: function() {
        var self = this;
        if (!self.use_classes) {
            $.ajax({
                url: 'http://'+server+'/use_classes',
                success: function (result) {
                    if (result.isOk == false) alert(result.message);
                    self.use_classes = result;
                },
                async: false
            });
        }
        return self.use_classes;
    },
    layerClasses: function() {
        var self = this;
        if (!self.layer_classes) {
            $.ajax({
                url: 'http://'+server+'/layer_classes',
                success: function (result) {
                    if (result.isOk == false) alert(result.message);
                    self.layer_classes = result;
                },
                async: false
            });
        }
        return self.layer_classes;
    },
    changePlan: function(id) {
        this.model.changePlan(id);
    },
    addPlan: function() {
        var self = this;
        self.editor.dialog("option", "title", 'Uusi suunnitelma');
        var name = 'plan-name';
        self.editor.html("Name for the new plan: "+element('input', {type:'text', id:name}, ''));
        self.ok = function() {
            name = $(self.editor_id+' #'+name).val();
            self.post({
                url: 'http://'+server+'/browser/plan?save',
                payload: { name: name },
                atSuccess: function(data) {self.model.addPlan(data)}
            });
        };
        self.editor.dialog('open');
    },
    editPlan: function(plan) {
        var self = this;
        self.editor.dialog("option", "title", 'Suunnitelma');
        var name = 'plan-name';
        var del = 'delete-plan';
        var html = element('p', {}, "Name for the plan: "+element('input', {type:'text', id:name, value:plan.name}, ''));
        html += element('p', {}, element('input', {id:del, type:"checkbox"},  "Delete plan "+plan.name));
        self.editor.html(html);
        self.ok = function() {
            name = $(self.editor_id+' #'+name).val();
            del = $(self.editor_id+' #'+del).prop('checked');
            if (del) {
                self.post({
                    url: 'http://'+server+'/browser/plan:'+plan.id+'?delete',
                    payload: {},
                    atSuccess: function(data) {self.model.deletePlan(plan.id)}
                });
            } else {
                self.post({
                    url: 'http://'+server+'/browser/plan:'+plan.id+'?modify',
                    payload: { name: name },
                    atSuccess: function(data) {self.model.editPlan(data)}
                });
            }
        };
        self.editor.dialog('open');
    },
    addUse: function() {
        var self = this;
        self.editor.dialog("option", "title", 'New use');
        var id = 'use-id';
        var name = 'use-name';
        var classes = self.useClasses();
        var list = '';
        for (var i = 0; i < classes.length; ++i) {
            if (!self.model.hasUse(classes[i].id)) {
                list += element('option', {value:classes[i].id}, classes[i].name);
            }
        }
        var html = "Select the class for the new use: "+element('select', {id:id}, list);
        self.editor.html(html)
        self.ok = function() {
            id = $(self.editor_id+' #'+id).val();
            self.post({
                url: 'http://'+server+'/browser/use?save',
                payload: { plan:self.model.plan.id, use_class:id },
                atSuccess: function(data) {self.model.addUse(data)}
            });
        };
        self.editor.dialog('open');
    },
    editUse: function(args) {
        var self = this;
        args = self.model.getLayer(args);
        self.editor.dialog("option", "title", 'Use');
        var del = 'delete-use';
        self.editor.html(element('input', {id:del, type:"checkbox"},  "Delete use "+args.use.name));
        self.ok = function() {
            del = $(self.editor_id+' #'+del).prop('checked');
            if (del) {
                self.post({
                    url: 'http://'+server+'/browser/use:'+args.use.id+'?delete',
                    payload: {},
                    atSuccess: function(data) {self.model.deleteUse(args.use.id)}
                });
            }
        };
        self.editor.dialog('open');
    },
    addLayer: function(args) {
        var self = this;
        self.editor.dialog("option", "title", 'New layer');
        var id = 'layer-id';
        var name = 'layer-name';
        var classes = self.layerClasses();
        var list = '';
        for (var i = 0; i < classes.length; ++i) {
            if (!self.model.hasLayer({use:args.use, layer:classes[i].id})) {
                list += element('option', {value:classes[i].id}, classes[i].name);
            }
        }
        var html = "Select the class for the new layer: "+element('select', {id:id}, list);
        self.editor.html(html)
        self.ok = function() {
            id = $(self.editor_id+' #'+id).val();
            self.post({
                url: 'http://'+server+'/browser/layer?save',
                payload: { use:args.use, layer_class:id, style:0, rule_system:0 },
                atSuccess: function(data) {self.model.addLayer(data)}
            });
        };
        self.editor.dialog('open');
    },
    editLayer: function(args) {
        var self = this;
        args = self.model.getLayer(args);
        self.editor.dialog("option", "title", 'Layer');
        var name = 'plan-name';
        self.editor.html("Layer: "+element('input', {type:'text', id:name, value:args.layer.name}, ''));
        self.ok = function() {
            name = $(self.editor_id+' #'+name).val();
            self.post({
                url: 'http://'+server+'/browser/plan:id?modify',
                payload: { name: name },
                atSuccess: function(data) {self.model.editLayer(data)}
            });
        };
        self.editor.dialog('open');
    },
    addRule: function() {
    },
    deleteRule: function() {
    },
    modifyRule: function(args) {
        var self = this;
        self.rule_tool.dialog("option", "title", 'Modify rule');
        var rule = self.model.selectRule(args.id);
        var html = rule.name;
        
        html = html
            .replace(/^- If/, "Do not allocate if")
            .replace(/==/, "equals:");

        var editor = 'rule-editor';
        var slider_value = 'rule-slider-value';
        if (rule.value_semantics) {
            if (self.model.layer.rule_class == "exclusive")
                html = "Unmark cell if "+html+" is "+rule.op+" than";
            //var label = element('label',{for:'rule-editor'},'Select value');
            var options = '';
            $.each(rule.value_semantics, function(i, semantic) {
                var attr = {value:i};
                if (i == rule.value) attr.selected = "selected";
                options += element('option', attr, semantic);
            });
            var menu = element('select', {id:editor}, options);
            html += element('p',{},menu);
        } else if (rule.binary) {
            html += element('p',{},"Binary rule, nothing to edit.");
        } else if (rule.type == 'integer') {
            html += element('p',{},element('input', {id:editor}));
        } else if (rule.type == 'real') {
            html += element('p', {}, element('div', {id:editor}));
            html += element('p', {id:slider_value}, '');
        }
        html += element('p', {}, rule.description);
        self.rule_tool.html(html);

        editor = self.rule_tool_id+' #'+editor;
        slider_value = self.rule_tool_id+' #'+slider_value;
        
        if (rule.type == 'integer') {
            $(editor)
                .spinner({
                    min: rule.min,
                    max: rule.max
                })
                .spinner("value", rule.value);
        } else if (rule.type == 'real') {
            $(editor).slider({
                min: parseFloat(rule.min),
                max: parseFloat(rule.max),
                step: 0.1, // todo fix this
                value: parseFloat(rule.value),
                slide: function (event, ui) {
                    var value = slider.slider("value");
                    $(slider_value).html(value);
                }
            });
            $(slider_value).html(rule.value);
        }
        self.apply = function() {
            var value;
            if (rule.value_semantics)
                value = $(editor).find(":selected").attr('value');
            else if (rule.type == 'integer')
                value = $(editor).spinner("value");
            else if (rule.type == 'real')
                value = $(editor).slider("value");
            self.post({
                url: 'http://'+server+'/browser/rule:'+rule.id+'?update',
                payload: { value: value },
                atSuccess: function(data) {
                    self.model.modifyRule(data.object);
                }
                // if (xhr.status == 403)
                //     alert("Rule modification requires cookies. Please enable cookies and reload this app.");
            });
        };
        self.rule_tool.dialog("open");
    }
};

function MSPView(model, elements, id) {
    var self = this;
    self.model = model;
    self.elements = elements;
    self.id = id;
    self.draw = {key:null, draw:null, source:null};
    // elements are plans, layers, rule_info, rules, site_type, site_info, ...
    // ids are rules

    self.elements.layers.sortable({
        stop: function () {
            var newOrder = [];
            var uses = self.model.plan.uses;
            var ul = self.elements.layers.children();
            for (var i = 0; i < ul.length; ++i) {
                var n = ul[i].id;
                n = n.replace(/use/, '');
                newOrder.push(n);
            }
            self.newLayerOrder.notify({ order : newOrder });
        }
    });

    self.planSelected = new Event(self);
    self.newLayerOrder = new Event(self);

    self.addPlan = new Event(self);
    self.editPlan = new Event(self);
    self.addUse = new Event(self);
    self.editUse = new Event(self);
    self.addLayer = new Event(self);
    self.editLayer = new Event(self);
    self.ruleSelected = new Event(self);

    // attach model listeners
    self.model.newPlans.attach(function(sender, args) {
        self.buildPlans();
    });
    self.model.planChanged.attach(function(sender, args) {
        self.elements.plans.val(args.plan.id);
        self.buildPlan(args.plan);
    });
    self.model.newLayerList.attach(function(sender, args) {
        self.buildLayers();
    });
    self.model.layerSelected.attach(function(sender, args) {
        self.selectLayer();
        self.fillRulesPanel();
    });
    self.model.layerUnselected.attach(function(sender, args) {
        self.unselectLayer(args);
    });
    self.model.ruleEdited.attach(function(sender, args) {
        self.fillRulesPanel(self.model.layer);
    });
    self.model.siteInitialized.attach(function(sender, args) {
        self.siteInteraction(args.source);
    });
    self.model.siteInformationReceived.attach(function(sender, args) {
        self.elements.site_info.html(args.report);
    });

    // attach listeners to HTML controls
    self.elements.plans.change(function(e) {
        self.planSelected.notify({ id : self.elements.plans.val() });
    });
}

MSPView.prototype = {
    windowResize: function() {
        var right_width = 220; // from layout.css
        var h = $(window).height() -  $('.header').height() - $('.plot').height();
        var w = $(window).width() - right_width - 15;
        this.elements.map
            .height(h)
            .width(w);
        $('.right').css('max-height', h);
        if (this.model.map) this.model.map.updateSize();
    },
    buildPlans: function() {
        var self = this;
        if (user != 'guest') self.elements.user.html('Hello '+user+'!');
        if (self.model.auth) {
            self.elements.plan.html(
                element('button', {id:"add_plan", type:'button', style:'display:inline;'}, 'Add plan') +
                '&nbsp;' +
                element('button', {id:"edit_plan", type:'button', style:'display:inline;'}, 'Edit plan'));
            $("#add_plan").click(function() {
                self.addPlan.notify();
            });
            $("#edit_plan").click(function() {
                self.editPlan.notify(self.model.plan);
            });
        }
        self.elements.plans.html('');
        $.each(self.model.plans, function(i, plan) {
            if (plan.id > 1) // not Ecosystem and Data, which are "pseudo plans"
                self.elements.plans.append(element('option',{value:plan.id},plan.name));
        });
        this.elements.rule_header.html('');
        self.elements.rule_info.html('');
        self.elements.site.html('');
        self.elements.color_scale.html('');
    },
    buildPlan: function(plan) {
        var self = this;
        if (self.model.auth) {
            if (self.model.plan.owner == user)
                $("#edit_plan").show();
            else
                $("#edit_plan").hide();
        }
        self.model.createLayers(true);
        self.elements.rules.empty();
        self.fillRulesPanel();
    },
    usesItem: function(use) {
        var self = this;
        var use_item = element('button', {class:'use', type:'button'}, '&rtrif;') + '&nbsp;' + use.name;
        use_item = element('label', {title:use.name}, use_item);
        if (self.model.auth && use.owner == user) {
            use_item += '&nbsp;' + element('button', {class:"edit", type:'button'}, 'Edit');
        }
        var callbacks = [];
        var layers = '';
        if (self.model.auth && use.owner == user) {
            layers = element('button', {id:'add_layer_'+use.id, type:'button'}, 'Add layer')+'<br/>';
        }
        $.each(use.layers.reverse(), function(j, layer) {
            var attr = { type: "checkbox", class: "visible"+layer.index };
            var id = 'l'+use.id+'_'+layer.id;
            var name = layer.name;
            var lt = element('div', { id:id, style:'display:inline;' }, name);
            if (self.model.auth && layer.owner == user) {
                lt += '&nbsp;'+element('button', {class:"layer_edit"+layer.index, type:'button'}, 'Edit');
            }
            lt += '<br/>';
            layers += element('input', attr, lt);
            attr = { class:"opacity"+layer.index, type:"range", min:"0", max:"1", step:"0.01" };
            layers += element('div', {class:"opacity"+layer.index}, element('input', attr, '<br/>'));
            callbacks.push({ selector: '#'+id, use: use.id, layer: layer.id });
        });
        layers = element('div', {class:'use'}, layers);
        var attr = { id: 'use'+use.index, tabindex: use.index+1 };
        return { element: element('li', attr, use_item + layers), callbacks: callbacks };
    },
    buildLayers: function() {
        var self = this;
        self.elements.layers.html('');
        if (self.model.auth && self.model.plan.owner == user) {
            self.elements.layers.append(element('button', {id:'add_use', type:'button'}, 'Add use'));
            $("#add_use").click(function() {
                self.addUse.notify();
            });
        }
        // all uses with controls: on/off, select/unselect, transparency
        // end to beginning to maintain overlay order
        $.each(self.model.plan.uses.reverse(), function(i, use) {
            var item = self.usesItem(use);
            self.elements.layers.append(item.element);
            if (self.model.auth && use.owner == user) {
                $("#add_layer_"+use.id).click(function() {
                    self.addLayer.notify({use:use.id});
                });
            }
            $.each(item.callbacks, function(i, callback) {
                $(callback.selector).click(function() {
                    var was_selected = self.model.unselectLayer();
                    if (was_selected.use != callback.use || was_selected.layer != callback.layer)
                        self.model.selectLayer(callback);
                });
            });
        });
        self.selectLayer(); // restore selected layer
        $.each(self.model.plan.uses, function(i, use) {
            // edit use
            $('li#use'+use.index+' button.edit').click(function() {
                self.editUse.notify({use:use.id});
            });
            // open and close a use item
            var b = $('li#use'+use.index+' button.use');
            b.on('click', null, {use:use}, function(event) {
                $('li#use'+event.data.use.index+' div.use').toggle();
                if (!arguments.callee.flipflop) {
                    arguments.callee.flipflop = 1;
                    $(this).html('&dtrif;');
                    event.data.use.open = true;
                } else {
                    arguments.callee.flipflop = 0;
                    $(this).html('&rtrif;');
                    event.data.use.open = false;
                }
            });
            $('li#use'+use.index+' div.use').hide();
            // show/hide layer and set its transparency
            $.each(use.layers, function(j, layer) {
                // edit use
                $('li#use'+use.index+' button.layer_edit'+layer.index).click(function() {
                    self.editLayer.notify({use:use.id, layer:layer.id});
                });
                // show/hide layer
                var cb = $('li#use'+use.index+' input.visible'+layer.index);
                cb.change({use:use, layer:layer}, function(event) {
                    $('li#use'+event.data.use.index+' div.opacity'+event.data.layer.index).toggle();
                    event.data.layer.object.setVisible(this.checked);
                    if (this.checked) {
                        self.model.unselectLayer();
                        var use = self.model.plan.uses[event.data.use.index];
                        var layer = use.layers[event.data.layer.index];
                        self.model.selectLayer({use:use.id, layer:layer.id});
                    }
                    if (self.model.layer)
                        self.elements.site.html(self.model.layer.name);
                    else
                        self.elements.site.html("");
                        
                });
                var slider = $('li#use'+use.index+' input.opacity'+layer.index);
                if (layer.visible) {
                    cb.prop('checked', true);
                } else {
                    $('li#use'+use.index+' div.opacity'+layer.index).hide();
                }
                slider.on('input change', null, {layer:layer}, function(event) {
                    event.data.layer.object.setOpacity(parseFloat(this.value));
                });
                slider.val(String(layer.object.getOpacity()));
            });
            if (use.hasOwnProperty("open") && use.open) {
                // restore openness of use
                use.open = true;
                b.trigger('click');  // triggers b.on('click'... above
            } else {
                use.open = false;
            }
        });
    },
    selectLayer: function() {
        if (!this.model.use || !this.model.layer) return;
        var plan = this.model.plan;
        var use = this.model.use;
        var layer = this.model.layer;
        $("#l"+use.id+'_'+layer.id).css("background-color","yellow");
        var url = 'http://'+self.server+'/legend';
        var cache_breaker = '&time='+new Date().getTime();
        this.elements.color_scale.html(
            element('img',{src:url+'?layer='+plan.id+'_'+use.id+'_'+layer.id+cache_breaker},'')
        );
        if (use.id == 0) {
            this.elements.rule_header.html("Information about dataset:");
            this.elements.rule_info.html(layer.provenance);
        } else {
            this.elements.rule_header.html("Rules for layer:");
            if (layer.rule_class == "exclusive") 
                this.elements.rule_info.html("Default is YES, rules subtract.");
            else if (layer.rule_class == "inclusive") 
                this.elements.rule_info.html("Default is NO, rules add.");
            else if (layer.rule_class == "multiplicative") 
                this.elements.rule_info.html("Value is a product of rules.");
            else if (layer.rule_class == "inclusive") 
                this.elements.rule_info.html("Value is a sum of rules.");
        }
        if (layer.visible) {
            this.elements.site.html(layer.name);
        }
    },
    unselectLayer: function(ids) {
        $("#l"+ids.use+'_'+ids.layer).css("background-color","white");
        this.elements.rule_header.html("");
        this.elements.rule_info.html("");
        this.elements.color_scale.html('');
        this.elements.rules.empty();
        this.elements.site.html("");
    },
    fillRulesPanel: function(layer) {
        var self = this;
        self.elements.rules.empty();
        var layer = self.model.layer;
        if (!layer) return;
        if (layer.descr)
            self.elements.rules.append(layer.descr);
        else
            $.each(layer.rules, function(i, rule) {
                var item;
                if (layer.name == 'Value')
                    item = rule.name;
                else {
                    var attr = {
                        type:"checkbox",
                        use: layer.use,
                        layer: layer.id,
                        rule:rule.id
                    };
                    if (rule.active) attr.checked = "checked";
                    var name = rule.name;
                    if (!rule.binary) {
                        var value = rule.value;
                        if (rule.value_semantics) value = rule.value_semantics[value];
                        name += ' '+rule.op+' '+value;
                    }
                    item = element('a', {id:"rule", rule:rule.id}, name);
                    if (layer.use > 1) item = element('input', attr, item);
                }
                self.elements.rules.append(item);
                rule.active = true;
                self.elements.rules.append(element('br'));
            });
        $(self.id.rules+" :checkbox").change(function() {
            // todo: send message rule activity changed
            var rule_id = $(this).attr('rule');
            var active = this.checked;
            self.model.setRuleActive(rule_id, active);
            self.model.createLayers(true);
        });
        $(self.id.rules+" #rule").click(function() {
            self.ruleSelected.notify({id:$(this).attr('rule')});
        });
    },
    siteInteraction: function(source) {
        var self = this;
        var typeSelect = self.elements.site_type[0];
        $(typeSelect).val('');
        self.elements.site_info.html('');
        function addInteraction() {
            var value = typeSelect.value;
            self.model.removeInteraction(self.draw);
            self.draw = {key:null, draw:null, source:null};
            if (value == 'Polygon') {
                var geometryFunction, maxPoints;
                self.draw.draw = new ol.interaction.Draw({
                    source: source,
                    type: value,
                    geometryFunction: geometryFunction,
                    maxPoints: maxPoints
                });
                self.model.addInteraction(self.draw);
                self.draw.draw.on('drawstart', function() {
                    source.clear();
                });
            } else if (value == 'Point') {
                self.draw.source = source;
                self.draw.key = self.model.addInteraction(self.draw);
            } else {
                source.clear();
                self.elements.site_info.html('');
            }
        }
        typeSelect.onchange = addInteraction;
        addInteraction();
    }
};

function MSP(args) {
    this.server = args.server;
    this.firstPlan = args.firstPlan;
    this.auth = args.auth;
    this.proj = null;
    this.map = null;
    this.site = null; // layer showing selected location or area
    this.plans = null;
    // selected things, i.e., where the users focus is
    this.plan = null;
    this.use = null;
    this.layer = null;
    this.rule = null;

    this.newPlans = new Event(this);
    this.planChanged = new Event(this);
    this.newLayerList = new Event(this);
    this.layerSelected = new Event(this);
    this.layerUnselected = new Event(this);
    this.ruleEdited = new Event(this);
    this.siteInitialized = new Event(this);
    this.siteInformationReceived = new Event(this);
}

MSP.prototype = {
    getPlans: function() {
        var self = this;
        self.removeLayers();
        self.removeSite();
        // the planning system is a tree: root->plans->uses->layers->rules
        $.ajax({
            url: 'http://'+self.server+'/plans',
            xhrFields: {
                withCredentials: true
            }
        }).done(function(plans) {
            self.plans = plans;
            self.newPlans.notify();
            self.changePlan(self.firstPlan);
            self.initSite();
        }).fail(function(xhr, textStatus, errorThrown) {
            var msg = "The configured SmartSea MSP server at "+self.server+" is not responding.";
            alert(msg);
        });
    },
    addPlan: function(plan) {
        var self = this;
        self.plans.unshift(plan);
        self.newPlans.notify();
        self.changePlan(plan.id);
        self.initSite();
    },
    changePlan: function(id) {
        var self = this;
        // remove extra use
        if (self.plan) {
            var newUses = [];
            for (var i = 0; i < this.plan.uses.length; ++i) {
                if (this.plan.uses[i].id > 1) // not a pseudo plan
                    newUses.push(this.plan.uses[i]);
            }
            this.plan.uses = newUses;
        }
        self.plan = null;
        self.use = null;
        self.layer = null;
        // pseudo plans, note reserved use class id's
        var datasets = {id:0, name:"Data", open:false, plan:0, layers:[]};
        var ecosystem = {id:1, name:"Ecosystem", open:false, plan:1, layers:[]};
        $.each(self.plans, function(i, plan) {
            if (id == plan.id) self.plan = plan;
        });
        if (!self.plan) {
            $.each(self.plans, function(i, plan) {
                if (plan.id > 1) {
                    self.plan = plan;
                    return false;
                }
            });
            if (!self.plan) self.plan = {id:2, name:"No plan", data:[], uses:[]};
        }
        $.each(self.plans, function(i, plan) {
            if (plan.id == 0) { // a pseudo plan Data
                $.each(plan.uses[0].layers, function(i, dataset) {
                    if (self.plan.data[dataset.id])
                        datasets.layers.push(dataset);
                });
            }
            if (plan.id == 1) { // a pseudo plan Ecosystem
                $.each(plan.uses[0].layers, function(i, component) {
                    ecosystem.layers.push(component);
                });
            }
            $.each(plan.uses, function(i, use) {
                $.each(use.layers, function(j, layer) {
                    if (layer.object) self.map.removeLayer(layer.object);
                });
            });
        });
        // add datasets and ecosystem as an extra use
        self.plan.uses.push(ecosystem);
        self.plan.uses.push(datasets);
        if (self.plan) self.planChanged.notify({ plan: self.plan });
    },
    hasUse: function(id) {
        var self = this;
        var retval = false;
        $.each(self.plan.uses, function(i, use) {
            if (use.id == id) {
                retval = true;
                return false;
            }
        });
        return retval;
    },
    createLayers: function(boot) {
        var self = this;
        self.removeSite();
        // reverse order to add to map in correct order
        $.each(self.plan.uses.reverse(), function(i, use) {
            use.index = self.plan.uses.length - 1 - i;
            $.each(use.layers.reverse(), function(j, layer) {
                layer.index = use.layers.length - 1 - j;
                if (layer.object) self.map.removeLayer(layer.object);
                if (boot) {
                    // initial boot or new plan
                    var wmts = self.plan.id + '_' + use.id + '_' + layer.id;
                    if (layer.rules.length > 0) {
                        var rules = '';
                        // add rules
                        $.each(layer.rules, function(i, rule) {
                            if (rule.active) rules += '_'+rule.id;
                        });
                        if (rules == '') rules = '_0'; // avoid no rules = all rules
                        wmts += rules;
                        // needs to be updated
                        if (layer.object) layer.object = null;
                    }
                    layer.wmts = wmts;
                }
                if (!layer.object) layer.object = createLayer(layer, self.proj);
                layer.object.on('change:visible', function () {
                    this.visible = !this.visible;
                }, layer);
                // restore visibility:
                var visible = layer.visible;
                layer.object.setVisible(visible);
                layer.visible = visible;
                self.map.addLayer(layer.object);
            });
        });
        self.newLayerList.notify();
        self.addSite();
    },
    removeLayers: function() {
        var self = this;
        if (!self.plan) return;
        $.each(self.plan.uses.reverse(), function(i, use) {
            $.each(use.layers.reverse(), function(j, layer) {
                if (layer.object) self.map.removeLayer(layer.object);
            });
        });
        self.newLayerList.notify();
    },
    setLayerOrder: function(order) {
        var newUses = [];
        for (var i = 0; i < order.length; ++i) {
            newUses.push(this.plan.uses[order[i]]);
        }
        this.plan.uses = newUses;
        this.createLayers(false);
    },
    hasLayer: function(ids) {
        var self = this;
        var retval = false;
        $.each(self.plan.uses, function(i, u) {
            if (u.id == ids.use) {
                $.each(u.layers, function(i, l) {
                    if (l.id == ids.layer) {
                        retval = true;
                        return false;
                    }
                });
                return false;
            }
        });
        return retval;
    },
    getLayer: function(ids) {
        var self = this;
        var use = null;
        var layer = null;
        $.each(self.plan.uses, function(i, u) {
            if (u.id == ids.use) {
                use = u;
                $.each(u.layers, function(i, l) {
                    if (l.id == ids.layer) {
                        layer = l;
                        return false;
                    }
                });
                return false;
            }
        });
        return {use:use, layer:layer};
    },
    selectLayer: function(ids) {
        var self = this;
        self.use = null;
        self.layer = null;
        $.each(self.plan.uses, function(i, use) {
            if (use.id == ids.use) {
                self.use = use;
                $.each(use.layers, function(i, layer) {
                    if (layer.id == ids.layer) {
                        self.layer = layer;
                        return false;
                    }
                });
                return false;
            }
        });
        if (self.layer) self.layerSelected.notify();
    },
    unselectLayer: function() {
        var self = this;
        var use = null, layer = null;
        var unselect = 0;
        if (self.use && self.layer) {
            use = self.use.id;
            layer = self.layer.id;
            unselect = 1;
        }
        self.use = null;
        self.layer = null;
        if (unselect) self.layerUnselected.notify({ use: use, layer: layer });
        return {use: use, layer: layer};
    },
    selectRule: function(id) {
        var self = this;
        self.rule = null;
        $.each(self.layer.rules, function(i, rule) {
            if (rule.id == id) {
                self.rule = rule;
                return false;
            }
        });
        return self.rule;
    },
    selectedRule: function() {
        var self = this;
        return self.rule;
    },
    setRuleActive: function(id, active) {
        var self = this;
        $.each(self.layer.rules, function(i, rule) {
            if (rule.id == id) {
                rule.active = active;
                return false;
            }
        });
    },
    modifyRule: function(object) {
        var self = this;
        self.rule.value = object.value;
        self.createLayers(true);
        self.ruleEdited.notify();
    },
    initSite: function() {
        var self = this;
        var source = new ol.source.Vector({});
        source.on('addfeature', function(evt){
            var feature = evt.feature;
            var geom = feature.getGeometry();
            var type = geom.getType();
            var query = 'plan='+self.plan.id;
            if (self.layer && self.layer.visible) query += '&use='+self.layer.use+'&layer='+self.layer.id;
            if (type == 'Polygon') {
                var format  = new ol.format.WKT();
                query += '&wkt='+format.writeGeometry(geom);
            } else if (type == 'Point') {
                var coordinates = geom.getCoordinates();
                query += '&easting='+coordinates[0]+'&northing='+coordinates[1];
            }
            query += '&srs='+self.proj.projection.getCode();
            $.ajax({
                url: 'http://'+self.server+'/explain?'+query
            }).done(function(data) {
                self.siteInformationReceived.notify(data);
            });
        });
        if (self.site) self.map.removeLayer(self.site);
        self.site = new ol.layer.Vector({
            source: source,
            style: new ol.style.Style({
                fill: new ol.style.Fill({
                    color: 'rgba(255, 255, 255, 0.2)'
                }),
                stroke: new ol.style.Stroke({
                    color: '#ffcc33',
                    width: 2
                }),
                image: new ol.style.Circle({
                    radius: 7,
                    fill: new ol.style.Fill({
                        color: '#ffcc33'
                    })
                })
            })
        });
        self.map.addLayer(self.site);
        self.siteInitialized.notify({source: source});
    },
    removeSite: function() {
        if (this.site) this.map.removeLayer(this.site);
    },
    addSite: function() {
        if (this.site) this.map.addLayer(this.site);
    },
    removeInteraction: function(draw) {
        if (draw.key) this.map.unByKey(draw.key);
        if (draw.draw) this.map.removeInteraction(draw.draw);
    },
    addInteraction: function(draw) {
        if (draw.draw) this.map.addInteraction(draw.draw);
        if (draw.source) {
            return this.map.on('click', function(evt) {
                var coordinates = evt.coordinate;
                var f = new ol.Feature({
                    geometry: new ol.geom.Point(coordinates)
                });
                var iconStyle = new ol.style.Style({
                    image: new ol.style.Icon({
                        anchor: [16, 32],
                        anchorXUnits: 'pixels',
                        anchorYUnits: 'pixels',
                        opacity: 1,
                        src: 'img/Map-Marker-Marker-Outside-Pink-icon.png'
                    })
                });
                f.setStyle(iconStyle);
                draw.source.clear();
                draw.source.addFeature(f);
            });
        }
    }
};

function Event(sender) {
    this.sender = sender;
    this.listeners = [];
}

Event.prototype = {
    attach : function(listener) {
        this.listeners.push(listener);
    },
    notify : function(args) {
        var i;
        for (i = 0; i < this.listeners.length; ++i) {
            this.listeners[i](this.sender, args);
        }
    }
};
