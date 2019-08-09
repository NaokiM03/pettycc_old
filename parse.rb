#
#  Tokenizer
#

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

def new_token(kind, cur, str, len)
  tok = Token.new
  tok.kind = kind
  tok.str = str
  tok.len = len
  tok.cur = $user_input_cur
  cur.next = tok
  return tok
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

def alpha?(c)
  (c =~ /\A[A-Za-z]+\z/) == 0 || c == "_"
end

def alnum?(c)
  (c =~ /\A[A-Za-z0-9]+\z/) == 0
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

    if startswith(p, "return") && !alnum?(p[6])
      ret = n_next_cur(p, 6)
      cur = new_token(TokenKind::RESERVED, cur, ret, 6)
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

    if downcase?(p[0])
      cur = new_token(TokenKind::IDENT, cur, next_cur(p), 1)
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

#
#  Parser
#

module NodeKind
  ADD       = "ADD"       # +
  SUB       = "SUB"       # -
  MUL       = "MUL"       # *
  DIV       = "DIV"       # /
  EQ        = "EQ"        # ==
  NE        = "NE"        # !=
  LT        = "LT"        # <
  LE        = "LE"        # <=
  ASSIGN    = "ASSIGN"    # =
  RETURN    = "RETURN"    # "return"
  EXPR_STMT = "EXPR_STMT" # Expression statement
  LVAR      = "LVAR"      # Local variable
  NUM       = "NUM"       # Integer
end

class Node
  attr_accessor :kind, :next, :lhs, :rhs, :name, :val

  def initialize
    @kind = nil # NodeKind
    @next = nil # Next node
    @lhs  = nil # Left-hand side
    @rhs  = nil # Right-hand side
    @name = nil # local variable name
    @val  = nil # value if kind == NodeKind::NUM
  end
end

def new_node(kind)
  node = Node.new
  node.kind = kind
  return node
end

def new_binary(kind, lhs, rhs)
  node = new_node(kind)
  node.lhs = lhs
  node.rhs = rhs
  return node
end

def new_unary(kind, expr)
  node = new_node(kind)
  node.lhs = expr
  return node
end

def new_num(val)
  node = new_node(NodeKind::NUM)
  node.val = val
  return node
end

def new_lvar(name)
  node = new_node(NodeKind::LVAR)
  node.name = name
  return node
end

def program
  cur = Token.new
  node = cur

  while !at_eof()
    cur.next = stmt()
    cur = cur.next
  end

  node = node.next
end

def stmt
  if consume?("return")
    node = new_unary(NodeKind::RETURN, expr())
    expect(";")
    return node
  end

  node = new_unary(NodeKind::EXPR_STMT, expr())
  expect(";")
  return node
end

def expr
  return assign()
end

def assign
  node = equality()
  if consume?("=")
    node = new_binary(NodeKind::ASSIGN, node, assign())
  end
  return node
end

def equality
  node = relational()

  loop do
    if consume?("==")
      node = new_binary(NodeKind::EQ, node, relational())
    elsif consume?("!=")
      node = new_binary(NodeKind::NE, node, relational())
    else
      return node
    end
  end
end

def relational
  node = add()

  loop do
    if consume?("<")
      node = new_binary(NodeKind::LT, node, add())
    elsif consume?("<=")
      node = new_binary(NodeKind::LE, node, add())
    elsif consume?(">")
      node = new_binary(NodeKind::LT, add(), node)
    elsif consume?(">=")
      node = new_binary(NodeKind::LE, add(), node)
    else
      return node
    end
  end
end

def add
  node = mul()

  loop do
    if consume?("+")
      node = new_binary(NodeKind::ADD, node, mul())
    elsif consume?("-")
      node = new_binary(NodeKind::SUB, node, mul())
    else
      return node
    end
  end
end

def mul
  node = unary()

  loop do
    if consume?("*")
      node = new_binary(NodeKind::MUL, node, unary())
    elsif consume?("/")
      node = new_binary(NodeKind::DIV, node, unary())
    else
      return node
    end
  end
end

def unary
  if consume?("+")
    return unary()
  end
  if consume?("-")
    return new_binary(NodeKind::SUB, new_num(0), unary())
  end
  return term()
end

def term
  if consume?("(")
    node = expr()
    expect(")")
    return node
  end

  tok = consume_ident()
  if tok
    return new_lvar(tok.str)
  end

  return new_num(expect_number())
end
