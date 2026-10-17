package com.example.kasir_platform;

import java.util.Locale;

/** A document display title must never be interpreted as a filesystem path. */
final class DocumentExportName {
    static String checked(String proposed, String fallback) {
        String name = proposed == null ? fallback : proposed;
        String extension = ".kasirbackup";
        if (!name.equals(name.trim()) || name.length() > 128 ||
                !name.toLowerCase(Locale.ROOT).endsWith(extension)) {
            throw new IllegalArgumentException("Invalid archive name");
        }
        String stem = name.substring(0, name.length() - extension.length());
        if (stem.trim().isEmpty() || stem.startsWith(".") || stem.endsWith(".")) {
            throw new IllegalArgumentException("Invalid archive name");
        }
        for (int i = 0; i < name.length(); i++) {
            char c = name.charAt(i);
            if (c < 32 || c == 127 || "<>:\"/\\|?*".indexOf(c) >= 0) {
                throw new IllegalArgumentException("Invalid archive name");
            }
        }
        return name;
    }
}
