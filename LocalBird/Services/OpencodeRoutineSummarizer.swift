import Foundation

protocol RoutineSummarizer: Sendable {
    func generateRoutine(packetPath: URL, routineType: RoutineType) async throws -> RoutineResult
}

protocol ProcessRunning: Sendable {
    func run(executableURL: URL, arguments: [String], workingDirectory: URL) async throws -> ProcessResult
}

struct ProcessResult: Equatable, Sendable {
    var exitCode: Int32
    var stdout: String
    var stderr: String
}

struct FoundationProcessRunner: ProcessRunning {
    func run(executableURL: URL, arguments: [String], workingDirectory: URL) async throws -> ProcessResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stdout = Pipe()
            let stderr = Pipe()
            process.executableURL = executableURL
            process.arguments = arguments
            process.currentDirectoryURL = workingDirectory
            process.standardOutput = stdout
            process.standardError = stderr
            process.terminationHandler = { process in
                let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
                let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: ProcessResult(
                    exitCode: process.terminationStatus,
                    stdout: String(decoding: outputData, as: UTF8.self),
                    stderr: String(decoding: errorData, as: UTF8.self)
                ))
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

struct OpencodeRoutineSummarizer: RoutineSummarizer {
    var executableURL: URL?
    var processRunner: ProcessRunning

    init(executableURL: URL? = nil, processRunner: ProcessRunning = FoundationProcessRunner()) {
        self.executableURL = executableURL
        self.processRunner = processRunner
    }

    func generateRoutine(packetPath: URL, routineType: RoutineType) async throws -> RoutineResult {
        let executable = try executableURL ?? Self.findOpencode()
        let prompt = """
        Read AGENTS.md, prompt.md, timeline.md, timeline.json, and representative screenshots in this folder.
        Generate the \(routineType.rawValue) routine exactly as requested.
        Write the final Markdown only to output.md.
        """
        let result = try await processRunner.run(
            executableURL: executable,
            arguments: ["run", prompt],
            workingDirectory: packetPath
        )
        guard result.exitCode == 0 else {
            let message = result.stderr.isEmpty ? result.stdout : result.stderr
            throw LocalBirdError.opencodeFailed(message)
        }
        let output = packetPath.appendingPathComponent("output.md")
        guard FileManager.default.fileExists(atPath: output.path) else {
            throw LocalBirdError.outputMissing
        }
        let markdown = try String(contentsOf: output, encoding: .utf8)
        guard !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LocalBirdError.outputMissing
        }
        return RoutineResult(outputMarkdownURL: output, markdown: markdown)
    }

    static func findOpencode() throws -> URL {
        let candidates = [
            "/opt/homebrew/bin/opencode",
            "/usr/local/bin/opencode",
            "/usr/bin/opencode"
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        throw LocalBirdError.opencodeUnavailable
    }
}
