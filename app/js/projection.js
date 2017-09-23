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
/*global alert, ol*/

/**
 * Options for creating a projection.
 * @typedef {Object} ProjectionOptions
 * @property {number} epsg - 3857 or 3067.
 * @property {string} matrixSet - ETRS-TM35FIN or EPSG:3857.
 * @property {Array} center - [x,y].
 * @property {number} zoom - .
 */
/**
 * A projection and a view to be used in the map.
 * @constructor
 * @param {ProjectionOptions} options - Options.
 */
function Projection(options) {
    var self = this,
        p = ol.proj.get('EPSG:' + options.epsg),
        extent,
        size,
        z_n,
        z;
    if (options.epsg === 3067) {
        extent = [-548576, 6291456, 1548576, 8388608];
        p.setExtent(extent);
    } else {
        extent = p.getExtent();
    }
    self.epsg = options.epsg;
    self.projection = p;
    self.matrixSet = options.matrixSet;
    self.view = new ol.View({
        projection: p, // needed at least for 3067, not for 3857
        center: options.center,
        zoom: options.zoom
    });
    self.extent = extent;
    size = ol.extent.getWidth(extent) / 256;
    z_n = 16;
    self.resolutions = [];
    self.matrixIds = [];
    for (z = 0; z < z_n; z += 1) {
        self.resolutions[z] = size / Math.pow(2, z);
        self.matrixIds[z] = z;
    }
}

Projection.prototype = {
};
