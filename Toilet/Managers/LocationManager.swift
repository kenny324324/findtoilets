import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    
    @Published var location: CLLocation?
    @Published var freshLocation: CLLocation? // 只從 GPS 回調設定，不從快取載入
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocating: Bool = false
    @Published var errorMessage: String?

    private var pendingLocationCallback: ((CLLocation) -> Void)?
    
    override init() {
        super.init()
        locationManager.delegate = self
        // 使用較低的精度以提升定位速度
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        // 設定距離過濾器，減少不必要的更新
        locationManager.distanceFilter = 10
        authorizationStatus = locationManager.authorizationStatus
        
        // 載入最後已知位置
        loadLastKnownLocation()
        
        print("LocationManager 初始化，權限狀態：\(authorizationStatus.rawValue)")
        
        // 如果權限未確定，立即請求
        if authorizationStatus == .notDetermined {
            print("初始化時請求權限")
            requestLocationPermission()
        }
    }
    
    private func loadLastKnownLocation() {
        let lat = UserDefaults.standard.double(forKey: "LastLat")
        let lon = UserDefaults.standard.double(forKey: "LastLon")
        // 檢查座標是否有效（非 0.0）
        if lat != 0.0 && lon != 0.0 {
            self.location = CLLocation(latitude: lat, longitude: lon)
            print("已載入最後已知位置：\(lat), \(lon)")
        }
    }

    func requestLocationPermission() {
        print("請求位置權限...")
        print("當前權限狀態：\(locationManager.authorizationStatus.rawValue)")
        
        // 直接請求權限，不使用 DispatchQueue
        locationManager.requestWhenInUseAuthorization()
        print("已調用 requestWhenInUseAuthorization")
        
        // 延遲檢查權限狀態變化
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("1秒後權限狀態：\(self.locationManager.authorizationStatus.rawValue)")
        }
    }
    
    func startLocationUpdates() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestLocationPermission()
            return
        }
        
        isLocating = true
        errorMessage = nil
        locationManager.startUpdatingLocation()
    }
    
    func stopLocationUpdates() {
        isLocating = false
        locationManager.stopUpdatingLocation()
    }
    
    func getCurrentLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            print("權限不足，請求權限")
            requestLocationPermission()
            return
        }
        
        print("開始定位流程")
        isLocating = true
        errorMessage = nil
        
        // 先嘗試快速定位
        print("嘗試快速定位...")
        locationManager.requestLocation()
        
        // 縮短超時時間到2秒，提升用戶體驗
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if self.isLocating && self.location == nil {
                print("快速定位失敗，開始持續定位...")
                self.locationManager.startUpdatingLocation()
            }
        }
        
        // 額外的超時保護，避免定位卡住
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
            if self.isLocating {
                print("定位超時，停止定位")
                self.isLocating = false
                self.errorMessage = LocalizedStrings.locationTimeout.localized
                self.locationManager.stopUpdatingLocation()
            }
        }
    }
    
    // 快速定位方法（使用 callback 取代 timer 輪詢）
    func getQuickLocation(completion: ((CLLocation) -> Void)? = nil) {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            print("權限不足，請求權限")
            requestLocationPermission()
            return
        }

        print("開始快速定位流程")
        isLocating = true
        errorMessage = nil
        freshLocation = nil // 清除舊的 fresh location
        pendingLocationCallback = completion

        // 固定使用 hundredMeters，不切換精度（避免 race condition）
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.requestLocation()

        // 超時保護（5 秒）
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard let self = self, self.isLocating else { return }
            print("快速定位超時，停止定位")
            self.isLocating = false
            self.errorMessage = LocalizedStrings.locationTimeout.localized
            self.locationManager.stopUpdatingLocation()
            self.pendingLocationCallback = nil
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }

        // 驗證：拒絕超過 10 秒的舊位置
        let age = -newLocation.timestamp.timeIntervalSinceNow
        guard age < 10.0 else {
            print("拒絕過期位置（age: \(age)s）")
            return
        }

        // 驗證：拒絕精度太差的結果（> 1000m）
        guard newLocation.horizontalAccuracy >= 0 && newLocation.horizontalAccuracy < 1000 else {
            print("拒絕不準確位置（accuracy: \(newLocation.horizontalAccuracy)m）")
            return
        }

        DispatchQueue.main.async {
            self.location = newLocation
            self.freshLocation = newLocation
            self.isLocating = false
            self.errorMessage = nil

            // 儲存最後已知位置
            UserDefaults.standard.set(newLocation.coordinate.latitude, forKey: "LastLat")
            UserDefaults.standard.set(newLocation.coordinate.longitude, forKey: "LastLon")

            // 停止持續定位
            self.locationManager.stopUpdatingLocation()

            // 觸發 callback
            self.pendingLocationCallback?(newLocation)
            self.pendingLocationCallback = nil

            print("定位成功：\(newLocation.coordinate.latitude), \(newLocation.coordinate.longitude), 精度: \(newLocation.horizontalAccuracy)m")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isLocating = false
            self.errorMessage = error.localizedDescription
            
            print("定位失敗：\(error.localizedDescription)")
            
            // 停止持續定位
            self.locationManager.stopUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
            print("權限狀態變更：\(status.rawValue)")
            
            if status == .denied {
                print("權限被拒絕")
                self.isLocating = false
            } else if status == .restricted {
                print("權限受限制")
                self.isLocating = false
            } else if status == .authorizedWhenInUse || status == .authorizedAlways {
                print("權限已獲得，開始定位")
                // 權限獲得後，立即開始定位（避免重複請求）
                if !self.isLocating {
                    self.getQuickLocation()
                }
            }
        }
    }
}
