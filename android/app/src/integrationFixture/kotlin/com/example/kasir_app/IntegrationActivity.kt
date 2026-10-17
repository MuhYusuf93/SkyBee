package com.example.kasir_app

import android.os.Bundle
import android.view.WindowManager

/** Keeps only the isolated test window awake; no system setting or wake lock.
 * This source directory is excluded from ordinary APKs by the isolation flag.
 */
class IntegrationActivity : MainActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        check(packageName == "com.example.kasir_app.integration")
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }
}
