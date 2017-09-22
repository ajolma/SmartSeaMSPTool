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

/*global $, alert, ol, element, Config, Menu, MSPModel, MSPView, MSPController*/

(function () {
    var config = new Config({
        bootstrap: function () {
            var map = new ol.Map({
                    layers: [],
                    target: 'map',
                    controls: ol.control.defaults().extend([
                        new ol.control.FullScreen()
                    ]),
                    view: config.proj.view
                }),
                model = new MSPModel({
                    config: config,
                    map: map,
                    firstPlan: 30
                }),
                view = new MSPView(model, {
                    map: $('#map'),
                    user: $('#user'),
                    plan: $('#plan'),
                    plan_menu: $('#plan-menu'),
                    plans: $('#plans'),
                    layers: $('#layers'),
                    rule_header: $('#rule-header'),
                    rule_info: $('#rule-info'),
                    rules: $('#rules'),
                    site: $('#explain-site'),
                    site_type: $('#site-type'),
                    site_info: $('#site-info'),
                    legend: $('#legend')
                },{
                    uses: '#useslist',
                    rules: '#rules'
                }),
                controller = new MSPController(model, view),
                sourceSwap = function () {
                    var $this = $(this),
                        newSource = $this.data('hilite-src');
                    $this.data('hilite-src', $this.attr('src'));
                    $this.attr('src', newSource);
                };
            
            map.addControl(new ol.control.ScaleLine());

            $.each(config.bg, function (i, bg) {
                bg.layer.setVisible(false);
                map.addLayer(bg.layer);
                $('#bg-map').append(element('option', {value: i}, bg.title));
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
                    var options = [{cmd: 'boot', label: 'Boot'}],
                        menu = new Menu({
                            element: $('#main-menu'),
                            menu: $('#main-menu-ul'),
                            right: 24,
                            options: options,
                            select: function () { // cmd
                                controller.loadPlans();
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
