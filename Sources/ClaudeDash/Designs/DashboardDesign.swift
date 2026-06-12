import SwiftUI

/// A self-contained dashboard skin. Designs read only from DashboardModel —
/// never from Core types — so adding a new design is a new folder under
/// Designs/<Name>/ plus one entry in DesignRegistry.all.
@MainActor
protocol DashboardDesign {
    var id: String { get }
    var displayName: String { get }
    /// The overlay panel is sized to this.
    var preferredSize: CGSize { get }
    func makeView(model: DashboardModel) -> AnyView
}

@MainActor
enum DesignRegistry {
    static let all: [any DashboardDesign] = [
        GT3Design(),
        LotusDesign()
    ]

    static func design(id: String) -> any DashboardDesign {
        all.first { $0.id == id } ?? all[0]
    }
}
