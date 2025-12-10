export PREFIX = /usr
TARGET := iphone:clang:latest:11.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AutoClicker

AutoClicker_FILES = Tweak.x
AutoClicker_CFLAGS = -fobjc-arc
AutoClicker_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
