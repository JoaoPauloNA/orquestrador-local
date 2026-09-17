import SwiftUI

/// State badge using corrected contrast colors that pass WCAG 2.1 AA.
/// Text colors are the dark variants of each semantic color;
/// #059669 and #d97706 are NOT used as text — only #047857 and #92400e respectively.
struct StateBadgeView: View {
    let state: ServiceLifecycleState

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: state.sfSymbol)
                .font(.caption2)
                .foregroundStyle(iconColor)
            Text(state.label)
                .font(.caption2.bold())
                .foregroundStyle(textColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(bgColor))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Estado: \(state.label)")
    }

    // Text colors — all pass WCAG 2.1 AA (≥4.5:1) against their backgrounds
    private var textColor: Color {
        switch state {
        case .ready:    return Color("OrqGreenText")    // #047857 on #ecfdf5 = 5.2:1 ✓
        case .starting,
             .stopping: return Color("OrqGoldText")     // #92400e on #fef3c7 = 6.4:1 ✓
        case .stopped:  return Color("OrqMuted")        // #475569 on #f1f5f9 = 6.9:1 ✓
        case .error:    return Color("OrqDangerText")   // #991b1b on #fef2f2 = 6.1:1 ✓
        case .external: return Color("OrqExternalText") // #075985 on #f0f9ff = 5.5:1 ✓
        case .unknown:  return Color("OrqMuted")        // same as stopped
        }
    }

    // Icon colors — used decoratively (larger target, can use lighter variants)
    private var iconColor: Color {
        switch state {
        case .ready:    return Color("OrqGreenAccent")  // #059669 as icon accent
        case .starting,
             .stopping: return Color("OrqGoldAccent")   // #d97706 as icon accent
        case .stopped:  return Color("OrqMuted")
        case .error:    return Color("OrqDanger")
        case .external: return Color("OrqExternal")
        case .unknown:  return Color("OrqMuted")
        }
    }

    private var bgColor: Color {
        switch state {
        case .ready:    return Color("OrqGreenBg")
        case .starting,
             .stopping: return Color("OrqGoldBg")
        case .stopped:  return Color("OrqNeutralBg")
        case .error:    return Color("OrqDangerBg")
        case .external: return Color("OrqExternalBg")
        case .unknown:  return Color("OrqNeutralBg")
        }
    }
}
