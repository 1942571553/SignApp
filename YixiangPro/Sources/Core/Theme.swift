import SwiftUI
import UIKit

enum YTheme {
    static let background = Color(red: 0.972, green: 0.965, blue: 1.0)
    static let card = Color.white
    static let text = Color(red: 0.118, green: 0.106, blue: 0.180)
    static let muted = Color(red: 0.545, green: 0.525, blue: 0.627)
    static let soft = Color(red: 0.925, green: 0.910, blue: 0.980)
    static let border = Color(red: 0.914, green: 0.898, blue: 0.972)

    static let purple = Color(red: 0.486, green: 0.302, blue: 1.0)
    static let violet = Color(red: 0.659, green: 0.333, blue: 0.969)
    static let pink = Color(red: 0.957, green: 0.447, blue: 0.714)
    static let blue = Color(red: 0.365, green: 0.420, blue: 0.965)
    static let cyan = Color(red: 0.180, green: 0.800, blue: 0.820)
    static let green = Color(red: 0.129, green: 0.639, blue: 0.396)
    static let orange = Color(red: 0.961, green: 0.620, blue: 0.043)
    static let red = Color(red: 0.937, green: 0.267, blue: 0.267)

    static let gradient = LinearGradient(
        colors: [Color(red: 0.427, green: 0.357, blue: 1.0), violet, pink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let coolGradient = LinearGradient(
        colors: [Color(red: 0.353, green: 0.416, blue: 0.996), violet, cyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let softGradient = LinearGradient(
        colors: [purple.opacity(0.14), violet.opacity(0.10), pink.opacity(0.12)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let radius: CGFloat = 18
    static let largeRadius: CGFloat = 24
}

extension View {
    func yCard(_ padding: CGFloat = 14) -> some View {
        self
            .padding(padding)
            .background(YTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: YTheme.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: YTheme.radius, style: .continuous)
                    .stroke(YTheme.border, lineWidth: 0.8)
            )
    }
}

struct YSectionTitle: View {
    let title: String
    var subtitle: String? = nil
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(YTheme.text)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(YTheme.muted)
            }
            Spacer(minLength: 0)
            if let trailing {
                Text(trailing)
                    .font(.caption2)
                    .foregroundColor(YTheme.muted)
            }
        }
        .padding(.horizontal, 2)
    }
}

struct YGradientPill: View {
    let title: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.system(size: 10, weight: .semibold)) }
            Text(title).font(.caption.weight(.semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(YTheme.gradient)
        .clipShape(Capsule())
    }
}

struct YSoftPill: View {
    let title: String
    var color: Color = YTheme.purple
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.system(size: 9, weight: .semibold)) }
            Text(title).font(.caption2.weight(.semibold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(color.opacity(0.10))
        .clipShape(Capsule())
    }
}

struct YEmpty: View {
    let icon: String
    let title: String
    let message: String
    var action: (() -> Void)? = nil
    var actionTitle: String? = nil

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(YTheme.softGradient).frame(width: 86, height: 86)
                Image(systemName: icon).font(.system(size: 31, weight: .medium)).foregroundColor(YTheme.purple)
            }
            Text(title).font(.headline).foregroundColor(YTheme.text)
            Text(message)
                .font(.footnote)
                .foregroundColor(YTheme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            if let action, let actionTitle {
                Button(actionTitle, action: action)
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(YTheme.gradient)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 42)
    }
}

struct YRemoteIcon: View {
    let url: URL?
    let fallback: String
    var size: CGFloat = 58

    var body: some View {
        Group {
            if let url {
                if url.isFileURL, let image = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                } else {
                    AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        placeholder
                    }
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.23, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: size * 0.23, style: .continuous).stroke(YTheme.border, lineWidth: 0.8))
    }

    private var placeholder: some View {
        ZStack {
            YTheme.softGradient
            Text(String(fallback.prefix(1))).font(.system(size: size * 0.32, weight: .bold)).foregroundColor(YTheme.purple)
        }
    }
}

extension URL {
    static var yDocuments: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
