//
//  Created by Stas Telnov on 01.06.2025.
//

import Foundation

// MARK: - String

extension String {
    static let jsonMimeType = "application/json"
    static let multipartMimeType = "multipart/form-data"
    static let octeatStreamMimeType = "application/octet-stream"
    static let post = "POST"
    static let put = "PUT"
    static let delete = "DELETE"
    static let patch = "PATCH"
    static let contentType = "Content-Type"
}


// MARK: - URLError

extension URLError {
    static let invalidUrl = URLError(.badURL)
    static let emptyResponse = URLError(URLError.Code(rawValue: 204))
    static let invalidResponse = URLError(.badServerResponse)
}

// MARK: - URLSession

extension URLSession {
    typealias ProgressClosure = @Sendable (Double) -> Void
    
    func asyncData(for request: URLRequest) async throws -> (Data, URLResponse) {
        if #available(iOS 15.0, *) {
            return try await data(for: request)
        } else {
            return try await withCheckedThrowingContinuation { continuation in
                let task = self.dataTask(with: request) { data, response, error in
                    guard let data, let response else {
                        let error = error ?? URLError.invalidResponse
                        return continuation.resume(throwing: error)
                    }

                    continuation.resume(returning: (data, response))
                }
                task.resume()
            }
        }
    }
    
    func asyncUpload(
        for request: URLRequest,
        with body: Data,
        progressHandler: @escaping ProgressClosure
    ) async throws -> (Data, URLResponse) {
        let delegate = UploadDelegate(progress: progressHandler)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        
        return try await withCheckedThrowingContinuation { cont in
            let task = session.uploadTask(with: request, from: body) { data, resp, err in
                if let err = err {
                    cont.resume(throwing: err)
                    return
                }
                guard let data = data,
                      let resp = resp else {
                    cont.resume(throwing: URLError(.badServerResponse))
                    return
                }
                cont.resume(returning: (data, resp))
            }
            task.resume()
        }
    }
}
