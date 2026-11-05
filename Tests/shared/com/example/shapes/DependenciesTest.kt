package com.example.shapes

import com.example.shapes.dependencies.AppState
import com.example.shapes.dependencies.Dependencies
import com.example.shapes.dependencies.Reader
import com.example.shapes.dependencies.System
import com.example.shapes.models.Book
import com.example.shapes.models.LibraryError
import com.example.shapes.models.Scheme
import java.util.concurrent.ExecutionException
import com.example.shapes.clients.CatalogClient
import com.example.shapes.clients.NotificationsClientMock
import com.example.shapes.clients.SearchClientMock
import com.example.shapes.dependencies.Clients
import com.example.shapes.dependencies.Loan
import com.example.shapes.models.Shelf
import com.example.shapes.models.ShelfID
import kotlin.test.assertNull
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertIs

class DependenciesTest {
    @Test
    fun clientsTypedAsAnotherModulesProtocols() {
        val clients = Dependencies.preview().clients
        assertEquals("search mock", clients.search.name)
        assertEquals(1, clients.search.search("cosmos").get().size)
        assertEquals(1, clients.catalog.all().size)
    }

    @Test
    fun autoclosureConfiguration() {
        var reads = 0
        val system = System.init({ reads++; Scheme.release() }, { "Library" })
        assertEquals(0, reads)   // evaluated only when read
        assertEquals("Library", system.appName.invoke())
        assertEquals(Scheme.release().toDebugString(), system.scheme.invoke().toDebugString())
        assertEquals(1, reads)
    }

    @Test
    fun asyncFunctionsTakingEntities() {
        val state = AppState.init()
        val book = Book.init("1", "Cosmos")
        val offline = assertFailsWith<ExecutionException> { state.borrow(book).get() }
        assertIs<LibraryError>(offline.cause)

        state.connect(Reader.init("Ada")).get()
        assertEquals("Ada", state.reader!!.name)
        assertEquals(14, state.borrow(book).get().days)
        state.connect(null).get()
    }

    @Test
    fun containersBuiltFromKotlin() {
        val clients = Clients.init(
            SearchClientMock.init("s", arrayOf()), NotificationsClientMock.init(), CatalogClient.init(arrayOf()),
        )
        assertEquals("s", clients.search.id)
        clients.notifications.notify_(com.example.shapes.models.Message.string("hi"))
        assertEquals(0, clients.catalog.ids().size)

        val state = AppState.init()
        val dependencies = Dependencies.init(clients, System.init({ Scheme.debug() }, { "App" }), state)
        assertEquals("App", dependencies.system.appName.invoke())
        assertEquals("s", dependencies.clients.search.id)
        assertNull(dependencies.state.reader)
    }

    @Test
    fun appStateLoadsACatalog() {
        val state = AppState.init()
        assertEquals(0, state.shelves.size)
        state.load(Dependencies.preview().clients.catalog)
        assertEquals(3, state.shelves[ShelfID.init("main")]!!.books.size)

        val loan = Loan.init(Book.init("1", "Cosmos"), 7)
        assertEquals("Cosmos", loan.book.title)
        assertEquals(7, loan.days)
    }

    @Test
    fun setsComeOnlyFromSwift() {
        // Gap: Kotlin can't create a `SwiftSet`, so a set parameter takes only a set Swift returned.
        val tags = Dependencies.preview().clients.catalog.all()[ShelfID.init("main")]!!.tags
        assertEquals(setOf("new"), tags.toJavaSet())
        val shelf = Shelf.init(ShelfID.init("copy"), arrayOf(), tags)
        assertEquals(setOf("new"), shelf.tags.toSet())
    }
}
