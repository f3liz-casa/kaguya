use smol_str::SmolStr;

// ============================================================
// Node types
// ============================================================

pub enum Node {
    Text(SmolStr),
    Bold(Vec<Node>),
    Italic(Vec<Node>),
    Strike(Vec<Node>),
    Small(Vec<Node>),
    Center(Vec<Node>),
    Plain(Vec<Node>),
    Quote(Vec<Node>),
    InlineCode(SmolStr),
    BlockCode { code: SmolStr, lang: Option<SmolStr> },
    MathInline(SmolStr),
    MathBlock(SmolStr),
    Mention { username: SmolStr, host: Option<SmolStr> },
    Hashtag(SmolStr),
    Url(SmolStr),
    Link { url: SmolStr, children: Vec<Node>, silent: bool },
    Fn { name: SmolStr, args: Vec<(SmolStr, SmolStr)>, children: Vec<Node> },
    EmojiCode(SmolStr),
    UnicodeEmoji(SmolStr),
    Search(SmolStr),
}

// ============================================================
// Parser
// ============================================================

pub struct Parser<'a> {
    input: &'a str,
    pos: usize,
    nest_limit: u32,
    depth: u32,
}

impl<'a> Parser<'a> {
    pub fn new(input: &'a str, nest_limit: u32) -> Self {
        Parser {
            input,
            pos: 0,
            nest_limit,
            depth: 0,
        }
    }

    // ---- Utility methods ----

    fn remaining(&self) -> &str {
        &self.input[self.pos..]
    }

    fn is_eof(&self) -> bool {
        self.pos >= self.input.len()
    }

    fn starts_with(&self, s: &str) -> bool {
        self.remaining().starts_with(s)
    }

    fn starts_with_ci(&self, s: &str) -> bool {
        let rem = self.remaining().as_bytes();
        let s_bytes = s.as_bytes();
        if rem.len() < s_bytes.len() {
            return false;
        }
        rem[..s_bytes.len()].eq_ignore_ascii_case(s_bytes)
    }

    fn peek_char(&self) -> Option<char> {
        self.remaining().chars().next()
    }

    fn advance(&mut self, n: usize) {
        self.pos = (self.pos + n).min(self.input.len());
    }

    fn advance_char(&mut self) -> Option<char> {
        let c = self.peek_char()?;
        self.pos += c.len_utf8();
        Some(c)
    }

    fn at_line_start(&self) -> bool {
        self.pos == 0
            || (self.pos > 0 && self.input.as_bytes()[self.pos - 1] == b'\n')
    }

    fn save(&self) -> usize {
        self.pos
    }

    fn restore(&mut self, pos: usize) {
        self.pos = pos;
    }

    fn prev_char(&self) -> Option<char> {
        if self.pos == 0 {
            return None;
        }
        self.input[..self.pos].chars().next_back()
    }

    // ---- Main entry points ----

    pub fn parse(&mut self) -> Vec<Node> {
        let mut nodes: Vec<Node> = Vec::new();
        let mut text_start: Option<usize> = None;

        while !self.is_eof() {
            let pos_before = self.pos;

            // Try block-level (only at line start)
            if self.at_line_start() {
                if let Some(node) = self.try_block() {
                    if let Some(start) = text_start.take() {
                        nodes.push(Node::Text(SmolStr::new(&self.input[start..pos_before])));
                    }
                    nodes.push(node);
                    continue;
                }
            }

            // Try inline
            if let Some(node) = self.try_inline() {
                if let Some(start) = text_start.take() {
                    nodes.push(Node::Text(SmolStr::new(&self.input[start..pos_before])));
                }
                nodes.push(node);
                continue;
            }

            // Accumulate text
            if text_start.is_none() {
                text_start = Some(self.pos);
            }
            self.advance_char();
        }

        if let Some(start) = text_start {
            nodes.push(Node::Text(SmolStr::new(&self.input[start..self.pos])));
        }

        nodes
    }

    pub fn parse_simple(&mut self) -> Vec<Node> {
        let mut nodes: Vec<Node> = Vec::new();
        let mut text_start: Option<usize> = None;

        while !self.is_eof() {
            let pos_before = self.pos;

            // Only try emoji patterns in simple mode
            if let Some(node) = self.try_emoji_code().or_else(|| self.try_unicode_emoji()) {
                if let Some(start) = text_start.take() {
                    nodes.push(Node::Text(SmolStr::new(&self.input[start..pos_before])));
                }
                nodes.push(node);
                continue;
            }

            if text_start.is_none() {
                text_start = Some(self.pos);
            }
            self.advance_char();
        }

        if let Some(start) = text_start {
            nodes.push(Node::Text(SmolStr::new(&self.input[start..self.pos])));
        }

        nodes
    }

    // ---- Block-level parsing ----

    fn try_block(&mut self) -> Option<Node> {
        self.try_code_block()
            .or_else(|| self.try_math_block())
            .or_else(|| self.try_center())
            .or_else(|| self.try_quote())
            .or_else(|| self.try_search())
    }

    fn try_code_block(&mut self) -> Option<Node> {
        let save = self.save();

        if !self.starts_with("```") {
            return None;
        }
        self.advance(3);

        // Optional language name
        let lang_start = self.pos;
        while !self.is_eof() && self.peek_char() != Some('\n') {
            self.advance_char();
        }
        let lang_str = self.input[lang_start..self.pos].trim();
        let lang = if lang_str.is_empty() {
            None
        } else {
            Some(SmolStr::new(lang_str))
        };

        // Must have newline after opening
        if self.peek_char() != Some('\n') {
            self.restore(save);
            return None;
        }
        self.advance(1);

        // Find closing ```
        let code_start = self.pos;
        loop {
            if self.is_eof() {
                self.restore(save);
                return None;
            }
            if self.at_line_start() && self.starts_with("```") {
                let code_end = self.pos;
                self.advance(3);
                // Skip trailing newline
                if self.peek_char() == Some('\n') {
                    self.advance(1);
                }
                let mut code = &self.input[code_start..code_end];
                // Remove trailing newline from code content
                if code.ends_with('\n') {
                    code = &code[..code.len() - 1];
                }
                return Some(Node::BlockCode {
                    code: SmolStr::new(code),
                    lang,
                });
            }
            self.advance_char();
        }
    }

