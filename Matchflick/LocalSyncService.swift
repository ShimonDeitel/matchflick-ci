import Foundation
import MultipeerConnectivity
import UIKit

/// Honest scope: this is NOT iCloud. There's no way to verify "same Apple ID" without an account
/// system (Sign in with Apple was removed — see AppModel history). Instead this pairs over the
/// local Wi-Fi network with any other device running Minder that also has sync turned on —
/// exactly like AirDrop discovery, no login, nothing leaves the network. Real background/
/// over-the-internet iCloud sync (the Notes/Reminders model) needs a CloudKit container, which
/// is blocked pending Developer Portal access — see AppModel.makeContainer's cloudKitDatabase
/// attempt, which will start working on its own the day that capability is enabled.
///
/// Sync is additive-only by design: an item added on one device appears on the other, but a
/// delete or move made locally does not propagate. That keeps merge logic simple and safe
/// (no risk of one device's deletion silently wiping data the other device still wants).
struct SyncSnapshot: Codable {
    var entries: [SyncEntry]
    var boards: [SyncBoard]

    struct SyncEntry: Codable {
        var id: UUID
        var movieId: String
        var title: String
        var year: Int
        var mediaTypeRaw: String
        var statusRaw: String
        var boardID: UUID?
        var addedAt: Date
    }

    struct SyncBoard: Codable {
        var id: UUID
        var name: String
        var symbol: String
        var kindRaw: String
        var isDefault: Bool
        var createdAt: Date
    }
}

@MainActor
final class LocalSyncService: NSObject, ObservableObject {
    private static let serviceType = "minder-sync"

    @Published private(set) var connectedPeerCount = 0
    @Published private(set) var isRunning = false

    var onReceiveSnapshot: ((SyncSnapshot) -> Void)?
    var makeLocalSnapshot: (() -> SyncSnapshot)?

    private let peerID = MCPeerID(displayName: UIDevice.current.name)
    private lazy var session: MCSession = {
        let s = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        s.delegate = self
        return s
    }()
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    func start() {
        guard !isRunning else { return }
        isRunning = true
        let advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: Self.serviceType)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser

        let browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser
    }

    func stop() {
        isRunning = false
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        browser?.stopBrowsingForPeers()
        browser = nil
        session.disconnect()
        connectedPeerCount = 0
    }

    /// Call after any local mutation while sync is on, so connected peers pick up the change.
    func broadcastLocalState() {
        guard isRunning, !session.connectedPeers.isEmpty, let snapshot = makeLocalSnapshot?() else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }
}

extension LocalSyncService: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            self.connectedPeerCount = session.connectedPeers.count
            if state == .connected { self.broadcastLocalState() }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let snapshot = try? JSONDecoder().decode(SyncSnapshot.self, from: data) else { return }
        Task { @MainActor in self.onReceiveSnapshot?(snapshot) }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension LocalSyncService: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
                                 withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in invitationHandler(true, self.session) }
    }
}

extension LocalSyncService: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            guard self.session.connectedPeers.contains(peerID) == false else { return }
            browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 10)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}
