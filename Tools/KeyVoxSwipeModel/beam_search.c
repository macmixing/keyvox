// Lexicon-constrained CTC beam search over a key-path trie.
//
// Each beam entry is a trie node (a key-path prefix) with the log-probability of every
// alignment so far that spells exactly that prefix, split by whether the last frame was a
// blank (lb) or the prefix's last key (lnb). After each frame the beam keeps the `beam`
// prefixes with the highest pruning score
//     log p(prefix) / max(depth, 1)^prune_gamma + prune_beta * depth,
// which keeps short prefixes from crowding out longer ones. After the last frame, every
// surviving prefix that ends a word is a candidate, with the exact CTC log-probability of
// its full key path.

#include <math.h>
#include <stdlib.h>

typedef struct {
    int node;
    float blank;
    float key;
    float score;
} Entry;

static float add_log(float a, float b) {
    if (a == -INFINITY) return b;
    if (b == -INFINITY) return a;
    float high = a > b ? a : b;
    return high + log1pf(expf(-fabsf(a - b)));
}

static int by_score_descending(const void *left, const void *right) {
    float a = ((const Entry *)left)->score, b = ((const Entry *)right)->score;
    return (a < b) - (a > b);
}

static void accumulate(Entry *next, int *count, int *slot, int node, float blank, float key) {
    int index = slot[node];
    if (index < 0) {
        index = (*count)++;
        slot[node] = index;
        next[index].node = node;
        next[index].blank = blank;
        next[index].key = key;
        return;
    }
    next[index].blank = add_log(next[index].blank, blank);
    next[index].key = add_log(next[index].key, key);
}

// emissions: [frames, symbols] log-probabilities, symbol 0 is the blank, symbol k + 1 is key k.
// slot: node_count ints, all -1 on entry and on return.
// current, next: room for beam * (largest child count + 1) entries each.
// Returns the number of candidates written to out_node / out_log_probability (at most beam).
int keyvox_beam_search(
    const float *emissions, int frames, int symbols,
    const int *node_key, const int *node_depth, const int *child_start, const int *child_node,
    const int *form_start, int beam, float prune_gamma, float prune_beta,
    int *slot, Entry *current, Entry *next, int *out_node, float *out_log_probability) {
    int current_count = 1;
    current[0].node = 0;
    current[0].blank = 0.0f;
    current[0].key = -INFINITY;

    for (int frame = 0; frame < frames; frame++) {
        const float *emission = emissions + (size_t)frame * symbols;
        int next_count = 0;
        for (int i = 0; i < current_count; i++) {
            const Entry *entry = &current[i];
            int node = entry->node;
            float total = add_log(entry->blank, entry->key);
            float stay_key = node > 0 ? entry->key + emission[node_key[node] + 1] : -INFINITY;
            accumulate(next, &next_count, slot, node, total + emission[0], stay_key);
            for (int c = child_start[node]; c < child_start[node + 1]; c++) {
                int child = child_node[c];
                int key = node_key[child];
                float before = (node > 0 && node_key[node] == key) ? entry->blank : total;
                accumulate(next, &next_count, slot, child, -INFINITY, before + emission[key + 1]);
            }
        }
        for (int i = 0; i < next_count; i++) {
            Entry *entry = &next[i];
            slot[entry->node] = -1;
            int depth = node_depth[entry->node];
            float length = depth > 1 ? (float)depth : 1.0f;
            entry->score = add_log(entry->blank, entry->key) / powf(length, prune_gamma) + prune_beta * depth;
        }
        if (next_count > beam) {
            qsort(next, next_count, sizeof(Entry), by_score_descending);
            next_count = beam;
        }
        Entry *swap = current;
        current = next;
        next = swap;
        current_count = next_count;
    }

    int candidates = 0;
    for (int i = 0; i < current_count; i++) {
        int node = current[i].node;
        if (form_start[node + 1] > form_start[node]) {
            out_node[candidates] = node;
            out_log_probability[candidates] = add_log(current[i].blank, current[i].key);
            candidates++;
        }
    }
    return candidates;
}
