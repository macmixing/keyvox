package org.keyvox.platformlab.capture;

import android.Manifest;
import android.app.Activity;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.view.WindowManager;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;
import java.io.File;

/** Minimal diagnostic presentation; does not choose an engine frontend stack. */
public final class CaptureActivity extends Activity {
    private static final int MICROPHONE_REQUEST = 1;
    private final AudioCapture capture = new AudioCapture();
    private TextView status;
    private Button record;
    private Button stop;
    private boolean visible;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        status = new TextView(this);
        status.setText(R.string.ready);
        record = new Button(this); record.setText(R.string.record);
        stop = new Button(this); stop.setText(R.string.stop); stop.setEnabled(false);
        layout.addView(status); layout.addView(record); layout.addView(stop);
        setContentView(layout);
        record.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View view) { requestCapture(); }
        });
        stop.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View view) { stop.setEnabled(false); capture.stop(); }
        });
    }

    private void requestCapture() {
        if (!visible || capture.isActive()) return;
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[] { Manifest.permission.RECORD_AUDIO }, MICROPHONE_REQUEST);
            return;
        }
        record.setEnabled(false);
        capture.start(getExternalFilesDir(null), new AudioCapture.Listener() {
            @Override public void recording() {
                runOnUiThread(new Runnable() {
                  @Override public void run() {
                    if (!visible) { capture.stop(); return; }
                    status.setText(R.string.recording);
                    stop.setEnabled(true);
                    getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
                  }
                });
            }
            @Override public void finished(File file, Exception failure) {
                runOnUiThread(new Runnable() {
                  @Override public void run() {
                    getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
                    record.setEnabled(true); stop.setEnabled(false);
                    if (failure == null) status.setText(getString(R.string.saved, file.getAbsolutePath()));
                    else if (file != null) status.setText(getString(R.string.failed_saved, failure.toString(), file.getAbsolutePath()));
                    else status.setText(getString(R.string.failed, failure.toString()));
                  }
                });
            }
        });
    }

    @Override public void onRequestPermissionsResult(int request, String[] permissions, int[] results) {
        super.onRequestPermissionsResult(request, permissions, results);
        if (request == MICROPHONE_REQUEST) {
            if (results.length > 0 && results[0] == PackageManager.PERMISSION_GRANTED) requestCapture();
            else status.setText(R.string.permission_needed);
        }
    }

    @Override protected void onStart() {
        super.onStart();
        visible = true;
    }

    @Override protected void onStop() {
        visible = false;
        capture.stop();
        super.onStop();
    }
}
