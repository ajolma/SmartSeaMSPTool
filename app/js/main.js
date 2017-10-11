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

/*global $, ol, msp*/

(function () {
    var sheet = msp.find(document.styleSheets, 'href', /layout.css/),
        rules = sheet.rules || sheet.cssRules,
        right = msp.find(rules, 'selectorText', /^\.right/),
        config,
        about = function (model, controller) {
            var lang = msp.lang === 'fi' ? 'fi' : 'en';
            $.ajax({
                url: model.serverURL() + '/html/about.' + lang + '.html',
                success: function (result) {
                    controller.setEditor({
                        title: '',
                        html: result,
                        buttons: 'close'
                    });
                    controller.editor.dialog('open');
                },
                fail: function (xhr, textStatus) {
                    controller.error(xhr.responseText || textStatus);
                }
            });
        };
    msp.layoutRightWidth = parseInt(/(\d+)/.exec(right.style.width)[0], 10);
    if (navigator.languages) {
        msp.lang = navigator.languages[0];
    } else if (navigator.language || navigator.userLanguage) {
        msp.lang = navigator.language || navigator.userLanguage;
    }
    if (msp.lang) {
        msp.lang = msp.lang.match(/^(\w+)/);
        if (msp.lang) {
            msp.lang = msp.lang[0];
        } else {
            msp.lang = '';
        }
    }
    if (msp.lang === 'fi') {
        $('#plan-title').html('Suunnitelma');
        $('#use-title').html('Alueiden käyttö');
        $('#bg-title').html('Taustakartta');
        $('#layer-title').html('Valittu taso');
        $('#query-tool-title').html('Kyselytyökalu');
        $('#legend-title').html('Legenda');
    } else {
        $('#plan-title').html('Plan');
        $('#use-title').html('Uses');
        $('#bg-title').html('Background map');
        $('#layer-title').html('Selected layer');
        $('#query-tool-title').html('Query tool');
        $('#legend-title').html('Legend');
    }
    config = new msp.Config({
        bootstrap: function () {
            var map = new ol.Map({
                    layers: [],
                    target: 'map',
                    controls: ol.control.defaults().extend([
                        new ol.control.FullScreen()
                    ]),
                    view: config.proj.view
                }),
                model = new msp.Model({
                    config: config,
                    map: map,
                    firstPlan: 30
                }),
                view = new msp.View({
                    model: model,
                    elements: {
                        map: $('#map'),
                        user: $('#user'),
                        plans: $('#plans'),
                        uses: $('#uses-list'),
                        layer_info: $('#layer-info'),
                        rules: $('#rules'),
                        query_tool: $('#query-tool'),
                        query_result: $('#query-result'),
                        legend: $('#legend')
                    },
                    selectors: {
                        uses: '#uses',
                        rules: '#rules'
                    }
                }),
                editor = new msp.Editor({
                    selector: '#editor',
                    config: config,
                    model: model,
                    view: view
                }),
                controller = new msp.Controller({
                    model: model,
                    view: view,
                    dialog: 'dialog'
                }),
                sourceSwap = function () {
                    var $this = $(this),
                        newSource = $this.data('hilite-src');
                    $this.data('hilite-src', $this.attr('src'));
                    $this.attr('src', newSource);
                };

            if (model.config.config.about) {
                about(model, controller);
            }
                        
            map.addControl(new ol.control.ScaleLine());

            $.each(config.bg, function (i, bg) {
                bg.layer.setVisible(false);
                map.addLayer(bg.layer);
                $('#bg-map').append(msp.e('option', {value: i}, bg.title));
            });
            config.base = config.bg[0].layer;
            config.base.setVisible(true);
            $('#bg-map').change(function () {
                config.base.setVisible(false);
                config.base = config.bg[parseInt($('#bg-map').val(), 10)].layer;
                config.base.setVisible(true);
            });
            
            $('#reload').click((function reload() {
                controller.loadPlans();
                return reload;
            }()));
            
            $(window).resize(function () {
                view.windowResize();
            });
            view.windowResize();

            $(function () {
                $('img.main-menu').hover(sourceSwap, sourceSwap);
                $('img.main-menu').click(function (event) {
                    var options = [
                            {label: 'Boot', cmd: 'boot'},
                            {label: 'Editor...', cmd: 'editor'},
                            {label: 'About...', cmd: 'about'},
                        ],
                        menu = new msp.Menu({
                            element: $('#main-menu'),
                            menu: $('#main-menu-ul'),
                            right: 24,
                            options: options,
                            select: function (cmd) { // cmd
                                if (cmd === 'boot') {
                                    controller.loadPlans();
                                } else if (cmd === 'editor') {
                                    if (model.layer) {
                                        editor.open({active_tab: 'rules'});
                                    } else {
                                        editor.open({active_tab: 'uses'});
                                    }
                                } else if (cmd === 'about') {
                                    about(model, controller);
                                }
                            },
                            event: event
                        });
                    menu.activate();
                    return false;
                });
            });
            
        }
    }); 
    
    $('body').addClass('stop-scrolling');
    $('.menu').hide();
    $(document).click(function (e) {
        if ($('.menu').has(e.target).length === 0) {
            $('.menu').hide();
        }
    });

}());
