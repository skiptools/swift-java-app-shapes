package com.example.shapes

import com.example.shapes.clients.CatalogClient
import com.example.shapes.clients.DownloadProgress
import com.example.shapes.clients.LifecycleObserver
import com.example.shapes.clients.LifecycleObserverFactory
import com.example.shapes.clients.NotificationsClient
import com.example.shapes.clients.NotificationsClientMock
import com.example.shapes.clients.SearchClient
import com.example.shapes.clients.SearchClientMock
import com.example.shapes.models.Book
import com.example.shapes.models.LibraryError
import com.example.shapes.models.Message
import com.example.shapes.models.Shelf
import com.example.shapes.models.ShelfID
import java.util.concurrent.ExecutionException
import org.swift.swiftkit.core.SwiftArena
import kotlin.test.assertNull
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertIs

class ClientsTest {
    private val books = arrayOf(Book.init("1", "Cosmos"), Book.init("2", "Cosmic Dust"), Book.init("3", "History"))

    @Test
    fun protocolExtensionMembersAndAsyncRequirements() {
        val search: SearchClient = SearchClientMock.init("mock", books)
        assertEquals("search mock", search.name)   // implemented by the protocol extension
        assertEquals(2, search.search("cosm").get().size)
        val failure = assertFailsWith<ExecutionException> { search.search("").get() }
        assertIs<LibraryError>(failure.cause)
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
        assertEquals(listOf("hi", "closed 1000 bye", "closed 1001 "), mock.delivered.toList())
        assertEquals(3, mock.deliveredCount)
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
        // Gap: the extension is a separate class, reached only by wrapping the entity's address, which neither
        // copies nor retains it. The arena is never closed, so only `book` destroys the value.
        val book = Book.init("1", "Cosmos", 300)
        val sharing = com.example.shapes.clients.Book.wrapMemoryAddressUnsafe(book.`$memoryAddress`(), SwiftArena.ofConfined())
        assertEquals("Cosmos (300 pages)", sharing.shareText())
        assertEquals("Cosmos", book.title)
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
}
