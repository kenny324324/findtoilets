//
//  ToiletApp.swift
//  Toilet
//
//  Created by Kenny's Macbook on 2024/11/27.
//

import SwiftUI
import StoreKit
import GoogleMobileAds

@main
struct ToiletApp: App {
    // 建立 PremiumManager 實例
    @StateObject private var premiumManager = PremiumManager()
    @StateObject private var purchaseManager = PurchaseManager()
    
    init() {
        // 初始化 Google Mobile Ads SDK
        MobileAds.shared.start(completionHandler: nil)
        
        // 詳細診斷 CloudKit 環境
        print("\n======== CloudKit 診斷開始 ========")
        if let bundleID = Bundle.main.bundleIdentifier {
            print("📱 App Bundle ID: \(bundleID)")
        }
        
        // 檢查 Entitlements 是否真的生效
        // 注意：我們無法直接讀取 entitlements，但可以檢查是否有 iCloud Token
        let token = FileManager.default.ubiquityIdentityToken
        print("☁️ Ubiquity Identity Token: \(token != nil ? "存在 (代表 iCloud 有開通)" : "不存在 (可能沒開通或沒登入)")")
        
        print("==================================\n")
        
        // 初始化 CloudKit 狀態檢查
        _ = CloudKitManager.shared
    }
    
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
