import ComposableArchitecture
import Dependencies
import DependenciesAdditions
import _CoreDataDependency
import CoreData
import SwiftUI

struct TodoFeature: Reducer {

  struct State: Equatable {
    var todos: Todo.FetchedResults = .empty
  }

  enum Action: Equatable {
    case viewDidAppear
    case didLoad(todos: Todo.FetchedResults)
    case addTodoButtonTapped
    case toggleComplete(todo: Fetched<Todo>)
  }

  @Dependency(\.persistentContainer) var persistentContainer;
  @Dependency(\.uuid) var uuid;

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .viewDidAppear:
        return .run { @MainActor send in
          for try await todos in self.persistentContainer.request(
            Todo.self,
            sortDescriptors: [
              NSSortDescriptor(keyPath: \Todo.title, ascending: true)
            ]
          ) {
            send(.didLoad(todos: todos))
          }
        }

      case .didLoad(todos: let todos):
        state.todos = todos
        return .none

      case let .toggleComplete(todo: todo):
        return .run { @MainActor _ in
          _ = persistentContainer.with { context in
            todo.withManagedObject { update in
              update.complete.toggle()
//              try! update.managedObjectContext!.save()
            }
            try! context.save()
          }
        }

      case .addTodoButtonTapped:
        return .run { @MainActor _ in
          _ = persistentContainer.with { context in
            let newTodo = Todo(context: context)
            newTodo.title = "Finish CoreData"
            newTodo.id = uuid()

            try! context.save()
          }
        }
      }
    }
  }
}

struct ContentView: View {
  let store: StoreOf<TodoFeature>

  var body: some View {
    WithViewStore(store, observe: { $0 }) { viewStore in
      VStack {
        Image(systemName: "globe")
          .imageScale(.large)
          .foregroundColor(.accentColor)
        Text("Hello, world!")

        List(viewStore.todos, id: \.id) { (todo: Fetched<Todo>) in
          HStack {
            Text(todo.title ?? "Unknown")
            Spacer()
            Button(action: { viewStore.send(.toggleComplete(todo: todo)) }) {
              Image(systemName: todo.complete ? "checkmark.square.fill" : "square")
                .foregroundColor(todo.complete ? .green : nil)
            }
          }
        }

        Button("Add Todo") {
          viewStore.send(.addTodoButtonTapped)
        }
      }
      .padding()
      .onAppear { viewStore.send(.viewDidAppear) }
    }
  }
//
//  func toggleTodo(id: UUID?) {
//    guard let id = id,
//            let todo = todos.first(where: { $0.id == id })
//    else { return }
//    todo.complete.toggle()
//    try? moc.save()
//  }
}


struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView(
      store: .init(
        initialState: TodoFeature.State(),
        reducer: TodoFeature()
          .dependency(\.persistentContainer, .default(inMemory: true))
      )
    )
  }
}
