//
//  WebSearchTool.swift
//  MDWriter
//

import Foundation

struct SearchResult: Identifiable, Codable, Sendable {
    let id: UUID
    let title: String
    let url: String
    let snippet: String

    init(title: String, url: String, snippet: String) {
        self.id = UUID()
        self.title = title
        self.url = url
        self.snippet = snippet
    }
}

enum WebSearchEngineProvider: String, CaseIterable, Identifiable, Codable, Sendable {
    case duckDuckGo = "ddg"
    case searxng = "searxng"
    case brave = "brave"
    case tavily = "tavily"
    case exa = "exa"
    case google = "google"
    case bing = "bing"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .duckDuckGo: return "DuckDuckGo (Built-in Free)"
        case .searxng: return "SearXNG (Self-Hosted)"
        case .brave: return "Brave Search"
        case .tavily: return "Tavily Search (AI)"
        case .exa: return "Exa Search (AI)"
        case .google: return "Google Custom Search"
        case .bing: return "Bing Web Search"
        }
    }
}

/// Zero-API Key or multi-provider web search tool supporting DDG, SearXNG, Brave, Tavily, Exa, Google, Bing.
final class WebSearchTool: Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Perform web search and return structured search results.
    func search(query: String, maxResults: Int = 5) async throws -> [SearchResult] {
        let isEnabled = UserDefaults.standard.object(forKey: "searchEnabled") as? Bool ?? true
        guard isEnabled else { return [] }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }

        let engineRaw = UserDefaults.standard.string(forKey: "searchEngine") ?? "ddg"
        let engine = WebSearchEngineProvider(rawValue: engineRaw) ?? .duckDuckGo

        switch engine {
        case .duckDuckGo:
            return try await searchDuckDuckGo(query: trimmedQuery, maxResults: maxResults)

        case .searxng:
            let customURL = UserDefaults.standard.string(forKey: "searchCustomURL")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard let baseURL = URL(string: customURL), !customURL.isEmpty else {
                return try await searchDuckDuckGo(query: trimmedQuery, maxResults: maxResults)
            }
            return try await searchSearXNG(query: trimmedQuery, baseURL: baseURL, maxResults: maxResults)

        case .brave:
            let key = UserDefaults.standard.string(forKey: "searchBraveKey")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !key.isEmpty else { return try await searchDuckDuckGo(query: trimmedQuery, maxResults: maxResults) }
            return try await searchBrave(query: trimmedQuery, apiKey: key, maxResults: maxResults)

        case .tavily:
            let key = UserDefaults.standard.string(forKey: "searchTavilyKey")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !key.isEmpty else { return try await searchDuckDuckGo(query: trimmedQuery, maxResults: maxResults) }
            return try await searchTavily(query: trimmedQuery, apiKey: key, maxResults: maxResults)

        case .exa:
            let key = UserDefaults.standard.string(forKey: "searchExaKey")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !key.isEmpty else { return try await searchDuckDuckGo(query: trimmedQuery, maxResults: maxResults) }
            return try await searchExa(query: trimmedQuery, apiKey: key, maxResults: maxResults)

        case .google:
            let key = UserDefaults.standard.string(forKey: "searchGoogleKey")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let cx = UserDefaults.standard.string(forKey: "searchGoogleCX")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !key.isEmpty, !cx.isEmpty else { return try await searchDuckDuckGo(query: trimmedQuery, maxResults: maxResults) }
            return try await searchGoogle(query: trimmedQuery, apiKey: key, cx: cx, maxResults: maxResults)

        case .bing:
            let key = UserDefaults.standard.string(forKey: "searchBingKey")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !key.isEmpty else { return try await searchDuckDuckGo(query: trimmedQuery, maxResults: maxResults) }
            return try await searchBing(query: trimmedQuery, apiKey: key, maxResults: maxResults)
        }
    }

    // MARK: - DuckDuckGo
    private func searchDuckDuckGo(query: String, maxResults: Int) async throws -> [SearchResult] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://html.duckduckgo.com/html/?q=\(encodedQuery)") else {
            return []
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        let bodyString = "q=\(encodedQuery)"
        request.httpBody = bodyString.data(using: .utf8)
        request.timeoutInterval = 8.0

        let (data, response) = try await session.data(for: request)
        guard let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            return []
        }

        return SearchResultParser.parseDuckDuckGoHTML(html, maxResults: maxResults)
    }

    // MARK: - SearXNG
    private func searchSearXNG(query: String, baseURL: URL, maxResults: Int) async throws -> [SearchResult] {
        var components = URLComponents(url: baseURL.appendingPathComponent("search"), resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let url = components?.url else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8.0

        let (data, response) = try await session.data(for: request)
        guard let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) else {
            return []
        }

        struct SearXNGResponse: Codable {
            struct Item: Codable {
                let title: String?
                let url: String?
                let content: String?
            }
            let results: [Item]?
        }

        let decoded = try JSONDecoder().decode(SearXNGResponse.self, from: data)
        let items = decoded.results ?? []
        return items.prefix(maxResults).compactMap { item in
            guard let title = item.title, let url = item.url else { return nil }
            return SearchResult(title: title, url: url, snippet: item.content ?? "")
        }
    }

    // MARK: - Brave Search
    private func searchBrave(query: String, apiKey: String, maxResults: Int) async throws -> [SearchResult] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.search.brave.com/res/v1/web/search?q=\(encodedQuery)&count=\(maxResults)") else {
            return []
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-Subscription-Token")
        request.timeoutInterval = 8.0

        let (data, response) = try await session.data(for: request)
        guard let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) else { return [] }

        struct BraveResponse: Codable {
            struct Web: Codable {
                struct Result: Codable {
                    let title: String?
                    let url: String?
                    let description: String?
                }
                let results: [Result]?
            }
            let web: Web?
        }

        let decoded = try JSONDecoder().decode(BraveResponse.self, from: data)
        let results = decoded.web?.results ?? []
        return results.compactMap { res in
            guard let title = res.title, let url = res.url else { return nil }
            return SearchResult(title: title, url: url, snippet: res.description ?? "")
        }
    }

    // MARK: - Tavily Search
    private func searchTavily(query: String, apiKey: String, maxResults: Int) async throws -> [SearchResult] {
        guard let url = URL(string: "https://api.tavily.com/search") else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 8.0

        let payload: [String: Any] = [
            "api_key": apiKey,
            "query": query,
            "max_results": maxResults
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        guard let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) else { return [] }

        struct TavilyResponse: Codable {
            struct Result: Codable {
                let title: String?
                let url: String?
                let content: String?
            }
            let results: [Result]?
        }

        let decoded = try JSONDecoder().decode(TavilyResponse.self, from: data)
        let results = decoded.results ?? []
        return results.compactMap { res in
            guard let title = res.title, let url = res.url else { return nil }
            return SearchResult(title: title, url: url, snippet: res.content ?? "")
        }
    }

    // MARK: - Exa Search
    private func searchExa(query: String, apiKey: String, maxResults: Int) async throws -> [SearchResult] {
        guard let url = URL(string: "https://api.exa.ai/search") else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.timeoutInterval = 8.0

        let payload: [String: Any] = [
            "query": query,
            "numResults": maxResults
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        guard let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) else { return [] }

        struct ExaResponse: Codable {
            struct Result: Codable {
                let title: String?
                let url: String?
                let text: String?
                let snippet: String?
            }
            let results: [Result]?
        }

        let decoded = try JSONDecoder().decode(ExaResponse.self, from: data)
        let results = decoded.results ?? []
        return results.compactMap { res in
            guard let title = res.title, let url = res.url else { return nil }
            return SearchResult(title: title, url: url, snippet: res.snippet ?? res.text ?? "")
        }
    }

    // MARK: - Google Custom Search
    private func searchGoogle(query: String, apiKey: String, cx: String, maxResults: Int) async throws -> [SearchResult] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.googleapis.com/customsearch/v1?key=\(apiKey)&cx=\(cx)&q=\(encodedQuery)&num=\(maxResults)") else {
            return []
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8.0

        let (data, response) = try await session.data(for: request)
        guard let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) else { return [] }

        struct GoogleResponse: Codable {
            struct Item: Codable {
                let title: String?
                let link: String?
                let snippet: String?
            }
            let items: [Item]?
        }

        let decoded = try JSONDecoder().decode(GoogleResponse.self, from: data)
        let items = decoded.items ?? []
        return items.compactMap { item in
            guard let title = item.title, let url = item.link else { return nil }
            return SearchResult(title: title, url: url, snippet: item.snippet ?? "")
        }
    }

    // MARK: - Bing Search
    private func searchBing(query: String, apiKey: String, maxResults: Int) async throws -> [SearchResult] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.bing.microsoft.com/v7.0/search?q=\(encodedQuery)&count=\(maxResults)") else {
            return []
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.timeoutInterval = 8.0

        let (data, response) = try await session.data(for: request)
        guard let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) else { return [] }

        struct BingResponse: Codable {
            struct WebPages: Codable {
                struct Value: Codable {
                    let name: String?
                    let url: String?
                    let snippet: String?
                }
                let value: [Value]?
            }
            let webPages: WebPages?
        }

        let decoded = try JSONDecoder().decode(BingResponse.self, from: data)
        let values = decoded.webPages?.value ?? []
        return values.compactMap { val in
            guard let title = val.name, let url = val.url else { return nil }
            return SearchResult(title: title, url: url, snippet: val.snippet ?? "")
        }
    }
}
