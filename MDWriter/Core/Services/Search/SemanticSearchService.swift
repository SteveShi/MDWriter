//
//  SemanticSearchService.swift
//  MDWriter
//
//  Local vector embedding and semantic search engine powered by Apple NaturalLanguage framework.
//

import Foundation
import NaturalLanguage
import SwiftData

/// Represents a semantically chunked text segment from a note.
struct SemanticChunk: Sendable {
    let noteID: PersistentIdentifier
    let noteTitle: String
    let folderName: String?
    let text: String
    let vector: [Double]
}

/// Search result item containing matching passage, note title, and similarity score.
struct SemanticSearchResult: Identifiable, Sendable {
    var id: String { "\(noteTitle)-\(snippet.prefix(20))" }
    let noteID: PersistentIdentifier
    let noteTitle: String
    let folderName: String?
    let snippet: String
    let similarity: Double
    let directURL: String
}

/// Local-first semantic search engine utilizing on-device Apple NaturalLanguage embeddings.
@MainActor
final class SemanticSearchService {
    static let shared = SemanticSearchService()

    // Cached embeddings per note: [NotePersistentModelID: (modifiedAt, chunks)]
    private var cache: [PersistentIdentifier: (modifiedAt: Date, chunks: [SemanticChunk])] = [:]

    private let zhEmbedding: NLEmbedding?
    private let enEmbedding: NLEmbedding?

    private init() {
        self.zhEmbedding = NLEmbedding.sentenceEmbedding(for: .simplifiedChinese)
        self.enEmbedding = NLEmbedding.sentenceEmbedding(for: .english)
    }

    // MARK: - Public Search API

    /// Performs semantic vector search across all active (non-trashed) notes.
    func search(
        query: String,
        notes: [Note],
        limit: Int = 5,
        minSimilarity: Double = 0.25
    ) -> [SemanticSearchResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }

        guard let queryVector = computeEmbedding(for: trimmedQuery) else {
            return fallbackTextSearch(query: trimmedQuery, notes: notes, limit: limit)
        }

        // 1. Ensure all active notes have up-to-date chunk embeddings
        updateCacheIfNeeded(for: notes)

        // 2. Compute similarity for all cached chunks
        var scoredResults: [SemanticSearchResult] = []
        let queryLower = trimmedQuery.lowercased()

        for (_, cacheEntry) in cache {
            for chunk in cacheEntry.chunks {
                let cosSim = cosineSimilarity(queryVector, chunk.vector)

                // Optional lexical boost if exact keywords appear in chunk or title
                var finalScore = cosSim
                let chunkLower = chunk.text.lowercased()
                if chunkLower.contains(queryLower) {
                    finalScore += 0.15
                }
                if chunk.noteTitle.lowercased().contains(queryLower) {
                    finalScore += 0.10
                }

                if finalScore >= minSimilarity {
                    let url = "mdwriter://note/\(chunk.noteID)"
                    scoredResults.append(
                        SemanticSearchResult(
                            noteID: chunk.noteID,
                            noteTitle: chunk.noteTitle,
                            folderName: chunk.folderName,
                            snippet: chunk.text,
                            similarity: min(1.0, finalScore),
                            directURL: url
                        )
                    )
                }
            }
        }

