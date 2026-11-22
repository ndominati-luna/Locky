import SwiftUI

/// Locky in 2015 and in 2026, side by side: the icons of the iPhone, the Mac and the Watch, then
/// what changed under the hood.
///
/// The lines of code are those the team wrote, without the libraries it embedded: in 2015, the
/// files of `Legacy/` signed by the team in their header; in 2026, the Swift of `Apps/` and
/// `Packages/` at the rebirth.
struct ThenAndNowCard: View {
    var body: some View {
        VStack(spacing: 18) {
            Text("Then and now")
                .font(.system(.title2, design: .rounded, weight: .bold))
            Grid(horizontalSpacing: 14, verticalSpacing: 12) {
                GridRow {
                    Color.clear
                        .gridCellUnsizedAxes([.horizontal, .vertical])
                    EraHeader(year: 2015, iPhone: .icon2015IPhone, mac: .icon2015Mac, watch: .icon2015Watch)
                    EraHeader(year: 2026, iPhone: .icon2026IPhone, mac: .icon2026Mac, watch: .icon2026Watch)
                }
                Divider()
                    .overlay(.white.opacity(0.3))
                ComparisonRow(label: "Language", then: Text(verbatim: "Objective-C"), now: Text(verbatim: "Swift"))
                ComparisonRow(label: "Lines of code", then: Text(21_600, format: .number), now: Text(23_700, format: .number))
                ComparisonRow(label: "Embedded libraries", then: Text(13, format: .number), now: Text(1, format: .number))
                ComparisonRow(label: "Server", then: Text(verbatim: "Parse"), now: Text(verbatim: "iCloud"))
            }
            VStack(spacing: 6) {
                Text("The logo hasn’t aged a day: only the Mac icon lost its round shape.")
                    .font(.subheadline)
                Text("Lines written by the team, libraries not included.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
    }
}

/// A year and the icons of the three apps that year.
private struct EraHeader: View {
    let year: Int
    let iPhone: ImageResource
    let mac: ImageResource
    let watch: ImageResource

    var body: some View {
        VStack(spacing: 8) {
            Text(verbatim: String(year))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
            HStack(spacing: 4) {
                Image(iPhone)
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: 6.5, style: .continuous))
                Image(mac)
                    .resizable()
                    .scaledToFit()
                Image(watch)
                    .resizable()
                    .scaledToFit()
                    .clipShape(.circle)
            }
            .frame(height: 30)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: String(year)))
    }
}

/// What a thing was in 2015 and what it is in 2026.
private struct ComparisonRow: View {
    let label: LocalizedStringKey
    let then: Text
    let now: Text

    var body: some View {
        GridRow {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
                .gridColumnAlignment(.leading)
            then
                .font(.headline)
                .monospacedDigit()
            now
                .font(.headline)
                .monospacedDigit()
        }
    }
}
