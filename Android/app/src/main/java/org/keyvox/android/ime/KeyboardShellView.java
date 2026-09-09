package org.keyvox.android.ime;

import android.content.Context;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.view.ViewGroup;
import android.view.WindowInsets;
import android.view.Gravity;
import android.widget.LinearLayout;
import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import org.keyvox.android.dictation.DictationSession;

/** Root presentation for the Android KeyVox keyboard. */
final class KeyboardShellView extends LinearLayout {
    private final KeyboardToolbarView toolbar;
    private final KeyboardKeyGridView keyGrid;
    private final GradientDrawable shellBackground;

    KeyboardShellView(
        Context context,
        Runnable nextKeyboard,
        BooleanSupplier delete,
        Consumer<String> insertText,
        Runnable toggleDictation,
        Runnable cancelDictation
    ) {
        super(context);
        setOrientation(VERTICAL);
        setClipChildren(false);
        setClipToPadding(false);

        shellBackground = new GradientDrawable();
        shellBackground.setColor(KeyboardStyle.background(context));
        shellBackground.setCornerRadii(new float[] {
            KeyboardStyle.layoutDp(context, 24), KeyboardStyle.layoutDp(context, 24),
            KeyboardStyle.layoutDp(context, 24), KeyboardStyle.layoutDp(context, 24),
            0, 0, 0, 0
        });
        setBackground(shellBackground);

        int horizontalPadding = KeyboardStyle.layoutDp(context, KeyboardStyle.HORIZONTAL_PADDING_DP);
        int topPadding = KeyboardStyle.layoutDp(context, KeyboardStyle.TOP_PADDING_DP);
        int bottomPadding = KeyboardStyle.layoutDp(context, KeyboardStyle.BOTTOM_PADDING_DP);
        setPadding(horizontalPadding, topPadding, horizontalPadding, bottomPadding);

        setOnApplyWindowInsetsListener((view, insets) -> {
            int navigationBottom = insets.getSystemWindowInsetBottom();
            if (Build.VERSION.SDK_INT >= 30) {
                navigationBottom = insets.getInsetsIgnoringVisibility(WindowInsets.Type.navigationBars()).bottom;
            }
            view.setPadding(horizontalPadding, topPadding, horizontalPadding, navigationBottom + bottomPadding);
            return insets;
        });

        KeyboardContentView content = new KeyboardContentView(context);
        LayoutParams contentParams = new LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        );
        contentParams.gravity = Gravity.CENTER_HORIZONTAL;
        addView(content, contentParams);

        toolbar = new KeyboardToolbarView(context, toggleDictation, cancelDictation);
        content.addView(toolbar, new LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            KeyboardStyle.layoutDp(context, KeyboardStyle.TOOLBAR_HEIGHT_DP)
        ));

        keyGrid = new KeyboardKeyGridView(context, new KeyboardKeyGridView.Listener() {
            @Override public void insertText(String text) { insertText.accept(text); }
            @Override public boolean deleteBackward() { return delete.getAsBoolean(); }
            @Override public void switchToNextKeyboard() { nextKeyboard.run(); }
        });
        LayoutParams keyGridParams = new LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        keyGridParams.topMargin = KeyboardStyle.layoutDp(context, KeyboardStyle.ROW_SPACING_DP);
        content.addView(keyGrid, keyGridParams);
    }

    void render(DictationSession session) {
        toolbar.render(session);
    }

    void refreshAppearance() {
        shellBackground.setColor(KeyboardStyle.background(getContext()));
        toolbar.refreshAppearance();
        keyGrid.refreshAppearance();
        invalidate();
    }
}