    fn try_math_block(&mut self) -> Option<Node> {
        let save = self.save();

        if !self.starts_with("\\[") {
            return None;
        }

        // Check that \[ is the only content on the line (maybe trailing whitespace)
        let after_bracket = self.pos + 2;
        let rest_of_line = &self.input[after_bracket..];
        let line_end = rest_of_line.find('\n');
        let trailing = match line_end {
            Some(i) => &rest_of_line[..i],
            None => rest_of_line,
        };
        if !trailing.trim().is_empty() {
            return None;
        }

        self.advance(2); // skip \[
        // Skip to next line
        if let Some(i) = self.remaining().find('\n') {
            self.advance(i + 1);
        } else {
            self.restore(save);
            return None;
        }

        let formula_start = self.pos;

        // Find closing \]
        loop {
            if self.is_eof() {
                self.restore(save);
                return None;
            }
            if self.at_line_start() && self.starts_with("\\]") {
                let formula_end = self.pos;
                self.advance(2);
                if self.peek_char() == Some('\n') {
                    self.advance(1);
                }
                let mut formula = &self.input[formula_start..formula_end];
                if formula.ends_with('\n') {
                    formula = &formula[..formula.len() - 1];
                }
                return Some(Node::MathBlock(SmolStr::new(formula)));
            }
            self.advance_char();
        }
    }

    fn try_center(&mut self) -> Option<Node> {
        let save = self.save();

        if !self.starts_with_ci("<center>") {
            return None;
        }
        self.advance(8);

        // Skip optional trailing whitespace + newline
        while self.peek_char() == Some(' ') || self.peek_char() == Some('\t') {
            self.advance(1);
        }
        if self.peek_char() == Some('\n') {
            self.advance(1);
        }

        let content_start = self.pos;

        // Find closing </center>
        loop {
            if self.is_eof() {
                self.restore(save);
                return None;
            }
            if self.at_line_start() && self.starts_with_ci("</center>") {
                let content_end = self.pos;
                self.advance(9);
                if self.peek_char() == Some('\n') {
                    self.advance(1);
                }
                let mut content = &self.input[content_start..content_end];
                if content.ends_with('\n') {
                    content = &content[..content.len() - 1];
                }
                let mut inner = Parser::new(content, self.nest_limit);
                inner.depth = self.depth;
                let children = inner.parse();
                return Some(Node::Center(children));
            }
            self.advance_char();
        }
    }

    fn try_quote(&mut self) -> Option<Node> {
        if !self.starts_with(">") {
            return None;
        }

        let save = self.save();
        let mut quote_lines: Vec<&str> = Vec::new();

        // Collect consecutive quoted lines
        while !self.is_eof() && self.at_line_start() {
            if self.starts_with("> ") {
                self.advance(2);
            } else if self.starts_with(">") && self.remaining().len() > 1 {
                let next = self.input.as_bytes().get(self.pos + 1).copied();
                if next == Some(b'\n') {
                    // Empty quote line "> " with just >
                    self.advance(1);
                } else if next != Some(b' ') {
                    // ">text" without space - still valid quote in mfm-js
                    self.advance(1);
                } else {
                    break;
                }
            } else if self.starts_with(">") && self.remaining().len() == 1 {
                self.advance(1);
            } else {
                break;
            }

            let line_start = self.pos;
            while !self.is_eof() && self.peek_char() != Some('\n') {
                self.advance_char();
            }
            quote_lines.push(&self.input[line_start..self.pos]);

            if self.peek_char() == Some('\n') {
                self.advance(1);
            }
        }

        if quote_lines.is_empty() {
            self.restore(save);
            return None;
        }

        let inner = quote_lines.join("\n");
        let mut inner_parser = Parser::new(&inner, self.nest_limit);
        inner_parser.depth = self.depth + 1;
        let children = inner_parser.parse();

        Some(Node::Quote(children))
    }

    fn try_search(&mut self) -> Option<Node> {
        if !self.at_line_start() {
            return None;
        }

        let line_end = self.remaining().find('\n')
            .map(|i| self.pos + i)
            .unwrap_or(self.input.len());
        let line = &self.input[self.pos..line_end];

        let keywords: &[&str] = &[
            " 検索", " [検索]",
            " search", " Search",
            " [search]", " [Search]",
        ];

        for kw in keywords {
            if line.ends_with(kw) {
                let query = &line[..line.len() - kw.len()];
                if !query.is_empty() {
                    self.pos = line_end;
                    if self.peek_char() == Some('\n') {
                        self.advance(1);
                    }
                    return Some(Node::Search(SmolStr::new(query)));
                }
            }
        }

        None
    }

    // ---- Inline-level parsing ----

    fn try_inline(&mut self) -> Option<Node> {
        if self.depth >= self.nest_limit {
            return None;
        }

        let c = self.peek_char()?;

        match c {
            '*' => self.try_bold_asterisk().or_else(|| self.try_italic_asterisk()),
            '_' => self.try_bold_underscore().or_else(|| self.try_italic_underscore()),
            '~' => self.try_strike(),
            '`' => self.try_inline_code(),
            '\\' => self.try_math_inline(),
            '@' => self.try_mention(),
            '#' => self.try_hashtag(),
            'h' => self.try_url(),
            '[' => self.try_link(),
            '?' => self.try_silent_link(),
            '$' => self.try_fn_node(),
            ':' => self.try_emoji_code(),
            '<' => self.try_tag_based(),
            '\n' => None, // newlines are text
            c if is_emoji_char(c) => self.try_unicode_emoji(),
            _ => None,
        }
    }

