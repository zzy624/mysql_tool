# -*- mode: python ; coding: utf-8 -*-

import os
import sys
def get_mysql_paths():
    import mysql.connector
    mysql_path = os.path.dirname(mysql.connector.__file__)
    locales_path = os.path.join(mysql_path, 'locales')
    plugins_path = os.path.join(mysql_path, 'plugins')
    return mysql_path, locales_path, plugins_path

mysql_path, locales_path, plugins_path = get_mysql_paths()

datas = [
    ('./res/mysql_tool.icns','.'),
    ('./templates/v1/template','./templates/v1'),
    ('./templates/v1/template_ex','./templates/v1'),
    ('./config/config.ini','./config'),
]

if os.path.exists(locales_path):
    datas.append((locales_path, 'mysql/connector/locales'))

binaries = []
if os.path.exists(plugins_path):
    for file in os.listdir(plugins_path):
        if file.endswith('.so') or file.endswith('.dylib'):
            binaries.append((os.path.join(plugins_path, file), 'mysql/connector/plugins'))

a = Analysis(
    ['main.py'],
    pathex=[],
    binaries=binaries,
    datas=datas,  # 包含 locales
    hiddenimports=[
        'PyQt5.sip',
        'PyQt5.QtCore',
        'PyQt5.QtGui',
        'PyQt5.QtWidgets',
        'mysql.connector',
        'mysql.connector.locales',
        'mysql.connector.locales.eng_client_error',
        'mysql.connector.plugins',
        'mysql.connector.plugins.caching_sha2_password',
        'mysql.connector.plugins.mysql_native_password',
        'pkg_resources.py2_warn',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        'PyQt5.QtBluetooth',
        'PyQt5.QtDesigner',
        'PyQt5.QtHelp',
        'PyQt5.QtMultimedia',
        'PyQt5.QtMultimediaWidgets',
        'PyQt5.QtNetwork',
        'PyQt5.QtNfc',
        'PyQt5.QtOpenGL',
        'PyQt5.QtPositioning',
        'PyQt5.QtPrintSupport',
        'PyQt5.QtQml',
        'PyQt5.QtQuick',
        'PyQt5.QtQuickWidgets',
        'PyQt5.QtSensors',
        'PyQt5.QtSerialPort',
        'PyQt5.QtSql',
        'PyQt5.QtTest',
        'PyQt5.QtWebChannel',
        'PyQt5.QtWebEngine',
        'PyQt5.QtWebEngineCore',
        'PyQt5.QtWebEngineWidgets',
        'PyQt5.QtWebSockets',
        'PyQt5.QtXml',
        'PyQt5.QtXmlPatterns',
    ],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='main',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=True,
    target_arch=None,
    codesign_identity=None,
    entitlements_file='None',
)

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=False,
    upx_exclude=[],
    name='数据库工具',  # 统一中文名
)

app = BUNDLE(
    coll,
    name='数据库工具.app',
    icon='res/mysql_tool.icns',
    bundle_identifier='com.zzy624.mysqltool',
)