import Foundation

enum GitHubClientError: LocalizedError, Equatable {
    case ghNotFound
    case tokenMissing
    case http(Int, String)
    case decoding(String)
    case empty

    var errorDescription: String? {
        switch self {
        case .ghNotFound:
            return "GitHub CLI not found. Install gh and run gh auth login."
        case .tokenMissing:
            return "Not signed in. Run gh auth login."
        case .http(let code, let body):
            return "GitHub HTTP \(code): \(body)"
        case .decoding(let message):
            return "Could not read GitHub response: \(message)"
        case .empty:
            return "Empty GitHub response."
        }
    }
}

struct GitHubClient: Sendable {
    var tokenProvider: @Sendable () throws -> String = GitHubClient.readTokenFromGH
    var session: URLSession = .shared
    var endpoint: URL = URL(string: "https://api.github.com/graphql")!

    func viewerLogin() async throws -> String {
        let data = try await graphql("query { viewer { login } }")
        let parsed = try JSONDecoder().decode(ViewerResponse.self, from: data)
        if let message = parsed.errors?.first?.message {
            throw GitHubClientError.decoding(message)
        }
        guard let login = parsed.data?.viewer.login, !login.isEmpty else {
            throw GitHubClientError.decoding("missing viewer.login")
        }
        return login
    }

    func mergedPRs(author: String, window: DayWindow) async throws -> [MergedPR] {
        var collected: [MergedPR] = []
        var cursor: String?
        let queryString = "is:pr is:merged author:\(author) merged:>=\(window.githubSearchLowerBound)"

        repeat {
            let after = cursor.map { ", after: \"\($0)\"" } ?? ""
            let document = """
            query {
              search(query: "\(queryString)", type: ISSUE, first: 100\(after)) {
                pageInfo { hasNextPage endCursor }
                nodes {
                  ... on PullRequest {
                    title
                    url
                    mergedAt
                    createdAt
                    repository { nameWithOwner }
                  }
                }
              }
            }
            """
            let data = try await graphql(document)
            let parsed = try JSONDecoder().decode(SearchResponse.self, from: data)
            if let message = parsed.errors?.first?.message {
                throw GitHubClientError.decoding(message)
            }
            guard let search = parsed.data?.search else {
                throw GitHubClientError.decoding("missing search")
            }

            for node in search.nodes {
                guard
                    let title = node.title,
                    let urlString = node.url,
                    let url = URL(string: urlString),
                    let mergedAtString = node.mergedAt,
                    let mergedAt = DateDecoding.iso8601(mergedAtString),
                    window.contains(mergedAt)
                else { continue }
                collected.append(
                    MergedPR(
                        title: title,
                        url: url,
                        repo: node.repository?.nameWithOwner ?? "unknown",
                        mergedAt: mergedAt
                    )
                )
            }

            cursor = search.pageInfo.hasNextPage ? search.pageInfo.endCursor : nil
        } while cursor != nil

        return collected.sorted { $0.mergedAt > $1.mergedAt }
    }

    func openPRs(author: String) async throws -> [MergedPR] {
        let queryString = "is:pr is:open author:\(author)"
        let document = """
        query {
          search(query: "\(queryString)", type: ISSUE, first: 30) {
            pageInfo { hasNextPage endCursor }
            nodes {
              ... on PullRequest {
                title
                url
                mergedAt
                createdAt
                repository { nameWithOwner }
              }
            }
          }
        }
        """
        let data = try await graphql(document)
        let parsed = try JSONDecoder().decode(SearchResponse.self, from: data)
        if let message = parsed.errors?.first?.message {
            throw GitHubClientError.decoding(message)
        }
        var collected: [MergedPR] = []
        for node in parsed.data?.search.nodes ?? [] {
            guard
                let title = node.title,
                let urlString = node.url,
                let url = URL(string: urlString)
            else { continue }
            let created = node.createdAt.flatMap(DateDecoding.iso8601) ?? Date.distantPast
            collected.append(
                MergedPR(
                    title: title,
                    url: url,
                    repo: node.repository?.nameWithOwner ?? "unknown",
                    mergedAt: created
                )
            )
        }
        return collected.sorted { $0.mergedAt > $1.mergedAt }
    }

    private func graphql(_ query: String) async throws -> Data {
        let token = try tokenProvider()
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("PRBar/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["query": query])

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GitHubClientError.empty }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GitHubClientError.http(http.statusCode, String(body.prefix(240)))
        }
        return data
    }

    static func readTokenFromGH() throws -> String {
        let binaries = [
            "/opt/homebrew/bin/gh",
            "/usr/local/bin/gh",
            "/usr/bin/gh"
        ]
        let path = binaries.first { FileManager.default.isExecutableFile(atPath: $0) }
        guard let path else { throw GitHubClientError.ghNotFound }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["auth", "token"]
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        let token = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard process.terminationStatus == 0, !token.isEmpty else {
            throw GitHubClientError.tokenMissing
        }
        return token
    }
}

private struct GraphQLError: Decodable {
    let message: String
}

private struct ViewerResponse: Decodable {
    struct DataBody: Decodable {
        struct Viewer: Decodable { let login: String }
        let viewer: Viewer
    }
    let data: DataBody?
    let errors: [GraphQLError]?
}

private struct SearchResponse: Decodable {
    struct DataBody: Decodable { let search: Search }
    struct Search: Decodable {
        let pageInfo: PageInfo
        let nodes: [Node]
    }
    struct PageInfo: Decodable {
        let hasNextPage: Bool
        let endCursor: String?
    }
    struct Node: Decodable {
        let title: String?
        let url: String?
        let mergedAt: String?
        let createdAt: String?
        let repository: Repository?
    }
    struct Repository: Decodable { let nameWithOwner: String }

    let data: DataBody?
    let errors: [GraphQLError]?
}
