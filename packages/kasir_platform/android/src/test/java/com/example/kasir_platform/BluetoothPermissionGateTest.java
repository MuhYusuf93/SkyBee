package com.example.kasir_platform;

import java.util.concurrent.atomic.AtomicInteger;
import java.util.ArrayList;
import java.util.List;
import org.junit.Test;
import static org.junit.Assert.*;

/** Counts actual prompt callbacks across simulated plugin/session recreation.
 * Android dialog/lifecycle behavior still requires the physical-device retest.
 */
public final class BluetoothPermissionGateTest {
    private static final class Store {
        boolean granted, requested;
    }
    private static BluetoothPermissionGate.State session(Store store) {
        return new BluetoothPermissionGate.State() {
            public boolean granted() { return store.granted; }
            public boolean requested() { return store.requested; }
            public void rememberRequest() { store.requested = true; }
        };
    }
    @Test public void denialDoesNotLaunchAgainAcrossPinAndPluginRecreation() {
        Store store = new Store();
        AtomicInteger prompts = new AtomicInteger();
        List<Boolean> results = new ArrayList<>();
        BluetoothPermissionGate.request(session(store), prompts::incrementAndGet, results::add);
        assertEquals(1, prompts.get());
        assertTrue(store.requested);
        assertTrue(results.isEmpty()); // Android owns the pending first result.
        results.add(false); // User denies, then re-enters PIN.
        for (int retry = 0; retry < 3; retry++) {
            BluetoothPermissionGate.request(session(store), prompts::incrementAndGet, results::add);
        }
        assertEquals("Retries must not relaunch the OS permission dialog", 1, prompts.get());
        assertEquals(List.of(false, false, false, false), results);
    }
    @Test public void settingsGrantIsAcceptedThenRevocationFailsClosedWithoutPrompt() {
        Store store = new Store();
        store.requested = true;
        store.granted = true;
        AtomicInteger prompts = new AtomicInteger();
        List<Boolean> results = new ArrayList<>();
        BluetoothPermissionGate.request(session(store), prompts::incrementAndGet, results::add);
        store.granted = false;
        BluetoothPermissionGate.request(session(store), prompts::incrementAndGet, results::add);
        assertEquals(0, prompts.get());
        assertEquals(List.of(true, false), results);
    }
    @Test public void existingGrantNeverRecordsAnUnnecessaryPrompt() {
        Store store = new Store();
        store.granted = true;
        List<Boolean> results = new ArrayList<>();
        BluetoothPermissionGate.request(session(store), () -> fail("Already granted"), results::add);
        assertFalse(store.requested);
        assertEquals(List.of(true), results);
    }
}
