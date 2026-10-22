package com.example.kasir_platform;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.*;
import android.content.pm.PackageManager;
import android.hardware.usb.*;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.*;
import java.util.concurrent.*;

/** Android Host API, printer class 7/1 protocol 1 or 2 only. No vendor serial
 * emulation, force-claim, auto launch, global USB settings or automatic send.
 * A missing/duplicate serial gives an attachment-only identity: the user must
 * reselect after detach/restart rather than risk sending to a similar printer.
 */
final class PrinterUsb {
    private record Choice(UsbDevice device, UsbInterface intf, UsbEndpoint out) {}
    private final Context context;
    private final UsbManager manager;
    private final Executor executor;
    private final Handler main = new Handler(Looper.getMainLooper());
    private final Map<String,String> attachments = new HashMap<>();
    private final UsbPermissionGate permissionGate = new UsbPermissionGate();
    private final String permissionAction;
    private Activity activity;
    private CompletableFuture<Boolean> pending;
    private Choice pendingChoice;
    private String pendingAttachment;
    private String pendingNonce;
    private PendingIntent permissionIntent;
    private volatile UsbPrinterIo link;
    private volatile Choice connected;
    private volatile String connectedId;
    private volatile boolean disposed;

    PrinterUsb(Context context, Executor executor) {
        this.context = context; this.executor = executor;
        manager = (UsbManager)context.getSystemService(Context.USB_SERVICE);
        permissionAction = context.getPackageName()+".USB_PERMISSION."+UUID.randomUUID();
        IntentFilter filter = new IntentFilter(permissionAction);
        filter.addAction(UsbManager.ACTION_USB_DEVICE_DETACHED);
        if (Build.VERSION.SDK_INT >= 33) context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED);
        else context.registerReceiver(receiver, filter);
    }
    void attach(Activity value) { activity = value; }
    void detach() { activity = null; finishPermission(false); }
    private boolean available() { return manager != null && context.getPackageManager().hasSystemFeature(PackageManager.FEATURE_USB_HOST); }
    private static String key(UsbDevice d) { return d.getDeviceName()+":"+d.getDeviceId(); }
    private synchronized String attachment(UsbDevice d) {
        return attachments.computeIfAbsent(key(d), ignored -> UUID.randomUUID().toString());
    }
    private boolean present(UsbDevice d) {
        if (manager == null) return false;
        UsbDevice now = manager.getDeviceList().get(d.getDeviceName());
        return now != null && now.getDeviceId() == d.getDeviceId()
            && now.getVendorId() == d.getVendorId() && now.getProductId() == d.getProductId();
    }
    private List<Choice> choices() throws IOException {
        if (!available()) return List.of();
        var devices = manager.getDeviceList();
        if (devices.size() > 128) throw new IOException("usb_descriptor_limit");
        List<Choice> rows = new ArrayList<>();
        for (UsbDevice d : devices.values()) {
            if (d.getInterfaceCount() > 32) continue;
            for (int i=0;i<d.getInterfaceCount();i++) {
                UsbInterface intf=d.getInterface(i);
                if (intf.getEndpointCount()>32) continue;
                UsbEndpoint out=null; int count=0;
                for(int j=0;j<intf.getEndpointCount();j++) {
                    UsbEndpoint endpoint=intf.getEndpoint(j);
                    if(endpoint.getDirection()==UsbConstants.USB_DIR_OUT && endpoint.getType()==UsbConstants.USB_ENDPOINT_XFER_BULK) { out=endpoint; count++; }
                }
                if(UsbPrinterIo.supported(intf.getInterfaceClass(),intf.getInterfaceSubclass(),intf.getInterfaceProtocol(),intf.getAlternateSetting(),count)) rows.add(new Choice(d,intf,out));
            }
        }
        return rows;
    }
    private String sessionId(Choice c) { return "usb:t:"+attachment(c.device)+":"+c.intf.getId(); }
    private String serialId(Choice c) {
        try {
            if(!manager.hasPermission(c.device)) return null;
            String serial=c.device.getSerialNumber();
            if(serial==null||serial.isBlank()||serial.length()>512) return null;
            if(serial.length()<4||serial.matches("^(.)\\1+$")||Set.of("USB001","1234567890","123456789").contains(serial.toUpperCase(Locale.ROOT)))return null;
            byte[] digest=MessageDigest.getInstance("SHA-256").digest(serial.getBytes(StandardCharsets.UTF_8));
            StringBuilder hex=new StringBuilder();for(byte b:digest)hex.append(String.format(Locale.ROOT,"%02x",b&255));
            return String.format(Locale.ROOT,"usb:s:%04x:%04x:%s:%d",c.device.getVendorId(),c.device.getProductId(),hex,c.intf.getId());
        } catch(Exception error) { return null; }
    }
    private String canonical(Choice c,List<Choice> all) {
        String serial=serialId(c);
        if(serial==null) return sessionId(c);
        int matches=0; for(Choice candidate:all)if(serial.equals(serialId(candidate)))matches++;
        return matches==1?serial:sessionId(c);
    }
    private Choice resolve(String id) throws IOException {
        if(id==null||id.length()>180||!id.startsWith("usb:")) throw new IOException("usb_device_invalid");
        List<Choice> all=choices(); Choice match=null;
        for(Choice c:all)if(id.equals(sessionId(c))||id.equals(canonical(c,all))) {
            if(match!=null)throw new IOException("usb_device_ambiguous");match=c;
        }
        if(match==null)throw new IOException("usb_device_missing");
        return match;
    }
    List<Map<String,Object>> devices() throws IOException {
        List<Choice> all=choices(); List<Map<String,Object>> rows=new ArrayList<>();
        for(Choice c:all) {
            String id=canonical(c,all), name=c.device.getProductName();
            if(name==null||name.isBlank())name="USB printer";
            if(name.length()>200)name=name.substring(0,200);
            Map<String,Object> row=new HashMap<>();
            row.put("id",id);row.put("name",name);row.put("transport","usb");
            row.put("vendorId",c.device.getVendorId());row.put("productId",c.device.getProductId());
            row.put("interface",c.intf.getId());row.put("permission",manager.hasPermission(c.device));
            row.put("sessionOnly",id.startsWith("usb:t:"));rows.add(row);
        }
        rows.sort(Comparator.comparing(row->(String)row.get("id")));return rows;
    }
    String identity(String id) throws IOException {
        Choice c=resolve(id);
        if(!manager.hasPermission(c.device))throw new IOException("usb_permission_denied");
        return canonical(c,choices());
    }
    // Called on main thread. Each attachment is prompted at most once unless
    // the user explicitly chooses retry; denial never loops management PIN.
    CompletableFuture<Boolean> permission(String id,boolean retry) throws IOException {
        Choice c=resolve(id);
        if(manager.hasPermission(c.device))return CompletableFuture.completedFuture(true);
        if(activity==null||!activity.hasWindowFocus()||pending!=null)throw new IOException("usb_permission_unavailable");
        String token=attachment(c.device);
        if(!permissionGate.request(token,retry))return CompletableFuture.completedFuture(false);
        CompletableFuture<Boolean> result=new CompletableFuture<>();pending=result;pendingChoice=c;pendingAttachment=token;
        pendingNonce=UUID.randomUUID().toString();
        permissionIntent=PendingIntent.getBroadcast(context,0,new Intent(permissionAction).setPackage(context.getPackageName()).putExtra("request",pendingNonce),PendingIntent.FLAG_IMMUTABLE|PendingIntent.FLAG_CANCEL_CURRENT);
        try{manager.requestPermission(c.device,permissionIntent);}catch(RuntimeException error){finishPermission(false);throw new IOException("usb_permission_unavailable");}
        main.postDelayed(()->{if(pending==result)finishPermission(false);},20000);
        return result;
    }
    private void finishPermission(boolean granted) {
        CompletableFuture<Boolean> result=pending;pending=null;pendingChoice=null;pendingAttachment=null;pendingNonce=null;
        if(permissionIntent!=null){permissionIntent.cancel();permissionIntent=null;}
        if(result!=null)result.complete(granted);
    }
    private final BroadcastReceiver receiver=new BroadcastReceiver(){
        @Override public void onReceive(Context c,Intent intent){
            if(permissionAction.equals(intent.getAction())) {
                if(pendingNonce==null||!pendingNonce.equals(intent.getStringExtra("request")))return;
                Choice expected=pendingChoice;
                // Do not trust broadcast extras; immutable PendingIntent may
                // omit them. Check the actual selected attachment and OS grant.
                boolean granted=expected!=null&&present(expected.device)
                    &&attachment(expected.device).equals(pendingAttachment)&&manager.hasPermission(expected.device);
                finishPermission(granted);
            } else if(UsbManager.ACTION_USB_DEVICE_DETACHED.equals(intent.getAction())) {
                UsbDevice d=intent.getParcelableExtra(UsbManager.EXTRA_DEVICE);
                if(d==null)return;
                synchronized(PrinterUsb.this){String token=attachments.remove(key(d));if(token!=null)permissionGate.detached(token);}
                if(pendingChoice!=null&&key(pendingChoice.device).equals(key(d)))finishPermission(false);
                Choice current=connected;
                if(current!=null&&key(current.device).equals(key(d))) {
                    UsbPrinterIo stale=link; link=null;connected=null;connectedId=null;
                    if(stale!=null)executor.execute(stale::close);
                }
            }
        }
    };
    void connect(String id) throws IOException {
        Choice c=resolve(id);
        if(!manager.hasPermission(c.device))throw new IOException("usb_permission_denied");
        disconnect();
        UsbDeviceConnection conn=manager.openDevice(c.device);
        if(conn==null)throw new IOException("usb_open_failed");
        boolean claimed=false;
        try {
            // false never detaches a kernel/system driver to force ownership.
            if(!conn.claimInterface(c.intf,false))throw new IOException("usb_interface_busy");
            claimed=true;
            if(!present(c.device)||!manager.hasPermission(c.device)||disposed)throw new IOException("usb_device_missing");
            UsbPrinterIo fresh=new UsbPrinterIo(new UsbPrinterIo.Link(){
                public boolean presentAndPermitted(){return !disposed&&present(c.device)&&manager.hasPermission(c.device);}
                public int transfer(byte[] bytes,int timeout){return conn.bulkTransfer(c.out,bytes,bytes.length,timeout);}
                public void close(){try{conn.releaseInterface(c.intf);}finally{conn.close();}}
            });
            connected=c;connectedId=canonical(c,choices());link=fresh;
            if(!fresh.ready()){disconnect();throw new IOException("usb_device_missing");}
        } catch(Exception error) {
            if(claimed)try{conn.releaseInterface(c.intf);}catch(Exception ignored){}
            conn.close();throw new IOException(error instanceof IOException?error.getMessage():"usb_open_failed");
        }
    }
    void write(byte[] bytes) throws IOException { UsbPrinterIo current=link;if(current==null)throw new IOException("usb_not_connected");current.write(bytes); }
    void disconnect(){UsbPrinterIo previous=link;link=null;connected=null;connectedId=null;if(previous!=null)previous.close();}
    Map<String,Object> status() {
        UsbPrinterIo current=link;boolean ready=current!=null&&current.ready();
        Map<String,Object> value=new HashMap<>();value.put("available",available());value.put("enabled",available());value.put("connected",ready);
        if(ready&&connectedId!=null)value.put("device",connectedId);return value;
    }
    void dispose(){disposed=true;detach();disconnect();try{context.unregisterReceiver(receiver);}catch(IllegalArgumentException ignored){}}
}
