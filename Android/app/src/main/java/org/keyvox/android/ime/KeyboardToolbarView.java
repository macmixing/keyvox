package org.keyvox.android.ime;

import android.content.Context;
import android.view.Gravity;
import android.widget.FrameLayout;
import java.util.ArrayList;
import java.util.List;
import org.keyvox.android.R;
import org.keyvox.android.dictation.DictationSession;

/** Positions fixed and capability-driven controls across the keyboard toolbar. */
final class KeyboardToolbarView extends FrameLayout {
    private final KeyboardIconButton settings;
    private final KeyboardIconButton cancel;
    private final KeyboardLogoBarView logo;
    private final KeyboardToolbarLayout.Plan slotPlan;
    private final List<AccessoryView> packedAccessories = new ArrayList<>();

    private static final class AccessoryView {
        final KeyboardToolbarLayout.Placement placement;
        final KeyboardIconButton view;

        AccessoryView(KeyboardToolbarLayout.Placement placement, KeyboardIconButton view) {
            this.placement = placement;
            this.view = view;
        }
    }

    KeyboardToolbarView(Context context, Runnable toggleDictation, Runnable cancelDictation) {
        super(context);
        slotPlan = KeyboardToolbarLayout.plan(false, false);
        setClipChildren(false);
        setClipToPadding(false);

        settings = new KeyboardIconButton(
            context,
            R.drawable.ic_settings,
            KeyboardIconButton.TintRole.FOREGROUND,
            context.getString(R.string.keyboard_settings),
            null
        );
        addView(settings);

        cancel = new KeyboardIconButton(
            context,
            R.drawable.ic_close,
            KeyboardIconButton.TintRole.CANCEL,
            context.getString(R.string.cancel_dictation),
            cancelDictation
        );
        cancel.setVisibility(GONE);
        addView(cancel);

        addPackedAccessories(slotPlan.accessories);

        logo = new KeyboardLogoBarView(context, toggleDictation);
        addView(logo, new LayoutParams(
            KeyboardStyle.layoutDp(context, KeyboardStyle.LOGO_DIAMETER_DP),
            KeyboardStyle.layoutDp(context, KeyboardStyle.LOGO_DIAMETER_DP)
        ));
    }

    void render(DictationSession session) {
        boolean active = session.phase() == DictationSession.Phase.STARTING
            || session.phase() == DictationSession.Phase.RECORDING
            || session.phase() == DictationSession.Phase.PROCESSING
            || session.phase() == DictationSession.Phase.CANCELLING;
        settings.setVisibility(active ? GONE : VISIBLE);
        cancel.setVisibility(active ? VISIBLE : GONE);
        cancel.setEnabled(session.phase() != DictationSession.Phase.CANCELLING);
        logo.render(session);
    }

    void refreshAppearance() {
        settings.refreshAppearance();
        cancel.refreshAppearance();
        for (AccessoryView accessory : packedAccessories) accessory.view.refreshAppearance();
        logo.refreshAppearance();
    }

