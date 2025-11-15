// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/Flow/

import Foundation
import SwiftUI

/// Caches "resolved" text.
///
/// Thread-safe cache using @MainActor to ensure all access happens on the main thread.
/// The cache automatically evicts all entries when it exceeds the maximum size to prevent unbounded growth.
@MainActor
class TextCache: ObservableObject {

    struct Key: Equatable, Hashable {
        var string: String
        var font: Font
    }

    /// Maximum number of cached text entries before eviction.
    /// Typical graphs have 50-200 unique node names and 20-50 port names across 2 fonts.
    private static let maxCacheSize = 500

    private var cache: [Key: GraphicsContext.ResolvedText] = [:]

    /// Clears all cached text entries.
    /// Call this when switching between patches or when memory is constrained.
    func clear() {
        cache.removeAll()
    }

    func text(string: String,
              font: Font,
              _ cx: GraphicsContext) -> GraphicsContext.ResolvedText {

        let key = Key(string: string, font: font)

        if let resolved = cache[key] {
            return resolved
        }

        // Evict entire cache when it exceeds maximum size
        if cache.count >= Self.maxCacheSize {
            cache.removeAll(keepingCapacity: true)
        }

        let resolved = cx.resolve(Text(string).font(font))
        cache[key] = resolved
        return resolved
    }
}
