import CharbonCore
import OSLog
import WebKit

/// Fills the identity provider's login pages with the saved login, one page at a time.
///
/// The login pages change without loading a new page, so it looks at the web view ten times a
/// second. A page that comes back after two tries is left alone, so a wrong password cannot lock
/// the account. Use one instance per login attempt.
@MainActor
final class LoginAutofill {
  private static let logger = Logger(subsystem: "ch.codevs.charbon", category: "autofill")
  private static let maximumTries = 2
  private static let maximumDuration: Duration = .seconds(120)
  // The page just filled stays on screen until the server answers.
  private static let cooldown: Duration = .seconds(3)

  // A page is recognised by its fields: password first, then the authenticator code, then the
  // email of the first page, then the button that picks a password over a passkey.
  private static let script = """
    const visible = element => element.offsetParent !== null;
    const find = selector => [...document.querySelectorAll(selector)].find(visible);
    const fill = (element, value) => {
      const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
      setter.call(element, value);
      element.dispatchEvent(new Event('input', {bubbles: true}));
      element.dispatchEvent(new Event('change', {bubbles: true}));
    };
    const send = element => {
      const form = element.form;
      const button = form && form.querySelector('button[type=submit], input[type=submit]');
      if (button) { button.click(); } else if (form) { form.requestSubmit(); }
    };
    const codeFields = ['one-time-code', 'otp', 'token', 'code']
      .map(name => `input[autocomplete=${name}], input[name*=${name} i]`).join(', ');
    const fields = [
      ['password', 'input[type=password]', password],
      ['code', codeFields, code],
      ['username', 'input[name=j_username]', username],
    ];
    for (const [step, selector, value] of fields) {
      const element = find(selector);
      if (!element) { continue; }
      if (!steps.includes(step) || !value) { return 'skipped ' + step; }
      fill(element, value);
      send(element);
      return step;
    }
    const choice = [...document.querySelectorAll('button, a')].filter(visible)
      .find(button => /^use password$/i.test(button.textContent.trim()));
    if (choice) {
      if (!steps.includes('method')) { return 'skipped method'; }
      choice.click();
      return 'method';
    }
    const inputs = [...document.querySelectorAll('input')].map(input => {
      return input.type + ':' + input.name + (visible(input) ? '' : ':hidden');
    });
    const buttons = [...document.querySelectorAll('button, a')].filter(visible)
      .map(button => button.textContent.trim().slice(0, 30));
    const text = (document.body ? document.body.innerText : '').replace(/\\s+/g, ' ').slice(0, 200);
    return `unknown inputs ${inputs.join(' ')} | frames ${window.frames.length} | `
      + `buttons ${buttons.join(', ')} | text ${text}`;
    """

  // The server refuses a code it has seen, so a second login in the same 30 seconds has to wait
  // for the next one.
  private static var lastCode: String?

  // A wrong password must not be tried again and again, or edu-ID locks the account. After two
  // runs that sent the password and still failed, the autofill stays off until the login is saved
  // again or a login works.
  private static let maximumFailedRuns = 2
  private static var failedRuns = 0

  static func reset() {
    failedRuns = 0
  }

  private var credentials: LoginCredentials?
  private var wasPaused = false
  private var sawCodePageWithoutCode = false
  private var tries: [String: Int] = [:]
  private var lastFilled: [String: ContinuousClock.Instant] = [:]
  private var task: Task<Void, Never>?
  private var lastNote = ""

  // Calls `onProgress` each time it has filled a page, with how much longer than usual the next
  // page may take. While it waits for a new code that is up to 30 seconds.
  func start(in webView: WKWebView, onProgress: @escaping (Duration) -> Void) {
    task?.cancel()
    credentials = CredentialVault.load()
    wasPaused = Self.failedRuns >= Self.maximumFailedRuns
    task = Task { [weak webView] in
      let deadline = ContinuousClock.now + Self.maximumDuration
      while !Task.isCancelled, ContinuousClock.now < deadline, let webView {
        if let extraWait = await advance(in: webView) {
          onProgress(extraWait)
        }
        try? await Task.sleep(for: .milliseconds(100))
      }
    }
  }

  func stop() {
    task?.cancel()
    task = nil
  }

  // Ends a run of the renewal, which either reached Timbrage or did not.
  func finish(landed: Bool) {
    stop()
    if landed {
      Self.reset()
    } else if tries["password", default: 0] > 0 {
      Self.failedRuns += 1
    }
  }

  /// Why the run did not get in, or `nil` when there was no saved login to try.
  var failure: AutoLoginFailure? {
    guard credentials != nil else {
      return nil
    }
    if wasPaused {
      return .paused
    }
    if sawCodePageWithoutCode {
      return .needsCode
    }
    if tries["password"] != nil || tries["code"] != nil {
      return .rejected
    }
    return tries.isEmpty ? .timedOut : .unknownPage
  }

  private func advance(in webView: WKWebView) async -> Duration? {
    guard
      let host = webView.url?.host, host == "eduid.ch" || host.hasSuffix(".eduid.ch"),
      !webView.isLoading,
      Self.failedRuns < Self.maximumFailedRuns,
      let credentials
    else {
      return nil
    }
    let code = TOTP.code(secret: credentials.totpSecret, at: .now) ?? ""
    let isCodeUsed = code == Self.lastCode
    let now = ContinuousClock.now
    let steps = ["password", "code", "username", "method"].filter { step in
      tries[step, default: 0] < Self.maximumTries
        && lastFilled[step].map { now - $0 > Self.cooldown } ?? true
        && !(step == "code" && isCodeUsed)
    }
    let arguments: [String: Any] = [
      "username": credentials.username, "password": credentials.password, "code": code,
      "steps": steps,
    ]
    let result: String
    do {
      let value = try await webView.callAsyncJavaScript(
        Self.script, arguments: arguments, contentWorld: .page)
      result = value as? String ?? ""
    } catch {
      let detail = (error as NSError).userInfo["WKJavaScriptExceptionMessage"] ?? error
      Self.logger.error("Autofill failed: \(String(describing: detail), privacy: .public)")
      return nil
    }
    guard steps.contains(result) else {
      if result != lastNote {
        lastNote = result
        Self.logger.notice("Login page not filled: \(result, privacy: .public)")
      }
      if result == "skipped code", code.isEmpty {
        sawCodePageWithoutCode = true
      }
      return result == "skipped code" && isCodeUsed ? .seconds(30) : nil
    }
    tries[result, default: 0] += 1
    lastFilled[result] = now
    if result == "code" {
      Self.lastCode = code
    }
    Self.logger.notice("Filled the \(result, privacy: .public) page")
    return .zero
  }
}
