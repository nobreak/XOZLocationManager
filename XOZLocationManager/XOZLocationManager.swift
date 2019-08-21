//
//  LocationManager.swift
//  hundred
//
//  Created by Philipp Homann on 17.04.19.
//  Copyright © 2019 wwwPage.de UG (haftungsbeschränkt). All rights reserved.
//

import Foundation
import MapKit



public protocol XOZLocationManagerDelegate {
    func locationManagerDidUpdateLocations(_ manager: XOZLocationManager, didUpdateLocations locations: [CLLocation])
}

// optionals delegate methods
public extension XOZLocationManagerDelegate {
    // region monitoring is optional
    func locationManager(_ manager: XOZLocationManager, didEnterRegion region:CLRegion) {}
    func locationManager(_ manager: XOZLocationManager, didExitRegion region:CLRegion) {}
    func locationManager(_ manager: XOZLocationManager, monitoringDidFailedFor region:CLRegion, withError error: Error) {}
}



/**
 * This is a GEO based location manager for your project.
 * Currently they are 3 main features inside:
 *
 * 1. Use it to check and or request for authorization status
 * 2. Use it to request device position or let you inform about updates
 * 3. use it to activate region monitoring for 1..n regions. iOS normaly has a maximum of 20 regions, this class manages for you more then 20. It automatical registers the neares regions based on the position
 * 4. @TODO: implement Significant location changes, to let update regions to monitor, also based on events of this
 *
 * How to USE:
 * ==========
 *
 * 1. Use Case: you only whant to request authorization:
 *
    if XOZLocationManager.shared.isAuthorized() == false {
        XOZLocationManager.shared.requestAutorization(authType: .whenInUse)
    } else {
        // do something, e.g.:
        debugPrint("app is authorized")
    }
 *
 * 2. Use Case: directly start updating Locations with e special authorization status
 *
   XOZLocationManager.shared.startUpdatingLocationFor(authType: .whenInUse)
 *
 * 3. add one region which should be monitored (only this is enough to start the region monitoring for all)
 *
    let radius : CLLocationDistance = 200 // or locationManager.maximumRegionMonitoringDistance
    let location : CLLocation = CLLocation(latitude: 52.502758, longitude: 13.503246)
    let uniqueID : String = "An-Unique-String"
    let region = CLCircularRegion(center: location.coordinate, radius: radius, identifier: uniqueID)
    XOZLocationManager.shared.addRegionToMonitor(region:region)
 *
 *
 * 4. add more than one region which are should be monitored (only this is enough to start the region monitoring for all)
 
   var regionsToMonitor : [CLCircularRegion] = []
   for object in arrOfObjects {
       regionsToMonitor.append(object.region)
   }
   XOZLocationManager.shared.addRegionsToMonitor(regions: regionsToMonitor)
 *
 * 
 * HOW TO GET EVENTS:
 * =================
 *
 * You could inheriet from XOZLocationManagerDelegate and assign you as delegate, or register for event notification at NSNotification center like
 *
 * LocationManagerDidUpdateLocations
 * LocationManagerDidEnterRegion
 * LocationManagerDidExitRegion
 * LocationManagerMonitoringDidFailed
 *
 * e.g.:
 * NotificationCenter.default.addObserver(self, selector: #selector(didUpdateLocations(notification:)), name: .LocationManagerDidUpdateLocations, object: nil)
 *
 * you should
    import MapKit
 *
 **/
public class XOZLocationManager: NSObject, CLLocationManagerDelegate {

    public enum Authorization {
        case whenInUse
        case always
    }
    

    var delegate: XOZLocationManagerDelegate?
    
    public static let shared = XOZLocationManager()
    private let locationManager = CLLocationManager()
    private var lastKnownLocation : CLLocation?
    
