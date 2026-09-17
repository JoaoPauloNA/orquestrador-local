import Foundation
import SwiftUI

/// Runtime state of one registered service.
@MainActor
public final class ServiceRuntime: ObservableObject, Identifiable {
    public let profile: ServiceProfile
    public nonisolated let id: UUID

    @Published public private(set) var lifecycleState: ServiceLifecycleState = .stopped
    @Published public private(set) var activityState: ActivityState = .unknown
    @Published public private(set) var lastChecked: Date?
    @Published public private(set) var lastError: String?
    @Published public private(set) var quotaState: QuotaState = .notChecked
    @Published public private(set) var isActionInProgress: Bool = false
    @Published public private(set) var recentEvents: [ServiceEvent] = []
    @Published public private(set) var managedPID: Int?
    @Published public private(set) var lastExitStatus: Int?
    @Published public private(set) var lastOutput: String?

    private let eventLog = EventLog()

    public init(profile: ServiceProfile) {
        self.profile = profile
        self.id = profile.id
    }

    @discardableResult
    func applyTransition(to next: ServiceLifecycleState) -> Bool {
        guard lifecycleState.canTransition(to: next) else { return false }
        lifecycleState = next
        return true
    }

    func setActivity(_ state: ActivityState) {
        activityState = state
        lastChecked = Date()
    }

    func setActionInProgress(_ value: Bool) { isActionInProgress = value }

    func setQuota(_ state: QuotaState) { quotaState = state }

    func reconcileState(_ state: ServiceLifecycleState) {
        lifecycleState = state
    }

    func setError(_ message: String) {
        lastError = message
        let event = ServiceEvent(serviceId: profile.id, kind: .error, message: message)
        Task {
            await eventLog.append(event)
            recentEvents = await eventLog.recent()
        }
    }

    func clearError() { lastError = nil }

    func setProcessDetails(pid: Int?, exitStatus: Int?, output: String?) {
        managedPID = pid
        lastExitStatus = exitStatus
        if let output, !output.isEmpty { lastOutput = ServiceEvent.sanitize(output) }
    }

    func addEvent(_ event: ServiceEvent) {
        Task {
            await eventLog.append(event)
            recentEvents = await eventLog.recent()
        }
    }
}

/// Central coordinator — serialises lifecycle actions per service, drives UI state.
@MainActor
public final class OrchestrationCoordinator: ObservableObject {

    public static let localTranscriberLabel = "com.joaopaulo.localtranscriber"
    public static let secondMindLabel = "com.joaopaulo.segunda-mente"

    @Published public private(set) var services: [ServiceRuntime] = []
    @Published public private(set) var catalogError: String?

    private let catalog: CatalogStore
    private let launchAgent: LaunchAgentAdapter
    private let readinessProbe: ReadinessProbe
    private let activityProbe: ActivityProbe
    private let quotaProbe: QuotaProbe
    public let resourceGuard: ResourceGuardCoordinator

    /// Tracks which service IDs have an active lock (prevents concurrent start/stop)
    private var actionLocks: Set<UUID> = []

    private var pollingTask: Task<Void, Never>?

    /// Dependencies are injectable only to exercise the real product against
    /// isolated fixtures; production uses the defaults.
    public init(
        catalog: CatalogStore = CatalogStore(),
        launchAgent: LaunchAgentAdapter = LaunchAgentAdapter(),
        readinessProbe: ReadinessProbe = ReadinessProbe(),
        activityProbe: ActivityProbe = ActivityProbe(),
        quotaProbe: QuotaProbe = QuotaProbe(),
        resourceGuard: ResourceGuardCoordinator = ResourceGuardCoordinator()
    ) {
        self.catalog = catalog
        self.launchAgent = launchAgent
        self.readinessProbe = readinessProbe
        self.activityProbe = activityProbe
        self.quotaProbe = quotaProbe
        self.resourceGuard = resourceGuard
    }

    // MARK: - Startup

