module TokenKind
  RESERVED = "RESERVED"
  IDENT = "IDENT"
  NUM = "NUM"
  EOF = "EOF"
end

class Token
  attr_accessor :kind, :next, :val, :str, :len, :cur

  def initialize
    @kind = nil
    @next = nil
    @val  = nil
    @str  = nil
    @len  = nil

    @cur  = nil
  end
end

def strndup(p, len)
  p.dup
end

def consume?(op)
  if $token.kind != TokenKind::RESERVED \
  || op.length != $token.len \
  || $token.str != op
    return false
  end
  $token = $token.next
  return true
end

def consume_ident
  if $token.kind != TokenKind::IDENT
    return nil
  end
  t = $token
  $token = $token.next
  return t
end

def expect(op)
  if $token.kind != TokenKind::RESERVED \
  || op.length != $token.len \
  || $token.str != op
    error_at("expected \"#{op}\"")
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
  kw = ["return", "if", "else"]

  kw.length.times{|i|
    len = kw[i].length
    if startswith(p, kw[i]) && !alnum?(p[len])
      return kw[i]
    end
  }
  return nil
end

def tokenize()
  p = $user_input.dup
  cur = Token.new
  $token = cur

  while p.length != 0
    if p[0] == " "
      next_cur(p)
      next
    end

    kw = starts_with_keyword(p)
    if kw
      len = kw.length
      str = n_next_cur(p, len)
      cur = new_token(TokenKind::RESERVED, cur, str, len)
      next
    end

    if startswith(p, "==") || startswith(p, "!=") ||
        startswith(p, "<=") || startswith(p, ">=")
      op = n_next_cur(p, 2)
      cur = new_token(TokenKind::RESERVED, cur, op, 2)
      next
    end

    if ["+", "-", "*", "/", "(", ")", "<", ">", ";", "="].include?(p[0])
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

    error_at("invalid token")
  end

  new_token(TokenKind::EOF, cur, p[0], 0)
  $token = $token.next
end
