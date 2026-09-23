import SwiftUI

@main
struct RhythmAceApp: App {
    @State private var seq = Sequencer()

    var body: some Scene {
        WindowGroup {
            PanelView()
                .environment(seq)
                .preferredColorScheme(.light)
                .statusBarHidden(false)
        }
    }
}
