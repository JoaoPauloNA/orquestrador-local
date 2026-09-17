import Foundation

/// Interacts with launchctl without ever blocking the main actor on a child
/// process. Output is drained while the process runs and only a small,
/// sanitized prefix is retained for diagnostics.
public actor LaunchAgentAdapter {
    private let uid: uid_t
    private let executableURL: URL
    private let commandTimeout: TimeInterval
    private let maximumOutputBytes: Int

    public init(
        executableURL: URL = URL(fileURLWithPath: "/bin/launchctl"),
        commandTimeout: TimeInterval = 8,
        maximumOutputBytes: Int = 32 * 1024
    ) {
        self.uid = getuid()
        self.executableURL = executableURL
        self.commandTimeout = commandTimeout
        self.maximumOutputBytes = maximumOutputBytes
    }

    public struct ServiceStatus: Sendable { public let pid: Int?; public let lastExitStatus: Int?; public let program: String? }
    public enum Observation: Sendable { case running(ServiceStatus), loaded(ServiceStatus), absent, unavailable(String) }

    public func observe(label: String, domain: LaunchdDomain) async -> Observation {
        let target = "\(domain.rawValue)/\(uid)/\(label)"
        let result = await runCommand(["print", target])
        guard result.exitCode == 0 else {
            let reason = result.stderr.lowercased()
            if reason.contains("could not find service") || reason.contains("not found") { return .absent }
            if result.cancelled { return .unavailable("Observação do LaunchAgent cancelada") }
            return .unavailable(result.timedOut ? "Observação do LaunchAgent excedeu o limite" : sanitizeOutput(result.stderr))
        }
        var pid: Int?; var exitStatus: Int?; var program: String?
        for line in result.stdout.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("pid =") { pid = Int(extractValue(from: t)) }
            else if t.hasPrefix("last exit code =") { exitStatus = Int(extractValue(from: t)) }
            else if t.hasPrefix("program =") { program = extractValue(from: t) }
        }
        let status = ServiceStatus(pid: pid, lastExitStatus: exitStatus, program: program)
        return pid == nil ? .loaded(status) : .running(status)
    }

    public func verifyIdentity(label: String, domain: LaunchdDomain, expectedExecutable: String) async -> Bool {
        guard case .running(let status) = await observe(label: label, domain: domain), let program = status.program else { return false }
        // launchd may report the resolved target of a symlink even when the
        // validated plist deliberately names its stable symlink path (notably
        // /usr/bin/python3 on Xcode-backed systems).  Compare canonical paths
        // so this remains an identity check rather than a spelling check.
        return canonicalExecutablePath(program) == canonicalExecutablePath(expectedExecutable)
    }

    public enum StartResult: Sendable { case success, alreadyRunning, failed(String) }
    public func bootstrap(label: String, domain: LaunchdDomain, plistPath: String) async -> StartResult {
        guard FileManager.default.fileExists(atPath: plistPath) else { return .failed("Plist cadastrado não encontrado") }
        let serviceTarget = "\(domain.rawValue)/\(uid)/\(label)"
        switch await observe(label: label, domain: domain) {
        case .running: return .alreadyRunning
        case .loaded:
            let result = await runCommand(["kickstart", serviceTarget])
            return result.exitCode == 0 ? .success : .failed(commandError(result))
        case .unavailable(let reason): return .failed(reason)
        case .absent: break
        }
        let result = await runCommand(["bootstrap", "\(domain.rawValue)/\(uid)", plistPath])
        if result.exitCode == 0 {
            // bootstrap only registers a RunAtLoad=false job. Explicitly ask
            // launchd to start that newly registered, already-validated label.
            let kickstart = await runCommand(["kickstart", serviceTarget])
            return kickstart.exitCode == 0 ? .success : .failed(commandError(kickstart))
        }
        let stderr = result.stderr.lowercased()
        if stderr.contains("already loaded") || stderr.contains("service already exists") { return .alreadyRunning }
        return .failed(commandError(result))
    }

    public enum StopResult: Sendable { case success, notLoaded, failed(String) }
    /// Asks launchd to stop only the named managed job. It never signals a PID.
    public func bootout(label: String, domain: LaunchdDomain) async -> StopResult {
        let result = await runCommand(["bootout", "\(domain.rawValue)/\(uid)/\(label)"])
        if result.exitCode == 0 { return .success }
        let stderr = result.stderr.lowercased()
        if stderr.contains("no such process") || stderr.contains("not found") { return .notLoaded }
        return .failed(commandError(result))
    }

    /// Last resort after a graceful bootout timeout. This is scoped to the
    /// verified launchd label, never a process name or a port.
    public func forceStopManagedJob(label: String, domain: LaunchdDomain) async -> Bool {
        let result = await runCommand(["kill", "SIGKILL", "\(domain.rawValue)/\(uid)/\(label)"])
        return result.exitCode == 0
    }

    /// Checks only the numeric loopback port registered in a profile before
    /// bootstrap, preventing a foreign listener from being displaced.
    public func isPortOccupied(by url: URL) async -> Bool {
        guard let port = url.port, (1...65535).contains(port) else { return true }
        let result = await runSystemCommand("/usr/sbin/lsof", ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN"])
        return result.exitCode == 0 && !result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The UI receives only a bounded, sanitized tail; it never receives the
    /// log paths or full command/environment of a managed service.
    public func recentOutput(plistPath: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return nil }
        let paths = [plist["StandardErrorPath"], plist["StandardOutPath"]].compactMap { $0 as? String }
        let tails = paths.compactMap { path -> String? in
            guard let handle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: path)) else { return nil }
            defer { try? handle.close() }
            let size = (try? handle.seekToEnd()) ?? 0
            try? handle.seek(toOffset: size > 4096 ? size - 4096 : 0)
            guard let text = String(data: handle.readDataToEndOfFile(), encoding: .utf8) else { return nil }
            return text
        }
        let text = tails.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : ServiceEvent.sanitize(String(text.suffix(1024)))
    }

    // Internal product test seam: it runs an explicitly supplied helper only.
    public func runCommandForTesting(_ arguments: [String]) async -> (exitCode: Int32, stdout: String, stderr: String, timedOut: Bool, cancelled: Bool, outputTruncated: Bool) {
        let result = await runCommand(arguments)
        return (result.exitCode, result.stdout, result.stderr, result.timedOut, result.cancelled, result.outputTruncated)
    }

    fileprivate struct ProcessResult: Sendable { let exitCode: Int32; let stdout: String; let stderr: String; let timedOut: Bool; let cancelled: Bool; let outputTruncated: Bool }

    private func runCommand(_ arguments: [String]) async -> ProcessResult {
        let runner = ProcessRunner(executableURL: executableURL, arguments: arguments, timeout: commandTimeout, maximumOutputBytes: maximumOutputBytes)
        return await withTaskCancellationHandler(operation: {
            await runner.run()
        }, onCancel: {
            // Only the short-lived child created by this invocation is
            // terminated. launchctl-managed services are never signalled here.
            Task { await runner.cancel() }
        })
    }

    private func runSystemCommand(_ path: String, _ arguments: [String]) async -> ProcessResult {
        let runner = ProcessRunner(executableURL: URL(fileURLWithPath: path), arguments: arguments, timeout: commandTimeout, maximumOutputBytes: maximumOutputBytes)
        return await runner.run()
    }

    private func commandError(_ result: ProcessResult) -> String {
        result.timedOut ? "Comando launchctl excedeu o limite de tempo" : sanitizeOutput(result.stderr)
    }
    private func extractValue(from line: String) -> String {
        let parts = line.split(separator: "=", maxSplits: 1)
        return parts.count >= 2 ? String(parts[1]).trimmingCharacters(in: CharacterSet(charactersIn: " ;\"")) : ""
    }
    private func sanitizeOutput(_ raw: String) -> String {
        let lower = raw.lowercased()
        if lower.contains("operation not permitted") || lower.contains("permission denied") { return "Permissão negada ao observar o LaunchAgent" }
        if lower.contains("could not find service") || lower.contains("not found") { return "LaunchAgent não encontrado no domínio do usuário" }
        return "launchctl falhou (código sanitizado)"
    }

    private func canonicalExecutablePath(_ path: String) -> String {
        URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path
    }
}

