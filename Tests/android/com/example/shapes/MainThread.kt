package com.example.shapes

import androidx.test.platform.app.InstrumentationRegistry

/** Runs `block` on the main (UI) thread, which Swift's main actor runs on. */
fun <T> onMainThread(block: () -> T): T {
    var result: Result<T>? = null
    InstrumentationRegistry.getInstrumentation().runOnMainSync { result = runCatching(block) }
    return result!!.getOrThrow()
}