    public func start() async {
        await loadCatalog()
        if let stale = services.first(where: {
            $0.profile.label == Self.localTranscriberLabel &&
            ($0.profile.plistPath.contains("(Self.localTranscriberLabel)") ||
             !$0.profile.executablePath.hasSuffix("/.venv/bin/python3"))
        }) {
            _ = await launchAgent.bootout(
                label: Self.localTranscriberLabel,
                domain: stale.profile.launchdDomain
            )
            try? await catalog.remove(id: stale.id)
            services.removeAll { $0.id == stale.id }
            try? FileManager.default.removeItem(atPath: stale.profile.plistPath)
        }
        if !services.contains(where: { $0.profile.label == Self.localTranscriberLabel }) {
            do {
                try await registerLocalTranscriber()
            } catch {
                catalogError = error.localizedDescription
            }
        }
        await refreshSecondMindRegistrationIfNeeded()
        if !services.contains(where: { $0.profile.label == Self.secondMindLabel }) {
            do {
                try await registerSecondMind()
            } catch {
                catalogError = error.localizedDescription
            }
        }
        await registerConfiguredServices()
        await reconcileAll(refreshQuota: true)
        startPolling()
    }

    public func reportCatalogError(_ message: String) {
        catalogError = message
    }

    private func loadCatalog() async {
        do {
            try await catalog.load()
            let profiles = await catalog.allProfiles()
            services = profiles.map { ServiceRuntime(profile: $0) }
        } catch {
            catalogError = error.localizedDescription
            let profiles = await catalog.allProfiles()
            services = profiles.map { ServiceRuntime(profile: $0) }
        }
    }

    // MARK: - Registration

    public func register(input: ProfileValidator.RawInput) async throws {
        let profile = try ProfileValidator.validate(input)
        try await catalog.add(profile)
        let runtime = ServiceRuntime(profile: profile)
        services.append(runtime)
        await reconcile(runtime)
    }

    /// Registers the project-local transcription service without starting it.
    /// The LaunchAgent is created only after the user presses the dedicated UI action.
    public func registerLocalTranscriber() async throws {
        guard !services.contains(where: { $0.profile.label == Self.localTranscriberLabel }) else { return }

        let projectRoot = URL(fileURLWithPath: "/Users/joaopaulo/Documents/Projetos/Pessoal/LLM/LocalTranscriber", isDirectory: true)
        let executable = projectRoot.appendingPathComponent(".venv/bin/python3")
        let launchAgents = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
        let plistURL = launchAgents.appendingPathComponent(Self.localTranscriberLabel + ".plist")
        guard FileManager.default.fileExists(atPath: executable.path) else {
            throw CoordinatorError.integrationUnavailable("LocalTranscriber não encontrado em (projectRoot.path)")
        }

        try FileManager.default.createDirectory(at: launchAgents, withIntermediateDirectories: true)
        let plist: [String: Any] = [
            "Label": Self.localTranscriberLabel,
            "Program": executable.path,
            "ProgramArguments": [executable.path, "-m", "uvicorn", "app.main:app", "--host", "127.0.0.1", "--port", "8766"],
            "WorkingDirectory": projectRoot.path,
            "RunAtLoad": false,
            "KeepAlive": false,
            "ProcessType": "Background",
            "StandardOutPath": projectRoot.appendingPathComponent("data/orquestrador-local.stdout.log").path,
            "StandardErrorPath": projectRoot.appendingPathComponent("data/orquestrador-local.stderr.log").path
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL, options: .atomic)

        let input = ProfileValidator.RawInput(
            name: "LocalTranscriber",
            label: Self.localTranscriberLabel,
            launchdDomain: .gui,
            plistPath: plistURL.path,
            executablePath: executable.path,
            workingDirectory: projectRoot.path,
            readinessURLString: "http://127.0.0.1:8766/api/health",
            readinessIdentityKind: .bodyContains,
            readinessIdentityValue: "\"ok\":true",
            activityURLString: "",
            openURLString: "http://127.0.0.1:8766/",
            readinessTimeoutSeconds: 90,
            stopTimeoutSeconds: 30,
            description: "Transcrição privada de áudio e vídeo local com whisper.cpp"
        )
        try await register(input: input)
    }