    fn try_tag_based(&mut self) -> Option<Node> {
        self.try_bold_tag()
            .or_else(|| self.try_italic_tag())
            .or_else(|| self.try_strike_tag())
            .or_else(|| self.try_small_tag())
            .or_else(|| self.try_plain_tag())
    }

    // Parse nested inline content until a closing delimiter
    fn parse_inline_until(&mut self, closing: &str, allow_newlines: bool) -> Option<Vec<Node>> {
        let mut nodes: Vec<Node> = Vec::new();
        let mut text_start: Option<usize> = None;

        while !self.is_eof() {
            // Check closing delimiter first
            if self.starts_with(closing) {
                if let Some(start) = text_start.take() {
                    nodes.push(Node::Text(SmolStr::new(&self.input[start..self.pos])));
                }
                self.advance(closing.len());
                return Some(nodes);
            }

            if !allow_newlines && self.peek_char() == Some('\n') {
                break;
            }

            let pos_before = self.pos;

            // Try inline patterns recursively
            if self.depth < self.nest_limit {
                if let Some(node) = self.try_inline() {
                    if let Some(start) = text_start.take() {
                        nodes.push(Node::Text(SmolStr::new(&self.input[start..pos_before])));
                    }
                    nodes.push(node);
                    continue;
                }
            }

            if text_start.is_none() {
                text_start = Some(self.pos);
            }
            self.advance_char();
        }

        // Reached EOF or newline without finding closing - fail
        None
    }

    // Case-insensitive version for HTML tags
    fn parse_inline_until_ci(&mut self, closing: &str) -> Option<Vec<Node>> {
        let mut nodes: Vec<Node> = Vec::new();
        let mut text_start: Option<usize> = None;

        while !self.is_eof() {
            if self.starts_with_ci(closing) {
                if let Some(start) = text_start.take() {
                    nodes.push(Node::Text(SmolStr::new(&self.input[start..self.pos])));
                }
                self.advance(closing.len());
                return Some(nodes);
            }

            let pos_before = self.pos;

            if self.depth < self.nest_limit {
                if let Some(node) = self.try_inline() {
                    if let Some(start) = text_start.take() {
                        nodes.push(Node::Text(SmolStr::new(&self.input[start..pos_before])));
                    }
                    nodes.push(node);
                    continue;
                }
            }

            if text_start.is_none() {
                text_start = Some(self.pos);
            }
            self.advance_char();
        }

        None
    }

    // ---- Bold ----

    fn try_bold_asterisk(&mut self) -> Option<Node> {
        if !self.starts_with("**") {
            return None;
        }
        let save = self.save();
        self.advance(2);
        self.depth += 1;
        let result = self.parse_inline_until("**", true);
        self.depth -= 1;
        match result {
            Some(children) if !children.is_empty() => Some(Node::Bold(children)),
            _ => {
                self.restore(save);
                None
            }
        }
    }

    fn try_bold_underscore(&mut self) -> Option<Node> {
        if !self.starts_with("__") {
            return None;
        }
        let save = self.save();
        self.advance(2);
        self.depth += 1;
        let result = self.parse_inline_until("__", true);
        self.depth -= 1;
        match result {
            Some(children) if !children.is_empty() => Some(Node::Bold(children)),
            _ => {
                self.restore(save);
                None
            }
        }
    }

    fn try_bold_tag(&mut self) -> Option<Node> {
        if !self.starts_with_ci("<b>") {
            return None;
        }
        let save = self.save();
        self.advance(3);
        self.depth += 1;
        let result = self.parse_inline_until_ci("</b>");
        self.depth -= 1;
        match result {
            Some(children) if !children.is_empty() => Some(Node::Bold(children)),
            _ => {
                self.restore(save);
                None
            }
        }
    }

    // ---- Italic ----

    fn try_italic_tag(&mut self) -> Option<Node> {
        if !self.starts_with_ci("<i>") {
            return None;
        }
        let save = self.save();
        self.advance(3);
        self.depth += 1;
        let result = self.parse_inline_until_ci("</i>");
        self.depth -= 1;
        match result {
            Some(children) if !children.is_empty() => Some(Node::Italic(children)),
            _ => {
                self.restore(save);
                None
            }
        }
    }

    fn try_italic_asterisk(&mut self) -> Option<Node> {
        // Must be single * (not **)
        if self.starts_with("**") {
            return None;
        }
        if !self.starts_with("*") {
            return None;
        }
        let save = self.save();
        self.advance(1);

        // Content until closing *
        let content_start = self.pos;
        let mut found_close = false;
        while !self.is_eof() && self.peek_char() != Some('\n') {
            if self.starts_with("*") && !self.starts_with("**") && self.pos > content_start {
                found_close = true;
                break;
            }
            self.advance_char();
        }

        if !found_close || self.pos == content_start {
            self.restore(save);
            return None;
        }

        let content = &self.input[content_start..self.pos];
        self.advance(1); // skip closing *

        // Parse content inline
        let mut inner = Parser::new(content, self.nest_limit);
        inner.depth = self.depth + 1;
        let children = inner.parse();

        if children.is_empty() {
            self.restore(save);
            return None;
        }

        Some(Node::Italic(children))
    }

