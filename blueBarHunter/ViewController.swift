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


    // keys for local storage
    private static let NotifyMe_key = "notifyme"
    private static let RequestUpdates_key = "updates"
    private static let RequestSignificantLocationChange_key = "significantLocationChange"
    private static let RequestVisits_key = "visits"
    private static let RequestFence_key = "fence"
    private static let FenceRegionLat_key = "fence_region_lat"
    private static let FenceRegionLon_key = "fence_region_lon"

    @IBOutlet var requestLocation: UISegmentedControl!

    @IBOutlet var requestLocationUpdate: UISwitch!
    @IBOutlet var requestOne: UIButton!
    @IBOutlet var requestRead: UIButton!

    @IBOutlet var requestSignificantLocationChange: UISwitch!
    @IBOutlet var requestVisits: UISwitch!
    @IBOutlet var requestFence: UISwitch!

    @IBOutlet var requestNotifications: UISwitch!
    @IBOutlet var textBox: UILabel!

    private var locManager: CLLocationManager?
    private var lastLocation: CLLocation?
    private var geocence: CLRegion?
    private var notifyMe:Bool = false

    private var lastMessageUpdate: Date = Date()


    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        locManager = CLLocationManager()
        locManager?.pausesLocationUpdatesAutomatically = false
        locManager?.allowsBackgroundLocationUpdates = true

        self.restoreStatus()
        self.restoreState()

        self.requestLocation.addTarget(self, action: #selector(onRequestUserAuthorization(sender:)), for: UIControlEvents.valueChanged)

        self.requestLocationUpdate.addTarget(self, action: #selector(onRequestUpdate(sender:)), for: UIControlEvents.touchUpInside)
        self.requestOne.addTarget(self, action: #selector(onRequestOneUpdate(sender:)), for: UIControlEvents.touchUpInside)
        self.requestRead.addTarget(self, action: #selector(onReadLocatiopn(sender:)), for: UIControlEvents.touchUpInside)

        self.requestSignificantLocationChange.addTarget(self, action: #selector(onRequestSignificantLocationChange(sender:)), for: UIControlEvents.touchUpInside)
        self.requestVisits.addTarget(self, action: #selector(onRequestVisits(sender:)), for: UIControlEvents.touchUpInside)
        self.requestFence.addTarget(self, action: #selector(onGeoFence(sender:)), for: UIControlEvents.touchUpInside)
        self.requestNotifications.addTarget(self, action: #selector(onNotifyMe(sender:)), for: UIControlEvents.touchUpInside)

        NotificationCenter.default.addObserver(self, selector: #selector(restoreStatus), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.storeState()
    }

    //MARK: - UI bindings

    // request for location, will display the famous popup.
    @objc
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


    // one location setup
    @objc
    func onRequestOneUpdate(sender:UIButton) {
        if let locationManager = self.locManager,
            CLLocationManager.authorizationStatus() == .authorizedAlways || CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            locationManager.delegate = self
            locationManager.requestLocation()
        }
    }

    // read location
    @objc
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

    // location setup
    @objc
    func onRequestUpdate(sender:UISwitch) {
        if let locationManager = self.locManager,
            CLLocationManager.authorizationStatus() == .authorizedAlways || CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            locationManager.delegate = self

            if sender.isOn {
                UIApplication.shared.beginBackgroundTask(withName: "location_background_update", expirationHandler: {
                        self.textBox.text = "Did not end background task"
                        self.nextMessage()
                })

                locationManager.startUpdatingLocation()
                textBox?.text = "Location Change On"
                self.nextMessage()
            } else {
                locationManager.stopUpdatingLocation()
                textBox?.text = "Location Change Off"
                self.nextMessage()
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) { self.storeState() }
        }

    }


    // visit setup
    @objc
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

            DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) { self.storeState() }
        }
    }

    // visit setup
    @objc
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

            DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) { self.storeState() }
        }
    }

    // 200 meters geofence around me
    @objc
    func onGeoFence(sender:UISwitch) {
        if let locationManager = self.locManager,
            CLLocationManager.authorizationStatus() == .authorizedAlways || CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            locationManager.delegate = self

            if sender.isOn {
                var region: CLRegion?

                if let currentRegion = self.geocence {
                    region = currentRegion

                } else if let currentLocation = self.lastLocation {
                    region =  CLCircularRegion(center: currentLocation.coordinate, radius: 200, identifier: "Geofence")
                    self.geocence = region
                }

                guard let newregion = region else {
                    textBox?.text = "Request one location First"
                    sender.setOn(false, animated: true)
                    self.nextMessage()
                    return
                }

                locationManager.startMonitoring(for: newregion)
                textBox?.text = "Geofence Setup Done"
                self.nextMessage()

            } else {
                guard let currentGeofence = self.geocence else {
                    textBox?.text = "Error: No geofence found to stop geofencing"
                    self.nextMessage()
                    return
                }

                locationManager.stopMonitoring(for: currentGeofence)
                self.geocence = nil
                textBox?.text = "Geofence Removed"
                self.nextMessage()
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) { self.storeState() }
        }

    }


    // annoy user with a notification every time we print something
    @objc
    func onNotifyMe(sender:UISwitch) {
        if sender.isOn {
            let notificationSettings = UIUserNotificationSettings(types: UIUserNotificationType.alert, categories: nil)
            UIApplication.shared.registerUserNotificationSettings(notificationSettings)
        }

        self.notifyMe = sender.isOn

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) { self.storeState() }
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
        self.restoreStatus()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.textBox.text = "Error -> \(error)"
        self.nextMessage()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let task = UIApplication.shared.beginBackgroundTask(expirationHandler: {
            self.textBox.text = "Did not end background task"
            self.nextMessage()
        })

        self.lastLocation = locations.first
        self.textBox.text = "Location Update: \(locations.first?.debugDescription ?? "no location")"
        self.nextMessage()

        UIApplication.shared.endBackgroundTask(task)
    }

    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        let task = UIApplication.shared.beginBackgroundTask(expirationHandler: {
            self.textBox.text = "Did not end background task"
            self.nextMessage()
        })

        self.textBox.text = "Visit : \(visit.debugDescription)"
        self.nextMessage()
        UIApplication.shared.endBackgroundTask(task)
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

        if self.notifyMe {
            let notification = UILocalNotification()
            notification.alertAction = nil
            notification.alertBody = self.textBox.text ?? "No message"
            UIApplication.shared.presentLocalNotificationNow(notification)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if -self.lastMessageUpdate.timeIntervalSinceNow > 4.8 {
                self.textBox.text = ""
            }
        }
    }

    // updates the current status of the app based on what is stored and user settings
    @objc
    private func restoreStatus() {
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


    private func storeState() {
        DispatchQueue.main.async {
            UserDefaults.standard.set(self.notifyMe, forKey: ViewController.NotifyMe_key)
            UserDefaults.standard.set(self.requestVisits.isOn, forKey: ViewController.RequestVisits_key)
            UserDefaults.standard.set(self.requestSignificantLocationChange.isOn, forKey: ViewController.RequestSignificantLocationChange_key)
            UserDefaults.standard.set(self.requestLocationUpdate.isOn, forKey: ViewController.RequestUpdates_key)

            if self.requestFence.isOn, let fence = self.geocence as? CLCircularRegion {
                UserDefaults.standard.set(true, forKey: ViewController.RequestFence_key)
                UserDefaults.standard.set(fence.center.latitude, forKey: ViewController.FenceRegionLat_key)
                UserDefaults.standard.set(fence.center.longitude, forKey: ViewController.FenceRegionLon_key)
            } else {
                UserDefaults.standard.set(false, forKey: ViewController.RequestFence_key)
            }
        }
    }


    @objc
    private func restoreState() {

        if UserDefaults.standard.bool(forKey: ViewController.NotifyMe_key) {
            self.notifyMe = true
            self.requestNotifications.setOn(true, animated: false)
            self.onNotifyMe(sender: self.requestNotifications)
        }

        if UserDefaults.standard.bool(forKey: ViewController.RequestVisits_key) {
            self.requestVisits.setOn(true, animated: false)
            self.onRequestVisits(sender: self.requestVisits)
        }

        if UserDefaults.standard.bool(forKey: ViewController.RequestSignificantLocationChange_key) {
            self.requestSignificantLocationChange.setOn(true, animated: false)
            self.onRequestSignificantLocationChange(sender: self.requestSignificantLocationChange)
        }

        if UserDefaults.standard.bool(forKey: ViewController.RequestUpdates_key) {
            self.requestLocationUpdate.setOn(true, animated: false)
            self.onRequestUpdate(sender: self.requestLocationUpdate)
        }

        if UserDefaults.standard.bool(forKey: ViewController.RequestFence_key) {
            let lat = UserDefaults.standard.double(forKey: ViewController.FenceRegionLat_key)
            let lon = UserDefaults.standard.double(forKey: ViewController.FenceRegionLon_key)

            let region = CLCircularRegion(center: CLLocationCoordinate2D(latitude:lat, longitude:lon) , radius: 200, identifier: "Geofence")
            self.geocence = region

            self.requestFence.setOn(true, animated: false)
            self.onGeoFence(sender:self.requestFence)
        }
    }


}

