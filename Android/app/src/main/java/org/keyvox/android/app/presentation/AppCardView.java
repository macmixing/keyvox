package org.keyvox.android.app.presentation;

import android.content.Context;
import android.widget.FrameLayout;
import org.keyvox.android.R;

/** Shared containing-app card surface. */
public final class AppCardView extends FrameLayout {
    public AppCardView(Context context) {
        super(context);
        int padding = getResources().getDimensionPixelSize(R.dimen.app_card_padding);
        setPadding(padding, padding, padding, padding);
        setBackgroundResource(R.drawable.app_card_background);
    }
}
