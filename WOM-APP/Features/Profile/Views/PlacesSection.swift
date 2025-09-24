import SwiftUI

struct PlacesSection: View {
    let state: LoadableState<[Business]>
    let userId: String?
    var onRetry: () -> Void
    var onFindNearby: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Places")
                .font(.title2.bold())
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)

            content
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .idle, .loading:
            HStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .accessibilityLabel("Loading places")
                Text("Loading your places...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 32)
        case .failed(let error):
            let message = error.localizedDescription.isEmpty ? "Something went wrong." : error.localizedDescription
            VStack(spacing: 12) {
                Text("We couldn't load your places.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Retry", action: onRetry)
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        case .loaded(let businesses):
            if businesses.isEmpty {
                VStack(spacing: 12) {
                    Text("No Places yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Find businesses near me", action: onFindNearby)
                        .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(businesses) { business in
                        if let userId {
                            NavigationLink {
                                BusinessDetailView(business: business, userId: userId)
                            } label: {
                                PlaceRowView(business: business)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        } else {
                            PlaceRowView(business: business)
                                .contentShape(Rectangle())
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ScrollView {
        PlacesSection(
            state: .loaded([PreviewData.placeVerified, PreviewData.placeUnverified]),
            userId: "preview",
            onRetry: {},
            onFindNearby: {}
        )
    }
    .background(Color(.systemGroupedBackground))
}
