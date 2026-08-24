ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = OTAToggle
OTAToggle_FILES = main.m AppDelegate.m ViewController.m RootSpawn.m
OTAToggle_FRAMEWORKS = UIKit Foundation
OTAToggle_CFLAGS = -fobjc-arc
OTAToggle_CODESIGN_FLAGS = -Sentitlements.plist
ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
OTAToggle_CODESIGN_FLAGS = -Sentitlements-roothide.plist
endif
OTAToggle_RESOURCE_DIRS = Resources

include $(THEOS_MAKE_PATH)/application.mk

SUBPROJECTS += helper
include $(THEOS_MAKE_PATH)/aggregate.mk

after-OTAToggle-stage::
	@cp .theos/obj/otatoggle-helper $(THEOS_STAGING_DIR)/Applications/OTAToggle.app/otatoggle-helper 2>/dev/null || cp .theos/obj/debug/otatoggle-helper $(THEOS_STAGING_DIR)/Applications/OTAToggle.app/otatoggle-helper
	@if [ "$(THEOS_PACKAGE_SCHEME)" = "roothide" ]; then ldid -Shelper/helper-entitlements-roothide.plist $(THEOS_STAGING_DIR)/Applications/OTAToggle.app/otatoggle-helper; else ldid -Shelper/helper-entitlements.plist $(THEOS_STAGING_DIR)/Applications/OTAToggle.app/otatoggle-helper; fi
	@chmod 6755 $(THEOS_STAGING_DIR)/Applications/OTAToggle.app/otatoggle-helper

ipa: clean all stage
	@rm -rf build/Payload build/OTAToggle-unsigned.ipa
	@mkdir -p build/Payload
	@cp -R $(THEOS_STAGING_DIR)/Applications/OTAToggle.app build/Payload/
	@cd build && zip -qry OTAToggle-unsigned.ipa Payload
	@echo "Created: $(CURDIR)/build/OTAToggle-unsigned.ipa"
