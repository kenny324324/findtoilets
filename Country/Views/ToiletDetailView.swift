//
//  ToiletDetailView.swift
//  Country
//
//  Created by Kenny's Macbook on 2024/11/27.
//

import SwiftUI

struct ToiletDetailView: View {
    let toilet: ToiletInfo
    @Environment(\.dismiss) private var dismiss // 用於控制返回操作

    var body: some View {
        VStack(spacing: 0) {
            // 固定的標題欄
            VStack(spacing: 16) {
                // 標題 + 返回按鈕
                HStack(spacing: 16) {
                    Button(action: {
                        dismiss() // 返回上一頁
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .fontWeight(.semibold)
                            .frame(width: 30, height: 30)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(Circle())
                    }
                    
                    Text(getCleanToiletName(toilet.name))
                        .font(.title.weight(.semibold))
                        .fontDesign(.rounded)
                        .bold()
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            .background(Color(.systemBackground))
            
            // 分格線
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 0.5)
            
            // 可捲動的內容區域
            ScrollView {
                VStack(spacing: 20) {
                    // 公廁詳細資訊
                    VStack(alignment: .leading, spacing: 20) {
                    // 基本資訊卡片
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: toilet.typeIcon)
                                .font(.largeTitle)
                                .foregroundColor(toilet.typeColor)
                                .frame(width: 60, height: 60)
                                .background(toilet.typeColor.opacity(0.2))
                                .cornerRadius(15)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(toilet.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .fontDesign(.rounded)
                                
                                HStack(spacing: 4) {
                                    Image(systemName: toilet.gradeDisplayText.components(separatedBy: " ").first ?? "star")
                                        .font(.subheadline)
                                        .foregroundColor(.yellow)
                                    Text(toilet.gradeDisplayText.components(separatedBy: " ").dropFirst().joined(separator: " "))
                                        .font(.subheadline)
                                        .foregroundColor(.yellow)
                                        .fontWeight(.semibold)
                                }
                            }
                            Spacer()
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "location")
                                    .foregroundColor(.red)
                                    .font(.body)
                                Text(toilet.address)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .fontDesign(.rounded)
                            }
                            
                            HStack {
                                Image(systemName: "building.2")
                                    .foregroundColor(.blue)
                                    .font(.body)
                                Text("管理單位：\(toilet.administration)")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .fontDesign(.rounded)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(16)
                    
                    // 設施資訊卡片
                    VStack(alignment: .leading, spacing: 12) {
                        Text("設施資訊")
                            .font(.headline)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: toilet.type2Icon)
                                    .font(.title3)
                                    .foregroundColor(toilet.type2Color)
                                Text("場所類型：\(toilet.type2)")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .fontDesign(.rounded)
                            }
                            
                            HStack {
                                Image(systemName: toilet.typeIcon)
                                    .font(.title3)
                                    .foregroundColor(toilet.typeColor)
                                Text("廁所類型：\(toilet.type)")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .fontDesign(.rounded)
                            }
                            
                            HStack {
                                Image(systemName: toilet.hasDiaperStation ? "checkmark.circle.fill" : "xmark.circle")
                                    .foregroundColor(toilet.hasDiaperStation ? .green : .red)
                                    .font(.body)
                                Text(toilet.hasDiaperStation ? "有尿布台" : "無尿布台")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .fontDesign(.rounded)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(16)
                    
                    // 位置資訊卡片
                    VStack(alignment: .leading, spacing: 12) {
                        Text("位置資訊")
                            .font(.headline)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "map")
                                    .foregroundColor(.orange)
                                    .font(.body)
                                Text("經緯度：\(toilet.latitude), \(toilet.longitude)")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .fontDesign(.rounded)
                            }
                            
                            HStack {
                                Image(systemName: "house")
                                    .foregroundColor(.purple)
                                    .font(.body)
                                Text("行政區：\(toilet.village)")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .fontDesign(.rounded)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    // 清理廁所名稱，移除類型後綴
    private func getCleanToiletName(_ name: String) -> String {
        let suffixes = ["-女廁", "-男廁", "-親子廁所", "-無障礙廁所", "-通用廁所"]
        var cleanName = name
        for suffix in suffixes {
            if cleanName.hasSuffix(suffix) {
                cleanName = String(cleanName.dropLast(suffix.count))
                break
            }
        }
        return cleanName
    }
}

#Preview {
    ToiletDetailView(toilet: ToiletInfo(
        county: "10001",
        city: "1000101",
        village: "信義區",
        number: "DEMO001",
        name: "台北101-女廁",
        address: "台北市信義區信義路五段7號",
        administration: "台北101",
        latitude: "25.0330",
        longitude: "121.5654",
        grade: "特優級",
        type2: "商業營業場所",
        type: "女廁所",
        exec: "台北101",
        diaper: "1"
    ))
}
