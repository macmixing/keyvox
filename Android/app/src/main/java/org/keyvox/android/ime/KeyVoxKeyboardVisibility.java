package org.keyvox.android.ime;

import java.util.HashSet;
import java.util.Set;

/** Owns whether the KeyVox IME window is currently visible. */
public final class KeyVoxKeyboardVisibility {
    private final Set<Runnable> observers = new HashSet<>();
    private boolean visible;

    public boolean isVisible() {
        return visible;
    }

    public void setVisible(boolean visible) {
        if (this.visible == visible) return;
        this.visible = visible;
        for (Runnable observer : new HashSet<>(observers)) observer.run();
    }

    public void observe(Runnable observer) {
        observers.add(observer);
        observer.run();
    }

    public void removeObserver(Runnable observer) {
        observers.remove(observer);
    }
}
