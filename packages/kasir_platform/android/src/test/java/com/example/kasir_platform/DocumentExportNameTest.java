package com.example.kasir_platform;

import org.junit.Test;
import static org.junit.Assert.*;

public final class DocumentExportNameTest {
    @Test public void proposedNamesAreMetadataAndLegacyFallbackStillWorks() {
        assertEquals("Toko 名 17.kasirbackup", DocumentExportName.checked("Toko 名 17.kasirbackup", "original.kasirbackup"));
        assertEquals("original.kasirbackup", DocumentExportName.checked(null, "original.kasirbackup"));
    }
    @Test public void rejectsPathsControlsAndWrongArchiveExtensions() {
        for(String name: new String[]{"../escape.kasirbackup", "C:\\backup.kasirbackup", "x/y.kasirbackup", "name\n.kasirbackup", ".kasirbackup", " .kasirbackup", "name.exe", "x".repeat(129)+".kasirbackup", "name..kasirbackup"}) {
            assertThrows(name, IllegalArgumentException.class, () -> DocumentExportName.checked(name, "unused.kasirbackup"));
        }
    }
}
