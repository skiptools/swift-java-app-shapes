package com.example.shapes

import com.example.shapes.clients.CatalogClient
import com.example.shapes.clients.DownloadProgress
import java.util.concurrent.CompletableFuture
import org.swift.swiftkit.core.SwiftArena
import com.example.shapes.clients.verify
import com.example.shapes.clients.DeviceSession
import com.example.shapes.clients.DeviceClient
import com.example.shapes.clients.AnalyticsClient
import com.example.shapes.clients.AnalyticsInput
import com.example.shapes.clients.AnalyticsRecorder
import com.example.shapes.clients.LifecycleObserver
import com.example.shapes.clients.LifecycleObserverFactory
import com.example.shapes.clients.AuthMonitor
import com.example.shapes.clients.NotificationsClient
import com.example.shapes.clients.NotificationsClientMock
import com.example.shapes.clients.SearchClient
import com.example.shapes.clients.SearchClientMock
import com.example.shapes.clients.search
import com.example.shapes.clients.shareText
import com.example.shapes.clients.updates
import com.example.shapes.clients.waitUntilComplete
import com.example.shapes.models.Book
import com.example.shapes.models.LibraryError
import com.example.shapes.models.Message
import com.example.shapes.models.Shelf
import com.example.shapes.models.ShelfID
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue
import kotlin.test.assertFailsWith
import kotlin.test.assertIs
import kotlin.test.assertNull
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout

class ClientsTest {
    private val books = arrayOf(Book.init("1", "Cosmos"), Book.init("2", "Cosmic Dust"), Book.init("3", "History"))

    @Test
    fun protocolExtensionMembersAndAsyncRequirements() {
        val search: SearchClient = SearchClientMock.init("mock", books)
        assertEquals("search mock", search.name)   // implemented by the protocol extension
        runBlocking {
            assertEquals(2, search.search("cosm").size)
            assertFailsWith<LibraryError> { search.search("") }
        }
    }

    @Test
    fun requirementTakingAClosure() {
        val mock = NotificationsClientMock.init()
        val client: NotificationsClient = mock
        var failures = 0
        client.onAuthError { failures++ }
        mock.failAuth()
        assertEquals(1, failures)

        client.notify_(Message.string("hi"))
        assertEquals(listOf("hi"), mock.delivered.toList())
    }

    @Test
    fun swiftClosureToAKotlinImplementation() {
        val handlers = mutableListOf<NotificationsClient.onAuthError.handler>()
        val client = object : NotificationsClient {
            override fun onAuthError(handler: NotificationsClient.onAuthError.handler) {
                handlers += handler
            }

            override fun notify_(message: Message) {}
        }
        val monitor = AuthMonitor.init(client)   // Swift passes its closure to Kotlin's onAuthError
        assertEquals(1, handlers.size)
        handlers.forEach { it.invoke() }
        handlers.forEach { it.invoke() }
        assertEquals(2, monitor.failures)
    }

    @Test
    fun dictionariesOfAnotherModulesTypes() {
        val catalog = CatalogClient.init(arrayOf(Shelf.init(ShelfID.init("a"), books), Shelf.init(ShelfID.init("b"), books)))
        val all = catalog.all()
        assertEquals(2, all.size)
        assertEquals(3, all[ShelfID.init("a")]!!.books.size)
        assertEquals(setOf("a", "b"), catalog.ids().map { it.rawValue }.toSet())
    }

    @Test
    fun combineBackedState() {
        val progress = DownloadProgress.init()
        progress.advance(0.25)
        progress.advance(0.25)
        assertEquals(0.5, progress.current)
    }

    @Test
    fun protocolProperties() {
        val mock = SearchClientMock.init("mock", books)
        assertEquals("mock", mock.id)
        val search: SearchClient = mock
        assertEquals("mock", search.id)
    }

    @Test
    fun everyMessageReachesTheClient() {
        val mock = NotificationsClientMock.init()
        mock.notify_(Message.string("hi"))
        mock.notify_(Message.closed(1000, "bye"))
        mock.notify_(Message.closed(1001, null))
        mock.notify_(Message.event("page", mapOf("b" to "2", "a" to "1")))
        mock.notify_(Message.event("page", null))
        assertEquals(
            listOf("hi", "closed 1000 bye", "closed 1001 ", "page [\"a=1\", \"b=2\"]", "page []"),
            mock.delivered.toList(),
        )
        assertEquals(5, mock.deliveredCount)
    }

