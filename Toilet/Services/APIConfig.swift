//
//  APIConfig.swift
//  Toilet
//

import Foundation

enum APIConfig {
    static let baseURL = "https://data.moenv.gov.tw/api/v2/fac_p_07"
    static let apiKey = "b2ca67bd-9f51-412f-9447-0087c2dd3107"
    static let pageSize = 500
    static let cacheExpiryDays = 7

    // Google Places API
    static let googlePlacesAPIKey = "AIzaSyCIYfp3eNpCsPetAYF3qS3V-ZF9fPzdEJ4"

    /// 根據系統語言回傳 API 的 language 參數（"zh" 或 "en"）
    static var language: String {
        let preferredLanguage = Locale.preferredLanguages.first ?? "zh"
        return preferredLanguage.hasPrefix("zh") ? "zh" : "en"
    }
}
