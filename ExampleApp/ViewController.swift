//
//  ViewController.swift
//  ExampleApp
//
//  Created by Philipp Homann on 21.08.19.
//  Copyright © 2019 wwwpage.de UG. All rights reserved.
//

import UIKit
import MapKit
import XOZLocationManager

class ViewController: UIViewController, XOZLocationManagerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Use Case: you only whant to request authorization:
        if XOZLocationManager.shared.isAuthorized() == false {
            XOZLocationManager.shared.requestAutorization(authType: .whenInUse)
        } else {
            // do something, e.g.:
            debugPrint("app is authorized")
        }
        
        
        // Use Case: directly start updating Locations with e special authorization status
        XOZLocationManager.shared.startUpdatingLocationFor(authType: .whenInUse)
        
        // Use Case: add one region which should be monitored (only this is enough to start the region monitoring for all)
        
        let radius : CLLocationDistance = 200 // or locationManager.maximumRegionMonitoringDistance
        let location : CLLocation = CLLocation(latitude: 52.502758, longitude: 13.503246)
        let uniqueID : String = "An-Unique-String"
        let region = CLCircularRegion(center: location.coordinate, radius: radius, identifier: uniqueID)
        XOZLocationManager.shared.addRegionToMonitor(region:region)

        
        // add more than one region which are should be monitored (only this is enough to start the region monitoring for all)
        
        // var regionsToMonitor : [CLCircularRegion] = []
        //for object in arrOfObjects {
        //    regionsToMonitor.append(object.region)
        //}
        //XOZLocationManager.shared.addRegionsToMonitor(regions: regionsToMonitor)

        
    }
    
    // delegates
    func locationManagerDidUpdateLocations(_ manager: XOZLocationManager, didUpdateLocations locations: [CLLocation]){
        
    }
    
    func locationManager(_ manager: XOZLocationManager, didEnterRegion region:CLRegion) {
        debugPrint("didEnterRegion \(region.debugDescription )")
    }
    
    func locationManager(_ manager: XOZLocationManager, didExitRegion region:CLRegion) {
        debugPrint("didExitRegion \(region.debugDescription )")
    }
    
    func locationManager(_ manager: XOZLocationManager, monitoringDidFailedFor region:CLRegion, withError error: Error) {
        debugPrint("ERROR: didFailWithError (\(error.localizedDescription)")
    }




}

