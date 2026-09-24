// ExportEngine.swift — MileageTax
// Phase 5 & 6: Premium multi-page PDF + 20-field CSV export engine.
// Sources: IRS Pub 463, HMRC record-keeping guidance, ATO requirements.

import Foundation
import PDFKit
import UIKit
import CoreData
import MapKit

enum ExportEngine {

    // MARK: - Shared Settings

    private static var currencySymbol: String {
        UserDefaults.standard.string(forKey: AppStorageKeys.currencySymbol) ?? "$"
    }
    private static var distanceUnit: String {
        UserDefaults.standard.string(forKey: AppStorageKeys.distanceUnit) ?? "mi"
    }
    private static var countryLabel: String {
        UserDefaults.standard.string(forKey: AppStorageKeys.countryTaxLabel) ?? "IRS Standard (USA)"
    }

    // MARK: - Rate for a given trip date

    /// Full tax record active for the given date (native-unit rate + effective dates).
    private static func rateRecord(for date: Date) -> TaxRateRecord? {
        let country = countryLabel
        let match = TaxRuleEngine.database.first { r in
            country.contains(r.country) || country.contains(r.authority)
        }
        guard let match else { return nil }
        return TaxRuleEngine.database
            .filter { $0.country == match.country }
            .first { r in r.effectiveFrom <= date && (r.effectiveTo == nil || r.effectiveTo! >= date) }
            ?? match
    }

    private static func rate(for date: Date) -> Double {
        if let record = rateRecord(for: date) { return record.rate }
        let saved = UserDefaults.standard.double(forKey: AppStorageKeys.irsRateOverride)
        return saved > 0 ? saved : MileageTaxDefaults.irsRatePerMile
    }

    /// Accurate deduction value for a trip: personal trips are always $0;
    /// business/unclassified use the stored value, falling back to miles × rate.
    private static func deduction(for trip: TripEntity, appliedRate: Double) -> Double {
        if trip.classification == "personal" { return 0 }
        if trip.taxDeductionValueUSD > 0 { return trip.taxDeductionValueUSD }
        return trip.totalDistanceMiles * appliedRate
    }

    // MARK: ─── PHASE 6: Rich 20-Field CSV ────────────────────────────────

