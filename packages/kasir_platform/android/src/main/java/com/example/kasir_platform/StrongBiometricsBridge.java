package com.example.kasir_platform;

import android.app.KeyguardManager;
import android.os.PowerManager;
import android.content.*;
import android.os.*;
import android.security.keystore.*;
import android.util.AtomicFile;
import android.util.Base64;
import androidx.biometric.BiometricManager;
import androidx.biometric.BiometricPrompt;
import androidx.fragment.app.FragmentActivity;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.security.*;
import java.util.*;
import java.util.concurrent.atomic.AtomicLong;
import javax.crypto.*;
import javax.crypto.spec.GCMParameterSpec;
import org.json.JSONObject;

/** Per-database, nonportable auth binding. This alias never wraps SQLCipher or
 * portable backup keys. Enrollment invalidation can only remove this binding.
 * Class3 CryptoObject is mandatory; no device-PIN/weak-biometric fallback.
 */
final class StrongBiometricsBridge {
    private final Context context;
    private FragmentActivity activity;
    private final Handler main = new Handler(Looper.getMainLooper());
    private MethodChannel.Result pending;
    private BiometricPrompt prompt;
    private long request = 0;
    private static final AtomicLong screenGeneration = new AtomicLong();
    private final BroadcastReceiver screen = new BroadcastReceiver() {
        @Override public void onReceive(Context c, Intent i) {
            if (Intent.ACTION_SCREEN_OFF.equals(i.getAction())) screenGeneration.incrementAndGet();
        }
    };
    StrongBiometricsBridge(Context c) {
        context = c;
        IntentFilter filter = new IntentFilter(Intent.ACTION_SCREEN_OFF);
        if (Build.VERSION.SDK_INT >= 33) c.registerReceiver(screen, filter, Context.RECEIVER_NOT_EXPORTED);
        else c.registerReceiver(screen, filter);
    }
    void attach(android.app.Activity value) { activity = value instanceof FragmentActivity ? (FragmentActivity)value : null; }
    void detach() { cancel(); activity = null; }
    void dispose() { detach(); try { context.unregisterReceiver(screen); } catch (Exception ignored) {} }
    private String scope(MethodCall call) throws IOException {
        String value = call.argument("scope");
        if (value == null || !value.matches("[a-f0-9]{64}")) throw new IOException("Invalid scope");
        return value;
    }
    private String epoch(MethodCall call) throws IOException {
        String value = call.argument("epoch");
        if (value == null || !value.matches("[a-f0-9]{64}")) throw new IOException("Invalid epoch");
        return value;
    }
    private String alias(String scope) { return "kasir.m51.biometric." + scope; }
    private AtomicFile file(String scope) { return new AtomicFile(new File(context.getNoBackupFilesDir(), "biometric-" + scope)); }
    private KeyStore store() throws Exception { KeyStore ks = KeyStore.getInstance("AndroidKeyStore"); ks.load(null); return ks; }
    private void clear(String scope) throws Exception { file(scope).delete(); store().deleteEntry(alias(scope)); }
    private SecretKey key(String scope, boolean create) throws Exception {
        KeyStore ks = store();
        if (ks.containsAlias(alias(scope))) return (SecretKey)ks.getKey(alias(scope), null);
        if (!create) throw new KeyStoreException("Binding unavailable");
        KeyGenerator generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore");
        KeyGenParameterSpec.Builder spec = new KeyGenParameterSpec.Builder(alias(scope), KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
            .setKeySize(256).setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setUserAuthenticationRequired(true).setInvalidatedByBiometricEnrollment(true);
        if (Build.VERSION.SDK_INT >= 30) spec.setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG);
        else spec.setUserAuthenticationValidityDurationSeconds(-1);
        generator.init(spec.build()); return generator.generateKey();
    }
    private JSONObject load(String scope) throws Exception {
        if (file(scope).getBaseFile().length() > 2048) throw new IOException("Invalid binding");
        byte[] bytes = file(scope).readFully();
        if (bytes.length > 2048) throw new IOException("Invalid binding");
        JSONObject object = new JSONObject(new String(bytes, StandardCharsets.UTF_8));
        if (object.getInt("format") != 1 || !object.getString("epoch").matches("[a-f0-9]{64}")) throw new IOException("Invalid binding");
        return object;
    }
    private Cipher cipher(String scope, JSONObject binding) throws Exception {
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        if (binding == null) cipher.init(Cipher.ENCRYPT_MODE, key(scope, true));
        else {
            byte[] iv = Base64.decode(binding.getString("iv"), Base64.NO_WRAP);
            if (iv.length != 12) throw new IOException("Invalid IV");
            cipher.init(Cipher.DECRYPT_MODE, key(scope, false), new GCMParameterSpec(128, iv));
        }
        return cipher;
    }
    private void save(String scope, String epoch, Cipher cipher, byte[] encrypted) throws Exception {
        JSONObject object = new JSONObject().put("format", 1).put("epoch", epoch)
            .put("iv", Base64.encodeToString(cipher.getIV(), Base64.NO_WRAP))
            .put("ciphertext", Base64.encodeToString(encrypted, Base64.NO_WRAP));
        AtomicFile dest = file(scope); FileOutputStream out = null;
        try { out = dest.startWrite(); out.write(object.toString().getBytes(StandardCharsets.UTF_8)); dest.finishWrite(out); }
        catch (Exception error) { if (out != null) dest.failWrite(out); throw error; }
    }
    boolean handle(MethodCall call, MethodChannel.Result result) {
        if (call.method.equals("screenSecurityState")) {
            KeyguardManager manager = (KeyguardManager)context.getSystemService(Context.KEYGUARD_SERVICE);
            PowerManager power = (PowerManager)context.getSystemService(Context.POWER_SERVICE);
            result.success(Map.of("locked", manager == null || manager.isDeviceLocked() || manager.isKeyguardLocked(), "generation", screenGeneration.get(), "interactive", power != null && power.isInteractive()));
            return true;
        }
        if (!call.method.startsWith("biometric")) return false;
        try {
            String scope = scope(call);
            if (call.method.equals("biometricClear")) { clear(scope); result.success(null); return true; }
            String epoch = epoch(call);
            if (call.method.equals("biometricStatus")) {
                boolean enabled = false, invalidated = false;
                if (file(scope).getBaseFile().exists()) {
                    try {
                        JSONObject binding = load(scope);
                        if (!epoch.equals(binding.getString("epoch"))) throw new KeyStoreException("Epoch changed");
                        cipher(scope, binding); enabled = true;
                    } catch (Exception error) { clear(scope); invalidated = true; }
                }
                int status = BiometricManager.from(context).canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG);
                result.success(Map.of("available", status == BiometricManager.BIOMETRIC_SUCCESS, "enabled", enabled, "invalidated", invalidated));
                return true;
            }
            if (!call.method.equals("biometricEnroll") && !call.method.equals("biometricAuthenticate")) { result.notImplemented(); return true; }
            if (activity == null || pending != null || !activity.hasWindowFocus()) throw new IllegalStateException("Foreground required");
            if (BiometricManager.from(context).canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) != BiometricManager.BIOMETRIC_SUCCESS) {
                result.error("biometric_unavailable", "Strong biometric unavailable.", null); return true;
            }
            final boolean enroll = call.method.equals("biometricEnroll");
            final JSONObject binding = enroll ? null : load(scope);
            if (binding != null && !epoch.equals(binding.getString("epoch"))) {
                clear(scope); result.error("biometric_invalidated", "Binding changed. Use app PIN.", null); return true;
            }
            if (enroll) clear(scope);
            final Cipher crypto = cipher(scope, binding);
            String title = call.argument("title"), negative = call.argument("negative");
            if (title == null || negative == null || title.length() > 160 || negative.length() > 80) throw new IOException("Invalid prompt labels");
            pending = result; final long own = ++request;
            prompt = new BiometricPrompt(activity, task -> main.post(task), new BiometricPrompt.AuthenticationCallback() {
                @Override public void onAuthenticationError(int code, CharSequence message) {
                    if (own != request || pending == null) return;
                    String kind = switch(code) {
                        case BiometricPrompt.ERROR_NEGATIVE_BUTTON, BiometricPrompt.ERROR_USER_CANCELED, BiometricPrompt.ERROR_CANCELED -> "biometric_cancelled";
                        case BiometricPrompt.ERROR_LOCKOUT, BiometricPrompt.ERROR_LOCKOUT_PERMANENT -> "biometric_lockout";
                        default -> "biometric_unavailable";
                    };
                    finishError(own, kind);
                }
                @Override public void onAuthenticationSucceeded(BiometricPrompt.AuthenticationResult answer) {
                    if (own != request || pending == null) return;
                    byte[] cleartext = null;
                    try {
                        if (answer.getAuthenticationType() == BiometricPrompt.AUTHENTICATION_RESULT_TYPE_DEVICE_CREDENTIAL || answer.getCryptoObject() == null || answer.getCryptoObject().getCipher() != crypto) throw new GeneralSecurityException("Crypto authentication required");
                        byte[] marker = ("kasir-biometric-v1:" + epoch).getBytes(StandardCharsets.UTF_8);
                        try {
                            if (enroll) save(scope, epoch, crypto, crypto.doFinal(marker));
                            else {
                                byte[] encrypted = Base64.decode(binding.getString("ciphertext"), Base64.NO_WRAP);
                                if (encrypted.length > 512) throw new IOException("Invalid proof");
                                cleartext = crypto.doFinal(encrypted);
                                if (!MessageDigest.isEqual(cleartext, marker)) throw new GeneralSecurityException("Invalid proof");
                            }
                        } finally { Arrays.fill(marker, (byte)0); }
                        MethodChannel.Result done = pending; pending = null; prompt = null; done.success(true);
                    } catch (Exception error) { try { clear(scope); } catch (Exception ignored) {} finishError(own, "biometric_invalidated"); }
                    finally { if (cleartext != null) Arrays.fill(cleartext, (byte)0); }
                }
            });
            BiometricPrompt.PromptInfo info = new BiometricPrompt.PromptInfo.Builder().setTitle(title)
                .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
                .setNegativeButtonText(negative).setConfirmationRequired(true).build();
            prompt.authenticate(info, new BiometricPrompt.CryptoObject(crypto));
            main.postDelayed(() -> { if (own == request && pending != null) cancel(); }, 60000);
        } catch (Exception error) {
            if (pending == result) finishError(request, "biometric_unavailable");
            else result.error("biometric_unavailable", "Strong biometric unavailable. Use app PIN.", null);
        }
        return true;
    }
    private void finishError(long own, String code) {
        if (own != request || pending == null) return;
        MethodChannel.Result done = pending; pending = null; prompt = null;
        done.error(code, "Biometric authentication did not complete. Use app PIN.", null);
    }
    private void cancel() {
        MethodChannel.Result done = pending; pending = null; request++;
        BiometricPrompt active = prompt; prompt = null;
        if (active != null) active.cancelAuthentication();
        if (done != null) done.error("biometric_cancelled", "Authentication cancelled.", null);
    }
}
