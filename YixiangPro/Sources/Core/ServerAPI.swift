import UIKit
import Foundation

final class APIClient {
    static let shared = APIClient()
    static let baseURL = URL(string: "https://sign.yixsc.cn")!

    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 180
        session = URLSession(configuration: config)
    }

    var deviceID: String {
        let key = "yixiang.device.id"
        if let value = UserDefaults.standard.string(forKey: key) { return value }
        let value = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(value, forKey: key)
        return value
    }

    var token: String? {
        get { UserDefaults.standard.string(forKey: "yixiang.auth.token") }
        set { UserDefaults.standard.set(newValue, forKey: "yixiang.auth.token") }
    }

    func fetchConfig(completion: @escaping (Result<ClientConfig, Error>) -> Void) {
        var request = URLRequest(url: APIClient.baseURL.appendingPathComponent("api/client/config"))
        request.httpMethod = "GET"
        applyHeaders(&request)
        session.dataTask(with: request) { data, response, error in
            self.handle(data: data, response: response, error: error, completion: completion)
        }.resume()
    }

    func login(username: String, password: String, completion: @escaping (Result<AuthResponse, Error>) -> Void) {
        post(path: "api/auth/login", body: ["username": username, "password": password], completion: completion)
    }

    func register(username: String, password: String, completion: @escaping (Result<AuthResponse, Error>) -> Void) {
        post(path: "api/auth/register", body: ["username": username, "password": password], completion: completion)
    }

    func redeem(code: String, completion: @escaping (Result<RedeemResponse, Error>) -> Void) {
        post(path: "api/cards/redeem", body: ["code": code, "deviceId": deviceID], completion: completion)
    }

    func fetchRepository(_ url: URL, completion: @escaping (Result<Repository, Error>) -> Void) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("YixiangPro/2.0", forHTTPHeaderField: "User-Agent")
        session.dataTask(with: request) { data, response, error in
            self.handle(data: data, response: response, error: error, completion: completion)
        }.resume()
    }

    func uploadInstall(
        ipaURL: URL,
        app: SignedApp,
        progress: ((Double) -> Void)? = nil,
        completion: @escaping (Result<InstallUploadResponse, Error>) -> Void
    ) {
        var request = URLRequest(url: APIClient.baseURL.appendingPathComponent("api/install/upload"))
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue(app.name.addingPercentEncoding(withAllowedCharacters: .urlHeaderAllowed) ?? "App", forHTTPHeaderField: "X-App-Name")
        request.setValue(app.bundleID, forHTTPHeaderField: "X-Bundle-ID")
        request.setValue(app.version, forHTTPHeaderField: "X-App-Version")
        applyHeaders(&request)

        let task = session.uploadTask(with: request, fromFile: ipaURL) { data, response, error in
            self.handle(data: data, response: response, error: error, completion: completion)
        }
        task.resume()

        _ = progress
    }

    private func post<T: Decodable>(path: String, body: [String: Any], completion: @escaping (Result<T, Error>) -> Void) {
        var request = URLRequest(url: APIClient.baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyHeaders(&request)
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        session.dataTask(with: request) { data, response, error in
            self.handle(data: data, response: response, error: error, completion: completion)
        }.resume()
    }

    private func applyHeaders(_ request: inout URLRequest) {
        request.setValue(deviceID, forHTTPHeaderField: "X-Device-ID")
        request.setValue("YixiangPro/2.0", forHTTPHeaderField: "User-Agent")
        if let token = token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func handle<T: Decodable>(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        if let error = error {
            DispatchQueue.main.async { completion(.failure(error)) }
            return
        }
        guard let http = response as? HTTPURLResponse, let data = data else {
            DispatchQueue.main.async { completion(.failure(APIError(message: "服务器没有返回数据"))) }
            return
        }
        if !(200...299).contains(http.statusCode) {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
            DispatchQueue.main.async { completion(.failure(APIError(message: message ?? "请求失败 (\(http.statusCode))"))) }
            return
        }
        do {
            let value = try decoder.decode(T.self, from: data)
            DispatchQueue.main.async { completion(.success(value)) }
        } catch {
            DispatchQueue.main.async { completion(.failure(APIError(message: "数据解析失败：\(error.localizedDescription)"))) }
        }
    }
}

struct APIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private extension CharacterSet {
    static let urlHeaderAllowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
}
