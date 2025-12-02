//
//  CloudKitManager.swift
//  Toilet
//
//  Created by Cursor on 2024/12/02.
//

import Foundation
import CloudKit
import Combine

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
                }
            } else if let error = error {
                print("\n⚠️ [CloudKit] 身分驗證失敗: \(error.localizedDescription)")
            }
        }
    }
    
    // 2. 上傳評論
    func saveReview(report: LocationReport, completion: @escaping (Result<Bool, Error>) -> Void) {
        // 將 LocationReport 轉換為 CKRecord
        let record = CKRecord(recordType: "Review")
        
        // 儲存欄位
        record["locationId"] = report.locationId.uuidString
        record["type"] = report.type.rawValue
        record["rating"] = report.rating
        record["content"] = report.content ?? ""
        record["userNickname"] = report.userNickname
        
        // 新增：儲存標籤與評分詳情
        record["tags"] = report.tags as CKRecordValue
        // CloudKit 不直接支援 Dictionary，我們轉成 JSON String 存
        if let jsonData = try? JSONSerialization.data(withJSONObject: report.ratingDetails, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            record["ratingDetails"] = jsonString
        }
        
        // note: time 會使用系統的 creationDate，userId 會使用系統的 creatorUserRecordID
        
        print("📤 [CloudKit] 準備上傳評論...")
        print("   - Location ID: \(report.locationId.uuidString)")
        print("   - Content: \(report.content ?? "無內容")")
        print("   - Tags: \(report.tags)")
        
        publicDB.save(record) { savedRecord, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("\n❌ [CloudKit] 上傳評論失敗: \(error.localizedDescription)")
                    completion(.failure(error))
                } else {
                    print("\n✅ [CloudKit] 上傳評論成功！")
                    print("   -> 資料已存入雲端 Public Database。")
                    print("   -> 請至 CloudKit Dashboard 查看: https://icloud.developer.apple.com/dashboard/")
                    print("   -> 進入後選擇 'Public Database' -> 左側選 'Review' -> 按 'Query Records' 查詢\n")
                    completion(.success(true))
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
        // 注意：這需要在 CloudKit Dashboard 將 createdTimestamp 設為 Sortable
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
                // 詳細除錯：印出每一筆資料的欄位，確認是否有缺
                /*
                print("   - Record ID: \(record.recordID.recordName)")
                print("     Keys: \(record.allKeys())")
                */
                
                guard let locationIdString = record["locationId"] as? String,
                      let locationUUID = UUID(uuidString: locationIdString),
                      let typeString = record["type"] as? String,
                      let type = LocationReport.ReportType(rawValue: typeString),
                      let rating = record["rating"] as? Int,
                      let nickname = record["userNickname"] as? String,
                      let creationDate = record.creationDate else { // 注意：creationDate 是系統屬性，不是自訂欄位
                    
                    print("⚠️ [CloudKit] 解析失敗，跳過此筆資料 (ID: \(record.recordID.recordName))")
                    print("     缺少必要欄位。現有欄位: \(record.allKeys())")
                    return nil
                }
                
                let creatorID = record.creatorUserRecordID?.recordName ?? "Unknown"
                let content = record["content"] as? String
                let tags = record["tags"] as? [String] ?? []
                
                var ratingDetails: [String: Int] = [:]
                if let jsonString = record["ratingDetails"] as? String,
                   let jsonData = jsonString.data(using: .utf8),
                   let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Int] {
                    ratingDetails = dict
                }
                
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
                    ratingDetails: ratingDetails
                )
            }
            
            DispatchQueue.main.async {
                print("✅ [CloudKit] 解析完成，成功轉換 \(reports.count) 筆 LocationReport")
                completion(reports)
            }
        }
    }
}
