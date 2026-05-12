import Foundation

/// `editorFocus && ghostVisible && !inPlaceholderMode` 같은 표현식을 AST로 파싱한다.
/// 지원 토큰: 식별자, `&&`, `||`, `!`, `(`, `)`. 빈 문자열은 nil (= 항상 true).
enum WhenExpressionParser {
    enum ParseError: Error, CustomStringConvertible {
        case unexpectedCharacter(Character)
        case unexpectedToken(String)
        case unbalancedParen
        case trailingTokens

        var description: String {
            switch self {
            case .unexpectedCharacter(let c): return "예상치 못한 문자: \(c)"
            case .unexpectedToken(let s):     return "예상치 못한 토큰: \(s)"
            case .unbalancedParen:            return "괄호가 닫히지 않음"
            case .trailingTokens:             return "표현식 뒤에 남은 토큰이 있음"
            }
        }
    }

    private enum Token: Equatable {
        case identifier(String)
        case and
        case or
        case not
        case lparen
        case rparen
    }

    static func parse(_ raw: String) throws -> WhenExpression? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let tokens = try tokenize(trimmed)
        var idx = 0
        let expr = try parseOr(tokens, &idx)
        if idx != tokens.count {
            throw ParseError.trailingTokens
        }
        return expr
    }

    // MARK: - Tokenizer

    private static func tokenize(_ s: String) throws -> [Token] {
        var tokens: [Token] = []
        let chars = Array(s)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c.isWhitespace { i += 1; continue }

            if c == "(" { tokens.append(.lparen); i += 1; continue }
            if c == ")" { tokens.append(.rparen); i += 1; continue }
            if c == "!" { tokens.append(.not); i += 1; continue }

            if c == "&" {
                guard i + 1 < chars.count, chars[i + 1] == "&" else {
                    throw ParseError.unexpectedCharacter(c)
                }
                tokens.append(.and); i += 2; continue
            }
            if c == "|" {
                guard i + 1 < chars.count, chars[i + 1] == "|" else {
                    throw ParseError.unexpectedCharacter(c)
                }
                tokens.append(.or); i += 2; continue
            }

            // 식별자: [A-Za-z_][A-Za-z0-9_.]*
            if c.isLetter || c == "_" {
                let start = i
                while i < chars.count {
                    let cc = chars[i]
                    if cc.isLetter || cc.isNumber || cc == "_" || cc == "." {
                        i += 1
                    } else {
                        break
                    }
                }
                tokens.append(.identifier(String(chars[start..<i])))
                continue
            }

            throw ParseError.unexpectedCharacter(c)
        }
        return tokens
    }

    // MARK: - Parser (precedence: or < and < not < primary)

    private static func parseOr(_ tokens: [Token], _ idx: inout Int) throws -> WhenExpression {
        var left = try parseAnd(tokens, &idx)
        while idx < tokens.count, tokens[idx] == .or {
            idx += 1
            let right = try parseAnd(tokens, &idx)
            left = .or(left, right)
        }
        return left
    }

    private static func parseAnd(_ tokens: [Token], _ idx: inout Int) throws -> WhenExpression {
        var left = try parseUnary(tokens, &idx)
        while idx < tokens.count, tokens[idx] == .and {
            idx += 1
            let right = try parseUnary(tokens, &idx)
            left = .and(left, right)
        }
        return left
    }

    private static func parseUnary(_ tokens: [Token], _ idx: inout Int) throws -> WhenExpression {
        guard idx < tokens.count else { throw ParseError.unexpectedToken("(end)") }
        if tokens[idx] == .not {
            idx += 1
            let inner = try parseUnary(tokens, &idx)
            return .not(inner)
        }
        return try parsePrimary(tokens, &idx)
    }

    private static func parsePrimary(_ tokens: [Token], _ idx: inout Int) throws -> WhenExpression {
        guard idx < tokens.count else { throw ParseError.unexpectedToken("(end)") }
        let tok = tokens[idx]
        switch tok {
        case .lparen:
            idx += 1
            let inner = try parseOr(tokens, &idx)
            guard idx < tokens.count, tokens[idx] == .rparen else {
                throw ParseError.unbalancedParen
            }
            idx += 1
            return inner
        case .identifier(let name):
            idx += 1
            return .identifier(name)
        case .and, .or, .not, .rparen:
            throw ParseError.unexpectedToken("\(tok)")
        }
    }
}