private actor ProcessRunner {
    private enum Stream { case stdout, stderr }
    private let executableURL: URL, arguments: [String], timeout: TimeInterval, limit: Int
    private let process = Process()
    private let stdoutPipe = Pipe(), stderrPipe = Pipe()
    private var stdoutData = Data(), stderrData = Data(), truncated = false
    private var continuation: CheckedContinuation<LaunchAgentAdapter.ProcessResult, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var didFinish = false, didCancel = false, didTimeout = false

    init(executableURL: URL, arguments: [String], timeout: TimeInterval, maximumOutputBytes: Int) {
        self.executableURL = executableURL; self.arguments = arguments; self.timeout = timeout; self.limit = max(1, maximumOutputBytes)
    }

    func run() async -> LaunchAgentAdapter.ProcessResult {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            guard !didCancel else { finish(exitCode: -1); return }
            process.executableURL = executableURL; process.arguments = arguments
            process.standardOutput = stdoutPipe; process.standardError = stderrPipe
            stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                Task { await self?.append(data, to: .stdout) }
            }
            stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                Task { await self?.append(data, to: .stderr) }
            }
            process.terminationHandler = { [weak self] _ in Task { await self?.terminated() } }
            do { try process.run() } catch { finish(exitCode: -1, launchError: error.localizedDescription); return }
            let delay = timeout
            timeoutTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                await self?.timeoutExpired()
            }
        }
    }

    func cancel() {
        guard !didFinish else { return }
        didCancel = true
        if process.isRunning { process.terminate() } else { finish(exitCode: -1) }
    }

    private func timeoutExpired() {
        guard !didFinish else { return }
        didTimeout = true
        if process.isRunning { process.terminate() } else { finish(exitCode: -1) }
    }

    private func terminated() { finish(exitCode: process.terminationStatus) }

    private func append(_ data: Data, to stream: Stream) {
        guard !data.isEmpty, !didFinish else { return }
        if stream == .stdout { append(data, into: &stdoutData) } else { append(data, into: &stderrData) }
    }
    private func append(_ data: Data, into target: inout Data) {
        let remaining = limit - target.count
        guard remaining > 0 else { truncated = true; return }
        target.append(data.prefix(remaining)); if data.count > remaining { truncated = true }
    }
    private func finish(exitCode: Int32, launchError: String? = nil) {
        guard !didFinish else { return }; didFinish = true; timeoutTask?.cancel()
        stdoutPipe.fileHandleForReading.readabilityHandler = nil; stderrPipe.fileHandleForReading.readabilityHandler = nil
        appendCaptured(stdoutPipe.fileHandleForReading.readDataToEndOfFile(), to: .stdout)
        appendCaptured(stderrPipe.fileHandleForReading.readDataToEndOfFile(), to: .stderr)
        let result = LaunchAgentAdapter.ProcessResult(exitCode: exitCode, stdout: String(data: stdoutData, encoding: .utf8) ?? "", stderr: launchError ?? (String(data: stderrData, encoding: .utf8) ?? ""), timedOut: didTimeout, cancelled: didCancel, outputTruncated: truncated)
        continuation?.resume(returning: result); continuation = nil
    }

    private func appendCaptured(_ data: Data, to stream: Stream) {
        guard !data.isEmpty else { return }
        if stream == .stdout { append(data, into: &stdoutData) } else { append(data, into: &stderrData) }
    }
}
