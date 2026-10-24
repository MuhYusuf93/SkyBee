package com.example.kasir_platform;

import java.io.*;
import java.util.*;
import java.util.concurrent.*;
import org.junit.Test;
import static org.junit.Assert.*;

public final class BluetoothPrinterIoTest {
    /** A delayed SPP link feeding a 512-byte receiver. Android acceptance can
     * precede delivery; close discards pending packets. No brand assumptions. */
    private static final class Receiver implements BluetoothPrinterIo.Link, BluetoothPrinterIo.Wait {
        long now; boolean connected=true; int dropped,calls;
        final Queue<Integer> fifo=new ArrayDeque<>();
        final Queue<Packet> pending=new ArrayDeque<>();
        final ByteArrayOutputStream printed=new ByteArrayOutputStream();
        record Packet(long due,byte[] bytes) {}
        final OutputStream stream=new OutputStream(){
            public void write(int b) {write(new byte[]{(byte)b},0,1);}
            public void write(byte[] bytes,int at,int length){
                calls++;pending.add(new Packet(now+100,Arrays.copyOfRange(bytes,at,at+length)));
            }
        };
        public boolean connected(){return connected;}
        public OutputStream output(){return stream;}
        public void close(){connected=false;for(Packet p:pending)dropped+=p.bytes.length;pending.clear();}
        public void pause(long millis){
            for(int t=0;t<millis;t++){
                now++;
                while(!pending.isEmpty()&&pending.peek().due<=now){
                    for(byte b:pending.remove().bytes){if(fifo.size()<512)fifo.add(b&255);else dropped++;}
                }
                for(int n=0;n<8&&!fifo.isEmpty();n++)printed.write(fifo.remove());
            }
        }
    }
    private static byte[] payload(int count){byte[] b=new byte[count];for(int i=0;i<count;i++)b[i]=(byte)(i*37);return b;}
    @Test public void unpacedBurstCanCorruptBinaryAtSmallReceiver() throws Exception {
        Receiver r=new Receiver();byte[] bytes=payload(4096);
        r.output().write(bytes);r.pause(1000);
        assertTrue(r.dropped>0);assertFalse(Arrays.equals(bytes,r.printed.toByteArray()));
    }
    @Test public void pacedDocumentsPreserveAllBinaryBytesAndDrainBeforeClose() throws Exception {
        for(int width:new int[]{384,576,640}){
            Receiver r=new Receiver();BluetoothPrinterIo io=new BluetoothPrinterIo(r,r);
            byte[] bytes=payload(width*40+17);
            for(int at=0;at<bytes.length;at+=4096)io.write(Arrays.copyOfRange(bytes,at,Math.min(at+4096,bytes.length)));
            io.finish();io.close();r.pause(1000);
            assertEquals(0,r.dropped);assertArrayEquals(bytes,r.printed.toByteArray());
        }
    }
    @Test public void closingWithoutDocumentFinishLosesTheTail() throws Exception {
        Receiver r=new Receiver();BluetoothPrinterIo io=new BluetoothPrinterIo(r,r);
        byte[] bytes=payload(4000);io.write(bytes);io.close();r.pause(1000);
        assertTrue(r.dropped>0);assertFalse(Arrays.equals(bytes,r.printed.toByteArray()));
    }
    @Test public void interruptionClosesAndDoesNotRetryAcceptedBytes() throws Exception {
        Receiver r=new Receiver();BluetoothPrinterIo io=new BluetoothPrinterIo(r,millis->{throw new InterruptedException();});
        try {
            assertThrows(IOException.class,()->io.write(payload(1000)));
            assertFalse(r.connected);assertEquals(1,r.calls);
            assertThrows(IOException.class,()->io.write(payload(1000)));assertEquals(1,r.calls);
        } finally {Thread.interrupted();}
    }
    @Test public void invalidInputNeverWritesAndDisconnectedFinishFails() {
        Receiver r=new Receiver();BluetoothPrinterIo io=new BluetoothPrinterIo(r,r);
        for(int size:new int[]{0,4097})assertThrows(IOException.class,()->io.write(new byte[size]));
        assertEquals(0,r.calls);io.close();assertThrows(IOException.class,io::finish);
    }
    @Test public void closeUnblocksAWriteWithoutWaitingForItsMonitor() throws Exception {
        CountDownLatch started=new CountDownLatch(1),closed=new CountDownLatch(1);
        BluetoothPrinterIo.Link link=new BluetoothPrinterIo.Link(){
            public boolean connected(){return closed.getCount()!=0;}
            public OutputStream output(){return new OutputStream(){
                public void write(int value) throws IOException{
                    started.countDown();
                    try {if(!closed.await(2,TimeUnit.SECONDS))throw new AssertionError("close blocked");}
                    catch(InterruptedException e){throw new IOException(e);}
                    throw new IOException("PUBLIC disconnect");
                }
            };}
            public void close(){closed.countDown();}
        };
        BluetoothPrinterIo io=new BluetoothPrinterIo(link,millis->{});
        ExecutorService pool=Executors.newSingleThreadExecutor();
        try {
            Future<?> task=pool.submit(()->assertThrows(IOException.class,()->io.write(new byte[]{1})));
            assertTrue(started.await(2,TimeUnit.SECONDS));io.close();task.get(2,TimeUnit.SECONDS);
        } finally {pool.shutdownNow();}
    }
}