        // 3. Sort by highest similarity and take top K
        let sorted = scoredResults.sorted { $0.similarity > $1.similarity }
        return Array(sorted.prefix(limit))
    }

    // MARK: - Cache Management

    private func updateCacheIfNeeded(for notes: [Note]) {
        let activeNoteIDs = Set(notes.map { $0.persistentModelID })

        // Evict deleted notes from cache
        for cachedID in cache.keys where !activeNoteIDs.contains(cachedID) {
            cache.removeValue(forKey: cachedID)
        }

        // Index or refresh modified notes
        for note in notes where !note.isTrashed {
            let noteID = note.persistentModelID
            if let existing = cache[noteID], existing.modifiedAt == note.modifiedAt {
                continue // Cache hit
            }

            let chunks = chunkNote(note)
            cache[noteID] = (modifiedAt: note.modifiedAt, chunks: chunks)
        }
    }

    // MARK: - Chunking & Vectorization

    private func chunkNote(_ note: Note) -> [SemanticChunk] {
        let content = note.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return [] }

        // Split note by blank lines (paragraphs) or headers
        let rawParagraphs = content.components(separatedBy: "\n\n")
        var chunks: [SemanticChunk] = []

        for para in rawParagraphs {
            let trimmed = para.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 12 else { continue } // Ignore tiny non-informative fragments

            // If a paragraph is excessively long (> 800 chars), split into sub-blocks
            if trimmed.count > 800 {
                let subSegments = splitIntoSubsegments(trimmed, maxLen: 500)
                for sub in subSegments {
                    if let vector = computeEmbedding(for: sub) {
                        chunks.append(
                            SemanticChunk(
                                noteID: note.persistentModelID,
                                noteTitle: note.title.isEmpty ? String(localized: "Untitled") : note.title,
                                folderName: note.folder?.name,
                                text: sub,
                                vector: vector
                            )
                        )
                    }
                }
            } else {
                if let vector = computeEmbedding(for: trimmed) {
                    chunks.append(
                        SemanticChunk(
                            noteID: note.persistentModelID,
                            noteTitle: note.title.isEmpty ? String(localized: "Untitled") : note.title,
                            folderName: note.folder?.name,
                            text: trimmed,
                            vector: vector
                        )
                    )
                }
            }
        }

        return chunks
    }

    private func splitIntoSubsegments(_ text: String, maxLen: Int) -> [String] {
        var segments: [String] = []
        let lines = text.components(separatedBy: .newlines)
        var current = ""

        for line in lines {
            if current.count + line.count > maxLen && !current.isEmpty {
                segments.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = line
            } else {
                current += (current.isEmpty ? "" : "\n") + line
            }
        }

        if !current.isEmpty {
            segments.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return segments
    }

    private func computeEmbedding(for text: String) -> [Double]? {
        let lang = detectLanguage(for: text)
        let embedding = (lang == .simplifiedChinese || lang == .traditionalChinese)
            ? (zhEmbedding ?? enEmbedding)
            : (enEmbedding ?? zhEmbedding)

        guard let emb = embedding else { return nil }

        // Apple NLEmbedding provides sentence vector directly
        if let vector = emb.vector(for: text) {
            return vector
        }

        // Fallback: tokenize and average word vectors
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var totalVector: [Double] = Array(repeating: 0.0, count: emb.dimension)
        var wordCount = 0

        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let word = String(text[range])
            if let wordVec = emb.vector(for: word) {
                for i in 0..<emb.dimension {
                    totalVector[i] += wordVec[i]
                }
                wordCount += 1
            }
            return true
        }

        if wordCount > 0 {
            for i in 0..<emb.dimension {
                totalVector[i] /= Double(wordCount)
            }
            return totalVector
        }

        return nil
    }

    private func detectLanguage(for text: String) -> NLLanguage {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage ?? .simplifiedChinese
    }

    // MARK: - Cosine Similarity

    private func cosineSimilarity(_ v1: [Double], _ v2: [Double]) -> Double {
        guard v1.count == v2.count, !v1.isEmpty else { return 0.0 }

        var dotProduct = 0.0
        var normA = 0.0
        var normB = 0.0

        for i in 0..<v1.count {
            dotProduct += v1[i] * v2[i]
            normA += v1[i] * v1[i]
            normB += v2[i] * v2[i]
        }

        if normA <= 0 || normB <= 0 { return 0.0 }
        return dotProduct / (sqrt(normA) * sqrt(normB))
    }

    // MARK: - Fallback Text Search

    private func fallbackTextSearch(query: String, notes: [Note], limit: Int) -> [SemanticSearchResult] {
        let queryLower = query.lowercased()
        var results: [SemanticSearchResult] = []

        for note in notes where !note.isTrashed {
            let titleMatch = note.title.lowercased().contains(queryLower)
            let contentMatch = note.content.lowercased().contains(queryLower)

            if titleMatch || contentMatch {
                let snippet: String
                if let range = note.content.range(of: query, options: .caseInsensitive) {
                    let start = note.content.index(range.lowerBound, offsetBy: -50, limitedBy: note.content.startIndex) ?? note.content.startIndex
                    let end = note.content.index(range.upperBound, offsetBy: 150, limitedBy: note.content.endIndex) ?? note.content.endIndex
                    snippet = String(note.content[start..<end])
                } else {
                    snippet = String(note.content.prefix(200))
                }

                results.append(
                    SemanticSearchResult(
                        noteID: note.persistentModelID,
                        noteTitle: note.title.isEmpty ? String(localized: "Untitled") : note.title,
                        folderName: note.folder?.name,
                        snippet: snippet,
                        similarity: titleMatch ? 0.85 : 0.65,
                        directURL: "mdwriter://note/\(note.persistentModelID)"
                    )
                )
            }
        }

        return Array(results.prefix(limit))
    }
}
