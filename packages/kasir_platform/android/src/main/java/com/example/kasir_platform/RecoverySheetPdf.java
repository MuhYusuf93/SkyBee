package com.example.kasir_platform;

import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Typeface;
import android.graphics.pdf.PdfDocument;
import android.text.Layout;
import android.text.StaticLayout;
import android.text.TextPaint;
import android.text.TextUtils;
import io.flutter.plugin.common.MethodCall;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.List;

/** A single A4 page, with bounded localized text and a vector QR quiet zone. */
final class RecoverySheetPdf {
    private static final int INK = 0xff14243a;
    private static final int MUTED = 0xff425267;
    private static final int TEAL = 0xff136c6a;
    private static final int LIGHT = 0xffeaf4f3;
    private static final int LINE = 0xffdbe4e9;
    private static final int WIDTH = 595;
    private static final int HEIGHT = 842;
    private static final int MARGIN = 42;
    private static final int CONTENT = WIDTH - 2 * MARGIN;
    static final int MAX_BYTES = 512 * 1024;

    private RecoverySheetPdf() {}

    static byte[] render(MethodCall call) throws IOException {
        List<?> words = call.argument("words");
        byte[] matrix = call.argument("qr");
        Integer size = call.argument("size");
        if (words == null || words.size() != 24 || size == null ||
                size < 21 || size > 65 || (size - 21) % 4 != 0 ||
                matrix == null || matrix.length != size * size) {
            throw new IllegalArgumentException();
        }
        for (Object word : words) {
            if (!(word instanceof String text) || !text.matches("[a-z]{3,8}")) {
                throw new IllegalArgumentException();
            }
        }
        PdfDocument document = new PdfDocument();
        try (ByteArrayOutputStream output = new ByteArrayOutputStream()) {
            PdfDocument.Page page = document.startPage(new PdfDocument.PageInfo.Builder(
                    WIDTH, HEIGHT, 1).create());
            Canvas canvas = page.getCanvas();
            try {
                canvas.drawColor(Color.WHITE);
                box(canvas, MARGIN, 43, CONTENT, 4, TEAL);
                text(canvas, "SKYBEE", MARGIN, 58, CONTENT, 10, TEAL, true, 1);
                text(canvas, field(call, "title", 80), MARGIN, 77,
                        CONTENT, 27, INK, true, 2);
                text(canvas, field(call, "store", 220), MARGIN, 146,
                        CONTENT, 15, INK, true, 2);
                text(canvas, field(call, "metadata", 170), MARGIN, 191,
                        CONTENT, 10, MUTED, false, 2);

                box(canvas, MARGIN, 227, CONTENT, 66, LIGHT);
                text(canvas, field(call, "warning", 340), MARGIN + 13, 237,
                        CONTENT - 26, 12, INK, true, 3);
                text(canvas, field(call, "wordHeading", 90), MARGIN, 315,
                        CONTENT, 16, INK, true, 1);
                final Paint line = new Paint();
                line.setColor(LINE);
                for (int i = 0; i < 24; i++) {
                    int left = MARGIN + (i / 8) * 172;
                    int top = 347 + (i % 8) * 24;
                    canvas.drawLine(left, top + 20, left + 155, top + 20, line);
                    text(canvas, Integer.toString(i + 1), left, top,
                            26, 11, TEAL, true, 1);
                    text(canvas, (String) words.get(i), left + 28, top - 2,
                            127, 15, INK, false, 1);
                }

                box(canvas, MARGIN, 557, CONTENT, 1, LINE);
                drawQr(canvas, matrix, size, MARGIN, 578, 182);
                text(canvas, field(call, "qrHeading", 90), MARGIN + 201, 596,
                        CONTENT - 201, 16, INK, true, 2);
                text(canvas, field(call, "instructions", 440), MARGIN + 201, 645,
                        CONTENT - 201, 12, MUTED, false, 6);
                box(canvas, MARGIN, 775, CONTENT, 1, LINE);
                text(canvas, field(call, "footer", 145), MARGIN, 786,
                        CONTENT, 9, MUTED, false, 2);
            } finally {
                document.finishPage(page);
            }
            document.writeTo(output);
            byte[] bytes = output.toByteArray();
            if (!isPdf(bytes)) throw new IOException();
            return bytes;
        } finally {
            document.close();
        }
    }

    static boolean isPdf(byte[] bytes) {
        return bytes != null && bytes.length > 5 && bytes.length <= MAX_BYTES &&
                bytes[0] == '%' && bytes[1] == 'P' && bytes[2] == 'D' &&
                bytes[3] == 'F' && bytes[4] == '-';
    }

    private static String field(MethodCall call, String name, int limit) {
        String value = call.argument(name);
        if (value == null || value.trim().isEmpty() || value.length() > limit) {
            throw new IllegalArgumentException();
        }
        return value;
    }

    private static void box(Canvas canvas, float left, float top, float width,
                            float height, int color) {
        Paint paint = new Paint();
        paint.setColor(color);
        canvas.drawRect(left, top, left + width, top + height, paint);
    }

    private static void text(Canvas canvas, String value, int left, int top, int width,
                             int size, int color, boolean bold, int maxLines) {
        TextPaint paint = new TextPaint(Paint.ANTI_ALIAS_FLAG);
        paint.setColor(color);
        paint.setTextSize(size);
        paint.setTypeface(Typeface.create("sans-serif", bold ? Typeface.BOLD : Typeface.NORMAL));
        StaticLayout layout = StaticLayout.Builder.obtain(value, 0, value.length(), paint, width)
                .setAlignment(Layout.Alignment.ALIGN_NORMAL)
                .setIncludePad(false)
                .setMaxLines(maxLines)
                .setEllipsize(TextUtils.TruncateAt.END)
                .build();
        canvas.save();
        canvas.translate(left, top);
        layout.draw(canvas);
        canvas.restore();
    }

    private static void drawQr(Canvas canvas, byte[] matrix, int size,
                               int left, int top, int width) {
        final int quiet = 4;
        final int module = width / (size + 2 * quiet);
        final int inset = (width - module * size) / 2;
        if (module < 2) throw new IllegalArgumentException();
        Paint black = new Paint();
        black.setColor(Color.BLACK);
        for (int row = 0; row < size; row++) {
            for (int column = 0; column < size; column++) {
                byte pixel = matrix[row * size + column];
                if (pixel == 0) continue;
                if (pixel != 1) throw new IllegalArgumentException();
                int x = left + inset + column * module;
                int y = top + inset + row * module;
                canvas.drawRect(x, y, x + module, y + module, black);
            }
        }
    }
}
