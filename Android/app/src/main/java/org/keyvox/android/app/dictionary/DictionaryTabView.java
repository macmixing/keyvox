package org.keyvox.android.app.dictionary;

import android.content.Context;
import android.graphics.Typeface;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import org.keyvox.android.R;

/** Complete Android containing-app dictionary experience. */
public final class DictionaryTabView extends FrameLayout {
    private final DictionarySession session;
    private final LinearLayout page;
    private final TextView availabilityError;
    private final TextView loadWarning;
    private final TextView saveError;
    private final DictionarySegmentedControl sortControl;
    private final DictionaryEntryListView entryList;
    private final View emptyState;
    private final TextView note;
    private final DictionaryFloatingAddButton addButton;
    private final Runnable editorPresented;
    private final Runnable editorDismissed;
    private final Runnable changed = this::render;
    private DictionarySortMode sortMode = DictionarySortMode.ALPHABETICAL;
    private boolean editorOpen;

    public DictionaryTabView(
        Context context,
        DictionarySession session,
        Runnable editorPresented,
        Runnable editorDismissed
    ) {
        super(context);
        this.session = session;
        this.editorPresented = editorPresented;
        this.editorDismissed = editorDismissed;
        setBackgroundColor(getColor(R.color.app_screen_background));

        ScrollView scroll = new ScrollView(context);
        scroll.setFillViewport(true);
        scroll.setClipToPadding(false);
        scroll.setVerticalScrollBarEnabled(false);
        int screenPadding = dimension(R.dimen.app_screen_padding);
        scroll.setPadding(0, 0, 0, dp(92));
        addView(scroll, new FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        ));

