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

/** Plaintext reports use two phases. A late SAF result only selects an empty
 * destination; Dart must reauthorize after PIN before any report bytes leave.
 * Tokens are engine-local, single-use, expire, and never survive process death.
 */
final class ReportDocumentExport {
    static final int REQUEST=59306;
    private Activity activity;
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
    ReportDocumentExport(Executor io){this.io=io;}
    void attach(Activity owner){activity=owner;}
    void detach(){
        activity=null;
        if(pending!=null){pending.error("report_interrupted","Report selection interrupted.",null);pending=null;}
        for(Target target:new ArrayList<>(targets.values())){target.cancelled=true;if(!target.writing)io.execute(target::remove);}
        targets.clear();
    }
    void choose(MethodChannel.Result result,String name,String mime){
        boolean csv="text/csv".equals(mime), xlsx="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet".equals(mime);
        if(activity==null||pending!=null||!targets.isEmpty()||!activity.hasWindowFocus()){
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
        if(request!=REQUEST||pending==null)return false;
        MethodChannel.Result result=pending;pending=null;
        if(code!=Activity.RESULT_OK||data==null||data.getData()==null){result.success(null);return true;}
        if(activity==null){result.error("report_interrupted","Report interrupted.",null);return true;}
        String token=UUID.randomUUID().toString();Target target=new Target(activity,data.getData());targets.put(token,target);
        main.postDelayed(()->{if(targets.get(token)==target&&!target.writing){targets.remove(token);target.cancelled=true;io.execute(target::remove);}},120000);
        result.success(token);return true;
    }
    void cancel(String token){Target target=targets.remove(token);if(target!=null){target.cancelled=true;if(!target.writing)io.execute(target::remove);}}
    void write(MethodChannel.Result result,String token,File file){
        Target target=targets.get(token);
        if(target==null||target.writing||target.cancelled||activity==null||!activity.hasWindowFocus()||SystemClock.elapsedRealtime()>target.deadline){
            cancel(token);result.error("report_expired","Reauthorize report export.",null);return;
        }
        target.writing=true;
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
                if(!Arrays.equals(expected,actual))throw new IOException();
                main.post(()->{targets.remove(token);result.success(true);});
            }catch(Exception error){target.remove();main.post(()->{targets.remove(token);result.error("report_io_failed","Report write or verification failed.",null);});}
        });
    }
    private static byte[] copy(Target target,InputStream input,OutputStream output,long maximum)throws Exception{
        MessageDigest hash=MessageDigest.getInstance("SHA-256");byte[] buffer=new byte[65536];long count=0;int n;
        try{while((n=input.read(buffer))!=-1){if(target.cancelled||SystemClock.elapsedRealtime()>target.deadline||(count+=n)>maximum)throw new IOException();output.write(buffer,0,n);hash.update(buffer,0,n);}return hash.digest();}
        finally{Arrays.fill(buffer,(byte)0);}
    }
}
