package com.example.kasir_platform;

import java.io.IOException;
import java.util.concurrent.atomic.AtomicBoolean;

/** One selected interface, bounded writes, no retry or transport fallback. A
 * short/error transfer may already have reached the printer and is ambiguous.
 * The production bridge and JVM fault tests use this same ownership boundary.
 */
final class UsbPrinterIo {
    interface Link {
        boolean presentAndPermitted();
        int transfer(byte[] bytes, int timeoutMillis);
        void close();
    }
    private final Link link;
    private final AtomicBoolean closed = new AtomicBoolean();
    UsbPrinterIo(Link link) { this.link = link; }
    static boolean supported(int deviceClass, int subclass, int protocol,
                             int alternate, int bulkOutCount) {
        return deviceClass == 7 && subclass == 1 && (protocol == 1 || protocol == 2)
            && alternate == 0 && bulkOutCount == 1;
    }
    boolean ready() { return !closed.get() && link.presentAndPermitted(); }
    synchronized void write(byte[] bytes) throws IOException {
        if (bytes == null || bytes.length == 0 || bytes.length > 4096)
            throw new IOException("usb_invalid_chunk");
        if (!ready()) { close(); throw new IOException("usb_not_connected"); }
        try {
            int sent = link.transfer(bytes, 5000);
            if (sent != bytes.length || !ready()) throw new IOException("usb_transfer_unknown");
        } catch (RuntimeException error) {
            close(); throw new IOException("usb_transfer_unknown");
        } catch (IOException error) { close(); throw error; }
    }
    // Must not acquire write's monitor: detach can interrupt a blocked transfer.
    void close() {
        if (closed.compareAndSet(false, true)) {
            try { link.close(); } catch (RuntimeException ignored) {
                // A disappearing USB service/FD must not crash the detach
                // receiver or replace an already ambiguous delivery outcome.
            }
        }
    }
}
