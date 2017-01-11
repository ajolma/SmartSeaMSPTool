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

(function() {
    $('body').addClass('stop-scrolling');
    var model = new MSP(server, 3);
    var view = new MSPView(model, {
        map: $("#map"),
        plans: $("#plans"),
        layers: $("#layers"),
        rule_info: $("#rule-info"),
        rules: $("#rules"),
        rule_dialog: $("#rule-dialog"),
        site_type: $('#site-type'),
        site_info: $('#site-info')
    }, {
        rules: "#rules",
        rule_dialog: "#rule-dialog"
    });
    var controller = new MSPController(model, view);
        
    model.proj = projection(config);

    model.map = new ol.Map({
        layers: [],
        target: 'map',
        controls: ol.control.defaults({
            attributionOptions:{
                collapsible: false
            }
        }),
        view: model.proj.view
    });
    model.map.addControl(new ol.control.ScaleLine());
    $.each(createLayer({bg: config.bg}, model.proj), function(i, layer) {
        model.map.addLayer(layer);
    });

    model.getPlans();

    $(window).resize(function(){view.windowResize()});
    view.windowResize();
    return;

    // from http://jsfiddle.net/kCduV/10/
    $('.right').resizable({
        handles       : 'e,w', 
        resize        : function (event,ui){
            ui.position.left = ui.originalPosition.left;
            ui.size.width    = ( ui.size.width
                                 - ui.originalSize.width )*2
        }
    });

}());
