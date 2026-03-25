//
//  BusinessHoursManager.swift
//  Toilet
//

import Foundation
import CloudKit

class BusinessHoursManager: ObservableObject {
    @Published var businessHours: BusinessHoursInfo?
    @Published var isLoading = false
    @Published var loadFailed = false

    private let googleService = GooglePlacesService()
    private let cloudKitManager = CloudKitManager.shared

    /// 載入地點的營業時間（CloudKit 快取優先 → Google Places API）
    func loadHours(for location: ToiletLocation) {
        guard !isLoading else {
            print("⏰ [營業時間] 已在載入中，跳過")
            return
        }

        print("⏰ [營業時間] 開始查詢: \(location.name)")
        isLoading = true
        loadFailed = false

        let locationIdString = location.id.uuidString

        // 1. 先查 CloudKit 快取
        cloudKitManager.fetchBusinessHours(locationId: locationIdString) { [weak self] cached in
            guard let self = self else {
                print("⏰ [營業時間] self 已釋放")
                return
            }

            if let cached = cached, !cached.isExpired {
                print("⏰ [營業時間] CloudKit 快取命中: \(cached.todayHoursText)")
                DispatchQueue.main.async {
                    self.businessHours = cached
                    self.isLoading = false
                }
                return
            }

            print("⏰ [營業時間] CloudKit 無快取，改查 Google Places API...")
            // 2. 快取不存在或已過期，從 Google Places API 查詢
            self.fetchFromGoogle(location: location, locationIdString: locationIdString)
        }
    }

    private func fetchFromGoogle(location: ToiletLocation, locationIdString: String) {
        Task {
            do {
                print("⏰ [營業時間] 呼叫 Google Places API: \(location.name) (\(location.latitude), \(location.longitude))")
                let hours = try await googleService.fetchBusinessHours(
                    name: location.name,
                    latitude: location.latitude,
                    longitude: location.longitude
                )

                await MainActor.run {
                    if let hours = hours {
                        print("⏰ [營業時間] Google 查詢成功: \(hours.todayHoursText)")
                        self.businessHours = hours
                        // 存到 CloudKit 供其他裝置使用
                        self.cloudKitManager.saveBusinessHours(
                            locationId: locationIdString,
                            info: hours
                        )
                    } else {
                        print("⏰ [營業時間] Google 查詢回傳 nil（找不到此地點或無營業時間資料）")
                    }
                    self.isLoading = false
                }
            } catch {
                print("❌ [營業時間] Google Places 查詢失敗: \(error)")
                await MainActor.run {
                    self.loadFailed = true
                    self.isLoading = false
                }
            }
        }
    }
}
