import FilmDomain
import SwiftUI

struct MediaRowView: View {
    let item: MediaItem
    var progress: PlaybackProgress?
    @ScaledMetric(relativeTo: .title2) private var iconWidth = 32

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: item.isDirectory ? "folder.fill" : "play.rectangle")
                .font(.title2)
                .foregroundStyle(item.isDirectory ? Color.accentColor : Color.secondary)
                .frame(width: iconWidth)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.isDirectory ? item.name : item.title)
                    .font(.body)
                    .lineLimit(2)

                if item.isDirectory {
                    Text("文件夹")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(item.fileExtension.uppercased())
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                        Text(details)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                if let progress, progress.canContinue, progress.duration > 0 {
                    ProgressView(value: progress.fraction)
                        .progressViewStyle(.linear)
                        .accessibilityHidden(true)
                }
            }

            Spacer(minLength: 4)

            if item.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            } else if progress?.isWatched == true {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.isDirectory ? item.name + "，文件夹" : item.title)
        .accessibilityValue(accessibilityDetail)
        .accessibilityIdentifier("media.row." + item.id)
    }

    private var details: String {
        if item.isDirectory { return "文件夹" }
        var parts: [String] = []
        if let size = item.size {
            parts.append(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
        }
        if let progress {
            if progress.isWatched {
                parts.append("已看")
            } else if progress.position > 0 {
                let position = PlaybackTimeLabel.string(progress.position)
                if progress.duration > 0 {
                    parts.append("已看 \(position) / \(PlaybackTimeLabel.string(progress.duration))")
                } else {
                    parts.append("已看 \(position)")
                }
            }
        }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private var accessibilityDetail: String {
        let format = item.fileExtension.uppercased()
        guard let progress else { return format + "，" + details }
        if progress.isWatched { return "已看完，" + format + "，" + details }
        if progress.duration > 0, progress.position > 0 {
            return "已观看 \(Int(progress.fraction * 100))%，" + details
        }
        return details
    }
}

enum PlaybackTimeLabel {
    static func string(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(min(seconds, Double(Int.max / 2)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        let secondsText = seconds < 10 ? "0\(seconds)" : "\(seconds)"
        if hours > 0 {
            let minutesText = minutes < 10 ? "0\(minutes)" : "\(minutes)"
            return "\(hours):\(minutesText):\(secondsText)"
        }
        return "\(minutes):\(secondsText)"
    }
}
