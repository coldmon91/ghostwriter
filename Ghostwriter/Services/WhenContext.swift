import Foundation

/// `when` 표현식이 평가될 때 참조하는 현재 에디터 상태.
struct WhenContext {
    var editorFocus: Bool
    var ghostVisible: Bool
    var inPlaceholderMode: Bool
    var slashPopupVisible: Bool
    var hasSelection: Bool

    static let empty = WhenContext(
        editorFocus: false,
        ghostVisible: false,
        inPlaceholderMode: false,
        slashPopupVisible: false,
        hasSelection: false
    )

    /// 식별자 이름으로 boolean 조회. 모르는 이름은 false.
    func value(forIdentifier name: String) -> Bool {
        switch name {
        case "editorFocus":        return editorFocus
        case "ghostVisible":       return ghostVisible
        case "inPlaceholderMode":  return inPlaceholderMode
        case "slashPopupVisible":  return slashPopupVisible
        case "hasSelection":       return hasSelection
        default:                   return false
        }
    }
}
