import ComposableArchitecture
import _CoreDataDependency
import Dependencies
import DependenciesAdditions
import Foundation
import XCTestDynamicOverlay

extension DependencyValues {
  var todoClient: TodoClient {
    get { self[TodoClient.self] }
    set { self[TodoClient.self] = newValue }
  }
}

struct TodoClient {
  var fetch: ((Todo.FetchedResults) async -> Void) async throws -> Void
  var save: (Todo) throws -> Void
  var delete: (Fetched<Todo>) async throws -> Void

  struct TodoUpdate: Equatable {
    var title: String?
    var isComplete: Bool?

    var hasUpdates: Bool {
      title != nil || isComplete != nil
    }

    fileprivate func applyUpdates(_ todo: inout Todo) {
      if let title {
        todo.title = title
      }
      if let isComplete {
        todo.complete = isComplete
      }
    }
  }
}

extension TodoClient {
  func update(_ todo: Fetched<Todo>, updates: TodoUpdate) async throws {
    guard updates.hasUpdates else { return }
    try await todo.withManagedObject { updatedTodo in
      var updated = updatedTodo
      updates.applyUpdates(&updated)
      try self.save(updated)
    }
  }

  func toggleComplete(_ todo: Fetched<Todo>) async throws {
    try await todo.withManagedObject(perform: { todo in
      todo.complete.toggle()
      try self.save(todo)
    })
  }
}

extension TodoClient: DependencyKey {

  static var liveValue: Self {
    @Dependency(\.persistentContainer) var persistentContainer;

    return .init(
      fetch: { @MainActor send in
        for try await todos in persistentContainer.request(
          Todo.self,
          sortDescriptors: [
            NSSortDescriptor(keyPath: \Todo.title, ascending: false)
          ]
        ) {
          await send(todos)
        }
      },
      save: { todo in
        try todo.managedObjectContext?.save()
      },
      delete: { todo in
        try todo.withManagedObject { todo in
          todo.managedObjectContext?.delete(todo)
          try todo.managedObjectContext?.save()
        }
      }
    )
  }

  static var testValue: Self {
    .init(
      fetch: unimplemented(),
      save: unimplemented(),
      delete: unimplemented()
    )
  }
}
