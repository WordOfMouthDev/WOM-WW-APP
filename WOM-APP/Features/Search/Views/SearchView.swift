import SwiftUI

struct SearchView: View {
    @State private var query: String = ""

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    Text("Type to search…")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Results for \"\(query)\"")
                }
            }
            .searchable(text: $query)
            .navigationTitle("Search")
        }
    }
}

#Preview {
    SearchView()
}

