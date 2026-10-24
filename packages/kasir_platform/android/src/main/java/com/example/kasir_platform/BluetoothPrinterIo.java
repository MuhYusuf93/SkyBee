package com.example.kasir_platform;

import java.io.IOException;
import java.io.OutputStream;
import java.util.concurrent.atomic.AtomicBoolean;

/** Bounded SPP submission for ESC/POS receivers with small input buffers.
 * Android flush is not a printer acknowledgment. Pace writes and leave a
 * final delivery interval before close; never retry partially accepted bytes.
 * Policy is independent of printer name/model and never sends status/text.
 */
final class BluetoothPrinterIo {
    interface Link {
        boolean connected();
        OutputStream output() throws IOException;
        void close() throws IOException;
    }
    interface Wait { void pause(long millis) throws InterruptedException; }
    private final Link link;
    private final Wait wait;
    private final AtomicBoolean closed = new AtomicBoolean();
    BluetoothPrinterIo(Link link) { this(link, Thread::sleep); }
    BluetoothPrinterIo(Link link, Wait wait) { this.link=link; this.wait=wait; }
    private void ready() throws IOException {
        if (closed.get() || !link.connected()) throw new IOException("Printer disconnected");
    }
    private void pause(long millis) throws IOException {
        try { wait.pause(millis); }
        catch (InterruptedException error) {
            Thread.currentThread().interrupt();
            throw new IOException("Printer transfer interrupted", error);
        }
        ready();
    }
    synchronized void write(byte[] bytes) throws IOException {
        if (bytes==null || bytes.length==0 || bytes.length>4096) throw new IOException("Invalid Bluetooth chunk");
        try {
            ready();
            OutputStream stream=link.output();
            for (int at=0; at<bytes.length; at+=256) {
                ready();
                stream.write(bytes,at,Math.min(256,bytes.length-at));
                stream.flush();
                pause(40);
            }
        } catch (IOException | RuntimeException error) {
            close(); throw error;
        }
    }
    synchronized void finish() throws IOException {
        try {
            ready(); link.output().flush(); pause(400);
        } catch (IOException | RuntimeException error) {
            close(); throw error;
        }
    }
    // Cancellation/detach must interrupt a blocked writer without its monitor.
    void close() {
        if (closed.compareAndSet(false,true)) {
            try { link.close(); } catch (IOException | RuntimeException ignored) { }
        }
    }
}
