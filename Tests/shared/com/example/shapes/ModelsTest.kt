package com.example.shapes

import com.example.shapes.models.Availability
import com.example.shapes.models.Book
import com.example.shapes.models.Cover
import com.example.shapes.models.ImageCover
import com.example.shapes.models.LibraryError
import com.example.shapes.models.Message
import com.example.shapes.models.Quantity
import com.example.shapes.models.Rating
import com.example.shapes.models.Review
import com.example.shapes.models.Shelf
import com.example.shapes.models.SortPolicy
import com.example.shapes.models.ShelfID
import com.example.shapes.models.TextCover
import com.example.shapes.util.Formatting
import com.example.shapes.util.Range64
import java.net.URI
import com.example.shapes.models.Genre
import com.example.shapes.models.Scheme
import com.example.shapes.util.Platform
import kotlin.test.assertTrue
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertNull

class ModelsTest {
    @Test
    fun entitiesAndFoundationValues() {
        val book = Book.init("1", "Cosmos", 300)
        assertEquals("Cosmos", book.title)
        assertNull(book.coverURL)
        assertEquals("Untitled", Book.getDefault().title)
        val range = book.pageRange!!
        assertEquals(1L, range.first().asLong)
        assertEquals(300L, range.last().asLong)
    }

    @Test
    fun nestedArrays() {
        val books = (1..5).map { Book.init("$it", "Book $it") }.toTypedArray()
        val shelf = Shelf.init(ShelfID.init("s"), books)
        val sections = shelf.sections(2)
        assertEquals(listOf(2, 2, 1), sections.map { it.size })
        assertEquals("Book 5", sections[2][0].title)
        assertEquals(5, Shelf.merge(sections, ShelfID.init("t")).books.size)
    }

    @Test
    fun overloadsAndClashingNames() {
        assertEquals("image https://example.com/c.png", Cover.init(ImageCover.init(URI("https://example.com/c.png"))).summary)
        assertEquals("text Title", Cover.init(TextCover.init("Title")).summary)

        val availability = Availability.init(true, "Now")
        assertEquals(true, availability.getLive())
        assertEquals(true, availability.isLive)
        assertEquals("Now", availability.title)
        assertEquals("Availability", Availability.getTitle_())

        assertEquals(2.5, Quantity.init(2.5).value)
        assertEquals("4: good", Review.init(Rating.init(4), "good").summary)
    }

    @Test
    fun javaKeywordsAndObjectMethods() {
        val range = Range64.init(10, 3)
        assertEquals(10, range.long)
        assertEquals(7, range.wait_())
        assertEquals(2, Formatting.getDefaultPrecision())
        assertEquals("50%", Formatting.percent(0.5))
        assertEquals("shown", Formatting.describe({ "shown" }, true))
    }

    @Test
    fun enumPayloads() {
        // Exhaustive: the Java `Case` is a sealed interface, so a missing case doesn't compile.
        fun describe(error: LibraryError): String = when (val case = error.case) {
            is LibraryError.Case.NotFound -> "not found ${case.id}"
            is LibraryError.Case.Failed -> "failed ${case.underlying.message}"
            is LibraryError.Case.Offline -> "offline"
        }
        assertEquals("failed disk", describe(LibraryError.failed(IllegalStateException("disk"))))
        assertEquals("not found id", describe(LibraryError.notFound("id")))
        assertEquals("offline", describe(LibraryError.offline()))

        fun describe(message: Message): String = when (val case = message.case) {
            is Message.Case.String -> case.arg0
            is Message.Case.Closed -> "closed ${case.code} ${case.reason ?: "-"}"
        }
        assertEquals("hello", describe(Message.string("hello")))
        assertEquals("closed 1000 bye", describe(Message.closed(1000, "bye")))
        assertEquals("closed 1001 -", describe(Message.closed(1001, null)))
    }

    @Test
    fun everyEntityField() {
        val url = URI("https://example.com/c.png")
        val book = Book.init("1", "Cosmos", 300, Genre.science, url)
        assertEquals("1", book.id)
        assertEquals(300, book.pages)
        assertEquals(Genre.science, book.genre)
        assertEquals(url, book.coverURL)
        assertEquals(0, book.published.time)
        assertEquals(Genre.history, Book.init("2", "History", 120, Genre.history).genre)
        val defaults = Book.init("3", "Defaults")
        assertEquals(100, defaults.pages)
        assertEquals(Genre.fiction, defaults.genre)
        assertEquals("0", Book.getDefault().id)
        assertNull(Book.init("4", "Empty", 0).pageRange)
    }

