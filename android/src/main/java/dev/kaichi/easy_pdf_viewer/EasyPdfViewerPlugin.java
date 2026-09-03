package dev.kaichi.easy_pdf_viewer;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.pdf.PdfRenderer;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.Looper;
import android.os.ParcelFileDescriptor;

import androidx.annotation.NonNull;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.Locale;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/** Renders PDF pages to temporary PNG files for the Flutter viewer. */
public final class EasyPdfViewerPlugin implements FlutterPlugin, MethodCallHandler {
  private static final String CHANNEL_NAME = "easy_pdf_viewer_plugin";
  private static final String FILE_PREFIX = "FlutterEasyPdfViewerPlugin";
  private static final int TARGET_WIDTH = 2048;
  private static final int MAX_BITMAP_HEIGHT = 4096;

  private final Handler mainHandler = new Handler(Looper.getMainLooper());
  private MethodChannel channel;
  private HandlerThread workerThread;
  private Handler workerHandler;
  private File cacheDirectory;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL_NAME);
    channel.setMethodCallHandler(this);
    cacheDirectory = binding.getApplicationContext().getCacheDir();
    workerThread = new HandlerThread(
        "easy_pdf_viewer_worker",
        android.os.Process.THREAD_PRIORITY_BACKGROUND
    );
    workerThread.start();
    workerHandler = new Handler(workerThread.getLooper());
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    final Handler handler = workerHandler;
    if (handler == null) {
      result.error("PLUGIN_DETACHED", "The PDF viewer is no longer attached.", null);
      return;
    }

    handler.post(() -> {
      try {
        switch (call.method) {
          case "getNumberOfPages":
            final String filePath = requireString(call, "filePath");
            final boolean clearCache = Boolean.TRUE.equals(
                call.argument("clearCacheDir")
            );
            postSuccess(result, getNumberOfPages(filePath, clearCache));
            break;
          case "getPage":
            final String pagePath = requireString(call, "filePath");
            final Integer pageNumber = call.argument("pageNumber");
            if (pageNumber == null) {
              throw new IllegalArgumentException("Missing pageNumber argument.");
            }
            postSuccess(result, getPage(pagePath, pageNumber));
            break;
          case "clearCacheDir":
            clearCacheDir();
            postSuccess(result, null);
            break;
          default:
            mainHandler.post(result::notImplemented);
            break;
        }
      } catch (Exception exception) {
        postError(result, exception);
      }
    });
  }

  private static String requireString(MethodCall call, String argument) {
    final String value = call.argument(argument);
    if (value == null || value.isEmpty()) {
      throw new IllegalArgumentException("Missing " + argument + " argument.");
    }
    return value;
  }

  private void postSuccess(Result result, Object value) {
    mainHandler.post(() -> result.success(value));
  }

  private void postError(Result result, Exception exception) {
    mainHandler.post(() -> result.error(
        "PDF_RENDER_ERROR",
        exception.getMessage() == null ? "Unable to render PDF." : exception.getMessage(),
        null
    ));
  }

  private void clearCacheDir() {
    final File[] files = cacheDirectory == null ? null : cacheDirectory.listFiles(
        (directory, name) -> name.toLowerCase(Locale.ROOT)
            .startsWith(FILE_PREFIX.toLowerCase(Locale.ROOT))
    );
    if (files == null) return;
    for (File file : files) {
      if (file.isFile()) file.delete();
    }
  }

  private int getNumberOfPages(String filePath, boolean clearCache) throws IOException {
    if (clearCache) clearCacheDir();
    final File pdf = new File(filePath);
    if (!pdf.isFile()) throw new IOException("PDF file not found: " + filePath);

    try (ParcelFileDescriptor descriptor = ParcelFileDescriptor.open(
        pdf,
        ParcelFileDescriptor.MODE_READ_ONLY
    )) {
      try (PdfRenderer renderer = new PdfRenderer(descriptor)) {
        return renderer.getPageCount();
      }
    }
  }

  private String getPage(String filePath, int requestedPage) throws IOException {
    if (requestedPage < 1) {
      throw new IllegalArgumentException("Page numbers start at 1.");
    }
    final File pdf = new File(filePath);
    if (!pdf.isFile()) throw new IOException("PDF file not found: " + filePath);

    try (ParcelFileDescriptor descriptor = ParcelFileDescriptor.open(
        pdf,
        ParcelFileDescriptor.MODE_READ_ONLY
    )) {
      try (PdfRenderer renderer = new PdfRenderer(descriptor)) {
        final int pageIndex = Math.min(requestedPage - 1, renderer.getPageCount() - 1);
        if (pageIndex < 0) throw new IOException("The PDF does not contain any pages.");

        final PdfRenderer.Page page = renderer.openPage(pageIndex);
        try {
          final double ratio = (double) page.getWidth() / page.getHeight();
          int width = TARGET_WIDTH;
          int height = Math.max(1, (int) Math.round(width / ratio));
          if (height > MAX_BITMAP_HEIGHT) {
            height = MAX_BITMAP_HEIGHT;
            width = Math.max(1, (int) Math.round(height * ratio));
          }

          final Bitmap bitmap = Bitmap.createBitmap(
              width,
              height,
              Bitmap.Config.ARGB_8888
          );
          try {
            final Canvas canvas = new Canvas(bitmap);
            canvas.drawColor(Color.WHITE);
            page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY);
            return createTempPreview(bitmap, pdf.getName(), requestedPage);
          } finally {
            bitmap.recycle();
          }
        } finally {
          page.close();
        }
      }
    }
  }

  private String createTempPreview(Bitmap bitmap, String sourceName, int page)
      throws IOException {
    if (cacheDirectory == null) throw new IOException("Cache directory unavailable.");
    final String safeSourceName = sourceName.replaceAll("[^A-Za-z0-9._-]", "_");
    final File output = File.createTempFile(
        FILE_PREFIX + "-" + safeSourceName + "-" + page + "-",
        ".png",
        cacheDirectory
    );
    try (FileOutputStream outputStream = new FileOutputStream(output)) {
      if (!bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)) {
        throw new IOException("Unable to encode rendered PDF page.");
      }
    }
    return output.getAbsolutePath();
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    if (channel != null) channel.setMethodCallHandler(null);
    if (workerThread != null) workerThread.quitSafely();
    workerHandler = null;
    workerThread = null;
    channel = null;
    cacheDirectory = null;
  }
}
