import Foundation

extension String {
    func slugForFilename() -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let slug = String(scalars).lowercased()
            .split(separator: "-")
            .joined(separator: "-")
        return slug.isEmpty ? "unknown" : slug
    }
}
