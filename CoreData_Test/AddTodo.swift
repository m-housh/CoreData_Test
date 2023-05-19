import ComposableArchitecture
import CoreData
import _CoreDataDependency
import Dependencies
import DependenciesAdditions
import SwiftUI

struct AddTodo: Reducer {

  struct State: Equatable {
    @BindingState var title: String = ""
    @BindingState var isComplete: Bool = false
  }

  enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
  }

  var body: some ReducerOf<Self> {
    BindingReducer()
  }
}

struct AddTodoView: View {
  let store: StoreOf<AddTodo>

  var body: some View {
    WithViewStore(store, observe: { $0 }) { viewStore in
      Form {
        TextField("Todo title...", text: viewStore.binding(\.$title))
        Toggle("Complete", isOn: viewStore.binding(\.$isComplete))
      }
    }
  }
}

struct EditTodo: Reducer {

  struct State: Equatable {
    let todo: Fetched<Todo>
    @BindingState var title: String = ""
    @BindingState var isComplete: Bool = false

    init(todo: Fetched<Todo>) {
      self.todo = todo
      todo.withManagedObject { todo in
        self.title = todo.title ?? ""
        self.isComplete = todo.complete
      }
    }
  }

  enum Action: Equatable, BindableAction {
    case binding(BindingAction<State>)
    case saveButtonTapped
  }

  var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding:
        return .none
      case .saveButtonTapped:
        return .run { [state = state] _ in
          await state.todo.withManagedObject { update in
            update.title = state.title
            update.complete = state.isComplete
            try! update.managedObjectContext?.save()
          }
        }
      }
    }
  }
}

struct EditTodoView: View {
  let store: StoreOf<EditTodo>

  var body: some View {
    WithViewStore(store, observe: { $0 }) { viewStore in
      Form {
        TextField("Todo title...", text: viewStore.binding(\.$title))
        Toggle("Complete", isOn: viewStore.binding(\.$isComplete))
      }
      .toolbar {
        Button("Save") {
          viewStore.send(.saveButtonTapped)
        }
      }
    }
  }
}
