package com.example.kasir_platform;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.provider.DocumentsContract;
import io.flutter.plugin.common.MethodChannel;
import java.io.*;
import java.security.MessageDigest;
import java.util.Arrays;
import java.util.UUID;
import java.util.concurrent.Executor;
import android.os.Handler;
import android.os.Looper;

/** Storage Access Framework only. Data is encrypted before the picker. Export
 * is not successful until writing, closing and re-reading match; a provider
 * which cannot support readback is reported as failed, never a verified backup.
 */
final class DocumentPicker {
    static final int REQUEST=59305;
    private Activity activity;
    private MethodChannel.Result pending;
    private File file;
    private boolean export;
    private long maximumBytes=Long.MAX_VALUE;
    private final Executor io;
    private final Handler main=new Handler(Looper.getMainLooper());
    DocumentPicker(Executor io){this.io=io;}
    void attach(Activity activity){this.activity=activity;}
    void detach(){activity=null;if(pending!=null){pending.error("picker_interrupted","Picker interrupted; no restore performed.",null);pending=null;}}
    void pick(MethodChannel.Result result,boolean export,File file,String mime,Long maxBytes,String displayName) {
        if(activity==null||pending!=null){result.error("picker_unavailable","Foreground picker unavailable.",null);return;}
        if(mime!=null&&!mime.equals("image/*")&&!mime.equals("application/octet-stream")){result.error("picker_invalid","Unsupported document type.",null);return;}
        String title=null;
        if(export){
            try{title=DocumentExportName.checked(displayName,file.getName());}
            catch(IllegalArgumentException error){result.error("document_name_invalid","Invalid archive display name.",null);return;}
        }
        this.pending=result;this.export=export;this.file=file;this.maximumBytes=maxBytes==null?Long.MAX_VALUE:maxBytes;
        Intent intent=new Intent(export?Intent.ACTION_CREATE_DOCUMENT:Intent.ACTION_OPEN_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);intent.setType(mime==null?"application/octet-stream":mime);
        if(export)intent.putExtra(Intent.EXTRA_TITLE,title);
        try{activity.startActivityForResult(intent,REQUEST);}catch(Exception e){pending=null;result.error("picker_unavailable","No document provider available.",null);}
    }
    boolean result(int request,int code,Intent data) {
        if(request!=REQUEST||pending==null)return false;
        MethodChannel.Result result=pending;pending=null;
        if(code!=Activity.RESULT_OK||data==null||data.getData()==null){result.success(null);return true;}
        Uri uri=data.getData();Activity owner=activity;
        if(owner==null){result.error("picker_interrupted","Picker interrupted.",null);return true;}
        final boolean writing=export;final File target=file;final long maximum=maximumBytes;
        io.execute(()->{
            try{
                if(writing){
                    byte[] expected;
                    try(InputStream source=new FileInputStream(target);OutputStream output=owner.getContentResolver().openOutputStream(uri,"wt")){
                        if(output==null)throw new IOException("Provider refused output");expected=copy(source,output,Long.MAX_VALUE);output.flush();
                    }
                    byte[] actual;
                    try(InputStream source=owner.getContentResolver().openInputStream(uri)){
                        if(source==null)throw new IOException("Provider refused verification");actual=copy(source,new OutputStream(){@Override public void write(int b){} @Override public void write(byte[] b,int offset,int length){}},target.length());
                    }
                    if(!Arrays.equals(expected,actual))throw new IOException("Document verification failed");
                    main.post(()->result.success(true));
                }else{
                    if(target.exists())throw new IOException("Staging file exists");
                    long budget=Math.min(maximum,target.getParentFile().getUsableSpace()-33554432);
                    try(InputStream source=owner.getContentResolver().openInputStream(uri);FileOutputStream output=new FileOutputStream(target)){
                        if(source==null)throw new IOException("Provider refused input");copy(source,output,budget);output.getFD().sync();
                    }
                    main.post(()->result.success(target.getPath()));
                }
            }catch(Exception error){
                if(!writing)target.delete();
                // Delete only the newly selected CREATE_DOCUMENT output, never
                // a source document or anything outside this user-chosen URI.
                if(writing)try{DocumentsContract.deleteDocument(owner.getContentResolver(),uri);}catch(Exception ignored){}
                main.post(()->result.error("document_io_failed","Document operation failed; not a completed backup or restore.",null));
            }
        });return true;
    }
    private static byte[] copy(InputStream source,OutputStream target,long budget)throws Exception{
        MessageDigest hash=MessageDigest.getInstance("SHA-256");byte[] buffer=new byte[65536];long total=0;int n;
        while((n=source.read(buffer))!=-1){total+=n;if(total>budget)throw new IOException("Document exceeds storage budget");target.write(buffer,0,n);hash.update(buffer,0,n);}
        Arrays.fill(buffer,(byte)0);return hash.digest();
    }
}
