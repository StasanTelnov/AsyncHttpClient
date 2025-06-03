# iOS Swift AsyncHttpClient

Useful Swift iOS and MacOS Async HTTP Client.\
Motto: Perform http requests in one string

## SPM Usage:
```swift
    dependencies: [
        .package(url: "https://github.com/Oleg-E-Bakharev/AsyncHttpClient", from: "1.1.0")
    ],
```

## Usage sample

### Simple requests:
```swift

#import Foundation
#import AsyncHttpClient

struct Warehouse: Codable {
    let id: Int
    let title: String
}

struct UploadStatus: Codable {
    let status: String
}

let httpClient: AsyncHttpClient = AsyncHttpJSONClient()

func fetchWarehouses() async throws -> [Warehouse] {
    try await httpClient.get(url: URL(string: "https://my_sweet_url.com/warehouses"))
}

func update(warehouse: Warehouse) async throws {
    try await httpClient.post(url: URL(string: "https://my_sweet_url.com/warehouse"), body: warehouse)
}
```

### Files upload requests with `multipart/form-data`:

The easiest way to download files is by URL, for example, from Bundle, Documents, etc.
For upload files you should use `AsyncFileUpload` wrapper for body.
In this case, the wrapper itself subtracts the mime-type and name from the OGL.

#### Example:
```swift
func uploadFiles(filesUrls: [URL], metadata: Warehouse) async throws -> UploadStatus {
    try await httpClient.post(
        url: URL(string: "https://my_sweet_url.com/upload_warehouse")!,
        body: AsyncFileUpload(filesUrls: filesUrls, params: ["metadata": metadata]), // in this support some params with your custom name. Param value should be Encodable
        progress: {
            print("Progress of upload is \($0)")
        }
    )
}
```

If you need to use `Data`, you have two ways to do it, using `UploadFileInfo` struct and `filesInfos` init param in `AsyncFileUpload`.
First of it, use fabric method of `UploadFileInfo` with `Data` and file extension.

#### Example:
```swift
func uploadFiles(fileData: Data, ext: String) async throws {
    let fileInfo = try! await UploadFileInfo.fileInfo(fileData, ext: ext) // ext is file extension: "txt", "pdf", "jpg", etc.

    return try await httpClient.post(
        url: URL(string: "https://my_sweet_url.com/upload_warehouse")!,
        body: AsyncFileUpload(filesInfos: [filesUrls]), // in this support some params with your custom name. Param value should be Encodable
        progress: {
            print("Progress of upload is \($0)")
        }
    )
}
```
This way work only iOS 14+

The second way, is use all awailable file data properties or only some of its.
Init signature is:
```swift
public init(
        /// Data of file
        data: Data,
        
        /// file name without extension. For example MyPicture
        /// desirable if there is no filename, otherwise it will be UUID
        name: String? = nil,
        
        // full file name with extension (for example MyPicture.jpg)
        /// must be unique for each file, if several files are sent
        /// if absent, then formed on name + ext
        filename: String? = nil,
    
        /// file extension, desirable if there is no filename,
        /// if omitted and there is no filename and detectPropertiesIfNeeded == false it will be just "data"
        ext: String? = nil,
        
        /// optional, if not specified and cannot be calculated, it will be "application/octet-stream"
        mimeType: String? = nil,
    
        /// In case of ios 14+ and absence of some parameters filename, name, mime-type
        /// work only in iOS 14+
        detectPropertiesIfNeeded: Bool = true
    ) async throws
```

This init require only Data. Other properties is optional. If you dot set file extension for correct detection file extension on server.

#### Examples:
```swift
func uploadFile(_ file: Data /* other you params */) async throws -> UploadStatus {
    
    let first = try! await UploadFileInfo(data: file)
/// (AsyncHttpClient.UploadFileInfo)  (data = 32 bytes, filename = "BD5BAAFD-6C4D-43F2-9D16-5D15B3A0FD54.data", name = "BD5BAAFD-6C4D-43F2-9D16-5D15B3A0FD54", mimeType = "application/octet-stream")

    let second = try! await UploadFileInfo(data: file, filename: "testing.txt")
/// (AsyncHttpClient.UploadFileInfo)  (data = 32 bytes, filename = "testing.txt", name = "testing", mimeType = "text/plain")

    let third = try! await UploadFileInfo(data: file, name: "testing1")
/// (AsyncHttpClient.UploadFileInfo)  (data = 32 bytes, filename = "testing1.data", name = "testing1", mimeType = "application/octet-stream")

    let fourth = try! await UploadFileInfo(data: file, ext: "txt")
/// (AsyncHttpClient.UploadFileInfo)  (data = 32 bytes, filename = "FCB09108-2B02-4681-92F1-C3D73FD1B4FA.txt", name = "FCB09108-2B02-4681-92F1-C3D73FD1B4FA", mimeType = "text/plain")

    let fifth = try! await UploadFileInfo(data: file, name: "testing2", ext: "pdf")
/// (AsyncHttpClient.UploadFileInfo)  (data = 32 bytes, filename = "testing2.pdf", name = "testing2", mimeType = "application/pdf")

    let sixth = try! await UploadFileInfo(data: file, mimeType: "text/plain", detectPropertiesIfNeeded: false)
/// (AsyncHttpClient.UploadFileInfo)  (data = 32 bytes, filename = "5EACB335-9D47-4A6D-9F9A-CC554D36CD48.data", name = "5EACB335-9D47-4A6D-9F9A-CC554D36CD48", mimeType = "text/plain")

    let seventh = try! await UploadFileInfo(data: file, ext: "pdf", mimeType: "text/plain", detectPropertiesIfNeeded: false)
/// (AsyncHttpClient.UploadFileInfo)  (data = 32 bytes, filename = "2D1E357D-0CA0-46B8-BC38-EE0E3E1E20AA.pdf", name = "2D1E357D-0CA0-46B8-BC38-EE0E3E1E20AA", mimeType = "text/plain")

    let eighth  = try! await UploadFileInfo(data: file, ext: "pdf", mimeType: "text/plain")
/// (AsyncHttpClient.UploadFileInfo)  (data = 32 bytes, filename = "C54EA947-24AA-4491-8878-7A380D8EB8C9.pdf", name = "C54EA947-24AA-4491-8878-7A380D8EB8C9", mimeType = "application/pdf")

    let ninth = try! await UploadFileInfo(data: file, name: "customName", filename: "testing3.png")
/// (AsyncHttpClient.UploadFileInfo)  (data = 32 bytes, filename = "testing3.png", name = "customName", mimeType = "image/png")

    return try await httpClient.post(
        url: URL(string: "https://postman-echo.com/post")!,
        body: AsyncFileUpload(filesInfos: [first, second, third, fourth, fifth, sixth, seventh, eighth, ninth])
    )
}
```

Also you can combine `filesUrls` and `﻿﻿filesInfos` with Data and extension

#### Example:
```swift
func uploadFile(_ file: Data, ext: String, fileUrl: URL) async throws -> UploadStatus {
    let fileInfo = try! await UploadFileInfo.fileInfo(file, ext: ext)

    return try await httpClient.post(
        url: URL(string: "https://postman-echo.com/post")!,
        body: AsyncFileUpload(filesUrls: [fileUrl], filesInfos: [fileInfo])
    )
}
```
