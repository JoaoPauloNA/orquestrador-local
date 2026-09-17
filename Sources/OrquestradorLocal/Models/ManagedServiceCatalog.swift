import Foundation

/// Small dependency-free YAML reader for the intentionally flat service
/// catalog. It accepts only `section:` and `key: value` pairs so commands and
/// shell expressions cannot be smuggled into the configuration.
struct ManagedServiceDefinition: Sendable {
    let name: String
    let label: String
    let plistPath: String
    let executablePath: String
    let workingDirectory: String
    let readinessURL: String
    let readinessIdentityKind: ProfileValidator.ReadinessIdentityKind
    let readinessIdentity: String
    let activityURL: String
    let openURL: String
    let description: String

    var rawInput: ProfileValidator.RawInput {
        ProfileValidator.RawInput(
            name: name,
            label: label,
            launchdDomain: .gui,
            plistPath: plistPath,
            executablePath: executablePath,
            workingDirectory: workingDirectory,
            readinessURLString: readinessURL,
            readinessIdentityKind: readinessIdentityKind,
            readinessIdentityValue: readinessIdentity,
            activityURLString: activityURL,
            openURLString: openURL,
            readinessTimeoutSeconds: 90,
            stopTimeoutSeconds: 30,
            description: description
        )
    }
}

enum ManagedServiceCatalog {
    static func load() throws -> [ManagedServiceDefinition] {
        guard let url = Bundle.module.url(forResource: "services", withExtension: "yaml")
            ?? Bundle.module.url(forResource: "services", withExtension: "yaml", subdirectory: "Resources")
            ?? Bundle.module.resourceURL?.appendingPathComponent("Resources/services.yaml")
            ?? Bundle.module.resourceURL?.appendingPathComponent("services.yaml") else {
            throw NSError(domain: "ManagedServiceCatalog", code: 1, userInfo: [NSLocalizedDescriptionKey: "services.yaml não encontrado nos recursos"])
        }
        let text = try String(contentsOf: url, encoding: .utf8)
        var sections: [(String, [String: String])] = []
        var current: (String, [String: String])?
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            if !line.hasPrefix(" "), trimmed.hasSuffix(":"), !trimmed.contains(" ") {
                if let current { sections.append(current) }
                current = (String(trimmed.dropLast()), [:])
                continue
            }
            guard let separator = trimmed.firstIndex(of: ":"), var section = current else { continue }
            let key = String(trimmed[..<separator]).trimmingCharacters(in: .whitespaces)
            var value = String(trimmed[trimmed.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
            if value.hasPrefix("\"") && value.hasSuffix("\"") { value = String(value.dropFirst().dropLast()) }
            section.1[key] = value
            current = section
        }
        if let current { sections.append(current) }
        return try sections.map { _, values in
            guard let name = values["name"], let label = values["label"], let plistPath = values["plist_path"],
                  let executablePath = values["executable_path"], let workingDirectory = values["working_directory"],
                  let readinessURL = values["readiness_url"], let readinessIdentity = values["readiness_identity"],
                  let openURL = values["open_url"], let description = values["description"] else {
                throw NSError(domain: "ManagedServiceCatalog", code: 2, userInfo: [NSLocalizedDescriptionKey: "Entrada incompleta em services.yaml"])
            }
            let kind: ProfileValidator.ReadinessIdentityKind = values["readiness_identity_kind"] == "jsonTopLevelKey" ? .jsonTopLevelKey : .bodyContains
            return ManagedServiceDefinition(name: name, label: label, plistPath: plistPath, executablePath: executablePath, workingDirectory: workingDirectory, readinessURL: readinessURL, readinessIdentityKind: kind, readinessIdentity: readinessIdentity, activityURL: values["activity_url"] ?? "", openURL: openURL, description: description)
        }
    }
}
