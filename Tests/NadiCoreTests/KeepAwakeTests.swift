import Testing
@testable import NadiCore

struct KeepAwakeTests {
    @Test func parsesSleepDisabled() {
        let output = "System-wide power settings:\n SleepDisabled\t\t1\nCurrently in use:\n"
        #expect(KeepAwakeRule.sleepDisabled(pmsetOutput: output) == true)
        #expect(KeepAwakeRule.sleepDisabled(pmsetOutput: " SleepDisabled\t\t0\n") == false)
        #expect(KeepAwakeRule.sleepDisabled(pmsetOutput: "System-wide power settings:\n") == nil)
    }

    @Test func makesRestrictedSudoersRule() {
        #expect(KeepAwakeRule.sudoersLine(user: "dipandu") == "dipandu ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1")
        for user in ["", "-x", "a b", "a'b", "a\nb", "a,b"] {
            #expect(KeepAwakeRule.sudoersLine(user: user) == nil)
        }
    }

    @Test func installScriptUsesValidatedRule() {
        let line = KeepAwakeRule.sudoersLine(user: "dipandu")!
        let script = KeepAwakeRule.installScript(user: "dipandu")!
        #expect(script.contains(line))
        #expect(script.contains(KeepAwakeRule.sudoersPath))
    }

    @Test func escapesAppleScriptString() {
        #expect(KeepAwakeRule.appleScriptLiteral(#"say "hi" \ bye"#) == #""say \"hi\" \\ bye""#)
    }
}