    fn try_italic_underscore(&mut self) -> Option<Node> {
        // Must be single _ (not __)
        if self.starts_with("__") {
            return None;
        }
        if !self.starts_with("_") {
            return None;
        }
        let save = self.save();
        self.advance(1);

        let content_start = self.pos;
        let mut found_close = false;
        while !self.is_eof() && self.peek_char() != Some('\n') {
            if self.starts_with("_") && !self.starts_with("__") && self.pos > content_start {
                found_close = true;
                break;
            }
            self.advance_char();
        }

        if !found_close || self.pos == content_start {
            self.restore(save);
            return None;
        }

        let content = &self.input[content_start..self.pos];
        self.advance(1);

        let mut inner = Parser::new(content, self.nest_limit);
        inner.depth = self.depth + 1;
        let children = inner.parse();

        if children.is_empty() {
            self.restore(save);
            return None;
        }

        Some(Node::Italic(children))
    }

    // ---- Strike ----

    fn try_strike(&mut self) -> Option<Node> {
        if !self.starts_with("~~") {
            return None;
        }
        let save = self.save();
        self.advance(2);
        self.depth += 1;
        let result = self.parse_inline_until("~~", true);
        self.depth -= 1;
        match result {
            Some(children) if !children.is_empty() => Some(Node::Strike(children)),
            _ => {
                self.restore(save);
                None
            }
        }
    }

    fn try_strike_tag(&mut self) -> Option<Node> {
        if !self.starts_with_ci("<s>") {
            return None;
        }
        let save = self.save();
        self.advance(3);
        self.depth += 1;
        let result = self.parse_inline_until_ci("</s>");
        self.depth -= 1;
        match result {
            Some(children) if !children.is_empty() => Some(Node::Strike(children)),
            _ => {
                self.restore(save);
                None
            }
        }
    }

    // ---- Small ----

    fn try_small_tag(&mut self) -> Option<Node> {
        if !self.starts_with_ci("<small>") {
            return None;
        }
        let save = self.save();
        self.advance(7);
        self.depth += 1;
        let result = self.parse_inline_until_ci("</small>");
        self.depth -= 1;
        match result {
            Some(children) if !children.is_empty() => Some(Node::Small(children)),
            _ => {
                self.restore(save);
                None
            }
        }
    }

    // ---- Plain ----

    fn try_plain_tag(&mut self) -> Option<Node> {
        if !self.starts_with_ci("<plain>") {
            return None;
        }
        let save = self.save();
        self.advance(7);

        // Find closing </plain> - content is NOT parsed
        let content_start = self.pos;
        loop {
            if self.is_eof() {
                self.restore(save);
                return None;
            }
            if self.starts_with_ci("</plain>") {
                let content = &self.input[content_start..self.pos];
                self.advance(8);
                let children = vec![Node::Text(SmolStr::new(content))];
                return Some(Node::Plain(children));
            }
            self.advance_char();
        }
    }

    // ---- Inline code ----

    fn try_inline_code(&mut self) -> Option<Node> {
        if !self.starts_with("`") || self.starts_with("```") {
            return None;
        }
        let save = self.save();
        self.advance(1);

        let code_start = self.pos;
        while !self.is_eof() {
            match self.peek_char() {
                Some('`') => {
                    let code = &self.input[code_start..self.pos];
                    self.advance(1);
                    if code.is_empty() {
                        self.restore(save);
                        return None;
                    }
                    return Some(Node::InlineCode(SmolStr::new(code)));
                }
                Some('\n') => {
                    self.restore(save);
                    return None;
                }
                _ => {
                    self.advance_char();
                }
            }
        }

        self.restore(save);
        None
    }

    // ---- Math inline ----

    fn try_math_inline(&mut self) -> Option<Node> {
        if !self.starts_with("\\(") {
            return None;
        }
        let save = self.save();
        self.advance(2);

        let formula_start = self.pos;
        loop {
            if self.is_eof() {
                self.restore(save);
                return None;
            }
            if self.starts_with("\\)") {
                let formula = &self.input[formula_start..self.pos];
                self.advance(2);
                if formula.is_empty() {
                    self.restore(save);
                    return None;
                }
                return Some(Node::MathInline(SmolStr::new(formula)));
            }
            if self.peek_char() == Some('\n') {
                self.restore(save);
                return None;
            }
            self.advance_char();
        }
    }

    // ---- Mention ----

    fn try_mention(&mut self) -> Option<Node> {
        if !self.starts_with("@") {
            return None;
        }

        // Must be preceded by whitespace, newline, or start of input
        if let Some(prev) = self.prev_char() {
            if !prev.is_whitespace() && prev != '(' && prev != '[' {
                return None;
            }
        }

        let save = self.save();
        self.advance(1); // skip @

        // Parse username: [a-zA-Z0-9_-]
        let user_start = self.pos;
        while !self.is_eof() {
            match self.peek_char() {
                Some(c) if c.is_ascii_alphanumeric() || c == '_' || c == '-' => {
                    self.advance(1);
                }
                _ => break,
            }
        }
        let username = &self.input[user_start..self.pos];
        if username.is_empty() {
            self.restore(save);
            return None;
        }

        // Optionally parse @host
        let host = if self.starts_with("@") {
            self.advance(1);
            let host_start = self.pos;
            while !self.is_eof() {
                match self.peek_char() {
                    Some(c) if c.is_ascii_alphanumeric() || c == '-' || c == '.' => {
                        self.advance(1);
                    }
                    _ => break,
                }
            }
            let h = &self.input[host_start..self.pos];
            if h.is_empty() || !h.contains('.') {
                // Invalid host, backtrack to just username
                self.pos = user_start + username.len();
                None
            } else {
                Some(SmolStr::new(h))
            }
        } else {
            None
        };

        Some(Node::Mention {
            username: SmolStr::new(username),
            host,
        })
    }

    // ---- Hashtag ----

