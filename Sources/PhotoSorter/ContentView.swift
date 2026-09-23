import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var model = SortViewModel()
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            folderRow
            sortButton
            statusBar
            logView
        }
        .frame(minWidth: 560, minHeight: 420)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var folderRow: some View {
        HStack(spacing: 8) {
            Text("Folder:")
                .foregroundStyle(.secondary)
            TextField("Path to your photos folder", text: $model.folderPath)
                .textFieldStyle(.roundedBorder)
                .disabled(model.isSorting)
            Button("Browse…", action: browse)
                .disabled(model.isSorting)
        }
        .padding(12)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isDropTargeted ? Color.accentColor : .clear, lineWidth: 2)
                .padding(4)
        )
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
    }

    private var sortButton: some View {
        Button(action: model.startSort) {
            Text("Sort Photos")
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .tint(.accentColor)
        .disabled(model.isSorting)
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    private var statusBar: some View {
        VStack(spacing: 6) {
            Text(model.statusText)
                .font(.system(size: 12))
                .frame(maxWidth: .infinity, alignment: .leading)
            if model.isSorting && model.progressTotal > 0 {
                ProgressView(value: Double(model.progressCurrent), total: Double(model.progressTotal))
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var logView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(model.lines) { line in
                        Text(line.text)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(color(for: line.tag))
                            .fontWeight(line.tag == .done ? .bold : .regular)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(line.id)
                    }
                }
                .padding(8)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .onChange(of: model.lines.count) { _, _ in
                if let last = model.lines.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private func color(for tag: LogTag) -> Color {
        switch tag {
        case .plain: return .primary
        case .folder: return .accentColor
        case .skip: return .secondary
        case .err: return .red
        case .warn: return .orange
        case .done: return .green
        }
    }

    private func browse() {
        let panel = NSOpenPanel()
        panel.title = "Select photos folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if !model.folderPath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: model.folderPath)
        }
        if panel.runModal() == .OK, let url = panel.url {
            model.folderPath = url.path
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { return }
            DispatchQueue.main.async {
                model.folderPath = url.path
            }
        }
        return true
    }
}
