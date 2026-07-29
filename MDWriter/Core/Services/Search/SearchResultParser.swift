//
//  SearchResultParser.swift
//  MDWriter
//

import Foundation

/// Lightweight HTML parser for extracting search result titles, links, and snippets from DuckDuckGo HTML output.
final class SearchResultParser: Sendable {
    static func parseDuckDuckGoHTML(_ html: String, maxResults: Int = 5) -> [SearchResult] {
        var results: [SearchResult] = []
        
        // Regex patterns to match DuckDuckGo result links and snippets
        let linkPattern = #"class="result__a"[^>]*href="([^"]+)"[^>]*>(.*?)</a>"#
        let snippetPattern = #"class="result__snippet"[^>]*>(.*?)</a>"#

        guard let linkRegex = try? NSRegularExpression(pattern: linkPattern, options: [.dotMatchesLineSeparators]),
              let snippetRegex = try? NSRegularExpression(pattern: snippetPattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        let linkMatches = linkRegex.matches(in: html, options: [], range: range)
        let snippetMatches = snippetRegex.matches(in: html, options: [], range: range)

        let count = min(min(linkMatches.count, snippetMatches.count), maxResults)
        for i in 0..<count {
            let linkMatch = linkMatches[i]
            let snippetMatch = snippetMatches[i]

            if let rawURLRange = Range(linkMatch.range(at: 1), in: html),
               let titleRange = Range(linkMatch.range(at: 2), in: html),
               let snippetRange = Range(snippetMatch.range(at: 1), in: html) {
                let rawURL = String(html[rawURLRange])
                let title = cleanText(String(html[titleRange]))
                let snippet = cleanText(String(html[snippetRange]))

                // Clean duckduckgo redirect URL if needed (uddg=...)
                let cleanURL = extractURL(from: rawURL)
                if !title.isEmpty && !cleanURL.isEmpty {
                    results.append(SearchResult(title: title, url: cleanURL, snippet: snippet))
                }
            }
        }

        return results
    }

    private static func extractURL(from urlString: String) -> String {
        if let components = URLComponents(string: urlString),
           let queryItems = components.queryItems,
           let target = queryItems.first(where: { $0.name == "uddg" })?.value {
            return target
        }
        return urlString
    }

    private static func cleanText(_ htmlSnippet: String) -> String {
        let stripped = htmlSnippet.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let decoded = stripped
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
        return decoded.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
