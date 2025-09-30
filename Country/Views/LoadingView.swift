//
//  LoadingView.swift
//  Country
//
//  Created by Kenny's Macbook on 2024/11/27.
//

import SwiftUI

struct LoadingView: View {
    @ObservedObject var loadingManager: LoadingManager
    
    var body: some View {
        ZStack {
            // 背景漸層
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.1),
                    Color.blue.opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // App 圖示和標題
                VStack(spacing: 20) {
                    // App 圖示
                    Image(systemName: "toilet.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                        .scaleEffect(1.0)
                        .animation(
                            Animation.easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true),
                            value: loadingManager.isLoading
                        )
                    
                    // App 名稱
                    Text("找廁所！")
                        .font(.largeTitleRounded(.bold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // 載入進度區域
                VStack(spacing: 20) {
                    // 載入訊息
                    Text(loadingManager.loadingMessage)
                        .font(.headlineRounded())
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut(duration: 0.3), value: loadingManager.loadingMessage)
                    
                    // 進度條
                    VStack(spacing: 8) {
                        ProgressView(value: loadingManager.loadingProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .scaleEffect(x: 1, y: 2, anchor: .center)
                            .animation(.easeInOut(duration: 0.3), value: loadingManager.loadingProgress)
                        
                        // 進度百分比
                        Text("\(Int(loadingManager.loadingProgress * 100))%")
                            .font(.captionRounded(.medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: 200)
                }
                
                Spacer()
            }
            .padding(.horizontal, 40)
        }
    }
}

#Preview {
    LoadingView(loadingManager: LoadingManager())
}
