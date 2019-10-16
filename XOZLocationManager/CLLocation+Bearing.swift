//
//  CLLocation+Bearing.swift
//  hundred
//
//  Created by Philipp Homann on 16.10.19.
//  Copyright © 2019 wwwPage.de UG (haftungsbeschränkt). All rights reserved.
//

import Foundation
import CoreLocation


// from https://stackoverflow.com/questions/3925942/cllocation-category-for-calculating-bearing-w-haversine-function?rq=1

public extension CLLocation {
    
    func degreesToRadians(degrees: Double) -> Double {
        return degrees * .pi / 180.0
    }
    
    func radiansToDegrees(radians: Double) -> Double {
        return radians * 180.0 / .pi
    }
    
    func getBearingTo(location: CLLocation) -> Double {
        let lat1 = degreesToRadians(degrees: self.coordinate.latitude)
        let lon1 = degreesToRadians(degrees: self.coordinate.longitude)
        
        let lat2 = degreesToRadians(degrees: location.coordinate.latitude)
        let lon2 = degreesToRadians(degrees: location.coordinate.longitude)
        
        let dLon = lon2 - lon1
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radiansBearing = atan2(y, x)
        
        return radiansToDegrees(radians: radiansBearing)
    }
    
}
