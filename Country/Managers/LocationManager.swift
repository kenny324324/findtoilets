import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocating: Bool = false
    @Published var errorMessage: String?
    
    override init() {
        super.init()
        locationManager.delegate = self
        // 使用較低的精度以提升定位速度
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        // 設定距離過濾器，減少不必要的更新
        locationManager.distanceFilter = 10
        authorizationStatus = locationManager.authorizationStatus
        print("LocationManager 初始化，權限狀態：\(authorizationStatus.rawValue)")
        
        // 如果權限未確定，立即請求
        if authorizationStatus == .notDetermined {
            print("初始化時請求權限")
            requestLocationPermission()
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
    
    // 新增：快速定位方法（使用更低的精度）
    func getQuickLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            print("權限不足，請求權限")
            requestLocationPermission()
            return
        }
        
        print("開始快速定位流程")
        isLocating = true
        errorMessage = nil
        
        // 暫時降低精度以提升速度
        let originalAccuracy = locationManager.desiredAccuracy
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        
        // 嘗試快速定位
        locationManager.requestLocation()
        
        // 1秒後恢復原始精度設定
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.locationManager.desiredAccuracy = originalAccuracy
        }
        
        // 快速定位超時保護
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if self.isLocating {
                print("快速定位超時，停止定位")
                self.isLocating = false
                self.errorMessage = LocalizedStrings.locationTimeout.localized
                self.locationManager.stopUpdatingLocation()
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            self.location = location
            self.isLocating = false
            self.errorMessage = nil
            
            // 停止持續定位
            self.locationManager.stopUpdatingLocation()
            
            print("定位成功：緯度 \(location.coordinate.latitude), 經度 \(location.coordinate.longitude)")
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
                // 權限獲得後，立即開始定位
                self.getQuickLocation()
            }
        }
    }
}
