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
    func xozLocationManager(_ manager: XOZLocationManager, didUpdateLocations locations: [CLLocation])
    func xozLocationManager(_ manager: XOZLocationManager, didEnterRegion region:CLRegion)
    func xozLocationManager(_ manager: XOZLocationManager, didExitRegion region:CLRegion)
    func xozLocationManager(_ manager: XOZLocationManager, monitoringDidFailedFor region:CLRegion, withError error: Error)

}

// optionals delegate methods
public extension XOZLocationManagerDelegate {
    // region monitoring is optional
    func xozLocationManager(_ manager: XOZLocationManager, didEnterRegion region:CLRegion) {}
    func xozLocationManager(_ manager: XOZLocationManager, didExitRegion region:CLRegion) {}
    func xozLocationManager(_ manager: XOZLocationManager, monitoringDidFailedFor region:CLRegion, withError error: Error) {}
}



/**
 * This is a GEO based location manager for your project.
 * Currently they are 3 main features inside:
 *
 * 1. Use it to check and or request for authorization status
 * 2. Use it to request device position or let you inform about updates
 * 3. use it to activate region monitoring for 1..n regions. iOS normaly has a maximum of 20 regions, this class manages for you more then 20. It automatical registers the neares regions based on the position
 * 4. Using Significant Location Changes
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
 * XOZLocationManagerDidUpdateLocations
 * XOZLocationManagerDidEnterRegion
 * XOZLocationManagerDidExitRegion
 * XOZLocationManagerMonitoringDidFailed
 *
 * e.g.:
 * NotificationCenter.default.addObserver(self, selector: #selector(didUpdateLocations(notification:)), name: .XOZLocationManagerDidUpdateLocations, object: nil)
 *
 * you should
    import MapKit
 *
 **/
public class XOZLocationManager: NSObject, CLLocationManagerDelegate {

    /// use XOZLocationManager as singleton
    public static let shared = XOZLocationManager()
    public let locationManager = CLLocationManager()
    
    // register as delegate if needed
    public var delegate: XOZLocationManagerDelegate?

    // some configuration variables to get location updates (not for significant location changes or region monitoring)
    public static var activityType: CLActivityType = .fitness
    public static var distanceFilter: CLLocationDistance = 10
    public static var desiredAccuracy:CLLocationAccuracy = kCLLocationAccuracyNearestTenMeters
    
    public static var pausesLocationUpdatesAutomatically: Bool = true
    public static var allowsBackgroundLocationUpdates: Bool = true
    @available(iOS 11.0, *)
    public static var showsBackgroundLocationIndicator: Bool = false
    
    // logging
    public var logLevel : LogLevel  = .none // define loglevel, when activ it will only log in debug mode
    
    
    // region monitoring
    //@TODO, couldbe that at start i'm inside a region and than no more an didEnter event comes?
    public var wayToDetermineNearestRegions : WayToDetermineNearestRegions = .significantLocationChanges
    public var allRegionsToMonitor : [CLCircularRegion]? = []
    public let maximumOfRegionsToMonitor = 20
    
    
    // intenal states
    private var requiredAuthorizationForSignificantLocationChanges : Authorization = .always
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
    
    
    private var lastKnownLocation : CLLocation?
    private var wantsToStartUpdateLocation = false
    private var isUpdatingLocationActive = false
    private var wantsToStartSignificantLocationChanges = false
    private var isSignificantLocationChangesActive = false

    // enums
    public enum Authorization {
        case whenInUse
        case always
    }
    
    public enum WayToDetermineNearestRegions {
        case none
        case significantLocationChanges // default
        case locationUpdates
    }
    
    public enum LogLevel {
        case none
        case verbose
    }


    // constructor
    private override init() {
        super.init()
        self.locationManager.delegate = self
        self.locationManager.pausesLocationUpdatesAutomatically = XOZLocationManager.pausesLocationUpdatesAutomatically
        
        self.locationManager.allowsBackgroundLocationUpdates = XOZLocationManager.allowsBackgroundLocationUpdates
        if #available(iOS 11.0, *) {
            self.locationManager.showsBackgroundLocationIndicator = XOZLocationManager.showsBackgroundLocationIndicator
        }
        
