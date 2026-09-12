package org.keyvox.android.app.dictionary;

import android.app.Dialog;
import android.content.Context;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.text.Editable;
import android.text.InputType;
import android.text.TextWatcher;
import android.view.Gravity;
import android.view.HapticFeedbackConstants;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowManager;
import android.view.inputmethod.InputMethodManager;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.TextView;
import org.keyvox.android.R;

/** Compact add/edit sheet whose validation remains owned by DictionaryStore. */
final class DictionaryWordEditorDialog extends Dialog {
    private final DictionarySession session;
    private final DictionaryEntry entry;
    private final EditText phrase;
    private final TextView action;
    private final TextView error;
    private final Runnable onAdded;

    DictionaryWordEditorDialog(
        Context context,
        DictionarySession session,
        DictionaryEntry entry,
        Runnable onAdded
    ) {
        super(context);
        this.session = session;
        this.entry = entry;
        this.onAdded = onAdded;
        requestWindowFeature(Window.FEATURE_NO_TITLE);

        LinearLayout sheet = new LinearLayout(context);
        sheet.setOrientation(LinearLayout.VERTICAL);
        sheet.setPadding(dp(16), dp(8), dp(16), dp(30));
        sheet.setBackground(sheetBackground());

        View dragIndicator = new View(context);
        GradientDrawable indicatorBackground = new GradientDrawable();
        indicatorBackground.setColor(0x667F7F7F);
        indicatorBackground.setCornerRadius(dp(2));
        dragIndicator.setBackground(indicatorBackground);
        LinearLayout.LayoutParams indicatorParams = new LinearLayout.LayoutParams(dp(36), dp(5));
        indicatorParams.gravity = Gravity.CENTER_HORIZONTAL;
        indicatorParams.bottomMargin = dp(8);
        sheet.addView(dragIndicator, indicatorParams);

        LinearLayout toolbar = new LinearLayout(context);
        toolbar.setGravity(Gravity.CENTER_VERTICAL);
        TextView cancel = toolbarButton(R.string.cancel, Color.WHITE);
        cancel.setGravity(Gravity.START | Gravity.CENTER_VERTICAL);
        cancel.setOnClickListener(ignored -> dismiss());
        toolbar.addView(cancel, new LinearLayout.LayoutParams(0, dp(44), 1));

        TextView title = new TextView(context);
        title.setText(entry == null ? R.string.dictionary_add_title : R.string.dictionary_edit_title);
        title.setTextColor(Color.WHITE);
        title.setTextSize(17);
        title.setTypeface(Typeface.create("sans-serif", Typeface.BOLD));
        title.setGravity(Gravity.CENTER);
        toolbar.addView(title, new LinearLayout.LayoutParams(0, dp(44), 2));

        action = toolbarButton(
            entry == null ? R.string.add : R.string.save,
            getColor(R.color.app_accent)
        );
        action.setGravity(Gravity.END | Gravity.CENTER_VERTICAL);
        action.setOnClickListener(ignored -> submit());
        toolbar.addView(action, new LinearLayout.LayoutParams(0, dp(44), 1));
        sheet.addView(toolbar, new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ));

