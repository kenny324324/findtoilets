//
//  LoadingManager.swift
//  Country
//
//  Created by Kenny's Macbook on 2024/11/27.
//

import Foundation
import SwiftUI

class LoadingManager: ObservableObject {
    @Published var isLoading = true
    @Published var loadingProgress: Double = 0.0
    @Published var loadingMessage = ""
    
    private var loadingSteps = [
        "初始化應用程式...",
        "載入公廁資料...",
        "準備地圖服務...",
        "載入完成"
    ]
    
    private var currentStep = 0
    
    func startLoading() {
        isLoading = true
        loadingProgress = 0.0
        currentStep = 0
        
        // 開始載入流程
        loadNextStep()
    }
    
    private func loadNextStep() {
        guard currentStep < loadingSteps.count else {
            // 所有步驟完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isLoading = false
            }
            return
        }
        
        // 更新載入訊息
        loadingMessage = loadingSteps[currentStep]
        
        // 模擬載入時間
        let stepDuration = currentStep == 0 ? 0.5 : 1.0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration) {
            self.loadingProgress = Double(self.currentStep + 1) / Double(self.loadingSteps.count)
            self.currentStep += 1
            self.loadNextStep()
        }
    }
}
