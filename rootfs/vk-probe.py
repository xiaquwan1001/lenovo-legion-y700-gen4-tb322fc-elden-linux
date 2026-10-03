#!/usr/bin/env python3
"""Enumerate Vulkan physical devices without vulkan-tools installed.

Calls the loader directly through ctypes so we can tell whether turnip
recognises the Adreno 830 after the chip-id patch.
"""
import ctypes
import ctypes.util
import sys

name = ctypes.util.find_library("vulkan") or "libvulkan.so.1"
try:
    vk = ctypes.CDLL(name)
except OSError as err:
    sys.exit(f"cannot load {name}: {err}")


class AppInfo(ctypes.Structure):
    _fields_ = [
        ("sType", ctypes.c_int), ("pNext", ctypes.c_void_p),
        ("pApplicationName", ctypes.c_char_p), ("applicationVersion", ctypes.c_uint32),
        ("pEngineName", ctypes.c_char_p), ("engineVersion", ctypes.c_uint32),
        ("apiVersion", ctypes.c_uint32),
    ]


class InstInfo(ctypes.Structure):
    _fields_ = [
        ("sType", ctypes.c_int), ("pNext", ctypes.c_void_p), ("flags", ctypes.c_uint32),
        ("pApplicationInfo", ctypes.POINTER(AppInfo)),
        ("enabledLayerCount", ctypes.c_uint32), ("ppEnabledLayerNames", ctypes.c_void_p),
        ("enabledExtensionCount", ctypes.c_uint32), ("ppEnabledExtensionNames", ctypes.c_void_p),
    ]


class Limits(ctypes.Structure):
    _fields_ = [("pad", ctypes.c_uint8 * 504)]


class Sparse(ctypes.Structure):
    _fields_ = [("pad", ctypes.c_uint32 * 8)]


class Props(ctypes.Structure):
    _fields_ = [
        ("apiVersion", ctypes.c_uint32), ("driverVersion", ctypes.c_uint32),
        ("vendorID", ctypes.c_uint32), ("deviceID", ctypes.c_uint32),
        ("deviceType", ctypes.c_uint32), ("deviceName", ctypes.c_char * 256),
        ("pipelineCacheUUID", ctypes.c_uint8 * 16),
        ("limits", Limits), ("sparseProperties", Sparse),
    ]


TYPES = {0: "OTHER", 1: "INTEGRATED_GPU", 2: "DISCRETE_GPU", 3: "VIRTUAL_GPU", 4: "CPU"}

app = AppInfo(0, None, b"vk-probe", 1, b"none", 1, (1 << 22) | (1 << 12))
info = InstInfo(1, None, 0, ctypes.pointer(app), 0, None, 0, None)
inst = ctypes.c_void_p()

rc = vk.vkCreateInstance(ctypes.byref(info), None, ctypes.byref(inst))
if rc != 0:
    sys.exit(f"vkCreateInstance failed: {rc}")

count = ctypes.c_uint32(0)
vk.vkEnumeratePhysicalDevices(inst, ctypes.byref(count), None)
print(f"physical devices: {count.value}")
if not count.value:
    sys.exit("no Vulkan device -- turnip did not claim the GPU")

devs = (ctypes.c_void_p * count.value)()
vk.vkEnumeratePhysicalDevices(inst, ctypes.byref(count), devs)
for d in devs:
    p = Props()
    vk.vkGetPhysicalDeviceProperties(ctypes.c_void_p(d), ctypes.byref(p))
    api = p.apiVersion
    print(f"  name   : {p.deviceName.decode()}")
    print(f"  type   : {TYPES.get(p.deviceType, p.deviceType)}")
    print(f"  vendor : 0x{p.vendorID:04x}  device: 0x{p.deviceID:04x}")
    print(f"  api    : {api >> 22}.{(api >> 12) & 0x3ff}.{api & 0xfff}")
