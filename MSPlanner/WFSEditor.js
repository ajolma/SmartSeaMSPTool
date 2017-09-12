"use strict";

/*global $, ol, XMLSerializer, btoa*/

function WFSEditor(options) {
    var self = this;

    self.chart = options.chart;
    self.layer = options.layer;
    self.map = options.map;
    self.config = options.config;

    self.formatWFS = new ol.format.WFS();

    self.formatGML = new ol.format.GML({
        featureNS: self.config.wfs_feature_ns,
        featureType: self.config.wfs_user_type,
        srsName: 'EPSG:3857'
    });

    self.xs = new XMLSerializer();

    self.selectedButton = null;

    self.interaction = null;

    self.interactionSnap = new ol.interaction.Snap({
        source: self.layer.getSource()
    });

    self.interactionSelect = new ol.interaction.Select({
        style: new ol.style.Style({
            stroke: new ol.style.Stroke({
                color: '#FF2828'
            })
        })
    });

    self.interactionSelectPointerMove = new ol.interaction.Select({
        condition: ol.events.condition.pointerMove
    });

    self.dirty = {};

    $('button').click(function () {
        self.action($(this));
    });

}

WFSEditor.prototype = {
    action: function (button) {
        var self = this,
            use;

        button.siblings().removeClass('btn-active');
        button.addClass('btn-active');

        self.map.removeInteraction(self.interaction);
        self.interactionSelect.getFeatures().clear();
        self.map.removeInteraction(self.interactionSelect);
        self.map.removeInteraction(self.interactionSnap);

        if (self.selectedButton === button.attr('id')) {
            button.removeClass('btn-active');
            self.selectedButton = null;
            return;
        }
        self.selectedButton = button.attr('id');

        switch (self.selectedButton) {

        case 'btnEdit':
            self.map.addInteraction(self.interactionSelect);
            self.interaction = new ol.interaction.Modify({
                features: self.interactionSelect.getFeatures()
            });
            self.map.addInteraction(self.interaction);
            self.map.addInteraction(self.interactionSnap);
            self.dirty = {};
            self.interactionSelect.getFeatures().on('add', function (e) {
                e.element.on('change', function (e) {
                    self.dirty[e.target.getId()] = true;
                });
            });
            self.interactionSelect.getFeatures().on('remove', function (e) {
                var f = e.element,
                    featureProperties,
                    clone;
                if (self.dirty[f.getId()]) {
                    delete self.dirty[f.getId()];
                    featureProperties = f.getProperties();
                    delete featureProperties.boundedBy;
                    clone = new ol.Feature(featureProperties);
                    clone.setId(f.getId());
                    self.transactWFS('update', clone);
                }
            });
            break;

        case 'btnDelete':
            self.interaction = new ol.interaction.Select();
            self.interaction.getFeatures().on('add', function (e) {
                self.transactWFS('delete', e.target.item(0));
                self.interactionSelectPointerMove.getFeatures().clear();
                self.interaction.getFeatures().clear();
            });
            self.map.addInteraction(self.interaction);
            break;

        case 'btnArea1':
        case 'btnArea2':
        case 'btnArea3':
            switch (self.selectedButton) {
            case 'btnArea1':
                use = 1;
                break;
            case 'btnArea2':
                use = 2;
                break;
            case 'btnArea3':
                use = 3;
                break;
            }
            self.interaction = new ol.interaction.Draw({
                type: 'Polygon',
                source: self.layer.getSource()
            });
            self.interaction.on('drawend', function (e) {
                e.feature.set('use', use);
                e.feature.set('username', self.config.user);
                self.transactWFS('insert', e.feature);
            });
            self.map.addInteraction(self.interaction);
            break;

        default:
            break;
        }
    },
    transactWFS: function (mode, f) {
        var self = this,
            node,
            url = self.config.protocol + '://' + self.config.wfs_server,
            payload;
        switch (mode) {
        case 'insert':
            node = self.formatWFS.writeTransaction([f], null, null, self.formatGML);
            break;
        case 'update':
            node = self.formatWFS.writeTransaction(null, [f], null, self.formatGML);
            break;
        case 'delete':
            node = self.formatWFS.writeTransaction(null, null, [f], self.formatGML);
            break;
        }
        payload = self.xs.serializeToString(node);
        $.ajax(url, {
            beforeSend: function (xhr) {
                var auth = self.config.wfs_username + ":" + self.config.wfs_password;
                xhr.setRequestHeader("Authorization", "Basic " + btoa(auth));
            },
            type: 'POST',
            dataType: 'xml',
            processData: false,
            contentType: 'text/xml',
            data: payload
        }).done(function () {
            self.layer.getSource().clear();
            self.chart({layer: 'left'}, self.config);
        });
    }
};
