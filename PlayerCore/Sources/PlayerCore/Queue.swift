import Foundation

public enum RepeatMode: String, Codable, Sendable, Equatable, CaseIterable {
    case off
    case one
    case all

    public var next: RepeatMode {
        switch self {
        case .off: return .one
        case .one: return .all
        case .all: return .off
        }
    }
}

public struct QueueState: Codable, Equatable, Sendable {
    public var linearOrder: [String]
    public var order: [String]
    public var index: Int
    public var repeatMode: RepeatMode
    public var shuffle: Bool

    public init(
        linearOrder: [String],
        order: [String],
        index: Int,
        repeatMode: RepeatMode,
        shuffle: Bool
    ) {
        self.linearOrder = linearOrder
        self.order = order
        self.index = index
        self.repeatMode = repeatMode
        self.shuffle = shuffle
    }

    public var currentID: String? {
        guard order.indices.contains(index) else { return nil }
        return order[index]
    }

    public var upNextIDs: [String] {
        guard order.indices.contains(index) else { return order }
        let next = index + 1
        guard next < order.count else { return [] }
        return Array(order[next...])
    }
}

public enum PlaybackQueue {
    public static func create(_ ids: [String]) -> QueueState {
        QueueState(linearOrder: ids, order: ids, index: 0, repeatMode: .off, shuffle: false)
    }

    public static func cycleRepeat(_ mode: RepeatMode) -> RepeatMode {
        mode.next
    }

    /// Keeps the current track in place and shuffles everything after it.
    public static func toggleShuffle(_ state: QueueState, rng: () -> Double = { Double.random(in: 0..<1) }) -> QueueState {
        if state.order.isEmpty {
            return QueueState(
                linearOrder: state.linearOrder,
                order: state.order,
                index: state.index,
                repeatMode: state.repeatMode,
                shuffle: !state.shuffle
            )
        }
        let currentID = state.order.indices.contains(state.index) ? state.order[state.index] : nil
        if !state.shuffle {
            let rest = state.order.filter { $0 != currentID }
            let shuffled = shuffleIDs(rest, rng: rng)
            let order = currentID.map { [$0] + shuffled } ?? shuffled
            return QueueState(
                linearOrder: state.linearOrder,
                order: order,
                index: 0,
                repeatMode: state.repeatMode,
                shuffle: true
            )
        }
        let index: Int
        if let currentID, let found = state.linearOrder.firstIndex(of: currentID) {
            index = found
        } else {
            index = 0
        }
        return QueueState(
            linearOrder: state.linearOrder,
            order: state.linearOrder,
            index: index,
            repeatMode: state.repeatMode,
            shuffle: false
        )
    }

    public static func nextIndex(_ state: QueueState) -> Int? {
        guard !state.order.isEmpty else { return nil }
        if state.repeatMode == .one { return state.index }
        let upcoming = state.index + 1
        if upcoming < state.order.count { return upcoming }
        if state.repeatMode == .all { return 0 }
        return nil
    }

    public static func previousTarget(
        _ state: QueueState,
        currentTime seconds: Double,
        restartThreshold: Double = 3
    ) -> (index: Int, restart: Bool) {
        guard !state.order.isEmpty else { return (0, true) }
        if seconds > restartThreshold { return (state.index, true) }
        if state.repeatMode == .one { return (state.index, true) }
        if state.index > 0 { return (state.index - 1, false) }
        if state.repeatMode == .all { return (state.order.count - 1, false) }
        return (0, true)
    }

    public static func play(_ state: QueueState, id: String) -> QueueState {
        guard let index = state.order.firstIndex(of: id) else { return state }
        var copy = state
        copy.index = index
        return copy
    }

    public static func remove(_ state: QueueState, at index: Int) -> QueueState {
        guard state.order.indices.contains(index) else { return state }
        let removed = state.order[index]
        var order = state.order
        order.remove(at: index)
        let linear = state.linearOrder.filter { $0 != removed }
        var next = state.index
        if index < state.index { next -= 1 }
        if next >= order.count { next = max(0, order.count - 1) }
        if order.isEmpty { next = 0 }
        return QueueState(
            linearOrder: linear,
            order: order,
            index: next,
            repeatMode: state.repeatMode,
            shuffle: state.shuffle
        )
    }

    /// Reorders the play queue. The track that was current stays current.
    public static func move(_ state: QueueState, from: Int, to: Int) -> QueueState {
        guard state.order.indices.contains(from), state.order.indices.contains(to), from != to else { return state }
        let current = state.currentID
        var order = state.order
        let item = order.remove(at: from)
        order.insert(item, at: to)
        let index = current.flatMap { order.firstIndex(of: $0) } ?? min(state.index, max(0, order.count - 1))
        return QueueState(
            linearOrder: state.linearOrder,
            order: order,
            index: index,
            repeatMode: state.repeatMode,
            shuffle: state.shuffle
        )
    }

    public static func replaceOrder(_ state: QueueState, ids: [String], keepID: String? = nil) -> QueueState {
        let linearOrder = ids
        var order = state.shuffle ? state.order.filter { ids.contains($0) } : ids
        for id in ids where !order.contains(id) {
            order.append(id)
        }
        let pruned = order.filter { ids.contains($0) }
        let focus: String?
        if let keepID, pruned.contains(keepID) {
            focus = keepID
        } else if pruned.indices.contains(state.index) {
            focus = pruned[state.index]
        } else {
            focus = pruned.first
        }
        let index = focus.flatMap { pruned.firstIndex(of: $0) } ?? 0
        return QueueState(
            linearOrder: linearOrder,
            order: pruned,
            index: index,
            repeatMode: state.repeatMode,
            shuffle: state.shuffle
        )
    }

    static func shuffleIDs(_ ids: [String], rng: () -> Double) -> [String] {
        var next = ids
        if next.count < 2 { return next }
        for index in stride(from: next.count - 1, through: 1, by: -1) {
            let roll = rng()
            let swap = min(index, max(0, Int(roll * Double(index + 1))))
            next.swapAt(index, swap)
        }
        return next
    }
}
