//
//  CountryApp.swift
//  Country
//
//  Created by Kenny's Macbook on 2024/11/27.
//

import SwiftUI

@main
struct CountryApp: App {
    @StateObject private var loadingManager = LoadingManager()
    
    var body: some Scene {
        WindowGroup {
            if loadingManager.isLoading {
                LoadingView(loadingManager: loadingManager)
                    .onAppear {
                        // 強制設定為直向
                        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
                        // 開始載入流程
                        loadingManager.startLoading()
                    }
            } else {
                ContentView()
                    .onAppear {
                        // 強制設定為直向
                        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
                    }
            }
        }
    }
}
