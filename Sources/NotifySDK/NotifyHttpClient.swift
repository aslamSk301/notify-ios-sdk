import Foundation

internal final class NotifyHttpClient: Sendable {
    private let config: NotifyConfig
    private let logger: NotifyLogger
    private let session: URLSession

    init(config: NotifyConfig, logger: NotifyLogger) {
        self.config = config
        self.logger = logger
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = config.requestTimeoutMs / 1000.0
        sessionConfig.timeoutIntervalForResource = config.requestTimeoutMs / 1000.0
        self.session = URLSession(configuration: sessionConfig)
    }

    /// POST /api/device/register
    func registerDevice(_ payload: RegisterPayload) async throws {
        let endpoint = "\(config.baseUrl)/api/device/register"
        let encoder = JSONEncoder()
        let bodyData = try encoder.encode(payload)
        
        _ = try await postWithRetry(url: endpoint, bodyData: bodyData, operation: "registerDevice")
    }

    /// POST /api/topics/subscribe
    func subscribeToTopic(appId: String, apiKey: String, fcmToken: String, topic: String) async throws {
        let endpoint = "\(config.baseUrl)/api/topics/subscribe"
        let body: [String: String] = [
            "appId": appId,
            "apiKey": apiKey,
            "fcmToken": fcmToken,
            "topic": topic
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        _ = try await postWithRetry(url: endpoint, bodyData: bodyData, operation: "subscribeToTopic")
    }

    /// POST /api/topics/unsubscribe
    func unsubscribeFromTopic(appId: String, apiKey: String, fcmToken: String, topic: String) async throws {
        let endpoint = "\(config.baseUrl)/api/topics/unsubscribe"
        let body: [String: String] = [
            "appId": appId,
            "apiKey": apiKey,
            "fcmToken": fcmToken,
            "topic": topic
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        _ = try await postWithRetry(url: endpoint, bodyData: bodyData, operation: "unsubscribeFromTopic")
    }

    /// GET /api/topics?appId=...&apiKey=...
    func fetchTopics(appId: String, apiKey: String) async throws -> [NotifyTopic] {
        var components = URLComponents(string: "\(config.baseUrl)/api/topics")
        components?.queryItems = [
            URLQueryItem(name: "appId", value: appId),
            URLQueryItem(name: "apiKey", value: apiKey)
        ]
        
        guard let url = components?.url else {
            throw NotifyError.invalidResponse("Invalid topic URL endpoint")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("ios", forHTTPHeaderField: "X-SDK-Platform")
        request.setValue("1.0.0", forHTTPHeaderField: "X-SDK-Version")

        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NotifyError.networkError("Invalid URL response", statusCode: nil)
        }

        if httpResponse.statusCode == 401 {
            throw NotifyError.authError("Invalid appId or apiKey")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NotifyError.networkError("HTTP \(httpResponse.statusCode)", statusCode: httpResponse.statusCode)
        }

        struct TopicsResponse: Codable {
            let topics: [NotifyTopic]?
        }

        let decoded = try JSONDecoder().decode(TopicsResponse.self, from: data)
        return decoded.topics ?? []
    }

    // MARK: - Internal Retry Logic

    private func postWithRetry(url: String, bodyData: Data, operation: String) async throws -> [String: Any] {
        guard let requestUrl = URL(string: url) else {
            throw NotifyError.invalidResponse("Invalid URL string: \(url)")
        }

        var attempt = 0
        var lastError: Error?

        while attempt < config.maxRetries {
            attempt += 1
            logger.debug("\(operation) attempt \(attempt) -> \(url)")

            var request = URLRequest(url: requestUrl)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("ios", forHTTPHeaderField: "X-SDK-Platform")
            request.setValue("1.0.0", forHTTPHeaderField: "X-SDK-Version")
            request.httpBody = bodyData

            do {
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NotifyError.networkError("Non-HTTP URL response", statusCode: nil)
                }

                if httpResponse.statusCode == 401 {
                    throw NotifyError.authError("Invalid appId or apiKey")
                }

                // If 4xx (except 429 rate limit), do not retry
                if (400...499).contains(httpResponse.statusCode) && httpResponse.statusCode != 429 {
                    let serverMsg = parseErrorMessage(from: data) ?? "HTTP \(httpResponse.statusCode)"
                    throw NotifyError.networkError(serverMsg, statusCode: httpResponse.statusCode)
                }

                if (200...299).contains(httpResponse.statusCode) {
                    let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
                    return json
                }

                throw NotifyError.networkError("HTTP \(httpResponse.statusCode)", statusCode: httpResponse.statusCode)

            } catch let err as NotifyError {
                switch err {
                case .authError:
                    throw err // Don't retry auth errors
                case .networkError(_, let code):
                    if let statusCode = code, (400...499).contains(statusCode) && statusCode != 429 {
                        throw err // Don't retry 4xx errors
                    }
                    lastError = err
                default:
                    lastError = err
                }
            } catch {
                lastError = error
            }

            if attempt < config.maxRetries {
                let delaySeconds = Double(attempt) * 0.5
                logger.warn("\(operation) failed (attempt \(attempt)), retrying in \(delaySeconds)s")
                try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            }
        }

        throw lastError ?? NotifyError.networkError("\(operation) failed after \(attempt) attempts", statusCode: nil)
    }

    private func parseErrorMessage(from data: Data) -> String? {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? String {
            return error
        }
        return nil
    }
}
