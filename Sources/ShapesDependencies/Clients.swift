import Foundation
import ShapesClients
import ShapesModels
import ShapesUtil
import SwiftJavaAnnotations

public struct Clients: Sendable {
  public let search: SearchClient
  public let notifications: NotificationsClient
  public let catalog: CatalogClient

  public init(search: SearchClient, notifications: NotificationsClient, catalog: CatalogClient) {
    self.search = search
    self.notifications = notifications
    self.catalog = catalog
  }
}
