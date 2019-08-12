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
  WHILE     = "WHILE"     # "while"
  FOR       = "FOR"       # "for"
  EXPR_STMT = "EXPR_STMT" # Expression statement
  LVAR      = "LVAR"      # Local variable
  NUM       = "NUM"       # Integer
end

class Node
  attr_accessor :kind, :next,
                :lhs, :rhs,
                :cond, :then, :els, :init, :inc,
                :lvar, :val

  def initialize
    @kind = nil      # NodeKind
    @next = nil      # Next node

    @lhs  = nil      # Left-hand side
    @rhs  = nil      # Right-hand side

    @cond = nil      #-------------------------------
    @then = nil      #
    @els  = nil      # "if", "while" or "for" statement
    @init = nil      #
    @inc  = nil      #-------------------------------

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

  head = Node.new
  cur = head

  while !at_eof()
    cur.next = stmt()
    cur = cur.next
  end

  prog = Program.new
  prog.node = head.next
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

  if consume?("while")
    node = new_node(NodeKind::WHILE)
    expect("(")
    node.cond = expr()
    expect(")")
    node.then = stmt()
    return node
  end

  if consume?("for")
    node = new_node(NodeKind::FOR)
    expect("(")
    if !consume?(";")
      node.init = read_expr_stmt()
      expect(";")
    end
    if !consume?(";")
      node.cond = expr()
      expect(";")
    end
    if !consume?(")")
      node.inc = read_expr_stmt()
      expect(")")
    end
    node.then = stmt()
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
