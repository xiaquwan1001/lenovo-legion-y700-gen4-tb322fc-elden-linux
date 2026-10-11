# waydroid-sensord-udp — route C (C4) sensor HAL for y700-elden
#
# Replaces upstream waydroid-sensors' sensorfw/libgbinder daemon data source
# with a UDP text protocol (scripts/eldroid-sensord.c). service.cpp/Sensors.cpp
# are unmodified upstream (GPL-3.0); SensorFW.{h,cpp} are ours.
#
# Build: make            (needs g++ pkgconf libgbinder-dev libglibutil-dev glib-dev)
# Run:   waydroid-sensord-udp /dev/hwbinder
#
# SPDX-License-Identifier: GPL-3.0-or-later

CXX      ?= g++
CXXFLAGS ?= -O2 -g -pthread -Wall -Wextra -Wno-unused-parameter
PKGS     := glib-2.0 gio-2.0 gio-unix-2.0 libglibutil libgbinder

PKG_CFLAGS := $(shell pkg-config --cflags $(PKGS))
PKG_LIBS   := $(shell pkg-config --libs $(PKGS))

TARGET := waydroid-sensord-udp
SRCS   := service.cpp Sensors.cpp SensorFW.cpp

all: $(TARGET)

$(TARGET): $(SRCS) Sensors.h SensorFW.h hybrisbindertypes.h
	$(CXX) $(CXXFLAGS) $(PKG_CFLAGS) -o $@ $(SRCS) $(PKG_LIBS)

clean:
	rm -f $(TARGET)

.PHONY: all clean
