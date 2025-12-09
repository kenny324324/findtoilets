//
//  LoadingView.swift
//  Toilet
//
//  Created by Kenny's Macbook on 2024/12/01.
//

import SwiftUI
import MapKit

struct LoadingView: View {
    var isDataLoaded: Bool // 外部通知：資料好了沒
    var onAnimationComplete: (() -> Void)? // 內部通知：動畫跑完了
    
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
            // 階段一：模擬載入
            // 先在 2.0 秒內跑到 80%，讓使用者感覺有在動，但留一點空間給最後衝刺
            // 如果資料已經好了，這個動畫會立刻被下面的 onChange 覆蓋
            if !isDataLoaded {
                withAnimation(.easeInOut(duration: 2.0)) {
                    loadingProgress = 0.8
                }
            } else {
                // 如果一進來資料就已經好了（秒開），直接填滿
                finishAnimation()
            }
        }
        .onChange(of: isDataLoaded) { loaded in
            if loaded {
                finishAnimation()
            }
        }
    }
    
    private func finishAnimation() {
        // 階段二：資料好了，加速衝刺！
        // 無論目前在哪，都在 0.5 秒內填滿剩下的部分
        withAnimation(.easeOut(duration: 0.5)) {
            loadingProgress = 1.0
        }
        
        // 等待動畫跑完後，通知外部
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            onAnimationComplete?()
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
    LoadingView(isDataLoaded: false, onAnimationComplete: {})
}

