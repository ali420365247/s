import 'dart:typed_data';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'identity_manager.dart';

class OfflineTransferService {
  static const String serviceId = "chat.nexus.zero.transfer";

  /// Start on OLD phone (sender)
  static Future<void> startExport() async {
    final Uint8List blob = await IdentityManager.exportEncryptedBlob(); // ~small

    // 1. Try NFC first (instant if tapped)
    try {
      final nfcAvailable = await NfcManager.instance.isAvailable();
      if (nfcAvailable) {
        // Start NFC session and write NDEF when discovered. Keep session open
        // long enough for tap. In production, handle errors/timeouts and
        // disable other transports when NFC completes.
        NfcManager.instance.startSession(onDiscovered: (tag) async {
          try {
            final ndef = NdefMessage.withRecords([
              NdefRecord.createMime("application/nexus.zero", blob),
            ]);
            await tag.writeNdef(ndef);
          } catch (_) {
            // ignore write errors in scaffold
          }
        });
      }
    } catch (_) {
      // NFC not available — fall through to multi-transport
    }

    // 2. Simultaneously advertise via Nearby (WiFi-Direct + BT + others)
    try {
      await Nearby().startAdvertising(
        userName: "NexusTransfer",
        strategy: Strategy.P2P_CLUSTER,
        serviceId: serviceId,
        onConnectionResult: (endpointId, status) async {
          if (status == Status.CONNECTED) {
            // Perform handshake: send intro with local index id, wait for ack
            try {
              final localId = await IdentityManager.getLocalIndexId();
              final pubKey = await IdentityManager.getSigningPublicKey();
              final introMsg = jsonEncode({
                'type': 'intro',
                'index_id': localId,
                'signing_public': pubKey,
              });
              final introBytes = Uint8List.fromList(utf8.encode(introMsg));
              final signature = await IdentityManager.signMessage(introBytes);
              final intro = {
                'type': 'intro',
                'index_id': localId,
                'signing_public': pubKey,
                'signature': base64Encode(signature),
              };
              await Nearby().sendBytesPayload(endpointId, Uint8List.fromList(utf8.encode(jsonEncode(intro))));

              // Wait for ack: the library delivers payloads via onPayloadReceived on the other side.
              // Here we optimistically wait a short time for an ack to be delivered by the remote
              // and handled there; since the Nearby plugin doesn't provide a direct "receive synchronously",
              // we rely on the peer to send an ack payload back which will be delivered via the plugin callbacks
              // implemented on the receiver side. To keep this scaffold straightforward we proceed with a
              // short delay poll and then send the blob; in production a proper request/response should
              // be implemented with explicit acknowledgement messages and timeouts.
              await Future.delayed(const Duration(milliseconds: 400));

              // Send the bytes payload (identity blob). The receiver should only accept if it previously
              // acknowledged allowing transfer.
              await Nearby().sendBytesPayload(endpointId, blob);
              await Nearby().stopAdvertising();
            } catch (_) {
              // send failed — ignore for scaffold
            }
          }
        },
      );
    } catch (e) {
      // advertising failed — handle gracefully in UI
    }
  }

  /// Start export to a specific contact (by indexId). This enforces that the
  /// contact must be accepted before attempting a transfer.
  static Future<bool> startExportTo(String indexId) async {
    final accepted = await IdentityManager.isContactAccepted(indexId);
    if (!accepted) return false;
    // Proceed with the same export flow (NFC/Nearby/QR fallback)
    await startExport();
    return true;
  }

  /// Start on NEW phone (receiver)
  static Future<void> startImport() async {
    try {
      await Nearby().startDiscovery(
        userName: "NexusImport",
        strategy: Strategy.P2P_CLUSTER,
        serviceId: serviceId,
        onEndpointFound: (id, name, svcId) async {
          // Request a connection to the discovered endpoint
          await Nearby().requestConnection(
            "NexusImport",
            id,
            onConnectionResult: (endpointId, status) async {
              if (status == Status.CONNECTED) {
                await Nearby().acceptConnection(endpointId, onPayloadReceived: (payload) async {
                  try {
                    if (payload.type == PayloadType.BYTES && payload.bytes != null) {
                      final bytes = payload.bytes!;
                      // Try to parse as JSON intro first
                      final txt = utf8.decode(bytes);
                      var parsed = null;
                      try {
                        parsed = jsonDecode(txt);
                      } catch (_) {
                        parsed = null;
                      }

                      if (parsed is Map && parsed['type'] == 'intro' && parsed['index_id'] != null && parsed['signing_public'] != null && parsed['signature'] != null) {
                        final senderId = parsed['index_id'] as String;
                        final pubKey = parsed['signing_public'] as String;
                        final sig = base64Decode(parsed['signature'] as String);
                        // Verify signature
                        final introMsg = jsonEncode({
                          'type': 'intro',
                          'index_id': senderId,
                          'signing_public': pubKey,
                        });
                        final introBytes = Uint8List.fromList(utf8.encode(introMsg));
                        final valid = await IdentityManager.verifySignature(introBytes, sig, pubKey);
                        if (!valid) {
                          // Signature invalid: reject
                          await Nearby().stopDiscovery();
                          return;
                        }
                        // Check local contacts: only allow transfer from accepted contacts
                        final allowed = await IdentityManager.isContactAccepted(senderId);
                        final ack = jsonEncode({'type': 'intro_ack', 'allow': allowed});
                        await Nearby().sendBytesPayload(endpointId, Uint8List.fromList(utf8.encode(ack)));
                        if (!allowed) {
                          // Not allowed: stop discovery and close
                          await Nearby().stopDiscovery();
                          return;
                        }
                        // else: wait for the next payload which should be the identity blob
                        return;
                      }

                      // If this payload wasn't an intro JSON, treat it as the blob directly
                      // (older clients) — try to import
                      await IdentityManager.importAndWipeOld(bytes);
                      await Nearby().stopDiscovery();
                    }
                  } catch (e) {
                    // ignore and continue discovery
                  }
                });
              }
            },
          );
        },
      );
    } catch (e) {
      // discovery failed — handle gracefully and fall back to QR
    }
  }
}
