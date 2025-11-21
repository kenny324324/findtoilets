//
//  ToiletApp.swift
//  Toilet
//
//  Created by Kenny's Macbook on 2024/11/27.
//

import SwiftUI
import StoreKit

@main
struct ToiletApp: App {
    // 建立 PremiumManager 實例
    @StateObject private var premiumManager = PremiumManager()
    @StateObject private var purchaseManager = PurchaseManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(premiumManager) // 注入到整個 App
                .environmentObject(purchaseManager)
                .onAppear {
                    // 強制設定為直向
                    UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
                    // 啟動後同步一次購買狀態
                    Task { @MainActor in
                        await purchaseManager.refreshPurchasedState()
                        premiumManager.updateFromPurchaseState(isPurchased: purchaseManager.isPurchased)
                    }
                }
                .onChange(of: purchaseManager.isPurchased) { newValue in
                    // 當交易變化時更新 Premium 狀態
                    premiumManager.updateFromPurchaseState(isPurchased: newValue)
                }
        }
    }
}
