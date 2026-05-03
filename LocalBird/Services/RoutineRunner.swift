import Foundation

@MainActor
final class RoutineRunner: ObservableObject {
    @Published private(set) var latestRun: RoutineRun?
    @Published private(set) var latestMarkdown: String = ""
    @Published private(set) var latestPacketURL: URL?
    @Published private(set) var isRunning = false
    @Published private(set) var lastError: String?

    private let paths: LocalBirdPaths
    private let store: SQLiteStore
    private let blockBuilder: ActivityBlockBuilder
    private let packetGenerator: RoutinePacketGenerator
    private let summarizer: RoutineSummarizer
    private let fileManager: FileManager

    init(
        paths: LocalBirdPaths,
        store: SQLiteStore,
        blockBuilder: ActivityBlockBuilder,
        packetGenerator: RoutinePacketGenerator,
        summarizer: RoutineSummarizer,
        fileManager: FileManager = .default
    ) {
        self.paths = paths
        self.store = store
        self.blockBuilder = blockBuilder
        self.packetGenerator = packetGenerator
        self.summarizer = summarizer
        self.fileManager = fileManager
        loadLatestSummary()
    }

    func runDailyNow(day: Date = Date()) async {
        guard !isRunning else { return }
        isRunning = true
        lastError = nil
        let now = Date()
        var run = RoutineRun(
            id: UUID().uuidString,
            routineType: .daily,
            startedAt: now,
            completedAt: nil,
            inputPacketPath: "",
            outputMarkdownPath: nil,
            backend: "opencode",
            status: .running,
            errorMessage: nil,
            createdAt: now
        )

        do {
            let captures = try store.captures(on: day)
            let blocks = blockBuilder.buildBlocks(from: captures)
            try store.insertActivityBlocks(blocks)
            let representativeIDs = blockBuilder.representativeCaptureIDs(from: blocks)
            let packet = try packetGenerator.generateDailyPacket(
                for: day,
                captures: captures,
                blocks: blocks,
                representativeIDs: representativeIDs
            )
            latestPacketURL = packet.folderURL
            run.inputPacketPath = packet.folderURL.path
            try store.insertRoutineRun(run)

            let result = try await summarizer.generateRoutine(packetPath: packet.folderURL, routineType: .daily)
            let summaryURL = paths.summaries.appendingPathComponent("\(DateFormatter.localBirdDay.string(from: day))-daily.md")
            try result.markdown.write(to: summaryURL, atomically: true, encoding: .utf8)
            run.completedAt = Date()
            run.outputMarkdownPath = summaryURL.path
            run.status = .completed
            try store.insertRoutineRun(run)
            latestRun = run
            latestMarkdown = result.markdown
        } catch {
            run.completedAt = Date()
            run.status = .failed
            run.errorMessage = error.localizedDescription
            try? store.insertRoutineRun(run)
            latestRun = run
            lastError = error.localizedDescription
        }
        isRunning = false
    }

    func loadLatestSummary() {
        do {
            latestRun = try store.latestRoutineRun(type: .daily)
            if let path = latestRun?.outputMarkdownPath {
                latestMarkdown = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
            }
            if let packetPath = latestRun?.inputPacketPath, !packetPath.isEmpty {
                latestPacketURL = URL(fileURLWithPath: packetPath)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }
}
