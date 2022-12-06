//
//  ViewModel.swift
//  CoreLocationApp
//
//  Created by Heston Suorsa on 11/11/22.
//

import Foundation
import CoreLocation
import UIKit
import MapKit
import UserNotifications
import FirebaseFirestore

class MapViewModel: NSObject, CLLocationManagerDelegate, ObservableObject {
    
    let firestore = FirestoreManager<FirestoreEvent>(collection: "event")
    let db = Firestore.firestore()
    
    var locationManager = CLLocationManager()
    
    @Published var userLat: Double? = nil
    @Published var userLon: Double? = nil
    var eventTimer: EventTimer? = nil
    var regionEvent: FirestoreActiveEvent? = nil
    
    
    static let shared: MapViewModel = {
        return MapViewModel()
    }()
    
    override init() {
        
        // init its parent
        super.init()
        
        // create a delegate
        locationManager.delegate = self
        
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        // request permission to the user
        locationManager.requestWhenInUseAuthorization()
        
    }
    
    // MARK - Location Manager Delegate Methods
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        
        if locationManager.authorizationStatus == .authorizedAlways ||
            locationManager.authorizationStatus == .authorizedWhenInUse {
            
            // start geolocating the user, after we get the permission
            locationManager.startUpdatingLocation()
            
        } else if locationManager.authorizationStatus == .denied {
            
            print("location access not given")
            
        }
        
    }
    
    // capture the published geolocation by the locationManager
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        //print(locations.first ?? "No location")
        
        if let userLocation = locations.first {
            self.userLat = userLocation.coordinate.latitude
            self.userLon = userLocation.coordinate.longitude
        }
    }

    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        // TODO: Start incrementing time within event zone
        
        // Check if you have been to event
        let collection = db.collection("users/\(AuthManager.shared.uid!)/active_events")
        let query = collection.whereField("event_id", isEqualTo: region.identifier)
        
        query.getDocuments() { (querySnapshot, error) in
            if let error = error {
                print(error.localizedDescription)
            } else {
                // If the event was active already
                if let doc = querySnapshot?.documents.first, doc.exists {
                    
                    print("event was already activated before")
                    
                    // Get the remaining seconds to tick down from
                    do {
                        
                        self.regionEvent = try doc.data(as: FirestoreActiveEvent.self)
                        // Start timer
                        self.eventTimer = EventTimer(event: self.regionEvent!)
                        self.eventTimer?.start()
                        
                    } catch {
                        print("Error reading in firestore active event model from firestore data")
                    }
                    //self.seconds = doc.data()["seconds"] as! Int
                    
                } else { // New event => Initialize it in db
                    
                    print("discovered a brand new event!")
                    
                    if let event = self.firestore.firestoreModels.first(where: { $0.id == region.identifier }) {
                        // Add to user's active events
                        do {
                            print("Adding to user a new active event")
                            try collection.addDocument(from: FirestoreActiveEvent(event_id: region.identifier, seconds: event.seconds)) // ["event_id": region.identifier, "seconds": event.seconds])
                        } catch {
                            print("Error uploading the active event to firebase")
                        }
                        // Get the remaining seconds to tick down from
                        self.regionEvent = FirestoreActiveEvent(event_id: event.id!, seconds: event.seconds)
                        
                        // Start timer
                        self.eventTimer = EventTimer(event: self.regionEvent!)
                        self.eventTimer?.start()
                    }
                    
                }
            }
        }
        
        let title = "You Entered the Region"
        let message = "Wow theres cool stuff in here! YAY!"
        print("\(title): \(message)")
        print("Region: \(region.identifier)")
    }
        
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        // TODO: Stop incrementing time within event zone
        if let timer = eventTimer {
            timer.stop()
            
            // Upload new time
            let collection = db.collection("users/\(AuthManager.shared.uid!)/active_events")
            let query = collection.whereField("event_id", isEqualTo: region.identifier)
            query.getDocuments() { (querySnapshot, error) in
                if let error = error {
                    print(error.localizedDescription)
                } else {
                    
                    if let doc = querySnapshot?.documents.first, doc.exists {
                        collection.document(doc.documentID).updateData(["seconds": timer.active_event.seconds])
                    }
                    
                }
            }
        }
        
        let title = "You Left the Region"
        let message = "Say bye bye to all that cool stuff. =["
        print("\(title): \(message)")
        print("Region: \(region.identifier)")
    }
    
}

// Event timer stuff

enum mode {
    case running
    case stopped
    case finished
}

class EventTimer: ObservableObject {
    var timer = Timer()
    
    @Published var status : mode = .stopped
    var active_event: FirestoreActiveEvent
    
    init (event: FirestoreActiveEvent) {
        self.active_event = event
        print("Timer is init")
    }
    
    func start() {
        print("started timer")
        status = .running
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.active_event.seconds -= 1
            print("Time remaining: \(self.active_event.seconds) seconds")
            if self.active_event.seconds <= 0 {
                print("Time limit reached!")
                self.finish()
            }
        }
    }
    
    func finish() {
        print("timer reached .finished")
        status = .finished
        active_event.seconds = 0
        timer.invalidate()
    }
    
    func stop() {
        print("stopped timer")
        if (status != .finished) {
            status = .stopped
        }
        timer.invalidate()
    }
}