        page = new LinearLayout(context);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setPadding(
            screenPadding,
            dimension(R.dimen.app_tab_page_top_inset),
            screenPadding,
            0
        );
        scroll.addView(page, new ScrollView.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ));

        availabilityError = statusMessage();
        loadWarning = statusMessage();
        saveError = statusMessage();
        entryList = new DictionaryEntryListView(
            context,
            this::presentEditEditor,
            this::confirmDelete
        );
        sortControl = new DictionarySegmentedControl(context, mode -> {
            entryList.closeActiveRowImmediately();
            sortMode = mode;
            render();
        });
        emptyState = createEmptyState();
        note = createNote();

        page.addView(availabilityError, matchWidth(ViewGroup.LayoutParams.WRAP_CONTENT, dp(10)));
        page.addView(loadWarning, matchWidth(ViewGroup.LayoutParams.WRAP_CONTENT, dp(10)));
        page.addView(saveError, matchWidth(ViewGroup.LayoutParams.WRAP_CONTENT, dp(10)));
        page.addView(sortControl, matchWidth(dp(32), dp(24)));
        page.addView(entryList, matchWidth(ViewGroup.LayoutParams.WRAP_CONTENT, 0));
        page.addView(emptyState, matchWidth(ViewGroup.LayoutParams.WRAP_CONTENT, 0));
        page.addView(note, noteLayoutParams());

        addButton = new DictionaryFloatingAddButton(context, this::presentAddEditor);
        int addButtonDiameter = dp(DictionaryFloatingAddButton.DIAMETER_DP);
        FrameLayout.LayoutParams addParams = new FrameLayout.LayoutParams(
            addButtonDiameter,
            addButtonDiameter,
            Gravity.END | Gravity.BOTTOM
        );
        addParams.rightMargin = dp(20);
        addParams.bottomMargin = dp(20);
        addView(addButton, addParams);
    }

    @Override protected void onAttachedToWindow() {
        super.onAttachedToWindow();
        session.observe(changed);
        session.refresh();
    }

    @Override protected void onDetachedFromWindow() {
        session.removeObserver(changed);
        entryList.closeActiveRowImmediately();
        addButton.hideImmediately();
        super.onDetachedFromWindow();
    }

    private void render() {
        updateStatusMessage(
            availabilityError,
            session.unavailable() ? getContext().getString(R.string.dictionary_unavailable) : null
        );
        updateStatusMessage(loadWarning, session.loadWarningMessage());
        updateStatusMessage(saveError, session.saveErrorMessage());

        boolean ready = session.ready();
        List<DictionaryEntry> entries = sortedEntries();
        LinearLayout.LayoutParams sortParams = (LinearLayout.LayoutParams) sortControl.getLayoutParams();
        sortParams.bottomMargin = entries.isEmpty() ? dp(20) : dp(24);
        sortControl.setLayoutParams(sortParams);
        entryList.submitEntries(entries);
        sortControl.setVisibility(ready ? View.VISIBLE : View.GONE);
        entryList.setVisibility(ready && !entries.isEmpty() ? View.VISIBLE : View.GONE);
        emptyState.setVisibility(ready && entries.isEmpty() ? View.VISIBLE : View.GONE);
        note.setVisibility(ready ? View.VISIBLE : View.GONE);
        if (ready && !editorOpen) {
            if (addButton.getVisibility() != View.VISIBLE) addButton.present();
        } else {
            addButton.hideImmediately();
        }
    }

    private List<DictionaryEntry> sortedEntries() {
        List<DictionaryEntry> result = new ArrayList<>(session.entries());
        if (sortMode == DictionarySortMode.ALPHABETICAL) {
            result.sort(Comparator
                .comparing(DictionaryEntry::phrase, String.CASE_INSENSITIVE_ORDER)
                .thenComparing(DictionaryEntry::id));
        } else {
            java.util.Collections.reverse(result);
        }
        return result;
    }

    private TextView statusMessage() {
        TextView status = new TextView(getContext());
        status.setTextColor(getColor(R.color.app_error));
        status.setTextSize(12);
        status.setGravity(Gravity.CENTER);
        status.setTypeface(getResources().getFont(R.font.kanit_medium), Typeface.NORMAL);
        status.setVisibility(View.GONE);
        return status;
    }

    private void updateStatusMessage(TextView status, String message) {
        status.setText(message == null ? "" : message);
        status.setVisibility(message == null || message.isEmpty() ? View.GONE : View.VISIBLE);
    }

    private View createEmptyState() {
        LinearLayout empty = new LinearLayout(getContext());
        empty.setOrientation(LinearLayout.VERTICAL);
        empty.setGravity(Gravity.CENTER);
        empty.setPadding(0, dp(28), 0, dp(12));

        ImageView icon = new ImageView(getContext());
        icon.setImageResource(R.drawable.ic_dictionary);
        icon.setImageTintList(android.content.res.ColorStateList.valueOf(getColor(R.color.app_secondary_text)));
        empty.addView(icon, new LinearLayout.LayoutParams(dp(42), dp(42)));

        TextView title = emptyText(R.string.dictionary_empty_title, 18, R.font.kanit_medium);
        LinearLayout.LayoutParams titleParams = matchWidth(ViewGroup.LayoutParams.WRAP_CONTENT, 0);
        titleParams.topMargin = dp(10);
        empty.addView(title, titleParams);

        TextView description = emptyText(R.string.dictionary_empty_description, 13, R.font.kanit_light);
        LinearLayout.LayoutParams descriptionParams = matchWidth(ViewGroup.LayoutParams.WRAP_CONTENT, 0);
        descriptionParams.topMargin = dp(4);
        empty.addView(description, descriptionParams);
        empty.setVisibility(View.GONE);
        return empty;
    }

    private TextView createNote() {
        TextView note = new TextView(getContext());
        note.setText(R.string.dictionary_english_only);
        note.setTextColor(getColor(R.color.app_secondary_text));
        note.setTextSize(11);
        note.setGravity(Gravity.CENTER);
        note.setTypeface(getResources().getFont(R.font.kanit_medium), Typeface.NORMAL);
        return note;
    }

    private LinearLayout.LayoutParams noteLayoutParams() {
        LinearLayout.LayoutParams params = matchWidth(ViewGroup.LayoutParams.WRAP_CONTENT, 0);
        params.topMargin = dp(4);
        return params;
    }

    private TextView emptyText(int text, float size, int font) {
        TextView view = new TextView(getContext());
        view.setText(text);
        view.setTextColor(getColor(R.color.app_secondary_text));
        view.setTextSize(size);
        view.setGravity(Gravity.CENTER);
        view.setTypeface(getResources().getFont(font));
        return view;
    }

    private void presentAddEditor() {
        presentEditor(null, () -> {
            sortMode = DictionarySortMode.RECENTLY_ADDED;
            sortControl.selectWithoutFeedback(sortMode);
        });
    }

    private void presentEditEditor(DictionaryEntry entry) {
        presentEditor(entry, () -> {});
    }

    private void presentEditor(DictionaryEntry entry, Runnable saved) {
        if (editorOpen) return;
        DictionaryWordEditorDialog editor = new DictionaryWordEditorDialog(
            getContext(),
            session,
            entry,
            saved
        );
        editorOpen = true;
        addButton.hideImmediately();
        editorPresented.run();
        editor.setOnDismissListener(ignored -> {
            editorOpen = false;
            if (session.ready()) addButton.present();
            editorDismissed.run();
        });
        editor.show();
    }

    private void confirmDelete(DictionaryEntry entry) {
        DictionaryDeleteConfirmationDialog.show(getContext(), () ->
            session.delete(entry, (success, message) -> {
                if (!success && message != null) {
                    // The authoritative save error is rendered by the session update.
                    announceForAccessibility(message);
                }
            })
        );
    }

    private LinearLayout.LayoutParams matchWidth(int height, int bottomMargin) {
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            height
        );
        params.bottomMargin = bottomMargin;
        return params;
    }

    private int getColor(int id) { return getResources().getColor(id, getContext().getTheme()); }
    private int dimension(int id) { return getResources().getDimensionPixelSize(id); }
    private int dp(float value) { return Math.round(value * getResources().getDisplayMetrics().density); }
}