    fn try_hashtag(&mut self) -> Option<Node> {
        if !self.starts_with("#") {
            return None;
        }

        // Must be preceded by whitespace, newline, or start of input
        if let Some(prev) = self.prev_char() {
            if !prev.is_whitespace() {
                return None;
            }
        }

        let save = self.save();
        self.advance(1); // skip #

        let tag_start = self.pos;
        let mut paren_depth: i32 = 0;
        let mut bracket_depth: i32 = 0;

        while !self.is_eof() {
            let c = self.peek_char().unwrap();
            match c {
                ' ' | '\t' | '\n' | '\r' => break,
                '(' => { paren_depth += 1; self.advance_char(); }
                ')' => {
                    if paren_depth > 0 {
                        paren_depth -= 1;
                        self.advance_char();
                    } else {
                        break;
                    }
                }
                '[' => { bracket_depth += 1; self.advance_char(); }
                ']' => {
                    if bracket_depth > 0 {
                        bracket_depth -= 1;
                        self.advance_char();
                    } else {
                        break;
                    }
                }
                '.' | ',' | '!' | '?' | ':' | ';' => {
                    // Check if this is trailing punctuation (next char is space/eof)
                    let next_pos = self.pos + c.len_utf8();
                    if next_pos >= self.input.len()
                        || self.input[next_pos..].starts_with(|nc: char| nc.is_whitespace())
                    {
                        break;
                    }
                    self.advance_char();
                }
                _ => { self.advance_char(); }
            }
        }

        let tag = &self.input[tag_start..self.pos];
        if tag.is_empty() {
            self.restore(save);
            return None;
        }

        Some(Node::Hashtag(SmolStr::new(tag)))
    }

    // ---- URL ----

    fn try_url(&mut self) -> Option<Node> {
        let scheme = if self.starts_with("https://") {
            "https://"
        } else if self.starts_with("http://") {
            "http://"
        } else {
            return None;
        };

        let save = self.save();
        let url_start = self.pos;
        self.advance(scheme.len());

        // URL must have at least one char after scheme
        if self.is_eof() || self.peek_char().map_or(true, |c| c.is_whitespace()) {
            self.restore(save);
            return None;
        }

        let mut paren_depth: i32 = 0;

        while !self.is_eof() {
            let c = self.peek_char().unwrap();
            match c {
                ' ' | '\t' | '\n' | '\r' => break,
                '(' => {
                    paren_depth += 1;
                    self.advance_char();
                }
                ')' => {
                    if paren_depth > 0 {
                        paren_depth -= 1;
                        self.advance_char();
                    } else {
                        break;
                    }
                }
                _ => {
                    self.advance_char();
                }
            }
        }

        // Trim trailing punctuation
        while self.pos > url_start + scheme.len() {
            let prev = self.input[..self.pos].chars().next_back().unwrap();
            match prev {
                '.' | ',' | ';' | ':' | '!' | '?' | '\'' | '"' => {
                    self.pos -= prev.len_utf8();
                }
                _ => break,
            }
        }

        if self.pos <= url_start + scheme.len() {
            self.restore(save);
            return None;
        }

        let url = SmolStr::new(&self.input[url_start..self.pos]);
        Some(Node::Url(url))
    }

    // ---- Link ----

    fn try_link(&mut self) -> Option<Node> {
        self.parse_link(false)
    }

    fn try_silent_link(&mut self) -> Option<Node> {
        if !self.starts_with("?[") {
            return None;
        }
        let save = self.save();
        self.advance(1); // skip ?
        match self.parse_link(true) {
            Some(node) => Some(node),
            None => {
                self.restore(save);
                None
            }
        }
    }

    fn parse_link(&mut self, silent: bool) -> Option<Node> {
        if !self.starts_with("[") {
            return None;
        }
        let save = self.save();
        self.advance(1); // skip [

        // Parse link text until ]
        self.depth += 1;
        let children_result = self.parse_inline_until("]", true);
        self.depth -= 1;

        let children = match children_result {
            Some(c) if !c.is_empty() => c,
            _ => {
                self.restore(save);
                return None;
            }
        };

        // Must be followed by (url)
        if !self.starts_with("(") {
            self.restore(save);
            return None;
        }
        self.advance(1);

        // Parse URL until )
        let url_start = self.pos;
        let mut paren_depth: i32 = 0;
        loop {
            if self.is_eof() {
                self.restore(save);
                return None;
            }
            match self.peek_char().unwrap() {
                ')' if paren_depth == 0 => {
                    let url = SmolStr::new(&self.input[url_start..self.pos]);
                    self.advance(1);
                    return Some(Node::Link {
                        url,
                        children,
                        silent,
                    });
                }
                '(' => {
                    paren_depth += 1;
                    self.advance(1);
                }
                ')' => {
                    paren_depth -= 1;
                    self.advance(1);
                }
                '\n' => {
                    self.restore(save);
                    return None;
                }
                _ => {
                    self.advance_char();
                }
            }
        }
    }

    // ---- Fn ----

