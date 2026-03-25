//
//  GooglePlacesService.swift
//  Toilet
//

import Foundation
import CoreLocation

/// 每日營業時間
struct DayHours: Codable, Equatable {
    let day: Int           // 0=Sunday, 1=Monday, ..., 6=Saturday
    let openTime: String   // "09:00"
    let closeTime: String  // "17:00"
    let isClosed: Bool
}

/// 營業時間資訊
struct BusinessHoursInfo: Codable, Equatable {
    let locationId: String
    let placeId: String
    let weekdayHours: [DayHours]   // 7 天的營業時間
    let fetchedAt: Date

    /// 根據當前時間判斷是否營業中
    var isOpenNow: Bool {
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now) - 1 // 1=Sunday → 0
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let currentTime = String(format: "%02d:%02d", hour, minute)

        guard let todayHours = weekdayHours.first(where: { $0.day == weekday }) else {
            return false
        }

        if todayHours.isClosed { return false }

        if todayHours.closeTime < todayHours.openTime {
            // 跨午夜（例如 06:00 - 01:00）
            return currentTime >= todayHours.openTime || currentTime < todayHours.closeTime
        } else {
            return currentTime >= todayHours.openTime && currentTime < todayHours.closeTime
        }
    }

    /// 取得今日營業時間的顯示文字（AM/PM 格式）
    var todayHoursText: String {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date()) - 1

        guard let todayHours = weekdayHours.first(where: { $0.day == weekday }) else {
            return "無資料"
        }

        if todayHours.isClosed { return "今日休息" }
        return "\(Self.toAMPM(todayHours.openTime)) - \(Self.toAMPM(todayHours.closeTime))"
    }

    /// 將 "06:00" 轉為 "6:00 AM"、"13:30" 轉為 "1:30 PM"
    private static func toAMPM(_ time: String) -> String {
        let parts = time.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return time }

        if hour == 0 {
            return "12:\(String(format: "%02d", minute)) AM"
        } else if hour < 12 {
            return "\(hour):\(String(format: "%02d", minute)) AM"
        } else if hour == 12 {
            return "12:\(String(format: "%02d", minute)) PM"
        } else {
            return "\(hour - 12):\(String(format: "%02d", minute)) PM"
        }
    }

    /// 快取是否過期（30 天）
    var isExpired: Bool {
        let days = Calendar.current.dateComponents([.day], from: fetchedAt, to: Date()).day ?? Int.max
        return days >= 30
    }
}

class GooglePlacesService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// 用座標和名稱查詢營業時間
    func fetchBusinessHours(name: String, latitude: Double, longitude: Double) async throws -> BusinessHoursInfo? {
        // Step 1: Nearby Search — 用座標+名稱找到 place_id
        guard let placeId = try await searchPlace(name: name, latitude: latitude, longitude: longitude) else {
            return nil
        }

        // Step 2: Place Details — 用 place_id 取得營業時間
        return try await getPlaceDetails(placeId: placeId, locationId: "\(name)-\(latitude)-\(longitude)")
    }

    // MARK: - Private: Places API (New)

    /// 用 Text Search (New) 查找 place_id
    private func searchPlace(name: String, latitude: Double, longitude: Double) async throws -> String? {
        let url = URL(string: "https://places.googleapis.com/v1/places:searchText")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(APIConfig.googlePlacesAPIKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue("places.id", forHTTPHeaderField: "X-Goog-FieldMask")
        request.setValue(Bundle.main.bundleIdentifier ?? "", forHTTPHeaderField: "X-Ios-Bundle-Identifier")

        let body: [String: Any] = [
            "textQuery": name,
            "locationBias": [
                "circle": [
                    "center": [
                        "latitude": latitude,
                        "longitude": longitude
                    ],
                    "radius": 500.0
                ]
            ],
            "maxResultCount": 1
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("⏰ [Google] Text Search: 無 HTTP 回應")
            return nil
        }

        if httpResponse.statusCode != 200 {
            let responseBody = String(data: data, encoding: .utf8) ?? "無法解析"
            print("⏰ [Google] Text Search 失敗 (HTTP \(httpResponse.statusCode)): \(responseBody)")
            return nil
        }

        let result = try JSONDecoder().decode(TextSearchResponse.self, from: data)
        let placeId = result.places?.first?.id
        print("⏰ [Google] Text Search 結果: \(placeId ?? "未找到")")
        return placeId
    }

    /// 用 Place Details (New) 取得營業時間
    private func getPlaceDetails(placeId: String, locationId: String) async throws -> BusinessHoursInfo? {
        let url = URL(string: "https://places.googleapis.com/v1/places/\(placeId)")!

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(APIConfig.googlePlacesAPIKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue("regularOpeningHours", forHTTPHeaderField: "X-Goog-FieldMask")
        request.setValue(Bundle.main.bundleIdentifier ?? "", forHTTPHeaderField: "X-Ios-Bundle-Identifier")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("⏰ [Google] Place Details: 無 HTTP 回應")
            return nil
        }

        if httpResponse.statusCode != 200 {
            let responseBody = String(data: data, encoding: .utf8) ?? "無法解析"
            print("⏰ [Google] Place Details 失敗 (HTTP \(httpResponse.statusCode)): \(responseBody)")
            return nil
        }

        let result = try JSONDecoder().decode(PlaceDetailsNewResponse.self, from: data)

        guard let periods = result.regularOpeningHours?.periods else {
            return nil
        }

        let weekdayHours = parseOpeningPeriods(periods)

        return BusinessHoursInfo(
            locationId: locationId,
            placeId: placeId,
            weekdayHours: weekdayHours,
            fetchedAt: Date()
        )
    }

    /// 將 Google 的 opening periods 轉換為 [DayHours]
    private func parseOpeningPeriods(_ periods: [NewOpeningPeriod]) -> [DayHours] {
        // 如果只有一個 period 且 close 為空，表示 24 小時營業
        if periods.count == 1, let first = periods.first,
           first.open.day == 0, first.open.hour == 0, first.open.minute == 0,
           first.close == nil {
            return (0...6).map { day in
                DayHours(day: day, openTime: "00:00", closeTime: "23:59", isClosed: false)
            }
        }

        // 建立每天的營業時間
        var dayHoursMap: [Int: DayHours] = [:]

        for period in periods {
            let day = period.open.day
            let openTime = String(format: "%02d:%02d", period.open.hour ?? 0, period.open.minute ?? 0)
            let closeTime: String
            if let close = period.close {
                closeTime = String(format: "%02d:%02d", close.hour ?? 0, close.minute ?? 0)
            } else {
                closeTime = "23:59"
            }
            dayHoursMap[day] = DayHours(day: day, openTime: openTime, closeTime: closeTime, isClosed: false)
        }

        // 填入未出現的天（表示休息）
        return (0...6).map { day in
            dayHoursMap[day] ?? DayHours(day: day, openTime: "", closeTime: "", isClosed: true)
        }
    }
}

// MARK: - Places API (New) Response Models

/// Text Search response
private struct TextSearchResponse: Decodable {
    let places: [PlaceResult]?
}

private struct PlaceResult: Decodable {
    let id: String
}

/// Place Details response
private struct PlaceDetailsNewResponse: Decodable {
    let regularOpeningHours: RegularOpeningHours?
}

private struct RegularOpeningHours: Decodable {
    let periods: [NewOpeningPeriod]?
}

private struct NewOpeningPeriod: Decodable {
    let open: NewDayTime
    let close: NewDayTime?
}

private struct NewDayTime: Decodable {
    let day: Int
    let hour: Int?
    let minute: Int?
}
