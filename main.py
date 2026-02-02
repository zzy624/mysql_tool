# -*-coding:utf-8-*-

import configparser
import os
import random
import re
import string
import sys
import time

from PyQt5.QtCore import pyqtSlot, Qt, QThread, pyqtSignal
from PyQt5.QtGui import QIntValidator
from PyQt5.QtWidgets import QApplication, QMainWindow, QListWidgetItem, QDialog, QTableWidgetItem, QMessageBox, QSlider

from logic import autoMysqlTool
from ui.pyui.ui_config import Ui_Dialog
from ui.pyui.ui_main import Ui_MainWindow

tab_bar_stylesheet = """
            QTabBar::tab {
                background-color: lightgray;
                color: rgb(38, 38, 38);
                border-radius: 2px; /* 设置圆角半径 */
                padding:5px;
            }

            QTabBar::tab:selected {
                background-color: rgb(20, 133, 255);
                color: rgb(255, 255, 255);
            }
        """


class WorkerThread(QThread):
    update_progress = pyqtSignal(float)
    task_finished = pyqtSignal()

    def __init__(self, count, value, mysqlClient):
        super(WorkerThread, self).__init__()
        self.count = count
        self.value = value
        self.mysqlClient = mysqlClient

    # 插入数据
    def run(self):
        data = []
        for i in range(0, int(self.count)):
            v = []
            for t in self.value["data"].split(","):
                if "{" in t:
                    prefix = ""
                    if t[0] != "{":
                        prefix = t.split('{', -1)[0]
                    # 获取函数
                    match = re.search(r'\{(.+?)\}', t).group(1)
                    # 获取函数名称和参数
                    if match.split('_', -1)[0] == "index":
                        if match.split('_', -1)[2] == "int":
                            t = prefix + int(match.split('_', -1)[1]) + i
                        if match.split('_', -1)[2] == "str":
                            t = prefix + str(int(match.split('_', -1)[1]) + i)
                    if match.split('_', -1)[0] == "random":
                        if match.split('_', -1)[2] == "str":
                            t = prefix + self.generate_random_string(int(match.split('_', -1)[1]))
                        if match.split('_', -1)[2] == "float":
                            t = prefix + self.generate_random_float(int(match.split('_', -1)[1]),
                                                                    int(match.split('_', -1)[3]))
                v.append(t)
            data.append(tuple(v))
            if i > int(self.count) / 100:
                self.mysqlClient.InsertDatas(self.value["sql_i"], self.value["sql_v"], data)
                progress = i / int(self.count)
                self.update_progress.emit(progress)
                data = []
            if i == int(self.count) - 1:
                self.mysqlClient.InsertDatas(self.value["sql_i"], self.value["sql_v"], data)
                progress = i / int(self.count)
                self.update_progress.emit(progress)
                data = []

        self.task_finished.emit()

    def generate_random_string(self, length):
        characters = string.ascii_letters + string.digits  # 包含字母和数字
        random_string = ''.join(random.choice(characters) for _ in range(length))
        return random_string

    def generate_random_float(self, length, decimal_places):
        # 生成随机浮点数
        random_float = round(random.uniform(0, 10 ** length), decimal_places)
        # 将浮点数格式化为字符串
        float_str = "{:0.{}f}".format(random_float, decimal_places)
        return float_str


class UIConfigDialog(QDialog, Ui_Dialog):
    def __init__(self):
        super(UIConfigDialog, self).__init__()
        self.setupUi(self)
        self.tabWidget.setStyleSheet(tab_bar_stylesheet)