    // region monitoring
    //@TODO, couldbe that at start i'm inside a region and than no more an didEnter event comes?
    private var iShouldMonitorForRegions = true
    var shouldMonitorForRegions : Bool
    {
        get {
            return self.iShouldMonitorForRegions
        }
        set (newValue) {
            self.iShouldMonitorForRegions = newValue
            
            if newValue == true {
                self.tryToUpdateRegionsToMonitor()
            } else {
                self.stopMonitoringAllRegions()
            }
        }
    }
    
    var allRegionsToMonitor : [CLCircularRegion]? = []
    let maximumOfRegionsToMonitor = 20
    
    private override init() {
        super.init()
        self.locationManager.delegate = self
    }
    
    public func startUpdatingLocationFor(authType : XOZLocationManager.Authorization) {
        if self.isAuthorized() == true {
            self.startUpdatingLocation()
        } else {
            self.requestAutorization(authType: authType)
            // startUpdatingLocations will be called than in didChangeAuthorization status
        }
    }
    
    public func isAuthorized() -> Bool {
        var result = false
        if CLLocationManager.authorizationStatus() != .notDetermined {
            result = true
        }
        return result
    }
    
    public func requestAutorization(authType : XOZLocationManager.Authorization) {
        if authType == .whenInUse {
            locationManager.requestWhenInUseAuthorization()
        } else if authType == .always {
            locationManager.requestAlwaysAuthorization()
        }
    }
    
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }
    
    // MARK: CLLocationManager Delegates
    
    private func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        debugPrint("new Location Manager auth state: \(status)")
        
        if status != .notDetermined {
            self.startUpdatingLocation()
        }
    }
    
    private func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        if let lastLocation = locations.last {
            self.lastKnownLocation = lastLocation
            debugPrint("latest known location: \(lastLocation)")
            
            // scream it out to the world that we have a new location
            self.delegate?.locationManagerDidUpdateLocations(self, didUpdateLocations: locations)
            let locationDataDict:[String: CLLocation] = ["lastLocation": lastLocation]
            NotificationCenter.default.post(name: .LocationManagerDidUpdateLocations, object: nil, userInfo: locationDataDict)
            
            // update regions monitoring if needed
            updateRegionsToMonitor()
        }
    }
    
    private func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        debugPrint("ERROR: didFailWithError (\(error.localizedDescription)")
    }
    
    
    
    // MARK: region monitoring
    
    
    // add an array of regions which you want to monito
    // if shouldMonitorForRegions is true, this region will be registered at OS, else only stored for later use
    public func addRegionsToMonitor(regions: [CLCircularRegion]) {
        self.allRegionsToMonitor?.append(contentsOf: regions)
        self.tryToUpdateRegionsToMonitor()
    }

    // add a new region which you want to monitor
    // if shouldMonitorForRegions is true, this region will be registered at OS, else only stored for later use
    public func addRegionToMonitor(region: CLCircularRegion){
        self.allRegionsToMonitor?.append(region)
        self.tryToUpdateRegionsToMonitor()
    }
    
    // removes a special region from the array which holds all regions which are to monitor
    public func removeRegionToMonitor(region: CLCircularRegion) {
        if let index = self.allRegionsToMonitor?.index(of: region) {
           self.allRegionsToMonitor?.remove(at: index)
        }
        self.tryToUpdateRegionsToMonitor()
    }
    
    // this request to get the latest known location, it end's in didUpdateLocations, which calls updateRegionsToMonitor()
    private func tryToUpdateRegionsToMonitor()
    {
        self.locationManager.requestLocation()
        // we start the update than in the delegate didUpdateLocations when we have a location
    }

    
    // will update the regions which are to be monitored
    // you never should call this directly, call instead tryToUpdateRegionsToMonitor() to get latest known position of user
    private func updateRegionsToMonitor(){
        if self.shouldMonitorForRegions == true {
            // get nearest 20 regions based on last known user position
            if let lastLocation = self.lastKnownLocation {
                if var regionsToMonitor = self.allRegionsToMonitor {
                    // sort all given regions by distance to last known location
                    // but maybe we have differences in radius, so we calculate the distance to neares radius
                    regionsToMonitor.sort(by: {
                        CLLocation(latitude: $0.center.latitude, longitude: $0.center.longitude).distance(from:lastLocation)-$0.radius < CLLocation(latitude: $1.center.latitude, longitude: $1.center.longitude).distance(from:lastLocation)-$1.radius
                        })
                    
                    // stop all maybe currently monitored regions
                    self.stopMonitoringAllRegions()
                    
                    // add now all regions which we want to monitor until the maximum of 20
                    var index = 0
                    for region in regionsToMonitor {
                        self.startMonitorRegion(region: region)
                        index = +1
                        if index == self.maximumOfRegionsToMonitor-1 {
                            break;
                        }
                    }
                }
            }
        }
    }
    
    private func startMonitorRegion(region : CLRegion ) {
        // Make sure the app is authorized.
        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            // Make sure region monitoring is supported.
            if CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) {
                // Register the region.
                //let maxDistance = locationManager.maximumRegionMonitoringDistance
                locationManager.startMonitoring(for: region)
            }
        }
    }
    
    // tells the CLLocationManager to stop to monitor a region
    private func stopMonitoringRegion(region: CLRegion)
    {
        locationManager.stopMonitoring(for: region)
    }

    // tells the CLLocationManager to stop to monitor a all monitored regions
    // ATTENTION: this stops the monitoring off all regions which was registered with a CLLocationManager instance (not only this)
    private func stopMonitoringAllRegions()
    {
        for region in locationManager.monitoredRegions{
            self.stopMonitoringRegion(region: region)
        }
    }

    
    private func locationManager(_ manager: CLLocationManager, didEnterRegion region:CLRegion) {
        debugPrint("didEnterRegion \(region.debugDescription )")
        
        // scream it out to the world that we entered a region
        self.delegate?.locationManager(self, didEnterRegion: region)
        let regionDataDict:[String: CLRegion] = ["region": region]
        NotificationCenter.default.post(name: .LocationManagerDidEnterRegion, object: nil, userInfo: regionDataDict)
    }
    
    private func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        debugPrint("didDetermineState for \(region.debugDescription ) new state \(state)")
    }
    
    private func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        debugPrint("didExitRegion \(region.debugDescription )")
        
        // scream it out to the world that we leaved a region
        self.delegate?.locationManager(self, didExitRegion: region)
        let regionDataDict:[String: CLRegion] = ["region": region]
        NotificationCenter.default.post(name: .LocationManagerDidExitRegion, object: nil, userInfo: regionDataDict)

    }
    
    private func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        debugPrint("didStartMonitoringFor \(region.debugDescription )")
        
        #if DEBUG
            // would be intresting to know how the current state ie
            self.locationManager.requestState(for: region)
        #endif
    }
    
    private func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        debugPrint("ERROR: monitoringDidFailFor \(region.debugDescription ) (\(error.localizedDescription)")
        
        if let tRegion = region {
            self.delegate?.locationManager(self, monitoringDidFailedFor: tRegion, withError: error)
            var regionDataDict:Dictionary<String,Any> = [:]
            regionDataDict["region"] = tRegion
            regionDataDict["error"] = error

            NotificationCenter.default.post(name: .LocationManagerMonitoringDidFailed, object: nil, userInfo: regionDataDict)
        }
    }
    

}


extension Notification.Name {
    static let LocationManagerDidUpdateLocations = Notification.Name("LocationManagerDidUpdateLocations")
    static let LocationManagerDidEnterRegion = Notification.Name("LocationManagerDidEnterRegion")
    static let LocationManagerDidExitRegion = Notification.Name("LocationManagerDidExitRegion")
    static let LocationManagerMonitoringDidFailed = Notification.Name("LocationManagerMonitoringDidFailed")

}
