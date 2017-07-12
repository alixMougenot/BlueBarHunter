//
//  ViewController.swift
//  blueBarHunter
//
//  Created by Alix on 12/07/2017.
//  Copyright © 2017 Alix Mougenot.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


import UIKit
import CoreLocation

class ViewController: UIViewController, CLLocationManagerDelegate {


    @IBOutlet var requestLocation: UISegmentedControl!

    @IBOutlet var requestLocationUpdate: UISwitch!
    @IBOutlet var requestOne: UIButton!
    @IBOutlet var requestRead: UIButton!

    @IBOutlet var requestSignificantLocationChange: UISwitch!
    @IBOutlet var requestVisits: UISwitch!
    @IBOutlet var requestFence: UISwitch!

    @IBOutlet var textBox: UILabel!

    private var locManager: CLLocationManager?
    private var lastLocation: CLLocation?
    private var geocence: CLRegion?

    private var lastMessageUpdate: Date = Date()


    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        locManager = CLLocationManager()

        self.updateStatus()
        self.requestLocation.addTarget(self, action: #selector(onRequestUserAuthorization(sender:)), for: UIControlEvents.valueChanged)

        self.requestLocationUpdate.addTarget(self, action: #selector(onRequestUpdate(sender:)), for: UIControlEvents.touchUpInside)
        self.requestOne.addTarget(self, action: #selector(onRequestOneUpdate(sender:)), for: UIControlEvents.touchUpInside)
        self.requestRead.addTarget(self, action: #selector(onReadLocatiopn(sender:)), for: UIControlEvents.touchUpInside)

        self.requestSignificantLocationChange.addTarget(self, action: #selector(onRequestSignificantLocationChange(sender:)), for: UIControlEvents.touchUpInside)
        self.requestVisits.addTarget(self, action: #selector(onRequestVisits(sender:)), for: UIControlEvents.touchUpInside)
        self.requestFence.addTarget(self, action: #selector(onGeoFence(sender:)), for: UIControlEvents.touchUpInside)

        NotificationCenter.default.addObserver(self, selector: #selector(updateStatus), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // request for location, will display the famous popup.
    func onRequestUserAuthorization(sender:UISegmentedControl) {

        if let locationManager = self.locManager {
            // Set the delegate
            locationManager.delegate = self

            // Check if the authorization is already granted
            let status = CLLocationManager.authorizationStatus()

            // If the status is not determined, then do nothing
            guard status == .notDetermined else {
                switch status {
                case .authorizedAlways : textBox?.text = "Authorized Always"
                case .authorizedWhenInUse : textBox?.text = "Authorized InUse"
                case .denied : textBox?.text = "Denied"
                case .restricted : textBox?.text = "Restricted"
                default:()
                }

                self.nextMessage()
                return
            }

            if sender.selectedSegmentIndex == 0 {
                locationManager.requestAlwaysAuthorization()
            } else {
                locationManager.requestWhenInUseAuthorization()
            }

            return
        }
    }


    // location setup
    func onRequestUpdate(sender:UISwitch) {
        if let locationManager = self.locManager,
            CLLocationManager.authorizationStatus() == .authorizedAlways || CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            locationManager.delegate = self

            if sender.isOn {
                locationManager.startUpdatingLocation()
                textBox?.text = "Location Change On"
                self.nextMessage()
            } else {
                locationManager.stopUpdatingLocation()
                textBox?.text = "Location Change Off"
                self.nextMessage()
            }
        }

    }


    // one location setup
    func onRequestOneUpdate(sender:UIButton) {
        if let locationManager = self.locManager,
            CLLocationManager.authorizationStatus() == .authorizedAlways || CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            locationManager.delegate = self
            locationManager.requestLocation()
        }
    }


    // read location
    func onReadLocatiopn(sender:UIButton) {
        if let locationManager = self.locManager,
            CLLocationManager.authorizationStatus() == .authorizedAlways || CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            locationManager.delegate = self
            if let loc = locationManager.location {
                self.lastLocation = loc
                self.textBox.text = "Found Location: \(loc.debugDescription)"
                self.nextMessage()
            } else {
                self.textBox.text = "There is no Current Location"
                self.nextMessage()
            }
        }
    }


    // visit setup
    func onRequestSignificantLocationChange(sender:UISwitch) {

        if let locationManager = self.locManager,
            CLLocationManager.authorizationStatus() == .authorizedAlways || CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            locationManager.delegate = self

            if sender.isOn {
                locationManager.startMonitoringSignificantLocationChanges()
                textBox?.text = "Significant Location Change On"
                self.nextMessage()
            } else {
                locationManager.stopMonitoringSignificantLocationChanges()
                textBox?.text = "Significant Location Change Off"
                self.nextMessage()
            }
        }
    }

    // visit setup
    func onRequestVisits(sender:UISwitch) {

        if let locationManager = self.locManager,
            CLLocationManager.authorizationStatus() == .authorizedAlways || CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            locationManager.delegate = self

            if sender.isOn {
                locationManager.startMonitoringVisits()
                textBox?.text = "Visit On"
                self.nextMessage()
            } else {
                locationManager.stopMonitoringVisits()
                textBox?.text = "Visit Off"
                self.nextMessage()
            }
        }
    }


    // 200 meters geofence around me
    func onGeoFence(sender:UISwitch) {
        if let locationManager = self.locManager,
            CLLocationManager.authorizationStatus() == .authorizedAlways || CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            locationManager.delegate = self

            if sender.isOn {
                guard let currentLocation = self.lastLocation else {
                    textBox?.text = "Request One location First"
                    self.nextMessage()
                    return
                }

                let region = CLCircularRegion(center: currentLocation.coordinate, radius: 200, identifier: "Geofence")
                self.geocence = region
                locationManager.startMonitoring(for: region)
                textBox?.text = "Geofence Setup Done"
                self.nextMessage()

            } else {
                guard let currentGeofence = self.geocence else {
                    textBox?.text = "Error: No geofence found to stop geofencing"
                    self.nextMessage()
                    return
                }

                locationManager.stopMonitoring(for: currentGeofence)
                textBox?.text = "Geofence Removed"
                self.nextMessage()
            }
        }

    }


    // MARK: Location Manager Delegate
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways : textBox?.text = "Authorized Always"
        case .authorizedWhenInUse : textBox?.text = "Authorized InUse"
        case .denied : textBox?.text = "Denied"
        case .restricted : textBox?.text = "Restricted"
        default:()
        }

        self.nextMessage()
        self.updateStatus()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.textBox.text = "Error -> \(error)"
        self.nextMessage()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        self.lastLocation = locations.first
        self.textBox.text = "Location Update: \(locations.first?.debugDescription ?? "no location")"
        self.nextMessage()
    }

    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        self.textBox.text = "Visit : \(visit.debugDescription)"
        self.nextMessage()
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        self.textBox.text = "Enter : \(region.debugDescription)"
        self.nextMessage()
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        self.textBox.text = "Exit : \(region.debugDescription)"
        self.nextMessage()
    }


    // MARK: Other
    private func nextMessage() {
        NSLog(self.textBox.text ?? "")
        self.lastMessageUpdate = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            if -self.lastMessageUpdate.timeIntervalSinceNow > 3.8 {
                self.textBox.text = ""
            }
        }
    }

    @objc
    private func updateStatus() {
        switch CLLocationManager.authorizationStatus() {
        case .authorizedAlways :
            self.requestLocation.selectedSegmentIndex = 0
            self.requestLocation.isEnabled = false
        case .authorizedWhenInUse :
            self.requestLocation.selectedSegmentIndex = 1
            self.requestLocation.isEnabled = false
        case .denied, .restricted :
            self.requestLocation.selectedSegmentIndex = 2
            self.requestLocation.isEnabled = false
        default:()
        }
    }


}

