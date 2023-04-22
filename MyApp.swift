import SwiftUI

@main
struct PulseApp: App {
    @StateObject private var cameraViewModel = CameraViewModel()
    @State private var welcomePresented = true
    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
                    .navigationTitle("Pulse")
                    .environmentObject(cameraViewModel)
                    .sheet(isPresented: $welcomePresented) {
                        WelcomeView(shown: $welcomePresented)
                    }
            }
        }
    }
}
