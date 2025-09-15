//
//  ToiletInfo.swift
//  Country
//
//  Created by Kenny's Macbook on 2024/11/27.
//

import Foundation
import SwiftUI

// 台灣公廁資料模型
struct ToiletInfo: Codable, Identifiable, Equatable {
    let id = UUID() // 為 SwiftUI List 提供唯一識別符
    let county: String          // 縣市代碼
    let city: String            // 鄉鎮市區代碼
    let village: String         // 村里
    let number: String          // 公廁編號
    let name: String            // 公廁名稱
    let address: String         // 完整地址
    let administration: String  // 管理單位
    let latitude: String        // 緯度
    let longitude: String       // 經度
    let grade: String           // 等級（特優級等）
    let type2: String           // 場所類型（宗教禮儀場所、商業營業場所等）
    let type: String            // 廁所類型（女廁所、男廁所等）
    let exec: String            // 執行單位
    let diaper: String          // 是否有尿布台（"0"=無，"1"=有）
    
    // 計算屬性：將字串轉換為 Double 座標
    var latitudeDouble: Double {
        return Double(latitude) ?? 0.0
    }
    
    var longitudeDouble: Double {
        return Double(longitude) ?? 0.0
    }
    
    // 計算屬性：是否有尿布台
    var hasDiaperStation: Bool {
        return diaper == "1"
    }
    
    // 計算屬性：等級顯示文字
    var gradeDisplayText: String {
        switch grade {
        case "特優級":
            return "star.fill 特優級"
        case "優級":
            return "sparkles 優級"
        case "良級":
            return "hand.thumbsup 良級"
        case "普級":
            return "doc.text 普級"
        default:
            return "doc.text \(grade)"
        }
    }
    
    // 計算屬性：場所類型圖示
    var type2Icon: String {
        switch type2 {
        case "宗教禮儀場所":
            return "building.columns"
        case "商業營業場所":
            return "storefront"
        case "交通運輸場站":
            return "bus"
        case "觀光遊憩場所":
            return "tree"
        case "教育場所":
            return "graduationcap"
        case "醫療場所":
            return "cross"
        case "政府機關場所":
            return "building.2"
        case "運動場所":
            return "sportscourt"
        case "其他":
            return "mappin"
        default:
            return "mappin"
        }
    }
    
    // 計算屬性：廁所類型圖示
    var typeIcon: String {
        switch type {
        case "女廁所":
            return "figure.stand"
        case "男廁所":
            return "figure.stand"
        case "親子廁所":
            return "figure.and.child.holdinghands"
        case "無障礙廁所":
            return "figure.roll"
        case "混合廁所":
            return "toilet"
        case "性別友善廁所":
            return "person.2.fill"
        default:
            return "figure.stand"
        }
    }
    
    // 計算屬性：廁所類型顏色
    var typeColor: Color {
        switch type {
        case "女廁所":
            return .red
        case "男廁所":
            return .blue
        case "親子廁所":
            return .green
        case "無障礙廁所":
            return .gray
        case "混合廁所":
            return .orange
        case "性別友善廁所":
            return .purple
        default:
            return .blue
        }
    }
    
    // 計算屬性：評級顏色
    var gradeColor: Color {
        return .secondary // 統一的次要文字顏色
    }
    
    // 計算屬性：場所類型顏色
    var type2Color: Color {
        return .secondary // 統一的次要文字顏色
    }
}
