from PyQt4.QtCore import *
from PyQt4.QtGui import *
from PyQt4 import uic
from qgis.core import *
import subprocess
import os
import psycopg2
import urllib, json

class SmartSea:

  def __init__(self, iface):
    # save reference to the QGIS interface
    self.iface = iface
    self.plugin_dir = QFileInfo(QgsApplication.qgisUserDbFilePath()).path() + \
        "/python/plugins/smartsea/"

  def initGui(self):
    # self.dialog = uic.loadUi(self.plugin_dir+"topcons.ui")
    
    # create action that will start plugin configuration
    self.action = QAction(QIcon(self.plugin_dir+"icon.png"), "SmartSea", self.iface.mainWindow())
    self.action.setObjectName("SmartSea")
    #self.action.setWhatsThis("Open TOPCONS dialog box")
    #self.action.setStatusTip("Open TOPCONS dialog box")
    QObject.connect(self.action, SIGNAL("triggered()"), self.run)

    # add toolbar button and menu item
    self.iface.addToolBarIcon(self.action)
    self.iface.addPluginToMenu("&Plugins", self.action)

  def unload(self):
    # remove the plugin menu item and icon
    self.iface.removePluginMenu("&Plugins",self.action)
    self.iface.removeToolBarIcon(self.action)

  def run(self):
    root = QgsProject.instance().layerTreeRoot()

    print "Here I am!"
    print "Get the data..."
    # need to ask which plan
    url = "http://localhost:5000/core/plans/3"
    response = urllib.urlopen(url)
    data = json.loads(response.read())

    urlWithParams = 'url=http://localhost:5000/WMS&styles=&format=image/png&crs=EPSG:3067&tileDimensions=256;256&layers='

    for plan in data:
      print plan["title"]
      g = root.addGroup(plan["title"])
      for use in plan["uses"]:
        g2 = g.addGroup(use["title"])
        for layer in use["layers"]:
          s = str(plan["id"])+"_"+str(use["id"])+"_"+str(layer["id"])
          l = QgsRasterLayer(urlWithParams+s, layer["title"], 'wms')
          if not l.isValid():
            print "Layer failed to load!"
          else:
            print "Layer ok!"
            QgsMapLayerRegistry.instance().addMapLayer(l, False)
            l2 = g2.addLayer(l)
            l2.setVisible(False)
    print "there!"
