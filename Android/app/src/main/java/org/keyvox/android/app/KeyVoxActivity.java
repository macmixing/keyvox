package org.keyvox.android.app;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.provider.Settings;
import android.view.View;
import android.view.inputmethod.InputMethodManager;
import android.widget.FrameLayout;
import org.keyvox.android.dictation.DictationSession;
import org.keyvox.android.R;
import org.keyvox.android.app.navigation.AppTabHostView;
import org.keyvox.android.app.navigation.ContainingAppTab;

/** Minimal host surface. Dictation lifetime must never belong to this Activity. */
public final class KeyVoxActivity extends Activity {
    private static final int MICROPHONE_PERMISSION_REQUEST = 1;
    private static final String SELECTED_TAB_KEY = "selectedTab";

    private AppTabHostView tabHost;
    private KeyVoxSetupView setupView;
    private final Runnable changed = this::render;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        setupView = new KeyVoxSetupView(
            this,
            () -> startActivity(new Intent(Settings.ACTION_INPUT_METHOD_SETTINGS)),
            () -> getSystemService(InputMethodManager.class).showInputMethodPicker(),
            () -> requestPermissions(
                new String[] { android.Manifest.permission.RECORD_AUDIO },
                MICROPHONE_PERMISSION_REQUEST
            ),
            () -> KeyVoxApplication.dictation(this).downloadModel()
        );
        tabHost = new AppTabHostView(this, this::pageForTab);
        tabHost.setOnApplyWindowInsetsListener((view, insets) -> {
            view.setPadding(
                insets.getSystemWindowInsetLeft(),
                insets.getSystemWindowInsetTop(),
                insets.getSystemWindowInsetRight(),
                insets.getSystemWindowInsetBottom()
            );
            return insets;
        });
        setContentView(tabHost);

        if (state != null) {
            String restored = state.getString(SELECTED_TAB_KEY);
            if (restored != null) {
                try {
                    tabHost.selectTab(ContainingAppTab.valueOf(restored));
                } catch (IllegalArgumentException ignored) {
                    tabHost.selectTab(ContainingAppTab.HOME);
                }
            }
        }
    }

    @Override public void onStart() { super.onStart(); KeyVoxApplication.dictation(this).observe(changed); }
    @Override public void onResume() { super.onResume(); render(); }
    @Override public void onStop() { KeyVoxApplication.dictation(this).removeObserver(changed); super.onStop(); }

    @Override public void onRequestPermissionsResult(
        int requestCode,
        String[] permissions,
        int[] grantResults
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == MICROPHONE_PERMISSION_REQUEST) render();
    }

    @Override protected void onSaveInstanceState(Bundle state) {
        state.putString(SELECTED_TAB_KEY, tabHost.selectedTab().name());
        super.onSaveInstanceState(state);
    }

    private View pageForTab(ContainingAppTab tab) {
        if (tab == ContainingAppTab.SETTINGS) return setupView;
        FrameLayout page = new FrameLayout(this);
        page.setBackgroundColor(getColor(R.color.app_screen_background));
        return page;
    }

    private void render() {
        DictationSession session = KeyVoxApplication.dictation(this);
        setupView.render(session);
    }
}