        phrase = new EditText(context);
        phrase.setText(entry == null ? "" : entry.phrase());
        phrase.setHint(R.string.dictionary_placeholder);
        phrase.setSingleLine(true);
        phrase.setTextSize(16);
        phrase.setTextColor(Color.WHITE);
        phrase.setHintTextColor(getColor(R.color.app_secondary_text));
        phrase.setTypeface(getContext().getResources().getFont(R.font.kanit_light));
        phrase.setInputType(InputType.TYPE_CLASS_TEXT
            | InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
            | InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS);
        phrase.setImeOptions(android.view.inputmethod.EditorInfo.IME_ACTION_DONE);
        phrase.setPadding(dp(16), 0, dp(16), 0);
        phrase.setBackground(rowBackground());
        phrase.setOnEditorActionListener((view, actionID, event) -> {
            if (actionID == android.view.inputmethod.EditorInfo.IME_ACTION_DONE) {
                submit();
                return true;
            }
            return false;
        });
        sheet.addView(phrase, new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            dp(52)
        ));

        error = new TextView(context);
        error.setTextColor(getColor(R.color.app_error));
        error.setTextSize(12);
        error.setGravity(Gravity.CENTER);
        error.setTypeface(getContext().getResources().getFont(R.font.kanit_medium));
        error.setVisibility(View.GONE);
        LinearLayout.LayoutParams errorParams = new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        );
        errorParams.topMargin = dp(8);
        sheet.addView(error, errorParams);

        if (entry == null) {
            TextView description = new TextView(context);
            description.setText(R.string.dictionary_add_description);
            description.setTextColor(getColor(R.color.app_primary_action));
            description.setTextSize(12);
            description.setGravity(Gravity.CENTER);
            description.setTypeface(getContext().getResources().getFont(R.font.kanit_medium));
            LinearLayout.LayoutParams descriptionParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            );
            descriptionParams.topMargin = dp(10);
            sheet.addView(description, descriptionParams);
        }

        phrase.addTextChangedListener(new TextWatcher() {
            @Override public void beforeTextChanged(CharSequence value, int start, int count, int after) {}
            @Override public void onTextChanged(CharSequence value, int start, int before, int count) {
                error.setVisibility(View.GONE);
                updateActionState();
            }
            @Override public void afterTextChanged(Editable value) {}
        });
        updateActionState();
        setContentView(sheet);
    }

    @Override public void show() {
        super.show();
        Window window = getWindow();
        if (window != null) {
            window.setBackgroundDrawableResource(android.R.color.transparent);
            window.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
            window.setGravity(Gravity.BOTTOM);
            window.addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND);
            WindowManager.LayoutParams attributes = window.getAttributes();
            attributes.dimAmount = 0.38f;
            window.setAttributes(attributes);
            window.setSoftInputMode(
                WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE
                    | WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_VISIBLE
            );
        }
        phrase.requestFocus();
        phrase.setSelection(phrase.length());
        phrase.post(() -> getContext().getSystemService(InputMethodManager.class)
            .showSoftInput(phrase, InputMethodManager.SHOW_IMPLICIT));
    }

    private void submit() {
        String value = phrase.getText().toString().trim();
        if (value.isEmpty() || !action.isEnabled()) return;
        action.setEnabled(false);
        DictionarySession.MutationCallback callback = (success, message) -> {
            if (success) {
                if (entry == null) {
                    phrase.performHapticFeedback(HapticFeedbackConstants.CONFIRM);
                    onAdded.run();
                }
                dismiss();
            } else {
                phrase.performHapticFeedback(HapticFeedbackConstants.REJECT);
                error.setText(message);
                error.setVisibility(View.VISIBLE);
                updateActionState();
            }
        };
        if (entry == null) session.add(value, callback);
        else session.update(entry, value, callback);
    }

    private void updateActionState() {
        boolean enabled = phrase != null && !phrase.getText().toString().trim().isEmpty();
        action.setEnabled(enabled);
        action.setAlpha(enabled ? 1 : 0.42f);
    }

    private TextView toolbarButton(int label, int color) {
        TextView button = new TextView(getContext());
        button.setText(label);
        button.setTextColor(color);
        button.setTextSize(16);
        button.setTypeface(Typeface.create("sans-serif", Typeface.NORMAL));
        button.setClickable(true);
        return button;
    }

    private GradientDrawable sheetBackground() {
        GradientDrawable background = new GradientDrawable();
        background.setColor(getColor(R.color.app_screen_background));
        background.setCornerRadii(new float[] {dp(18), dp(18), dp(18), dp(18), 0, 0, 0, 0});
        background.setStroke(dp(1), getColor(R.color.app_card_stroke));
        return background;
    }

    private GradientDrawable rowBackground() {
        GradientDrawable background = new GradientDrawable();
        background.setColor(getColor(R.color.app_row_fill));
        background.setCornerRadius(dp(10));
        background.setStroke(dp(1), getColor(R.color.app_row_stroke));
        return background;
    }

    private int getColor(int id) { return getContext().getResources().getColor(id, getContext().getTheme()); }
    private int dp(float value) { return Math.round(value * getContext().getResources().getDisplayMetrics().density); }
}
