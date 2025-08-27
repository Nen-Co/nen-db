const std = @import("std");

pub const TokenKind = enum {
    // punctuation
    l_paren, r_paren, l_brack, r_brack, l_brace, r_brace,
    colon, comma, dot, minus, gt, lt, eq, star, plus, slash, pipe,
    // literals
    integer, float, string, identifier,
    // keywords (uppercased during lexing for comparison)
    keyword,
    // end of input / invalid
    eof, invalid,
};

pub const Token = struct {
    kind: TokenKind,
    lexeme: []const u8,
};

pub const Lexer = struct {
    input: []const u8,
    index: usize = 0,

    pub fn init(input: []const u8) Lexer {
        return .{ .input = input };
    }

    pub fn next(self: *Lexer) Token {
        self.skipWhitespace();
        if (self.index >= self.input.len) return .{ .kind = .eof, .lexeme = self.input[self.index..self.index] };
        const c = self.input[self.index];
        switch (c) {
            '(' => return self.single(.l_paren),
            ')' => return self.single(.r_paren),
            '[' => return self.single(.l_brack),
            ']' => return self.single(.r_brack),
            '{' => return self.single(.l_brace),
            '}' => return self.single(.r_brace),
            ':' => return self.single(.colon),
            ',' => return self.single(.comma),
            '.' => return self.single(.dot),
            '-' => return self.single(.minus),
            '>' => return self.single(.gt),
            '<' => return self.single(.lt),
            '=' => return self.single(.eq),
            '*' => return self.single(.star),
            '+' => return self.single(.plus),
            '/' => return self.single(.slash),
            '|' => return self.single(.pipe),
            '0'...'9' => return self.number(),
            '"' => return self.string(),
            '\'' => return self.string(),
            else => return self.identifierOrKeyword(),
        }
    }

    inline fn single(self: *Lexer, kind: TokenKind) Token {
        const start = self.index;
        self.index += 1;
        return .{ .kind = kind, .lexeme = self.input[start..self.index] };
    }

    fn number(self: *Lexer) Token {
        const start = self.index;
        var seen_dot = false;
        while (self.index < self.input.len) : (self.index += 1) {
            const ch = self.input[self.index];
            if (ch == '.') {
                if (seen_dot) break;
                seen_dot = true;
                continue;
            }
            if (ch < '0' or ch > '9') break;
        }
        const lex = self.input[start..self.index];
        return .{ .kind = if (seen_dot) .float else .integer, .lexeme = lex };
    }

    fn string(self: *Lexer) Token {
        const quote = self.input[self.index];
        const start = self.index;
        self.index += 1; // skip opening quote
        while (self.index < self.input.len) : (self.index += 1) {
            const ch = self.input[self.index];
            if (ch == '\\') {
                self.index += 1; // skip escaped
                continue;
            }
            if (ch == quote) {
                self.index += 1; // include closing quote
                return .{ .kind = .string, .lexeme = self.input[start..self.index] };
            }
        }
        return .{ .kind = .invalid, .lexeme = self.input[start..self.index] };
    }

    fn identifierOrKeyword(self: *Lexer) Token {
        const start = self.index;
        // allow ASCII letters, underscore, digits after first
        if (!isIdentStart(self.input[self.index])) {
            self.index += 1;
            return .{ .kind = .invalid, .lexeme = self.input[start..self.index] };
        }
        self.index += 1;
        while (self.index < self.input.len and isIdentPart(self.input[self.index])) : (self.index += 1) {}
        const slice = self.input[start..self.index];
        // classify as keyword if matches known keywords ignoring case
        const upper = toUpperTemp(slice);
        if (isKeyword(upper)) return .{ .kind = .keyword, .lexeme = upper };
        return .{ .kind = .identifier, .lexeme = slice };
    }

    fn skipWhitespace(self: *Lexer) void {
        while (self.index < self.input.len) : (self.index += 1) {
            const ch = self.input[self.index];
            if (ch == ' ' or ch == '\n' or ch == '\t' or ch == '\r') continue;
            if (ch == '/' and self.index + 1 < self.input.len and self.input[self.index + 1] == '/') {
                // line comment
                self.index += 2;
                while (self.index < self.input.len and self.input[self.index] != '\n') : (self.index += 1) {}
                continue;
            }
            break;
        }
    }
};

fn isIdentStart(c: u8) bool {
    return (c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z') or c == '_';
}

fn isIdentPart(c: u8) bool {
    return isIdentStart(c) or (c >= '0' and c <= '9');
}

fn toUpperTemp(slice: []const u8) []const u8 {
    // Return the same slice if already uppercase. For now, we allocate no buffer here
    // and simply map ASCII letters to uppercase on the fly by writing into a threadlocal buffer.
    // To avoid allocations in this early skeleton, we detect exact keyword spans directly.
    return slice; // parser will compare case-insensitively
}

fn isKeyword(s: []const u8) bool {
    // Case-insensitive checks during parse; here treat any of these as keyword when matched ignoring case
    return std.ascii.eqlIgnoreCase(s, "MATCH")
        or std.ascii.eqlIgnoreCase(s, "RETURN")
        or std.ascii.eqlIgnoreCase(s, "WITH")
        or std.ascii.eqlIgnoreCase(s, "WHERE")
        or std.ascii.eqlIgnoreCase(s, "CREATE")
        or std.ascii.eqlIgnoreCase(s, "MERGE")
        or std.ascii.eqlIgnoreCase(s, "SET")
        or std.ascii.eqlIgnoreCase(s, "DELETE")
        or std.ascii.eqlIgnoreCase(s, "DETACH")
        or std.ascii.eqlIgnoreCase(s, "AS")
        or std.ascii.eqlIgnoreCase(s, "ASC")
        or std.ascii.eqlIgnoreCase(s, "DESC")
        or std.ascii.eqlIgnoreCase(s, "REMOVE")
        or std.ascii.eqlIgnoreCase(s, "UNWIND")
        or std.ascii.eqlIgnoreCase(s, "ORDER")
        or std.ascii.eqlIgnoreCase(s, "BY")
        or std.ascii.eqlIgnoreCase(s, "SKIP")
        or std.ascii.eqlIgnoreCase(s, "LIMIT")
        or std.ascii.eqlIgnoreCase(s, "USING");
}

test "lexer basic punctuation" {
    var lx = Lexer.init("(n)-[r:REL]->(m) RETURN n");
    _ = lx.next(); // (
    _ = lx.next(); // identifier
    _ = lx.next(); // )
    _ = lx.next(); // -
    _ = lx.next(); // [
}


