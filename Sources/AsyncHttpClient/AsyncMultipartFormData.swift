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
public struct UploadFileInfo {
    
    // MARK: - Properties
    let data: Data
    let filename: String
    let name: String
    let mimeType: String
    
    // MARK: - Fabric methods
    
    @available(iOS 14, *)
    public static func fileInfo(_ data: Data, ext: String = "data") async throws -> Self {
        let fileManager = FileManager.default
        
        let tempFileName = UUID().uuidString + "." + ext
        let tempURL = fileManager.temporaryDirectory.appendingPathComponent(tempFileName)
        
        do {
            try data.write(to: tempURL)
        } catch {
            throw error
        }
        
        defer {
            try? fileManager.removeItem(at: tempURL)
        }
        
        let result: Self
        do {
            result = try Self(tempURL)
        } catch {
            throw error
        }
        
        return result
    }
    
    // MARK: - Inits

    /// Для файлов, которые содержат только Data
    public init(
        /// Data файла
        data: Data,
        
        /// имя файла без расширения. Например MyPicture
        /// желательно если нет filename, в противном случае будет UUID
        name: String? = nil,
        
        /// полное имя файла с расширением (например MyPicture.jpg)
        /// должно быть уникальным для каждого файла, если отправляется несколько файлов
        /// если отсутствиет, то формируется на name + ext
        filename: String? = nil,
    
        /// расширение файла, желательно если нет filename,
        /// если пропущено и нет filename и detectPropertiesIfNeeded == false будет просто "data"
        ext: String? = nil,
        
        /// опционально, в случае если не указан и не удастся вычислить, будет "application/octet-stream"
        mimeType: String? = nil,
    
        /// В случае ios 14+ и отсутствии части параметров filename, name,  mime-type
        detectPropertiesIfNeeded: Bool = true
    ) async throws {
        var currentExt = ext ?? "data"
        
        if #available(iOS 14, *),
           detectPropertiesIfNeeded,
           name == nil,
           filename == nil {
            self = try await Self.fileInfo(data, ext: currentExt)
            return
        }
        
        self.data = data
        
        var currentFileName = name ?? UUID().uuidString
        
        if let filename = filename {
            self.filename = filename
            if name == nil {
                currentFileName = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
            }
            if ext == nil {
                currentExt = URL(fileURLWithPath: filename).pathExtension
            }
        } else {
            self.filename = currentFileName + "." + currentExt
        }
        
        self.name = currentFileName
        
        if let ext = ext {
            currentExt = ext
        }
        
        if #available(iOS 14.0, *),
           mimeType == nil,
           detectPropertiesIfNeeded {
            self.mimeType = UTType(filenameExtension: currentExt)?.preferredMIMEType ?? .octeatStreamMimeType
        } else {
            self.mimeType = mimeType ?? .octeatStreamMimeType
        }
    }
    
    /// Для файлов с url (например, хранящихся в Bundle, Documents, etc)
    public init(_ fileURL: URL) throws {
        let fileData: Data
        do {
            fileData = try Data(contentsOf: fileURL)
        } catch {
            throw error
        }
        
        self.data = fileData
        self.filename = fileURL.lastPathComponent
        self.name = fileURL.deletingPathExtension().lastPathComponent
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
    
    var filesUrls: [URL] = []
    var filesInfos: [UploadFileInfo] = []
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
        
        var allFilesInfoList = filesInfos
        
        for fileUrl in filesUrls {
            guard let file = try? UploadFileInfo(fileUrl) else {
                continue
            }
            allFilesInfoList.append(file)
        }
        
        for fileInfo in allFilesInfoList {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(fileInfo.name)\"; filename=\"\(fileInfo.filename)\"\r\n")
            append("Content-Type: \(fileInfo.mimeType)\r\n\r\n")
            data.append(fileInfo.data)
            append("\r\n")
        }

        append("--\(boundary)--\r\n")
        return data
    }
    
    // MARK: - Life cicle
    
    public init(filesUrls: [URL] = [], filesInfos: [UploadFileInfo] = [], params: [String : Codable]? = nil) {
        self.filesUrls = filesUrls
        self.filesInfos = filesInfos
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
