package org.keyvox.android.app.dictionary;

import android.content.ClipData;
import android.content.ClipboardManager;
import android.graphics.drawable.GradientDrawable;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.PopupWindow;
import android.widget.TextView;
import org.keyvox.android.R;

/** Dark, rounded row context menu aligned to the selected entry. */
final class DictionaryEntryContextMenu {
    private DictionaryEntryContextMenu() {}

    static void show(View anchor, DictionaryEntry entry, Runnable edit, Runnable delete) {
        LinearLayout menu = new LinearLayout(anchor.getContext());
        menu.setOrientation(LinearLayout.VERTICAL);
        menu.setPadding(0, dp(anchor, 6), 0, dp(anchor, 6));
        GradientDrawable background = new GradientDrawable();
        background.setColor(0xF22C2C2E);
        background.setCornerRadius(dp(anchor, 14));
        background.setStroke(dp(anchor, 1), 0x24FFFFFF);
        menu.setBackground(background);

        PopupWindow popup = new PopupWindow(menu, dp(anchor, 210), ViewGroup.LayoutParams.WRAP_CONTENT, true);
        popup.setBackgroundDrawable(new android.graphics.drawable.ColorDrawable(0x00000000));
        popup.setOutsideTouchable(true);
        popup.setElevation(dp(anchor, 16));

        menu.addView(action(anchor, R.drawable.ic_copy, R.string.copy, false, () -> {
            anchor.getContext().getSystemService(ClipboardManager.class).setPrimaryClip(
                ClipData.newPlainText(entry.phrase(), entry.phrase())
            );
            popup.dismiss();
        }));
        menu.addView(divider(anchor));
        menu.addView(action(anchor, R.drawable.ic_edit, R.string.edit, false, () -> {
            popup.dismiss();
            edit.run();
        }));
        menu.addView(divider(anchor));
        menu.addView(action(anchor, R.drawable.ic_delete, R.string.delete, true, () -> {
            popup.dismiss();
            delete.run();
        }));

        int[] location = new int[2];
        anchor.getLocationOnScreen(location);
        int menuHeight = dp(anchor, 164);
        int screenHeight = anchor.getResources().getDisplayMetrics().heightPixels;
        int preferredY = location[1] + anchor.getHeight() - dp(anchor, 8);
        int y = preferredY + menuHeight <= screenHeight
            ? preferredY
            : location[1] - menuHeight + dp(anchor, 8);
        popup.showAtLocation(
            anchor,
            Gravity.NO_GRAVITY,
            location[0] + dp(anchor, 18),
            Math.max(dp(anchor, 8), y)
        );
    }

    private static View action(View anchor, int iconResource, int labelResource, boolean destructive, Runnable action) {
        LinearLayout row = new LinearLayout(anchor.getContext());
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(dp(anchor, 16), 0, dp(anchor, 16), 0);
        row.setClickable(true);
        int color = destructive ? anchor.getContext().getColor(R.color.app_error) : 0xFFFFFFFF;

        ImageView icon = new ImageView(anchor.getContext());
        icon.setImageResource(iconResource);
        icon.setImageTintList(android.content.res.ColorStateList.valueOf(color));
        row.addView(icon, new LinearLayout.LayoutParams(dp(anchor, 21), dp(anchor, 21)));

        TextView label = new TextView(anchor.getContext());
        label.setText(labelResource);
        label.setTextColor(color);
        label.setTextSize(16);
        label.setTypeface(android.graphics.Typeface.create("sans-serif", android.graphics.Typeface.NORMAL));
        label.setGravity(Gravity.CENTER_VERTICAL);
        LinearLayout.LayoutParams labelParams = new LinearLayout.LayoutParams(0, dp(anchor, 48), 1);
        labelParams.leftMargin = dp(anchor, 12);
        row.addView(label, labelParams);
        row.setOnClickListener(ignored -> action.run());
        return row;
    }

    private static View divider(View anchor) {
        View divider = new View(anchor.getContext());
        divider.setBackgroundColor(0x24FFFFFF);
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            dp(anchor, 1)
        );
        params.leftMargin = dp(anchor, 48);
        divider.setLayoutParams(params);
        return divider;
    }

    private static int dp(View view, float value) {
        return Math.round(value * view.getResources().getDisplayMetrics().density);
    }
}
