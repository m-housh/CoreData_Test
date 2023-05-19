import ComposableArchitecture
import Dependencies
import DependenciesAdditions
import _CoreDataDependency
import CoreData
import SwiftUI

struct TodoFeature: Reducer {

  struct State: Equatable {
    var todos: Todo.FetchedResults = .empty
    @PresentationState var addTodo: AddTodo.State?
  }

  enum Action: Equatable {
    case viewDidAppear
    case deleteTapped(todo: Fetched<Todo>)
    case didLoad(todos: Todo.FetchedResults)
    case editButtonTapped(todo: Fetched<Todo>)
    case addTodoButtonTapped
    case toggleComplete(todo: Fetched<Todo>)
    case saveButtonTapped
    case addTodo(PresentationAction<AddTodo.Action>)
  }

  struct Destination: Reducer {

    enum State: Equatable {
      case addTodo(AddTodo.State)
      case editTodo(EditTodo.State)
    }

    enum Action: Equatable {
      case addTodo(AddTodo.Action)
      case editTodo(EditTodo.Action)
    }

    var body: some ReducerOf<Self> {
      Scope(state: /State.addTodo, action: /Action.addTodo) {
        AddTodo()
      }
      Scope(state: /State.editTodo, action: /Action.editTodo) {
        EditTodo()
      }
    }
  }

  @Dependency(\.persistentContainer) var persistentContainer;
  @Dependency(\.uuid) var uuid;
  @Dependency(\.todoClient) var todoClient;

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .viewDidAppear:
        return .run { send in
          try await todoClient.fetch {
            await send(.didLoad(todos: $0))
          }
        }

      case let .deleteTapped(todo: todo):
        return .run { _ in
          try await todoClient.delete(todo)
        }

      case .didLoad(todos: let todos):
        state.todos = todos
        return .none

      case .editButtonTapped(todo: _):
//        state.addTodo = .init(title: todo.title ?? "", isComplete: todo.complete)
        return .none

      case let .toggleComplete(todo: todo):
        return .run { _ in
          try await todoClient.toggleComplete(todo)
//          try await todoClient.update(todo, updates: .ini)
//          await todo.withManagedObject { update in
//            update.complete.toggle()
//            try! update.managedObjectContext?.save()
//          }
        }

      case .addTodoButtonTapped:
        state.addTodo = .init()
        return .none

      case .addTodo:
        return .none

      case .saveButtonTapped:
        guard let addTodo = state.addTodo
        else { return .none }
        return .run { send in
          try await persistentContainer.withNewBackgroundContext { context in
            let todo = Todo(context: context)
            todo.id = uuid()
            todo.title = addTodo.title
            todo.complete = addTodo.isComplete
            try todoClient.save(todo)
//            try! context.save()
          }
          await send(.addTodo(.dismiss))
        }
      }
    }
    .ifLet(\.$addTodo, action: /Action.addTodo) {
      AddTodo()
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

              Button {
                viewStore.send(.editButtonTapped(todo: todo))
              } label: {
                Label("Edit", systemImage: "square.and.pencil")
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
      .sheet(
        store: store.scope(state: \.$addTodo, action: TodoFeature.Action.addTodo)
      ) { store in
        NavigationStack {
          AddTodoView(store: store)
            .navigationTitle("Add Todo")
            .toolbar {
              ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                  viewStore.send(.addTodo(.dismiss))
                }
              }
              ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                  viewStore.send(.saveButtonTapped)
                }
              }
            }
        }
      }
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
