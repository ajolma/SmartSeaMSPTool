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

function projection(options) {
    var p = ol.proj.get('EPSG:'+options.epsg);
    var extent;
    if (options.epsg == 3067) {
        extent = [-548576, 6291456, 1548576, 8388608];
        p.setExtent(extent);
    } else {
        extent = p.getExtent();
    }
    var proj = {
        projection: p,
        matrixSet: options.matrixSet,
        view: new ol.View({
            projection: p, // needed at least for 3067, not for 3857
            center: options.center,
            zoom: options.zoom
        }),
        extent: extent
    };
    var size = ol.extent.getWidth(extent) / 256;
    var z_n = 16;
    proj.resolutions = new Array(z_n);
    proj.matrixIds = new Array(z_n);
    for (var z = 0; z < z_n; ++z) {
        proj.resolutions[z] = size / Math.pow(2, z);
        proj.matrixIds[z] = z;
    }
    return proj;
}
