import SwiftUI

struct PlaceRowView: View {
    let business: Business

    private var ratingText: String? {
        guard let rating = business.rating else { return nil }
        return String(format: "%.1f", rating)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 4) {
                Text(business.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(business.category.replacingOccurrences(of: "-", with: " ").capitalized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let ratingText {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        Text(ratingText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Rating \(ratingText) out of five")
                }
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .accessibilityElement(children: .combine)
    }

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.systemGray5))
                .frame(width: 56, height: 56)

            if let imageURL = business.imageURL {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } placeholder: {
                    Image(systemName: "building.2")
                        .foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: "building.2")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

#Preview {
    PlaceRowView(business: PreviewData.placeVerified)
        .padding()
        .background(Color(.systemGroupedBackground))
}