    static func exportCSV(trips: [TripEntity]) -> URL {
        let header = [
            "Trip ID", "Date", "Start Time", "End Time",
            "Start Address", "Start Landmark", "End Address", "End Landmark",
            "Purpose", "Classification", "Vehicle",
            "Start Latitude", "Start Longitude", "End Latitude", "End Longitude",
            "Distance (\(distanceUnit))", "Tax Authority", "Rate Applied",
            "Rate Effective Date", "Mileage Value (\(currencySymbol))",
            "Parking (\(currencySymbol))", "Tolls (\(currencySymbol))",
            "Total Value (\(currencySymbol))", "Track Method", "Breadcrumb Count", "Notes"
        ].joined(separator: ",")

        let dateFmt = DateFormatter(); dateFmt.dateFormat = "yyyy-MM-dd"
        let timeFmt = DateFormatter(); timeFmt.dateFormat = "HH:mm"

        var rows: [String] = [header]

        for trip in trips {
            let tripDate = trip.startDate ?? Date()
            let appliedRate = rate(for: tripDate)
            let effectiveDate = rateRecord(for: tripDate)?.effectiveFrom ?? tripDate
            let deduction = Self.deduction(for: trip, appliedRate: appliedRate)

            let breadcrumbCount: Int = {
                guard let data = trip.breadcrumbsData,
                      let crumbs = try? JSONDecoder().decode([TripBreadcrumb].self, from: data)
                else { return 0 }
                return crumbs.count
            }()
            let trackMethod = breadcrumbCount > 0 ? "GPS Automatic (\(breadcrumbCount) pts)" : "Manual"

            let cells: [String] = [
                escaped(trip.id?.uuidString ?? ""),
                dateFmt.string(from: tripDate),
                timeFmt.string(from: trip.startDate ?? Date()),
                timeFmt.string(from: trip.endDate ?? Date()),
                escaped(trip.startAddress ?? ""),
                escaped(trip.startLandmark ?? trip.startAddress ?? ""),
                escaped(trip.endAddress ?? ""),
                escaped(trip.endLandmark ?? trip.endAddress ?? ""),
                escaped(trip.businessPurpose ?? ""),
                escaped(trip.classification ?? "unclassified"),
                escaped(trip.vehicleName ?? ""),
                String(format: "%.6f", trip.startLatitude),
                String(format: "%.6f", trip.startLongitude),
                String(format: "%.6f", trip.endLatitude),
                String(format: "%.6f", trip.endLongitude),
                String(format: "%.2f", MileageUnits.distanceValue(trip.totalDistanceMiles)),
                escaped(countryLabel),
                String(format: "%.4f", appliedRate),
                dateFmt.string(from: effectiveDate),
                String(format: "%.2f", deduction),
                "",   // parking — not tracked
                "",   // tolls   — not tracked
                String(format: "%.2f", deduction),
                trackMethod,
                String(breadcrumbCount),
                ""    // notes
            ]
            rows.append(cells.joined(separator: ","))
        }

        let csv = rows.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MileageTax_Export_\(dateStamp()).csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: ─── PHASE 5: Premium 3-Section PDF ────────────────────────────

    static func exportPDF(trips: [TripEntity], userName: String = "Taxpayer", startDate: Date? = nil, endDate: Date? = nil) -> URL {
        let pageW: CGFloat = 612
        let pageH: CGFloat = 792
        let margin: CGFloat = 44

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MileageTax_Report_\(dateStamp()).pdf")

        let businessTrips = trips.filter { $0.classification == "business" }
        let totalMiles    = trips.reduce(0.0) { $0 + $1.totalDistanceMiles }
        let totalDeduct   = businessTrips.reduce(0.0) { $0 + $1.taxDeductionValueUSD }

        let dateFmtLabel = DateFormatter()
        dateFmtLabel.dateFormat = "MMM d, yyyy"
        let rangeLabel: String = {
            if let s = startDate, let e = endDate {
                return "\(dateFmtLabel.string(from: s)) – \(dateFmtLabel.string(from: e))"
            }
            return "Tax Year \(Calendar.current.component(.year, from: Date()))"
        }()

        let data = renderer.pdfData { ctx in
            // ── Page 1: Cover & Summary ──────────────────────────────────
            ctx.beginPage()
            let gc = ctx.cgContext
            drawSummaryPage(gc: gc, pageW: pageW, margin: margin,
                            trips: trips,
                            totalMiles: totalMiles, totalDeduct: totalDeduct,
                            userName: userName, rangeLabel: rangeLabel)

            // ── Pages 2+: Detailed Trip Log ──────────────────────────────
            var yPos: CGFloat = 0
            var isFirstTripPage = true

            for trip in trips {
                let blockHeight: CGFloat = 120
                if yPos == 0 || yPos + blockHeight > pageH - margin {
                    ctx.beginPage()
                    yPos = isFirstTripPage
                        ? drawDetailPageHeader(gc: ctx.cgContext, pageW: pageW, margin: margin)
                        : drawDetailPageHeader(gc: ctx.cgContext, pageW: pageW, margin: margin)
                    isFirstTripPage = false
                }
                yPos = drawTripRow(gc: ctx.cgContext, trip: trip,
                                   yPos: yPos, margin: margin, pageW: pageW)
            }

            // ── Last Page: Certification Footer ──────────────────────────
            ctx.beginPage()
            drawCertificationPage(gc: ctx.cgContext, pageW: pageW, margin: margin,
                                  totalMiles: totalMiles, totalDeduct: totalDeduct)
        }

        try? data.write(to: url)
        return url
    }

    // MARK: - PDF Drawing Helpers

    // Color constants
    private static let green  = UIColor(red: 0.00, green: 1.00, blue: 0.53, alpha: 1)
    private static let cyan   = UIColor(red: 0.00, green: 0.90, blue: 1.00, alpha: 1)
    private static let dark   = UIColor(red: 0.02, green: 0.04, blue: 0.05, alpha: 1)
    private static let grey   = UIColor(red: 0.40, green: 0.40, blue: 0.40, alpha: 1)

    private static func drawSummaryPage(gc: CGContext, pageW: CGFloat, margin: CGFloat,
                                        trips: [TripEntity],
                                        totalMiles: Double, totalDeduct: Double, userName: String,
                                        rangeLabel: String = "") {
        var y: CGFloat = margin

        // ── Header band ──────────────────────────────────────────────────
        gc.setFillColor(dark.cgColor)
        gc.fill(CGRect(x: 0, y: 0, width: pageW, height: 120))

        // App name
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 22, weight: .black),
            .foregroundColor: UIColor.white
        ]
        "MILEAGETAX".draw(at: CGPoint(x: margin, y: 24), withAttributes: titleAttr)

