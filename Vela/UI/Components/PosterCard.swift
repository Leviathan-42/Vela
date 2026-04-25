import SwiftUI

struct PosterCard: View {
    let item: MediaItem
    var width: CGFloat = 120
    var height: CGFloat = 180

    var body: some View {
        AsyncImage(url: item.posterURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure, .empty:
                placeholder
            @unknown default:
                placeholder
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.card)
            .fill(Theme.surface)
            .overlay(
                Text(item.title)
                    .font(.caption2)
                    .foregroundStyle(Theme.subtle)
                    .padding(6)
                    .multilineTextAlignment(.center)
            )
    }
}
