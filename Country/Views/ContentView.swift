//
//  ContentView.swift
//  Country
//
//  Created by Kenny's Macbook on 2024/11/27.
//

import SwiftUI
import MapKit

struct ContentView: View {
    @State private var sheetPresented: Bool = true // 控制 sheet 是否顯示
    @State private var selectedDetent: PresentationDetent = .medium // 預設 detent 尺寸
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 25.0330, longitude: 121.5654), // 台北101
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05) // 地圖縮放範圍（調整為台灣區域）
    )
    @State private var mapType: MKMapType = .standard // 地圖類型（默認為向量地圖）

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 地圖視圖
            MapView(region: $region, mapType: mapType)
                .edgesIgnoringSafeArea(.all)

            // 切換地圖樣式的按鈕
            VStack(spacing: 0) { // 調整按鈕間距
                Button(action: {
                    mapType = .standard // 切換到標準地圖
                }) {
                    Image(systemName: "map") // 地圖圖示
                        .font(.system(size: 15,weight: .heavy)) // 改為較小的字體大小
                        .frame(width: 40, height: 40) // 調整按鈕大小
                        .background(Color.clear)
                        .clipShape(Circle())
                        .foregroundColor(mapType == .standard ? .black : .gray)
                }

                Button(action: {
                    mapType = .satellite // 切換到衛星地圖
                }) {
                    Image(systemName: "cloud") // 衛星圖圖示
                        .font(.system(size: 15, weight: .heavy)) // 改為較小的字體大小
                        .frame(width: 40, height: 40) // 調整按鈕大小
                        .background(mapType == .satellite ? Color.gray.opacity(0) : Color.clear)
                        .clipShape(Circle())
                        .foregroundColor(mapType == .satellite ? .black : .gray)
                }
            }
            .background(Color.white.opacity(0.9))
            .cornerRadius(15)
            .padding(.trailing, 12) // 距離右邊的間距
            .padding(.top, 12) // 距離頂部的間距
        }
        .sheet(isPresented: $sheetPresented) {
            CountryView(sheetPresented: $sheetPresented, selectedDetent: $selectedDetent)
                .presentationDetents([.height(200), .medium, .fraction(0.95)], selection: $selectedDetent)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(15)
                .interactiveDismissDisabled()
        }
    }
}

#Preview {
    ContentView()
}
