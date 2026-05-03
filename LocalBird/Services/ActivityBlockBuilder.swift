import Foundation

struct ActivityBlockBuilder: Sendable {
    var gapThreshold: TimeInterval = 15 * 60
    var maxRepresentatives: Int = 30

    func buildBlocks(from captures: [CaptureRecord]) -> [ActivityBlock] {
        let ordered = captures.sorted { $0.capturedAt < $1.capturedAt }.filter { !$0.isDuplicate }
        guard let first = ordered.first else { return [] }

        var groups: [[CaptureRecord]] = [[first]]
        for capture in ordered.dropFirst() {
            guard var current = groups.popLast(), let previous = current.last else {
                groups.append([capture])
                continue
            }
            if shouldStartNewBlock(previous: previous, current: capture) {
                groups.append(current)
                groups.append([capture])
            } else {
                current.append(capture)
                groups.append(current)
            }
        }

        return groups.map(makeBlock)
    }

    func representativeCaptureIDs(from blocks: [ActivityBlock]) -> [String] {
        var ids: [String] = []
        for block in blocks {
            for id in block.representativeCaptureIDs where !ids.contains(id) {
                ids.append(id)
            }
        }
        if ids.count > maxRepresentatives {
            return Array(ids.prefix(maxRepresentatives))
        }
        return ids
    }

    private func shouldStartNewBlock(previous: CaptureRecord, current: CaptureRecord) -> Bool {
        if current.capturedAt.timeIntervalSince(previous.capturedAt) > gapThreshold {
            return true
        }
        if previous.activeAppBundleID != current.activeAppBundleID {
            return true
        }
        let previousTitle = previous.windowTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentTitle = current.windowTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        if previousTitle != currentTitle, current.capturedAt.timeIntervalSince(previous.capturedAt) > 120 {
            return true
        }
        return false
    }

    private func makeBlock(_ captures: [CaptureRecord]) -> ActivityBlock {
        let apps = orderedTopValues(captures.compactMap(\.activeAppName))
        let titles = orderedTopValues(captures.compactMap(\.windowTitle))
        let representatives = representativeIDs(for: captures)
        let hintParts = [
            apps.first.map { "Primary app: \($0)" },
            titles.first.map { "Window: \($0)" },
            mostUsefulOCRLine(in: captures).map { "Visible text: \($0)" }
        ].compactMap { $0 }

        return ActivityBlock(
            id: UUID().uuidString,
            startTime: captures.first?.capturedAt ?? Date(),
            endTime: captures.last?.capturedAt ?? Date(),
            dominantApps: apps,
            dominantWindowTitles: titles,
            summaryHint: hintParts.joined(separator: ". "),
            representativeCaptureIDs: representatives,
            createdAt: Date()
        )
    }

    private func representativeIDs(for captures: [CaptureRecord]) -> [String] {
        guard !captures.isEmpty else { return [] }
        var records = [captures[0]]
        if captures.count > 2 {
            records.append(captures[captures.count / 2])
        }
        if captures.count > 1 {
            records.append(captures[captures.count - 1])
        }
        var seen = Set<String>()
        return records.compactMap { record in
            guard seen.insert(record.id).inserted else { return nil }
            return record.id
        }
    }

    private func orderedTopValues(_ values: [String]) -> [String] {
        let counts = Dictionary(grouping: values.filter { !$0.isEmpty }, by: { $0 })
            .mapValues(\.count)
        return counts.sorted { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key < rhs.key
            }
            return lhs.value > rhs.value
        }
        .prefix(5)
        .map(\.key)
    }

    private func mostUsefulOCRLine(in captures: [CaptureRecord]) -> String? {
        captures
            .compactMap(\.ocrText)
            .flatMap { $0.split(separator: "\n").map(String.init) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 12 }
            .max { $0.count < $1.count }
    }
}
