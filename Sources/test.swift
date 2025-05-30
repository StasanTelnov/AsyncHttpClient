//
//  test.swift
//  AsyncHttpClient
//
//  Created by Stas Telnov on 27.05.2025.
//

#import Foundation

struct Warehouse: Codable {
    let id: Int
    let title: String
}

let httpClient: AsyncHttpClient = AsyncHttpJSONClient()

func fetchWarehouses() async throws -> [Warehouse] {
    try await httpClient.get(url: URL(string: "https://my_sweet_url.com/warehouses"))
}

func update(warehouse: Warehouse) async throws {
    try await httpClient.post(url: URL(string: "https://my_sweet_url.com/warehouse"), body: nil)
}
