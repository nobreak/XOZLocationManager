//
//  ViewController.swift
//  ExampleApp
//
//  Created by Philipp Homann on 21.08.19.
//  Copyright © 2019 exozet. All rights reserved.
//

import UIKit
import XOZLocationManager

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Use Case: you only whant to request authorization:
        if XOZLocationManager.shared.isAuthorized() == false {
            XOZLocationManager.shared.requestAutorization(authType: .whenInUse)
        } else {
            XOZLocationManager.shared.startUpdatingLocation()
        }
        
    }


}

