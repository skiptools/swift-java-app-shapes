import Foundation
import Testing

@testable import ShapesModels

struct ModelsTests {
  @Test func book() throws {
    let url = try #require(URL(string: "https://example.com/c.png"))
    let book = Book(id: "1", title: "Cosmos", pages: 300, genre: .science, coverURL: url)
    #expect(book.id == "1")
    #expect(book.title == "Cosmos")
    #expect(book.pages == 300)
    #expect(book.genre == .science)
    #expect(book.coverURL == url)
    #expect(book.published == Date(timeIntervalSince1970: 0))
    #expect(book.rawPayload == nil)

    let defaults = Book(id: "2", title: "Defaults")
    #expect(defaults.pages == 100)
    #expect(defaults.genre == .fiction)
    #expect(defaults.coverURL == nil)
    #expect(Book.default.id == "0")
    #expect(Book.default.title == "Untitled")

    let range = try #require(book.pageRange)
    #expect(range.first == 1)
    #expect(range.last == 300)
    #expect(Book(id: "3", title: "Empty", pages: 0).pageRange == nil)

    #expect(try Book.decode(JSONEncoder().encode(book)) == book)
    #expect(Set([book, book, defaults]).count == 2)
  }

  @Test func enums() throws {
    #expect(Genre.allCases == [.fiction, .history, .science])
    #expect(Genre(rawValue: "history") == .history)
    #expect(try JSONDecoder().decode(Genre.self, from: Data("\"science\"".utf8)) == .science)
    #expect(Scheme.debug.rawValue == "debug")
    #expect(Scheme(rawValue: "release") == .release)
  }

  @Test func shelf() {
    let books = (1...5).map { Book(id: "\($0)", title: "Book \($0)") }
    let shelf = Shelf(id: ShelfID("s"), books: books, tags: ["new"])
    #expect(shelf.id == ShelfID("s"))
    #expect(shelf.id.rawValue == "s")
    #expect(shelf.books == books)
    #expect(shelf.tags == ["new"])
    #expect(shelf.pageCounts == nil)
    #expect(Shelf(id: ShelfID("t"), books: []).tags.isEmpty)

    let sections = shelf.sections(size: 2)
    #expect(sections.map(\.count) == [2, 2, 1])
    #expect(sections[2][0].title == "Book 5")

    let merged = Shelf.merge(sections, id: ShelfID("m"))
    #expect(merged.id.rawValue == "m")
    #expect(merged.books == books)

    let counted = shelf.withPageCounts([10, 20])
    #expect(counted.pageCounts == [10, 20])
    #expect(counted.books == books)
    #expect(counted.tags == ["new"])
    #expect(counted.withPageCounts(nil).pageCounts == nil)
  }

  @Test func libraryError() {
    struct DiskFull: Error {}
    guard case .failed(let underlying) = LibraryError.failed(underlying: DiskFull()) else {
      Issue.record("expected .failed")
      return
    }
    #expect(underlying is DiskFull)
    guard case .notFound(let id) = LibraryError.notFound(id: "x") else {
      Issue.record("expected .notFound")
      return
    }
    #expect(id == "x")
    #expect(throws: LibraryError.self) { throw LibraryError.offline }
  }

  @Test func message() {
    guard case .string(let text) = Message.string("hi") else {
      Issue.record("expected .string")
      return
    }
    #expect(text == "hi")
    guard case .closed(let code, let reason) = Message.closed(code: 1000, reason: nil) else {
      Issue.record("expected .closed")
      return
    }
    #expect(code == 1000)
    #expect(reason == nil)
  }

  @Test func sortPolicy() {
    let books = [Book(id: "1", title: "B"), Book(id: "2", title: "A")]
    guard case .custom(let areInIncreasingOrder) = SortPolicy.custom({ $0.id > $1.id }) else {
      Issue.record("expected .custom")
      return
    }
    #expect(books.sorted(by: areInIncreasingOrder).map(\.id) == ["2", "1"])
    guard case .byTitle = SortPolicy.byTitle else {
      Issue.record("expected .byTitle")
      return
    }
  }

  @Test func covers() throws {
    let url = try #require(URL(string: "https://example.com/c.png"))
    #expect(ImageCover(url: url).url == url)
    #expect(TextCover(title: "T").title == "T")
    #expect(Cover(image: ImageCover(url: url)).summary == "image https://example.com/c.png")
    #expect(Cover(text: TextCover(title: "T")).summary == "text T")
  }

  @Test func naming() {
    var availability = Availability(live: true, title: "Now")
    #expect(availability.live)
    #expect(availability.isLive)
    #expect(availability.title == "Now")
    availability.title = "Later"
    #expect(availability.title == "Later")
    #expect(Availability.title == "Availability")

    #expect(Quantity(amount: 2.5).value == 2.5)
    #expect(Quantity(units: 3).value == 3)

    #expect(Rating(stars: 5).stars == 5)
    #expect(Review(result: Rating(stars: 4), comment: "good").summary == "4: good")
    #expect(Review(result: nil, comment: "none").summary == "0: none")
  }

  @MainActor @Test func types() {
    var calls = 0
    let callback: VoidCallback = { calls += 1 }
    callback()
    #expect(calls == 1)
    #expect(CacheEntry(key: "k").key == "k")
  }
}
