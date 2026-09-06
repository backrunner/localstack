import SwiftUI
import WidgetKit
import AppIntents
import LocalStackShared

public struct OpenLocalStackServiceIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open LocalStack Service"

    @Parameter(title: "Service ID")
    public var serviceID: String

    public init() { serviceID = "" }

    public init(serviceID: String) {
        self.serviceID = serviceID
    }

    public func perform() async throws -> some IntentResult {
        let url = URL(string: "localstack://service/\(serviceID)")!
        return .result(opensIntent: OpenURLIntent(url))
    }
}

public struct LocalStackWidgetEntry: TimelineEntry {
    public let date: Date
    public let snapshot: ServiceWidgetSnapshot

    public init(date: Date = .now, snapshot: ServiceWidgetSnapshot) {
        self.date = date
        self.snapshot = snapshot
    }
}

public struct LocalStackWidgetProvider: TimelineProvider {
    public init() {}

    public func placeholder(in context: Context) -> LocalStackWidgetEntry {
        LocalStackWidgetEntry(snapshot: ServiceWidgetSnapshot(services: []))
    }

    public func getSnapshot(in context: Context, completion: @escaping (LocalStackWidgetEntry) -> Void) {
        completion(LocalStackWidgetEntry(snapshot: WidgetSnapshotStore().load() ?? ServiceWidgetSnapshot(services: [])))
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<LocalStackWidgetEntry>) -> Void) {
        let snapshot = WidgetSnapshotStore().load() ?? ServiceWidgetSnapshot(services: [])
        let entry = LocalStackWidgetEntry(snapshot: snapshot)
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30))))
    }
}

public struct LocalStackWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LocalStackWidgetEntry
    private let mint = Color(red: 0.35, green: 0.85, blue: 0.67)

    public init(entry: LocalStackWidgetEntry) { self.entry = entry }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "square.3.layers.3d")
                    .foregroundStyle(mint)
                Text("LocalStack").font(.system(size: 13, weight: .semibold))
                Spacer(minLength: 0)
                Text(String(entry.snapshot.services.count))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            if entry.snapshot.services.isEmpty {
                Spacer(minLength: 0)
                Text("暂无本地服务").font(.system(size: 12, weight: .semibold))
                Text("启动本地网页服务后会自动显示。")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                ForEach(entry.snapshot.services.prefix(family == .systemSmall ? 2 : 3)) { service in
                    serviceRow(service)
                }
                Spacer(minLength: 0)
            }
        }
        .containerBackground(for: .widget) {
            Color(nsColor: .windowBackgroundColor)
        }
    }

    private func serviceRow(_ service: WidgetService) -> some View {
        Button(intent: OpenLocalStackServiceIntent(serviceID: service.id.uuidString)) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2).fill(service.health == .active ? mint : .orange).frame(width: 3, height: 25)
                VStack(alignment: .leading, spacing: 3) {
                    Text(service.displayName).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                    Text(service.url.host.map { "\($0):\(service.url.port ?? 80)" } ?? service.url.absoluteString)
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                if family == .systemMedium {
                    Image(systemName: "arrow.up.right").font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }.padding(.vertical, 3).contentShape(Rectangle())
        }
        .buttonStyle(.plain).foregroundStyle(.primary)
        .accessibilityLabel("\(service.displayName)，\(service.health == .active ? "在线" : "确认中")")
    }
}

public struct LocalStackWidgetConfiguration: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LocalStackWidget", provider: LocalStackWidgetProvider()) { entry in
            LocalStackWidgetView(entry: entry)
        }
        .configurationDisplayName("LocalStack")
        .description("查看当前可打开的本地开发服务")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
