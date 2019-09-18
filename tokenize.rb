module TokenKind
  RESERVED = "RESERVED"
  IDENT    = "IDENT"
  STR      = "STR"
  NUM      = "NUM"
  EOF      = "EOF"
end

class Token
  attr_accessor :kind, :next, :val, :str, :len,
                :contents, :cont_len,
                :cur

  def initialize
    @kind = nil
    @next = nil
    @val  = nil
    @str  = nil
    @len  = nil

    @contents = nil # String literal contents including terminating "\0"
    @cont_len = nil # String literal length

    @cur  = nil
  end
end

def strndup(p, len)
  p.dup
end

def peek(s)
  if $token.kind != TokenKind::RESERVED \
    || s.length != $token.len \
    || $token.str != s
    return nil
  end
  return $token
end

def consume?(s)
  if !peek(s)
    return nil
  end
  t = $token
  $token = $token.next
  return t
end

def consume_ident
  if $token.kind != TokenKind::IDENT
    return nil
  end
  t = $token
  $token = $token.next
  return t
end

def expect(s)
  if !peek(s)
    error_at("expected \"#{s}\"")
  end
  $token = $token.next
end

def expect_number
  if $token.kind != TokenKind::NUM
    error_at("expected a number")
  end
  val = $token.val
  $token = $token.next
  return val
end

def expect_ident
  if $token.kind != TokenKind::IDENT
    error_at("expected an identifier")
  end
  s = strndup($token.str, $token.len)
  $token = $token.next
  return s
end

def at_eof
  return $token.kind == TokenKind::EOF
end

def new_token(kind, cur, str, len)
  tok = Token.new
  tok.kind = kind
  tok.str = str
  tok.len = len
  tok.cur = $user_input_cur
  cur.next = tok
  return tok
end

def starts_with_keyword(p)
  kw = ["return", "if", "else", "while", "for", "int", "char", "sizeof"]

  kw.length.times{|i|
    len = kw[i].length
    if startswith(p, kw[i]) && !alnum?(p[len])
      return kw[i]
    end
  }

  ops = ["==", "!=", "<=", ">="]

  ops.length.times{|i|
    if startswith(p, ops[i])
      return ops[i]
    end
  }

  return nil
end

def get_escape_char(c)
  case c
  when "a" then
    return "\a"
  when "b" then
    return "\b"
  when "t" then
    return "\t"
  when "n" then
    return "\n"
  when "v" then
    return "\v"
  when "f" then
    return "\f"
  when "r" then
    return "\r"
  when "e" then
    return "27"
  else
    return c
  end
end

def read_string_literal(cur, p)
  next_cur(p)
  str = ""
  while p[0] && p[0] != '"'
    str += if p[0] == "\\"
      next_cur(p)
      s = next_cur(p)
      get_escape_char(s)
    else
      next_cur(p)
    end
    if str.length == 1024
      error("string literal too large")
    end
  end
  str += "\0"
  next_cur(p)
  if !p[0]
    error("unclosed string literal")
  end
  cur = new_token(TokenKind::STR, cur, str, str.length)
  cur.contents = str
  cur.cont_len = str.length
  return cur
end

def tokenize()
  p = $user_input.dup
  head = Token.new
  cur = head

  while p.length != 0
    if p[0] == " "
      next_cur(p)
      next
    end

    if startswith(p, "//")
      p.slice!(0, 2)
      while !startswith(p, "\n")
        p.slice!(0)
      end
    end

    if startswith(p, "/*")
      p.slice!(0, 2)
      while !startswith(p, "*/")
        p.slice!(0)
      end
      p.slice!(0, 2)
    end

    kw = starts_with_keyword(p)
    if kw
      len = kw.length
      str = n_next_cur(p, len)
      cur = new_token(TokenKind::RESERVED, cur, str, len)
      next
    end

    if ["+", "-", "*", "/",
        "(", ")", "<", ">", ";", "=",
        "{", "}", ",", "&", "[", "]"].include?(p[0])
      cur = new_token(TokenKind::RESERVED, cur, next_cur(p), 1)
      next
    end

    if alpha?(p[0])
      str = ""
      while alnum?(p[0])
        str += next_cur(p)
      end
      cur = new_token(TokenKind::IDENT, cur, str, str.length)
      next
    end

    if p[0] == '"'
      cur = read_string_literal(cur, p)
      next
    end

    if int?(p[0])
      q = p.dup
      num = ""
      while int?(p[0])
        num += next_cur(p)
      end
      cur = new_token(TokenKind::NUM, cur, num, 0)
      cur.val = num.to_i
      cur.len = q.length - p.length
      next
    end

    if p[0] = "\n"
      p.slice!(0)
      next
    end

    error_at("invalid token")
  end

  new_token(TokenKind::EOF, cur, "\0", 0)
  head = head.next
end
