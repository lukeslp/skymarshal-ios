import Foundation

/// Shape check for Bluesky app passwords.
///
/// App passwords are always issued as four dash-separated groups of four
/// alphanumerics (`xxxx-xxxx-xxxx-xxxx`). A login failure with a
/// password that doesn't match that shape almost always means the user
/// typed their main account password — worth a targeted hint before the
/// raw server error, since the server-side message ("Invalid identifier
/// or password") gives no clue about the real mistake.
///
/// Deliberately NOT used to block submission: the check is a heuristic
/// for improving the failure message only, so a false negative can never
/// lock anyone out.
public enum AppPasswordFormat {

    /// True when `password` matches the `xxxx-xxxx-xxxx-xxxx` app-password
    /// shape (case-insensitive alphanumeric groups).
    public static func looksLikeAppPassword(_ password: String) -> Bool {
        let pattern = "^[a-z0-9]{4}(-[a-z0-9]{4}){3}$"
        return password.range(
            of: pattern,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }
}
