class Var
  attr_accessor :name, :ty, :is_local,
                :offset,
                :contents, :cont_len

  def initialize
    @name   = nil
    @ty     = Type.new
    @is_local = nil

    @offset = nil

    @contents = nil
    @cont_len = nil
  end
end

class VarList
  attr_accessor :next, :var

  def initialize
    @next   = nil
    @var    = Var.new
  end
end

def find_var(tok)
  vl = $locals
  while vl
    var = vl.var
    if var.name.length == tok.len && tok.str == var.name
      return var
    end
    vl = vl.next
  end

  vl = $globals
  while vl
    var = vl.var
    if var.name.length == tok.len && tok.str == var.name
      return var
    end
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
  ADDR      = "ADDR"      # unary &
  DEREF     = "DEREF"     # unary *
  RETURN    = "RETURN"    # "return"
  IF        = "IF"        # "if"
  WHILE     = "WHILE"     # "while"
  FOR       = "FOR"       # "for"
  SIZEOF    = "SIZEOF"    # "sizeof"
  BLOCK     = "BLOCK"     # { ... }
  FUNCALL   = "FUNCALL"   # Function call
  EXPR_STMT = "EXPR_STMT" # Expression statement
  VAR       = "VAR"       # Variable
  NUM       = "NUM"       # Integer
  NULL      = "NULL"      # Empty statement
end

class Node
  attr_accessor :kind, :next, :ty,
                :lhs, :rhs,
                :cond, :then, :els, :init, :inc,
                :body,
                :funcname, :args,
                :var, :val

  def initialize
    @kind     = nil      # NodeKind
    @next     = nil      # Next node
    @ty       = Type.new # Type

    @lhs      = nil      # Left-hand side
    @rhs      = nil      # Right-hand side

    @cond     = nil      #-------------------------------
    @then     = nil      #
    @els      = nil      # "if", "while" or "for" statement
    @init     = nil      #
    @inc      = nil      #-------------------------------

    @body     = nil      # Block

    @funcname = nil      # Function call
    @args     = nil      #

    @var     = Var.new  # Variable name
    @val      = nil      # value if kind == NodeKind::NUM
  end
end

class FuncParam
  attr_accessor :next, :var

  def initialize
    @next       = nil
    @var        = Var.new
  end
end

class Function
  attr_accessor :next, :name, :params,
                :node, :locals, :stack_size

  def initialize
    @next       = nil
    @name       = nil
    @params     = nil

    @node       = nil
    @locals     = nil
    @stack_size = nil
  end
end

class Program
  attr_accessor :globals, :fns

  def initialize
    @globals = VarList.new
    @fns     = Function.new
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

def new_var(var)
  node = new_node(NodeKind::VAR)
  node.var = var
  return node
end

def push_var(name, ty, is_local)
  var = Var.new
  var.name = name
  var.ty = ty
  var.is_local = is_local

  vl = VarList.new
  vl.var = var

  if is_local
    vl.next = $locals
    $locals = vl
  else
    vl.next = $globals
    $globals = vl  
  end

  return var
end

$cnt = 0

def new_label
  str = ".L.data.#{$cnt}"
  $cnt += 1
  return str
end

def is_function
  tok = $token
  basetype()
  isfunc = consume_ident() && consume?("(")
  $token = tok
  return isfunc
end

def program
  head = Function.new
  cur = head
  $globals = nil

  while !at_eof()
    if is_function()
      cur.next = function()
      cur = cur.next
    else
      global_var()
    end
  end

  prog = Program.new
  prog.globals = $globals
  prog.fns = head.next
  return prog
end

def basetype
  ty = nil
  if consume?("char")
    ty = char_type()
  else
    expect("int")
    ty = int_type()
  end

  while consume?("*")
    ty = pointer_to(ty)
  end
  return ty
end

def read_type_suffix(base)
  if !consume?("[")
    return base
  end
  sz = expect_number()
  expect("]")
  base = read_type_suffix(base)
  return array_of(base, sz)
end

def read_func_param
  ty = basetype()
  name = expect_ident()
  ty = read_type_suffix(ty)

  vl = VarList.new
  vl.var = push_var(name, ty, true)
  return vl
end

def read_func_params
  if consume?(")")
    return nil
  end

  head = read_func_param()
  cur = head

  while !consume?(")")
    expect(",")
    cur.next = read_func_param()
    cur = cur.next
  end

  return head
end

def function
  $locals = nil

  fn = Function.new
  basetype()
  fn.name = expect_ident()
  expect("(")
  fn.params = read_func_params()
  expect("{")

  head = Node.new
  cur = head

  while !consume?("}")
    cur.next = stmt()
    cur = cur.next
  end

  fn.node = head.next
  fn.locals = $locals
  return fn
end

def global_var
  ty = basetype()
  name = expect_ident()
  ty = read_type_suffix(ty)
  expect(";")
  push_var(name, ty, false)
end

def declaration
  ty = basetype()
  name = expect_ident()
  ty = read_type_suffix(ty)
  var = push_var(name, ty, true)

  if consume?(";")
    return new_node(NodeKind::NULL)
  end

  expect("=")
  lhs = new_var(var)
  rhs = expr()
  expect(";")
  node = new_binary(NodeKind::ASSIGN, lhs, rhs)
  return new_unary(NodeKind::EXPR_STMT, node)
end

def read_expr_stmt
  return new_unary(NodeKind::EXPR_STMT, expr())
end

def is_typename
  return peek("char") || peek("int")
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

  if consume?("{")
    head = Node.new
    cur = head

    while !consume?("}")
      cur.next = stmt()
      cur = cur.next
    end

    node = new_node(NodeKind::BLOCK)
    node.body = head.next
    return node
  end

  if is_typename()
    return declaration()
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
  if consume?("&")
    return new_unary(NodeKind::ADDR, unary())
  end
  if consume?("*")
    return new_unary(NodeKind::DEREF, unary())
  end
  return postfix()
end

def postfix
  node = term()

  while consume?("[")
    exp = new_binary(NodeKind::ADD, node, expr())
    expect("]")
    node = new_unary(NodeKind::DEREF, exp)
  end
  return node
end

def func_args
  if consume?(")")
    return nil
  end

  head = assign()
  cur = head

  while consume?(",")
    cur.next = assign()
    cur = cur.next
  end

  expect(")")
  return head
end

def term
  tok = nil
  if consume?("(")
    node = expr()
    expect(")")
    return node
  end

  if tok = consume?("sizeof")
    return new_unary(NodeKind::SIZEOF, unary())
  end

  if tok = consume_ident()
    if consume?("(")
      node = new_node(NodeKind::FUNCALL)
      node.funcname = strndup(tok.str, tok.len)
      node.args = func_args()
      return node
    end

    var = find_var(tok)
    if !var
      error("undefined variable")
    end
    return new_var(var)
  end

  tok = $token
  if tok.kind == TokenKind::STR
    $token = $token.next

    ty = array_of(char_type(), tok.cont_len)
    var = push_var(new_label(), ty, false)
    var.contents = tok.contents
    var.cont_len = tok.cont_len
    return new_var(var)
  end

  if tok.kind != TokenKind::NUM
    error("expected expression")
  end

  return new_num(expect_number())
end
