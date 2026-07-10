import Foundation
import OSLog

private let logger = Logger(subsystem: "com.dirxplorerakib.pro", category: "URLAnalyzer")

/// Metadata extracted from a URL via HEAD request.
public struct URLMetadata: Sendable, Codable {
    public var fileName: String
    public var mimeType: String
    public var fileExtension: String
    public var fileSize: Int64
    public var supportsResume: Bool
    public var supportsRange: Bool
    public var contentDisposition: String
    public var server: String
    public var etag: String
    public var lastModified: String
    public var expiresAt: Date?
    public var finalURL: String
    public var statusCode: Int
    public var redirectChain: [String]
    public var acceptRanges: String

    public static let empty = URLMetadata(
        fileName: "", mimeType: "", fileExtension: "",
        fileSize: 0, supportsResume: false, supportsRange: false,
        contentDisposition: "", server: "", etag: "",
        lastModified: "", expiresAt: nil, finalURL: "",
        statusCode: 0, redirectChain: [], acceptRanges: ""
    )
}

/// Performs HEAD requests to extract download metadata before the actual download.
public actor URLMetadataAnalyzer {

    public static let shared = URLMetadataAnalyzer()

    private init() {}

    /// Analyze a URL via HEAD request and return metadata.
    public func analyze(url: URL, headers: [String: String]? = nil) async -> URLMetadata {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 30
        headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.setValue("DirXplorePro/1.0", forHTTPHeaderField: "User-Agent")

        var redirectChain: [String] = []
        var finalURL = url.absoluteString
        var statusCode = 0

        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.timeoutIntervalForRequest = 30
        let session = URLSession(configuration: sessionConfig)

        defer { session.invalidateAndCancel() }

        guard let (data, response) = try? await session.data(for: request) else {
            logger.warning("HEAD request failed for \(url.absoluteString)")
            return URLMetadata.empty
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            return URLMetadata.empty
        }

        statusCode = httpResponse.statusCode

        // Track redirects
        if let finalResp = response.url {
            finalURL = finalResp.absoluteString
        }

        let respHeaders = httpResponse.allHeaderFields
        let contentDisposition = (respHeaders["Content-Disposition"] as? String) ?? ""
        let contentType = (respHeaders["Content-Type"] as? String) ?? ""
        let contentLength = (respHeaders["Content-Length"] as? String) ?? "0"
        let server = (respHeaders["Server"] as? String) ?? ""
        let etag = (respHeaders["ETag"] as? String) ?? ""
        let lastModified = (respHeaders["Last-Modified"] as? String) ?? ""
        let acceptRanges = (respHeaders["Accept-Ranges"] as? String) ?? ""

        let fileSize = Int64(contentLength) ?? 0
        let supportsRange = acceptRanges.lowercased() == "bytes"
        let supportsResume = supportsRange && fileSize > 0 && !etag.isEmpty

        // Parse filename from Content-Disposition
        var fileName = parseFileName(from: contentDisposition)
        if fileName.isEmpty {
            // Fall back to last path segment
            let path = finalURL.split(separator: "?").first.map(String.init) ?? finalURL
            fileName = URL(string: path)?.lastPathComponent ?? ""
        }
        if fileName.isEmpty {
            fileName = "download_\(ISO8601DateFormatter().string(from: Date()))"
        }

        // Decode percent encoding
        fileName = fileName.removingPercentEncoding ?? fileName

        let fileExtension = (fileName as NSString).pathExtension

        // Parse expiration from headers or URL query
        var expiresAt: Date? = nil
        if let cacheControl = respHeaders["Cache-Control"] as? String {
            if cacheControl.contains("max-age=") {
                if let maxAgeStr = cacheControl.split(separator: "=").last,
                   let maxAge = Int(maxAgeStr) {
                    expiresAt = Date().addingTimeInterval(TimeInterval(maxAge))
                }
            }
        }
        if let expiresHeader = respHeaders["Expires"] as? String {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
            if let date = formatter.date(from: expiresHeader) {
                expiresAt = date
            }
        }

        return URLMetadata(
            fileName: fileName,
            mimeType: contentType,
            fileExtension: fileExtension,
            fileSize: fileSize,
            supportsResume: supportsResume,
            supportsRange: supportsRange,
            contentDisposition: contentDisposition,
            server: server,
            etag: etag,
            lastModified: lastModified,
            expiresAt: expiresAt,
            finalURL: finalURL,
            statusCode: statusCode,
            redirectChain: redirectChain,
            acceptRanges: acceptRanges
        )
    }

    /// Parse filename from Content-Disposition header.
    private func parseFileName(from disposition: String) -> String {
        guard !disposition.isEmpty else { return "" }

        // Try filename*=UTF-8''encoded-name
        if let starRange = disposition.range(of: "filename*=") {
            let after = disposition[starRange.upperBound...]
            if let quoteRange = after.range(of: "''") {
                let encoded = after[quoteRange.upperBound...]
                    .trimmingCharacters(in: .whitespaces)
                    .components(separatedBy: ";").first ?? ""
                return encoded.removingPercentEncoding ?? encoded
            }
            let val = after
                .trimmingCharacters(in: .whitespaces)
                .components(separatedBy: ";").first ?? ""
            return val.removingPercentEncoding ?? val
        }

        // Try filename="quoted-name"
        if let nameRange = disposition.range(of: "filename=") {
            let after = disposition[nameRange.upperBound...]
                .trimmingCharacters(in: .whitespaces)
            if after.hasPrefix("\"") {
                let start = after.index(after: after.startIndex)
                if let end = after[start...].firstIndex(of: "\"") {
                    return String(after[start..<end])
                }
            }
            return after.components(separatedBy: ";").first?
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"")) ?? ""
        }

        return ""
    }
}
