import Foundation
import XCTest

final class OpencodeRoutineSummarizerTests: XCTestCase {
    func testUsesRunnerAndReadsOutput() async throws {
        let root = temporaryDirectory()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let runner = FakeProcessRunner(markdown: "# Daily Overview\n\nDone")
        let summarizer = OpencodeRoutineSummarizer(
            executableURL: URL(fileURLWithPath: "/usr/bin/true"),
            processRunner: runner
        )

        let result = try await summarizer.generateRoutine(packetPath: root, routineType: .daily)

        XCTAssertEqual(result.markdown, "# Daily Overview\n\nDone")
    }
}

private struct FakeProcessRunner: ProcessRunning {
    let markdown: String

    func run(executableURL: URL, arguments: [String], workingDirectory: URL) async throws -> ProcessResult {
        try markdown.write(to: workingDirectory.appendingPathComponent("output.md"), atomically: true, encoding: .utf8)
        return ProcessResult(exitCode: 0, stdout: "", stderr: "")
    }
}
