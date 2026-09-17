import Foundation
import CryptoKit

/// Validates a raw registration form before creating a ServiceProfile.
/// Rejects: missing required fields, non-existent paths, non-loopback URLs,
/// labels with forbidden characters, metacharacter injection.
public enum ProfileValidator {

    public struct RawInput: Sendable {
        public var name: String
        public var label: String
        public var launchdDomain: LaunchdDomain
        public var plistPath: String
        public var executablePath: String
        public var workingDirectory: String
        public var readinessURLString: String
        public var readinessIdentityKind: ReadinessIdentityKind
        public var readinessIdentityValue: String
        public var activityURLString: String
        public var openURLString: String
        public var readinessTimeoutSeconds: Int
        public var stopTimeoutSeconds: Int
        public var description: String

        public init(
            name: String = "",
            label: String = "",
            launchdDomain: LaunchdDomain = .gui,
            plistPath: String = "",
            executablePath: String = "",
            workingDirectory: String = "",
            readinessURLString: String = "",
            readinessIdentityKind: ReadinessIdentityKind = .bodyContains,
            readinessIdentityValue: String = "",
            activityURLString: String = "",
            openURLString: String = "",
            readinessTimeoutSeconds: Int = 90,
            stopTimeoutSeconds: Int = 30,
            description: String = ""
        ) {
            self.name = name
            self.label = label
            self.launchdDomain = launchdDomain
            self.plistPath = plistPath
            self.executablePath = executablePath
            self.workingDirectory = workingDirectory
            self.readinessURLString = readinessURLString
            self.readinessIdentityKind = readinessIdentityKind
            self.readinessIdentityValue = readinessIdentityValue
            self.activityURLString = activityURLString
            self.openURLString = openURLString
            self.readinessTimeoutSeconds = readinessTimeoutSeconds
            self.stopTimeoutSeconds = stopTimeoutSeconds
            self.description = description
        }
    }

    public enum ReadinessIdentityKind: String, CaseIterable, Identifiable, Sendable {
        case bodyContains = "Texto no corpo"
        case jsonTopLevelKey = "Chave JSON"
        public var id: String { rawValue }
    }

    public enum ValidationError: Error, LocalizedError {
        case emptyField(String)
        case invalidLabel(String)
        case pathNotFound(String)
        case pathNotAbsolute(String)
        case nonLoopbackURL(String)
        case invalidURL(String)
        case injectionAttempt(String)
        case timeoutOutOfRange(String)
        case labelNotAllowed(String)
        case invalidPlist(String)
        case plistContractMismatch(String)
        case plistOwnership(String)

        public var errorDescription: String? {
            switch self {
            case .emptyField(let f):       return "Campo obrigatório vazio: \(f)"
            case .invalidLabel(let l):     return "Label inválida: \(l)"
            case .pathNotFound(let p):     return "Caminho não encontrado: \(p)"
            case .pathNotAbsolute(let p):  return "Caminho deve ser absoluto: \(p)"
            case .nonLoopbackURL(let u):   return "URL deve ser loopback (127.0.0.1): \(u)"
            case .invalidURL(let u):       return "URL inválida: \(u)"
            case .injectionAttempt(let f): return "Conteúdo não permitido no campo: \(f)"
            case .timeoutOutOfRange(let f):return "Timeout fora do intervalo (5–600s): \(f)"
            case .labelNotAllowed(let l):  return "Label não permitida para controle: \(l)"
            case .invalidPlist(let m):      return "Plist inválido: \(m)"
            case .plistContractMismatch(let m): return "Contrato do LaunchAgent não confere: \(m)"
            case .plistOwnership(let m):   return "Propriedade do plist não permitida: \(m)"
            }
        }
    }

    // Labels that the panel is never allowed to control
    private static let forbiddenLabels: Set<String> = [
        "com.apple.launchd",
        "com.apple.launchd.peruser",
    ]

    // Characters not allowed in labels (only alphanumeric, dots, hyphens)
    private static let labelAllowedChars = CharacterSet.alphanumerics
        .union(CharacterSet(charactersIn: ".-"))

    // Characters that indicate injection attempts in any field
    private static let injectionPatterns: [String] = [
        ";", "&&", "||", "`", "$(",  // shell metacharacters
        "\0",                          // null byte
        "../", "/..",                  // path traversal
    ]

    public static func validate(_ input: RawInput) throws -> ServiceProfile {
        // Name
        let name = input.name.trimmingCharacters(in: .whitespaces)
        if name.isEmpty { throw ValidationError.emptyField("nome") }
        try checkInjection(name, field: "nome")

        // Label
        let label = input.label.trimmingCharacters(in: .whitespaces)
        if label.isEmpty { throw ValidationError.emptyField("label") }
        try checkInjection(label, field: "label")
        guard label.unicodeScalars.allSatisfy({ labelAllowedChars.contains($0) }) else {
            throw ValidationError.invalidLabel(label)
        }
        if forbiddenLabels.contains(label) {
            throw ValidationError.labelNotAllowed(label)
        }

        // Plist path
        let plistPath = try validateAbsolutePath(input.plistPath, field: "plist")

        // Executable path (must exist)
        let execPath = try validateAbsolutePath(input.executablePath, field: "executável")
        guard FileManager.default.fileExists(atPath: execPath) else {
            throw ValidationError.pathNotFound(execPath)
        }

        // Working directory (must exist)
        let workDir = try validateAbsolutePath(input.workingDirectory, field: "diretório")
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: workDir, isDirectory: &isDir),
              isDir.boolValue else {
            throw ValidationError.pathNotFound(workDir)
        }

