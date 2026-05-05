import Foundation
import OrangeCloudIMClient

#if canImport(SwiftUI)
import SwiftUI

@main
struct OrangeCloudIMDemoApp: App {
    var body: some Scene {
        WindowGroup {
            ChatDemoView()
        }
    }
}
#else
print("OrangeCloudIMDemo requires SwiftUI (iOS 16+ / macOS 13+)")
#endif
