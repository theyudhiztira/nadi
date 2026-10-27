import SwiftUI

// The macOS 27 SDK resolves `@State` to a macro whose plugin ships only with Xcode, not the Command Line Tools.
// This alias names the property wrapper directly; use `@ViewState` instead of `@State`.
typealias ViewState = SwiftUI.State