        // Readiness URL
        let readinessURL = try validateLoopbackURL(input.readinessURLString, field: "URL de prontidão")
        let identityValue = input.readinessIdentityValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if identityValue.isEmpty { throw ValidationError.emptyField("identidade de prontidão") }
        try checkInjection(identityValue, field: "identidade de prontidão")
        guard identityValue.count <= 128 else {
            throw ValidationError.plistContractMismatch("identidade de prontidão excede 128 caracteres")
        }
        let readinessIdentity: ReadinessIdentity = input.readinessIdentityKind == .bodyContains
            ? .bodyContains(identityValue)
            : .jsonTopLevelKey(identityValue)

        // Activity URL (optional)
        let activityURL: URL?
        if input.activityURLString.trimmingCharacters(in: .whitespaces).isEmpty {
            activityURL = nil
        } else {
            activityURL = try validateLoopbackURL(input.activityURLString, field: "URL de atividade")
        }

        // Open URL
        let openURL = try validateLoopbackURL(input.openURLString, field: "URL de abertura")

        // Timeouts
        guard (5...600).contains(input.readinessTimeoutSeconds) else {
            throw ValidationError.timeoutOutOfRange("prontidão")
        }
        guard (5...300).contains(input.stopTimeoutSeconds) else {
            throw ValidationError.timeoutOutOfRange("parada")
        }

        // Description
        let desc = String(input.description.prefix(256))
        try checkInjection(desc, field: "descrição")

        let fingerprint = try validateLaunchAgentContract(
            plistPath: plistPath,
            expectedLabel: label,
            expectedExecutable: execPath,
            expectedWorkingDirectory: workDir
        )

        return ServiceProfile(
            id: UUID(),
            name: name,
            label: label,
            launchdDomain: input.launchdDomain,
            plistPath: plistPath,
            executablePath: execPath,
            workingDirectory: workDir,
            controlFingerprint: fingerprint,
            readinessURL: readinessURL,
            readinessIdentity: readinessIdentity,
            activityURL: activityURL,
            activityRunningKey: nil,
            activityPendingKey: nil,
            openURL: openURL,
            readinessTimeoutSeconds: input.readinessTimeoutSeconds,
            stopTimeoutSeconds: input.stopTimeoutSeconds,
            description: desc,
            schemaVersion: ServiceProfile.currentSchemaVersion,
            validatedAt: Date()
        )
    }

    private static func validateLaunchAgentContract(
        plistPath: String,
        expectedLabel: String,
        expectedExecutable: String,
        expectedWorkingDirectory: String
    ) throws -> String {
        let url = URL(fileURLWithPath: plistPath).standardizedFileURL
        let allowedDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .standardizedFileURL
        guard url.pathExtension == "plist", url.deletingLastPathComponent() == allowedDirectory else {
            throw ValidationError.plistOwnership("somente ~/Library/LaunchAgents/*.plist")
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ValidationError.pathNotFound(url.path)
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let ownerID = attributes[.ownerAccountID] as? NSNumber,
              ownerID.uint32Value == getuid() else {
            throw ValidationError.plistOwnership("arquivo não pertence ao usuário atual")
        }
        let data = try Data(contentsOf: url)
        guard let dictionary = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: Any] else {
            throw ValidationError.invalidPlist("raiz não é um dicionário")
        }
        guard dictionary["Label"] as? String == expectedLabel else {
            throw ValidationError.plistContractMismatch("Label diverge do arquivo")
        }
        let declaredExecutable = dictionary["Program"] as? String
            ?? (dictionary["ProgramArguments"] as? [String])?.first
        guard let declaredExecutable,
              URL(fileURLWithPath: declaredExecutable).standardizedFileURL.path == URL(fileURLWithPath: expectedExecutable).standardizedFileURL.path else {
            throw ValidationError.plistContractMismatch("executável diverge do arquivo")
        }
        if let declaredDirectory = dictionary["WorkingDirectory"] as? String,
           URL(fileURLWithPath: declaredDirectory).standardizedFileURL.path != URL(fileURLWithPath: expectedWorkingDirectory).standardizedFileURL.path {
            throw ValidationError.plistContractMismatch("diretório de trabalho diverge do arquivo")
        }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public static func revalidate(_ profile: ServiceProfile) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: profile.plistPath))
        let current = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard current == profile.controlFingerprint else {
            throw ValidationError.plistContractMismatch("o plist mudou após a aprovação")
        }
        _ = try validateLaunchAgentContract(
            plistPath: profile.plistPath,
            expectedLabel: profile.label,
            expectedExecutable: profile.executablePath,
            expectedWorkingDirectory: profile.workingDirectory
        )
    }

    private static func validateAbsolutePath(_ raw: String, field: String) throws -> String {
        let path = raw.trimmingCharacters(in: .whitespaces)
        if path.isEmpty { throw ValidationError.emptyField(field) }
        guard path.hasPrefix("/") else { throw ValidationError.pathNotAbsolute(path) }
        try checkInjection(path, field: field)
        return path
    }

    private static func validateLoopbackURL(_ raw: String, field: String) throws -> URL {
        let s = raw.trimmingCharacters(in: .whitespaces)
        if s.isEmpty { throw ValidationError.emptyField(field) }
        guard let url = URL(string: s), let host = url.host else {
            throw ValidationError.invalidURL(s)
        }
        guard host == "127.0.0.1" || host == "localhost" || host == "::1" else {
            throw ValidationError.nonLoopbackURL(s)
        }
        guard url.scheme == "http" || url.scheme == "https" else {
            throw ValidationError.invalidURL(s)
        }
        try checkInjection(s, field: field)
        return url
    }

    private static func checkInjection(_ value: String, field: String) throws {
        for pattern in injectionPatterns {
            if value.contains(pattern) {
                throw ValidationError.injectionAttempt(field)
            }
        }
    }
}
