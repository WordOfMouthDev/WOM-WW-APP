import SwiftUI

struct BusinessDetailView: View {
    @StateObject private var viewModel: BusinessDetailViewModel

    init(business: Business, userId: String) {
        _viewModel = StateObject(wrappedValue: BusinessDetailViewModel(business: business, userId: userId))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                infoChips

                statusSection

                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(viewModel.business.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerImage
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text(viewModel.business.name)
                .font(.title.bold())
                .multilineTextAlignment(.leading)
                .foregroundStyle(.primary)

            Text(viewModel.business.category.replacingOccurrences(of: "-", with: " ").capitalized)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private var headerImage: some View {
        Group {
            if let imageURL = viewModel.business.imageURL {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    placeholderImage
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
            } else {
                placeholderImage
                    .frame(height: 200)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
    }

    private var placeholderImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
            Image(systemName: "building.2")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var infoChips: some View {
        let chips = makeChips()
        if chips.isEmpty {
            EmptyView()
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                ForEach(chips) { chip in
                    HStack(spacing: 6) {
                        Image(systemName: chip.icon)
                        Text(chip.label)
                    }
                    .font(.footnote)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color(.secondarySystemBackground))
                    )
                    .accessibilityLabel(chip.accessibility)
                }
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if viewModel.isVerified {
            Text("Booking & sharing functionality needs to be implemented.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
        } else {
            VStack(alignment: .leading, spacing: 16) {
                Text("This business isn't verified yet. Would you like to see this business on our platform?")
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                HStack(spacing: 16) {
                    feedbackButton(
                        systemImage: "hand.thumbsup",
                        label: "Like",
                        count: viewModel.business.likeCount,
                        isSelected: viewModel.userFeedback == .like
                    ) {
                        viewModel.toggleFeedback(.like)
                    }

                    feedbackButton(
                        systemImage: "hand.thumbsdown",
                        label: "Dislike",
                        count: viewModel.business.dislikeCount,
                        isSelected: viewModel.userFeedback == .dislike
                    ) {
                        viewModel.toggleFeedback(.dislike)
                    }
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityLabel(error)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.orange.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.orange.opacity(0.25), lineWidth: 1)
            )
            .accessibilityElement(children: .combine)
        }
    }

    private func makeChips() -> [InfoChip] {
        var chips: [InfoChip] = []
        if let address = viewModel.business.address, !address.isEmpty {
            chips.append(InfoChip(icon: "mappin.and.ellipse", label: address, accessibility: "Address \(address)"))
        }
        if let website = viewModel.business.website, !website.isEmpty {
            chips.append(InfoChip(icon: "globe", label: website, accessibility: "Website \(website)"))
        }
        if let phone = viewModel.business.phoneNumber, !phone.isEmpty {
            chips.append(InfoChip(icon: "phone", label: phone, accessibility: "Phone number \(phone)"))
        }
        return chips
    }

    private struct InfoChip: Identifiable {
        let id = UUID()
        let icon: String
        let label: String
        let accessibility: String
    }

    private func feedbackButton(
        systemImage: String,
        label: String,
        count: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(label)
                if count > 0 {
                    Text("\(count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                }
            }
            .font(.subheadline.bold())
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.orange.opacity(0.2) : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.orange : Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isSaving)
        .accessibilityLabel("\(label) this business")
    }
}

#Preview("Verified") {
    NavigationStack {
        BusinessDetailView(business: PreviewData.placeVerified, userId: "preview")
    }
}

#Preview("Unverified") {
    NavigationStack {
        BusinessDetailView(business: PreviewData.placeUnverified, userId: "preview")
    }
}
