import Foundation
import SwiftUI

struct DownloadItem: Identifiable, Hashable {
    enum State: String {
        case waiting, downloading, completed, failed
    }
    var id: String
    var name: String
    var bundleID: String
    var iconURL: URL?
    var sourceName: String
    var progress: Double
    var state: State
    var localPath: String?
    var error: String?
}

final class DownloadManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    static let shared = DownloadManager()

    @Published var items: [DownloadItem] = []
    private var session: URLSession!
    private var tasks: [Int: String] = [:]

    private override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 300
        session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
    }

    func start(_ item: StoreItem) {
        guard let url = item.app.downloadLink else { return }
        let id = UUID().uuidString
        let record = DownloadItem(
            id: id,
            name: item.app.displayName,
            bundleID: item.app.bundleID,
            iconURL: item.app.iconLink,
            sourceName: item.source.name,
            progress: 0,
            state: .waiting,
            localPath: nil,
            error: nil
        )
        items.insert(record, at: 0)
        let task = session.downloadTask(with: url)
        tasks[task.taskIdentifier] = id
        task.resume()
    }

    func remove(_ item: DownloadItem) {
        items.removeAll { $0.id == item.id }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let id = tasks[downloadTask.taskIdentifier], let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].state = .downloading
        if totalBytesExpectedToWrite > 0 {
            items[index].progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let id = tasks[downloadTask.taskIdentifier], let index = items.firstIndex(where: { $0.id == id }) else { return }
        let folder = YFiles.unsigned.appendingPathComponent(id, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let target = folder.appendingPathComponent("download.ipa")
            try? FileManager.default.removeItem(at: target)
            try FileManager.default.moveItem(at: location, to: target)
            items[index].progress = 1
            items[index].localPath = target.path
            AppModel.shared.importIPA(target) { ok, error in
                if ok {
                    self.items[index].state = .completed
                } else {
                    self.items[index].state = .failed
                    self.items[index].error = error
                }
            }
        } catch {
            items[index].state = .failed
            items[index].error = error.localizedDescription
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error, let id = tasks[task.taskIdentifier], let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].state = .failed
        items[index].error = error.localizedDescription
    }
}
