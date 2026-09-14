// ExportEngine.swift — MileageTax
// Generates IRS-compliant CSV and PDF mileage log files from TripEntity records.

import Foundation
import PDFKit
import UIKit
import CoreData

enum ExportEngine {

    // MARK: - CSV

    static func exportCSV(trips: [TripEntity]) -> URL {
        var rows: [String] = [
            "Date,Start Address,End Address,Miles,Max Speed (mph),Deduction (USD),Classification,Purpose,Vehicle"
        ]
        let fmt = DateFormatter()
        fmt.dateStyle = .short
        fmt.timeStyle = .short

        for trip in trips {
            let row: [String] = [
                fmt.string(from: trip.startDate ?? Date()),
                escaped(trip.startAddress ?? ""),
                escaped(trip.endAddress ?? ""),
                String(format: "%.2f", trip.totalDistanceMiles),
                String(format: "%.1f", trip.maxSpeedMph),
                String(format: "%.2f", trip.taxDeductionValueUSD),
                trip.classification ?? "unclassified",
                escaped(trip.businessPurpose ?? ""),
                escaped(trip.vehicleName ?? ""),
            ]
            rows.append(row.joined(separator: ","))
        }

        let csv     = rows.joined(separator: "\n")
        let dir     = FileManager.default.temporaryDirectory
        let fileURL = dir.appendingPathComponent("MileageTax_Export_\(dateStamp()).csv")
        try? csv.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    // MARK: - PDF

    static func exportPDF(trips: [TripEntity]) -> URL {
        let pdfRenderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: 612, height: 792)) // US Letter

        let dir     = FileManager.default.temporaryDirectory
        let fileURL = dir.appendingPathComponent("MileageTax_MileageLog_\(dateStamp()).pdf")

        let data = pdfRenderer.pdfData { ctx in
            ctx.beginPage()
            let context = ctx.cgContext
            drawPDFPage(context: context, trips: trips)
        }

        try? data.write(to: fileURL)
        return fileURL
    }

    // MARK: - PDF Drawing

    private static func drawPDFPage(context: CGContext, trips: [TripEntity]) {
        let margin: CGFloat = 40
        var y: CGFloat = margin

        // Title
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 20, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        "MileageTax — IRS Mileage Log".draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttr)
        y += 30

        // Subtitle
        let subAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.gray
        ]
        "Generated: \(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .short))"
            .draw(at: CGPoint(x: margin, y: y), withAttributes: subAttr)
        y += 20

        // Total deduction
        let total = trips.reduce(0.0) { $0 + $1.taxDeductionValueUSD }
        let totalMiles = trips.reduce(0.0) { $0 + $1.totalDistanceMiles }
        let sumAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: UIColor.black
        ]
        "Total Business Miles: \(String(format: "%.1f", totalMiles))   Est. Deduction: $\(String(format: "%.2f", total))"
            .draw(at: CGPoint(x: margin, y: y), withAttributes: sumAttr)
        y += 30

        // Draw divider
        context.setStrokeColor(UIColor.lightGray.cgColor)
        context.move(to: CGPoint(x: margin, y: y))
        context.addLine(to: CGPoint(x: 612 - margin, y: y))
        context.strokePath()
        y += 10

        // Table header
        let headerAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .bold),
            .foregroundColor: UIColor.darkGray
        ]
        let columns: [(String, CGFloat)] = [
            ("Date", 55), ("Start", 120), ("End", 120),
            ("Miles", 45), ("Class.", 55), ("Deduction", 60)
        ]
        var x = margin
        for (header, width) in columns {
            header.draw(at: CGPoint(x: x, y: y), withAttributes: headerAttr)
            x += width
        }
        y += 16

        // Table rows
        let rowAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8),
            .foregroundColor: UIColor.black
        ]
        let fmtShort = DateFormatter()
        fmtShort.dateFormat = "MM/dd/yy"

        for (idx, trip) in trips.enumerated() {
            if y > 750 { break } // simple overflow guard
            // Zebra stripe
            if idx % 2 == 1 {
                context.setFillColor(UIColor(white: 0.96, alpha: 1).cgColor)
                context.fill(CGRect(x: margin, y: y - 2, width: 612 - 2 * margin, height: 14))
            }

            x = margin
            let cells: [String] = [
                fmtShort.string(from: trip.startDate ?? Date()),
                String((trip.startAddress ?? "").prefix(18)),
                String((trip.endAddress ?? "").prefix(18)),
                String(format: "%.1f", trip.totalDistanceMiles),
                String((trip.classification ?? "").prefix(7)),
                String(format: "$%.2f", trip.taxDeductionValueUSD),
            ]
            for (cell, width) in zip(cells, columns.map { $0.1 }) {
                cell.draw(at: CGPoint(x: x, y: y), withAttributes: rowAttr)
                x += width
            }
            y += 14
        }
    }

    // MARK: - Helpers

    private static func escaped(_ s: String) -> String {
        let needs = s.contains(",") || s.contains("\"") || s.contains("\n")
        if needs { return "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\"" }
        return s
    }

    private static func dateStamp() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }
}
