#!/usr/bin/env swift
/// Deterministic runtime probe: validates named color resolution in a packaged bundle.
/// Unambiguous contract:
///   - App bundle path: checks nested SwiftPM bundle inside Contents/Resources
///   - Nested SwiftPM bundle: checks bundle's own Resources (SwiftPM uses non-standard layout)
/// Missing compiled assets, missing color, invalid path, or failed appearance resolution → exit nonzero.
/// NEVER modifies the actual delivered package.

import Foundation
import AppKit

// Colors actually used by the app's SwiftUI views at runtime
let usedColorNames: [String] = [
    "CardSurface",
    "OrqDanger",
    "OrqDangerText",
    "OrqDangerBg",
    "OrqGoldText",
    "OrqGoldBg",
    "OrqGoldAccent",
    "OrqGreenAccent",
    "OrqMuted",
    "OrqGreenText",
    "OrqExternalText",
    "OrqGreenBg",
    "OrqNeutralBg",
    "OrqExternalBg",
    "OrqExternal",
]

struct ProbeResult {
    let name: String
    let bundleLabel: String
    let resolved: Bool
    let rgba: String?
    let error: String?
}

func rgbaString(_ color: NSColor) -> String? {
    guard let rgb = color.usingColorSpace(.deviceRGB) else { return nil }
    let r = Int(rgb.redComponent * 255)
    let g = Int(rgb.greenComponent * 255)
    let b = Int(rgb.blueComponent * 255)
    let a = Int(rgb.alphaComponent * 255)
    return a < 255 ? "RGBA(\(r),\(g),\(b),\(a))" : "RGB(\(r),\(g),\(b))"
}

/// Detect bundle type and find the right paths for probing
/// SwiftPM nested bundles have non-standard layout: bundle/Resources/ (no Contents/)
/// Standard macOS bundles: bundle/Contents/Resources/
func detectBundleInfo(_ bundlePath: String) -> (isAppBundle: Bool, bundleForProbing: String, resourcesPath: String) {
    let fm = FileManager.default

    // Check if this is an app bundle by looking for Contents/Info.plist
    let appInfoPlist = bundlePath + "/Contents/Info.plist"
    if fm.fileExists(atPath: appInfoPlist) {
        // App bundle - find nested SwiftPM bundle
        let nestedBundlePath = bundlePath + "/Contents/Resources/OrquestradorLocal_OrquestradorLocal.bundle"
        if fm.fileExists(atPath: nestedBundlePath) {
            // SwiftPM nested bundles: bundle/Resources/ (no Contents/)
            let nestedResources = nestedBundlePath + "/Resources"
            return (true, nestedBundlePath, nestedResources)
        }
    }

    // Check for SwiftPM-style bundle: bundle/Resources/Info.plist
    let swiftpmInfoPlist = bundlePath + "/Resources/Info.plist"
    if fm.fileExists(atPath: swiftpmInfoPlist) {
        return (false, bundlePath, bundlePath + "/Resources")
    }

    // Fallback: assume bundlePath is already the Resources directory or use standard layout
    let standardResources = bundlePath + "/Contents/Resources"
    if fm.fileExists(atPath: standardResources) {
        return (false, bundlePath, standardResources)
    }

    // Last resort
    return (false, bundlePath, bundlePath)
}

/// Examine the on-disk structure
func examineBundleStructure(_ info: (isAppBundle: Bool, bundleForProbing: String, resourcesPath: String)) {
    let fm = FileManager.default
    let (isApp, bundleForProbing, resourcesPath) = info

    print("Bundle path: \(bundleForProbing)")
    print("Bundle type: \(isApp ? "app-bundle (nested SwiftPM inside)" : "SwiftPM-nested-bundle")")
    print("Resources path: \(resourcesPath)")

    // Check Assets.car
    let carPath = resourcesPath + "/Assets.car"
    if fm.fileExists(atPath: carPath) {
        let size = (try? fm.attributesOfItem(atPath: carPath)[.size] as? Int64) ?? 0
        print("  Assets.car: PRESENT (\(size) bytes)")
    } else {
        print("  Assets.car: MISSING")
    }

    // Check for raw Assets.xcassets
    let xcassetsPath = resourcesPath + "/Assets.xcassets"
    if fm.fileExists(atPath: xcassetsPath) {
        var totalSize: Int64 = 0
        if let enumerator = fm.enumerator(atPath: xcassetsPath) {
            while let file = enumerator.nextObject() as? String {
                let full = xcassetsPath + "/" + file
                if let attrs = try? fm.attributesOfItem(atPath: full), let size = attrs[.size] as? Int64 {
                    totalSize += size
                }
            }
        }
        print("  Assets.xcassets: PRESENT (raw, \(totalSize) bytes total)")
    } else {
        print("  Assets.xcassets: MISSING")
    }
}

