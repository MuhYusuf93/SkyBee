package com.example.kasir_platform;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.provider.DocumentsContract;
import io.flutter.plugin.common.MethodChannel;
import java.io.*;
import java.security.MessageDigest;
import java.util.*;
import java.util.concurrent.Executor;

/** A reset barrier spans all Flutter engines in this process. Cancellation is
 * followed by a bounded drain of streams; a timeout aborts reset, never asserts
 * that merely marking a target cancelled closed its file descriptors.
 */
final class ReportDocumentExport {
    static final int REQUEST=59306;
    private static final Object LOCK=new Object();
    private static final Set<ReportDocumentExport> INSTANCES=Collections.newSetFromMap(new WeakHashMap<>());
    private static final ReportResetBarrier BARRIER=new ReportResetBarrier();
    private Activity activity;
    private String ownedPause;
    private MethodChannel.Result pending;
    private final Executor io;
    private final Handler main=new Handler(Looper.getMainLooper());
    private final Map<String,Target> targets=new HashMap<>();
    private static final class Target {
        final Activity owner; final Uri uri; final long deadline=SystemClock.elapsedRealtime()+120000;
        volatile boolean cancelled=false, writing=false;
        Target(Activity owner,Uri uri){this.owner=owner;this.uri=uri;}
        void remove(){try{DocumentsContract.deleteDocument(owner.getContentResolver(),uri);}catch(Exception ignored){}}
    }
    ReportDocumentExport(Executor io){this.io=io;synchronized(LOCK){INSTANCES.add(this);}}
    void attach(Activity owner){activity=owner;}
    private void cancelAll(){
        if(pending!=null){pending.error("report_interrupted","Report selection interrupted.",null);pending=null;}
        for(Target target:new ArrayList<>(targets.values())){target.cancelled=true;if(!target.writing)io.execute(target::remove);}
        targets.clear();
    }
    void detach(){activity=null;cancelAll();}
    void dispose(){detach();synchronized(LOCK){if(ownedPause!=null)resume(ownedPause);}}
    // Method-channel selection/cancellation callbacks execute on Android's main
    // thread. IO only touches volatile Target flags and the guarded writer count.
    void pause(MethodChannel.Result result){
        final String token;
        try{token=BARRIER.pause();}catch(IllegalStateException error){result.error("report_reset_pending","Report reset already pending.",null);return;}
        synchronized(LOCK){
            ownedPause=token;
            for(ReportDocumentExport instance:new ArrayList<>(INSTANCES))instance.cancelAll();
        }
        io.execute(()->{
            boolean drained=false;
            try{
                drained=BARRIER.awaitDrain(token,15000);
            }catch(InterruptedException error){Thread.currentThread().interrupt();}
            catch(IllegalArgumentException abandoned){/* Owning engine was detached. */}
            if(!drained){synchronized(LOCK){if(token.equals(ownedPause))resume(token);}}
            boolean success=drained;
            main.post(()->{if(success)result.success(token);else result.error("report_drain_timeout","Report export did not drain.",null);});
        });
    }
    void resume(String token){synchronized(LOCK){
        if(token==null||!token.equals(ownedPause))throw new IllegalArgumentException();
        BARRIER.resume(token);ownedPause=null;
    }}
    private static boolean paused(){return BARRIER.paused();}
    void choose(MethodChannel.Result result,String name,String mime){
        boolean csv="text/csv".equals(mime), xlsx="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet".equals(mime);
        if(paused()||activity==null||pending!=null||!targets.isEmpty()||!activity.hasWindowFocus()){
            result.error("report_unavailable","Report picker unavailable.",null);return;
        }
        if(name==null||name.length()>100||!name.matches("[A-Za-z0-9_-]+\\.(csv|xlsx)")||(!csv&&!xlsx)||!name.endsWith(csv?".csv":".xlsx")){
            result.error("report_name_invalid","Report name invalid.",null);return;
        }
        pending=result;
        Intent intent=new Intent(Intent.ACTION_CREATE_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType(mime).putExtra(Intent.EXTRA_TITLE,name);
        try{activity.startActivityForResult(intent,REQUEST);}catch(Exception error){pending=null;result.error("report_unavailable","Report picker unavailable.",null);}
    }
    boolean result(int request,int code,Intent data){
        if(request!=REQUEST)return false;
        if(pending==null){
            // A cancelled picker can return a newly created empty document late.
            // It never receives bytes; only that returned target may be removed.
            if(activity!=null&&code==Activity.RESULT_OK&&data!=null&&data.getData()!=null){Target late=new Target(activity,data.getData());io.execute(late::remove);}
            return true;
        }
        MethodChannel.Result result=pending;pending=null;
        if(code!=Activity.RESULT_OK||data==null||data.getData()==null){result.success(null);return true;}
        if(activity==null||paused()){result.error("report_interrupted","Report interrupted.",null);return true;}
        String token=UUID.randomUUID().toString();Target target=new Target(activity,data.getData());targets.put(token,target);
        main.postDelayed(()->{if(targets.get(token)==target&&!target.writing){targets.remove(token);target.cancelled=true;io.execute(target::remove);}},120000);
        result.success(token);return true;
    }
    void cancel(String token){Target target=targets.remove(token);if(target!=null){target.cancelled=true;if(!target.writing)io.execute(target::remove);}}
    void write(MethodChannel.Result result,String token,File file){
        Target target=targets.get(token);
        synchronized(LOCK){
            if(target==null||target.writing||target.cancelled||activity==null||!activity.hasWindowFocus()||SystemClock.elapsedRealtime()>target.deadline){
                cancel(token);result.error("report_expired","Reauthorize report export.",null);return;
            }
            if(!BARRIER.beginWrite()){cancel(token);result.error("report_expired","Reauthorize report export.",null);return;}
            target.writing=true;
        }
        io.execute(()->{
            try{
                if(file.length()==0)throw new IOException();
                byte[] expected,actual;
                try(InputStream input=new FileInputStream(file);OutputStream output=target.owner.getContentResolver().openOutputStream(target.uri,"wt")){
                    if(output==null)throw new IOException();expected=copy(target,input,output,file.length());output.flush();
                }
                try(InputStream input=target.owner.getContentResolver().openInputStream(target.uri)){
                    if(input==null)throw new IOException();actual=copy(target,input,new OutputStream(){public void write(int b){}public void write(byte[] b,int o,int n){}},file.length());
                }
                if(target.cancelled||!Arrays.equals(expected,actual))throw new IOException();
                main.post(()->{targets.remove(token);result.success(true);});
            }catch(Exception error){target.remove();main.post(()->{targets.remove(token);result.error("report_io_failed","Report write or verification failed.",null);});}
            finally{BARRIER.endWrite();}
        });
    }
    private static byte[] copy(Target target,InputStream input,OutputStream output,long maximum)throws Exception{
        MessageDigest hash=MessageDigest.getInstance("SHA-256");byte[] buffer=new byte[65536];long count=0;int n;
        try{while((n=input.read(buffer))!=-1){if(target.cancelled||SystemClock.elapsedRealtime()>target.deadline||(count+=n)>maximum)throw new IOException();output.write(buffer,0,n);hash.update(buffer,0,n);}return hash.digest();}
        finally{Arrays.fill(buffer,(byte)0);}
    }
}
