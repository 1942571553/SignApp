import SwiftUI
import UIKit
import QuickLook
import UniformTypeIdentifiers

struct FileEntry: Identifiable, Hashable {
    var id: String { path }
    let url: URL
    let name: String
    let isDirectory: Bool
    let size: Int64
    let modified: Date

    var icon: String {
        if isDirectory { return "folder.fill" }
        switch url.pathExtension.lowercased() {
        case "ipa": return "shippingbox.fill"
        case "png", "jpg", "jpeg", "heic": return "photo.fill"
        case "mp4", "mov": return "video.fill"
        case "zip": return "doc.zipper"
        case "plist": return "list.bullet.rectangle"
        default: return "doc.fill"
        }
    }

    var tint: Color {
        if isDirectory { return YTheme.purple }
        switch url.pathExtension.lowercased() {
        case "ipa": return YTheme.blue
        case "png", "jpg", "jpeg", "heic": return YTheme.pink
        case "mp4", "mov": return YTheme.orange
        default: return YTheme.muted
        }
    }

    var sizeText: String {
        isDirectory ? "—" : ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    static func read(_ directory: URL) -> [FileEntry] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []
        return urls.map { url in
            let values = try? url.resourceValues(forKeys: Set(keys))
            return FileEntry(
                url: url,
                name: url.lastPathComponent,
                isDirectory: values?.isDirectory ?? false,
                size: Int64(values?.fileSize ?? 0),
                modified: values?.contentModificationDate ?? Date.distantPast
            )
        }
    }
}

