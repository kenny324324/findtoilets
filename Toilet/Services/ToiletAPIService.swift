//
//  ToiletAPIService.swift
//  Toilet
//

import Foundation

enum ToiletAPIError: Error, LocalizedError {
    case networkError(Error)
    case decodingError(Error)
    case invalidResponse(Int)
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "網路錯誤: \(error.localizedDescription)"
        case .decodingError(let error):
            return "資料解析錯誤: \(error.localizedDescription)"
        case .invalidResponse(let code):
            return "伺服器回應錯誤: \(code)"
        case .invalidURL:
            return "無效的 URL"
        }
    }
}

/// API 回應的中間結構（欄位名稱與 API 一致，使用 areacode）
private struct APIToiletRecord: Decodable {
    let county: String
    let areacode: String
    let village: String
    let number: String
    let name: String
    let address: String
    let administration: String
    let latitude: String
    let longitude: String
    let grade: String
    let type2: String
    let type: String
    let exec: String
    let diaper: String

    func toToiletInfo() -> ToiletInfo {
        ToiletInfo(
            county: county,
            city: areacode,
            village: village,
            number: number,
            name: name,
            address: address,
            administration: administration,
            latitude: latitude,
            longitude: longitude,
            grade: grade,
            type2: type2,
            type: type,
            exec: exec,
            diaper: diaper
        )
    }
}

class ToiletAPIService {
    private let session: URLSession
    private let maxRetries = 3

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// 拉取所有公廁資料（自動分頁）
    func fetchAllToilets(progress: ((Int) -> Void)? = nil) async throws -> [ToiletInfo] {
        var allRecords: [ToiletInfo] = []
        var offset = 0
        let pageSize = APIConfig.pageSize

        while true {
            let page = try await fetchPage(offset: offset)
            if page.isEmpty { break }
            allRecords.append(contentsOf: page)
            offset += pageSize
            progress?(allRecords.count)
        }

        return allRecords
    }

    /// 拉取單頁資料
    private func fetchPage(offset: Int) async throws -> [ToiletInfo] {
        guard var components = URLComponents(string: APIConfig.baseURL) else {
            throw ToiletAPIError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "language", value: APIConfig.language),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: String(APIConfig.pageSize)),
            URLQueryItem(name: "api_key", value: APIConfig.apiKey)
        ]

        guard let url = components.url else {
            throw ToiletAPIError.invalidURL
        }

        var lastError: Error?

        for attempt in 1...maxRetries {
            do {
                let (data, response) = try await session.data(from: url)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw ToiletAPIError.invalidResponse(0)
                }

                guard httpResponse.statusCode == 200 else {
                    throw ToiletAPIError.invalidResponse(httpResponse.statusCode)
                }

                let decoder = JSONDecoder()
                let records = try decoder.decode([APIToiletRecord].self, from: data)
                return records.map { $0.toToiletInfo() }

            } catch let error as ToiletAPIError {
                lastError = error
                if attempt < maxRetries {
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt - 1))) * 1_000_000_000)
                }
            } catch {
                lastError = ToiletAPIError.networkError(error)
                if attempt < maxRetries {
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt - 1))) * 1_000_000_000)
                }
            }
        }

        throw lastError ?? ToiletAPIError.networkError(NSError(domain: "ToiletAPI", code: -1))
    }
}
