//
// Copyright 2026 Che Tianshi
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
@preconcurrency import Security

nonisolated struct ClientAuthSession: Equatable, Sendable {
    let accessToken: String
    let userID: String
    let deviceID: String
}

nonisolated enum ClientAuthServiceError: Error {
    case invalidCredentials
    case releaseNotAllowed
    case unavailable
    case invalidResponse
}

nonisolated protocol ClientAuthServiceProtocol: Sendable {
    func login(username: String, password: String, initialDeviceName: String) async throws -> ClientAuthSession
}

final nonisolated class ClientAuthService: ClientAuthServiceProtocol, Sendable {
    private let endpoint = URL(string: "https://8.163.2.191/client-auth/login")! // swiftlint:disable:this force_unwrapping
    private let identityResourceName = "family-client"
    private let maximumResponseSize = 16 * 1024
    
    func login(username: String, password: String, initialDeviceName: String) async throws -> ClientAuthSession {
        guard isValidLocalpart(username),
              !password.isEmpty,
              password.utf8.count <= 4096,
              !initialDeviceName.isEmpty,
              initialDeviceName.utf8.count <= 255 else {
            throw ClientAuthServiceError.invalidCredentials
        }
        
        let identity = try loadIdentity()
        let delegate = ClientAuthURLSessionDelegate(identity: identity, allowedHost: endpoint.host()!) // swiftlint:disable:this force_unwrapping
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 30
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let requestBody = try JSONEncoder().encode(LoginRequest(username: username,
                                                                password: password,
                                                                initialDeviceDisplayName: initialDeviceName))
        guard requestBody.count <= 8 * 1024 else {
            throw ClientAuthServiceError.invalidCredentials
        }
        request.httpBody = requestBody
        
        var data = Data()
        let response: URLResponse
        do {
            let (bytes, urlResponse) = try await session.bytes(for: request)
            response = urlResponse
            if urlResponse.expectedContentLength > Int64(maximumResponseSize) {
                throw ClientAuthServiceError.invalidResponse
            }
            data.reserveCapacity(min(max(Int(urlResponse.expectedContentLength), 0), maximumResponseSize))
            for try await byte in bytes {
                guard data.count < maximumResponseSize else {
                    throw ClientAuthServiceError.invalidResponse
                }
                data.append(byte)
            }
        } catch let error as ClientAuthServiceError {
            throw error
        } catch {
            throw ClientAuthServiceError.unavailable
        }
        
        guard let response = response as? HTTPURLResponse,
              response.url?.scheme == "https",
              response.url?.host() == endpoint.host() else {
            throw ClientAuthServiceError.invalidResponse
        }
        
        switch response.statusCode {
        case 200:
            return try decodeSession(from: data, requestedUsername: username)
        case 403:
            switch decodeErrorCode(from: data) {
            case "M_FORBIDDEN":
                throw ClientAuthServiceError.invalidCredentials
            case "M_RELEASE_NOT_ALLOWED":
                throw ClientAuthServiceError.releaseNotAllowed
            default:
                throw ClientAuthServiceError.invalidResponse
            }
        case 503:
            throw ClientAuthServiceError.unavailable
        default:
            throw ClientAuthServiceError.invalidResponse
        }
    }
    
    private func loadIdentity() throws -> SecIdentity {
        guard let url = Bundle.main.url(forResource: identityResourceName, withExtension: "p12"),
              let data = try? Data(contentsOf: url),
              data.count <= 64 * 1024 else {
            throw ClientAuthServiceError.releaseNotAllowed
        }
        
        var importedItems: CFArray?
        let options = [kSecImportExportPassphrase as String: ""] as CFDictionary
        guard SecPKCS12Import(data as CFData, options, &importedItems) == errSecSuccess,
              let item = (importedItems as? [[String: Any]])?.first,
              let identityValue = item[kSecImportItemIdentity as String] else {
            throw ClientAuthServiceError.releaseNotAllowed
        }
        return identityValue as! SecIdentity // swiftlint:disable:this force_cast
    }
    
    private func decodeSession(from data: Data, requestedUsername: String) throws -> ClientAuthSession {
        guard let json = try? JSONSerialization.jsonObject(with: data),
              let response = json as? [String: Any],
              Set(response.keys) == LoginResponse.requiredKeys,
              let accessToken = response["access_token"] as? String,
              let userID = response["user_id"] as? String,
              let deviceID = response["device_id"] as? String,
              !accessToken.isEmpty,
              accessToken.utf8.count <= 8192,
              !deviceID.isEmpty,
              deviceID.utf8.count <= 255,
              userID == "@\(requestedUsername):8.163.2.191" else {
            throw ClientAuthServiceError.invalidResponse
        }
        
        return ClientAuthSession(accessToken: accessToken,
                                 userID: userID,
                                 deviceID: deviceID)
    }
    
    private func decodeErrorCode(from data: Data) -> String? {
        try? JSONDecoder().decode(ErrorResponse.self, from: data).errorCode
    }
    
    private func isValidLocalpart(_ username: String) -> Bool {
        !username.isEmpty &&
            username.utf8.count <= 255 &&
            !username.contains("@") &&
            !username.contains(":") &&
            !username.contains(where: \.isWhitespace)
    }
}

private final nonisolated class ClientAuthURLSessionDelegate: NSObject, URLSessionTaskDelegate {
    private let identity: SecIdentity
    private let allowedHost: String
    
    init(identity: SecIdentity, allowedHost: String) {
        self.identity = identity
        self.allowedHost = allowedHost
    }
    
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let protectionSpace = challenge.protectionSpace
        guard protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        guard challenge.previousFailureCount == 0,
              protectionSpace.protocol == "https",
              protectionSpace.host == allowedHost else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        completionHandler(.useCredential,
                          URLCredential(identity: identity, certificates: nil, persistence: .forSession))
    }
    
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

private nonisolated struct LoginRequest: Encodable {
    let username: String
    let password: String
    let initialDeviceDisplayName: String
    
    enum CodingKeys: String, CodingKey {
        case username, password
        case initialDeviceDisplayName = "initial_device_display_name"
    }
}

private nonisolated enum LoginResponse {
    static let requiredKeys: Set = ["access_token", "user_id", "device_id"]
}

private nonisolated struct ErrorResponse: Decodable {
    let errorCode: String
    
    enum CodingKeys: String, CodingKey {
        case errorCode = "errcode"
    }
}
