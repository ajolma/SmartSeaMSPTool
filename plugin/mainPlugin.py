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
    s = QSettings()
    self.server = s.value("smartsea/server", "http://localhost:5000/core")
    self.wmts = s.value("smartsea/wmts", "http://localhost:5000/WMS")
    # download plans here?
    # fail init and report if no connection?
    # provide a way to set these?

  def initGui(self):
    self.dialog = uic.loadUi(self.plugin_dir+"dialog.ui")

    QObject.connect(
        self.dialog.findChild(QPushButton, "DownloadPushButton"), 
        SIGNAL("clicked()"), self.load_plans)
    
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
    self.dialog.show()

  def load_plans(self):
    print "Get the plans tree..."
    # the URL needs to come somewhere configurable
    url = self.server + "/plans"
    response = urllib.urlopen(url)
    data = json.loads(response.read())
    # create a tree from data
    treeView = self.dialog.findChild(QTreeView, "treeView")
    model = QStandardItemModel()
    model.setHorizontalHeaderLabels(['plans'])
    
    for plan in data:
      planItem = QStandardItem(plan["title"])
      for use in plan["uses"]:
        useItem = QStandardItem(use["title"])
        planItem.appendRow(useItem)
        for layer in use["layers"]:
          layerItem = QStandardItem(layer["title"])
          useItem.appendRow(layerItem)
          if (layer["rules"]):
            for rule in layer["rules"]:
              ruleItem = QStandardItem(rule["title"])
              layerItem.appendRow(ruleItem)
          
      model.appendRow(planItem)
          
    treeView.setModel(model)
    treeView.show()

  def load(self):
    root = QgsProject.instance().layerTreeRoot()
    
    url = self.server+"/plans/3"
    response = urllib.urlopen(url)
    data = json.loads(response.read())

    styles = ''
    epsg = 3067
    frmt = 'image/png'
    url = 'url='+self.wmts+ \
          '&styles='+styles+ \
          '&format='+frmt+ \
          '&crs=EPSG:'+epsg+ \
          '&tileDimensions=256;256'+ \
          '&layers='

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
