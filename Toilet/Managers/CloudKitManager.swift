//
//  CloudKitManager.swift
//  Toilet
//
//  Created by Cursor on 2024/12/02.
//

import Foundation
import CloudKit
import Combine
import SwiftUI

// 使用者性別枚舉
enum UserGender: Int, Codable, CaseIterable, Identifiable {
    case secret = 0
    case male = 1
    case female = 2
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .secret: return "不透露"
        case .male: return "男生"
        case .female: return "女生"
        }
    }
    
    var color: Color {
        switch self {
        case .secret: return .gray
        case .male: return .blue
        case .female: return .red
        }
    }
}

// 使用者檔案模型
struct UserProfile: Identifiable {
    let id: CKRecord.ID
    let nickname: String
    let gender: UserGender
}

class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()
    
    // CloudKit 容器
    // 使用 v2 容器來解決舊容器 Bundle ID 關聯損壞的問題
    private let container = CKContainer(identifier: "iCloud.com.kenny.findtoilet.v2")
    
    // 公共資料庫 (所有人都看得到的資料)
    private lazy var publicDB = container.publicCloudDatabase
    
    // 當前使用者的獨特 ID (跨裝置不變)
    @Published var currentUserID: CKRecord.ID?
    @Published var permissionStatus: Bool = false
    @Published var currentUserProfile: UserProfile? // 當前使用者的檔案
    
    private init() {
        // 初始化時檢查 iCloud 狀態並取得 ID
        checkiCloudStatus()
    }
    
    // 1. 檢查並取得使用者 ID
    func checkiCloudStatus() {
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    self?.permissionStatus = true
                    self?.fetchUserRecordID()
                default:
                    // 使用者沒登入 iCloud 或受限制
                    self?.permissionStatus = false
                    print("iCloud account not available: \(String(describing: error))")
                }
            }
        }
    }
    
    private func fetchUserRecordID() {
        container.fetchUserRecordID { [weak self] recordID, error in
            if let recordID = recordID {
                DispatchQueue.main.async {
                    self?.currentUserID = recordID
                    print("\n🚀 [CloudKit] 身分驗證成功！")
                    print("   -> 您的 User ID: \(recordID.recordName)")
                    print("   -> 這組 ID 跨裝置、重裝都不會變，就是您的匿名身分證。\n")
                    
                    // 取得 ID 後，順便抓取使用者檔案
                    self?.fetchMyUserProfile(recordID: recordID)
                }
            } else if let error = error {
                print("\n⚠️ [CloudKit] 身分驗證失敗: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - User Profile Management
    
    // 取得自己的使用者檔案
    func fetchMyUserProfile(recordID: CKRecord.ID) {
        publicDB.fetch(withRecordID: recordID) { [weak self] record, error in
            DispatchQueue.main.async {
                if let record = record {
                    // 解析 UserProfile
                    // 注意：User Records 是特殊的，我們直接在 User Record 上擴充欄位
                    // 或者我們使用獨立的 Users table，這裡假設我們擴充 User Record 或者使用 1:1 的 Profile
                    // 但通常 Public DB 的 User Record 是不可寫入的 (除了自訂欄位)，
                    // 比較好的做法是建立一個 "UserProfile" recordType，ID 為 userRecordID (或者有 reference)
                    // 為了簡化查詢，我們嘗試直接查詢 ID 為 userRecordID 的 UserProfile record
                    
                    self?.fetchUserProfileRecord(userRecordID: recordID)
                }
            }
        }
    }
    
    // 實際上抓取 UserProfile record
    private func fetchUserProfileRecord(userRecordID: CKRecord.ID) {
        // 假設 UserProfile 的 recordID.recordName 就是 userRecordID.recordName
        // 這樣可以確保一對一
        let profileRecordID = CKRecord.ID(recordName: userRecordID.recordName, zoneID: CKRecordZone.default().zoneID)
        
        publicDB.fetch(withRecordID: profileRecordID) { [weak self] record, error in
            DispatchQueue.main.async {
                if let record = record,
                   let nickname = record["nickname"] as? String,
                   let genderRaw = record["gender"] as? Int,
                   let gender = UserGender(rawValue: genderRaw) {
                    
                    let profile = UserProfile(id: record.recordID, nickname: nickname, gender: gender)
                    self?.currentUserProfile = profile
                    print("✅ [CloudKit] 成功載入使用者檔案: \(nickname), \(gender)")
                } else {
                    print("ℹ️ [CloudKit] 尚未建立使用者檔案 (或載入失敗)")
                }
            }
        }
    }
    
    // 儲存或更新使用者檔案
    func saveUserProfile(nickname: String, gender: UserGender, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let currentUserID = currentUserID else {
            completion(.failure(NSError(domain: "CloudKit", code: 401, userInfo: [NSLocalizedDescriptionKey: "未登入 iCloud"])))
            return
        }
        
        let profileRecordID = CKRecord.ID(recordName: currentUserID.recordName, zoneID: CKRecordZone.default().zoneID)
        
        // 先嘗試 fetch 看是否存在
        publicDB.fetch(withRecordID: profileRecordID) { [weak self] existingRecord, error in
            let record: CKRecord
            if let existingRecord = existingRecord {
                record = existingRecord
            } else {
                record = CKRecord(recordType: "UserProfile", recordID: profileRecordID)
            }
            
            record["nickname"] = nickname
            record["gender"] = gender.rawValue
            
            self?.publicDB.save(record) { savedRecord, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ [CloudKit] 儲存使用者檔案失敗: \(error.localizedDescription)")
                        completion(.failure(error))
                    } else {
                        print("✅ [CloudKit] 儲存使用者檔案成功")
                        self?.currentUserProfile = UserProfile(id: profileRecordID, nickname: nickname, gender: gender)
                        completion(.success(true))
                    }
                }
            }
        }
    }
    
    // 批量抓取使用者檔案 (用於評論列表)
    func fetchUserProfiles(userIDs: [String], completion: @escaping ([String: UserProfile]) -> Void) {
        guard !userIDs.isEmpty else {
            completion([:])
            return
        }
        
        // 去除重複 ID
        let uniqueIDs = Array(Set(userIDs))
        let recordIDs = uniqueIDs.map { CKRecord.ID(recordName: $0, zoneID: CKRecordZone.default().zoneID) }
        
        let operation = CKFetchRecordsOperation(recordIDs: recordIDs)
        operation.desiredKeys = ["nickname", "gender"]
        operation.qualityOfService = .userInitiated
        
        var profiles: [String: UserProfile] = [:]
        
        operation.perRecordResultBlock = { recordID, result in
            switch result {
            case .success(let record):
                if let nickname = record["nickname"] as? String,
                   let genderRaw = record["gender"] as? Int,
                   let gender = UserGender(rawValue: genderRaw) {
                    profiles[recordID.recordName] = UserProfile(id: recordID, nickname: nickname, gender: gender)
                }
            case .failure(let error):
                print("⚠️ [CloudKit] 無法抓取使用者 \(recordID.recordName): \(error.localizedDescription)")
            }
        }
        
        operation.fetchRecordsResultBlock = { result in
            DispatchQueue.main.async {
                completion(profiles)
            }
        }
        
        publicDB.add(operation)
    }
    
    // MARK: - Review Management
    
    // 2. 上傳評論（更新：使用固定 recordName 防止重複留言）
    func saveReview(report: LocationReport, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let currentUserID = currentUserID else {
            completion(.failure(NSError(domain: "CloudKit", code: 401, userInfo: [NSLocalizedDescriptionKey: "未登入 iCloud"])))
            return
        }
        
        // 關鍵：使用 locationId + userId 組成唯一的 recordName
        // 這樣同一個使用者對同一個地點只能有一筆評論（更新而非新增）
        let uniqueRecordName = "\(report.locationId.uuidString)_\(currentUserID.recordName)"
        let recordID = CKRecord.ID(recordName: uniqueRecordName, zoneID: CKRecordZone.default().zoneID)
        
        print("📤 [CloudKit] 準備上傳評論...")
        print("   - Record Name (唯一): \(uniqueRecordName)")
        print("   - Location ID: \(report.locationId.uuidString)")
        print("   - Content: \(report.content ?? "無內容")")
        print("   - Tags: \(report.tags)")
        print("   - Gender: \(report.userGender?.title ?? "未設定")")
        
        // 先嘗試 fetch 現有的 record，如果存在就更新，不存在就創建新的
        publicDB.fetch(withRecordID: recordID) { [weak self] existingRecord, fetchError in
            guard let self = self else { return }
            
            let record: CKRecord
            
            if let existingRecord = existingRecord {
                // 找到現有 record，更新它
                print("🔄 [CloudKit] 找到現有評論，執行更新...")
                record = existingRecord
            } else {
                // 沒有現有 record，創建新的
                print("➕ [CloudKit] 沒有現有評論，創建新評論...")
                record = CKRecord(recordType: "Review", recordID: recordID)
            }
            
            // 更新所有欄位
            record["locationId"] = report.locationId.uuidString
            record["type"] = report.type.rawValue
            record["rating"] = report.rating
            record["content"] = report.content ?? ""
            record["userNickname"] = report.userNickname
            
            // 儲存標籤
            record["tags"] = report.tags as CKRecordValue
            
            // 儲存評分詳情（轉成 JSON String）
            if let jsonData = try? JSONSerialization.data(withJSONObject: report.ratingDetails, options: []),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                record["ratingDetails"] = jsonString
            }
            
            // 儲存性別
            if let gender = report.userGender {
                record["userGender"] = gender.rawValue as CKRecordValue
            }
            
            // 儲存地點資訊
            if let locationName = report.locationName {
                record["locationName"] = locationName as CKRecordValue
            }
            if let latitude = report.latitude {
                record["latitude"] = latitude as CKRecordValue
            }
            if let longitude = report.longitude {
                record["longitude"] = longitude as CKRecordValue
            }
            
            // 保存 record
            self.publicDB.save(record) { savedRecord, saveError in
                DispatchQueue.main.async {
                    if let saveError = saveError {
                        print("\n❌ [CloudKit] 上傳評論失敗: \(saveError.localizedDescription)")
                        completion(.failure(saveError))
                    } else {
                        print("\n✅ [CloudKit] 上傳評論成功！")
                        completion(.success(true))
                    }
                }
            }
        }
    }
    
    // 2-1. 檢查使用者是否已對該地點留過言
    func checkExistingReview(for locationId: UUID, completion: @escaping (LocationReport?) -> Void) {
        guard let currentUserID = currentUserID else {
            completion(nil)
            return
        }
        
        let uniqueRecordName = "\(locationId.uuidString)_\(currentUserID.recordName)"
        let recordID = CKRecord.ID(recordName: uniqueRecordName, zoneID: CKRecordZone.default().zoneID)
        
        print("🔍 [CloudKit] 檢查是否已有評論: \(uniqueRecordName)")
        
        publicDB.fetch(withRecordID: recordID) { record, error in
            DispatchQueue.main.async {
                if let record = record {
                    // 找到現有評論，解析並回傳
                    print("✅ [CloudKit] 找到現有評論")
                    
                    guard let locationIdString = record["locationId"] as? String,
                          let locationUUID = UUID(uuidString: locationIdString),
                          let typeString = record["type"] as? String,
                          let type = LocationReport.ReportType(rawValue: typeString),
                          let rating = record["rating"] as? Int,
                          let creationDate = record.creationDate else {
                        completion(nil)
                        return
                    }
                    
                    let creatorID = record.creatorUserRecordID?.recordName ?? "Unknown"
                    let nickname = record["userNickname"] as? String ?? "匿名"
                    let content = record["content"] as? String
                    let tags = record["tags"] as? [String] ?? []
                    
                    var ratingDetails: [String: Int] = [:]
                    if let jsonString = record["ratingDetails"] as? String,
                       let jsonData = jsonString.data(using: .utf8),
                       let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Int] {
                        ratingDetails = dict
                    }
                    
                    var gender: UserGender? = nil
                    if let genderRawValue = record["userGender"] as? Int,
                       let userGender = UserGender(rawValue: genderRawValue) {
                        gender = userGender
                    }
                    
                    let locationName = record["locationName"] as? String
                    let latitude = record["latitude"] as? Double
                    let longitude = record["longitude"] as? Double
                    
                    let existingReport = LocationReport(
                        id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
                        locationId: locationUUID,
                        type: type,
                        rating: rating,
                        content: content,
                        time: creationDate,
                        userNickname: nickname,
                        userId: creatorID,
                        tags: tags,
                        ratingDetails: ratingDetails,
                        userGender: gender,
                        locationName: locationName,
                        latitude: latitude,
                        longitude: longitude
                    )
                    
                    completion(existingReport)
                } else {
                    // 沒有現有評論
                    print("ℹ️ [CloudKit] 沒有現有評論（可以新增）")
                    completion(nil)
                }
            }
        }
    }
    
    // 3. 下載特定地點的評論
    func fetchReviews(for locationId: UUID, completion: @escaping ([LocationReport]) -> Void) {
        // 建立查詢條件：locationId 等於目標 ID
        let predicate = NSPredicate(format: "locationId == %@", locationId.uuidString)
        let query = CKQuery(recordType: "Review", predicate: predicate)
        
        // 按照時間倒序排列 (新的在上面)
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        print("📥 [CloudKit] 開始下載評論 (LocationID: \(locationId.uuidString))...")
        
        publicDB.perform(query, inZoneWith: nil) { records, error in
            if let error = error {
                print("❌ [CloudKit] 下載評論失敗: \(error.localizedDescription)")
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            guard let records = records else {
                print("⚠️ [CloudKit] 下載成功但沒有資料 (Records is nil)")
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            print("✅ [CloudKit] 下載成功，共 \(records.count) 筆資料")
            
            // 將 CKRecord 轉回 LocationReport
            let reports = records.compactMap { record -> LocationReport? in
                guard let locationIdString = record["locationId"] as? String,
                      let locationUUID = UUID(uuidString: locationIdString),
                      let typeString = record["type"] as? String,
                      let type = LocationReport.ReportType(rawValue: typeString),
                      let rating = record["rating"] as? Int,
                      let creationDate = record.creationDate else {
                    
                    return nil
                }
                
                // 相容舊資料：如果沒有 creatorUserRecordID (極少見)，用 Unknown
                let creatorID = record.creatorUserRecordID?.recordName ?? "Unknown"
                
                // 這裡的 userNickname 只是備份，之後會被 Profile 覆蓋
                let nickname = record["userNickname"] as? String ?? "匿名"
                
                let content = record["content"] as? String
                let tags = record["tags"] as? [String] ?? []
                
                var ratingDetails: [String: Int] = [:]
                if let jsonString = record["ratingDetails"] as? String,
                   let jsonData = jsonString.data(using: .utf8),
                   let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Int] {
                    ratingDetails = dict
                }
                
                // 讀取性別（如果有的話）
                var gender: UserGender? = nil
                if let genderRawValue = record["userGender"] as? Int,
                   let userGender = UserGender(rawValue: genderRawValue) {
                    gender = userGender
                }
                
                let locationName = record["locationName"] as? String
                let latitude = record["latitude"] as? Double
                let longitude = record["longitude"] as? Double
                
                return LocationReport(
                    id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
                    locationId: locationUUID,
                    type: type,
                    rating: rating,
                    content: content,
                    time: creationDate,
                    userNickname: nickname,
                    userId: creatorID,
                    tags: tags,
                    ratingDetails: ratingDetails,
                    userGender: gender,
                    locationName: locationName,
                    latitude: latitude,
                    longitude: longitude
                )
            }
            
            DispatchQueue.main.async {
                print("✅ [CloudKit] 解析完成，成功轉換 \(reports.count) 筆 LocationReport")
                completion(reports)
            }
        }
    }
}
