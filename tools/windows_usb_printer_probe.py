"""Scoped Windows USBPRINT probe; no driver, queue or registry changes.

Default is read-only. --print-once sends exactly one fixed PUBLIC ESC/POS
sample to the explicitly identified 0483:5720 printer, never shop data. A
durable one-shot marker prevents replay after an ambiguous write/timeout.
Windows receipt of bytes is not evidence of paper output or Android OTG.
"""
import argparse
import ctypes as c
from ctypes import wintypes as w
import datetime
import json
import os
from pathlib import Path
import subprocess
import sys
import uuid

TARGET = r"USB\VID_0483&PID_5720\USB001"
PUBLIC_SAMPLE = (b"\x1b@\x1ba\x00UJI USB PC M5.1\n"
                 b"PYN-58L / USB DATA\n1234567890\nIDR 12.000\n"
                 b"BUKAN TRANSAKSI\n\n\n\n")


class Guid(c.Structure):
    _fields_ = [("raw", c.c_ubyte * 16)]


class DeviceData(c.Structure):
    _fields_ = [("size", w.DWORD), ("guid", Guid), ("flags", w.DWORD),
                ("reserved", c.c_size_t)]


def enumerate_printers():
    """Resolve only currently present USBPRINT interfaces with SetupAPI."""
    setup = c.WinDLL("setupapi", use_last_error=True)
    guid = Guid((c.c_ubyte * 16).from_buffer_copy(
        uuid.UUID("28d78fad-5a12-11d1-ae5b-0000f803a8c2").bytes_le))
    setup.SetupDiGetClassDevsW.argtypes = [c.POINTER(Guid), w.LPCWSTR, w.HWND, w.DWORD]
    setup.SetupDiGetClassDevsW.restype = w.HANDLE
    setup.SetupDiEnumDeviceInterfaces.argtypes = [w.HANDLE, c.c_void_p,
                                                c.POINTER(Guid), w.DWORD,
                                                c.POINTER(DeviceData)]
    setup.SetupDiEnumDeviceInterfaces.restype = w.BOOL
    setup.SetupDiGetDeviceInterfaceDetailW.argtypes = [w.HANDLE,
        c.POINTER(DeviceData), c.c_void_p, w.DWORD, c.POINTER(w.DWORD),
        c.POINTER(DeviceData)]
    setup.SetupDiGetDeviceInterfaceDetailW.restype = w.BOOL
    setup.SetupDiGetDeviceInstanceIdW.argtypes = [w.HANDLE,
        c.POINTER(DeviceData), w.LPWSTR, w.DWORD, c.POINTER(w.DWORD)]
    setup.SetupDiGetDeviceInstanceIdW.restype = w.BOOL
    setup.SetupDiDestroyDeviceInfoList.argtypes = [w.HANDLE]
    handle = setup.SetupDiGetClassDevsW(c.byref(guid), None, None, 0x12)
    if handle == c.c_void_p(-1).value:
        raise c.WinError(c.get_last_error())
    result = []
    try:
        for index in range(64):
            data = DeviceData(size=c.sizeof(DeviceData))
            if not setup.SetupDiEnumDeviceInterfaces(handle, None, c.byref(guid),
                                                     index, c.byref(data)):
                if c.get_last_error() == 259:
                    return result
                raise c.WinError(c.get_last_error())
            needed = w.DWORD()
            setup.SetupDiGetDeviceInterfaceDetailW(handle, c.byref(data), None,
                                                   0, c.byref(needed), None)
            if not 8 <= needed.value <= 16384:
                raise RuntimeError("Unexpected USBPRINT interface detail size")
            detail = c.create_string_buffer(needed.value)
            c.cast(detail, c.POINTER(w.DWORD))[0] = 8 if c.sizeof(c.c_void_p) == 8 else 6
            device = DeviceData(size=c.sizeof(DeviceData))
            if not setup.SetupDiGetDeviceInterfaceDetailW(handle, c.byref(data),
                    detail, needed, None, c.byref(device)):
                raise c.WinError(c.get_last_error())
            instance = c.create_unicode_buffer(2048)
            if not setup.SetupDiGetDeviceInstanceIdW(handle, c.byref(device),
                                                     instance, 2048, None):
                raise c.WinError(c.get_last_error())
            result.append({"instance": instance.value,
                           "path": c.wstring_at(c.addressof(detail) + 4)})
        raise RuntimeError("Too many printer interfaces; refuse ambiguous selection")
    finally:
        setup.SetupDiDestroyDeviceInfoList(handle)


