package com.example.kasir_platform;

import java.util.function.Consumer;

/** Permission history belongs to this installation, not a database backup or PIN
 * session. Returning a denial must not launch another Android activity: that
 * would relock management on every retry. Current OS grants always take priority.
 */
final class BluetoothPermissionGate {
    interface State {
        boolean granted();
        boolean requested();
        void rememberRequest();
    }

    static void request(State state, Runnable launch, Consumer<Boolean> complete) {
        if (state.granted()) {
            complete.accept(true);
            return;
        }
        if (state.requested()) {
            complete.accept(false);
            return;
        }
        state.rememberRequest();
        launch.run();
    }
}