    fn try_fn_node(&mut self) -> Option<Node> {
        if !self.starts_with("$[") {
            return None;
        }
        let save = self.save();
        self.advance(2); // skip $[

        // Parse function name
        let name_start = self.pos;
        while !self.is_eof() {
            match self.peek_char() {
                Some(c) if c.is_ascii_alphanumeric() || c == '_' => self.advance(1),
                _ => break,
            }
        }
        let name = &self.input[name_start..self.pos];
        if name.is_empty() {
            self.restore(save);
            return None;
        }

        // Parse optional args: .key=val,key=val
        let mut args: Vec<(SmolStr, SmolStr)> = Vec::new();
        if self.starts_with(".") {
            self.advance(1);
            loop {
                let key_start = self.pos;
                while !self.is_eof() {
                    match self.peek_char() {
                        Some(c) if c.is_ascii_alphanumeric() || c == '_' => self.advance(1),
                        _ => break,
                    }
                }
                let key = &self.input[key_start..self.pos];
                if key.is_empty() {
                    break;
                }

                let val = if self.starts_with("=") {
                    self.advance(1);
                    let val_start = self.pos;
                    while !self.is_eof() {
                        match self.peek_char() {
                            Some(c) if c != ',' && c != ' ' && c != ']' => { self.advance_char(); }
                            _ => break,
                        }
                    }
                    SmolStr::new(&self.input[val_start..self.pos])
                } else {
                    SmolStr::new("")
                };

                args.push((SmolStr::new(key), val));

                if self.starts_with(",") {
                    self.advance(1);
                } else {
                    break;
                }
            }
        }

        // Must have space before content
        if self.peek_char() != Some(' ') {
            self.restore(save);
            return None;
        }
        self.advance(1);

        // Parse content until ]
        self.depth += 1;
        let result = self.parse_inline_until("]", true);
        self.depth -= 1;

        match result {
            Some(children) => Some(Node::Fn {
                name: SmolStr::new(name),
                args,
                children,
            }),
            None => {
                self.restore(save);
                None
            }
        }
    }

    // ---- Emoji code ----

    fn try_emoji_code(&mut self) -> Option<Node> {
        if !self.starts_with(":") {
            return None;
        }
        let save = self.save();
        self.advance(1);

        let name_start = self.pos;
        while !self.is_eof() {
            match self.peek_char() {
                Some(c) if c.is_ascii_alphanumeric() || c == '_' || c == '-' || c == '+' || c == '.' => {
                    self.advance(1);
                }
                _ => break,
            }
        }

        let name = &self.input[name_start..self.pos];
        if name.is_empty() || !self.starts_with(":") {
            self.restore(save);
            return None;
        }
        self.advance(1); // skip closing :

        Some(Node::EmojiCode(SmolStr::new(name)))
    }

    // ---- Unicode emoji ----

    fn try_unicode_emoji(&mut self) -> Option<Node> {
        let c = self.peek_char()?;
        if !is_emoji_char(c) {
            return None;
        }

        let start = self.pos;
        self.advance_char();

        // Consume modifiers, variation selectors, ZWJ sequences
        loop {
            match self.peek_char() {
                Some(c) if is_emoji_modifier(c) => {
                    self.advance_char();
                }
                Some('\u{200D}') => {
                    // ZWJ
                    self.advance_char();
                    if let Some(c) = self.peek_char() {
                        if is_emoji_char(c) || is_emoji_modifier(c) {
                            self.advance_char();
                        }
                    }
                }
                Some('\u{FE0F}') | Some('\u{FE0E}') => {
                    // Variation selectors
                    self.advance_char();
                }
                _ => break,
            }
        }

        Some(Node::UnicodeEmoji(SmolStr::new(
            &self.input[start..self.pos],
        )))
    }
}

// ============================================================
// Emoji detection helpers
// ============================================================

fn is_emoji_char(c: char) -> bool {
    let cp = c as u32;
    matches!(
        cp,
        0x00A9 | 0x00AE
        | 0x203C | 0x2049
        | 0x2122 | 0x2139
        | 0x2194..=0x2199
        | 0x21A9..=0x21AA
        | 0x231A..=0x231B
        | 0x2328 | 0x23CF
        | 0x23E9..=0x23F3
        | 0x23F8..=0x23FA
        | 0x24C2
        | 0x25AA..=0x25AB
        | 0x25B6 | 0x25C0
        | 0x25FB..=0x25FE
        | 0x2600..=0x27BF
        | 0x2934..=0x2935
        | 0x2B05..=0x2B07
        | 0x2B1B..=0x2B1C
        | 0x2B50 | 0x2B55
        | 0x3030 | 0x303D
        | 0x3297 | 0x3299
        | 0x1F000..=0x1F02F
        | 0x1F0A0..=0x1F0FF
        | 0x1F100..=0x1F64F
        | 0x1F680..=0x1F6FF
        | 0x1F700..=0x1F77F
        | 0x1F780..=0x1F7FF
        | 0x1F800..=0x1F8FF
        | 0x1F900..=0x1F9FF
        | 0x1FA00..=0x1FA6F
        | 0x1FA70..=0x1FAFF
    )
}