func probeNamedColor(_ name: String, bundle: Bundle, bundleLabel: String) -> ProbeResult {
    if let color = NSColor(named: name, bundle: bundle) {
        return ProbeResult(name: name, bundleLabel: bundleLabel, resolved: true, rgba: rgbaString(color), error: nil)
    }

    // Diagnose why it failed
    let bundlePath = bundle.bundlePath
    // Try SwiftPM layout first
    let csPathSwiftPM = bundlePath + "/Resources/\(name).colorset/Contents.json"
    // Then standard layout
    let csPathStandard = bundlePath + "/Contents/Resources/\(name).colorset/Contents.json"

    if FileManager.default.fileExists(atPath: csPathSwiftPM) || FileManager.default.fileExists(atPath: csPathStandard) {
        return ProbeResult(
            name: name,
            bundleLabel: bundleLabel,
            resolved: false,
            rgba: nil,
            error: "Raw .colorset exists but NSColor(named:) returned nil — Assets.car not compiled or appearance mismatch"
        )
    }

    return ProbeResult(
        name: name,
        bundleLabel: bundleLabel,
        resolved: false,
        rgba: nil,
        error: "Not found in bundle (no .colorset, no compiled Assets.car)"
    )
}

// --- Main ---
let bundlePath: String
if CommandLine.argc > 1 {
    bundlePath = CommandLine.arguments[1]
} else {
    bundlePath = ""
}

print("=== Asset Catalog Structural Examination ===")

if bundlePath.isEmpty {
    print("No bundle path provided — using Bundle.main")
    let mainBundle = Bundle.main
    let info = detectBundleInfo(mainBundle.bundlePath)
    examineBundleStructure(info)

    print("\n=== Named Color Resolution Probe ===")
    var allResults: [ProbeResult] = []
    for name in usedColorNames {
        let result = probeNamedColor(name, bundle: mainBundle, bundleLabel: "main-bundle")
        let prefix = result.resolved ? "  [OK]  " : "  [FAIL] "
        let detail = result.resolved ? (result.rgba ?? "resolved") : (result.error ?? "nil")
        print("\(prefix)\(name): \(detail)")
        allResults.append(result)
    }

    print("\n=== Summary ===")
    let resolved = allResults.filter { $0.resolved }.count
    let failures = allResults.filter { !$0.resolved }
    print("Colors resolved: \(resolved)/\(allResults.count)")

    if failures.isEmpty {
        print("VERDICT: ALL named colors resolve correctly")
        exit(0)
    } else {
        print("\nCRITICAL: \(failures.count) named color(s) failed:")
        for f in failures {
            print("  \(f.name): \(f.error ?? "nil")")
        }
        exit(1)
    }
} else {
    // Probe the provided path
    let fm = FileManager.default
    guard fm.fileExists(atPath: bundlePath) else {
        print("ERROR: Bundle path does not exist: \(bundlePath)")
        exit(1)
    }

    let info = detectBundleInfo(bundlePath)
    let (isApp, bundleForProbing, resourcesPath) = info

    examineBundleStructure(info)

    // Load the bundle for color probing
    guard let probeBundle = Bundle(path: bundleForProbing) else {
        print("ERROR: Cannot load bundle at: \(bundleForProbing)")
        exit(1)
    }

    print("\n=== Named Color Resolution Probe ===")
    print("  [Bundle: \(bundleForProbing)]")

    var allResults: [ProbeResult] = []
    let bundleLabel = bundleForProbing

    for name in usedColorNames {
        let result = probeNamedColor(name, bundle: probeBundle, bundleLabel: bundleLabel)
        let prefix = result.resolved ? "  [OK]  " : "  [FAIL] "
        let detail = result.resolved ? (result.rgba ?? "resolved") : (result.error ?? "nil")
        print("\(prefix)\(name): \(detail)")
        allResults.append(result)
    }

    print("\n=== Summary ===")
    let resolved = allResults.filter { $0.resolved }.count
    let failures = allResults.filter { !$0.resolved }
    print("Colors resolved: \(resolved)/\(allResults.count)")

    // Final verdict: check both color resolution AND Assets.car presence
    let carPath = resourcesPath + "/Assets.car"
    let hasAssetsCar = fm.fileExists(atPath: carPath)

    if failures.isEmpty && hasAssetsCar {
        print("VERDICT: ALL named colors resolve correctly, Assets.car present")
        exit(0)
    } else if failures.isEmpty && !hasAssetsCar {
        print("WARNING: All colors resolved but Assets.car is missing from bundle")
        print("VERDICT: FAIL — Assets.car missing")
        exit(1)
    } else {
        print("\nCRITICAL: \(failures.count) named color(s) failed:")
        for f in failures {
            print("  \(f.name): \(f.error ?? "nil")")
        }
        if !hasAssetsCar {
            print("Assets.car: MISSING")
        }
        print("VERDICT: FAIL — color resolution failed or Assets.car missing")
        exit(1)
    }
}
