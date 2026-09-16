package org.keyvox.android.accessibility;

import android.graphics.PointF;
import android.graphics.Rect;
import java.util.ArrayList;
import java.util.List;

/** Calculates the bubble's first screen-edge impact and reflected bounce direction. */
final class BubbleFlingPhysics {
    private static final float IMPACT_EPSILON = 0.0001f;
    private static final float IMPACT_INSET_TOLERANCE = 0.5f;

    enum Edge {
        LEFT(1, 0),
        RIGHT(-1, 0),
        TOP(0, 1),
        BOTTOM(0, -1);

        final PointF normal;

        Edge(float normalX, float normalY) {
            normal = new PointF(normalX, normalY);
        }
    }

    static final class Impact {
        final Edge edge;
        final float timeToImpact;
        final PointF position;

        Impact(Edge edge, float timeToImpact, PointF position) {
            this.edge = edge;
            this.timeToImpact = timeToImpact;
            this.position = position;
        }
    }

    private BubbleFlingPhysics() {}

    static Impact firstImpact(float originX, float originY, float velocityX, float velocityY, Rect bounds) {
        List<Impact> candidates = new ArrayList<>(2);

        if (velocityX > IMPACT_EPSILON) {
            addVerticalImpact(candidates, Edge.RIGHT, bounds.right, originX, originY, velocityX, velocityY, bounds);
        } else if (velocityX < -IMPACT_EPSILON) {
            addVerticalImpact(candidates, Edge.LEFT, bounds.left, originX, originY, velocityX, velocityY, bounds);
        }

        if (velocityY > IMPACT_EPSILON) {
            addHorizontalImpact(candidates, Edge.BOTTOM, bounds.bottom, originX, originY, velocityX, velocityY, bounds);
        } else if (velocityY < -IMPACT_EPSILON) {
            addHorizontalImpact(candidates, Edge.TOP, bounds.top, originX, originY, velocityX, velocityY, bounds);
        }

        Impact earliest = null;
        for (Impact candidate : candidates) {
            if (earliest == null || candidate.timeToImpact < earliest.timeToImpact) earliest = candidate;
        }
        return earliest;
    }

    static PointF reflectedDirection(float velocityX, float velocityY, PointF normal) {
        float dot = velocityX * normal.x + velocityY * normal.y;
        float reflectedX = velocityX - 2 * dot * normal.x;
        float reflectedY = velocityY - 2 * dot * normal.y;
        float length = (float) Math.hypot(reflectedX, reflectedY);
        if (length <= IMPACT_EPSILON) return new PointF(normal.x, normal.y);
        return new PointF(reflectedX / length, reflectedY / length);
    }

    static long travelDurationMillis(float distance, float speed, long minimum, long maximum) {
        long duration = Math.round(1_000f * distance / Math.max(speed, 1));
        return Math.max(minimum, Math.min(maximum, duration));
    }

    private static void addVerticalImpact(
            List<Impact> candidates,
            Edge edge,
            float impactX,
            float originX,
            float originY,
            float velocityX,
            float velocityY,
            Rect bounds) {
        float time = (impactX - originX) / velocityX;
        if (time <= IMPACT_EPSILON) return;
        float y = originY + velocityY * time;
        if (y < bounds.top - IMPACT_INSET_TOLERANCE || y > bounds.bottom + IMPACT_INSET_TOLERANCE) return;
        candidates.add(new Impact(edge, time, new PointF(impactX, clamp(y, bounds.top, bounds.bottom))));
    }

    private static void addHorizontalImpact(
            List<Impact> candidates,
            Edge edge,
            float impactY,
            float originX,
            float originY,
            float velocityX,
            float velocityY,
            Rect bounds) {
        float time = (impactY - originY) / velocityY;
        if (time <= IMPACT_EPSILON) return;
        float x = originX + velocityX * time;
        if (x < bounds.left - IMPACT_INSET_TOLERANCE || x > bounds.right + IMPACT_INSET_TOLERANCE) return;
        candidates.add(new Impact(edge, time, new PointF(clamp(x, bounds.left, bounds.right), impactY)));
    }

    private static float clamp(float value, float minimum, float maximum) {
        return Math.max(minimum, Math.min(maximum, value));
    }
}
