//
//  ViewController.swift
//  DineSmart
//
//  Created by Mohammed Al-Dahleh on 2019-06-04.
//  Copyright © 2019 Codeovo Software Ltd. All rights reserved.
//

import PinFloyd
import MapKit
import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var inspectionMapView: MKMapView!
    @IBOutlet weak var loadingLabel: UILabel!
    
    let client = InspectionClient()
    let clusteringManager = ClusteringManager()
    let inspectionDictionary = InspectionDictionary()
    
    private struct Constants {
        static let DetailSegue = "toDetailView"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setInteractionAllowed(to: false)
        
        inspectionMapView.delegate = self
        inspectionMapView.center()
        
        // TODO: WIP
        client.inspections { [weak self] result in
            guard let self = self else {
                return
            }
            
            self.setInteractionAllowed(to: true)
            
            switch result {
            case .success(let inspections):
                self.clusteringManager.add(annotations: inspections.compactMap { inspection in
                    guard let annotation = inspection.asMKAnnotation() else {
                        return nil
                    }
                    
                    self.inspectionDictionary.insert(annotation.coordinate.latitude, annotation.coordinate.longitude, value: inspection)
                    return annotation
                })
                
                self.clusteringManager.renderAnnotations(onMapView: self.inspectionMapView)
            case .failure:
                self.presentAlertWith(message: "API Request Failed")
            }
        }
    }
    
    func setInteractionAllowed(to allowed: Bool) {
        inspectionMapView.isUserInteractionEnabled = allowed
        loadingLabel.isHidden = allowed
    }
}

// MARK: - MKMapViewDelegate
extension ViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        clusteringManager.renderAnnotations(onMapView: inspectionMapView)
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let annotation = view.annotation else {
            return
        }
        
        let annotations = (annotation as? ClusterAnnotation)?.heldAnnotations ?? [annotation]
        let inspections: [[InspectedLocation]] = annotations.compactMap { [weak self] annotation in
            guard let self = self, let locations = self.inspectionDictionary.locationsAt(annotation.coordinate.latitude, annotation.coordinate.longitude) else {
                return nil
            }
            
            return locations
        }
        
        var flatInspections = inspections.flatMap { $0 }
        flatInspections.removeDuplicates()
        
        performSegue(withIdentifier: Constants.DetailSegue, sender: flatInspections)
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard annotation is ClusterAnnotation else {
            return nil
        }
        
        let id = ClusterAnnotationView.identifier
        
        var clusterView = mapView.dequeueReusableAnnotationView(withIdentifier: id)
        if clusterView == nil {
            clusterView = ClusterAnnotationView(annotation: annotation, reuseIdentifier: id)
        } else {
            clusterView?.annotation = annotation
        }
        
        return clusterView
    }
}
