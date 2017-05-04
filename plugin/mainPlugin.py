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
    
        # save a reference to the QGIS interface
        self.iface = iface
        self.plugin_dir = QFileInfo(QgsApplication.qgisUserDbFilePath()).path() + \
                          "/python/plugins/smartsea/"
    
        s = QSettings()
        self.server = s.value("smartsea/server", "http://msp.smartsea.fmi.fi/Starman/core")
        self.wmts = s.value("smartsea/wmts", "http://msp.smartsea.fmi.fi/Starman/WMS")
        
    def initGui(self):
        self.dialog = uic.loadUi(self.plugin_dir+"dialog.ui")

        QObject.connect(
            self.dialog.findChild(QPushButton, "configPushButton"), 
            SIGNAL("clicked()"), self.configure)

        QObject.connect(
            self.dialog.findChild(QPushButton, "loadPushButton"), 
            SIGNAL("clicked()"), self.load_layer)
    
        # create action that will start plugin configuration
        self.action = QAction(QIcon(self.plugin_dir+"icon.png"), "SmartSea",
                              self.iface.mainWindow())
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
            self.plans = json.loads(response.read())
            print "Response ok"
            # create a tree from response
            for plan in self.plans:
                print "Got plan "+plan["name"]
                planItem = self.item("plan", [plan])
                for use in plan["uses"]:
                    if plan["name"] == "Data" or plan["name"] == "Ecosystem":
                        useItem = planItem
                    else:
                        useItem = self.item("use", [plan, use])
                        planItem.appendRow(useItem)
                    for layer in use["layers"]:
                        layerItem = self.item("layer", [plan, use, layer])
                        useItem.appendRow(layerItem)
                        if (layer["rules"]):
                            for rule in layer["rules"]:
                                ruleItem = self.item("rule", [plan, use, layer, rule])
                                layerItem.appendRow(ruleItem)
          
                self.model.appendRow(planItem)
            print "Tree built"
        except:
            item = QStandardItem("Failed to load plans. Please configure.")
            self.model.appendRow(item)
    
        treeView.setModel(self.model)
        treeView.show()

    def load_layer(self):
        treeView = self.dialog.findChild(QTreeView, "treeView")
        l = treeView.selectedIndexes()
        if (len(l) == 0):
            msg = QMessageBox()
            msg.setIcon(QMessageBox.Information)
            msg.setText("Please select a plan, use, or a layer.")
            msg.setWindowTitle("Error")
            msg.setStandardButtons(QMessageBox.Ok)
            msg.exec_()
            return
        name = l[0].data()
        # klass = l[0].data(Qt.UserRole+2)
        # what's the id
        id = l[0].data(Qt.UserRole+3)
        trail = id.split("_")
        # trail is plan_use_layer_rule
        print "Load "+name+" "+str(id)
        root = QgsProject.instance().layerTreeRoot()

        epsg = 3067
        frmt = 'image/png'
    
        for plan in self.plans:
            if str(plan["id"]) != trail[0]:
                continue
            print "plan "+plan["name"]
            g = root.findGroup(plan["name"]) or root.addGroup(plan["name"])
            for use in plan["uses"]:
                if len(trail) > 1 and str(use["id"]) != trail[1]:
                    continue
                print "use "+use["name"]
                if use["name"] == "Data" or use["name"] == "EcoSystem":
                    g2 = g
                else:
                    g2 = g.findGroup(use["name"]) or g.addGroup(use["name"])
                for layer in use["layers"]:
                    if len(trail) > 2 and str(layer["id"]) != trail[2]:
                        continue
                    print "layer "+layer["name"]
                    
                    s = str(plan["id"])+"_"+str(use["id"])+"_"+str(layer["id"])
                    # rules?

                    wmts = 'url='+self.wmts+ \
                               '&styles='+layer["style"]+ \
                               '&format='+frmt+ \
                               '&crs=EPSG:'+str(epsg)+ \
                               '&tileDimensions=256;256'+ \
                               '&layers='
                            
                    l = QgsRasterLayer(wmts+s, layer["name"], 'wms')
                    if not l.isValid():
                        print "Layer failed to load, partial "+wmts+s+\
                                  ". Is the layer advertised?"
                    else:
                        print "Layer ok!"
                        QgsMapLayerRegistry.instance().addMapLayer(l, False)
                        l2 = g2.addLayer(l)
                        l2.setVisible(False)
                        print "Layer added!"

    def item(self, klass, objs):
        obj = objs[len(objs)-1]
        item = QStandardItem(obj["name"])
        item.setData(klass,Qt.UserRole+2)
        ids = []
        for obj in objs:
            ids.append(str(obj["id"]))
        data = "_".join(ids)
        item.setData(data,Qt.UserRole+3)
        return item
