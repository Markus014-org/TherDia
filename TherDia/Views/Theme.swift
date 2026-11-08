import SwiftUI

enum TherDiaTheme {
    static let ink = Color(red: 0.13, green: 0.22, blue: 0.29)
    static let accent = Color(red: 0.92, green: 0.38, blue: 0.05)
    static let canvas = Color(red: 0.86, green: 0.87, blue: 0.89)
    static let navy = Color(red: 0.15, green: 0.16, blue: 0.19)

    static func quality(_ value: Wellbeing) -> Color {
        switch value {
        case .good: return Color(red: 0.13, green: 0.66, blue: 0.35)
        case .fairlyGood: return Color(red: 0.89, green: 0.74, blue: 0.17)
        case .fairlyBad: return Color(red: 0.96, green: 0.50, blue: 0.16)
        case .bad: return Color(red: 0.83, green: 0.22, blue: 0.24)
        case .veryBad: return Color(red: 0.43, green: 0.06, blue: 0.12)
        }
    }
}

struct QualityDot: View {
    let quality: Wellbeing
    var size: CGFloat = 15
    var body: some View {
        Circle().fill(TherDiaTheme.quality(quality))
            .frame(width: size, height: size)
            .accessibilityLabel("Tagesbefinden: \(quality.title)")
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content

    init(_ title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline).foregroundStyle(TherDiaTheme.ink)
                if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .background(.background, in: RoundedRectangle(cornerRadius: 19))
        .overlay(RoundedRectangle(cornerRadius: 19).strokeBorder(TherDiaTheme.accent.opacity(0.08)))
    }
}

struct PrimaryAction: View {
    let title: String
    var disabled = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 13)
        }
        .buttonStyle(.borderedProminent)
        .tint(TherDiaTheme.accent)
        .disabled(disabled)
    }
}

extension Date {
    var diaryHeading: String {
        formatted(.dateTime.weekday(.wide).day().month(.wide).year().locale(Locale(identifier: "de_DE")))
    }
}

struct WellbeingControl: View {
    @Binding var value: Wellbeing
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                QualityDot(quality: value, size: 22)
                Text(value.title).font(.headline)
            }
            Slider(value: Binding(
                get: { Double(value.rawValue) },
                set: { value = Wellbeing(rawValue: Int($0.rounded())) ?? .fairlyGood }
            ), in: 0...4, step: 1)
                .tint(TherDiaTheme.quality(value))
                .accessibilityLabel(label)
            HStack {
                ForEach(Wellbeing.allCases) { quality in
                    Button {
                        value = quality
                    } label: {
                        QualityDot(quality: quality, size: value == quality ? 22 : 14)
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(quality.title)
                }
            }
            HStack {
                Text("Gut")
                Spacer()
                Text("Extrem schlecht")
            }.font(.caption).foregroundStyle(.secondary)
        }
    }
}
