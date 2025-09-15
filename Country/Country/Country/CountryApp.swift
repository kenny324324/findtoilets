//
//  CountryApp.swift
//  Country
//
//  Created by Kenny's Macbook on 2024/11/27.
//

import SwiftUI

@main
struct CountryApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // 強制設定為直向
                    UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
                }
        }
    }
}
