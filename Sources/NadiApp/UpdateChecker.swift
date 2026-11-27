import Foundation
import NadiCore
import Observation

@MainActor
@Observable
final class UpdateChecker {
    private(set) var available: AvailableUpdate?

    @ObservationIgnored private var task: Task<Void, Never>?

    func start() {
        guard task == nil,
              let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        else { return }
        task = Task {
            while !Task.isCancelled {
                await check(current: version)
                do {
                    try await Task.sleep(for: .seconds(86_400))
                } catch {
                    return
                }
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    private func check(current version: String) async {
        guard let url = URL(string: "https://api.github.com/repos/theyudhiztira/nadi/releases?per_page=20") else { return }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Nadi/\(version)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return }
        available = UpdateCheck.newest(in: data, current: version)
    }
}
