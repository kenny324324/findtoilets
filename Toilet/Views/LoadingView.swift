//
//  LoadingView.swift
//  Toilet
//
//  Created by Kenny's Macbook on 2024/12/01.
//

import SwiftUI

struct LoadingView: View {
    @State private var isAnimating = false
    
    // 監聽系統配色方案
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // 背景色：根據系統深淺色模式自動調整
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // App 名稱或 Logo
                Text("Toilet Map")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary) // 自動適應文字顏色（黑/白）
                    .padding(.bottom, 20)
                
                // 動畫長條圖 (模擬音樂頻譜效果)
                HStack(spacing: 6) {
                    ForEach(0..<3) { index in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: "1DB954")) // Spotify Green
                            .frame(width: 6, height: isAnimating ? 40 : 15)
                            .animation(
                                Animation.easeInOut(duration: 0.5)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.2),
                                value: isAnimating
                            )
                    }
                }
                .frame(height: 50)
                
                Spacer()
                
                // 底部文字與進度條
                VStack(spacing: 12) {
                    Text("Almost ready...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary) // 自動適應次要文字顏色
                    
                    // 進度條
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.2)) // 自動適應進度條底色
                            .frame(height: 4)
                        
                        Capsule()
                            .fill(Color(hex: "1DB954"))
                            .frame(width: 100, height: 4) // 固定長度或動態
                            .offset(x: isAnimating ? 200 : -200)
                            .mask(Capsule().frame(width: 200, height: 4)) // 遮罩
                    }
                    .frame(width: 200)
                    .clipShape(Capsule())
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// Color 擴充
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    LoadingView()
}

