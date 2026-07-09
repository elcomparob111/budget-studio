import Foundation
import UIKit
import Vision

/// Prefill values for AddTransactionSheet after a receipt/screenshot scan.
struct TransactionPrefill: Equatable {
    var date: Date?
    var type: String?
    var description: String?
    var amount: String?
    var category: String?
    var account: String?
}

struct ReceiptScanResult: Equatable {
    var amount: Double?
    var date: Date?
    var merchant: String?
    var type: String
    var rawText: String

    var asPrefill: TransactionPrefill {
        TransactionPrefill(
            date: date,
            type: type,
            description: merchant,
            amount: amount.map { String(format: "%g", $0) },
            category: nil,
            account: nil
        )
    }
}

enum ReceiptOCRService {
    enum OCRError: LocalizedError {
        case noImage
        case recognitionFailed
        case noTextFound

        var errorDescription: String? {
            switch self {
            case .noImage: return "Could not read that image."
            case .recognitionFailed: return "Text recognition failed. Try a clearer photo."
            case .noTextFound: return "No text found in the image."
            }
        }
    }

    static func recognize(from image: UIImage) async throws -> ReceiptScanResult {
        guard let cgImage = image.cgImage ?? image.normalizedCGImage() else {
            throw OCRError.noImage
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try await Task.detached(priority: .userInitiated) {
            try handler.perform([request])
        }.value

        guard let observations = request.results, !observations.isEmpty else {
            throw OCRError.noTextFound
        }

        let lines = observations
            .compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { throw OCRError.noTextFound }

        return parse(lines: lines)
    }

    static func parse(lines: [String]) -> ReceiptScanResult {
        let fullText = lines.joined(separator: "\n")
        let amount = extractAmount(from: lines, fullText: fullText)
        let date = extractDate(from: lines, fullText: fullText)
        let merchant = extractMerchant(from: lines)
        let type = inferType(from: fullText)

        return ReceiptScanResult(
            amount: amount,
            date: date,
            merchant: merchant,
            type: type,
            rawText: fullText
        )
    }

    // MARK: - Amount

    private static func extractAmount(from lines: [String], fullText: String) -> Double? {
        let currencyPattern = #"(?:\$|USD\s*)?\s*(\d{1,3}(?:,\d{3})*(?:\.\d{2})|\d+\.\d{2})"#
        let totalKeywords = ["total", "amount due", "amount", "balance", "charged", "payment", "paid"]

        var labeled: [Double] = []
        var all: [Double] = []

        for line in lines {
            let lower = line.lowercased()
            let values = matches(currencyPattern, in: line).compactMap(parseCurrency)
            all.append(contentsOf: values)
            if totalKeywords.contains(where: { lower.contains($0) }) {
                labeled.append(contentsOf: values)
            }
        }

        if labeled.isEmpty {
            labeled = matches(currencyPattern, in: fullText).compactMap(parseCurrency)
        }

        let candidates = (labeled.isEmpty ? all : labeled)
            .filter { $0 > 0 && $0 < 100_000 }
            .sorted(by: >)

        return candidates.first
    }

    private static func parseCurrency(_ raw: String) -> Double? {
        let cleaned = raw
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "USD", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(cleaned)
    }

    // MARK: - Date

    private static func extractDate(from lines: [String], fullText: String) -> Date? {
        let patterns = [
            #"\b(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\b"#,
            #"\b((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?\s+\d{1,2},?\s+\d{2,4})\b"#,
            #"\b(\d{4}-\d{2}-\d{2})\b"#
        ]

        let formats = [
            "M/d/yyyy", "M/d/yy", "MM/dd/yyyy", "MM/dd/yy",
            "M-d-yyyy", "M-d-yy", "yyyy-MM-dd",
            "MMM d, yyyy", "MMM d yyyy", "MMMM d, yyyy", "MMMM d yyyy"
        ]

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current

        for pattern in patterns {
            for match in matches(pattern, in: fullText) {
                for format in formats {
                    formatter.dateFormat = format
                    if let date = formatter.date(from: match) {
                        return date
                    }
                }
            }
        }

        // Prefer a line that looks like a date near the top
        for line in lines.prefix(8) {
            for pattern in patterns {
                for match in matches(pattern, in: line) {
                    for format in formats {
                        formatter.dateFormat = format
                        if let date = formatter.date(from: match) {
                            return date
                        }
                    }
                }
            }
        }

        return nil
    }

    // MARK: - Merchant

    private static func extractMerchant(from lines: [String]) -> String? {
        let skipFragments = [
            "receipt", "thank you", "visa", "mastercard", "amex", "discover",
            "auth", "approval", "card ending", "****", "www.", "http",
            "tel", "phone", "fax", "invoice", "order #", "confirmation"
        ]

        for line in lines.prefix(10) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 2, trimmed.count <= 48 else { continue }
            let lower = trimmed.lowercased()
            if skipFragments.contains(where: { lower.contains($0) }) { continue }
            if trimmed.range(of: #"^\d+$"#, options: .regularExpression) != nil { continue }
            if trimmed.range(of: #"^\$?\d"#, options: .regularExpression) != nil { continue }
            if extractDate(from: [trimmed], fullText: trimmed) != nil { continue }
            // Skip pure address-ish lines
            if lower.contains("street") || lower.contains("ave") || lower.contains("road") { continue }
            return trimmed
        }
        return lines.first
    }

    // MARK: - Type heuristic

    private static func inferType(from text: String) -> String {
        let lower = text.lowercased()
        let incomeKeywords = [
            "refund", "payroll", "paycheck", "direct deposit", "deposit",
            "salary", "reimbursement", "credit issued", "payment received",
            "you received", "incoming", "wage", "bonus"
        ]
        if incomeKeywords.contains(where: { lower.contains($0) }) {
            return "Income"
        }
        return "Expense"
    }

    // MARK: - Regex helpers

    private static func matches(_ pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, options: [], range: range).compactMap { match in
            let group = match.numberOfRanges > 1 ? 1 : 0
            guard let swiftRange = Range(match.range(at: group), in: text) else { return nil }
            return String(text[swiftRange])
        }
    }
}

private extension UIImage {
    /// Flattens orientation so Vision always sees upright pixels.
    func normalizedCGImage() -> CGImage? {
        if imageOrientation == .up, let cgImage { return cgImage }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let rendered = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.cgImage
    }
}
