//  Created by Stas Telnov on 28.05.2025.

import Foundation
import UniformTypeIdentifiers

/// Протокол загрузки файла
public protocol AsyncMultipartFormData: Encodable {
    var body: Data { get }
    var contentType: String { get }
}

// MARK: - UploadFileInfo

/// Формирует набор свойств отправляемого файла
private struct UploadFileInfo {
    let data: Data
    let name: String
    let filename: String
    let mimeType: String
    
    private init(data: Data, name: String, filename: String, mimeType: String) {
        self.data = data
        self.name = name
        self.filename = filename
        self.mimeType = mimeType
    }
    
    init(_ fileURL: URL) throws {
        let fileData: Data
        do {
            fileData = try Data(contentsOf: fileURL)
        } catch {
            throw error
        }
        
        self.data = fileData
        self.name = fileURL.deletingPathExtension().lastPathComponent
        self.filename = fileURL.lastPathComponent
        if #available(iOS 14.0, *) {
            self.mimeType = UTType(filenameExtension: fileURL.pathExtension)?.preferredMIMEType ?? .octeatStreamMimeType
        } else {
            self.mimeType = .octeatStreamMimeType
        }
    }
}

// MARK: - AsyncFileUpload

public struct AsyncFileUpload: AsyncMultipartFormData {
    
    // MARK: - Private properties
    
    private let boundary = "Boundary-\(UUID().uuidString)"
    
    // MARK: - Inner properties
    
    let filesUrls: [URL]
    var params: [String: Codable]? = nil
    
    // MARK: - Сomputed properties
    
    public var contentType: String {
        "\(String.multipartMimeType); boundary=\(boundary)"
    }
    
    public var body: Data {
        var data = Data()
        func append(_ string: String) {
            guard let stringData = string.data(using: .utf8) else {
                return
            }
            data.append(stringData)
        }
        
        if let params = params {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            params.forEach {
                if let jsonBody = try? encoder.encode($1) {
                    append("--\(boundary)\r\n")
                    append("Content-Disposition: form-data; name=\"\($0)\"\r\n")
                    append("Content-Type: \(String.jsonMimeType)\r\n\r\n")
                    data.append(jsonBody)
                    append("\r\n")
                }
            }
        }
        
        for fileUrl in filesUrls {
            guard let file = try? UploadFileInfo(fileUrl) else {
                continue
            }
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(file.name)\"; filename=\"\(file.filename)\"\r\n")
            append("Content-Type: \(file.mimeType)\r\n\r\n")
            data.append(file.data)
            append("\r\n")
        }

        append("--\(boundary)--\r\n")
        return data
    }
    
    // MARK: - Life cicle
    
    public init(filesUrls: [URL], params: [String : Codable]? = nil) {
        self.filesUrls = filesUrls
        self.params = params
    }
    
    public func encode(to encoder: any Encoder) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            var string: String = ""
            try encoder.encode(self).withUnsafeBytes { ptr in
                string += "\(ptr)"
            }
        } catch {
            throw error
        }
    }
}

// MARK: - UploadDelegate

final class UploadDelegate: NSObject, URLSessionTaskDelegate {
    let progress: URLSession.ProgressClosure
    
    init(progress: @escaping URLSession.ProgressClosure) {
        self.progress = progress
    }
    
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        guard totalBytesExpectedToSend > 0 else {
            return
        }
        let fraction = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        progress(fraction)
    }
}
