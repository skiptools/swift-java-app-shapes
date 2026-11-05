package com.example.shapes

import com.example.shapes.dependencies.Dependencies
import com.example.shapes.models.Book
import com.example.shapes.models.Genre
import com.example.shapes.models.LibraryError
import com.example.shapes.viewmodels.LoginViewModel
import com.example.shapes.viewmodels.MainLoop
import com.example.shapes.viewmodels.ShelfViewModel
import com.example.shapes.viewmodels.load
import com.example.shapes.viewmodels.setIcon
import com.example.shapes.viewmodels.share
import com.example.shapes.viewmodels.suspending
import java.net.URI
import java.util.Optional
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.atomic.AtomicReference
import kotlin.coroutines.CoroutineContext
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertFailsWith
import kotlin.test.assertIs
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/** Runs coroutines on the main thread, from `runMain`'s loop, as Android's main dispatcher would. */
private class MainLoopDispatcher : CoroutineDispatcher() {
    val queue = LinkedBlockingQueue<Runnable>()

    override fun dispatch(context: CoroutineContext, block: Runnable) {
        queue.add(block)
    }
}

/**
 * Runs `block` in a coroutine on the main thread, running Swift's main loop while it's suspended, as
 * Android's main looper does: main-actor `async` functions finish on the main thread.
 */
fun <T> runMain(block: suspend CoroutineScope.() -> T): T = onMainThread {
    val dispatcher = MainLoopDispatcher()
    val result = AtomicReference<Result<T>?>(null)
    CoroutineScope(dispatcher).launch { result.set(runCatching { block() }) }
    val deadline = System.currentTimeMillis() + 10_000
    while (result.get() == null && System.currentTimeMillis() < deadline) {
        dispatcher.queue.poll()?.run() ?: MainLoop.run(0.01)
    }
    (result.get() ?: error("timed out")).getOrThrow()
}

// Main-actor view models must be used from the main thread: `onMainThread` (Tests/jvm, Tests/android).
class ViewModelsTest {
    @Test
    fun callbacksTypedWithAnotherModulesTypealias() = onMainThread {
        val events = mutableListOf<String>()
        val vm = LoginViewModel.init(LoginViewModel.Callbacks.init({ events += "login" }, { events += "cancel" }))
        vm.submit("ada@example.com")
        vm.submit("")
        assertEquals(listOf("login", "cancel"), events)
        assertEquals("", vm.email)
    }

    @Test
    fun observableViewModelWithManyKindsOfCallbacks() = runMain {
        val opened = mutableListOf<String>()
        val selected = mutableListOf<Int>()
        val links = mutableListOf<URI>()
        val verified = mutableListOf<Pair<String?, Long?>>()
        val callbacks = ShelfViewModel.Callbacks.init(
            { book: Book -> opened += book.title },
            { books: Array<Book> -> selected += books.size },
            { urls: Array<URI> -> links += urls },
            { code: String?, attempt: Long? -> verified += code to attempt },
        )
        val vm = ShelfViewModel.init(Dependencies.preview(), callbacks)
        assertEquals("Library", vm.appName)

        vm.load("a")
        assertEquals(false, vm.isLoading)
        assertEquals(2, vm.books.size)

        vm.open(0)
        vm.selectAll()
        vm.verify("1234", 2)
        vm.verify(null, null)
        assertEquals(listOf("A Short History"), opened)
        assertEquals(listOf(2), selected)
        assertEquals(listOf("1234" to 2L, null to null), verified)
    }

    @Test
    fun asyncCallbacksAsSuspendLambdas() = runMain {
        val shared = mutableListOf<String>()
        val icons = mutableListOf<String?>()
        val callbacks = ShelfViewModel.Callbacks.init(
            { _: Book -> }, { _: Array<Book> -> }, { _: Array<URI> -> }, { _: String?, _: Long? -> },
            { vm: ShelfViewModel, genre: Genre -> suspending { shared += "${vm.appName} ${genre.name}" } },
            { name: String? -> suspending { icons += name } },
        )
        val vm = ShelfViewModel.init(Dependencies.preview(), callbacks)
        vm.share(Genre.science())
        vm.setIcon("dark")
        vm.setIcon(null)
        assertEquals(1, shared.size)
        assertEquals(listOf("dark", null), icons)
    }

    @Test
    fun defaultCallbacks() = runMain {
        val login = LoginViewModel.init(LoginViewModel.Callbacks.init())
        login.submit("ada@example.com")
        assertEquals("ada@example.com", login.email)

        val vm = ShelfViewModel.init(Dependencies.preview(), ShelfViewModel.Callbacks.init())
        vm.load("cosmos")
        assertEquals(listOf("Cosmos"), vm.books.map { it.title })
        vm.open(0)
        vm.selectAll()
        vm.verify(null, null)
        vm.share(Genre.fiction)
        vm.setIcon(null)
        assertEquals(1, vm.books.size)
    }

    @Test
    fun someCallbacks() = runMain {
        val opened = mutableListOf<String>()
        val vm = ShelfViewModel.init(
            Dependencies.preview(),
            ShelfViewModel.Callbacks.init({ book: Book -> opened += book.title }, { _: Array<Book> -> }),
        )
        vm.load("long")
        vm.open(0)
        assertEquals(listOf("A Long Story"), opened)
    }

    @Test
    fun failedLoads() = runMain {
        val vm = ShelfViewModel.init(Dependencies.preview(), ShelfViewModel.Callbacks.init())
        assertFailsWith<LibraryError> { vm.load("") }
        assertEquals(false, vm.isLoading)
        assertEquals(0, vm.books.size)
    }

    @Test
    fun seedProviderReturningAnOptionalArray() = onMainThread {
        val vm = ShelfViewModel.init(Dependencies.preview(), ShelfViewModel.Callbacks.init())
        vm.setSeedProvider { query: String ->
            if (query == "seeded") Optional.of(arrayOf(Book.init("9", "Seeded"))) else Optional.empty()
        }
        vm.seed("seeded")
        assertEquals(listOf("Seeded"), vm.books.map { it.title })
        vm.seed("other")
        assertEquals(0, vm.books.size)
    }

    @Test
    fun callbackHandedASwiftClosure() = onMainThread {
        val vm = ShelfViewModel.init(Dependencies.preview(), ShelfViewModel.Callbacks.init())
        vm.seed("any")
        var shown: List<String>? = null
        var onPicked: ShelfViewModel.pickBook.present.onPicked? = null
        vm.pickBook { titles, selected, picked ->
            shown = titles.toList()
            assertNull(selected)
            onPicked = picked  // kept, and called later, as a picker does
        }
        assertEquals(emptyList(), shown)
        assertNull(vm.picked)
        onPicked!!.invoke("Cosmos")
        assertEquals("Cosmos", vm.picked)
    }
}
