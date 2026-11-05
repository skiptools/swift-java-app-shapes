package com.example.shapes

import android.os.Bundle
import androidx.test.runner.AndroidJUnitRunner

/**
 * Loads the Swift libraries on the main thread before any test runs, as an app does at startup:
 * libdispatch binds its main queue, which Swift's main actor runs on, to the thread that loads it.
 */
class ShapesTestRunner : AndroidJUnitRunner() {
    override fun onCreate(arguments: Bundle?) {
        System.loadLibrary("ShapesApp")
        super.onCreate(arguments)
    }
}
