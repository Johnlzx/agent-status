import Foundation
import Darwin

final class IPCServer: @unchecked Sendable {
    static let shared = IPCServer()

    private let queue = DispatchQueue(label: "dev.johnlzx.agent-status.ipc", qos: .utility)
    private var listenFD: Int32 = -1
    private var store: SessionStore?
    private var started = false

    func start(store: SessionStore) {
        queue.async { [weak self] in
            guard let self, !self.started else { return }
            self.started = true
            self.store = store
            self.run()
        }
    }

    static func socketPath() -> String {
        let home = NSHomeDirectory()
        let dir = "\(home)/Library/Application Support/AgentStatus"
        try? FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true, attributes: nil
        )
        return "\(dir)/ipc.sock"
    }

    private func run() {
        let path = Self.socketPath()
        unlink(path)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            fputs("[IPC] socket() failed errno=\(errno)\n", stderr)
            return
        }
        listenFD = fd

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        path.withCString { cpath in
            withUnsafeMutablePointer(to: &addr.sun_path) { tuplePtr in
                tuplePtr.withMemoryRebound(to: CChar.self, capacity: 104) { dst in
                    _ = strlcpy(dst, cpath, 104)
                }
            }
        }
        let size = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bindRes = withUnsafePointer(to: &addr) { p -> Int32 in
            p.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                Darwin.bind(fd, sa, size)
            }
        }
        guard bindRes == 0 else {
            fputs("[IPC] bind() failed errno=\(errno) path=\(path)\n", stderr)
            close(fd)
            return
        }
        chmod(path, 0o600)

        guard listen(fd, 32) == 0 else {
            fputs("[IPC] listen() failed errno=\(errno)\n", stderr)
            close(fd)
            return
        }

        fputs("[IPC] listening on \(path)\n", stderr)

        while true {
            let client = accept(fd, nil, nil)
            if client < 0 {
                if errno == EINTR { continue }
                fputs("[IPC] accept() failed errno=\(errno)\n", stderr)
                break
            }
            let s = self.store
            DispatchQueue.global(qos: .utility).async {
                Self.handleConnection(fd: client, store: s)
            }
        }
    }

    private static func handleConnection(fd: Int32, store: SessionStore?) {
        defer { close(fd) }

        var timeout = timeval(tv_sec: 2, tv_usec: 0)
        _ = setsockopt(
            fd, SOL_SOCKET, SO_RCVTIMEO, &timeout,
            socklen_t(MemoryLayout<timeval>.size)
        )

        var buffer = Data()
        let tmpCapacity = 4096
        let tmp = UnsafeMutablePointer<UInt8>.allocate(capacity: tmpCapacity)
        defer { tmp.deallocate() }

        while buffer.count < 262_144 {
            let n = read(fd, tmp, tmpCapacity)
            if n <= 0 { break }
            buffer.append(tmp, count: n)
        }

        guard !buffer.isEmpty else { return }

        for line in buffer.split(separator: 0x0A, omittingEmptySubsequences: true) {
            guard !line.isEmpty else { continue }
            let data = Data(line)
            guard let event = try? JSONDecoder().decode(HookEvent.self, from: data) else {
                if let raw = String(data: data, encoding: .utf8) {
                    fputs("[IPC] drop bad json: \(raw.prefix(200))\n", stderr)
                }
                continue
            }
            Task { @MainActor in
                store?.applyClaudeEvent(event)
            }
        }
    }
}
