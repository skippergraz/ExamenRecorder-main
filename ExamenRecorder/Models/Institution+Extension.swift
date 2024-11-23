import Foundation

// MARK: - Identifiable Conformance
extension Institution {
    public var identifier: UUID {
        id ?? UUID()
    }
}
