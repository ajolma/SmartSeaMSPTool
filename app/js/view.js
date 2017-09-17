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
/*global $, alert, ol, Event, element, Menu*/

// after https://alexatnet.com/articles/model-view-controller-mvc-javascript

function MSPView(model, elements, id) {
    var self = this;
    self.model = model;
    self.elements = elements;
    self.id = id;
    self.draw = {key: null, draw: null, source: null};
    // elements DOM elements selected with jquery $()
    // ids are jquery selectors

    self.elements.layers.sortable({
        stop: function () {
            var newOrder = [],
                ul = self.elements.layers.children(),
                i,
                n;
            for (i = 0; i < ul.length; i += 1) {
                n = ul[i].id;
                n = n.replace(/use/, '');
                newOrder.push(parseInt(n, 10));
            }
            self.model.setUseOrder(newOrder);
        }
    });

    // model event listeners

    self.model.newPlans.attach(function () {
        self.buildPlans();
    });
    self.model.planChanged.attach(function (sender, args) {
        self.elements.plans.val(args.plan.id);
        self.buildPlan();
    });
    self.model.newLayerList.attach(function () {
        self.buildLayers();
    });
    self.model.layerSelected.attach(function () {
        self.selectLayer();
        self.fillRulesPanel();
    });
    self.model.layerUnselected.attach(function (sender, args) {
        self.unselectLayer(args);
    });
    self.model.rulesChanged.attach(function () {
        self.fillRulesPanel();
    });
    self.model.ruleEdited.attach(function () {
        self.fillRulesPanel();
    });
    self.model.siteInitialized.attach(function (sender, args) {
        self.siteInteraction(args.source);
    });
    self.model.siteInformationReceived.attach(function (sender, args) {
        self.elements.site_info.html(args.report);
    });

    // events

    self.error = new Event(self);
    self.planCommand = new Event(self);
    self.useCommand = new Event(self);
    self.layerCommand = new Event(self);
    self.ruleClicked = new Event(self);

    self.elements.plans.change(function () {
        self.model.changePlan(parseInt(self.elements.plans.val(), 10));
    });
}

