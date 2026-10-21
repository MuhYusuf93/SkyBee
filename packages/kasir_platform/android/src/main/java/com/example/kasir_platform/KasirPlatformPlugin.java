package com.example.kasir_platform;

import android.content.Context;
import android.content.Intent;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.Manifest;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.PersistableBundle;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyInfo;
import android.security.keystore.KeyProperties;
import android.util.AtomicFile;
import android.util.Base64;
import androidx.annotation.NonNull;
import com.google.crypto.tink.subtle.AesGcmHkdfStreaming;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.PluginRegistry;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import java.io.*;
import java.nio.channels.FileLock;
import java.nio.charset.StandardCharsets;
import java.security.*;
import java.util.*;
import java.util.concurrent.*;
import javax.crypto.*;
import javax.crypto.spec.GCMParameterSpec;

/** Android Keystore wrapping, process/file exclusion and bounded streaming I/O.
 * The OS releases the file lock on process death; no worker keeps a DB connection
 * beyond its lease. Errors deliberately omit key material and exception details.
 */
public final class KasirPlatformPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware,
    PluginRegistry.ActivityResultListener, PluginRegistry.RequestPermissionsResultListener {
    private Context context;
    private MethodChannel channel;
    private ActivityPluginBinding activity;
    private PrinterBluetooth bluetooth;
    private PrinterUsb usb;
    private volatile String activePrinter;
    private StrongBiometricsBridge biometrics;
    private final Set<String> protectedScreens = new HashSet<>();
    private final DocumentPicker picker=new DocumentPicker(IO);
    private final ReportDocumentExport reportPicker=new ReportDocumentExport(IO);
    private MethodChannel.Result permissionResult;
    private static final ExecutorService IO = Executors.newCachedThreadPool();
    private static final Map<String,Semaphore> GATES = new ConcurrentHashMap<>();
    private static final Map<String, Lease> LEASES = new ConcurrentHashMap<>();
    private static final String ALIAS = "kasir.m5.wrap.v1";
    private static final Object SECRETS = new Object();
    private final Handler main = new Handler(Looper.getMainLooper());
    private final Set<String> owned = ConcurrentHashMap.newKeySet();
    private record Lease(RandomAccessFile file, FileLock lock, Semaphore gate) {}

    @Override public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        bluetooth=new PrinterBluetooth(context);
        usb=new PrinterUsb(context,IO);
        biometrics=new StrongBiometricsBridge(context);
        channel = new MethodChannel(binding.getBinaryMessenger(), "kasir_app/platform");
        channel.setMethodCallHandler(this);
    }
    @Override public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        bluetooth.dispose();picker.detach();reportPicker.detach();
        usb.dispose();
        biometrics.dispose();
        // The engine owner drains DB work before detaching. Process death is
        // handled by the kernel, not by deleting a lock file or a database.
        for (String token : owned) { try { release(token); } catch (Exception ignored) {} }
    }
    @Override public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        if(call.method.equals("protectedScreen")) {
            String id=call.argument("id");
            if(id==null||!id.matches("[0-9]{1,20}")){result.error("invalid_scope","Invalid screen scope.",null);return;}
            if(Boolean.TRUE.equals(call.argument("active")))protectedScreens.add(id);else protectedScreens.remove(id);
            applyScreenPrivacy();result.success(null);return;
        }
        if(biometrics.handle(call,result))return;
        if(call.method.equals("copyRecoveryCode")){
            try {
                // A foreground user action only; no worker can copy a secret.
                String text=call.argument("text");
                if(activity==null||!activity.getActivity().hasWindowFocus()
                    ||text==null||!text.matches("[a-f0-9]{64}")) {
                    throw new IllegalStateException("Clipboard request unavailable");
                }
                ClipData clip=ClipData.newPlainText("Backup recovery code",text);
                PersistableBundle extras=new PersistableBundle();
                // Compatible with minSdk24; Android13+ uses this to hide preview.
                extras.putBoolean("android.content.extra.IS_SENSITIVE",true);
                clip.getDescription().setExtras(extras);
                ClipboardManager clipboard=(ClipboardManager)context.getSystemService(Context.CLIPBOARD_SERVICE);
                clipboard.setPrimaryClip(clip);
                result.success(true);
            } catch(Exception error) {
                result.error("clipboard_unavailable","Could not copy recovery code.",null);
            }
            return;
        }
        if(call.method.equals("btPermissions")){requestBluetoothPermissions(result);return;}
        if(call.method.equals("usbPermission")){
            try{usb.permission(call.argument("device"),Boolean.TRUE.equals(call.argument("retry"))).whenComplete((answer,error)->main.post(()->{
                if(error!=null)result.error("usb_permission_unavailable","USB permission unavailable.",null);else result.success(answer);
            }));}catch(Exception error){result.error("usb_permission_unavailable","USB permission unavailable.",null);}return;
        }
        if(call.method.equals("pickExport")||call.method.equals("pickImport")){
            try{Number max=call.argument("maxBytes");picker.pick(result,call.method.equals("pickExport"),privateFile(call.argument("path")),call.argument("mime"),max==null?null:max.longValue(),call.argument("displayName"));}
            catch(Exception error){result.error("document_path_invalid","Invalid private staging path.",null);}return;
        }
        if(call.method.equals("chooseReportExport")){reportPicker.choose(result,call.argument("displayName"),call.argument("mime"));return;}
        if(call.method.equals("cancelReportExport")){reportPicker.cancel(call.argument("token"));result.success(true);return;}
        if(call.method.equals("writeReportExport")){
            try{reportPicker.write(result,call.argument("token"),privateFile(call.argument("path")));}
            catch(Exception error){result.error("report_path_invalid","Invalid report staging path.",null);}return;
        }
        if(call.method.equals("btDiscover")){
            try{bluetooth.discover().whenComplete((answer,error)->main.post(()->{
                if(error!=null)result.error("bluetooth_failed","Discovery failed.",null);else result.success(answer);
            }));}catch(Exception error){result.error("bluetooth_failed","Bluetooth unavailable, disabled, or permission denied.",null);}return;
        }
        IO.execute(() -> {
            try {
                Object answer = switch (call.method) {
                    case "key" -> { synchronized (SECRETS) { yield readKey(call.argument("name"), Boolean.TRUE.equals(call.argument("create"))); } }
                    case "saveSecret" -> { synchronized (SECRETS) { writeSecret(call.argument("name"), call.argument("secret")); } yield true; }
                    case "securityInfo" -> { synchronized (SECRETS) { yield securityInfo(); } }
                    case "acquire" -> acquire(call.argument("name"));
                    case "tryAcquire" -> tryAcquire(call.argument("name"));
                    case "maintenanceConditions" -> {
                        android.os.PowerManager power=(android.os.PowerManager)context.getSystemService(Context.POWER_SERVICE);
                        android.os.BatteryManager battery=(android.os.BatteryManager)context.getSystemService(Context.BATTERY_SERVICE);
                        yield Map.of("idle",!power.isInteractive(),"charging",battery.isCharging());
                    }
                    case "release" -> { release(call.argument("token")); yield true; }
                    case "cryptFile" -> { crypt(call); yield true; }
                    case "packArchive" -> {
                        Map<String,String> entries=call.argument("files"); Map<String,File> files=new LinkedHashMap<>();
                        for(Map.Entry<String,String> entry:entries.entrySet()) files.put(entry.getKey(),privateFile(entry.getValue()));
                        PortableArchive.pack(privateFile(call.argument("output")),call.argument("key"),call.argument("manifest"),files);
                        yield true;
                    }
                    case "unpackArchive" -> {
                        Number budget=call.argument("budget");
                        File dir=privateFile(call.argument("output"));
                        if(budget.longValue()>dir.getParentFile().getUsableSpace()-16777216) throw new IOException("Insufficient extraction space");
                        PortableArchive.unpack(privateFile(call.argument("input")),dir,call.argument("key"),budget.longValue());
                        yield true;
                    }
                    case "freeBytes" -> privateFile(call.argument("path")).getUsableSpace();
                    case "syncDirectory" -> {
                        File directory=privateFile(call.argument("path"));
                        if(!directory.isDirectory())throw new IOException("Not a private directory");
                        java.io.FileDescriptor fd=android.system.Os.open(directory.getPath(),
                            android.system.OsConstants.O_RDONLY,0);
                        try{android.system.Os.fsync(fd);}finally{android.system.Os.close(fd);}yield true;
                    }
                    case "btPaired" -> bluetooth.paired();
                    case "btStatus" -> bluetooth.status();
                    case "btCancelDiscovery" -> {bluetooth.finishDiscovery(true,false);yield true;}
                    case "btPair" -> bluetooth.pair(call.argument("device"));
                    case "usbDevices" -> usb.devices();
                    case "usbStatus" -> usb.status();
                    case "usbIdentity" -> usb.identity(call.argument("device"));
                    case "usbConnect" -> {connectPrinter(call.argument("device"));yield true;}
                    case "printerConnect" -> {connectPrinter(call.argument("device"));yield true;}
                    case "btConnect" -> {connectPrinter(call.argument("device"));yield true;}
                    case "printerWrite" -> {
                        byte[] bytes=call.argument("bytes");
                        try{
                            if("usb".equals(activePrinter))usb.write(bytes);
                            else if("bluetooth".equals(activePrinter))bluetooth.write(bytes);
                            else throw new IOException("Printer not connected");
                        }finally{if(bytes!=null)Arrays.fill(bytes,(byte)0);}
                        yield true;
                    }
                    case "btWrite" -> {
                        byte[] bytes=call.argument("bytes");
                        try{bluetooth.write(bytes);}
                        finally{if(bytes!=null)Arrays.fill(bytes,(byte)0);}
                        yield true;
                    }
                    case "printerDisconnect", "btDisconnect" -> {activePrinter=null;usb.disconnect();bluetooth.disconnect();yield true;}
                    default -> null;
                };
                if (answer == null && !call.method.equals("tryAcquire")) main.post(result::notImplemented);
                else main.post(() -> result.success(answer));
            } catch (Exception error) {
                String code = error instanceof IOException && error.getMessage()!=null && error.getMessage().matches("usb_[a-z_]{1,40}") ? error.getMessage() : error instanceof FileNotFoundException ? "key_missing" :
                    error instanceof GeneralSecurityException ? "authentication_failed" : "platform_io_failed";
                main.post(() -> result.error(code, "Secure operation failed; existing data retained.", null));
            }
        });
    }
    private void connectPrinter(String device) throws Exception {
        activePrinter=null;
        if(device!=null&&device.startsWith("usb:")) {
            bluetooth.disconnect();usb.connect(device);activePrinter="usb";
        } else {
            if(device==null||!device.matches("(?i)([0-9a-f]{2}:){5}[0-9a-f]{2}"))throw new IOException("Invalid printer identity");
            usb.disconnect();bluetooth.connect(device);activePrinter="bluetooth";
        }
    }
    private void requestBluetoothPermissions(MethodChannel.Result result){
        String[] required=Build.VERSION.SDK_INT>=31?new String[]{Manifest.permission.BLUETOOTH_SCAN,Manifest.permission.BLUETOOTH_CONNECT}:
            new String[]{Manifest.permission.ACCESS_FINE_LOCATION};
        boolean granted=true;for(String permission:required)if(context.checkSelfPermission(permission)!=PackageManager.PERMISSION_GRANTED)granted=false;
        if(granted){result.success(true);return;}
        if(activity==null||permissionResult!=null){result.error("permission_unavailable","Foreground permission request required.",null);return;}
        // Android may still pause/resume the activity when a denied request is
        // immediately rejected. Repeating it after PIN entry therefore loops.
        // Keep prompt history outside the portable DB; permission recovery is an
        // explicit user action in Android settings, never a remembered PIN.
        var history=context.getSharedPreferences("kasir_printer_permissions",Context.MODE_PRIVATE);
        String key=Build.VERSION.SDK_INT>=31?"nearby_requested":"location_requested";
        try {
            BluetoothPermissionGate.request(new BluetoothPermissionGate.State(){
                public boolean granted(){
                    for(String permission:required)if(context.checkSelfPermission(permission)!=PackageManager.PERMISSION_GRANTED)return false;
                    return true;
                }
                public boolean requested(){return history.getBoolean(key,false);}
                public void rememberRequest(){
                    if(!history.edit().putBoolean(key,true).commit())throw new IllegalStateException("Permission history unavailable");
                }
            },()->{
                permissionResult=result;
                activity.getActivity().requestPermissions(required,59306);
            },result::success);
        } catch(Exception error){
            if(permissionResult==result)permissionResult=null;
            result.error("permission_unavailable","Permission request unavailable; use Android app settings.",null);
        }
    }
    @Override public boolean onRequestPermissionsResult(int request,String[] permissions,int[] results){
        if(request!=59306||permissionResult==null)return false;
        boolean granted=results.length>0;for(int r:results)granted&=r==PackageManager.PERMISSION_GRANTED;
        permissionResult.success(granted);permissionResult=null;return true;
    }
    @Override public boolean onActivityResult(int request,int code,Intent data){return reportPicker.result(request,code,data)||picker.result(request,code,data);}
    private void applyScreenPrivacy(){if(activity!=null){if(protectedScreens.isEmpty())activity.getActivity().getWindow().clearFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE);else activity.getActivity().getWindow().addFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE);}}
    @Override public void onAttachedToActivity(ActivityPluginBinding binding){activity=binding;picker.attach(binding.getActivity());reportPicker.attach(binding.getActivity());biometrics.attach(binding.getActivity());usb.attach(binding.getActivity());applyScreenPrivacy();binding.addActivityResultListener(this);binding.addRequestPermissionsResultListener(this);}
    @Override public void onDetachedFromActivityForConfigChanges(){detachActivity();}
    @Override public void onReattachedToActivityForConfigChanges(ActivityPluginBinding binding){onAttachedToActivity(binding);}
    @Override public void onDetachedFromActivity(){detachActivity();}
    private void detachActivity(){biometrics.detach();usb.detach();if(activity!=null){activity.removeActivityResultListener(this);activity.removeRequestPermissionsResultListener(this);}activity=null;picker.detach();reportPicker.detach();if(permissionResult!=null){permissionResult.error("permission_interrupted","Permission request interrupted.",null);permissionResult=null;}}
    private File privateFile(String path) throws IOException {
        File file = new File(path).getCanonicalFile();
        String root = context.getDataDir().getCanonicalPath() + File.separator;
        if (!file.getPath().startsWith(root)) throw new IOException("Outside application storage");
        return file;
    }
    private synchronized SecretKey wrappingKey() throws GeneralSecurityException, IOException {
        KeyStore store = KeyStore.getInstance("AndroidKeyStore"); store.load(null);
        if (store.containsAlias(ALIAS)) return (SecretKey) store.getKey(ALIAS, null);
        // A lost wrapping key must never be replaced if wrapped secrets remain.
        File[] existing = context.getNoBackupFilesDir().listFiles((dir, name) -> name.startsWith("secret-"));
        if (existing != null && existing.length != 0) throw new GeneralSecurityException("Keystore key missing");
        KeyGenerator generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore");
        generator.init(new KeyGenParameterSpec.Builder(ALIAS,
            KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256).build());
        return generator.generateKey();
    }
    private AtomicFile secretFile(String name) throws IOException {
        if (name == null || !name.matches("[a-zA-Z0-9_.-]{1,96}")) throw new IOException("Invalid key name");
        return new AtomicFile(new File(context.getNoBackupFilesDir(), "secret-" + name));
    }
    private synchronized void writeSecret(String name, String value) throws Exception {
        AtomicFile file = secretFile(name);
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.ENCRYPT_MODE, wrappingKey());
        cipher.updateAAD(("kasir-wrapped-v1:"+name).getBytes(StandardCharsets.UTF_8));
        byte[] encrypted = cipher.doFinal(value.getBytes(StandardCharsets.UTF_8));
        FileOutputStream out = file.startWrite();
        try { out.write(0xA1);out.write(cipher.getIV().length); out.write(cipher.getIV()); out.write(encrypted); file.finishWrite(out); }
        catch (Exception error) { file.failWrite(out); throw error; }
    }
    private synchronized String readKey(String name, boolean create) throws Exception {
        AtomicFile file = secretFile(name);
        if (!file.getBaseFile().exists() && !new File(file.getBaseFile() + ".bak").exists()) {
            if (!create) throw new FileNotFoundException("Key missing");
            byte[] bytes = new byte[32]; new SecureRandom().nextBytes(bytes);
            StringBuilder hex = new StringBuilder();
            for (byte b : bytes) hex.append(String.format(Locale.ROOT, "%02x", b & 255));
            writeSecret(name, hex.toString()); Arrays.fill(bytes, (byte) 0);
        }
        byte[] contents = file.readFully();
        boolean modern=(contents[0]&255)==0xA1;
        int start=modern?2:1;
        int n = contents[start-1] & 255;
        if (n != 12 || contents.length < n + start+16) throw new GeneralSecurityException("Wrapped key damaged");
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.DECRYPT_MODE, wrappingKey(), new GCMParameterSpec(128, Arrays.copyOfRange(contents, start, n+start)));
        if(modern)cipher.updateAAD(("kasir-wrapped-v1:"+name).getBytes(StandardCharsets.UTF_8));
        String value=new String(cipher.doFinal(contents,n+start,contents.length-n-start),StandardCharsets.UTF_8);
        // Version 0 exists only in early M5 isolated tests. Preserve its key
        // exactly while upgrading the authenticated name binding in-place.
        if(!modern)writeSecret(name,value);
        return value;
    }
    private Map<String,Object> securityInfo() throws Exception {
        SecretKeyFactory factory = SecretKeyFactory.getInstance("AES", "AndroidKeyStore");
        KeyInfo info = (KeyInfo) factory.getKeySpec(wrappingKey(), KeyInfo.class);
        return Map.of("insideSecureHardware", info.isInsideSecureHardware(), "algorithm", "AES-256-GCM",
            "userAuthenticationRequired", info.isUserAuthenticationRequired());
    }
    private String acquire(String requested) throws Exception {
        String name=requested==null?"database":requested;
        if(!name.matches("[a-z-]{1,32}"))throw new IOException("Invalid lease name");
        Semaphore gate=GATES.computeIfAbsent(name,ignored->new Semaphore(1,true));
        if (!gate.tryAcquire(90, TimeUnit.SECONDS)) throw new IOException("Database maintenance busy");
        RandomAccessFile file = null;
        try {
            file = new RandomAccessFile(new File(context.getNoBackupFilesDir(), name+".gate"), "rw");
            FileLock lock = file.getChannel().lock();
            String token = UUID.randomUUID().toString(); LEASES.put(token, new Lease(file, lock,gate)); owned.add(token);
            return token;
        } catch (Exception error) { if (file != null) file.close(); gate.release(); throw error; }
    }
    private void release(String token) throws Exception {
        if (!owned.remove(token)) throw new IOException("Lease ownership mismatch");
        Lease lease = LEASES.remove(token);
        try { lease.lock.release(); lease.file.close(); } finally { lease.gate.release(); }
    }
    /** No waiting: an occupied local semaphore OR cross-process lock skips. */
    private String tryAcquire(String name) throws Exception {
        if(name==null||!name.matches("[a-z-]{1,32}"))throw new IOException("Invalid lease name");
        Semaphore gate=GATES.computeIfAbsent(name,ignored->new Semaphore(1,true));
        if(!gate.tryAcquire())return null;
        RandomAccessFile file=null;boolean leased=false;
        try{
            file=new RandomAccessFile(new File(context.getNoBackupFilesDir(),name+".gate"),"rw");
            FileLock lock;
            try{lock=file.getChannel().tryLock();}catch(java.nio.channels.OverlappingFileLockException busy){return null;}
            if(lock==null)return null;
            String token=UUID.randomUUID().toString();LEASES.put(token,new Lease(file,lock,gate));owned.add(token);leased=true;return token;
        }finally{if(!leased){if(file!=null)file.close();gate.release();}}
    }
    private void crypt(MethodCall call) throws Exception {
        File input = privateFile(call.argument("input")), output = privateFile(call.argument("output"));
        if (input.equals(output) || output.exists()) throw new IOException("Staging output already exists");
        String key = call.argument("key");
        if (key == null || !key.matches("[0-9a-fA-F]{64}")) throw new GeneralSecurityException("Invalid recovery code");
        byte[] bytes = new byte[32];
        for (int i=0; i<32; i++) bytes[i] = (byte)Integer.parseInt(key.substring(i*2,i*2+2),16);
        AesGcmHkdfStreaming primitive = new AesGcmHkdfStreaming(bytes, "HmacSha256", 32, 65536, 0);
        Arrays.fill(bytes, (byte) 0);
        byte[] aad = "kasir-portable-backup-v1".getBytes(StandardCharsets.UTF_8);
        boolean decrypt = Boolean.TRUE.equals(call.argument("decrypt"));
        try (InputStream source = new BufferedInputStream(new FileInputStream(input));
             FileOutputStream targetFile = new FileOutputStream(output)) {
            if (decrypt) {
                try (InputStream plaintext = primitive.newDecryptingStream(source, aad)) { copy(plaintext, targetFile); }
                targetFile.getFD().sync();
            } else {
                try (OutputStream encrypted = primitive.newEncryptingStream(targetFile, aad)) {
                    copy(source, encrypted); encrypted.flush();
                    // close writes the authenticated final segment; sync after
                    // close using a separate descriptor below.
                }
            }
        } catch (Exception error) { output.delete(); throw error; }
        try (RandomAccessFile file = new RandomAccessFile(output, "rw")) { file.getFD().sync(); }
    }
    private static void copy(InputStream source, OutputStream target) throws IOException {
        byte[] buffer = new byte[65536]; int count;
        while ((count=source.read(buffer)) != -1) target.write(buffer,0,count);
        Arrays.fill(buffer,(byte)0);
    }
}
