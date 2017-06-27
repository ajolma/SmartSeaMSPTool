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

function MSPView(model, elements, id) {
    var self = this;
    self.model = model;
    self.elements = elements;
    self.id = id;
    self.draw = {key:null, draw:null, source:null};
    // elements DOM elements selected with jquery $()
    // ids are jquery selectors

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
            self.model.setUseOrder(newOrder);
        }
    });

    // model event listeners
    
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

    // events
    
    self.planCommand = new Event(self);
    self.useCommand = new Event(self);
    self.layerCommand = new Event(self);
    self.ruleSelected = new Event(self);

    self.elements.plans.change(function(e) {
        self.model.changePlan(self.elements.plans.val());
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
    cleanUp: function() {
        var self = this;
        self.elements.rule_header.html('');
        self.elements.rule_info.html('');
        self.elements.site.html('');
        self.elements.color_scale.html('');
    },
    buildPlans: function() {
        // add plans to the plan drop down
        var self = this;
        if (user != 'guest') self.elements.user.html('Hello '+user+'!');
        self.elements.plans.html('');
        $.each(self.model.plans, function(i, plan) {
            if (plan.id > 1) // not Ecosystem and Data, which are 'pseudo plans'
                self.elements.plans.append(element('option',{value:plan.id},plan.name));
        });
        self.cleanUp();
    },
    buildPlan: function(plan) {
        // activate selected plan
        var self = this;
        if (self.model.auth) {
            var options = [{cmd:'add', label:'Add...'}];
            if (self.model.plan.owner == user) {
                options.push({cmd:'edit', label:'Edit...'});
                options.push({cmd:'delete', label:'Delete...'});
                options.push({cmd:'add_use', label:'Add use...'});
            }    
            makeMenu({
                element: self.elements.plan,
                menu: self.elements.plan_menu,
                options: options,
                select: function(cmd) {
                    self.planCommand.notify({cmd: cmd});
                }
            });
        }
        self.elements.rules.empty();
        self.fillRulesPanel();
    },
    usesItem: function(use) {
        // an openable use item for a list
        var self = this;
        var use_item = element('button', {class:'use', type:'button'}, '&rtrif;') + '&nbsp;' + use.name;
        var layers = '';
        use_item = element('label', {title:use.name}, use_item);
        if (self.model.auth && use.owner == user) {
            use_item += element('ul', {class:'menu', id:"menu", style:'display:none'}, '');
        }
        $.each(use.layers.reverse(), function(j, layer) {
            var attr = {type: 'checkbox', class: 'visible'+layer.id};
            var id = 'layer'+layer.id;
            var name = layer.name;
            var lt = element('div', {id:id, style:'display:inline;'}, name);
            if (self.model.auth && layer.owner == user) {
                lt += element('ul', {class:'menu', id:"menu"+layer.id, style:'display:none'}, '');
            }
            layers += element('input', attr, lt+'<br/>');
            attr = {class:'opacity'+layer.id, type:'range', min:'0', max:'1', step:'0.01'};
            layers += element('div', {class:'opacity'+layer.id}, element('input', attr, '<br/>'));
        });
        layers = element('div', {class:'use'}, layers);
        return {element: element('li', {id:'use'+use.id}, use_item + layers)};
    },
    buildLayers: function() {
        // an openable list of use items
        var self = this;
        self.elements.layers.html('');
        // all uses with controls: on/off, select/unselect, transparency
        // end to beginning to maintain overlay order
        $.each(self.model.plan.uses.reverse(), function(i, use) {
            var selector = self.id.uses+" #use"+use.id;
            var item = self.usesItem(use);
            self.elements.layers.append(item.element);
            if (self.model.auth && use.owner == user) {
                var options = [];
                if (use.id == 1) {
                    options.push({cmd:'edit', label:'Edit...'});
                }
                if (use.id > 1) {
                    options.push({cmd:'delete', label:'Delete...'});
                    options.push({cmd:'add_layer', label:'Add layer...'});
                }
                makeMenu({
                    element: $(selector+" label"),
                    menu: $(selector+" #menu"),
                    options: options,
                    select: function(cmd) {
                        self.useCommand.notify({cmd:cmd, use:use});
                    }
                });
                $.each(use.layers, function(j, layer) {
                    if (use.id < 2) return true;
                    var options = [];
                    options.push({cmd:'edit', label:'Edit...'});
                    options.push({cmd:'delete', label:'Delete...'});
                    options.push([{label:'Rule'},
                                  {cmd:'add_rule', label:'Add...'},
                                  {cmd:'delete_rule', label:'Delete...'}]);
                    makeMenu({
                        element: $(selector+" #layer"+layer.id),
                        menu: $(selector+" #menu"+layer.id),
                        options: options,
                        select: function(cmd) {
                            self.layerCommand.notify({cmd:cmd, layer:layer});
                        }
                    });
                });
            }
            $.each(use.layers, function(j, layer) {
                $("#layer"+layer.id).click(function() {
                    var layer2 = self.model.unselectLayer();
                    if (!layer2 || layer2.id != layer.id)
                        self.model.selectLayer(layer.id);
                });
            });
        });
        self.selectLayer(); // restore selected layer
        $.each(self.model.plan.uses, function(i, use) {
            var selector = self.id.uses+" #use"+use.id;
            // edit use
            $(selector+' button.edit').click(function() {
                self.editUse.notify(use);
            });
            // open and close a use item
            var useButton = $(selector+' button.use');
            useButton.on('click', null, {use:use}, function(event) {
                $(self.id.uses+" #use"+event.data.use.id+' div.use').toggle();
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
            $(selector+' div.use').hide();
            // show/hide layer and set its transparency
            $.each(use.layers, function(j, layer) {
                // show/hide layer
                var cb = $(selector+' input.visible'+layer.id);
                cb.change({use:use, layer:layer}, function(event) {
                    $(self.id.uses+" #use"+event.data.use.id+' div.opacity'+event.data.layer.id).toggle();
                    event.data.layer.object.setVisible(this.checked);
                    if (this.checked) {
                        self.model.unselectLayer();
                        self.model.selectLayer(event.data.layer.id);
                    }
                    if (self.model.layer)
                        self.elements.site.html(self.model.layer.name);
                    else
                        self.elements.site.html('');
                });
                var slider = $(selector+' input.opacity'+layer.id);
                if (layer.visible) {
                    cb.prop('checked', true);
                } else {
                    $(selector+' div.opacity'+layer.id).hide();
                }
                slider.on('input change', null, {layer:layer}, function(event) {
                    event.data.layer.object.setOpacity(parseFloat(this.value));
                });
                slider.val(String(layer.object.getOpacity()));
            });
            if (use.hasOwnProperty('open') && use.open) {
                // restore openness of use
                use.open = true;
                useButton.trigger('click');  // triggers useButton.on('click'... above
            } else {
                use.open = false;
            }
        });
        self.cleanUp();
    },
    selectLayer: function() {
        // hilite a layer, get its legend and show info about rules
        if (!this.model.layer) return;
        var plan = this.model.plan;
        var layer = this.model.layer;
        $('#layer'+layer.id).css('background-color','yellow');
        var url = 'http://'+server+'/legend';
        var cache_breaker = '&time='+new Date().getTime();
        this.elements.color_scale.html(
            element('img',{src:url+'?layer='+layer.use_class_id+'_'+layer.id+cache_breaker},'')
        );
        if (layer.use_class_id == 0) { // Data
            this.elements.rule_header.html('Information about dataset:');
            this.elements.rule_info.html(layer.provenance);
        } else {
            this.elements.rule_header.html('Rules for layer:');
            if (layer.rule_class == 'exclusive') 
                this.elements.rule_info.html('Default is YES, rules subtract.');
            else if (layer.rule_class == 'inclusive') 
                this.elements.rule_info.html('Default is NO, rules add.');
            else if (layer.rule_class == 'multiplicative') 
                this.elements.rule_info.html('Value is a product of rules.');
            else if (layer.rule_class == 'inclusive') 
                this.elements.rule_info.html('Value is a sum of rules.');
        }
        if (layer.visible) {
            this.elements.site.html(layer.name);
        }
    },
    unselectLayer: function(layer) {
        $('#layer'+layer.id).css('background-color','white');
        this.elements.rule_header.html('');
        this.elements.rule_info.html('');
        this.elements.color_scale.html('');
        this.elements.rules.empty();
        this.elements.site.html('');
    },
    fillRulesPanel: function(layer) {
        var self = this;
        self.elements.rules.empty();
        var layer = self.model.layer;
        if (!layer) return;
        if (layer.descr)
            self.elements.rules.append(layer.descr);
        else if (layer.rules)
            $.each(layer.rules, function(i, rule) {
                var item;
                if (layer.name == 'Value')
                    item = rule.name;
                else {
                    var attr = {
                        type:'checkbox',
                        layer: layer.id,
                        rule:rule.id
                    };
                    if (rule.active) attr.checked = 'checked';
                    var name = rule.name;
                    if (!rule.binary) {
                        var value = rule.value;
                        if (rule.value_semantics) value = rule.value_semantics[value];
                        name += ' '+rule.op+' '+value;
                    }
                    item = element('a', {id:'rule', rule:rule.id}, name);
                    if (layer.use_class_id > 1) item = element('input', attr, item);
                }
                self.elements.rules.append(item);
                rule.active = true;
                self.elements.rules.append(element('br'));
            });
        $(self.id.rules+' :checkbox').change(function() {
            // todo: send message rule activity changed
            var rule_id = $(this).attr('rule');
            var active = this.checked;
            self.model.setRuleActive(rule_id, active);
            self.model.createLayers(true);
        });
        $(self.id.rules+' #rule').click(function() {
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
