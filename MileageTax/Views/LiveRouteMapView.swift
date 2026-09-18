//
//  LiveRouteMapView.swift
//  MileageTax — Phase 1: Live Hybrid Map for TrackView & RadarView
//
//  Renders a MKMapView (hybrid satellite) with a live-updating polyline
//  drawn from TripTrackerService.liveBreadcrumbs.
//

import SwiftUI
import MapKit
internal import Combine

// MARK: - Live Route Map (UIViewRepresentable)

struct LiveRouteMapView: UIViewRepresentable {
    /// Breadcrumbs to render — passed in from TripTrackerService
    var breadcrumbs: [TripBreadcrumb]
    var startCoordinate: CLLocationCoordinate2D?
    var isTracking: Bool

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.mapType = .hybridFlyover
        map.showsUserLocation = true
        map.showsCompass = false
        map.showsScale = false
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.isZoomEnabled = true
        map.isScrollEnabled = false
        map.userTrackingMode = .followWithHeading
        map.delegate = context.coordinator

        // Dark overlay for obsidian theme blending
        map.overrideUserInterfaceStyle = .dark
        map.layer.cornerRadius = 20
        map.clipsToBounds = true
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        // Remove old overlays
        map.removeOverlays(map.overlays)
        map.removeAnnotations(map.annotations.filter { !($0 is MKUserLocation) })

        let coords = breadcrumbs.map { $0.coordinate }
        guard coords.count >= 2 else { return }

        // Draw route polyline
        let polyline = MKPolyline(coordinates: coords, count: coords.count)
        map.addOverlay(polyline, level: .aboveRoads)

        // Start pin
        if let first = coords.first {
            let startPin = RouteAnnotation(coordinate: first, isStart: true)
            map.addAnnotation(startPin)
        }

        // Fit region to route when not actively tracking
        if !isTracking, let region = regionFitting(coords: coords) {
            map.setRegion(region, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    private func regionFitting(coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
        guard !coords.isEmpty else { return nil }
        var minLat = coords[0].latitude, maxLat = coords[0].latitude
        var minLon = coords[0].longitude, maxLon = coords[0].longitude
        for c in coords {
            minLat = min(minLat, c.latitude);  maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude); maxLon = max(maxLon, c.longitude)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                            longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(latitudeDelta: (maxLat - minLat) * 1.4 + 0.003,
                                    longitudeDelta: (maxLon - minLon) * 1.4 + 0.003)
        return MKCoordinateRegion(center: center, span: span)
    }

    // MARK: - Coordinator
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = UIColor(red: 0, green: 1, blue: 0.53, alpha: 0.9) // #00FF88
            renderer.lineWidth = 4
            renderer.lineCap = .round
            renderer.lineJoin = .round
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let routeAnnot = annotation as? RouteAnnotation else { return nil }
            let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "route")
            view.markerTintColor = routeAnnot.isStart
                ? UIColor(red: 0, green: 1, blue: 0.53, alpha: 1)
                : UIColor(red: 0, green: 0.9, blue: 1, alpha: 1)
            view.glyphImage = UIImage(systemName: routeAnnot.isStart ? "figure.stand" : "flag.checkered")
            return view
        }
    }
}

// MARK: - Route Annotation

class RouteAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let isStart: Bool
    init(coordinate: CLLocationCoordinate2D, isStart: Bool) {
        self.coordinate = coordinate
        self.isStart = isStart
    }
}

// MARK: - Completed Trip Route Map (for Classify / Vault)

struct TripRouteMapView: UIViewRepresentable {
    var breadcrumbs: [TripBreadcrumb]
    var startCoord: CLLocationCoordinate2D?
    var endCoord: CLLocationCoordinate2D?
    var mapType: MKMapType = .hybridFlyover

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.mapType = mapType
        map.showsUserLocation = false
        map.showsCompass = false
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.isScrollEnabled = true
        map.isZoomEnabled = true
        map.overrideUserInterfaceStyle = .dark
        map.layer.cornerRadius = 20
        map.clipsToBounds = true
        map.delegate = context.coordinator
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.removeOverlays(map.overlays)
        map.removeAnnotations(map.annotations)

        let coords = breadcrumbs.map { $0.coordinate }

        if coords.count >= 2 {
            let polyline = MKPolyline(coordinates: coords, count: coords.count)
            map.addOverlay(polyline, level: .aboveRoads)
        }

        // Pins
        if let start = (startCoord ?? coords.first) {
            map.addAnnotation(RouteAnnotation(coordinate: start, isStart: true))
        }
        if let end = (endCoord ?? coords.last) {
            map.addAnnotation(RouteAnnotation(coordinate: end, isStart: false))
        }

        // Fit to route
        if let region = regionFitting(coords: coords.isEmpty ? [startCoord, endCoord].compactMap { $0 } : coords) {
            map.setRegion(region, animated: false)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    private func regionFitting(coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
        guard !coords.isEmpty else { return nil }
        if coords.count == 1 {
            return MKCoordinateRegion(center: coords[0], latitudinalMeters: 1000, longitudinalMeters: 1000)
        }
        var minLat = coords[0].latitude, maxLat = coords[0].latitude
        var minLon = coords[0].longitude, maxLon = coords[0].longitude
        for c in coords {
            minLat = min(minLat, c.latitude);  maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude); maxLon = max(maxLon, c.longitude)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                            longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(latitudeDelta: (maxLat - minLat) * 1.5 + 0.005,
                                    longitudeDelta: (maxLon - minLon) * 1.5 + 0.005)
        return MKCoordinateRegion(center: center, span: span)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = UIColor(red: 0, green: 1, blue: 0.53, alpha: 0.85)
            renderer.lineWidth = 3.5
            renderer.lineCap = .round
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let routeAnnot = annotation as? RouteAnnotation else { return nil }
            let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "routePin")
            view.markerTintColor = routeAnnot.isStart
                ? UIColor(red: 0, green: 1, blue: 0.53, alpha: 1)
                : UIColor(red: 0, green: 0.9, blue: 1, alpha: 1)
            view.glyphImage = UIImage(systemName: routeAnnot.isStart ? "smallcircle.filled.circle" : "checkmark.circle.fill")
            return view
        }
    }
}
