package com.example.kasir_platform;

import java.io.IOException;
import java.util.concurrent.*;
import org.junit.Test;
import static org.junit.Assert.*;

public final class UsbPrinterIoTest {
    @Test public void detachCloseFailureDoesNotEscapeOrRetry(){
        Link link=new Link(){public void close(){closes++;throw new IllegalStateException("PUBLIC detached service");}};
        UsbPrinterIo io=new UsbPrinterIo(link);io.close();io.close();
        assertFalse(io.ready());assertEquals(1,link.closes);assertEquals(0,link.calls);
    }
    @Test public void denialOnlyRepromptsForExplicitRetryOrNewAttachment(){
        UsbPermissionGate gate=new UsbPermissionGate();
        assertTrue(gate.request("fixture-A",false));
        for(int i=0;i<4;i++)assertFalse(gate.request("fixture-A",false));
        assertTrue(gate.request("fixture-A",true));
        assertFalse(gate.request("fixture-A",false));
        assertTrue(gate.request("fixture-B",false));
        gate.detached("fixture-A");assertTrue(gate.request("fixture-A",false));
    }
    private static class Link implements UsbPrinterIo.Link {
        boolean permitted=true, present=true; int result=4, calls=0, closes=0, timeout;
        public boolean presentAndPermitted(){return permitted&&present;}
        public int transfer(byte[] bytes,int value){calls++;timeout=value;return result;}
        public void close(){closes++;}
    }
    @Test public void descriptorAllowListRejectsNonPrintersSerialAndAmbiguousEndpoints(){
        assertTrue(UsbPrinterIo.supported(7,1,1,0,1));
        assertTrue(UsbPrinterIo.supported(7,1,2,0,1));
        assertFalse(UsbPrinterIo.supported(255,1,2,0,1));
        assertFalse(UsbPrinterIo.supported(7,2,2,0,1));
        assertFalse(UsbPrinterIo.supported(7,1,3,0,1));
        assertFalse(UsbPrinterIo.supported(7,1,2,1,1));
        assertFalse(UsbPrinterIo.supported(7,1,2,0,0));
        assertFalse(UsbPrinterIo.supported(7,1,2,0,2));
    }
    @Test public void deniedAndDetachedNeverCallTransfer() throws Exception {
        for(boolean denial:new boolean[]{true,false}){
            Link link=new Link();if(denial)link.permitted=false;else link.present=false;
            UsbPrinterIo io=new UsbPrinterIo(link);
            assertThrows(IOException.class,()->io.write(new byte[4]));
            assertEquals(0,link.calls);assertEquals(1,link.closes);
        }
    }
    @Test public void shortZeroAndTimeoutCloseWithoutRetry() throws Exception {
        for(int result:new int[]{-1,0,1,3}){
            Link link=new Link();link.result=result;UsbPrinterIo io=new UsbPrinterIo(link);
            assertThrows(IOException.class,()->io.write(new byte[4]));
            assertThrows(IOException.class,()->io.write(new byte[4]));
            assertEquals(1,link.calls);assertEquals(1,link.closes);assertEquals(5000,link.timeout);
        }
    }
    @Test public void detachDuringWriteIsAmbiguousEvenIfAllBytesAccepted() throws Exception {
        Link link=new Link(){public int transfer(byte[] bytes,int timeout){calls++;present=false;return bytes.length;}};
        UsbPrinterIo io=new UsbPrinterIo(link);
        assertThrows(IOException.class,()->io.write(new byte[4]));
        assertEquals(1,link.calls);assertEquals(1,link.closes);
    }
    @Test public void invalidChunksNeverWriteAndSuccessfulChunkDoesNotClose() throws Exception {
        Link link=new Link();UsbPrinterIo io=new UsbPrinterIo(link);
        for(int length:new int[]{0,4097})assertThrows(IOException.class,()->io.write(new byte[length]));
        assertEquals(0,link.calls);io.write(new byte[4]);assertEquals(1,link.calls);
        assertTrue(io.ready());assertEquals(0,link.closes);io.close();io.close();assertEquals(1,link.closes);
    }
    @Test public void detachCanCloseWhileTransferIsBlocked() throws Exception {
        CountDownLatch started=new CountDownLatch(1),closed=new CountDownLatch(1);
        Link link=new Link(){
            public int transfer(byte[] bytes,int timeout){started.countDown();try{if(!closed.await(2,TimeUnit.SECONDS))throw new AssertionError("detach blocked");}catch(InterruptedException error){throw new AssertionError(error);}return -1;}
            public void close(){closes++;closed.countDown();}
        };
        UsbPrinterIo io=new UsbPrinterIo(link);ExecutorService pool=Executors.newSingleThreadExecutor();
        try{Future<?> task=pool.submit(()->{assertThrows(IOException.class,()->io.write(new byte[4]));});
            assertTrue(started.await(2,TimeUnit.SECONDS));io.close();task.get(2,TimeUnit.SECONDS);assertEquals(1,link.closes);
        }finally{pool.shutdownNow();}
    }
}
