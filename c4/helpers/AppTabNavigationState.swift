import Foundation

enum AppSection: Int, CaseIterable, Identifiable {
    case quickApply

    var id: Int { rawValue }
}
