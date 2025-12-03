//
//  LoadingView.swift
//  Toilet
//
//  Created by Kenny's Macbook on 2024/12/01.
//

import SwiftUI
import MapKit

struct LoadingView: View {
    @State private var loadingProgress: CGFloat = 0.0
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 25.0330, longitude: 121.5654),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    // 監聽系統配色方案
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // 最底層：地圖背景
            Map(coordinateRegion: .constant(region), interactionModes: [])
                .ignoresSafeArea()
            
            // 中間層：毛玻璃遮罩
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            
            // 最上層：Logo
            VStack {
                Spacer()
                
                GeometryReader { geometry in
                    ZStack {
                        // 底層：灰色的 Logo
                        Image("app_logo")
                            .resizable()
                            .scaledToFit()
                            .colorMultiply(.gray.opacity(0.3))
                        
                        // 上層：彩色的 Logo，從底部往上顯示
                        Image("app_logo")
                            .resizable()
                            .scaledToFit()
                            .mask(
                                VStack(spacing: 0) {
                                    Spacer()
                                    Rectangle()
                                        .frame(height: geometry.size.height * loadingProgress)
                                }
                            )
                    }
                }
                .frame(width: 80, height: 80)
                .offset(x: 5, y: -20) // 向右 5、向上 20
                
                Spacer()
            }
        }
        .onAppear {
            // 載入動畫（稍微延遲開始，確保完整填充）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 2.2)) {
                    loadingProgress = 1.0
                }
            }
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

