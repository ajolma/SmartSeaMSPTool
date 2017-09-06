"use strict";

/*global $, ol, XMLSerializer, btoa, Chart, PlannerMaps, WFSEditor*/

var chart = function (options) {
    var table = options.layer === 'left' ? 'wfs' : 'wfs2',
        parameters = 'table=' + table;
    if (options.layer === 'left') {
        parameters += '&username=' + options.username;
    }
    $.ajax('https://msp.smartsea.fmi.fi/PlanningServer?' + parameters, {
        type: 'GET',
    }).done(function (data) {
        var ctx = $('#' + options.layer + "Chart")[0].getContext('2d'),
            chart = new Chart(ctx, data);
    });
};

$.ajax('https://msp.smartsea.fmi.fi/Starman/auth/config', {
    type: 'GET',
}).done(function (config) {

    var plannerMaps = new PlannerMaps({
        chart: chart,
        username: config.user,
    }),
        editor = new WFSEditor({
            chart: chart,
            username: config.user,
            wfs_password: config.wfs_passwd,
            map: plannerMaps.getMap('left'),
            layer: plannerMaps.getLayer('left'),
        });

});
