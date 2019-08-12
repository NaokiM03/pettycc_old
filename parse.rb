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

def alpha?(c)
  (c =~ /\A[A-Za-z]+\z/) == 0 || c == "_"
end

def alnum?(c)
  (c =~ /\A[A-Za-z0-9]+\z/) == 0
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

#
#  Parser
#

class LVar
  attr_accessor :next, :name, :offset

  def initialize
    @next   = nil
    @name   = nil
    @offset = nil
  end
end

def find_lvar(tok)
  var = $locals
  loop do
    break if var.nil?
    if var.name.length == tok.len && tok.str == var.name
      return var
    end
    break if var.next.nil?
    var = var.next
  end
  return nil
end

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
  IF        = "IF"        # "if"
  EXPR_STMT = "EXPR_STMT" # Expression statement
  LVAR      = "LVAR"      # Local variable
  NUM       = "NUM"       # Integer
end

class Node
  attr_accessor :kind, :next,
                :lhs, :rhs,
                :cond, :then, :els,
                :lvar, :val

  def initialize
    @kind = nil      # NodeKind
    @next = nil      # Next node

    @lhs  = nil      # Left-hand side
    @rhs  = nil      # Right-hand side

    @cond = nil      #-----
    @then = nil      # "if"
    @els  = nil      #-----

    @lvar = LVar.new # local variable name
    @val  = nil      # value if kind == NodeKind::NUM
  end
end

class Program
  attr_accessor :node, :locals, :stack_size

  def initialize
    @node       = nil
    @locals      = nil
    @stack_size = nil
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

def new_lvar(var)
  node = new_node(NodeKind::LVAR)
  node.lvar = var
  return node
end

def program
  $locals = nil

  cur = Token.new
  node = cur

  while !at_eof()
    cur.next = stmt()
    cur = cur.next
  end

  prog = Program.new
  prog.node = node.next
  prog.locals = $locals
  return prog
end

def read_expr_stmt
  return new_unary(NodeKind::EXPR_STMT, expr())
end

def stmt
  if consume?("return")
    node = new_unary(NodeKind::RETURN, expr())
    expect(";")
    return node
  end

  if consume?("if")
    node = new_node(NodeKind::IF)
    expect("(")
    node.cond = expr()
    expect(")")
    node.then = stmt()
    if consume?("else")
      node.els = stmt()
    end
    return node
  end

  node = read_expr_stmt()
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
    var = find_lvar(tok)
    if !var
      var = LVar.new
      var.next = $locals
      var.name = strndup(tok.str, tok.len)
      $locals = var
    end
    return new_lvar(var)
  end

  return new_num(expect_number())
end
