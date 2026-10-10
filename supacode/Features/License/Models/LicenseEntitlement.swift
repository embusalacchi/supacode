nonisolated struct LicenseEntitlement: Equatable, Sendable {
  enum Status: String, Codable, Sendable {
    case active
    case deactivated
    case revoked
    case transferred
  }

  let licenseID: String
  let deviceID: String
  let status: Status
  let updatesThrough: LicenseDay?
  let revision: Int
  let issuedAt: Int64
  let revocationReason: String?
  let signedToken: String

  init(
    licenseID: String,
    deviceID: String,
    status: Status,
    updatesThrough: LicenseDay?,
    revision: Int,
    issuedAt: Int64,
    revocationReason: String?,
    signedToken: String
  ) {
    self.licenseID = licenseID
    self.deviceID = deviceID
    self.status = status
    self.updatesThrough = updatesThrough
    self.revision = revision
    self.issuedAt = issuedAt
    self.revocationReason = revocationReason
    self.signedToken = signedToken
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.licenseID == rhs.licenseID
      && lhs.deviceID == rhs.deviceID
      && lhs.status == rhs.status
      && lhs.updatesThrough == rhs.updatesThrough
      && lhs.revision == rhs.revision
      && lhs.issuedAt == rhs.issuedAt
      && lhs.revocationReason == rhs.revocationReason
  }
}
