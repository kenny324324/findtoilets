//
//  ToiletCacheManager.swift
//  Toilet
//

import Foundation

class ToiletCacheManager {
    private let cacheDirectoryName = "toilet_cache"
    private let toiletsFileName = "toilets.json"
    private let locationsFileName = "locations.json"
    private let metaFileName = "cache_meta.json"

    struct CacheMeta: Codable {
        let lastUpdated: Date
        let recordCount: Int
        let version: String

        static let currentVersion = "1.0"
    }

    // MARK: - 快取目錄

    private var cacheDirectory: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return caches.appendingPathComponent(cacheDirectoryName)
    }

    private func ensureCacheDirectoryExists() throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: cacheDirectory.path) {
            try fm.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }

    // MARK: - 快取狀態

    func cacheExists() -> Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: cacheDirectory.appendingPathComponent(locationsFileName).path)
    }

    func isCacheStale() -> Bool {
        guard let meta = loadMeta() else { return true }
        let daysSinceUpdate = Calendar.current.dateComponents(
            [.day], from: meta.lastUpdated, to: Date()
        ).day ?? Int.max
        return daysSinceUpdate >= APIConfig.cacheExpiryDays
    }

    func lastUpdatedDate() -> Date? {
        return loadMeta()?.lastUpdated
    }

    // MARK: - 載入快取

    func loadCachedLocations() -> [ToiletLocation]? {
        let url = cacheDirectory.appendingPathComponent(locationsFileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            return try JSONDecoder().decode([ToiletLocation].self, from: data)
        } catch {
            print("⚠️ 載入快取 locations 失敗: \(error)")
            return nil
        }
    }

    func loadCachedToilets() -> [ToiletInfo]? {
        let url = cacheDirectory.appendingPathComponent(toiletsFileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            return try JSONDecoder().decode([ToiletInfo].self, from: data)
        } catch {
            print("⚠️ 載入快取 toilets 失敗: \(error)")
            return nil
        }
    }

    // MARK: - 儲存快取

    /// 儲存原始廁所資料與分組後的地點資料
    func saveData(toilets: [ToiletInfo], locations: [ToiletLocation]) throws {
        try ensureCacheDirectoryExists()

        let encoder = JSONEncoder()

        // 儲存 toilets
        let toiletsData = try encoder.encode(toilets)
        try toiletsData.write(to: cacheDirectory.appendingPathComponent(toiletsFileName))

        // 儲存 locations
        let locationsData = try encoder.encode(locations)
        try locationsData.write(to: cacheDirectory.appendingPathComponent(locationsFileName))

        // 儲存 metadata
        let meta = CacheMeta(
            lastUpdated: Date(),
            recordCount: toilets.count,
            version: CacheMeta.currentVersion
        )
        let metaData = try encoder.encode(meta)
        try metaData.write(to: cacheDirectory.appendingPathComponent(metaFileName))

        print("✅ 快取儲存成功: \(toilets.count) 筆廁所, \(locations.count) 個地點")
    }

    // MARK: - 清除快取

    func clearCache() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        print("🗑️ 快取已清除")
    }

    // MARK: - Private

    private func loadMeta() -> CacheMeta? {
        let url = cacheDirectory.appendingPathComponent(metaFileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CacheMeta.self, from: data)
    }
}