fn is_emoji_modifier(c: char) -> bool {
    let cp = c as u32;
    matches!(
        cp,
        0xFE00..=0xFE0F         // Variation selectors
        | 0x1F3FB..=0x1F3FF     // Skin tone modifiers
        | 0x20E3                // Combining enclosing keycap
        | 0xE0020..=0xE007F     // Tags
        | 0x200D                // ZWJ
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    fn parse(input: &str) -> Vec<Node> {
        Parser::new(input, 20).parse()
    }

    fn parse_simple(input: &str) -> Vec<Node> {
        Parser::new(input, 20).parse_simple()
    }

    fn is_text(node: &Node, expected: &str) -> bool {
        matches!(node, Node::Text(s) if s.as_str() == expected)
    }

    // Basic text
    #[test]
    fn test_empty() { assert!(parse("").is_empty()); }

    #[test]
    fn test_plain_text() {
        let r = parse("hello world");
        assert_eq!(r.len(), 1);
        assert!(is_text(&r[0], "hello world"));
    }

    #[test]
    fn test_newline() {
        let r = parse("a\nb");
        assert_eq!(r.len(), 1);
        assert!(is_text(&r[0], "a\nb"));
    }

    // Bold
    #[test]
    fn test_bold() {
        let r = parse("**bold**");
        assert_eq!(r.len(), 1);
        assert!(matches!(&r[0], Node::Bold(c) if c.len() == 1 && is_text(&c[0], "bold")));
    }

    #[test]
    fn test_bold_underscore() {
        let r = parse("__bold__");
        assert_eq!(r.len(), 1);
        assert!(matches!(&r[0], Node::Bold(_)));
    }

    #[test]
    fn test_unclosed_bold() {
        let r = parse("**unclosed");
        assert_eq!(r.len(), 1);
        assert!(is_text(&r[0], "**unclosed"));
    }

    // Italic
    #[test]
    fn test_italic_asterisk() {
        let r = parse("*italic*");
        assert_eq!(r.len(), 1);
        assert!(matches!(&r[0], Node::Italic(_)));
    }

    #[test]
    fn test_italic_tag() {
        let r = parse("<i>italic</i>");
        assert_eq!(r.len(), 1);
        assert!(matches!(&r[0], Node::Italic(_)));
    }

    // Strike
    #[test]
    fn test_strike() {
        let r = parse("~~strike~~");
        assert_eq!(r.len(), 1);
        assert!(matches!(&r[0], Node::Strike(_)));
    }

    // Inline code
    #[test]
    fn test_inline_code() {
        let r = parse("`code`");
        assert_eq!(r.len(), 1);
        assert!(matches!(&r[0], Node::InlineCode(s) if s.as_str() == "code"));
    }

    #[test]
    fn test_inline_code_no_newline() {
        let r = parse("`code\nnext`");
        // Should fail to parse as inline code
        assert!(!matches!(r.first(), Some(Node::InlineCode(_))));
    }

    // Block code
    #[test]
    fn test_block_code() {
        let r = parse("```js\nconsole.log('hi')\n```");
        assert_eq!(r.len(), 1);
        assert!(matches!(&r[0], Node::BlockCode { code, lang } 
            if code.as_str() == "console.log('hi')" && lang.as_deref() == Some("js")));
    }

    #[test]
    fn test_block_code_no_lang() {
        let r = parse("```\ncode\n```");
        assert_eq!(r.len(), 1);
        assert!(matches!(&r[0], Node::BlockCode { lang, .. } if lang.is_none()));
    }

    // Mention
    #[test]
    fn test_mention_simple() {
        let r = parse("@user");
        assert_eq!(r.len(), 1);
        assert!(matches!(&r[0], Node::Mention { username, host } 
            if username.as_str() == "user" && host.is_none()));
    }

    #[test]
    fn test_mention_with_host() {
        let r = parse("@user@example.com");
        assert_eq!(r.len(), 1);
        assert!(matches!(&r[0], Node::Mention { username, host }
            if username.as_str() == "user" && host.as_deref() == Some("example.com")));
    }

    #[test]
    fn test_mention_not_in_word() {
        let r = parse("hello@user");
        // @ preceded by non-whitespace should not be a mention
        assert_eq!(r.len(), 1);
        assert!(is_text(&r[0], "hello@user"));
    }

    // Hashtag
    #[test]
    fn test_hashtag() {
        let r = parse("#tag");
        assert_eq!(r.len(), 1);
        assert!(matches!(&r[0], Node::Hashtag(s) if s.as_str() == "tag"));
    }

    // URL
    #[test]
    fn test_url() {
        let r = parse("https://example.com");
        assert_eq!(r.len(), 1);
        assert!(matches!(&r[0], Node::Url(s) if s.as_str() == "https://example.com"));
    }

    #[test]
    fn test_url_with_trailing_period() {
        let r = parse("https://example.com.");
        assert_eq!(r.len(), 2);
        assert!(matches!(&r[0], Node::Url(s) if s.as_str() == "https://example.com"));
    }

    #[test]
    fn test_url_scheme_only() {
        let r = parse("https://");
        assert_eq!(r.len(), 1);
        assert!(is_text(&r[0], "https://"));
    }

    // Link
    #[test]
    fn test_link() {
        let r = parse("[text](https://example.com)");
        assert_eq!(r.len(), 1);
        assert!(matches!(&r[0], Node::Link { url, silent, .. } 
            if url.as_str() == "https://example.com" && !*silent));
    }

    #[test]
    fn test_silent_link() {
        let r = parse("?[text](https://example.com)");
        assert_eq!(r.len(), 1);
        assert!(matches!(&r[0], Node::Link { silent, .. } if *silent));
    }

    // Emoji
    #[test]
    fn test_emoji_code() {
        let r = parse(":smile:");
        assert_eq!(r.len(), 1);
        assert!(matches!(&r[0], Node::EmojiCode(s) if s.as_str() == "smile"));
    }

    #[test]
    fn test_unclosed_emoji() {
        let r = parse(":notclosed");
        assert_eq!(r.len(), 1);
        assert!(is_text(&r[0], ":notclosed"));
    }

    #[test]
    fn test_unicode_emoji() {
        let r = parse("🎉");
        assert_eq!(r.len(), 1);
        assert!(matches!(&r[0], Node::UnicodeEmoji(s) if s.as_str() == "🎉"));
    }

    // Quote
    #[test]
    fn test_quote() {
        let r = parse("> quoted text");
        assert_eq!(r.len(), 1);
        assert!(matches!(&r[0], Node::Quote(_)));
    }

    // Math
    #[test]
    fn test_math_inline() {
        let r = parse("\\(x^2\\)");
        assert_eq!(r.len(), 1);
        assert!(matches!(&r[0], Node::MathInline(s) if s.as_str() == "x^2"));
    }

    // Fn
    #[test]
    fn test_fn() {
        let r = parse("$[spin text]");
        assert_eq!(r.len(), 1);
        assert!(matches!(&r[0], Node::Fn { name, .. } if name.as_str() == "spin"));
    }

    #[test]
    fn test_fn_with_args() {
        let r = parse("$[spin.speed=0.5s text]");
        assert_eq!(r.len(), 1);
        assert!(matches!(&r[0], Node::Fn { name, args, .. }
            if name.as_str() == "spin" && args.len() == 1));
    }

    // Search
    #[test]
    fn test_search() {
        let r = parse("keyword 検索");
        assert_eq!(r.len(), 1);
        assert!(matches!(&r[0], Node::Search(s) if s.as_str() == "keyword"));
    }

    // Simple mode
    #[test]
    fn test_simple_text() {
        let r = parse_simple("hello");
        assert_eq!(r.len(), 1);
        assert!(is_text(&r[0], "hello"));
    }

    #[test]
    fn test_simple_emoji() {
        let r = parse_simple(":cat:");
        assert_eq!(r.len(), 1);
        assert!(matches!(&r[0], Node::EmojiCode(s) if s.as_str() == "cat"));
    }

    #[test]
    fn test_simple_ignores_bold() {
        let r = parse_simple("**bold**");
        assert_eq!(r.len(), 1);
        assert!(is_text(&r[0], "**bold**"));
    }

    // Edge cases / stress tests
    #[test]
    fn test_mixed_content() {
        let _ = parse("Hello **world** @user https://x.com :emoji: #tag");
    }

    #[test]
    fn test_deeply_nested() {
        let _ = parse("**bold ~~strike *italic* strike~~ bold**");
    }

    #[test]
    fn test_cjk_text() {
        let _ = parse("こんにちは世界 **太字** @ユーザー");
    }

    #[test]
    fn test_many_emoji() {
        let _ = parse("🎉🎊🎈🎁🎂🎄🎃🎆🎇✨");
    }

    #[test]
    fn test_complex_url() {
        let _ = parse("https://example.com/path?q=1&b=2#frag");
    }

    #[test]
    fn test_url_with_parens() {
        let _ = parse("https://en.wikipedia.org/wiki/Rust_(programming_language)");
    }

    #[test]
    fn test_unclosed_everything() {
        let _ = parse("** ~~ ` $[ :abc <i> <b> <s> <small> <plain>");
    }

    #[test]
    fn test_only_special_chars() {
        let _ = parse("* _ ~ ` \\ @ # : < $ ? [");
    }

    #[test]
    fn test_consecutive_mentions() {
        let _ = parse("@a@b.com @c@d.com @e");
    }

    #[test]
    fn test_mention_without_dot() {
        let _ = parse("@user@nodot");
    }

    #[test]
    fn test_empty_bold() {
        let _ = parse("****");
    }

    #[test]
    fn test_nested_same_delimiter() {
        let _ = parse("**bold **nested** bold**");
    }

    #[test]
    fn test_code_block_unclosed() {
        let _ = parse("```\ncode without closing");
    }

    #[test]
    fn test_math_block() {
        let _ = parse("\\[\nx^2 + y^2\n\\]");
    }

    #[test]
    fn test_center() {
        let _ = parse("<center>\ncentered\n</center>");
    }

    #[test]
    fn test_plain() {
        let _ = parse("<plain>**not bold**</plain>");
    }

    #[test]
    fn test_small() {
        let _ = parse("<small>small text</small>");
    }

    #[test]
    fn test_link_with_nested_formatting() {
        let _ = parse("[**bold link**](https://x.com)");
    }

    #[test]
    fn test_multiline_quote() {
        let _ = parse("> line1\n> line2\n> line3");
    }

    #[test]
    fn test_bare_greater_than() {
        let _ = parse(">");
    }

    #[test]
    fn test_gt_no_space() {
        let _ = parse(">text");
    }

    #[test]
    fn test_fn_unclosed() {
        let _ = parse("$[spin unclosed");
    }

    #[test]
    fn test_fn_no_space() {
        let _ = parse("$[spin]");
    }

    #[test]
    fn test_hashtag_trailing_punct() {
        let _ = parse("#tag.");
    }

    #[test]
    fn test_emoji_zwj() {
        let _ = parse("👨‍👩‍👧‍👦");
    }

    #[test]
    fn test_variation_selector() {
        let _ = parse("❤️");
    }

    #[test]
    fn test_backslash_not_math() {
        let _ = parse("\\n \\t \\\\");
    }

    #[test]
    fn test_dollar_not_fn() {
        let _ = parse("$100 $[");
    }

    #[test]
    fn test_question_not_link() {
        let _ = parse("? ?text ?[no](close");
    }

    #[test]
    fn test_bracket_not_link() {
        let _ = parse("[text] [text](");
    }

    #[test]
    fn test_colon_not_emoji() {
        let _ = parse(": :: ::: :a");
    }

    #[test]
    fn test_at_not_mention() {
        let _ = parse("@ @@ email@test hello@ @");
    }

    #[test]
    fn test_hash_not_tag() {
        let _ = parse("# ## abc# 1#2");
    }

    #[test]
    fn test_long_text() {
        let input = "a".repeat(10000);
        let _ = parse(&input);
    }

    #[test]
    fn test_many_newlines() {
        let input = "\n".repeat(1000);
        let _ = parse(&input);
    }

    #[test]
    fn test_null_bytes() {
        let _ = parse("hello\0world");
    }

    #[test]
    fn test_surrogate_like() {
        let _ = parse("abc\u{FFFD}def");
    }

    #[test]
    fn test_mixed_scripts() {
        let _ = parse("English 日本語 한국어 العربية Русский");
    }

    #[test]
    fn test_real_misskey_note() {
        let _ = parse("今日は天気がいいですね :blobcat: @admin@misskey.io #ミスキー\nhttps://misskey.io\n**太字** *斜体*\n$[sparkle ✨]");
    }

    #[test]
    fn test_simple_real_name() {
        let _ = parse_simple("にゃんるす:blobcat_melt:");
    }

    #[test]
    fn test_search_english() {
        let _ = parse("rust programming search");
    }

    #[test]
    fn test_search_bracket() {
        let _ = parse("keyword [検索]");
    }

    #[test]
    fn test_fn_multiple_args() {
        let _ = parse("$[flip.h,v text]");
    }
}
