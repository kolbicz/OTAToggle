ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
include $(THEOS)/makefiles/common.mk
TOOL_NAME = otatoggle-helper
otatoggle-helper_FILES = main.m
otatoggle-helper_FRAMEWORKS = Foundation
otatoggle-helper_CFLAGS = -fobjc-arc
otatoggle-helper_CODESIGN_FLAGS = -Shelper-entitlements.plist
include $(THEOS_MAKE_PATH)/tool.mk
