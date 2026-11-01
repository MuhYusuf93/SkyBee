package com.example.kasir_platform;

import java.util.UUID;
import java.util.concurrent.TimeUnit;

/** Process-wide admission and stream lifetime accounting. Only the holder of
 * an opaque pause token can resume admission. A timeout never means drained.
 */
final class ReportResetBarrier {
    private String lease;
    private int writers;
    synchronized String pause() {
        if(lease!=null)throw new IllegalStateException("Report reset already pending");
        return lease=UUID.randomUUID().toString();
    }
    synchronized boolean paused(){return lease!=null;}
    synchronized boolean beginWrite(){if(lease!=null)return false;writers++;return true;}
    synchronized void endWrite(){if(writers<=0)throw new IllegalStateException("Unbalanced report writer");writers--;notifyAll();}
    synchronized void resume(String token){require(token);lease=null;notifyAll();}
    private void require(String token){if(token==null||!token.equals(lease))throw new IllegalArgumentException("Invalid report reset lease");}
    synchronized boolean awaitDrain(String token,long timeoutMillis)throws InterruptedException {
        require(token);
        long deadline=System.nanoTime()+TimeUnit.MILLISECONDS.toNanos(timeoutMillis);
        while(writers!=0){
            require(token);
            long remaining=deadline-System.nanoTime();
            if(remaining<=0)return false;
            TimeUnit.NANOSECONDS.timedWait(this,remaining);
        }
        require(token);return true;
    }
}