        // location updates (not significan location changes)
        self.locationManager.activityType = XOZLocationManager.activityType
        self.locationManager.distanceFilter = XOZLocationManager.distanceFilter
        self.locationManager.desiredAccuracy = XOZLocationManager.desiredAccuracy
        
    }
    
    public func startUpdatingLocationFor(authType : XOZLocationManager.Authorization) {
        self.wantsToStartUpdateLocation = true
        if self.isAuthorized() == true {
            self.startUpdatingLocation()
        } else {
            self.requestAutorization(authType: authType)
            // startUpdatingLocations will be called than in didChangeAuthorization status
        }
    }
    
    public func stopUpdatingLocation() {
        self.isUpdatingLocationActive = false
        self.locationManager.stopUpdatingLocation()
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
        self.isUpdatingLocationActive = true
        self.wantsToStartUpdateLocation = false
        locationManager.startUpdatingLocation()
    }
    
    // MARK: CLLocationManager Delegates
    
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        log("new Location Manager auth state: \(status)")
        
        if status != .notDetermined {
            if self.wantsToStartUpdateLocation == true {
                self.startUpdatingLocation()
            }
            else if self.wantsToStartSignificantLocationChanges == true {
                self.startReceivingSignificantLocationChanges()
            }
        }
    }
    
    /*:
     This is called if startUpdatingLocation() or startReceivingSignificantLocationChanges() was called
     an we received a new location update.
     */
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        if let lastLocation = locations.last {
            self.lastKnownLocation = lastLocation
            log("latest known location: \(lastLocation)")
            
            // scream it out to the world that we have a new location
            self.delegate?.xozLocationManager(self, didUpdateLocations: locations)
            let locationDataDict:[String: CLLocation] = ["lastLocation": lastLocation]
            NotificationCenter.default.post(name: .XOZLocationManagerDidUpdateLocations, object: nil, userInfo: locationDataDict)
            
            // update regions monitoring if needed
            self.updateRegionsToMonitor()
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        log("ERROR: didFailWithError (\(error.localizedDescription)")
    }
    
    // MARK: significant location changes
    
    func startReceivingSignificantLocationChanges() {
        if self.isAuthorized() == true && self.isSignificantLocationChangesActive == false {
            if CLLocationManager.significantLocationChangeMonitoringAvailable() {
                self.isSignificantLocationChangesActive = true
                self.wantsToStartSignificantLocationChanges = false
                locationManager.startMonitoringSignificantLocationChanges()
            } else {
                //@TODO: error is not supported
            }
        } else {
            self.requestAutorization(authType: self.requiredAuthorizationForSignificantLocationChanges)
        }
    }
    
    
    public func stopReceivingSignificantLocationChanges() {
        // be carefull, it will be started again when you add regions to monitor
        // or you set self.wayToDetermineNearestRegions to .none
        self.locationManager.stopMonitoringSignificantLocationChanges()
        self.isSignificantLocationChangesActive = false
    }
    
    
    public func getLastKnownLocation() -> CLLocation? {
        return self.lastKnownLocation
    }

    
    
    
    // MARK: region monitoring
    
    
    // add an array of regions which you want to monitor
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
        if let index = self.allRegionsToMonitor?.firstIndex(of: region) {
           self.allRegionsToMonitor?.remove(at: index)
            // @TODO: stop significant location changes or updating locations when no more is needed
        }
        self.tryToUpdateRegionsToMonitor()
    }
    
    
    // this request to get the latest known location, it end's in didUpdateLocations, which calls updateRegionsToMonitor()
    private func tryToUpdateRegionsToMonitor()
    {
        // we want to get the actually location if possible, else we are using the last known one
        var lastKnownLocationArr = [CLLocation]()
        if let lastKnownLocation = self.lastKnownLocation {
            lastKnownLocationArr.append(lastKnownLocation)
            locationManager(self.locationManager, didUpdateLocations: lastKnownLocationArr)
        } else {
            self.locationManager.requestLocation()
        }
        // we start the update than in the delegate didUpdateLocations when we have a location
        
        // we need to start a way to get location changes updates to calculate the nearest regions
        switch self.wayToDetermineNearestRegions {
            case .significantLocationChanges:
                self.startReceivingSignificantLocationChanges()
            case .locationUpdates:
                self.startUpdatingLocationFor(authType: self.requiredAuthorizationForSignificantLocationChanges)
            case .none:
                // nothing todo
                print("Attention: Region monitoring is enabled, but without determine neares regions !")
        }
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
                        log("added region to monitor: \(region)")
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
        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse  || CLLocationManager.authorizationStatus() == .authorizedAlways{
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
            log("XOZLocationManager: stoped monitoring for region \(region)")
        }
    }

    
    public func locationManager(_ manager: CLLocationManager, didEnterRegion region:CLRegion) {
        log("didEnterRegion \(region.debugDescription )")
        
        // scream it out to the world that we entered a region
        self.delegate?.xozLocationManager(self, didEnterRegion: region)
        let regionDataDict:[String: CLRegion] = ["region": region]
        NotificationCenter.default.post(name: .XOZLocationManagerDidEnterRegion, object: nil, userInfo: regionDataDict)
    }
    
    public func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        log("didDetermineState for \(region.debugDescription ) new state \(state.rawValue)")
    }
    
    public func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        log("didExitRegion \(region.debugDescription )")
        
        // scream it out to the world that we leaved a region
        self.delegate?.xozLocationManager(self, didExitRegion: region)
        let regionDataDict:[String: CLRegion] = ["region": region]
        NotificationCenter.default.post(name: .XOZLocationManagerDidExitRegion, object: nil, userInfo: regionDataDict)

    }
    
    public func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        log("didStartMonitoringFor \(region.debugDescription )")
        
        #if DEBUG
        if self.logLevel == .verbose {
            // would be intresting to know how the current state ie
            self.locationManager.requestState(for: region)
        }
        #endif
    }
    
    public func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        log("ERROR: monitoringDidFailFor \(region.debugDescription ) (\(error.localizedDescription)")
        
        if let tRegion = region {
            self.delegate?.xozLocationManager(self, monitoringDidFailedFor: tRegion, withError: error)
            var regionDataDict:Dictionary<String,Any> = [:]
            regionDataDict["region"] = tRegion
            regionDataDict["error"] = error

            NotificationCenter.default.post(name: .XOZLocationManagerMonitoringDidFailed, object: nil, userInfo: regionDataDict)
        }
    }
    
    private func log(_ message:String)
    {
        if self.logLevel == .verbose {
            debugPrint(message)
        }
    }
    

}



public extension Notification.Name {
    static let XOZLocationManagerDidUpdateLocations = Notification.Name("XOZLocationManagerDidUpdateLocations")
    static let XOZLocationManagerDidEnterRegion = Notification.Name("XOZLocationManagerDidEnterRegion")
    static let XOZLocationManagerDidExitRegion = Notification.Name("XOZLocationManagerDidExitRegion")
    static let XOZLocationManagerMonitoringDidFailed = Notification.Name("XOZLocationManagerMonitoringDidFailed")

}
