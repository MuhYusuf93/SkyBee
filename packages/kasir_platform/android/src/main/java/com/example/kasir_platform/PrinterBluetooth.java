package com.example.kasir_platform;

import android.bluetooth.*;
import android.content.*;
import android.os.Handler;
import android.os.Looper;
import java.io.*;
import java.util.*;
import java.util.concurrent.*;

/** Android SDK Classic SPP transport. No BLE emulation, background discovery,
 * root, global adapter enable or pairing configuration changes. Each blocking
 * socket operation has a timeout which closes the socket to unblock the writer.
 */
final class PrinterBluetooth {
    private final Context context;
    private final BluetoothAdapter adapter;
    private final Handler main=new Handler(Looper.getMainLooper());
    private final ExecutorService io=Executors.newCachedThreadPool();
    private BluetoothSocket socket;
    private BluetoothPrinterIo writer;
    private CompletableFuture<Map<String,Object>> discovery;
    private final Map<String,Map<String,Object>> found=new LinkedHashMap<>();
    private boolean registered;
    private static final UUID SPP=UUID.fromString("00001101-0000-1000-8000-00805F9B34FB");
    PrinterBluetooth(Context context){this.context=context;BluetoothManager manager=(BluetoothManager)context.getSystemService(Context.BLUETOOTH_SERVICE);adapter=manager==null?null:manager.getAdapter();}
    private void ready() throws IOException {if(adapter==null)throw new IOException("Bluetooth unavailable");if(!adapter.isEnabled())throw new IOException("Bluetooth is disabled");}
    private Map<String,Object> describe(BluetoothDevice device){
        Map<String,Object> row=new HashMap<>();row.put("id",device.getAddress());
        row.put("name",device.getName()==null?"":device.getName());row.put("paired",device.getBondState()==BluetoothDevice.BOND_BONDED);
        row.put("type",device.getType());return row;
    }
    List<Map<String,Object>> paired() throws IOException {ready();List<Map<String,Object>> rows=new ArrayList<>();for(BluetoothDevice d:adapter.getBondedDevices())rows.add(describe(d));return rows;}
    private final BroadcastReceiver receiver=new BroadcastReceiver(){
        @Override public void onReceive(Context c,Intent intent){
            if(BluetoothDevice.ACTION_FOUND.equals(intent.getAction())){
                BluetoothDevice device=intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE);
                if(device!=null) synchronized(PrinterBluetooth.this){found.put(device.getAddress(),describe(device));}
            } else if(BluetoothAdapter.ACTION_DISCOVERY_FINISHED.equals(intent.getAction())) finishDiscovery(false,false);
        }
    };
    synchronized CompletableFuture<Map<String,Object>> discover() throws IOException {
        ready();if(discovery!=null)throw new IOException("Discovery already running");
        found.clear();for(Map<String,Object> row:paired())found.put((String)row.get("id"),row);
        CompletableFuture<Map<String,Object>> result=new CompletableFuture<>();discovery=result;
        IntentFilter filter=new IntentFilter();filter.addAction(BluetoothDevice.ACTION_FOUND);filter.addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED);
        if(android.os.Build.VERSION.SDK_INT>=33)context.registerReceiver(receiver,filter,Context.RECEIVER_EXPORTED);
        else context.registerReceiver(receiver,filter);
        registered=true;
        if(!adapter.startDiscovery()){finishDiscovery(false,false);throw new IOException("Discovery could not start");}
        main.postDelayed(()->{synchronized(PrinterBluetooth.this){if(discovery==result)finishDiscovery(false,true);}},12000);
        return result;
    }
    synchronized void finishDiscovery(boolean cancelled,boolean timeout){
        CompletableFuture<Map<String,Object>> result=discovery;if(result==null)return;discovery=null;
        try{if(adapter!=null&&adapter.isDiscovering())adapter.cancelDiscovery();}catch(SecurityException ignored){}
        if(registered){context.unregisterReceiver(receiver);registered=false;}
        result.complete(Map.of("devices",new ArrayList<>(found.values()),"cancelled",cancelled,"timedOut",timeout));
    }
    synchronized Map<String,Object> status(){
        boolean enabled=adapter!=null&&adapter.isEnabled();
        boolean connected=enabled&&socket!=null&&socket.isConnected();
        return Map.of("available",adapter!=null,"enabled",enabled,"connected",connected,
            "device",connected?socket.getRemoteDevice().getAddress():"");
    }
    boolean pair(String address) throws IOException {ready();return adapter.getRemoteDevice(address).createBond();}
    void connect(String address) throws Exception {
        ready();finishDiscovery(true,false);disconnect();
        BluetoothDevice device=adapter.getRemoteDevice(address);
        if(device.getType()==BluetoothDevice.DEVICE_TYPE_LE)throw new IOException("BLE-only printer unsupported");
        BluetoothSocket candidate=device.createRfcommSocketToServiceRecord(SPP);
        synchronized(this){socket=candidate;writer=new BluetoothPrinterIo(new BluetoothPrinterIo.Link(){
            public boolean connected(){return candidate.isConnected();}
            public OutputStream output() throws IOException{return candidate.getOutputStream();}
            public void close() throws IOException{candidate.close();}
        });}
        Future<?> request=io.submit(()->{try{candidate.connect();}catch(IOException e){throw new CompletionException(e);}});
        try{request.get(15,TimeUnit.SECONDS);}catch(Exception error){candidate.close();request.cancel(true);disconnect();throw error;}
    }
    void write(byte[] bytes) throws Exception {
        if(bytes==null||bytes.length==0||bytes.length>4096)throw new IOException("Invalid Bluetooth chunk");
        BluetoothPrinterIo target;synchronized(this){target=writer;}
        if(target==null)throw new IOException("Printer not connected");
        Future<?> request=io.submit(()->{try{target.write(bytes);}catch(IOException e){throw new CompletionException(e);}});
        try{request.get(10,TimeUnit.SECONDS);}catch(Exception error){target.close();request.cancel(true);throw error;}
    }
    void finish() throws Exception {
        BluetoothPrinterIo target;synchronized(this){target=writer;}
        if(target==null)throw new IOException("Printer not connected");
        Future<?> request=io.submit(()->{try{target.finish();}catch(IOException e){throw new CompletionException(e);}});
        try{request.get(10,TimeUnit.SECONDS);}catch(Exception error){target.close();request.cancel(true);throw error;}
    }
    synchronized void disconnect() throws IOException {if(socket!=null){BluetoothSocket previous=socket;BluetoothPrinterIo old=writer;socket=null;writer=null;if(old!=null)old.close();else previous.close();}}
    void dispose(){finishDiscovery(true,false);try{disconnect();}catch(IOException ignored){}io.shutdownNow();}
}