def write_public_sample():
    """Child process watchdog bounds a synchronous kernel write to 12 seconds."""
    targets = [x for x in enumerate_printers() if x["instance"].upper() == TARGET]
    if len(targets) != 1:
        raise RuntimeError("Exact confirmed USB printer not uniquely present")
    kernel = c.WinDLL("kernel32", use_last_error=True)
    kernel.CreateFileW.argtypes = [w.LPCWSTR, w.DWORD, w.DWORD, c.c_void_p,
                                   w.DWORD, w.DWORD, w.HANDLE]
    kernel.CreateFileW.restype = w.HANDLE
    kernel.WriteFile.argtypes = [w.HANDLE, c.c_void_p, w.DWORD,
                                 c.POINTER(w.DWORD), c.c_void_p]
    kernel.WriteFile.restype = w.BOOL
    kernel.CloseHandle.argtypes = [w.HANDLE]
    handle = kernel.CreateFileW(targets[0]["path"], 0x40000000, 3, None, 3, 0, None)
    if handle == c.c_void_p(-1).value:
        print(json.dumps({"state": "not_sent", "winError": c.get_last_error()}))
        return 2
    try:
        written = w.DWORD()
        buffer = c.create_string_buffer(PUBLIC_SAMPLE)
        ok = kernel.WriteFile(handle, buffer, len(PUBLIC_SAMPLE), c.byref(written), None)
        complete = bool(ok and written.value == len(PUBLIC_SAMPLE))
        print(json.dumps({"state": "submitted" if complete else "ambiguous",
                          "bytesExpected": len(PUBLIC_SAMPLE), "bytesWritten": written.value,
                          "winError": 0 if ok else c.get_last_error()}))
        return 0 if complete else 3
    finally:
        kernel.CloseHandle(handle)


def main():
    if os.name != "nt":
        raise SystemExit("Windows USBPRINT only")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--print-once", action="store_true")
    parser.add_argument("--evidence", type=Path)
    parser.add_argument("--child-write", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.child_write:
        return write_public_sample()
    devices = enumerate_printers()
    # Device paths are handles, not printer identity; selection uses SetupAPI's
    # real instance ID, never a guessed/manually constructed symbolic path.
    public = [{"instance": x["instance"], "confirmedTarget": x["instance"].upper() == TARGET}
              for x in devices]
    if not args.print_once:
        print(json.dumps({"readOnly": True, "devices": public}, indent=2))
        return 0
    root = Path(__file__).resolve().parent.parent / "build"
    if args.evidence is None:
        parser.error("--evidence under this repository build/ is required")
    evidence = args.evidence.resolve()
    if not evidence.is_relative_to(root.resolve()):
        parser.error("Evidence must be within this repository build/")
    if sum(x["confirmedTarget"] for x in public) != 1:
        raise SystemExit("Confirmed printer unavailable; nothing sent")
    evidence.mkdir(parents=True, exist_ok=True)
    marker = evidence / "print-attempt.json"
    report = {"timeUtc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "devices": public, "state": "attempting", "payload": "fixed_public_sample",
              "paper": "NOT_VERIFIED", "androidOtg": "NOT_TESTED", "automaticRetry": False}
    # Exclusive creation prevents a prior ambiguous attempt being replayed.
    with marker.open("x", encoding="utf-8") as output:
        json.dump(report, output, indent=2)
    try:
        done = subprocess.run([sys.executable, __file__, "--child-write"],
                              capture_output=True, text=True, timeout=12)
        if done.stdout.strip():
            report.update(json.loads(done.stdout))
        else:
            report.update(state="ambiguous", childExit=done.returncode)
    except subprocess.TimeoutExpired:
        report["state"] = "ambiguous_timeout_no_retry"
    finally:
        marker.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0 if report["state"] == "submitted" else 3


if __name__ == "__main__":
    raise SystemExit(main())