        let subtitleAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: green
        ]
        let reportRangeText: String
        if rangeLabel.isEmpty {
            reportRangeText = "MILEAGE LOG REPORT · TAX YEAR \(Calendar.current.component(.year, from: Date()))"
        } else {
            reportRangeText = "MILEAGE LOG REPORT · \(rangeLabel.uppercased())"
        }
        reportRangeText.draw(at: CGPoint(x: margin, y: 50), withAttributes: subtitleAttr)

        let metaAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.lightGray
        ]
        "Driver: \(userName)   |   Tax Authority: \(countryLabel)   |   Rate: \(currencySymbol)\(String(format: "%.3f", rate(for: Date())))/\(distanceUnit)".draw(
            at: CGPoint(x: margin, y: 72), withAttributes: metaAttr)
        "Generated: \(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .short))".draw(
            at: CGPoint(x: margin, y: 90), withAttributes: metaAttr)

        y = 140

        // ── Summary Block ────────────────────────────────────────────────
        drawSectionHeader(gc: gc, title: "MILEAGE SUMMARY", y: y, margin: margin, pageW: pageW)
        y += 28

        let bizMiles  = trips.filter { $0.classification == "business" }.reduce(0.0) { $0 + $1.totalDistanceMiles }
        let persMiles = trips.filter { $0.classification == "personal" }.reduce(0.0) { $0 + $1.totalDistanceMiles }
        let uncMiles  = trips.filter { $0.classification == "unclassified" }.reduce(0.0) { $0 + $1.totalDistanceMiles }

        let summaryItems: [(String, String)] = [
            ("Business \(distanceUnit.uppercased())", String(format: "%.1f \(distanceUnit)", MileageUnits.distanceValue(bizMiles))),
            ("Business Deduction", String(format: "\(currencySymbol)%.2f", totalDeduct)),
            ("Personal \(distanceUnit.uppercased())", String(format: "%.1f \(distanceUnit)", MileageUnits.distanceValue(persMiles))),
            ("Unclassified \(distanceUnit.uppercased())", String(format: "%.1f \(distanceUnit)", MileageUnits.distanceValue(uncMiles))),
            ("Rate Applied", "\(currencySymbol)\(String(format: "%.3f", rate(for: Date())))/\(distanceUnit)"),
            ("Parking", "\(currencySymbol)0.00"),
            ("Tolls", "\(currencySymbol)0.00"),
            ("TOTAL LOGGED \(distanceUnit.uppercased())", String(format: "%.1f \(distanceUnit)", MileageUnits.distanceValue(totalMiles))),
            ("TOTAL DEDUCTION", String(format: "\(currencySymbol)%.2f", totalDeduct)),
        ]
        for (i, item) in summaryItems.enumerated() {
            let isBold = i == summaryItems.count - 1
            drawKeyValueRow(gc: gc, key: item.0, value: item.1, y: y, margin: margin,
                            pageW: pageW, bold: isBold, highlight: isBold)
            y += 22
        }

        y += 16

        // ── Trip Counts ──────────────────────────────────────────────────
        drawSectionHeader(gc: gc, title: "TRIP SUMMARY", y: y, margin: margin, pageW: pageW)
        y += 28

        let biz  = trips.filter { $0.classification == "business" }.count
        let pers = trips.filter { $0.classification == "personal" }.count
        let unc  = trips.filter { $0.classification == "unclassified" }.count
        let tripItems: [(String, String)] = [
            ("Business Trips", String(biz)),
            ("Personal Trips", String(pers)),
            ("Unclassified Trips", String(unc)),
            ("Total Trips Logged", String(trips.count)),
        ]
        for item in tripItems {
            drawKeyValueRow(gc: gc, key: item.0, value: item.1, y: y, margin: margin,
                            pageW: pageW, bold: false, highlight: false)
            y += 22
        }
    }

    private static func drawDetailPageHeader(gc: CGContext, pageW: CGFloat, margin: CGFloat) -> CGFloat {
        var y: CGFloat = 40
        let headerAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .black),
            .foregroundColor: dark
        ]
        "DETAILED MILEAGE LOG".draw(at: CGPoint(x: margin, y: y), withAttributes: headerAttr)
        y += 20

        // Column headers
        let colAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .bold),
            .foregroundColor: grey
        ]
        let columns: [(String, CGFloat)] = [
            ("DATE", 60), ("FROM → TO", 200), ("\(distanceUnit.uppercased())", 45),
            ("CLASS.", 60), ("RATE", 50), ("DEDUCTION", 65)
        ]
        var x = margin
        for (title, width) in columns {
            title.draw(at: CGPoint(x: x, y: y), withAttributes: colAttr)
            x += width
        }
        y += 14

        gc.setStrokeColor(UIColor.lightGray.cgColor)
        gc.move(to: CGPoint(x: margin, y: y))
        gc.addLine(to: CGPoint(x: pageW - margin, y: y))
        gc.strokePath()

        return y + 8
    }

    private static func drawTripRow(gc: CGContext, trip: TripEntity,
                                    yPos: CGFloat, margin: CGFloat, pageW: CGFloat) -> CGFloat {
        var y = yPos
        let appliedRate = rate(for: trip.startDate ?? Date())
        let deduction = Self.deduction(for: trip, appliedRate: appliedRate)

        let dateFmt = DateFormatter(); dateFmt.dateFormat = "MM/dd/yy"
        let timeFmt = DateFormatter(); dateFmt.dateFormat = "h:mm a"

        let rowAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8.5),
            .foregroundColor: UIColor.black
        ]
        let boldAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8.5, weight: .semibold),
            .foregroundColor: UIColor.black
        ]

        let dateStr    = dateFmt.string(from: trip.startDate ?? Date())
        let startLabel = trip.startLandmark ?? trip.startAddress ?? "—"
        let endLabel   = trip.endLandmark ?? trip.endAddress ?? "—"
        let fromTo     = "\(String(startLabel.prefix(22)))\n→ \(String(endLabel.prefix(22)))"
        let milesStr   = String(format: "%.1f", MileageUnits.distanceValue(trip.totalDistanceMiles))
        let classStr   = String((trip.classification ?? "").prefix(7))
        let rateStr    = "\(currencySymbol)\(String(format: "%.3f", appliedRate))"
        let deductStr  = String(format: "\(currencySymbol)%.2f", deduction)

        let cols: [(String, CGFloat, Bool)] = [
            (dateStr, 60, false), (fromTo, 200, false), (milesStr, 45, false),
            (classStr, 60, false), (rateStr, 50, false), (deductStr, 65, true)
        ]

        var x = margin
        let rowH: CGFloat = trip.businessPurpose != nil ? 36 : 26
        for (text, width, bold) in cols {
            let attr = bold ? boldAttr : rowAttr
            let rect = CGRect(x: x, y: y, width: width - 4, height: rowH)
            text.draw(in: rect, withAttributes: attr)
            x += width
        }

        // Purpose sub-row
        if let purpose = trip.businessPurpose, !purpose.isEmpty {
            y += 20
            let purposeAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 7.5),
                .foregroundColor: grey
            ]
            "Purpose: \(purpose)".draw(at: CGPoint(x: margin + 62, y: y), withAttributes: purposeAttr)
        }

        y += 20

        // Divider
        gc.setStrokeColor(UIColor(white: 0.92, alpha: 1).cgColor)
        gc.move(to: CGPoint(x: margin, y: y))
        gc.addLine(to: CGPoint(x: pageW - margin, y: y))
        gc.strokePath()

        return y + 6
    }

    private static func drawCertificationPage(gc: CGContext, pageW: CGFloat, margin: CGFloat,
                                              totalMiles: Double, totalDeduct: Double) {
        var y: CGFloat = margin

        gc.setFillColor(dark.cgColor)
        gc.fill(CGRect(x: 0, y: 0, width: pageW, height: 80))

        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .black),
            .foregroundColor: UIColor.white
        ]
        "MILEAGE RECORD CERTIFICATION".draw(at: CGPoint(x: margin, y: 24), withAttributes: titleAttr)

        y = 110
        let bodyAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.darkGray
        ]
        let certText = """
This document contains an automatically generated mileage log produced by the MileageTax application.

Each trip record includes: date, start location, end location, business purpose, distance, and the \
\(countryLabel) rate applied on the date of travel (\(currencySymbol)\(String(format: "%.3f", rate(for: Date())))/\(distanceUnit)).

SUMMARY
  Total Business \(distanceUnit.uppercased()): \(String(format: "%.1f", totalMiles)) \(distanceUnit)
  Total Estimated Deduction: \(currencySymbol)\(String(format: "%.2f", totalDeduct))
  Tax Authority: \(countryLabel)
  Report Generated: \(DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .medium))

RECORD-KEEPING NOTICE
This report is intended to assist with tax record-keeping. Please consult a qualified \
tax professional or accountant to confirm the applicability of these records to your specific \
tax situation. The app does not provide tax advice.

For US taxpayers: Records should be maintained in compliance with IRS Publication 463, \
which requires taxpayers to keep adequate records to establish the amount, time, place, \
and business purpose of each vehicle expense claimed.
"""
        let rect = CGRect(x: margin, y: y, width: pageW - 2 * margin, height: 600)
        certText.draw(in: rect, withAttributes: bodyAttr)
    }

    private static func drawSectionHeader(gc: CGContext, title: String, y: CGFloat,
                                          margin: CGFloat, pageW: CGFloat) {
        gc.setFillColor(UIColor(white: 0.95, alpha: 1).cgColor)
        gc.fill(CGRect(x: margin, y: y, width: pageW - 2 * margin, height: 22))

        let attr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .black),
            .foregroundColor: dark
        ]
        title.draw(at: CGPoint(x: margin + 8, y: y + 6), withAttributes: attr)
    }

    private static func drawKeyValueRow(gc: CGContext, key: String, value: String,
                                        y: CGFloat, margin: CGFloat, pageW: CGFloat,
                                        bold: Bool, highlight: Bool) {
        if highlight {
            gc.setFillColor(UIColor(red: 0, green: 0.3, blue: 0.2, alpha: 0.08).cgColor)
            gc.fill(CGRect(x: margin, y: y - 2, width: pageW - 2 * margin, height: 20))
        }

        let keyAttr: [NSAttributedString.Key: Any] = [
            .font: bold ? UIFont.systemFont(ofSize: 9, weight: .bold) : UIFont.systemFont(ofSize: 9),
            .foregroundColor: bold ? dark : grey
        ]
        let valAttr: [NSAttributedString.Key: Any] = [
            .font: bold ? UIFont.systemFont(ofSize: 10, weight: .black) : UIFont.systemFont(ofSize: 9, weight: .semibold),
            .foregroundColor: bold ? dark : UIColor.black
        ]
        key.draw(at: CGPoint(x: margin + 8, y: y), withAttributes: keyAttr)
        let valWidth = (value as NSString).size(withAttributes: valAttr).width
        value.draw(at: CGPoint(x: pageW - margin - valWidth - 8, y: y), withAttributes: valAttr)
    }

    // MARK: - Helpers

    private static func escaped(_ s: String) -> String {
        let needs = s.contains(",") || s.contains("\"") || s.contains("\n")
        if needs { return "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\"" }
        return s
    }

    private static func dateStamp() -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }
}
