import ComposableArchitecture
import SwiftUI

struct LicenseSettingsView: View {
  @Bindable var store: StoreOf<LicenseFeature>

  var body: some View {
    Form {
      Section("Supacode license") {
        if store.snapshot.isDevelopmentBuild {
          Text("Development builds have unlimited worktree creation.")
            .foregroundStyle(.secondary)
        } else if store.snapshot.ownsCurrentRelease {
          Label("This Mac is licensed", systemImage: "checkmark.seal")
          if let end = store.snapshot.entitlement?.updatesThrough {
            LabeledContent("Updates included through", value: end.rawValue)
          }
        } else {
          Text("\(store.snapshot.remainingCreations) free worktree creations remaining")
            .font(.headline)
          Text(
            "Create five new worktrees for free. A license unlocks unlimited creation. "
              + "Existing worktrees and terminals stay available."
          )
          .foregroundStyle(.secondary)
          if store.snapshot.entitlement?.status == .active {
            Text(
              "This release is newer than your included updates. "
                + "Renew updates or download an owned release from your license portal."
            )
            .foregroundStyle(.secondary)
          }
        }
        Text(
          "$99 USD for perpetual use on one Mac and one year of updates. "
            + "Optional updates renewal: $59 USD. Tax may apply."
        )
        .foregroundStyle(.secondary)
      }

      if store.snapshot.entitlement?.status == .active {
        Section {
          Button("Deactivate This Mac") { store.send(.deactivate) }
            .disabled(store.isBusy)
            .help("Deactivate this Mac so you can activate your license on another Mac.")
          Button("Refresh License") { store.send(.refresh) }
            .disabled(store.isBusy)
            .help("Check the license server for renewed updates or license changes.")
        }
      } else {
        Section("Activate") {
          TextField("License key", text: $store.keyInput)
            .textFieldStyle(.roundedBorder)
            .monospaced()
            .onSubmit { store.send(.activate) }
          Button("Activate License") { store.send(.activate) }
            .keyboardShortcut(.return)
            .disabled(
              store.isBusy || store.keyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
            .help("Activate your license on this Mac. Return.")
        }
      }

      if let error = store.errorMessage {
        Text(error).foregroundStyle(.red)
      }
      if store.isBusy { ProgressView().controlSize(.small) }
      Section {
        Button("Buy Supacode") { store.send(.buy) }
          .help("Purchase a Supacode license in your browser.")
        Button("License Portal") { store.send(.portal) }
          .help("Recover your key, renew updates, or manage your license.")
      }
    }
    .formStyle(.grouped)
    .navigationTitle("License")
  }
}
