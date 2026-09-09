package org.keyvox.android.ime;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import org.keyvox.android.R;

/** Slot plan shared by toolbar accessories and the ten-key reference row. */
final class KeyboardToolbarLayout {
    enum Slot {
        ONE(0), TWO(1), THREE(2), FOUR(3), FIVE(4),
        SIX(5), SEVEN(6), EIGHT(7), NINE(8), ZERO(9);

        final int column;
        Slot(int column) { this.column = column; }
    }

    enum Accessory {
        SPEAK(0),
        DICTIONARY(R.drawable.ic_dictionary),
        PARAGRAPHS(R.drawable.ic_paragraphs),
        LISTS(R.drawable.ic_numbered_list),
        CAPS_LOCK(R.drawable.ic_caps_lock),
        VIBES(0);

        final int iconResource;
        Accessory(int iconResource) { this.iconResource = iconResource; }
    }

    static final class Placement {
        final Accessory accessory;
        final Slot leading;
        final Slot trailing;

        Placement(Accessory accessory, Slot slot) { this(accessory, slot, slot); }

        Placement(Accessory accessory, Slot leading, Slot trailing) {
            this.accessory = accessory;
            this.leading = leading;
            this.trailing = trailing;
        }
    }

    static final class Plan {
        final List<Placement> accessories;
        final Slot logoLeading;
        final Slot utility;

        Plan(List<Placement> accessories, Slot logoLeading, Slot utility) {
            this.accessories = Collections.unmodifiableList(accessories);
            this.logoLeading = logoLeading;
            this.utility = utility;
        }
    }

    private KeyboardToolbarLayout() {}

    static Plan plan(boolean includesSpeak, boolean includesVibes) {
        List<Placement> placements = new ArrayList<>();
        if (includesVibes) {
            if (includesSpeak) placements.add(new Placement(Accessory.SPEAK, Slot.TWO));
            placements.add(new Placement(Accessory.DICTIONARY, Slot.THREE));
            placements.add(new Placement(Accessory.PARAGRAPHS, Slot.FOUR));
            placements.add(new Placement(Accessory.LISTS, Slot.FIVE));
            placements.add(new Placement(Accessory.CAPS_LOCK, Slot.SIX));
            placements.add(new Placement(Accessory.VIBES, Slot.SEVEN, Slot.EIGHT));
        } else {
            if (includesSpeak) placements.add(new Placement(Accessory.SPEAK, Slot.FOUR));
            placements.add(new Placement(Accessory.DICTIONARY, Slot.FIVE));
            placements.add(new Placement(Accessory.PARAGRAPHS, Slot.SIX));
            placements.add(new Placement(Accessory.LISTS, Slot.SEVEN));
            placements.add(new Placement(Accessory.CAPS_LOCK, Slot.EIGHT));
        }
        return new Plan(placements, Slot.NINE, Slot.ONE);
    }
}
