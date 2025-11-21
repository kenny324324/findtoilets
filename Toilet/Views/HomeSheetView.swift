//
//  HomeSheetView.swift
//  Toilet
//
//  主畫面 sheet，顯示初始選項
//

import SwiftUI
import CoreLocation

struct HomeSheetView: View {
    @EnvironmentObject var premiumManager: PremiumManager
    @Binding var selectedDetent: PresentationDetent
    @State private var showNearbyList: Bool = false
    @State private var nearbyListDetent: PresentationDetent = .medium
    @ObservedObject var locationManager: LocationManager
    @StateObject private var toiletDataManager = ToiletDataManager() // 預先載入數據管理器
    @Binding var mapToilets: [ToiletInfo]
    @Binding var mapLocations: [ToiletLocation]
    @Binding var selectedToiletFromMap: ToiletInfo?
    @Binding var selectedLocationFromMap: ToiletLocation?
    
    // 預先緩存的附近廁所數據
    @State private var cachedNearbyLocations: [ToiletLocation] = []
    @State private var cachedNearbyLocationsWithDistance: [(ToiletLocation, Int)] = []
    
    // 搜尋相關狀態
    @State private var searchText: String = ""
    @State private var searchResults: [ToiletLocation] = []
    @State private var isSearching: Bool = false
    @State private var showSearchResults: Bool = false
    @State private var searchResultsDetent: PresentationDetent = .medium
    
