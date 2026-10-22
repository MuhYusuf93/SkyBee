package com.example.kasir_platform;

import java.util.HashSet;
import java.util.Set;

/** Per-attachment denial history; retry is an explicit UI action, never resume. */
final class UsbPermissionGate {
    private final Set<String> requested = new HashSet<>();
    synchronized boolean request(String attachment, boolean retry) {
        if (requested.contains(attachment) && !retry) return false;
        requested.add(attachment); return true;
    }
    synchronized void detached(String attachment) { requested.remove(attachment); }
}
