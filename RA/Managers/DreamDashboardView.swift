import SwiftUI

// MARK: - Dream Model
struct Dream: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var date: Date
    var description: String
}

// MARK: - Dream Store
class DreamStore: ObservableObject {
    @Published var dreams: [Dream] = [] {
        didSet { saveDreams() }
    }
    
    private let dreamsKey = "dreams_key"
    
    init() {
        loadDreams()
    }
    
    func addDream(title: String, description: String) {
        let newDream = Dream(id: UUID(), title: title, date: Date(), description: description)
        dreams.insert(newDream, at: 0)
    }
    
    func deleteDream(at offsets: IndexSet) {
        dreams.remove(atOffsets: offsets)
    }
    
    private func saveDreams() {
        if let encoded = try? JSONEncoder().encode(dreams) {
            UserDefaults.standard.set(encoded, forKey: dreamsKey)
        }
    }
    
    private func loadDreams() {
        if let data = UserDefaults.standard.data(forKey: dreamsKey),
           let decoded = try? JSONDecoder().decode([Dream].self, from: data) {
            dreams = decoded
        }
    }
}

// MARK: - Add Dream View
struct AddDreamView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var store: DreamStore
    @State private var title = ""
    @State private var description = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Title")) {
                    TextField("Enter dream title", text: $title)
                }
                Section(header: Text("Description")) {
                    TextEditor(text: $description)
                        .frame(height: 120)
                }
            }
            .navigationBarTitle("Add Dream", displayMode: .inline)
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            }, trailing: Button("Save") {
                if !title.isEmpty && !description.isEmpty {
                    store.addDream(title: title, description: description)
                    presentationMode.wrappedValue.dismiss()
                }
            }.disabled(title.isEmpty || description.isEmpty))
        }
    }
}

// MARK: - Dream Dashboard View
struct DreamDashboardView: View {
    @StateObject private var store = DreamStore()
    @State private var showingAddDream = false
    
    var body: some View {
        NavigationView {
            VStack {
                if store.dreams.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "cloud.moon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.gray)
                        Text("No dreams logged yet.")
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(store.dreams) { dream in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(dream.title)
                                    .font(.headline)
                                Text(dream.date, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(dream.description)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete(perform: store.deleteDream)
                    }
                }
            }
            .navigationBarTitle("Dream Dashboard")
            .navigationBarItems(trailing: Button(action: {
                showingAddDream = true
            }) {
                Image(systemName: "plus")
            })
            .sheet(isPresented: $showingAddDream) {
                AddDreamView(store: store)
            }
        }
    }
}

// MARK: - Preview
struct DreamDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DreamDashboardView()
    }
} 