    /// Production service: the prior build is served with `next start`, not a
    /// live dev compiler/watcher. The data-mode variable is explicit but no
    /// private vault path or credential is copied into the LaunchAgent.
    public func registerSecondMind() async throws {
        guard !services.contains(where: { $0.profile.label == Self.secondMindLabel }) else { return }
        let projectRoot = URL(fileURLWithPath: "/Users/joaopaulo/Documents/Projetos/Pessoal/Projetos-SM/Home", isDirectory: true)
        let executable = URL(fileURLWithPath: "/Users/joaopaulo/.local/bin/npm")
        let launchAgents = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
        let plistURL = launchAgents.appendingPathComponent(Self.secondMindLabel + ".plist")
        guard FileManager.default.fileExists(atPath: executable.path),
              FileManager.default.fileExists(atPath: projectRoot.appendingPathComponent(".next/BUILD_ID").path) else {
            throw CoordinatorError.integrationUnavailable("Segunda Mente exige build de produção válido antes de iniciar")
        }
        try FileManager.default.createDirectory(at: launchAgents, withIntermediateDirectories: true)
        let logDirectory = projectRoot.appendingPathComponent(".orquestrador", isDirectory: true)
        try FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        let plist: [String: Any] = [
            "Label": Self.secondMindLabel,
            "Program": executable.path,
            "ProgramArguments": [executable.path, "run", "start", "--", "--hostname", "127.0.0.1", "--port", "3010"],
            "WorkingDirectory": projectRoot.path,
            "EnvironmentVariables": [
                "SECOND_MIND_DATA_SOURCE": "hybrid",
                // npm's stable shim uses `/usr/bin/env node`; launchd does
                // not inherit the interactive shell PATH.
                "PATH": "/Users/joaopaulo/.local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            ],
            "RunAtLoad": false,
            "KeepAlive": false,
            "ProcessType": "Background",
            "StandardOutPath": logDirectory.appendingPathComponent("segunda-mente.stdout.log").path,
            "StandardErrorPath": logDirectory.appendingPathComponent("segunda-mente.stderr.log").path
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL, options: .atomic)
        let input = ProfileValidator.RawInput(
            name: "Segunda Mente", label: Self.secondMindLabel, launchdDomain: .gui,
            plistPath: plistURL.path, executablePath: executable.path, workingDirectory: projectRoot.path,
            readinessURLString: "http://127.0.0.1:3010/api/health",
            readinessIdentityKind: .bodyContains, readinessIdentityValue: "\"service\":\"segunda-mente\"",
            activityURLString: "", openURLString: "http://127.0.0.1:3010/",
            readinessTimeoutSeconds: 90, stopTimeoutSeconds: 30,
            description: "Dashboard pessoal em modo HYBRID, servido pelo build de produção local"
        )
        try await register(input: input)
    }

    /// Adds missing declarative profiles and refreshes their stored readiness
    /// contract when the bundled catalog changes. It never creates, edits,
    /// unloads or disables a real pilot plist.
    private func registerConfiguredServices() async {
        guard let definitions = try? ManagedServiceCatalog.load() else { return }
        for definition in definitions {
            guard FileManager.default.fileExists(atPath: definition.plistPath) else { continue }
            if let index = services.firstIndex(where: { $0.profile.label == definition.label }) {
                do {
                    let candidate = try ProfileValidator.validate(definition.rawInput)
                    let current = services[index].profile
                    guard !sameConfiguration(current, candidate) else { continue }
                    let refreshed = candidate.replacingID(current.id)
                    try await catalog.replace(id: current.id, with: refreshed)
                    services[index] = ServiceRuntime(profile: refreshed)
                } catch {
                    catalogError = "\(definition.name): \(error.localizedDescription)"
                }
                continue
            }
            do {
                try await register(input: definition.rawInput)
            } catch {
                catalogError = "\(definition.name): \(error.localizedDescription)"
            }
        }
    }

    private func sameConfiguration(_ lhs: ServiceProfile, _ rhs: ServiceProfile) -> Bool {
        lhs.name == rhs.name &&
        lhs.label == rhs.label &&
        lhs.launchdDomain == rhs.launchdDomain &&
        lhs.plistPath == rhs.plistPath &&
        lhs.executablePath == rhs.executablePath &&
        lhs.workingDirectory == rhs.workingDirectory &&
        lhs.controlFingerprint == rhs.controlFingerprint &&
        lhs.readinessURL == rhs.readinessURL &&
        lhs.readinessIdentity == rhs.readinessIdentity &&
        lhs.activityURL == rhs.activityURL &&
        lhs.activityRunningKey == rhs.activityRunningKey &&
        lhs.activityPendingKey == rhs.activityPendingKey &&
        lhs.openURL == rhs.openURL &&
        lhs.readinessTimeoutSeconds == rhs.readinessTimeoutSeconds &&
        lhs.stopTimeoutSeconds == rhs.stopTimeoutSeconds &&
        lhs.description == rhs.description
    }

    /// Controlled one-time repair for this official profile only. It never
    /// rewrites a running job, and reuses the ordinary validated registration
    /// path so the stored fingerprint remains authoritative.
    private func refreshSecondMindRegistrationIfNeeded() async {
        guard let existing = services.first(where: { $0.profile.label == Self.secondMindLabel }) else { return }
        let profileIsCurrent = (try? ProfileValidator.revalidate(existing.profile)) != nil
        let hasLaunchdPath: Bool = {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: existing.profile.plistPath)),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                  let environment = plist["EnvironmentVariables"] as? [String: String] else { return false }
            return environment["PATH"] != nil
        }()
        guard !profileIsCurrent || !hasLaunchdPath else { return }
        if case .running = await launchAgent.observe(label: Self.secondMindLabel, domain: existing.profile.launchdDomain) {
            catalogError = "Atualização da Segunda Mente pendente: pare o serviço antes de reiniciar o Orquestrador"
            return
        }
        do {
            _ = await launchAgent.bootout(label: Self.secondMindLabel, domain: existing.profile.launchdDomain)
            try await catalog.remove(id: existing.id)
            services.removeAll { $0.id == existing.id }
            try FileManager.default.removeItem(atPath: existing.profile.plistPath)
        } catch {
            catalogError = "Não foi possível atualizar o perfil oficial da Segunda Mente"
        }
    }

    public func remove(id: UUID) async throws {
        guard let runtime = services.first(where: { $0.id == id }) else { return }
        // Never remove a service that is running under our control
        if runtime.lifecycleState == .ready || runtime.lifecycleState == .stopping {
            throw CoordinatorError.serviceStillRunning
        }
        try await catalog.remove(id: id)
        services.removeAll { $0.id == id }
    }

    // MARK: - Actions

    public func startService(_ id: UUID) async {
        guard let runtime = services.first(where: { $0.id == id }) else { return }
        guard runtime.lifecycleState.startEnabled else { return }
        guard acquireLock(id) else { return }
        defer { releaseLock(id) }

        runtime.setActionInProgress(true)
        defer { runtime.setActionInProgress(false) }

        do { try ProfileValidator.revalidate(runtime.profile) } catch {
            runtime.reconcileState(.unknown)
            runtime.setError(error.localizedDescription)
            return
        }

        runtime.clearError()
        if await launchAgent.isPortOccupied(by: runtime.profile.readinessURL) {
            runtime.reconcileState(.external)
            runtime.setError("A porta de prontidão já está ocupada por outro processo; início bloqueado")
            return
        }

        // Avaliação de Admissão pelo Resource Guard
        let decision = await resourceGuard.evaluateAdmission(for: runtime.profile.label)
        if resourceGuard.mode == .activeAdmission {
            switch decision {
            case .admit:
                // Permitido continuar normalmente
                break
            case .queue(let reason):
                runtime.setError("Início adiado pelo Resource Guard: \(reason)")
                runtime.addEvent(ServiceEvent(serviceId: id, kind: .stateReconciled, message: "Início adiado (QUEUE): \(reason)"))
                return
            case .deferMaintenance(let reason):
                runtime.setError("Início postergado pelo Resource Guard: \(reason)")
                runtime.addEvent(ServiceEvent(serviceId: id, kind: .stateReconciled, message: "Início adiado (DEFER): \(reason)"))
                return
            case .unknown(let reason):
                runtime.setError("Início prevenido pelo Resource Guard: \(reason)")
                runtime.addEvent(ServiceEvent(serviceId: id, kind: .stateReconciled, message: "Início prevenido (UNKNOWN): \(reason)"))
                return
            }
        } else {
            // Modo Observador: apenas registra telemetria e decisão consultiva sem bloquear
            switch decision {
            case .admit:
                break
            case .queue(let reason), .deferMaintenance(let reason), .unknown(let reason):
                runtime.addEvent(ServiceEvent(serviceId: id, kind: .stateReconciled, message: "Resource Guard [Observador]: \(reason)"))
            }
        }

        _ = runtime.applyTransition(to: .starting)
        runtime.addEvent(ServiceEvent(serviceId: id, kind: .started, message: "Início solicitado"))

        let bootstrapResult = await launchAgent.bootstrap(
            label: runtime.profile.label,
            domain: runtime.profile.launchdDomain,
            plistPath: runtime.profile.plistPath
        )
        switch bootstrapResult {
        case .failed(let msg):
            _ = runtime.applyTransition(to: .error)
            runtime.setError("Falha ao iniciar: \(msg)")
            return
        case .alreadyRunning:
            // Treat as if we started it — reconcile will determine actual state
            break
        case .success:
            break
        }

        // Wait for readiness
        let probeResult = await readinessProbe.waitUntilReady(
            url: runtime.profile.readinessURL,
            identity: runtime.profile.readinessIdentity,
            timeoutSeconds: runtime.profile.readinessTimeoutSeconds
        )

        switch probeResult {
        case .ready:
            _ = runtime.applyTransition(to: .ready)
            runtime.addEvent(ServiceEvent(serviceId: id, kind: .ready, message: "Serviço pronto"))
            let activity = await activityProbe.checkIfSupported(profile: runtime.profile)
            runtime.setActivity(activity)
            runtime.setQuota(await quotaProbe.check(profile: runtime.profile))
            await updateProcessDetails(for: runtime)
        case .timedOut:
            _ = runtime.applyTransition(to: .error)
            runtime.setError("Timeout de prontidão após \(runtime.profile.readinessTimeoutSeconds)s")
            runtime.addEvent(ServiceEvent(serviceId: id, kind: .startTimeout, message: "Timeout"))
        case .notReady(let reason), .error(let reason):
            _ = runtime.applyTransition(to: .error)
            runtime.setError(reason)
        }
    }

    /// Stop a service. Only callable via the Stop button; never triggered by a checkbox change.
    /// - Parameters:
    ///   - id: Service ID
    ///   - userConfirmedIdle: True only when user explicitly checked the confirmation box.
    public func stopService(_ id: UUID, userConfirmedIdle: Bool) async {
        guard let runtime = services.first(where: { $0.id == id }) else { return }
        guard runtime.lifecycleState.stopEnabled else { return }
        guard acquireLock(id) else { return }
        defer { releaseLock(id) }

        runtime.setActionInProgress(true)
        defer { runtime.setActionInProgress(false) }

        do { try ProfileValidator.revalidate(runtime.profile) } catch {
            runtime.reconcileState(.unknown)
            runtime.setError(error.localizedDescription)
            return
        }

        guard await launchAgent.verifyIdentity(
            label: runtime.profile.label,
            domain: runtime.profile.launchdDomain,
            expectedExecutable: runtime.profile.executablePath
        ) else {
            runtime.reconcileState(.external)
            runtime.setError("Propriedade do processo divergiu; parada bloqueada")
            return
        }

        // Check activity before stopping
        let activity = await activityProbe.checkIfSupported(profile: runtime.profile)
        runtime.setActivity(activity)

        switch activity.stopDecision(userConfirmedIdle: userConfirmedIdle) {
        case .blockedBusy:
            runtime.addEvent(ServiceEvent(
                serviceId: id,
                kind: .stopBlocked,
                message: "Parada bloqueada — serviço ocupado: \(activity.displayText)"
            ))
            runtime.setError("Parada bloqueada: \(activity.displayText)")
            return
        case .needsManualConfirmation:
            runtime.addEvent(ServiceEvent(
                serviceId: id,
                kind: .stopBlocked,
                message: "Parada bloqueada — atividade desconhecida; confirmação necessária"
            ))
            runtime.setError("Confirme que o serviço está ocioso antes de parar")
            return
        case .allowed:
            break
        }

        _ = runtime.applyTransition(to: .stopping)
        runtime.addEvent(ServiceEvent(serviceId: id, kind: .stopRequested, message: "Parada solicitada"))

        let result = await launchAgent.bootout(
            label: runtime.profile.label,
            domain: runtime.profile.launchdDomain
        )

        switch result {
        case .success, .notLoaded:
            // Verify service actually stopped within timeout
            let stopped = await verifyStoppped(
                label: runtime.profile.label,
                domain: runtime.profile.launchdDomain,
                timeoutSeconds: runtime.profile.stopTimeoutSeconds
            )
            if stopped {
                _ = runtime.applyTransition(to: .stopped)
                runtime.setActivity(.notSupported)
                runtime.addEvent(ServiceEvent(serviceId: id, kind: .stopped, message: "Serviço parado"))
            } else {
                runtime.addEvent(ServiceEvent(serviceId: id, kind: .stopTimeout, message: "Timeout de parada; encerramento forçado solicitado"))
                let forced = await launchAgent.forceStopManagedJob(label: runtime.profile.label, domain: runtime.profile.launchdDomain)
                let stoppedAfterForce = forced ? await verifyStoppped(label: runtime.profile.label, domain: runtime.profile.launchdDomain, timeoutSeconds: 5) : false
                if stoppedAfterForce {
                    _ = runtime.applyTransition(to: .stopped)
                    runtime.setActivity(.notSupported)
                    runtime.addEvent(ServiceEvent(serviceId: id, kind: .stopped, message: "Serviço encerrado após timeout"))
                } else {
                    _ = runtime.applyTransition(to: .error)
                    runtime.setError("Serviço não parou após \(runtime.profile.stopTimeoutSeconds)s; encerramento forçado falhou")
                }
            }
        case .failed(let msg):
            _ = runtime.applyTransition(to: .error)
            runtime.setError("Falha ao parar: \(msg)")
        }
    }

    public func openService(_ id: UUID) {
        guard let runtime = services.first(where: { $0.id == id }) else { return }
        guard runtime.lifecycleState == .ready else { return }
        NSWorkspace.shared.open(runtime.profile.openURL)
    }

    /// Restarts a managed service through the same graceful stop/start path.
    /// A stopped or errored profile is treated as a start request; a ready
    /// profile must first complete the ordinary stop safety gates.
    public func restartService(_ id: UUID, userConfirmedIdle: Bool) async {
        guard let runtime = services.first(where: { $0.id == id }) else { return }
        if runtime.lifecycleState == .ready {
            await stopService(id, userConfirmedIdle: userConfirmedIdle)
            guard runtime.lifecycleState == .stopped else { return }
        } else if !runtime.lifecycleState.startEnabled {
            return
        }
        await startService(id)
    }

    // MARK: - Reconciliation

    public func reconcileAll(refreshQuota: Bool = false) async {
        for runtime in services {
            await reconcile(runtime, refreshQuota: refreshQuota)
        }
    }

    private func reconcile(_ runtime: ServiceRuntime, refreshQuota: Bool = false) async {
        let label = runtime.profile.label
        let observation = await launchAgent.observe(label: label, domain: runtime.profile.launchdDomain)

        switch observation {
        case .running:
                // Something is running under this label
                let identityOK = await launchAgent.verifyIdentity(
                    label: label,
                    domain: runtime.profile.launchdDomain,
                    expectedExecutable: runtime.profile.executablePath
                )
                if identityOK {
                    await updateProcessDetails(for: runtime)
                    let probeResult = await readinessProbe.check(
                        url: runtime.profile.readinessURL,
                        identity: runtime.profile.readinessIdentity
                    )
                    if case .ready = probeResult {
                        runtime.reconcileState(.ready)
                        let activity = await activityProbe.checkIfSupported(profile: runtime.profile)
                        runtime.setActivity(activity)
                        if refreshQuota {
                            runtime.setQuota(await quotaProbe.check(profile: runtime.profile))
                        }
                    } else {
                        runtime.reconcileState(.starting)
                    }
                } else {
                    runtime.reconcileState(.external)
                }
        case .loaded(let status):
            runtime.setProcessDetails(pid: nil, exitStatus: status.lastExitStatus, output: await launchAgent.recentOutput(plistPath: runtime.profile.plistPath))
            if let exit = status.lastExitStatus, exit != 0 {
                runtime.reconcileState(.error)
                runtime.setError("Última saída com código \(exit)")
            } else {
                runtime.reconcileState(.stopped)
            }
        case .absent:
            runtime.reconcileState(.stopped)
            runtime.setActivity(.unknown)
            runtime.setProcessDetails(pid: nil, exitStatus: nil, output: await launchAgent.recentOutput(plistPath: runtime.profile.plistPath))
        case .unavailable(let reason):
            runtime.reconcileState(.unknown)
            runtime.setError(reason)
        }

        runtime.addEvent(ServiceEvent(
            serviceId: runtime.id,
            kind: .stateReconciled,
            message: "Reconciliado: \(runtime.lifecycleState.rawValue)"
        ))
    }

    // MARK: - Polling

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                // Active polling interval: 5s when window visible, approximated by constant interval
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await self?.reconcileAll()
            }
        }
    }

    // MARK: - Private helpers

    private func acquireLock(_ id: UUID) -> Bool {
        guard !actionLocks.contains(id) else { return false }
        actionLocks.insert(id)
        return true
    }

    private func releaseLock(_ id: UUID) {
        actionLocks.remove(id)
    }

    private func verifyStoppped(
        label: String,
        domain: LaunchdDomain,
        timeoutSeconds: Int
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(TimeInterval(timeoutSeconds))
        while Date() < deadline {
            let status = await launchAgent.observe(label: label, domain: domain)
            if case .absent = status {
                return true
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
        return false
    }

    private func updateProcessDetails(for runtime: ServiceRuntime) async {
        switch await launchAgent.observe(label: runtime.profile.label, domain: runtime.profile.launchdDomain) {
        case .running(let status), .loaded(let status):
            runtime.setProcessDetails(pid: status.pid, exitStatus: status.lastExitStatus, output: await launchAgent.recentOutput(plistPath: runtime.profile.plistPath))
        case .absent, .unavailable:
            break
        }
    }
}

public enum CoordinatorError: Error, LocalizedError {
    case serviceStillRunning
    case lockHeld
    case integrationUnavailable(String)

    public var errorDescription: String? {
        switch self {
        case .serviceStillRunning: return "Remover o cadastro enquanto o serviço está em execução não é permitido"
        case .lockHeld:            return "Uma ação já está em progresso para este serviço"
        case .integrationUnavailable(let message): return message
        }
    }
}
