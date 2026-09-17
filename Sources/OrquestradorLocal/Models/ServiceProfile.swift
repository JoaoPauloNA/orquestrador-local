import Foundation

public enum ReadinessIdentity: Codable, Sendable, Hashable {
    case bodyContains(String)
    case jsonTopLevelKey(String)

    public var summary: String {
        switch self {
        case .bodyContains(let marker): return "corpo contém “\(marker)”"
        case .jsonTopLevelKey(let key): return "JSON contém chave “\(key)”"
        }
    }
}

public enum LaunchdDomain: String, Codable, CaseIterable, Identifiable, Sendable, Hashable {
    case gui
    case user
    public var id: String { rawValue }
}

/// Immutable validated profile for a registered service. All fields are
/// pre-validated; no profile escapes the validator in invalid form.
public struct ServiceProfile: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let name: String
    /// LaunchAgent label (e.g. "com.joaopaulo.mflux-studio")
    public let label: String
    public let launchdDomain: LaunchdDomain
    /// Absolute path to the plist file
    public let plistPath: String
    /// Absolute path to the executable (for identity verification)
    public let executablePath: String
    /// Working directory
    public let workingDirectory: String
    /// SHA-256 of the approved plist bytes; any change blocks mutations until re-registration.
    public let controlFingerprint: String
    /// Readiness endpoint — loopback only
    public let readinessURL: URL
    /// Service-specific proof required in a successful readiness response.
    public let readinessIdentity: ReadinessIdentity
    /// Optional activity endpoint (ComfyUI /queue style). nil = not supported.
    public let activityURL: URL?
    /// JSON key path for queue_running count in activity response. nil = use default.
    public let activityRunningKey: String?
    /// JSON key path for queue_pending count. nil = use default.
    public let activityPendingKey: String?
    /// URL to open when service is ready (may differ from readiness URL)
    public let openURL: URL
    /// Readiness timeout in seconds
    public let readinessTimeoutSeconds: Int
    /// Stop timeout in seconds
    public let stopTimeoutSeconds: Int
    /// Short description shown in UI
    public let description: String
    /// Catalog schema version used when this profile was saved
    public let schemaVersion: Int
    /// Date this profile was added/last validated
    public let validatedAt: Date

    public static let currentSchemaVersion = 1

    /// Keeps the catalog identity stable while refreshing declarative fields.
    func replacingID(_ id: UUID) -> ServiceProfile {
        ServiceProfile(
            id: id,
            name: name,
            label: label,
            launchdDomain: launchdDomain,
            plistPath: plistPath,
            executablePath: executablePath,
            workingDirectory: workingDirectory,
            controlFingerprint: controlFingerprint,
            readinessURL: readinessURL,
            readinessIdentity: readinessIdentity,
            activityURL: activityURL,
            activityRunningKey: activityRunningKey,
            activityPendingKey: activityPendingKey,
            openURL: openURL,
            readinessTimeoutSeconds: readinessTimeoutSeconds,
            stopTimeoutSeconds: stopTimeoutSeconds,
            description: description,
            schemaVersion: schemaVersion,
            validatedAt: validatedAt
        )
    }
}