    @Override protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        int width = MeasureSpec.getSize(widthMeasureSpec);
        int height = KeyboardStyle.layoutDp(getContext(), KeyboardStyle.TOOLBAR_HEIGHT_DP);
        int utilityColumn = slotPlan.utility.column;
        int fixedWidth = KeyboardStyle.tenColumnRight(getContext(), width, utilityColumn)
            - KeyboardStyle.tenColumnLeft(getContext(), width, utilityColumn);
        int fixedHeight = Math.min(fixedWidth, height);
        settings.measure(
            MeasureSpec.makeMeasureSpec(fixedWidth, MeasureSpec.EXACTLY),
            MeasureSpec.makeMeasureSpec(fixedHeight, MeasureSpec.EXACTLY)
        );
        cancel.measure(
            MeasureSpec.makeMeasureSpec(fixedWidth, MeasureSpec.EXACTLY),
            MeasureSpec.makeMeasureSpec(fixedHeight, MeasureSpec.EXACTLY)
        );
        for (AccessoryView accessoryView : packedAccessories) {
            int leadingColumn = accessoryView.placement.leading.column;
            int trailingColumn = accessoryView.placement.trailing.column;
            int accessoryWidth = KeyboardStyle.tenColumnRight(getContext(), width, trailingColumn)
                - KeyboardStyle.tenColumnLeft(getContext(), width, leadingColumn);
            int accessoryHeight = Math.min(
                KeyboardStyle.tenColumnRight(getContext(), width, leadingColumn)
                    - KeyboardStyle.tenColumnLeft(getContext(), width, leadingColumn),
                height
            );
            accessoryView.view.measure(
                MeasureSpec.makeMeasureSpec(accessoryWidth, MeasureSpec.EXACTLY),
                MeasureSpec.makeMeasureSpec(accessoryHeight, MeasureSpec.EXACTLY)
            );
        }
        int logoSize = KeyboardStyle.layoutDp(getContext(), KeyboardStyle.LOGO_DIAMETER_DP);
        logo.measure(
            MeasureSpec.makeMeasureSpec(logoSize, MeasureSpec.EXACTLY),
            MeasureSpec.makeMeasureSpec(logoSize, MeasureSpec.EXACTLY)
        );
        setMeasuredDimension(width, resolveSize(height, heightMeasureSpec));
    }

    @Override protected void onLayout(boolean changed, int left, int top, int right, int bottom) {
        int width = right - left;
        int height = bottom - top;
        int utilityColumn = slotPlan.utility.column;
        int fixedLeft = KeyboardStyle.tenColumnLeft(getContext(), width, utilityColumn);
        int fixedWidth = KeyboardStyle.tenColumnRight(getContext(), width, utilityColumn) - fixedLeft;
        int fixedHeight = Math.min(fixedWidth, height);
        int keyTop = height - fixedHeight;

        settings.layout(fixedLeft, keyTop, fixedLeft + fixedWidth, keyTop + fixedHeight);
        cancel.layout(fixedLeft, keyTop, fixedLeft + fixedWidth, keyTop + fixedHeight);

        for (AccessoryView accessoryView : packedAccessories) {
            int leadingColumn = accessoryView.placement.leading.column;
            int trailingColumn = accessoryView.placement.trailing.column;
            int accessoryLeft = KeyboardStyle.tenColumnLeft(getContext(), width, leadingColumn);
            int accessoryRight = KeyboardStyle.tenColumnRight(getContext(), width, trailingColumn);
            int accessoryHeight = Math.min(
                KeyboardStyle.tenColumnRight(getContext(), width, leadingColumn) - accessoryLeft,
                height
            );
            int accessoryTop = height - accessoryHeight;
            accessoryView.view.layout(
                accessoryLeft,
                accessoryTop,
                accessoryRight,
                height
            );
        }

        int logoSize = KeyboardStyle.layoutDp(getContext(), KeyboardStyle.LOGO_DIAMETER_DP);
        int logoCenter = KeyboardStyle.tenColumnRight(getContext(), width, slotPlan.logoLeading.column)
            + KeyboardStyle.layoutDp(getContext(), KeyboardStyle.KEY_SPACING_DP) / 2;
        int logoLeft = logoCenter - logoSize / 2;
        int logoTop = height - logoSize;
        logo.layout(logoLeft, logoTop, logoLeft + logoSize, logoTop + logoSize);
    }

    private void addPackedAccessories(List<KeyboardToolbarLayout.Placement> placements) {
        for (KeyboardToolbarLayout.Placement placement : placements) {
            KeyboardToolbarLayout.Accessory accessory = placement.accessory;
            if (accessory.iconResource == 0) continue;
            KeyboardIconButton button = new KeyboardIconButton(
                getContext(),
                accessory.iconResource,
                accessory == KeyboardToolbarLayout.Accessory.LISTS
                    ? KeyboardIconButton.TintRole.ACTIVE
                    : KeyboardIconButton.TintRole.FOREGROUND,
                accessibilityLabel(accessory),
                null
            );
            packedAccessories.add(new AccessoryView(placement, button));
            addView(button);
        }
    }

    private CharSequence accessibilityLabel(KeyboardToolbarLayout.Accessory accessory) {
        switch (accessory) {
            case DICTIONARY: return getContext().getString(R.string.keyboard_dictionary);
            case PARAGRAPHS: return getContext().getString(R.string.keyboard_paragraphs);
            case LISTS: return getContext().getString(R.string.keyboard_lists);
            case CAPS_LOCK: return getContext().getString(R.string.keyboard_caps_lock);
            case SPEAK: return getContext().getString(R.string.keyboard_speak);
            case VIBES: return getContext().getString(R.string.keyboard_vibes);
            default: return getContext().getString(R.string.keyboard_settings);
        }
    }
}