MSPView.prototype = {
    windowResize: function () {
        var right_width = 230, // from layout.css
            h = $(window).height() -  $('.header').height() - $('.plot').height(),
            w = $(window).width() - right_width - 15;
        this.elements.map
            .height(h)
            .width(w);
        $('.right').css('max-height', h);
        if (this.model.map) {
            this.model.map.updateSize();
        }
    },
    cleanUp: function () {
        var self = this;
        self.elements.rule_header.html('');
        self.elements.rule_info.html('');
        self.elements.site.html('');
        self.elements.legend.html('');
    },
    buildPlans: function () {
        // add plans to the plan drop down
        var self = this;
        if (self.model.user !== 'guest') {
            self.elements.user.html('Hello ' + self.model.user + '!');
        }
        self.elements.plans.html('');
        $.each(self.model.plans, function (i, plan) {
            self.elements.plans.append(element('option', {value: plan.id}, plan.name));
        });
        self.cleanUp();
    },
    buildPlan: function () {
        // activate selected plan
        var self = this,
            options,
            menu;
        if (self.model.auth) {
            options = [{cmd: 'add', label: 'Add...'}];
            if (self.model.plan.owner === self.model.user) {
                options.push({cmd: 'edit', label: 'Edit...'});
                options.push({cmd: 'delete', label: 'Delete...'});
                options.push({cmd: 'add_use', label: 'Add use...'});
            }
            menu = new Menu({
                element: self.elements.plan,
                menu: self.elements.plan_menu,
                options: options,
                select: function (cmd) {
                    self.planCommand.notify({cmd: cmd});
                }
            });
            menu.activate();
        }
        $('#plan-owner').html('Owner: ' + self.model.plan.owner);
        self.elements.rules.empty();
        self.fillRulesPanel();
    },
    layerItem: function (layer) {
        var self = this,
            attr = {type: 'checkbox', class: 'visible' + layer.id},
            id = 'layer' + layer.id,
            auth = self.model.isAuthorized({layer: layer}),
            klass = auth ? 'context-menu' : 'tree-item',
            item = element('div', {id: id, class: klass}, layer.name),
            retval = '';
        if (auth) {
            item += element('ul', {class: 'menu', id: 'menu' + layer.id, style: 'display:none'}, '');
        }
        retval = element('input', attr, item + '<br/>');
        attr = {class: 'opacity' + layer.id, type: 'range', min: '0', max: '1', step: '0.01'};
        retval += element('div', {class: 'opacity' + layer.id}, element('input', attr, '<br/>'));
        return retval;
    },
    usesItem: function (use) {
        // an openable use item for a list
        var self = this,
            auth = self.model.isAuthorized({use: use}),
            klass = auth ? 'context-menu' : 'tree-item',
            use_text = element('div', {class: klass}, use.name),
            button = use.layers.length > 0
                ? element('button', {class: 'use', type: 'button'}, '&rtrif;') + '&nbsp;'
                : '',
            use_item = button  +  use_text,
            layers = '';
        use_item = element('label', {title: 'Owner: ' + use.owner}, use_item);
        if (auth) {
            use_item += element('ul', {class: 'menu', id: 'menu', style: 'display:none'}, '');
        }
        $.each(use.layers, function (j, layer) {
            layers += self.layerItem(layer);
        });
        layers = element('div', {class: 'use'}, layers);
        return {auth: auth, element: element('li', {id: 'use' + use.id}, use_item + layers)};
    },
    buildLayerTree: function () {
        var self = this;
        $.each(self.model.plan.uses, function (i, use) {
            var selector = self.id.uses + ' #use' + use.id,
                item = self.usesItem(use),
                options = [],
                menu;
            self.elements.layers.append(item.element);

            if (!self.model.auth) {
                return true;
            }

            // attach menus
            if (item.auth) {
                if (use.id === 0) { // data
                    options.push({cmd: 'edit', label: 'Edit...'});
                } else { // use
                    options.push({cmd: 'edit', label: 'Edit...'});
                    options.push({cmd: 'delete', label: 'Delete...'});
                    options.push({cmd: 'add_layer', label: 'Add layer...'});
                }
            } else {
                if (use.id > 1) { // not data or ecosystem component
                    options.push({cmd: 'add_layer', label: 'Add layer...'});
                }
            }
            menu = new Menu({
                element: $(selector + ' label'),
                menu: $(selector + ' #menu'),
                options: options,
                select: function (cmd) {
                    self.useCommand.notify({cmd: cmd, use: use});
                }
            });
            menu.activate();

            $.each(use.layers, function (j, layer) {
                var auth = self.model.isAuthorized({layer: layer}),
                    options2 = [],
                    menu;
                if (!auth) {
                    return true;
                }
                options2.push({cmd: 'edit', label: 'Edit...'});
                if (use.id > 2) {
                    options2.push({cmd: 'delete', label: 'Delete...'});
                    options2.push([
                        {label: 'Rule'},
                        {cmd: 'add_rule', label: 'Add...'},
                        {cmd: 'delete_rule', label: 'Delete...'}
                    ]);
                }
                menu = new Menu({
                    element: $(selector + ' #layer' + layer.id),
                    menu: $(selector + ' #menu' + layer.id),
                    options: options2,
                    prelude: function () {
                        self.model.unselectLayer();
                        self.model.selectLayer({use: use.id, layer: layer.id});
                    },
                    select: function (cmd) {
                        self.layerCommand.notify({cmd: cmd, use: use, layer: layer});
                    }
                });
                menu.activate();
            });
        });
    },
    buildLayers: function () {
        // an openable list of use items
        var self = this;
        self.elements.layers.html('');
        self.buildLayerTree();
        self.selectLayer(); // restore selected layer

        // attach controllers:
        $.each(self.model.plan.uses, function (i, use) {
            var selector = self.id.uses + ' #use' + use.id,
                useButton = $(selector + ' button.use');

            // edit use
            $(selector + ' button.edit').click(function () {
                self.editUse.notify(use);
            });

            // open and close a use item
            useButton.on('click', null, {use: use}, function (event) {
                $(self.id.uses + ' #use' + event.data.use.id + ' div.use').toggle();
                if (!this.flipflop) {
                    this.flipflop = 1;
                    $(this).html('&dtrif;');
                    event.data.use.open = true;
                } else {
                    this.flipflop = 0;
                    $(this).html('&rtrif;');
                    event.data.use.open = false;
                }
            });
            $(selector + ' div.use').hide();

            // show/hide layer and set its transparency
            $.each(use.layers, function (j, layer) {
                // select and unselect a layer
                $('#use' + use.id + ' #layer' + layer.id).click(function () {
                    var layer2 = self.model.unselectLayer();
                    if (!layer2 || !(layer2.id === layer.id && layer2.use.class_id === layer.use.class_id)) {
                        self.model.selectLayer({use: use.id, layer: layer.id});
                    }
                });
                // show/hide layer
                var cb = $(selector + ' input.visible' + layer.id),
                    slider = $(selector + ' input.opacity' + layer.id);
                cb.change({use: use, layer: layer}, function (event) {
                    $(self.id.uses + ' #use' + event.data.use.id + ' div.opacity' + event.data.layer.id).toggle();
                    event.data.layer.setVisible(this.checked);
                    if (this.checked) {
                        self.model.unselectLayer();
                        self.model.selectLayer({use: event.data.use.id, layer: event.data.layer.id});
                    }
                    if (self.model.layer) {
                        self.elements.site.html(self.model.layer.name);
                    } else {
                        self.elements.site.html('');
                    }
                });
                if (layer.visible) {
                    cb.prop('checked', true);
                } else {
                    $(selector + ' div.opacity' + layer.id).hide();
                }
                slider.on('input change', null, {layer: layer}, function (event) {
                    event.data.layer.setOpacity(parseFloat(this.value));
                });
                slider.val(String(layer.getOpacity()));
            });

            // restore openness of use
            if (use.hasOwnProperty('open') && use.open) {
                use.open = true;
                useButton.trigger('click');  // triggers useButton.on('click'... above
            } else {
                use.open = false;
            }
        });

        self.cleanUp();
    },
    selectLayer: function () {
        var self = this,
            layer = self.model.layer,
            url = self.model.protocol + '://' + self.model.server,
            style = '',
            cache_breaker = '&time=' + new Date().getTime(),
            layer_info = layer ? layer.info() : null;

        // hilite a layer, get its legend and show info about rules
        if (!layer) {
            return;
        }
        $('#use' + layer.use.id + ' #layer' + layer.id).css('background-color', 'yellow');
        /*
        if (layer.style.palette) {
            style = '&palette=' + layer.palette;
        }
        if (layer.scale_min !== null) {
            style = '&min=' + layer.scale_min;
        }
        */
        self.elements.legend.html(
            element('img', {src: url + '/legend?layer=' + layer.getName() + style + cache_breaker}, '')
        );

        self.elements.rule_header.html(layer_info.header);
        self.elements.rule_info.html(layer_info.body);

        if (layer.visible) {
            self.elements.site.html(layer.name);
        }
    },
    unselectLayer: function (layer) {
        $('#use' + layer.use.id + ' #layer' + layer.id).css('background-color', 'white');
        this.elements.rule_header.html('');
        this.elements.rule_info.html('');
        this.elements.legend.html('');
        this.elements.rules.empty();
        this.elements.site.html('');
    },
    fillRulesPanel: function () {
        var self = this;
        self.elements.rules.empty();
        if (!self.model.layer) {
            return;
        }
        if (self.model.layer.descr) {
            self.elements.rules.append(self.model.layer.descr);
        } else if (self.model.layer.rules) {
            $.each(self.model.layer.rules, function (i, rule) {
                var name = rule.getName(),
                    item,
                    attr = {
                        type: 'checkbox',
                        layer:  self.model.layer.id,
                        rule: rule.id
                    };
                if (rule.active) {
                    attr.checked = 'checked';
                }
                item = element('a', {id: 'rule', rule: rule.id}, name);
                if (self.model.layer.use.class_id > 1) {
                    item = element('input', attr, item);
                }
                self.elements.rules.append(item);
                self.elements.rules.append(element('br'));
            });
        }
        $(self.id.rules + ' :checkbox').change(function () {
            // send message rule activity changed?
            var rule_id = parseInt($(this).attr('rule'), 10),
                active = this.checked;
            self.model.layer.setRuleActive(rule_id, active);
        });
        $(self.id.rules + ' #rule').click(function () {
            self.ruleClicked.notify({id: parseInt($(this).attr('rule'), 10)});
        });
    },
    siteInteraction: function (source) {
        var self = this,
            typeSelect = self.elements.site_type[0];
        $(typeSelect).val('');
        self.elements.site_info.html('');
        typeSelect.onchange = (function addInteraction() {
            var value = typeSelect.value;
            self.model.removeInteraction(self.draw);
            self.draw = {key: null, draw: null, source: null};
            if (value === 'Polygon') {
                self.draw.draw = new ol.interaction.Draw({
                    source: source,
                    type: value
                });
                self.model.addInteraction(self.draw);
                self.draw.draw.on('drawstart', function () {
                    source.clear();
                });
            } else if (value === 'Point') {
                self.draw.source = source;
                self.draw.key = self.model.addInteraction(self.draw);
            } else {
                source.clear();
                self.elements.site_info.html('');
            }
            return addInteraction;
        }());
    }
};
