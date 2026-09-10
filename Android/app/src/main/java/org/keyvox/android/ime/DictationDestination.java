package org.keyvox.android.ime;

/** Tracks which live editor should receive one keyboard-started dictation request. */
final class DictationDestination {
    private long request = -1;
    private long editorGeneration = -1;

    void begin(long request, long editorGeneration) {
        this.request = request;
        this.editorGeneration = editorGeneration;
    }

    void recover(long request) {
        this.request = request;
        editorGeneration = -1;
    }

    void follow(long request, long editorGeneration) {
        if (this.request == request) this.editorGeneration = editorGeneration;
    }

    void clear() {
        request = -1;
        editorGeneration = -1;
    }

    long request() { return request; }
    long editorGeneration() { return editorGeneration; }
}
