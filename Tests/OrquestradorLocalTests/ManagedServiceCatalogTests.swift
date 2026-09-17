import XCTest
@testable import OrquestradorLocal

final class ManagedServiceCatalogTests: XCTestCase {
    func testBundledCatalogContainsRequiredServicesWithoutShellCommands() throws {
        let definitions = try ManagedServiceCatalog.load()
        XCTAssertEqual(Set(definitions.map(\.label)), Set([
            "com.joaopaulo.screenpipe",
            "com.joaopaulo.segunda-mente",
            "com.joaopaulo.sm-graficos",
            "local.comfyui",
            "com.joaopaulo.mflux-studio",
            "com.joaopaulo.anythingllm"
        ]))
        XCTAssertTrue(definitions.allSatisfy { !$0.rawInput.name.contains(";") })
        XCTAssertEqual(definitions.first(where: { $0.label == "local.comfyui" })?.rawInput.readinessIdentityKind, .jsonTopLevelKey)
        XCTAssertEqual(definitions.first(where: { $0.label == "local.comfyui" })?.rawInput.activityURLString, "http://127.0.0.1:8188/queue")
        XCTAssertEqual(definitions.first(where: { $0.label == "com.joaopaulo.sm-graficos" })?.rawInput.readinessURLString, "http://127.0.0.1:3011/")
        XCTAssertEqual(definitions.first(where: { $0.label == "com.joaopaulo.sm-graficos" })?.rawInput.readinessIdentityValue, "<div id=")
        XCTAssertEqual(definitions.first(where: { $0.label == "com.joaopaulo.screenpipe" })?.rawInput.readinessURLString, "http://127.0.0.1:3030/health")
    }

    func testExistingLaunchAgentsSatisfyTheDeclaredContracts() throws {
        for definition in try ManagedServiceCatalog.load() {
            XCTAssertNoThrow(try ProfileValidator.validate(definition.rawInput), definition.label)
        }
    }
}
