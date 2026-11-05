package com.example.shapes

/** Runs `block` on the main thread. The JVM tests already run on it (`-XstartOnFirstThread` on macOS). */
fun <T> onMainThread(block: () -> T): T = block()
