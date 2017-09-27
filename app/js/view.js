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
/*global $, alert, ol, msp*/

// after https://alexatnet.com/articles/model-view-controller-mvc-javascript

/**
 * A singleton for maintaining the GUI.
 * @constructor
 * @param {MSPModel} model - Model.
 * @param {ViewElements} elements - jQuery objects representing some GUI elements.
 * @param {ViewIds} ids - Selectors for some GUI elements.
 */
msp.View = function (options) {
    var self = this;
    self.model = options.model;
    self.elements = options.elements;
    self.selectors = options.selectors;
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

    self.error = new msp.Event(self);
    self.planCommand = new msp.Event(self);
    self.useCommand = new msp.Event(self);
    self.layerCommand = new msp.Event(self);
    self.ruleCommand = new msp.Event(self);

    self.elements.plans.change(function () {
        self.model.changePlan(parseInt(self.elements.plans.val(), 10));
    });
};

msp.View.prototype = {
    /**
     * React to the browser window resize event.
     */
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
    /**
     * Clean up the GUI after deselecting a layer.
     */
    cleanUp: function () {
        var self = this;
        self.elements.rule_header.html('');
        self.elements.rule_info.html('');
        self.elements.site.html('');
        self.elements.legend.html('');
    },
    /**
     * Update the list of available plans.
     */
    buildPlans: function () {
        var self = this;
        if (self.model.config.config.user !== 'guest') {
            self.elements.user.html('Hello ' + self.model.config.config.user + '!');
        }
        self.elements.plans.html('');
        $.each(self.model.plans, function (i, plan) {
            self.elements.plans.append(msp.e('option', {value: plan.id}, plan.name));
        });
        self.cleanUp();
    },
    buildPlan: function () {
        var self = this;
        $('#plan-owner').html('Owner: ' + self.model.plan.owner);
        self.elements.rules.empty();
        self.fillRulesPanel();
    },
    layerItem: function (layer) {
        var attr = {type: 'checkbox', class: 'visible' + layer.id},
            id = 'layer' + layer.id,
            item = msp.e('div', {id: id, class: 'tree-item'}, layer.name),
            retval = '';
        retval = msp.e('input', attr, item + '<br/>');
        attr = {class: 'opacity' + layer.id, type: 'range', min: '0', max: '1', step: '0.01'};
        retval += msp.e('div', {class: 'opacity' + layer.id}, msp.e('input', attr, '<br/>'));
        return retval;
    },
    usesItem: function (use) {
        // an openable use item for a list
        var self = this,
            use_text = msp.e('div', {class: 'tree-item'}, use.name),
            button = use.layers.length > 0
                ? msp.e('button', {class: 'use', type: 'button'}, '&rtrif;') + '&nbsp;'
                : '',
            use_item = button  +  use_text,
            layers = '';
        use_item = msp.e('label', {title: 'Owner: ' + use.owner}, use_item);
        $.each(use.layers, function (j, layer) {
            layers += self.layerItem(layer);
        });
        layers = msp.e('div', {class: 'use'}, layers);
        return {element: msp.e('li', {id: 'use' + use.id}, use_item + layers)};
    },
    buildLayerTree: function () {
        var self = this;
        $.each(self.model.plan.uses, function (i, use) {
            var item = self.usesItem(use);
            self.elements.layers.append(item.element);
        });
    },
    /**
     * Build the list of uses with layers for the selected plan.
     */
    buildLayers: function () {
        // an openable list of use items
        var self = this;
        self.elements.layers.html('');
        self.buildLayerTree();
        self.selectLayer(); // restore selected layer

        // attach controllers:
        $.each(self.model.plan.uses, function (i, use) {
            var selector = self.selectors.uses + ' #use' + use.id,
                useButton = $(selector + ' button.use');

            // edit use
            $(selector + ' button.edit').click(function () {
                self.editUse.notify(use);
            });

            // open and close a use item
            useButton.on('click', null, {use: use}, function (event) {
                self.toggleUse(event.data.use);
                
            });
            $(selector + ' div.use').hide();

            // show/hide layer and set its transparency
            $.each(use.layers, function (j, layer) {
                // select and unselect a layer
                $('#use' + use.id + ' #layer' + layer.id).click(function () {
                    var layer2 = self.model.unselectLayer();
                    if (!layer2 || !(layer2.id === layer.id && layer2.use.class_id === layer.use.class_id)) {
                        self.model.selectLayer(layer);
                    }
                });
                // show/hide layer
                var cb = $(selector + ' input.visible' + layer.id),
                    slider = $(selector + ' input.opacity' + layer.id);
                cb.change({use: use, layer: layer}, function (event) {
                    $(self.selectors.uses + ' #use' + event.data.use.id + ' div.opacity' + event.data.layer.id).toggle();
                    event.data.layer.setVisible(this.checked);
                    if (this.checked) {
                        self.model.unselectLayer();
                        self.model.selectLayer(event.data.layer);
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
            if (use.open) {
                use.open = false;
                self.openUse(use);
            }
        });

        self.cleanUp();
    },
    closeUse: function (use) {
        var self = this,
            button = $(self.selectors.uses + ' #use' + use.id + ' button');
        if (!use || !use.open) {
            return;
        }
        $(self.selectors.uses + ' #use' + use.id + ' div.use').toggle();
        $(button).html('&rtrif;');
        use.open = false;
    },
    openUse: function (use) {
        var self = this,
            button = $(self.selectors.uses + ' #use' + use.id + ' button');
        if (!use || use.open) {
            return;
        }
        $(self.selectors.uses + ' #use' + use.id + ' div.use').toggle();
        $(button).html('&dtrif;');
        use.open = true;
    },
    toggleUse: function (use) {
        var self = this,
            button = $(self.selectors.uses + ' #use' + use.id + ' button');
        if (!use) {
            return;
        }
        $(self.selectors.uses + ' #use' + use.id + ' div.use').toggle();
        if (!use.open) {
            $(button).html('&dtrif;');
            use.open = true;
        } else {
            $(button).html('&rtrif;');
            use.open = false;
        }
    },
    /**
     * Build the GUI for a selected layer.
     */
    selectLayer: function () {
        var self = this,
            layer = self.model.layer,
            url = self.model.serverURL(),
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
            msp.e('img', {src: url + '/legend?layer=' + layer.getName() + style + cache_breaker}, '')
        );

        self.elements.rule_header.html(layer_info.header);
        self.elements.rule_info.html(layer_info.body);

        if (layer.visible) {
            self.elements.site.html(layer.name);
        }
    },
    /**
     * Clean up after a layer is deselected.
     */
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
                item = msp.e('a', {id: 'rule', rule: rule.id}, name);
                if (self.model.layer.use.class_id > 1) {
                    item = msp.e('input', attr, item);
                }
                self.elements.rules.append(item);
                self.elements.rules.append(msp.e('br'));
            });
        }
        $(self.selectors.rules + ' :checkbox').change(function () {
            // send message rule activity changed?
            var rule_id = parseInt($(this).attr('rule'), 10),
                active = this.checked;
            self.model.layer.setRuleActive(rule_id, active);
        });
        $(self.selectors.rules + ' #rule').click(function () {
            var id = parseInt($(this).attr('rule'), 10),
                rule = self.model.getRule(id);
            self.ruleCommand.notify({
                cmd: 'edit',
                plan: self.model.plan,
                layer: self.model.layer,
                rule: rule
            });
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
