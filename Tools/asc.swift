import CryptoKit
import Foundation

// Mints a bearer token for the App Store Connect API.
//
// The API wants an ES256 JWT signed with the .p8 Apple issues. CryptoKit can do
// this directly, which avoids adding a Python crypto dependency just to sign a
// short-lived token.

func base64URL(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

let args = CommandLine.arguments
guard args.count >= 4 else {
    FileHandle.standardError.write(Data("usage: asc <keyPath> <keyID> <issuerID>\n".utf8))
    exit(2)
}
let (keyPath, keyID, issuerID) = (args[1], args[2], args[3])

let pem = try String(contentsOfFile: keyPath, encoding: .utf8)
let key = try P256.Signing.PrivateKey(pemRepresentation: pem)

let header = #"{"alg":"ES256","kid":"\#(keyID)","typ":"JWT"}"#
// Apple rejects anything longer than 20 minutes.
let expiry = Int(Date().timeIntervalSince1970) + 900
let payload = #"{"iss":"\#(issuerID)","exp":\#(expiry),"aud":"appstoreconnect-v1"}"#

let signingInput = "\(base64URL(Data(header.utf8))).\(base64URL(Data(payload.utf8)))"
let signature = try key.signature(for: Data(signingInput.utf8))
print("\(signingInput).\(base64URL(signature.rawRepresentation))")
