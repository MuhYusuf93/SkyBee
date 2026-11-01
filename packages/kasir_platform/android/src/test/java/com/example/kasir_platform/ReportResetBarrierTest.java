package com.example.kasir_platform;

import org.junit.Test;
import static org.junit.Assert.*;
import java.util.concurrent.*;

public final class ReportResetBarrierTest {
    @Test public void pauseBlocksNewWritersAcrossOwnersUntilExactLeaseResumes()throws Exception{
        ReportResetBarrier gate=new ReportResetBarrier();
        assertTrue(gate.beginWrite());
        String token=gate.pause();
        assertTrue(gate.paused());assertFalse(gate.beginWrite());
        assertFalse(gate.awaitDrain(token,1));
        gate.endWrite();assertTrue(gate.awaitDrain(token,1));
        assertFalse(gate.beginWrite());gate.resume(token);
        assertTrue(gate.beginWrite());gate.endWrite();
    }
    @Test public void timeoutDoesNotReopenAdmissionOrPretendOldStreamClosed()throws Exception{
        ReportResetBarrier gate=new ReportResetBarrier();gate.beginWrite();String token=gate.pause();
        assertFalse(gate.awaitDrain(token,1));assertTrue(gate.paused());assertFalse(gate.beginWrite());
        gate.endWrite();assertTrue(gate.awaitDrain(token,1));gate.resume(token);
    }
    @Test public void drainWaitsForEveryStreamFinally()throws Exception{
        ReportResetBarrier gate=new ReportResetBarrier();gate.beginWrite();gate.beginWrite();String token=gate.pause();
        ExecutorService executor=Executors.newSingleThreadExecutor();
        try{
            Future<Boolean> done=executor.submit(()->gate.awaitDrain(token,5000));
            gate.endWrite();assertFalse(gate.awaitDrain(token,1));
            gate.endWrite();assertTrue(done.get(5,TimeUnit.SECONDS));
        }finally{executor.shutdownNow();gate.resume(token);}
    }
    @Test public void staleOrForeignLeaseCannotReopenAnotherReset(){
        ReportResetBarrier gate=new ReportResetBarrier();String old=gate.pause();gate.resume(old);String current=gate.pause();
        assertThrows(IllegalArgumentException.class,()->gate.resume(old));assertTrue(gate.paused());
        assertThrows(IllegalStateException.class,gate::pause);gate.resume(current);
        assertThrows(IllegalStateException.class,gate::endWrite);
    }
}
