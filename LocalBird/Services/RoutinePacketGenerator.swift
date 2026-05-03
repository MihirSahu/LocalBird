import Foundation

struct RoutinePacketGenerator {
    let paths: LocalBirdPaths
    let fileManager: FileManager

    init(paths: LocalBirdPaths, fileManager: FileManager = .default) {
        self.paths = paths
        self.fileManager = fileManager
    }

    func generateDailyPacket(
        for day: Date,
        captures: [CaptureRecord],
        blocks: [ActivityBlock],
        representativeIDs: [String]
    ) throws -> RoutinePacket {
        guard !captures.isEmpty else {
            throw LocalBirdError.noCapturesForRoutine
        }

        let dayString = DateFormatter.localBirdDay.string(from: day)
        let folder = paths.routineRuns.appendingPathComponent("\(dayString)-daily", isDirectory: true)
        let screenshotFolder = folder.appendingPathComponent("screenshots", isDirectory: true)
        try? fileManager.removeItem(at: folder)
        try fileManager.createDirectory(at: screenshotFolder, withIntermediateDirectories: true)

        try agentsMarkdown().write(to: folder.appendingPathComponent("AGENTS.md"), atomically: true, encoding: .utf8)
        try promptMarkdown(dayString: dayString).write(to: folder.appendingPathComponent("prompt.md"), atomically: true, encoding: .utf8)
        try timelineMarkdown(dayString: dayString, blocks: blocks, captures: captures)
            .write(to: folder.appendingPathComponent("timeline.md"), atomically: true, encoding: .utf8)
        try timelineJSON(dayString: dayString, blocks: blocks, captures: captures)
            .write(to: folder.appendingPathComponent("timeline.json"), atomically: true, encoding: .utf8)

        let capturesByID = Dictionary(uniqueKeysWithValues: captures.map { ($0.id, $0) })
        for id in representativeIDs {
            guard let capture = capturesByID[id] else { continue }
            let source = URL(fileURLWithPath: capture.screenshotPath)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            let name = "\(DateFormatter.localBirdFilenameTime.string(from: capture.capturedAt))-\((capture.activeAppName ?? "unknown").slugForFilename())-\(id.prefix(8)).png"
            let destination = screenshotFolder.appendingPathComponent(name)
            try? fileManager.copyItem(at: source, to: destination)
        }

        let output = folder.appendingPathComponent("output.md")
        try "".write(to: output, atomically: true, encoding: .utf8)
        return RoutinePacket(folderURL: folder, outputURL: output)
    }

    private func agentsMarkdown() -> String {
        """
        You are generating personal daily routine summaries.

        Rules:
        - Read only files in this routine folder.
        - Do not modify screenshots, timeline files, or database exports.
        - Write the final answer only to output.md.
        - Do not access parent directories.
        - Do not run shell commands unless absolutely necessary.
        - Prefer accuracy over speculation.
        - If uncertain, say so briefly.
        """
    }

    private func promptMarkdown(dayString: String) -> String {
        """
        Generate a daily overview for \(dayString) from the provided timeline and representative screenshots.

        Focus on:
        - what the user worked on,
        - major activity blocks,
        - recurring themes,
        - notable context switches,
        - things worth remembering,
        - possible follow-ups.

        Write the final Markdown output to output.md using this structure:

        # Daily Overview - \(dayString)
        ## Summary
        ## Main Activity Blocks
        ## Key Workstreams
        ## Notable Context Switches
        ## Things Worth Remembering
        ## Possible Follow-ups
        """
    }

    private func timelineMarkdown(dayString: String, blocks: [ActivityBlock], captures: [CaptureRecord]) -> String {
        var lines = ["# Timeline - \(dayString)", ""]
        if blocks.isEmpty {
            lines.append("No activity blocks were generated.")
        }
        for block in blocks {
            lines.append("## \(DateFormatter.localBirdTimestamp.string(from: block.startTime)) - \(DateFormatter.localBirdTimestamp.string(from: block.endTime))")
            if !block.dominantApps.isEmpty {
                lines.append("- Apps: \(block.dominantApps.joined(separator: ", "))")
            }
            if !block.dominantWindowTitles.isEmpty {
                lines.append("- Windows: \(block.dominantWindowTitles.joined(separator: " | "))")
            }
            if !block.summaryHint.isEmpty {
                lines.append("- Evidence: \(block.summaryHint)")
            }
            lines.append("- Representative captures: \(block.representativeCaptureIDs.joined(separator: ", "))")
            lines.append("")
        }
        lines.append("## Raw Captures")
        for capture in captures {
            lines.append("- \(DateFormatter.localBirdTimestamp.string(from: capture.capturedAt)) | \(capture.activeAppName ?? "Unknown") | \(capture.windowTitle ?? "Untitled") | duplicate=\(capture.isDuplicate)")
            if let ocr = capture.ocrText, !ocr.isEmpty {
                lines.append("  OCR: \(ocr.replacingOccurrences(of: "\n", with: " ").prefix(500))")
            }
        }
        return lines.joined(separator: "\n")
    }

    private func timelineJSON(dayString: String, blocks: [ActivityBlock], captures: [CaptureRecord]) throws -> String {
        let payload = TimelinePayload(day: dayString, blocks: blocks, captures: captures)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        return String(decoding: data, as: UTF8.self)
    }
}

private struct TimelinePayload: Encodable {
    let day: String
    let blocks: [ActivityBlock]
    let captures: [CaptureRecord]
}