    @Test
    fun payloadlessEnumsAreJavaEnums() {
        assertEquals(listOf("fiction", "history", "science"), Genre.entries.map { it.name })
        assertEquals(Genre.Discriminator.SCIENCE, Genre.science().discriminator)
        assertTrue(Genre.fiction.getAsFiction().isPresent)
        assertTrue(Genre.history.getAsHistory().isPresent)
        assertTrue(Genre.science.getAsScience().isPresent)
        assertIs<Genre.Case.Fiction>(Genre.fiction.case)
        assertEquals(listOf("debug", "release"), Scheme.entries.map { it.name })
        assertTrue(Scheme.debug().getAsDebug().isPresent)
        assertTrue(Scheme.release.getAsRelease().isPresent)
        assertIs<Scheme.Case.Release>(Scheme.release.case)
    }

    @Test
    fun collectionsOfEntities() {
        val shelf = Shelf.init(ShelfID.init("s"), arrayOf(Book.init("1", "One")))
        assertEquals("s", shelf.id.rawValue)
        assertEquals(0, shelf.tags.size)
        assertNull(shelf.pageCounts)
        assertNull(shelf.featured)
    }

    @Test
    fun optionalArraysAsParameters() {
        val shelf = Shelf.init(ShelfID.init("s"), arrayOf(Book.init("1", "One")))
        assertEquals(listOf(10L, 20L), shelf.withPageCounts(longArrayOf(10, 20)).pageCounts!!.toList())
        assertNull(shelf.withPageCounts(null).pageCounts)

        shelf.featured = arrayOf(Book.init("2", "Two"))
        assertEquals(listOf("Two"), shelf.featured!!.map { it.title })
        shelf.featured = null
        assertNull(shelf.featured)
    }

    @Test
    fun valueAccessorsAndSetters() {
        val url = URI("https://example.com/c.png")
        assertEquals(url, ImageCover.init(url).url)
        assertEquals("Title", TextCover.init("Title").title)
        val availability = Availability.init(false, "Now")
        assertEquals(false, availability.isLive)
        availability.title = "Later"
        assertEquals("Later", availability.title)
        assertEquals(5, Rating.init(5).stars)
        assertEquals(0.0, Quantity.init(0.0).value)
        assertEquals("0: none", Review.init(null, "none").summary)
    }

    @Test
    fun everyEnumCase() {
        val offline = LibraryError.offline()
        assertEquals(LibraryError.Discriminator.OFFLINE, offline.discriminator)
        assertTrue(offline.getAsOffline().isPresent)
        assertIs<LibraryError.Case.NotFound>(LibraryError.notFound("x").case)

        val closed = Message.closed(1001, null).case as Message.Case.Closed
        assertEquals(1001, closed.code)
        assertNull(closed.reason)
        assertIs<Message.Case.String>(Message.string("hi").case)
    }

    @Test
    fun staticHelpers() {
        assertEquals("12.3%", Formatting.percent(0.1234, 1))
        assertEquals("", Formatting.describe({ error("not evaluated") }, false))
        assertEquals(3, Range64.init(10, 3).short)
        // ART reports itself as Dalvik.
        assertEquals(if (System.getProperty("java.vm.name") == "Dalvik") "android" else "apple", Platform.name())
    }

    @Test
    fun enumCaseWithAClosurePayload() {
        val byId = SortPolicy.custom { lhs: Book, rhs: Book -> lhs.id > rhs.id }
        val a = Book.init("1", "B")
        val b = Book.init("2", "A")
        assertTrue(byId.areInIncreasingOrder(b, a))
        assertIs<SortPolicy.Case.Custom>(byId.case)
        assertTrue(byId.getAsCustom().isPresent)
        assertEquals(SortPolicy.Discriminator.CUSTOM, byId.discriminator)

        val byTitle = SortPolicy.byTitle()
        assertTrue(byTitle.areInIncreasingOrder(b, a))
        assertIs<SortPolicy.Case.ByTitle>(byTitle.case)
    }
}
