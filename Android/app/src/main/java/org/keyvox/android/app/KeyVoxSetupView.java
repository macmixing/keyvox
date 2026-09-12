package org.keyvox.android.app;

import android.Manifest;
import android.content.Context;
import android.content.pm.PackageManager;
import android.graphics.Typeface;
import android.view.Gravity;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import org.keyvox.android.R;
import org.keyvox.android.dictation.DictationSession;

/** Presents the existing containing-app setup controls in the shared app theme. */
final class KeyVoxSetupView extends ScrollView {
    private final TextView status;
    private final Button microphone;
    private final Button download;

    KeyVoxSetupView(
        Context context,
        Runnable enableKeyboard,
        Runnable selectKeyboard,
        Runnable requestMicrophone,
        Runnable downloadModel
    ) {
        super(context);
        setFillViewport(true);
        setClipToPadding(false);
        setVerticalScrollBarEnabled(false);
        setBackgroundColor(getResources().getColor(R.color.app_screen_background, context.getTheme()));

        LinearLayout page = new LinearLayout(context);
        page.setOrientation(LinearLayout.VERTICAL);
        int screenPadding = dimension(R.dimen.app_screen_padding);
        page.setPadding(screenPadding, dimension(R.dimen.app_tab_page_top_inset), screenPadding, screenPadding);
        addView(page, new LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        LinearLayout card = new LinearLayout(context);
        card.setOrientation(LinearLayout.VERTICAL);
        int cardPadding = dimension(R.dimen.app_card_padding);
        card.setPadding(cardPadding, cardPadding, cardPadding, cardPadding);
        card.setBackgroundResource(R.drawable.app_card_background);
        page.addView(card, new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ));

        card.addView(actionButton(R.string.enable_keyboard, true, enableKeyboard), buttonParams(false));
        card.addView(actionButton(R.string.select_keyboard, true, selectKeyboard), buttonParams(true));
        microphone = actionButton(R.string.allow_microphone, true, requestMicrophone);
        card.addView(microphone, buttonParams(true));

        status = new TextView(context);
        status.setTextColor(getResources().getColor(R.color.app_secondary_text, context.getTheme()));
        status.setTextSize(15);
        status.setTypeface(getResources().getFont(R.font.kanit_light));
        status.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams statusParams = new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        );
        statusParams.topMargin = dp(18);
        statusParams.bottomMargin = dp(10);
        card.addView(status, statusParams);

        download = actionButton(R.string.download_model, true, downloadModel);
        card.addView(download, buttonParams(false));
    }

    void render(DictationSession session) {
        microphone.setEnabled(getContext().checkSelfPermission(Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED);
        int label = switch (session.model()) {
            case CHECKING -> R.string.model_checking;
            case MISSING -> R.string.model_missing;
            case DOWNLOADING -> R.string.model_downloading;
            case READY -> R.string.model_ready;
            case FAILED -> R.string.model_failed;
        };
        status.setText(session.phase() == DictationSession.Phase.FAILED ? R.string.engine_failed : label);
        boolean enabled = session.canDownloadModel();
        download.setEnabled(enabled);
    }

    private Button actionButton(int label, boolean primary, Runnable action) {
        Button button = new Button(getContext());
        button.setText(label);
        button.setTextSize(15);
        button.setAllCaps(false);
        button.setGravity(Gravity.CENTER);
        button.setTypeface(getResources().getFont(R.font.kanit_medium), Typeface.NORMAL);
        button.setTextColor(getResources().getColorStateList(
            primary ? R.color.app_primary_button_text : R.color.app_secondary_button_text,
            getContext().getTheme()
        ));
        button.setBackgroundResource(primary
            ? R.drawable.app_primary_button_background
            : R.drawable.app_secondary_button_background);
        button.setMinHeight(dimension(R.dimen.app_regular_button_height));
        button.setMinimumHeight(dimension(R.dimen.app_regular_button_height));
        button.setOnClickListener(view -> action.run());
        return button;
    }

    private LinearLayout.LayoutParams buttonParams(boolean hasTopMargin) {
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            dimension(R.dimen.app_regular_button_height)
        );
        if (hasTopMargin) params.topMargin = dp(10);
        return params;
    }

    private int dimension(int resource) {
        return getResources().getDimensionPixelSize(resource);
    }

    private int dp(float value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }
}
