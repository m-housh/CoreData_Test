import CoreData
import SwiftUI

@main
struct CoreData_TestApp: App {

  var body: some Scene {
    WindowGroup {
      ContentView(
        store: .init(
          initialState: TodoFeature.State(),
          reducer: TodoFeature()
            .dependency(\.persistentContainer, .default(inMemory: false))
            ._printChanges()
        )
      )
    }
  }
}