struct FilesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showImporter = false
    @State private var showNewFolder = false
    @State private var folderName = ""
    @State private var selectedFile: URL?
    @State private var sort: FileSort = .name

    enum FileSort: String, CaseIterable {
        case name = "名称", size = "大小", date = "修改时间"
    }

    private var folders: [FileEntry] {
        let names = ["Default", "下载项", "导入的文件", "导入的照片", "导入的视频"]
        return names.map { name in
            let url = YFiles.root.appendingPathComponent(name, isDirectory: true)
            if !FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            }
            let entries = FileEntry.read(url)
            let size = entries.reduce(Int64(0)) { $0 + $1.size }
            return FileEntry(url: url, name: name, isDirectory: true, size: size, modified: (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date())
        }
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    header
                    tableHeader
                    VStack(spacing: 8) {
                        ForEach(folders) { folder in
                            NavigationLink(destination: FileBrowserView(directory: folder.url, title: folder.name)) {
                                fileRow(folder)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    quickFolders
                }
                .padding(16)
                .padding(.bottom, 30)
            }
            .background(YTheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .overlay(alignment: .bottomTrailing) {
                Menu {
                    Button { showNewFolder = true } label: { Label("新建文件夹", systemImage: "folder.badge.plus") }
                    Button { showImporter = true } label: { Label("导入文件", systemImage: "doc.badge.plus") }
                    Button { model.refreshStore() } label: { Label("刷新", systemImage: "arrow.clockwise") }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 54, height: 54)
                        .background(YTheme.gradient)
                        .clipShape(Circle())
                        .shadow(color: YTheme.purple.opacity(0.3), radius: 10, y: 5)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 18)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(item: Binding(get: { selectedFile.map(FileURL.init) }, set: { _ in selectedFile = nil })) { item in
            QuickLookView(url: item.url)
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.data], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                let folder = YFiles.root.appendingPathComponent("导入的文件", isDirectory: true)
                for url in urls {
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    try? FileManager.default.copyItem(at: url, to: folder.appendingPathComponent(url.lastPathComponent))
                }
            }
        }
        .alert("新建文件夹", isPresented: $showNewFolder) {
            TextField("文件夹名称", text: $folderName)
            Button("创建") {
                let name = folderName.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    try? FileManager.default.createDirectory(at: YFiles.root.appendingPathComponent(name, isDirectory: true), withIntermediateDirectories: true)
                }
                folderName = ""
            }
            Button("取消", role: .cancel) { folderName = "" }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("文件").font(.system(size: 26, weight: .heavy)).foregroundColor(YTheme.text)
                Text("本机文件 · IPA · 照片 · 视频").font(.caption).foregroundColor(YTheme.muted)
            }
            Spacer()
            Image(systemName: "folder.fill")
                .font(.system(size: 26)).foregroundColor(YTheme.purple)
                .frame(width: 52, height: 52).background(YTheme.softGradient).clipShape(Circle())
        }
    }

    private var tableHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder.fill").foregroundColor(YTheme.muted).frame(width: 34)
            Text("名称").frame(maxWidth: .infinity, alignment: .leading)
            Text("大小").frame(width: 58, alignment: .trailing)
            Text("修改时间").frame(width: 70, alignment: .trailing)
        }
        .font(.system(size: 9.5, weight: .medium))
        .foregroundColor(YTheme.muted)
        .padding(.horizontal, 12)
    }

    private func fileRow(_ file: FileEntry) -> some View {
        HStack(spacing: 10) {
            Image(systemName: file.icon)
                .font(.system(size: 18))
                .foregroundColor(file.tint)
                .frame(width: 34, height: 34)
                .background(file.tint.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name).font(.subheadline.weight(.medium)).foregroundColor(YTheme.text).lineLimit(1)
                Text(file.isDirectory ? "文件夹" : file.url.pathExtension.uppercased())
                    .font(.system(size: 9)).foregroundColor(YTheme.muted)
            }
            Spacer()
            Text(file.sizeText).font(.system(size: 9.5)).foregroundColor(YTheme.muted).frame(width: 58, alignment: .trailing)
            Text(file.modified.formatted(date: .numeric, time: .omitted))
                .font(.system(size: 9)).foregroundColor(YTheme.muted).frame(width: 70, alignment: .trailing)
        }
        .padding(.horizontal, 10).padding(.vertical, 9)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var quickFolders: some View {
        VStack(alignment: .leading, spacing: 10) {
            YSectionTitle(title: "常用位置", subtitle: "App 沙盒")
            HStack(spacing: 10) {
                quick("已签名", "checkmark.seal.fill", YTheme.green) { FileBrowserView(directory: YFiles.signed, title: "已签名") }
                quick("未签名", "shippingbox.fill", YTheme.blue) { FileBrowserView(directory: YFiles.unsigned, title: "未签名") }
                quick("证书", "lock.shield.fill", YTheme.violet) { FileBrowserView(directory: YFiles.certs, title: "证书") }
            }
        }
    }

    private func quick<Destination: View>(_ title: String, _ icon: String, _ color: Color, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink(destination: destination()) {
            VStack(spacing: 7) {
                Image(systemName: icon).font(.system(size: 20)).foregroundColor(color)
                Text(title).font(.caption.weight(.medium)).foregroundColor(YTheme.text)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FileURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct FileBrowserView: View {
    let directory: URL
    let title: String
    @State private var entries: [FileEntry] = []
    @State private var sort: FilesView.FileSort = .name
    @State private var selectedFile: URL?
    @State private var showShare = false

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                HStack {
                    Text("\(entries.count) 项").font(.caption).foregroundColor(YTheme.muted)
                    Spacer()
                    Menu {
                        ForEach(FilesView.FileSort.allCases, id: \.self) { value in
                            Button(value.rawValue) { sort = value; reload() }
                        }
                    } label: {
                        Label("排序：\(sort.rawValue)", systemImage: "arrow.up.arrow.down")
                            .font(.caption).foregroundColor(YTheme.purple)
                    }
                }
                .padding(.horizontal, 4)
                if entries.isEmpty {
                    YEmpty(icon: "folder", title: "文件夹为空", message: "点击右上角或返回首页导入文件。")
                } else {
                    ForEach(entries) { entry in
                        if entry.isDirectory {
                            NavigationLink(destination: FileBrowserView(directory: entry.url, title: entry.name)) {
                                row(entry)
                            }.buttonStyle(PlainButtonStyle())
                        } else {
                            Button { selectedFile = entry.url } label: { row(entry) }.buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(YTheme.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(false)
        .onAppear(perform: reload)
        .sheet(item: Binding(get: { selectedFile.map(FileURL.init) }, set: { _ in selectedFile = nil })) { item in
            QuickLookView(url: item.url)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showShare = true } label: { Image(systemName: "square.and.arrow.up") }
            }
        }
        .sheet(isPresented: $showShare) { ShareSheet(items: [directory]) }
    }

    private func row(_ entry: FileEntry) -> some View {
        HStack(spacing: 10) {
            Image(systemName: entry.icon).foregroundColor(entry.tint).frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name).font(.subheadline).foregroundColor(YTheme.text).lineLimit(1)
                Text(entry.sizeText).font(.system(size: 9)).foregroundColor(YTheme.muted)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption2).foregroundColor(YTheme.muted.opacity(0.6))
        }
        .padding(10).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 11))
    }

    private func reload() {
        var list = FileEntry.read(directory)
        switch sort {
        case .name: list.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .size: list.sort { $0.size > $1.size }
        case .date: list.sort { $0.modified > $1.modified }
        }
        entries = list.filter { !$0.name.hasSuffix(".json") }
    }
}

struct QuickLookView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { url as NSURL }
    }
}