    @Test
    fun dictionariesAndAnyAreKotlinMaps() {
        val tracked = mutableListOf<Pair<String, Map<String, Any>>>()
        var pushed: Map<Any, Any>? = null
        val client = object : AnalyticsClient {
            override fun track(event: String, properties: Map<String, Any>) {
                tracked += event to properties
            }

            override fun handlePush(userInfo: Map<Any, Any>): Boolean {
                pushed = userInfo
                return userInfo.containsKey("aps")
            }
        }
        val recorder = AnalyticsRecorder.init(client)
        val properties = mapOf("count" to 2L, "tags" to listOf("a", "b"), "nested" to mapOf("on" to true), "skipped" to null)
        recorder.record(AnalyticsInput.init("opened", properties))
        recorder.record(AnalyticsInput.init("opened"))
        // `nil` values are dropped by the recorder; the rest come back as Kotlin values.
        assertEquals(
            listOf(
                "opened" to mapOf("count" to 2L, "tags" to listOf("a", "b"), "nested" to mapOf("on" to true)),
                "opened" to emptyMap(),
            ),
            tracked,
        )
        assertEquals(true, recorder.receivePush(mapOf("aps" to mapOf("alert" to "hi"))))
        assertEquals(mapOf<Any, Any>("aps" to mapOf("alert" to "hi")), pushed)
        assertEquals(mapOf("opened" to 2L), recorder.eventCounts())

        // An optional dictionary of optional values: `null` for `nil`, at both levels.
        assertEquals(mapOf("a" to "b", "n" to null), AnalyticsInput.init("x", mapOf("a" to "b", "n" to null)).properties)
        assertNull(AnalyticsInput.init("y").properties)
    }

    @Test
    fun combineBackedStateIsClamped() {
        val progress = DownloadProgress.init()
        assertEquals(0.0, progress.current)
        progress.advance(2.0)
        assertEquals(1.0, progress.current)
    }

    @Test
    fun extensionOfAnotherModulesType() {
        val book = Book.init("1", "Cosmos", 300)
        assertEquals("Cosmos (300 pages)", book.shareText())
    }

    @Test
    fun emptyCatalog() {
        val catalog = CatalogClient.init(arrayOf())
        assertEquals(0, catalog.all().size)
        assertNull(catalog.all()[ShelfID.init("a")])
        assertEquals(0, catalog.ids().size)
    }

    @Test
    fun closureReturningAKotlinImplementationOfAProtocol() {
        val disposed = mutableListOf<String>()
        val factory = LifecycleObserverFactory.init { id: String ->
            object : LifecycleObserver {
                override fun dispose() {
                    disposed += id
                }
            }
        }
        factory.observeOnce("a")
        factory.observeOnce("b")
        assertEquals(listOf("a", "b"), disposed)
    }

    @Test
    fun optionalResultsAndAsyncRequirementsOfAKotlinImplementation() = runBlocking {
        var device: String? = null
        var seen: Long? = null
        var book: Book? = null
        val codes = mutableListOf<String?>()
        val client = object : DeviceClient {
            override fun deviceId(): String? = device
            override fun lastSeen(): Long? = seen
            override fun lastBook(swiftArena: SwiftArena): Book? = book
            override fun verifyAsync(code: String?): CompletableFuture<Boolean> {
                codes += code
                return CompletableFuture.completedFuture(code == "1234")
            }
        }
        val session = DeviceSession.init(client)
        assertEquals("none never no book", session.describe())
        device = "pixel"
        seen = 42
        book = books[0]
        assertEquals("pixel 42 Cosmos", session.describe())
        assertTrue(session.verify("1234"))
        assertFalse(session.verify(null))
        assertEquals(listOf("1234", null), codes)
    }

    @Test
    fun suspendFunctionsAwaitSwift() = runBlocking {
        val progress = DownloadProgress.init()
        val waiting = launch(Dispatchers.Default) { progress.waitUntilComplete() }
        progress.advance(1.0)
        withTimeout(5_000) { waiting.join() }
        assertEquals(0, progress.cancellations)
    }

    @Test
    fun cancellingTheCoroutineCancelsTheSwiftTask() = runBlocking {
        val progress = DownloadProgress.init()
        val waiting = launch(Dispatchers.Default) { progress.waitUntilComplete() }
        delay(100)
        waiting.cancelAndJoin()
        withTimeout(5_000) { while (progress.cancellations == 0L) delay(10) }
        assertEquals(1, progress.cancellations)
    }

    @Test
    fun asyncStreamAsAFlow() = runBlocking {
        val progress = DownloadProgress.init()
        val values = async(Dispatchers.Default) { progress.updates().toList() }
        delay(100)
        progress.advance(0.5)
        progress.advance(0.5)
        // The stream finishes when the download does, which completes the flow.
        assertEquals(1.0, withTimeout(5_000) { values.await() }.last())
    }

    @Test
    fun cancellingACollectionStopsTheStream() = runBlocking {
        val progress = DownloadProgress.init()
        // `first()` cancels the collection after one value; the stream doesn't finish by itself.
        assertEquals(0.0, withTimeout(5_000) { progress.updates().first() })
    }
}
