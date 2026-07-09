import XCTest
@testable import Matchflick

final class MatchflickTests: XCTestCase {

    func testDeckRoster() {
        XCTAssertEqual(MovieDeck.all.count, 9)
        XCTAssertEqual(MovieDeck.all.filter(\.isFree).count, 3)
        for d in MovieDeck.all {
            XCTAssertGreaterThanOrEqual(d.movies.count, 15, d.name)
            XCTAssertFalse(d.symbol.isEmpty)
            XCTAssertEqual(Set(d.movies.map(\.id)).count, d.movies.count, d.name)
        }
        XCTAssertNotNil(MovieDeck.deck(id: "cozy"))
        XCTAssertNil(MovieDeck.deck(id: "nope"))
    }

    func testNoEmojiInMovieData() {
        for d in MovieDeck.all {
            for m in d.movies {
                XCTAssertTrue(m.title.unicodeScalars.allSatisfy { $0.value < 0x1F000 }, m.title)
                XCTAssertTrue(m.premise.unicodeScalars.allSatisfy { $0.value < 0x1F000 }, m.premise)
            }
        }
    }

    @MainActor
    func testMatchHistoryRecording() {
        let model = AppModel(container: AppModel.makeContainer())
        model.deleteAllData()
        XCTAssertTrue(model.history.isEmpty)
        model.recordMatch(title: "Test Movie", year: 2020, chemistry: 100, playerCount: 3)
        XCTAssertEqual(model.history.count, 1)
        XCTAssertEqual(model.history.first?.movieTitle, "Test Movie")
        model.delete(model.history[0])
        XCTAssertTrue(model.history.isEmpty)
    }

    @MainActor
    func testGameEngineTerminatesWithAMatch() {
        let engine = GameEngine()
        let movies = [
            Movie(id: "a", title: "A", year: 2020, genres: [], premise: "p", moodTags: ["cozy"], runtimeMins: 90),
            Movie(id: "b", title: "B", year: 2020, genres: [], premise: "p", moodTags: ["cozy"], runtimeMins: 90)
        ]
        engine.start(players: ["P1", "P2"], deck: movies)
        engine.beginSwiping()
        engine.swipe(liked: true)
        engine.swipe(liked: true)
        engine.beginSwiping()
        engine.swipe(liked: true)
        engine.swipe(liked: false)
        var iterations = 0
        while true {
            switch engine.phase {
            case .matched:
                return
            case .handoff:
                engine.beginSwiping()
            case .swiping:
                engine.swipe(liked: true)
            default:
                break
            }
            iterations += 1
            if iterations > 20 { XCTFail("Game engine failed to terminate"); return }
        }
    }
}
