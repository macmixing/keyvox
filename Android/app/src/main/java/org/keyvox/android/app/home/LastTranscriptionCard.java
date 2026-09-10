package org.keyvox.android.app.home;

import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.res.ColorStateList;
import android.graphics.Color;
import android.graphics.Typeface;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.view.Gravity;
import android.view.HapticFeedbackConstants;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;
import org.keyvox.android.R;

/** Renders and copies the most recent successful transcription. */
final class LastTranscriptionCard extends LinearLayout {
    private final Handler main = new Handler(Looper.getMainLooper());
    private final Button copy;
    private final LinearLayout body;
    private final Runnable resetCopyFeedback = () -> showCopyFeedback(false);
    private boolean hasRendered;
    private String transcription;

    LastTranscriptionCard(Context context) {
        super(context);
        setOrientation(VERTICAL);
        int padding = dimension(R.dimen.app_card_padding);
        setPadding(padding, padding, padding, padding);
        setBackgroundResource(R.drawable.app_card_background);

        LinearLayout header = new LinearLayout(context);
        header.setOrientation(HORIZONTAL);
        header.setGravity(Gravity.CENTER_VERTICAL);
        addView(header, new LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        TextView title = new TextView(context);
        title.setText(R.string.home_latest_transcription);
        title.setTextColor(getResources().getColor(R.color.app_primary_text, context.getTheme()));
        title.setTextSize(17);
        title.setTypeface(getResources().getFont(R.font.kanit_medium));
        header.addView(title, new LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));

        copy = new Button(context);
        copy.setText(R.string.copy);
        copy.setTextSize(15);
        copy.setAllCaps(false);
        copy.setGravity(Gravity.CENTER);
        copy.setTypeface(getResources().getFont(R.font.kanit_medium));
        copy.setTextColor(Color.BLACK);
        copy.setCompoundDrawablePadding(dp(6));
        copy.setCompoundDrawableTintList(ColorStateList.valueOf(Color.BLACK));
        copy.setBackgroundResource(R.drawable.app_primary_button_background);
        copy.setMinWidth(dp(84));
        copy.setMinimumWidth(dp(84));
        copy.setMinHeight(dimension(R.dimen.app_compact_button_height));
        copy.setMinimumHeight(dimension(R.dimen.app_compact_button_height));
        copy.setPadding(dp(12), 0, dp(12), 0);
        copy.setOnClickListener(view -> copyTranscription());
        header.addView(copy, new LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            dimension(R.dimen.app_compact_button_height)
        ));

        body = new LinearLayout(context);
        body.setOrientation(VERTICAL);
        LayoutParams bodyParams = new LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        bodyParams.topMargin = dp(14);
        addView(body, bodyParams);
    }

    void render(String text) {
        String next = text == null || text.trim().isEmpty() ? null : text;
        if (hasRendered && java.util.Objects.equals(transcription, next)) return;
        hasRendered = true;
        transcription = next;
        main.removeCallbacks(resetCopyFeedback);
        showCopyFeedback(false);
        body.removeAllViews();
        copy.setVisibility(next == null ? GONE : VISIBLE);
        if (next == null) {
            body.addView(emptyState(), new LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        } else {
            body.addView(transcriptionView(next), new LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        }
    }

    private View emptyState() {
        LinearLayout row = new LinearLayout(getContext());
        row.setOrientation(HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(dp(16), dp(16), dp(16), dp(16));
        row.setBackgroundResource(R.drawable.app_row_background);

        ImageView icon = new ImageView(getContext());
        icon.setImageResource(R.drawable.ic_waveform_mic);
        row.addView(icon, new LayoutParams(dp(22), dp(22)));

        TextView message = new TextView(getContext());
        message.setText(R.string.home_empty_transcription);
        message.setTextColor(getResources().getColor(R.color.app_secondary_text, getContext().getTheme()));
        message.setTextSize(14);
        message.setTypeface(getResources().getFont(R.font.kanit_light));
        LinearLayout.LayoutParams messageParams = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1);
        messageParams.leftMargin = dp(10);
        row.addView(message, messageParams);
        return row;
    }

    private View transcriptionView(String text) {
        MaxHeightScrollView scroll = new MaxHeightScrollView(
            getContext(),
            dimension(R.dimen.home_transcription_max_height)
        );
        scroll.setMinimumHeight(dp(64));
        scroll.setBackgroundResource(R.drawable.app_row_background);
        TextView value = new TextView(getContext());
        value.setText(text);
        value.setTextColor(getResources().getColor(R.color.app_primary_text, getContext().getTheme()));
        value.setTextSize(18);
        value.setTypeface(getResources().getFont(R.font.kanit_light));
        value.setTextIsSelectable(true);
        value.setGravity(Gravity.START);
        value.setPadding(dp(16), dp(16), dp(16), dp(16));
        scroll.addView(value, new ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ));
        return scroll;
    }

    private void copyTranscription() {
        if (transcription == null) return;
        ClipboardManager clipboard = getContext().getSystemService(ClipboardManager.class);
        clipboard.setPrimaryClip(ClipData.newPlainText("", transcription));
        copy.performHapticFeedback(Build.VERSION.SDK_INT >= 30
            ? HapticFeedbackConstants.CONFIRM
            : HapticFeedbackConstants.KEYBOARD_TAP);
        showCopyFeedback(true);
        main.removeCallbacks(resetCopyFeedback);
        main.postDelayed(resetCopyFeedback, 1_200);
    }

    private void showCopyFeedback(boolean copied) {
        copy.setCompoundDrawablesRelativeWithIntrinsicBounds(
            copied ? R.drawable.ic_check : R.drawable.ic_copy,
            0,
            0,
            0
        );
    }

    @Override protected void onDetachedFromWindow() {
        main.removeCallbacks(resetCopyFeedback);
        showCopyFeedback(false);
        super.onDetachedFromWindow();
    }

    private int dimension(int resource) {
        return getResources().getDimensionPixelSize(resource);
    }

    private int dp(float value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }
}
