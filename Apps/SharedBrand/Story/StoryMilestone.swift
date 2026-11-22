import Foundation

/// A step in the life of Locky, for the timeline of the easter egg.
///
/// The work dates of 2014 and 2015 come from the headers of the files of `Legacy/` (when each part
/// of the app was started); the first film from the Vimeo of Lunabee; the release, the Apple
/// Watch and the end from the history of the old app in App Store Connect (1.0 ready for sale on
/// 15 May 2015, 2.1 with the Apple Watch on 25 September 2015, removed from sale on 31 October
/// 2017); the later ones from the history of this repository.
struct StoryMilestone: Identifiable {
    let id: Int
    let year: Int
    /// The month, when known; the year alone otherwise.
    let month: Int?
    let text: LocalizedStringResource

    static let all: [StoryMilestone] = [
        .init(id: 0, year: 2014, month: 3, text: "The first lines of Locky, for the iPhone and the Mac."),
        .init(id: 1, year: 2014, month: 7, text: "The first film of Locky goes online."),
        .init(id: 2, year: 2015, month: 3, text: "The iPhone and the Mac now talk in encrypted messages, and Locky starts by itself when you log in."),
        .init(id: 3, year: 2015, month: 4, text: "A brand new welcome, with the logo that builds itself, and the Today widget."),
        .init(id: 4, year: 2015, month: 5, text: "Locky comes out: walk away, and your Mac locks itself."),
        .init(id: 5, year: 2015, month: 9, text: "Locky arrives on the Apple Watch."),
        .init(id: 6, year: 2017, month: 10, text: "Locky leaves the App Store: iOS 11 and macOS High Sierra broke its Bluetooth. RIP ☠️"),
        .init(id: 7, year: 2025, month: 5, text: "The code comes out of the boxes and compiles again."),
        .init(id: 8, year: 2026, month: 11, text: "Locky is reborn in Swift, from the iPhone to the Mac and the Apple Watch.")
    ]

    /// The first day of its month, to show the month and the year in the language of the app.
    var date: Date? {
        guard let month else { return nil }
        return Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: 1))
    }
}
