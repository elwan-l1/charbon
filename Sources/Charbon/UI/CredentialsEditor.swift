import CharbonCore
import SwiftUI

/// The login Charbon types for the user when the identity provider asks for it.
///
/// It lives in the Keychain of this Mac and goes nowhere else.
struct CredentialsEditor: View {
  let model: AppModel
  @State private var username = ""
  @State private var password = ""
  @State private var totpSecret = ""
  @State private var isSaved = false
  @State private var test = Test.idle
  @State private var problem: CharbonProblem?

  private enum Test {
    case idle, running, passed, failed
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(
        "Charbon fills the login pages by itself, so you stay logged in. "
          + "The login is kept in the Keychain of this Mac."
      )
      .font(.reading).foregroundStyle(Theme.muted)
      .fixedSize(horizontal: false, vertical: true)
      labeled("Switch edu-ID email") {
        TextField("name@hes-so.ch", text: $username).flatField(width: 340)
      }
      labeled("Password") {
        SecureField("Password", text: $password).flatField(width: 340)
      }
      labeled("Authenticator key or otpauth:// link, if you use an app code") {
        SecureField("Key or link from your password manager", text: $totpSecret)
          .flatField(width: 340)
      }
      if !isKeyValid {
        Text("That is not a key. A key has the letters A to Z and the digits 2 to 7.")
          .font(.note).foregroundStyle(Theme.bad)
      }
      if let problem {
        Notice(text: problem.headline, problem: problem)
      }
      HStack(spacing: 12) {
        Button("Save") { save() }
          .buttonStyle(.blockPrimary)
          .disabled(username.isEmpty || password.isEmpty || !isKeyValid)
        if isSaved {
          Button("Forget") { forget() }.buttonStyle(.block)
        }
        testResult
      }
    }
    .onAppear(perform: load)
  }

  @ViewBuilder private var testResult: some View {
    switch test {
    case .idle:
      if isSaved {
        Text("Saved").font(.note).foregroundStyle(Theme.muted)
      }
    case .running:
      ProgressView().controlSize(.small)
      Text("Testing the login").font(.note).foregroundStyle(Theme.muted)
    case .passed:
      Label("Saved, the login works", systemImage: "checkmark.circle.fill")
        .font(.note).foregroundStyle(Theme.good)
    case .failed:
      Label("Saved, but the login failed. Check the details.", systemImage: "xmark.circle.fill")
        .font(.note).foregroundStyle(Theme.bad)
    }
  }

  private var isKeyValid: Bool {
    totpSecret.isEmpty || TOTP.code(secret: totpSecret, at: .now) != nil
  }

  private func labeled<Content: View>(
    _ title: String, @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title).font(.note).foregroundStyle(Theme.muted)
      content()
    }
  }

  private func load() {
    guard let saved = CredentialVault.load() else {
      return
    }
    username = saved.username
    password = saved.password
    totpSecret = saved.totpSecret
    isSaved = true
  }

  private func save() {
    let credentials = LoginCredentials(
      username: username.trimmingCharacters(in: .whitespaces),
      password: password,
      totpSecret: totpSecret.trimmingCharacters(in: .whitespaces)
    )
    isSaved = CredentialVault.save(credentials)
    problem = isSaved ? nil : .loginNotSaved
    guard isSaved else {
      return
    }
    LoginAutofill.reset()
    Task { await runTest() }
  }

  // A signed in session would not use the login, so that case tries it in a separate web view.
  // The other case renews for real: the same code cannot be used twice, so a test first would
  // make that renewal fail.
  private func runTest() async {
    test = .running
    let session = model.session
    let works: Bool
    if session.state.isSignedIn {
      works = await session.testSavedLogin()
    } else {
      await session.renewNow()
      works = session.state.isSignedIn
    }
    test = works ? .passed : .failed
  }

  private func forget() {
    CredentialVault.delete()
    username = ""
    password = ""
    totpSecret = ""
    isSaved = false
    test = .idle
  }
}
