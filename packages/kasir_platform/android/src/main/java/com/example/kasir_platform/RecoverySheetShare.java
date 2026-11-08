package com.example.kasir_platform;

import android.app.Activity;
import android.content.ClipData;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import androidx.core.content.FileProvider;
import io.flutter.plugin.common.MethodChannel;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.Arrays;
import java.util.concurrent.Executor;

/** The chooser receives a read-only content URI with a bounded lifetime. */
final class RecoverySheetShare {
    private static final long LIFETIME_MS = 10 * 60 * 1000L;
    private static final int READ = Intent.FLAG_GRANT_READ_URI_PERMISSION;
    private final Handler main = new Handler(Looper.getMainLooper());
    private final Executor io;

    RecoverySheetShare(Executor io) {
        this.io = io;
    }

    private static File directory(Context context) {
        return new File(context.getCacheDir(), "skybee-recovery");
    }

    void prune(Context context) {
        io.execute(() -> {
            File[] files = directory(context).listFiles();
            if (files == null) return;
            long cutoff = System.currentTimeMillis() - LIFETIME_MS;
            for (File file : files) {
                if (file.getName().matches("recovery-[0-9]+\\.pdf") &&
                        file.isFile() && file.lastModified() <= cutoff) {
                    file.delete();
                }
            }
        });
    }

    void share(Activity owner, byte[] bytes, MethodChannel.Result result) {
        if (owner == null || !owner.hasWindowFocus() || !RecoverySheetPdf.isPdf(bytes)) {
            if (bytes != null) Arrays.fill(bytes, (byte) 0);
            unavailable(result);
            return;
        }
        Context context = owner.getApplicationContext();
        io.execute(() -> {
            File file = null;
            try {
                File directory = directory(context);
                if (!directory.isDirectory() && !directory.mkdirs()) throw new IOException();
                file = File.createTempFile("recovery-", ".pdf", directory);
                try (FileOutputStream output = new FileOutputStream(file)) {
                    output.write(bytes);
                }
                File owned = file;
                main.post(() -> launch(owner, context, owned, result));
            } catch (Exception failure) {
                if (file != null) file.delete();
                main.post(() -> unavailable(result));
            } finally {
                Arrays.fill(bytes, (byte) 0);
            }
        });
    }

    private void launch(Activity owner, Context context, File file, MethodChannel.Result result) {
        Uri uri = null;
        try {
            if (!owner.hasWindowFocus() || owner.isFinishing() || owner.isDestroyed()) {
                throw new IllegalStateException();
            }
            uri = FileProvider.getUriForFile(context, context.getPackageName() + ".recovery",
                    file, "SkyBee-Recovery-Sheet.pdf");
            Intent send = new Intent(Intent.ACTION_SEND)
                    .setType("application/pdf")
                    .putExtra(Intent.EXTRA_STREAM, uri)
                    .addFlags(READ);
            send.setClipData(ClipData.newRawUri("Recovery sheet", uri));
            owner.startActivity(Intent.createChooser(send, null));
            Uri granted = uri;
            main.postDelayed(() -> remove(context, file, granted), LIFETIME_MS);
            result.success(true);
        } catch (Exception failure) {
            remove(context, file, uri);
            unavailable(result);
        }
    }

    private void remove(Context context, File file, Uri uri) {
        if (uri != null) context.revokeUriPermission(uri, READ);
        io.execute(file::delete);
    }

    private static void unavailable(MethodChannel.Result result) {
        result.error("recovery_share_unavailable", "Recovery sheet share unavailable.", null);
    }
}
