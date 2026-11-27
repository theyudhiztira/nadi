import Foundation

public enum KeepAwakeRule {
    public static let sudoersPath = "/etc/sudoers.d/nadi-keep-awake"

    public static func sleepDisabled(pmsetOutput: String) -> Bool? {
        for line in pmsetOutput.split(whereSeparator: \.isNewline) {
            let fields = line.split(whereSeparator: \.isWhitespace)
            if fields.first == "SleepDisabled" {
                return fields.dropFirst().first == "1"
            }
        }
        return nil
    }

    public static func sudoersLine(user: String) -> String? {
        guard user.range(of: #"^[A-Za-z0-9_][A-Za-z0-9._-]*\z"#, options: .regularExpression) != nil else { return nil }
        return "\(user) ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1"
    }

    public static func installScript(user: String) -> String? {
        guard let line = sudoersLine(user: user) else { return nil }
        return "t=$(/usr/bin/mktemp) && /usr/bin/printf '%s\\n' '\(line)' > \"$t\" && /usr/sbin/visudo -cf \"$t\" && /usr/bin/install -m 0440 -o root -g wheel \"$t\" \(sudoersPath); r=$?; /bin/rm -f \"$t\"; exit $r"
    }

    public static func appleScriptLiteral(_ s: String) -> String {
        "\"\(s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
    }
}
