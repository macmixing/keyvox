package org.keyvox.android.app.dictionary;

import android.content.Context;
import android.transition.ChangeBounds;
import android.transition.TransitionManager;
import android.view.View;
import android.view.ViewGroup;
import android.view.animation.PathInterpolator;
import android.widget.LinearLayout;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;

/** Reconciles dictionary rows by stable entry ID without rebuilding the list. */
final class DictionaryEntryListView extends LinearLayout {
    private final Consumer<DictionaryEntry> edit;
    private final Consumer<DictionaryEntry> delete;
    private final Map<String, DictionarySwipeEntryRowView> rowsByID = new LinkedHashMap<>();
    private final Map<String, DictionaryEntry> entriesByID = new LinkedHashMap<>();
    private List<DictionaryEntry> renderedEntries = List.of();
    private boolean hasRendered;
    private DictionarySwipeEntryRowView activeRow;

    DictionaryEntryListView(
        Context context,
        Consumer<DictionaryEntry> edit,
        Consumer<DictionaryEntry> delete
    ) {
        super(context);
        this.edit = edit;
        this.delete = delete;
        setOrientation(VERTICAL);
    }

    void submitEntries(List<DictionaryEntry> entries) {
        if (renderedEntries.equals(entries)) return;

        if (hasRendered) {
            ChangeBounds movement = new ChangeBounds();
            movement.setDuration(260);
            movement.setInterpolator(new PathInterpolator(0.2f, 0f, 0f, 1f));
            TransitionManager.beginDelayedTransition(this, movement);
        }

        Map<String, DictionaryEntry> incomingByID = new LinkedHashMap<>();
        for (DictionaryEntry entry : entries) incomingByID.put(entry.id(), entry);

        for (String id : new ArrayList<>(rowsByID.keySet())) {
            DictionaryEntry incoming = incomingByID.get(id);
            if (incoming == null || !incoming.equals(entriesByID.get(id))) {
                DictionarySwipeEntryRowView removedRow = rowsByID.remove(id);
                removeView(removedRow);
                if (activeRow == removedRow) activeRow = null;
                entriesByID.remove(id);
            }
        }

        for (int index = 0; index < entries.size(); index++) {
            DictionaryEntry entry = entries.get(index);
            DictionarySwipeEntryRowView row = rowsByID.get(entry.id());
            if (row == null) {
                row = new DictionarySwipeEntryRowView(
                    getContext(),
                    entry,
                    () -> edit.accept(entry),
                    () -> delete.accept(entry),
                    this::rowInteractionBegan
                );
                rowsByID.put(entry.id(), row);
                entriesByID.put(entry.id(), entry);
            }

            LayoutParams params = rowLayoutParams(index == entries.size() - 1);
            int currentIndex = indexOfChild(row);
            if (currentIndex == View.NO_ID) {
                addView(row, index, params);
            } else if (currentIndex != index) {
                removeView(row);
                addView(row, index, params);
            } else {
                row.setLayoutParams(params);
            }
        }

        renderedEntries = List.copyOf(entries);
        hasRendered = true;
    }

    private void rowInteractionBegan(DictionarySwipeEntryRowView row) {
        if (activeRow != null && activeRow != row) activeRow.closeActions();
        activeRow = row;
    }

    void closeActiveRowImmediately() {
        if (activeRow == null) return;
        activeRow.closeActionsImmediately();
        activeRow = null;
    }

    private LayoutParams rowLayoutParams(boolean isLast) {
        LayoutParams params = new LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            dp(62)
        );
        params.bottomMargin = dp(isLast ? 4 : 10);
        return params;
    }

    private int dp(float value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }
}
