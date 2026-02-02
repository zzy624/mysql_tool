pyui:
	pyuic5 -o ./ui/pyui/ui_main.py ./skin/main.ui
qrc:
	pyrcc5 -o ./ui/pyui/icon_rc.py ./res/icon.qrc

builds:
	pyinstaller --noconfirm main.spec

APP = mysql_tool
ICON_SRC = res/$(APP).png
ICONSET = $(APP).iconset

icon: $(ICONSET)
	iconutil -c icns $(ICONSET) -o res/$(APP).icns
	rm -R $(ICONSET)

$(ICONSET):
	mkdir $(ICONSET)
	sips -z 16 16     $(ICON_SRC) --out $(ICONSET)/icon_16x16.png
	sips -z 32 32     $(ICON_SRC) --out $(ICONSET)/icon_16x16@2x.png
	sips -z 32 32     $(ICON_SRC) --out $(ICONSET)/icon_32x32.png
	sips -z 64 64     $(ICON_SRC) --out $(ICONSET)/icon_32x32@2x.png
	sips -z 128 128   $(ICON_SRC) --out $(ICONSET)/icon_128x128.png
	sips -z 256 256   $(ICON_SRC) --out $(ICONSET)/icon_128x128@2x.png
	sips -z 256 256   $(ICON_SRC) --out $(ICONSET)/icon_256x256.png
	sips -z 512 512   $(ICON_SRC) --out $(ICONSET)/icon_256x256@2x.png
	sips -z 512 512   $(ICON_SRC) --out $(ICONSET)/icon_512x512.png
	sips -z 1024 1024 $(ICON_SRC) --out $(ICONSET)/icon_512x512@2x.png

clean:
	rm -f *.icns
	rm -R $(ICONSET)
