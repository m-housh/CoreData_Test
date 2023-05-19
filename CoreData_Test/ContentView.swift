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
    case deleteTapped(todo: Fetched<Todo>)
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

      case let .deleteTapped(todo: todo):
        return .run { _ in
          await todo.withManagedObject { todo in
            todo.managedObjectContext?.delete(todo)
            try! todo.managedObjectContext?.save()
          }
        }

      case .didLoad(todos: let todos):
        state.todos = todos
        return .none

      case let .toggleComplete(todo: todo):
        return .run { _ in
          await todo.withManagedObject { update in
            update.complete.toggle()
            try! update.managedObjectContext?.save()
          }
        }

      case .addTodoButtonTapped:
        return .run { _ in
          await persistentContainer.withNewBackgroundContext { context in
            let todo = Todo(context: context)
            todo.title = "Finish CoreData"
            todo.id = uuid()
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

        List {
          ForEach(viewStore.todos, id: \.id) { (todo: Fetched<Todo>) in
            HStack {
              Text(todo.title ?? "Unknown")
              Spacer()
              Button(action: { viewStore.send(.toggleComplete(todo: todo)) }) {
                Image(systemName: todo.complete ? "checkmark.square.fill" : "square")
                  .foregroundColor(todo.complete ? .green : nil)
              }
            }
            .swipeActions(allowsFullSwipe: true) {
              Button(role: .destructive) {
                viewStore.send(.deleteTapped(todo: todo))
              } label: {
                Label("Delete", systemImage: "trash")
              }
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
