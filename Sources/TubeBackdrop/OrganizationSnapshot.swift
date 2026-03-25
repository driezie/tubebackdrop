import Foundation

struct OrganizationSnapshot: Codable {
  var projects: [MediaProject]
  var categories: [MediaCategory]
  var linkedDatabases: [LinkedDatabase]
}