    // 設定相關狀態
    @State private var showingSettings = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 20) {
                    Button(action: {
                        selectedDetent = .medium
                        DispatchQueue.main.async {
                            showNearbyList = true
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 24))
                            Text("查看附近")
                                .font(.headlineRounded(.semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer()
            }
            .background(Color.clear)
            .navigationTitle(LocalizedStrings.appTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: handleSettingsTap) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .searchable(text: $searchText, placement: .automatic, prompt: LocalizedStrings.searchPlaceholder.localized)
        .onChange(of: searchText, perform: performSearch)
        .onAppear(perform: preloadNearbyToilets)
        .onChange(of: locationManager.location) { _ in
            preloadNearbyToilets()
        }
        .sheet(isPresented: $showNearbyList) {
            NearbyListView(
                locationManager: locationManager,
                toiletDataManager: toiletDataManager,
                mapToilets: $mapToilets,
                mapLocations: $mapLocations,
                selectedToiletFromMap: $selectedToiletFromMap,
                selectedLocationFromMap: $selectedLocationFromMap,
                rootDetent: $selectedDetent,
                parentDetent: $nearbyListDetent,
                preloadedNearbyLocations: cachedNearbyLocations,
                preloadedNearbyLocationsWithDistance: cachedNearbyLocationsWithDistance
            )
            .environmentObject(premiumManager)
            .presentationDetents([.height(200), .medium, .large], selection: $nearbyListDetent)
            .presentationBackgroundInteraction(.enabled)
            .presentationDragIndicator(.hidden)
            .presentationCompactAdaptation(.sheet)
            .presentationContentInteraction(.scrolls)
            .presentationBackground(Color.white.opacity(0.2))
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showSearchResults) {
            SearchResultsView(
                locationManager: locationManager,
                toiletDataManager: toiletDataManager,
                searchResults: searchResults,
                isSearching: isSearching,
                mapToilets: $mapToilets,
                mapLocations: $mapLocations,
                selectedToiletFromMap: $selectedToiletFromMap,
                selectedLocationFromMap: $selectedLocationFromMap,
                rootDetent: $selectedDetent,
                parentDetent: $searchResultsDetent
            )
            .environmentObject(premiumManager)
            .presentationDetents([.height(200), .medium, .large], selection: $searchResultsDetent)
            .presentationBackgroundInteraction(.enabled)
            .presentationDragIndicator(.hidden)
            .presentationCompactAdaptation(.sheet)
            .presentationContentInteraction(.scrolls)
            .presentationBackground(Color.white.opacity(0.2))
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(premiumManager)
                .interactiveDismissDisabled(true)
        }
    }
    
    // 處理設定按鈕點擊
    private func handleSettingsTap() {
        showingSettings = true
    }
    
    // 執行搜尋
    private func performSearch(query: String) {
        if query.isEmpty {
            searchResults = []
            isSearching = false
            showSearchResults = false
            return
        }
        
        isSearching = true
        selectedDetent = .medium
        showSearchResults = true
        
        // 在後台線程執行搜尋
        DispatchQueue.global(qos: .userInitiated).async {
            let results = toiletDataManager.searchLocations(query: query)
            
            let sortedResults: [ToiletLocation]
            if locationManager.location != nil {
                sortedResults = results.sorted { first, second in
                    let firstDistance = self.calculateDistanceForLocation(first)
                    let secondDistance = self.calculateDistanceForLocation(second)
                    return firstDistance < secondDistance
                }
            } else {
                sortedResults = results
            }
            
            // 回到主線程更新結果
            DispatchQueue.main.async {
                self.searchResults = sortedResults
                self.isSearching = false
            }
        }
    }
    
    // 計算地點的距離
    private func calculateDistanceForLocation(_ location: ToiletLocation) -> Int {
        guard let userLocation = locationManager.location else {
            return 999999
        }
        
        guard let firstToilet = location.allToilets.first else {
            return 999999
        }
        
        return toiletDataManager.calculateDistance(from: userLocation, to: firstToilet)
    }
    
    // 預先載入附近廁所數據
    private func preloadNearbyToilets() {
        guard locationManager.authorizationStatus == .authorizedWhenInUse || 
              locationManager.authorizationStatus == .authorizedAlways else {
            return
        }
        
        guard let userLocation = locationManager.location else {
            return
        }
        
        // 在後台線程執行計算
        DispatchQueue.global(qos: .userInitiated).async {
            let locationsWithDistance = toiletDataManager.findNearbyLocationsWithDistance(userLocation: userLocation, radius: 1000)
            let locations = locationsWithDistance.map { $0.0 }
            
            // 回到主線程更新緩存
            DispatchQueue.main.async {
                self.cachedNearbyLocationsWithDistance = locationsWithDistance
                self.cachedNearbyLocations = locations
            }
        }
    }
}

// 附近列表視圖
struct NearbyListView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var premiumManager: PremiumManager
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var toiletDataManager: ToiletDataManager // 接收共享的數據管理器
    @Binding var mapToilets: [ToiletInfo]
    @Binding var mapLocations: [ToiletLocation]
    @Binding var selectedToiletFromMap: ToiletInfo?
    @Binding var selectedLocationFromMap: ToiletLocation?
    @Binding var rootDetent: PresentationDetent
    @Binding var parentDetent: PresentationDetent
    
    // 接收預先載入的數據
    let preloadedNearbyLocations: [ToiletLocation]
    let preloadedNearbyLocationsWithDistance: [(ToiletLocation, Int)]
    
    @State private var nearbyLocations: [ToiletLocation] = []
    @State private var nearbyLocationsWithDistance: [(ToiletLocation, Int)] = []
    @State private var showingSettings = false
    @State private var selectedToiletForDetail: ToiletInfo? = nil
    @State private var toiletDetailDetent: PresentationDetent = .medium
    @State private var selectedLocationForDetail: ToiletLocation? = nil
    @State private var locationDetailDetent: PresentationDetent = .medium
    @State private var settingsTapCount = 0
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "location.slash")
                            .font(.customRounded(50))
                            .foregroundColor(.gray)
                        Text(LocalizedStrings.locationPermissionRequired.localized)
                            .font(.headlineRounded())
                            .padding(.top)
                        Text(LocalizedStrings.locationPermissionDescription.localized)
                            .font(.subheadlineRounded())
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        
                        Button(LocalizedStrings.goToSettings.localized) {
                            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsUrl)
                            }
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // 預設顯示附近公廁
                    if toiletDataManager.isLoading {
                        VStack {
                            Spacer()
                            ProgressView(LocalizedStrings.loadingToilets.localized)
                                .font(.subheadlineRounded())
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        if locationManager.isLocating {
                            VStack {
                                Spacer()
                                ProgressView(LocalizedStrings.locating.localized)
                                    .font(.subheadlineRounded())
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            if nearbyLocations.isEmpty {
                                VStack {
                                    Spacer()
                                    Image(systemName: "location.slash")
                                        .font(.customRounded(50))
                                        .foregroundColor(.gray)
                                    Text(LocalizedStrings.needLocationForNearby.localized)
                                        .font(.headlineRounded())
                                        .padding(.top)
                                    Text(LocalizedStrings.pressLocationButton.localized)
                                        .font(.subheadlineRounded())
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .onAppear {
                                    mapToilets = []
                                    mapLocations = []
                                }
                            } else {
                                ScrollView {
                                    LazyVStack(spacing: 0) {
                                        ForEach(nearbyLocationsWithDistance, id: \.0.id) { locationWithDistance in
                                            Button(action: {
                                                presentLocationDetail(locationWithDistance.0)
                                            }) {
                                                LocationRowView(location: locationWithDistance.0, distance: locationWithDistance.1)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                }
                                .background(Color.clear)
                                .onAppear {
                                    mapToilets = nearbyLocations.flatMap { $0.allToilets }
                                    mapLocations = nearbyLocations
                                }
                            }
                        }
                    }
                }
            }
            .background(Color.clear)
            .navigationTitle(LocalizedStrings.nearbyToiletsTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        handleSettingsTap()
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .onChange(of: locationManager.location) { _ in
            updateNearbyToilets()
        }
        .onChange(of: locationManager.authorizationStatus) { status in
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                updateNearbyToilets()
            } else if status == .denied || status == .restricted {
                nearbyLocations = []
                nearbyLocationsWithDistance = []
            }
        }
        .onChange(of: selectedToiletFromMap) { newToilet in
            if let toilet = newToilet {
                presentToiletDetail(toilet)
                selectedToiletFromMap = nil
            }
        }
        .onChange(of: selectedLocationFromMap) { newLocation in
            if let location = newLocation {
                presentLocationDetail(location)
                selectedLocationFromMap = nil
            }
        }
        .onAppear {
            // 直接使用預先載入的數據，無需重新計算
            nearbyLocations = preloadedNearbyLocations
            nearbyLocationsWithDistance = preloadedNearbyLocationsWithDistance
            
            // 立即更新地圖
            mapToilets = nearbyLocations.flatMap { $0.allToilets }
            mapLocations = nearbyLocations
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(premiumManager)
                .interactiveDismissDisabled(true)
        }
        .sheet(item: $selectedToiletForDetail) { toilet in
            ToiletDetailView(toilet: toilet)
                .presentationDetents([.height(200), .medium, .large], selection: $toiletDetailDetent)
                .presentationBackgroundInteraction(.enabled)
                .presentationDragIndicator(.hidden)
                .presentationCompactAdaptation(.sheet)
                .presentationContentInteraction(.scrolls)
                .presentationBackground(Color.white.opacity(0.2))
                .onAppear {
                    // 確保打開時是 medium 高度
                    toiletDetailDetent = .medium
                }
        }
        .sheet(item: $selectedLocationForDetail) { location in
            LocationDetailView(location: location, locationDetailDetent: $locationDetailDetent)
                .presentationDetents([.height(200), .medium, .large], selection: $locationDetailDetent)
                .presentationBackgroundInteraction(.enabled)
                .presentationDragIndicator(.hidden)
                .presentationCompactAdaptation(.sheet)
                .presentationContentInteraction(.scrolls)
                .presentationBackground(Color.white.opacity(0.2))
                .interactiveDismissDisabled()
                .onAppear {
                    // 確保打開時是 medium 高度
                    locationDetailDetent = .medium
                }
        }
    }
    
    // 更新附近地點緩存（優化版本，在後台線程執行）
    private func updateNearbyToilets() {
        guard locationManager.authorizationStatus == .authorizedWhenInUse || 
              locationManager.authorizationStatus == .authorizedAlways else {
            nearbyLocations = []
            nearbyLocationsWithDistance = []
            return
        }
        
        guard let userLocation = locationManager.location else {
            nearbyLocations = []
            nearbyLocationsWithDistance = []
            return
        }
        
        // 在後台線程執行計算
        DispatchQueue.global(qos: .userInitiated).async {
            let locationsWithDistance = self.toiletDataManager.findNearbyLocationsWithDistance(userLocation: userLocation, radius: 1000)
            let locations = locationsWithDistance.map { $0.0 }
            
            // 回到主線程更新 UI
            DispatchQueue.main.async {
                self.nearbyLocationsWithDistance = locationsWithDistance
                self.nearbyLocations = locations
                
                self.mapToilets = self.nearbyLocations.flatMap { $0.allToilets }
                self.mapLocations = self.nearbyLocations
            }
        }
    }
    
    // 計算地點的距離
    private func getRealDistanceForLocation(_ location: ToiletLocation) -> Int {
        guard let userLocation = locationManager.location else {
            return 999999
        }
        
        guard let firstToilet = location.allToilets.first else {
            return 999999
        }
        
        return toiletDataManager.calculateDistance(from: userLocation, to: firstToilet)
    }
    
    // 處理設定按鈕點擊
    private func handleSettingsTap() {
        settingsTapCount += 1
        showingSettings = true
    }
    
    // MARK: - Sheet Presentation Helpers
    private func presentLocationDetail(_ location: ToiletLocation) {
        rootDetent = .medium
        parentDetent = .medium
        locationDetailDetent = .medium
        selectedLocationForDetail = nil
        DispatchQueue.main.async {
            selectedLocationForDetail = location
        }
    }
    
    private func presentToiletDetail(_ toilet: ToiletInfo) {
        rootDetent = .medium
        parentDetent = .medium
        toiletDetailDetent = .medium
        selectedToiletForDetail = nil
        DispatchQueue.main.async {
            selectedToiletForDetail = toilet
        }
    }
}

// 搜尋結果視圖
struct SearchResultsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var premiumManager: PremiumManager
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var toiletDataManager: ToiletDataManager
    let searchResults: [ToiletLocation]
    let isSearching: Bool
    @Binding var mapToilets: [ToiletInfo]
    @Binding var mapLocations: [ToiletLocation]
    @Binding var selectedToiletFromMap: ToiletInfo?
    @Binding var selectedLocationFromMap: ToiletLocation?
    @Binding var rootDetent: PresentationDetent
    @Binding var parentDetent: PresentationDetent
    
    @State private var selectedToiletForDetail: ToiletInfo? = nil
    @State private var toiletDetailDetent: PresentationDetent = .medium
    @State private var selectedLocationForDetail: ToiletLocation? = nil
    @State private var locationDetailDetent: PresentationDetent = .medium
    
    var body: some View {
        NavigationStack {
            GeometryReader { _ in
                Group {
                    if isSearching {
                        CustomLoadingView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if searchResults.isEmpty {
                        VStack {
                            Spacer()
                            Image(systemName: "magnifyingglass")
                                .font(.customRounded(50))
                                .foregroundColor(.gray)
                            Text(LocalizedStrings.noToiletsFound.localized)
                                .font(.headlineRounded())
                                .padding(.top)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(searchResults, id: \.id) { location in
                                    Button(action: {
                                        presentLocationDetail(location)
                                    }) {
                                        LocationRowView(location: location, distance: getRealDistanceForLocation(location))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .background(Color.clear)
                        .onAppear {
                            mapToilets = searchResults.flatMap { $0.allToilets }
                            mapLocations = searchResults
                        }
                    }
                }
            }
            .background(Color.clear)
            .navigationTitle("搜尋結果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .onChange(of: selectedToiletFromMap) { newToilet in
            if let toilet = newToilet {
                presentToiletDetail(toilet)
                selectedToiletFromMap = nil
            }
        }
        .onChange(of: selectedLocationFromMap) { newLocation in
            if let location = newLocation {
                presentLocationDetail(location)
                selectedLocationFromMap = nil
            }
        }
        .sheet(item: $selectedToiletForDetail) { toilet in
            ToiletDetailView(toilet: toilet)
                .presentationDetents([.height(200), .medium, .large], selection: $toiletDetailDetent)
                .presentationBackgroundInteraction(.enabled)
                .presentationDragIndicator(.hidden)
                .presentationCompactAdaptation(.sheet)
                .presentationContentInteraction(.scrolls)
                .presentationBackground(Color.white.opacity(0.2))
                .onAppear {
                    // 確保打開時是 medium 高度
                    toiletDetailDetent = .medium
                }
        }
        .sheet(item: $selectedLocationForDetail) { location in
            LocationDetailView(location: location, locationDetailDetent: $locationDetailDetent)
                .presentationDetents([.height(200), .medium, .large], selection: $locationDetailDetent)
                .presentationBackgroundInteraction(.enabled)
                .presentationDragIndicator(.hidden)
                .presentationCompactAdaptation(.sheet)
                .presentationContentInteraction(.scrolls)
                .presentationBackground(Color.white.opacity(0.2))
                .interactiveDismissDisabled()
                .onAppear {
                    // 確保打開時是 medium 高度
                    locationDetailDetent = .medium
                }
        }
    }
    
    // 計算地點的距離
    private func getRealDistanceForLocation(_ location: ToiletLocation) -> Int {
        guard let userLocation = locationManager.location else {
            return 999999
        }
        
        guard let firstToilet = location.allToilets.first else {
            return 999999
        }
        
        return toiletDataManager.calculateDistance(from: userLocation, to: firstToilet)
    }
    
    // MARK: - Sheet Presentation Helpers
    private func presentLocationDetail(_ location: ToiletLocation) {
        rootDetent = .medium
        parentDetent = .medium
        locationDetailDetent = .medium
        selectedLocationForDetail = nil
        DispatchQueue.main.async {
            selectedLocationForDetail = location
        }
    }
    
    private func presentToiletDetail(_ toilet: ToiletInfo) {
        rootDetent = .medium
        parentDetent = .medium
        toiletDetailDetent = .medium
        selectedToiletForDetail = nil
        DispatchQueue.main.async {
            selectedToiletForDetail = toilet
        }
    }
}

#Preview {
    HomeSheetView(
        selectedDetent: .constant(.medium),
        locationManager: LocationManager(),
        mapToilets: .constant([]),
        mapLocations: .constant([]),
        selectedToiletFromMap: .constant(nil),
        selectedLocationFromMap: .constant(nil)
    )
    .environmentObject(PremiumManager())
}
