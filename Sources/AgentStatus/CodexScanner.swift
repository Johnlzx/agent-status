import Foundation

final class CodexScanner: @unchecked Sendable {
    static let shared = CodexScanner()

    private var task: Task<Void, Never>?

    func start(store: SessionStore) {
        task?.cancel()
        task = Task.detached(priority: .utility) { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.tick(store: store)
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func tick(store: SessionStore) async {
        let entries = Self.findCodexProcesses()
        var pids = Set<Int32>()
        var cwds: [Int32: String] = [:]
        for e in entries {
            pids.insert(e.pid)
            cwds[e.pid] = Self.readCwd(pid: e.pid) ?? ""
        }
        let alivePids = pids
        let cwdByPid = cwds
        await MainActor.run {
            for e in entries {
                store.upsertCodex(pid: e.pid, cwd: cwdByPid[e.pid] ?? "")
            }
            store.reconcileCodex(alivePids: alivePids)
            store.sweepStale()
        }
    }

    struct ProcEntry: Sendable {
        let pid: Int32
        let comm: String
    }

    static func findCodexProcesses() -> [ProcEntry] {
        guard let output = runCommand("/bin/ps", ["-axo", "pid=,comm="]) else {
            return []
        }
        var result: [ProcEntry] = []
        for raw in output.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2, let pid = Int32(parts[0]) else { continue }
            let comm = String(parts[1])
            // Match binary basename `codex`. comm on macOS is argv[0] which is
            // typically the full path (e.g. /opt/homebrew/bin/codex) or just `codex`.
            let basename = (comm as NSString).lastPathComponent
            if basename == "codex" {
                result.append(ProcEntry(pid: pid, comm: comm))
            }
        }
        return result
    }

    static func readCwd(pid: Int32) -> String? {
        guard let out = runCommand(
            "/usr/sbin/lsof",
            ["-a", "-d", "cwd", "-p", "\(pid)", "-Fn"]
        ) else {
            return nil
        }
        // lsof -Fn output is one field per line, prefixed with field char.
        // We want the "n" (name) line under an "fcwd" entry.
        for raw in out.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(raw)
            if line.hasPrefix("n") {
                return String(line.dropFirst())
            }
        }
        return nil
    }

    static func runCommand(_ path: String, _ args: [String]) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let out = Pipe()
        let err = Pipe()
        p.standardOutput = out
        p.standardError = err
        do {
            try p.run()
        } catch {
            return nil
        }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }
}
