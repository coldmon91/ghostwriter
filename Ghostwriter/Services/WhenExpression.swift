import Foundation

/// `when` 절의 AST. `&&`, `||`, `!`, `()`, 식별자만 지원.
indirect enum WhenExpression {
    case identifier(String)
    case not(WhenExpression)
    case and(WhenExpression, WhenExpression)
    case or(WhenExpression, WhenExpression)

    func evaluate(in ctx: WhenContext) -> Bool {
        switch self {
        case .identifier(let name):    return ctx.value(forIdentifier: name)
        case .not(let e):              return !e.evaluate(in: ctx)
        case .and(let l, let r):       return l.evaluate(in: ctx) && r.evaluate(in: ctx)
        case .or(let l, let r):        return l.evaluate(in: ctx) || r.evaluate(in: ctx)
        }
    }
}
