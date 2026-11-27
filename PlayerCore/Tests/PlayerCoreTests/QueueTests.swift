import XCTest
@testable import PlayerCore

final class QueueTests: XCTestCase {
    func testRepeatCyclesOffOneAll() {
        XCTAssertEqual(PlaybackQueue.cycleRepeat(.off), .one)
        XCTAssertEqual(PlaybackQueue.cycleRepeat(.one), .all)
        XCTAssertEqual(PlaybackQueue.cycleRepeat(.all), .off)
    }

    func testNextStopsAtTheEndWhenRepeatIsOff() {
        let queue = PlaybackQueue.create(["a", "b"])
        XCTAssertEqual(PlaybackQueue.nextIndex(queue), 1)
        var end = queue
        end.index = 1
        XCTAssertNil(PlaybackQueue.nextIndex(end))
    }

    func testRepeatOneStaysOnTheCurrentTrack() {
        var queue = PlaybackQueue.create(["a", "b"])
        queue.repeatMode = .one
        XCTAssertEqual(PlaybackQueue.nextIndex(queue), 0)
    }

    func testRepeatAllWrapsToTheStart() {
        var queue = PlaybackQueue.create(["a", "b"])
        queue.repeatMode = .all
        queue.index = 1
        XCTAssertEqual(PlaybackQueue.nextIndex(queue), 0)
    }

    func testPreviousRestartsTheCurrentTrackAfterThreeSeconds() {
        var queue = PlaybackQueue.create(["a", "b"])
        queue.index = 1
        let restart = PlaybackQueue.previousTarget(queue, currentTime: 4)
        XCTAssertEqual(restart.index, 1)
        XCTAssertTrue(restart.restart)
        let back = PlaybackQueue.previousTarget(queue, currentTime: 1)
        XCTAssertEqual(back.index, 0)
        XCTAssertFalse(back.restart)
    }

    func testPreviousWrapsWhenRepeatIsAll() {
        var queue = PlaybackQueue.create(["a", "b"])
        queue.repeatMode = .all
        let wrapped = PlaybackQueue.previousTarget(queue, currentTime: 0)
        XCTAssertEqual(wrapped.index, 1)
        XCTAssertFalse(wrapped.restart)
    }

    func testShuffleKeepsTheCurrentTrackFirstAndCanBeUndone() {
        var queue = PlaybackQueue.create(["a", "b", "c"])
        queue.index = 1
        let shuffled = PlaybackQueue.toggleShuffle(queue) { 0 }
        XCTAssertTrue(shuffled.shuffle)
        XCTAssertEqual(shuffled.order[0], "b")
        XCTAssertEqual(shuffled.index, 0)
        XCTAssertEqual(shuffled.order.sorted(), ["a", "b", "c"])
        let restored = PlaybackQueue.toggleShuffle(shuffled) { 0 }
        XCTAssertFalse(restored.shuffle)
        XCTAssertEqual(restored.order, ["a", "b", "c"])
        XCTAssertEqual(restored.index, 1)
    }

    func testReplaceOrderKeepsAShuffledQueueAndAppendsNewTracks() {
        var state = PlaybackQueue.create(["a", "b", "c"])
        state.shuffle = true
        state.order = ["b", "c", "a"]
        state.index = 1
        let next = PlaybackQueue.replaceOrder(state, ids: ["a", "c", "d", "b"], keepID: "c")
        XCTAssertEqual(next.linearOrder, ["a", "c", "d", "b"])
        XCTAssertEqual(next.order, ["b", "c", "a", "d"])
        XCTAssertEqual(next.index, 1)
        XCTAssertTrue(next.shuffle)
    }

    func testPlayAndRemove() {
        let queued = PlaybackQueue.play(PlaybackQueue.create(["a", "b", "c"]), id: "c")
        XCTAssertEqual(queued.index, 2)
        let removed = PlaybackQueue.remove(queued, at: 0)
        XCTAssertEqual(removed.order, ["b", "c"])
        XCTAssertEqual(removed.order[removed.index], "c")
    }

    func testMoveKeepsTheCurrentTrack() {
        var queue = PlaybackQueue.create(["a", "b", "c"])
        queue.index = 1
        let moved = PlaybackQueue.move(queue, from: 2, to: 0)
        XCTAssertEqual(moved.order, ["c", "a", "b"])
        XCTAssertEqual(moved.currentID, "b")
        let removed = PlaybackQueue.remove(moved, at: 0)
        XCTAssertEqual(removed.order, ["a", "b"])
        XCTAssertEqual(removed.currentID, "b")
    }

    func testUpNextDropsTheCurrentTrack() {
        var queue = PlaybackQueue.create(["a", "b", "c"])
        queue.index = 0
        XCTAssertEqual(queue.upNextIDs, ["b", "c"])
    }
}