class UIMainWindow(QMainWindow, Ui_MainWindow):
    M = autoMysqlTool.MysqlClient()

    def __init__(self):
        super(UIMainWindow, self).__init__()
        self.setupUi(self)
        self.statusBar().showMessage('当前数据库状态：未连接')
        # 注册菜单点击事件
        self.actionmu.triggered.connect(self.on_actionmu_clicked)

        # 设置tabWidget中tab标签的样式，解决样式默认显示问题
        self.tabWidget.setStyleSheet(tab_bar_stylesheet)

        # 设置滑动条和lineEdit联动，初始值
        self.horizontalSlider.setMinimum(10)
        self.horizontalSlider.setMaximum(100000)
        self.horizontalSlider.setValue(5000)
        self.horizontalSlider.setTickPosition(QSlider.TicksBelow)
        self.horizontalSlider.setTickInterval(1000)
        self.horizontalSlider.valueChanged.connect(lambda value: self.lineEdit_data_count.setText(str(value)))

        # 设置进度条显示百分比
        self.progressBar.setFormat('%p%')
        # 设置验证器，限制只能输入数字和最大允许的值
        int_validator = QIntValidator()
        int_validator.setRange(0, 2147483647)

        self.lineEdit_data_count.setText(str(self.horizontalSlider.value()))
        self.lineEdit_data_count.setValidator(int_validator)
        self.lineEdit_data_count.textChanged.connect(
            lambda text: self.horizontalSlider.setValue(int(text) if text.isdigit() else 0))

        self.value = {}
        self.application_path = ""

        # 初始化配置文件
        self.conf = configparser.ConfigParser(allow_no_value=True)
        if getattr(sys, 'frozen', False):
            # 如果程序是被打包的，使用这个路径
            self.application_path = sys._MEIPASS
        else:
            # 如果程序不是打包的，使用当前文件的路径
            self.application_path = os.path.dirname(os.path.abspath(__file__))
        self.conf.read(self.application_path + "/config/config.ini")
        host = self.conf.get("Mysql", "host")
        port = self.conf.get("Mysql", "port")
        username = self.conf.get("Mysql", "username")
        password = self.conf.get("Mysql", "password")
        database = self.conf.get("Mysql", "database")
        self.lineEdit_host.setText(host)
        self.lineEdit_port.setText(port)
        self.lineEdit_username.setText(username)
        self.lineEdit_password.setText(password)
        self.lineEdit_database.setText(database)

        # 注册数据库连接配置文本框修改时间
        self.lineEdit_host.textChanged.connect(self.lineEdit_host_value)
        self.lineEdit_port.textChanged.connect(self.lineEdit_port_value)
        self.lineEdit_username.textChanged.connect(self.lineEdit_username_value)
        self.lineEdit_password.textChanged.connect(self.lineEdit_password_value)
        self.lineEdit_database.textChanged.connect(self.lineEdit_database_value)

        # 相对路径
        # self.path = os.path.dirname(os.path.dirname(os.path.realpath(sys.executable)))

    def lineEdit_host_value(self, host):
        self.conf.set("Mysql", "host", host)
        with open(self.application_path + "/config/config.ini", 'w') as f:
            self.conf.write(f)

    def lineEdit_port_value(self, host):
        self.conf.set("Mysql", "port", host)
        with open(self.application_path + "/config/config.ini", 'w') as f:
            self.conf.write(f)

    def lineEdit_username_value(self, username):
        self.conf.set("Mysql", "username", username)
        with open(self.application_path + "/config/config.ini", 'w') as f:
            self.conf.write(f)

    def lineEdit_password_value(self, password):
        self.conf.set("Mysql", "password", password)
        with open(self.application_path + "/config/config.ini", 'w') as f:
            self.conf.write(f)

    def lineEdit_database_value(self, database):
        self.conf.set("Mysql", "database", database)
        with open(self.application_path + "/config/config.ini", 'w') as f:
            self.conf.write(f)

    # 连接数据库按钮
    @pyqtSlot()
    def on_pushButton_clicked(self):
        if self.M.conn:
            return
        host = self.lineEdit_host.text()
        port = self.lineEdit_port.text()
        username = self.lineEdit_username.text()
        password = self.lineEdit_password.text()
        database = self.lineEdit_database.text()
        ok, e = self.M.SetClient(username, password, host, port, database)
        if ok:
            self.statusBar().showMessage('当前数据库状态：已连接')
            self.showTable()
        else:
            self.statusBar().showMessage(f'当前数据库状态：{e}')

    # 显示当前数据库中的表
    def showTable(self):
        tables = self.M.ExecSql("show tables;")
        for i in tuple(item[0] for item in tables):
            item = QListWidgetItem(i)
            self.listWidget.addItem(item)

    # 生成数据库结构体按钮
    @pyqtSlot()
    def on_pushButton_struct_clicked(self):
        if self.listWidget.currentItem() is None:
            QMessageBox.warning(self, "Warning", "请选择数据表")
            return
        table = self.listWidget.currentItem().text()
        if table:
            out = self.M.getTempalte(table, "template","v1")
            # print(out)
            self.textEdit_struct.setText(out)

    # 生成数据库函数按钮
    @pyqtSlot()
    def on_pushButton_func_clicked(self):
        if self.listWidget.currentItem() is None:
            QMessageBox.warning(self, "Warning", "请选择数据表")
            return
        table = self.listWidget.currentItem().text()
        if table:
            out = self.M.getTempalte(table, "template_ex","v1")
            self.textEdit_func.setText(out)

    # 复制结构体函数文件
    @pyqtSlot()
    def on_pushButton_copy_struct_clicked(self):
        clipboard = QApplication.clipboard()
        clipboard.setText(self.textEdit_struct.toPlainText())

    # 复制数据库函数文件
    @pyqtSlot()
    def on_pushButton_copy_func_clicked(self):
        clipboard = QApplication.clipboard()
        clipboard.setText(self.textEdit_func.toPlainText())

    # 打开配置文件对话框
    @pyqtSlot()
    def on_actionmu_clicked(self):
        cw = UIConfigDialog()
        with open(self.application_path + f'/templates/v1/template', 'r') as file:
            content = file.read()
            cw.textEdit.setText(content)
        with open(self.application_path + f'/templates/v1/template_ex', 'r') as file:
            content2 = file.read()
            cw.textEdit_2.setText(content2)

        # 执行对话框的模态运行，阻止用户与应用程序其他部分的交互
        cw.exec_()
        with open(self.application_path + f'/templates/v1/template', 'w') as file:
            file.write(cw.textEdit.toPlainText())
        with open(self.application_path + f'/templates/v1/template_ex', 'w') as file:
            file.write(cw.textEdit_2.toPlainText())

    # 获取数据库字段
    @pyqtSlot()
    def on_pushButton_get_col_clicked(self):
        self.tableWidget.clearContents()
        if self.listWidget.currentItem() is None:
            QMessageBox.warning(self, "Warning", "请选择数据表")
            return
        table = self.listWidget.currentItem().text()
        cols = []
        if table:
            if table != self.M.data["Name"]:
                cols = self.M.getTableInfo(table)["columns"]
            else:
                cols = self.M.data["columns"]
        # 设置表格行列
        self.tableWidget.setColumnCount(5)
        self.tableWidget.setRowCount(len(cols))
        self.tableWidget.setHorizontalHeaderLabels(["字段", "类型", "默认值", "备注", "随机数据函数"])
        # print(cols)
        for row in range(len(cols)):
            # 设置值
            field = QTableWidgetItem(cols[row]["Field"])
            type_ = QTableWidgetItem(cols[row]["Type"])
            default = QTableWidgetItem(cols[row]["Default"])
            comment = QTableWidgetItem(cols[row]["Comment"])
            self.tableWidget.setItem(row, 0, field)
            self.tableWidget.setItem(row, 1, type_)
            self.tableWidget.setItem(row, 2, default)
            self.tableWidget.setItem(row, 3, comment)
            # 不可编辑
            field.setFlags(field.flags() & ~Qt.ItemIsEditable)
            type_.setFlags(type_.flags() & ~Qt.ItemIsEditable)
            default.setFlags(default.flags() & ~Qt.ItemIsEditable)
            comment.setFlags(comment.flags() & ~Qt.ItemIsEditable)

        # 生成随机函数
        self.generate_random_func()

    def generate_random_func(self):
        self.value = {
            "sql_i": "",
            "sql_v": "",
            "data": "",
        }
        for i, v in enumerate(self.M.data["columns"]):
            sqli = ""
            sqlv = ""
            if v['Default']:
                sqli = v['Default']
                sqlv = "%s"
                if sqli == "CURRENT_TIMESTAMP":
                    sqli = f'{time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())}'
            else:
                if "int" in v['Type']:
                    # 排除主键ID
                    if "PRI" not in v["Key"]:
                        # 从1开始自增的数字
                        sqli = "{index_1_int}"
                        sqlv = "%d"
                if "varchar" in v["Type"]:
                    # 获取字段长度
                    match = re.search(r'\((\d+)\)', v["Type"])
                    number = match.group(1)
                    sqli = "{random_" + str(number) + "_str}"
                    sqlv = "%s"
                if "datetime" in v["Type"]:
                    sqli = f'"{time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())}"'
                    sqlv = "%s"
                if "decimal" in v["Type"]:
                    # 获取位数和保留位数
                    match = re.search(r'\((\d+),(\d+)\)', v["Type"])
                    sqli = "{random_" + str(match.group(1)) + "_float_" + str(match.group(2)) + "}"
                    sqlv = "%f"
                if "text" in v["Type"]:
                    sqli = ""
                    sqlv = "%s"
            self.value["data"] += sqli
            self.value["sql_v"] += sqlv
            # 排除主键ID
            if "PRI" not in v["Key"]:
                self.value["sql_i"] += '`' + v['Field'] + '`'
                if i != len(self.M.data["columns"]) - 1:
                    self.value["sql_i"] += ','
                    self.value["sql_v"] += ','
                    self.value["data"] += ','
        # print(self.value["data"])
        # print(self.M.data["columns"])
        for i, v in enumerate(self.value["data"].split(',', -1)):
            self.tableWidget.setItem(i + 1, 4, QTableWidgetItem(v))

    @pyqtSlot()
    def on_pushButton_generate_data_clicked(self):
        if self.M.data["Name"] == "":
            QMessageBox.warning(self, "Warning", "请先获取字段！")
            return
        self.value["data"] = ""
        for i in range(0, len(self.M.data["columns"])):
            if self.M.data["columns"][i]["Key"] != "PRI":
                self.value["data"] += self.tableWidget.item(i, 4).text()
                if i != len(self.M.data["columns"]) - 1:
                    self.value["data"] += ','

        # print(self.value)
        self.worker_thread = WorkerThread(self.lineEdit_data_count.text(), self.value, self.M)
        # 连接工作线程的update_progress信号到更新进度条的槽函数
        self.worker_thread.update_progress.connect(self.update_progress)
        # 连接工作线程的update_progress信号到更新进度条的槽函数
        self.worker_thread.task_finished.connect(self.finished_progress)
        # 启动工作线程
        self.worker_thread.start()
        self.lineEdit_data_count.setEnabled(False)
        self.horizontalSlider.setEnabled(False)

    @pyqtSlot()
    def on_pushButton_del_data_clicked(self):
        if self.listWidget.currentItem() is None:
            QMessageBox.warning(self, "Warning", "未选中任何表！")
            return
        messageBox = QMessageBox()
        messageBox.setWindowTitle(' ')
        messageBox.setText('是否确认执行?')
        messageBox.setStandardButtons(QMessageBox.Yes | QMessageBox.No)
        buttonY = messageBox.button(QMessageBox.Yes)
        buttonY.setText('确认')
        buttonN = messageBox.button(QMessageBox.No)
        buttonN.setText('取消')
        messageBox.exec_()
        if messageBox.clickedButton() == buttonY:
            self.M.ExecSql(f"truncate {self.listWidget.currentItem().text()}")
            QMessageBox.information(self, "Information", "清除完毕！")

    def update_progress(self, value):
        # 更新进度条的值
        v = int(value * 100)
        self.progressBar.setValue(int(value * 100))
        # 更新 QLabel 显示的百分比
        self.label_progress.setText(f'{int(value * 100)}%')

    def finished_progress(self):
        # 更新进度条的值
        self.progressBar.setValue(100)
        # 更新 QLabel 显示的百分比
        self.label_progress.setText(f'{int(100)}%')
        # self.worker_thread.thread().quit()
        self.worker_thread = None
        self.lineEdit_data_count.setEnabled(True)
        self.horizontalSlider.setEnabled(True)
        QMessageBox.information(self, "Information", "生成成功！")


if __name__ == '__main__':
    app = QApplication(sys.argv)
    dlg = UIMainWindow()
    dlg.show()
    # cw = UIConfigWindow()
    # cw.hide()
    app.exec_()
