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
    
    # provide a way to set these?

  def initGui(self):
    self.dialog = uic.loadUi(self.plugin_dir+"dialog.ui")

    QObject.connect(
        self.dialog.findChild(QPushButton, "configPushButton"), 
        SIGNAL("clicked()"), self.configure)

    QObject.connect(
        self.dialog.findChild(QPushButton, "loadPushButton"), 
        SIGNAL("clicked()"), self.load_layer)
    
    # create action that will start plugin configuration
    self.action = QAction(QIcon(self.plugin_dir+"icon.png"), "SmartSea", self.iface.mainWindow())
    self.action.setObjectName("SmartSea")
    self.action.setWhatsThis("Open SmartSea dialog box")
    self.action.setStatusTip("Open SmartSea dialog box")
    QObject.connect(self.action, SIGNAL("triggered()"), self.run)

    # add toolbar button and menu item
    self.iface.addToolBarIcon(self.action)
    self.iface.addPluginToMenu("&Plugins", self.action)

    self.fill_tree()

  def unload(self):
    # remove the plugin menu item and icon
    self.iface.removePluginMenu("&Plugins",self.action)
    self.iface.removeToolBarIcon(self.action)

  def run(self):
    self.dialog.show()

  def configure(self):
    print "Set the service URLs..."
    dialog = uic.loadUi(self.plugin_dir+"configure.ui")
    QObject.connect(
        dialog.findChild(QPushButton, "testPushButton"), 
        SIGNAL("clicked()"), self.test_connection)
    self.configure = dialog
    dialog.setModal(1);
    server = dialog.findChild(QLineEdit, "serverLineEdit")
    server.setText(self.server)
    wmts = dialog.findChild(QLineEdit, "wmtsLineEdit")
    wmts.setText(self.wmts)
    if (dialog.exec_()):
      s = QSettings()
      self.server = server.text()
      s.setValue("smartsea/server", self.server)
      self.wmts = wmts.text()
      s.setValue("smartsea/wmts", self.wmts)
      self.fill_tree()

  def test_connection(self):
    dialog = self.configure
    server = dialog.findChild(QLineEdit, "serverLineEdit")
    server.text()
    wmts = dialog.findChild(QLineEdit, "wmtsLineEdit")
    wmts.text()
    try:
      response = urllib.urlopen(server.text())
      response = urllib.urlopen(wmts.text())
      connectionOk = 1
    except:
      connectionOk = 0

    msg = QMessageBox()
    msg.setIcon(QMessageBox.Information)
    if (connectionOk):
      msg.setText("Connection OK")
    else:
      msg.setText("Connection FAILED")
      # error message into msg.setDetailedText()?
    msg.setWindowTitle("Connection test")
    msg.setStandardButtons(QMessageBox.Ok)
    msg.exec_()

  def fill_tree(self):
    treeView = self.dialog.findChild(QTreeView, "treeView")
    self.model = QStandardItemModel()
    self.model.setHorizontalHeaderLabels(['plans'])
    print "Get the plans tree..."
    url = self.server + "/plans"
    try:
      response = urllib.urlopen(url)
      data = json.loads(response.read())
      # create a tree from data
      for plan in data:
        planItem = self.item(plan, "plan")
        for use in plan["uses"]:
          useItem = self.item(use, "use")
          planItem.appendRow(useItem)
          for layer in use["layers"]:
            layerItem = self.item(layer, "layer")
            useItem.appendRow(layerItem)
            if (layer["rules"]):
              for rule in layer["rules"]:
                ruleItem = self.item(rule, "rule")
                layerItem.appendRow(ruleItem)
        for dataset in plan["datasets"]:
          datasetItem = self.item(dataset, "dataset")
          planItem.appendRow(datasetItem)
          
        self.model.appendRow(planItem)
    except:
      item = QStandardItem("Failed to load plans. Please configure.")
      self.model.appendRow(item)
    
    treeView.setModel(self.model)
    treeView.show()

  def load_layer(self):
    treeView = self.dialog.findChild(QTreeView, "treeView")
    l = treeView.selectedIndexes()
    name = l[0].data()
    print name
    # what is it
    klass = l[0].data(Qt.UserRole+2)
    # what's the id
    id = l[0].data(Qt.UserRole+3)
    root = QgsProject.instance().layerTreeRoot()

    styles = ''
    epsg = 3067
    frmt = 'image/png'
    wmts = 'url='+self.wmts+ \
          '&styles='+styles+ \
          '&format='+frmt+ \
          '&crs=EPSG:'+str(epsg)+ \
          '&tileDimensions=256;256'+ \
          '&layers='
    
    if (klass == "plan"):
      url = self.server+"/plans/"+str(id)
      try:
        response = urllib.urlopen(url)
        data = json.loads(response.read())
        for plan in data:
          print plan["title"]
          g = root.addGroup(plan["title"])
          for use in plan["uses"]:
            g2 = g.addGroup(use["title"])
            for layer in use["layers"]:
              s = str(plan["id"])+"_"+str(use["id"])+"_"+str(layer["id"])
              # rules?
              l = QgsRasterLayer(wmts+s, layer["title"], 'wms')
              if not l.isValid():
                print "Layer failed to load: "+wmts+s
              else:
                print "Layer ok!"
                QgsMapLayerRegistry.instance().addMapLayer(l, False)
                l2 = g2.addLayer(l)
                l2.setVisible(False)
                print "there!"
      except:
        print "failed: "+url
        
    elif (klass == "dataset"):
      layer = wmts+'dataset_'+str(id)
      l = QgsRasterLayer(layer, name, 'wms')
      if not l.isValid():
        print "Layer failed to load: "+layer
      else:
        print "Layer ok!"
        QgsMapLayerRegistry.instance().addMapLayer(l, False)
        l2 = root.addLayer(l)
        l2.setVisible(False)
        print "there!"

    else:
      print "loading "+klass+"s not yet implemented"

  def item(self, obj, klass):
    item = QStandardItem(obj["title"])
    item.setData(klass,Qt.UserRole+2)
    item.setData(obj["id"],Qt.UserRole+3)
    return item
