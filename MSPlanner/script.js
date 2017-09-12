"use strict";

/*global $, ol, XMLSerializer, btoa, Chart, PlannerMaps, WFSEditor*/

var config_url = window.location.href.replace(/planner-app[\w\W]*/, 'config'),
    chart = function (options, config) {
        var table = options.layer === 'left' ? 'wfs' : 'wfs2',
            parameters = 'table=' + table,
            url = config.protocol + '://' + config.server + '/planner?' + parameters;
        if (options.layer === 'left') {
            parameters += '&username=' + config.user;
        }
        $.ajax(url, {
            type: 'GET',
        }).done(function (data) {
            var ctx = $('#' + options.layer + "Chart")[0].getContext('2d'),
                chart = new Chart(ctx, data);
        });
    };


$.ajax(config_url, {
    type: 'GET',
}).done(function (config) {
    
    var plannerMaps = new PlannerMaps({
        chart: chart,
        config: config
    }),
        editor = new WFSEditor({
            chart: chart,
            config: config,
            map: plannerMaps.getMap('left'),
            layer: plannerMaps.getLayer('left'),
        });
    
});
