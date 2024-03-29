class Var
  attr_accessor :name, :ty, :is_local,
                :offset,
                :contents, :cont_len

  def initialize
    @name   = nil
    @ty     = nil
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

class Member
  attr_accessor :next, :ty, :name, :offset

  def initialize
    @next     = nil
    @ty       = nil
    @name     = nil
    @offset   = nil
  end
end

class TagScope
  attr_accessor :next, :name, :ty

  def initialize
    @next = nil
    @name = nil
    @ty   = nil
  end
end

class Scope
  attr_accessor :var_scope, :tag_scope

  def initialize
    @var_scope = nil
    @tag_scope = nil
  end
end

module NodeKind
  ADD       = "ADD"       # num + num
  PTR_ADD   = "PTR_ADD"   # ptr + num or num + ptr
  SUB       = "SUB"       # num - num
  PTR_SUB   = "PTR_SUB"   # ptr - num
  PTR_DIFF  = "PTR_DIFF"  # ptr - ptr
  MUL       = "MUL"       # *
  DIV       = "DIV"       # /
  EQ        = "EQ"        # ==
  NE        = "NE"        # !=
  LT        = "LT"        # <
  LE        = "LE"        # <=
  ASSIGN    = "ASSIGN"    # =
  MEMBER    = "MEMBER"    # . (struct menber access)
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
  STMT_EXPR = "STMT_EXPR" # Statement expression
  VAR       = "VAR"       # Variable
  NUM       = "NUM"       # Integer
  NULL      = "NULL"      # Empty statement
end

class Node
  attr_accessor :kind, :next, :ty,
                :lhs, :rhs,
                :cond, :then, :els, :init, :inc,
                :body,
                :member,
                :funcname, :args,
                :var, :val

  def initialize
    @kind     = nil             # NodeKind
    @next     = nil             # Next node
    @ty       = nil             # Type

    @lhs      = nil             # Left-hand side
    @rhs      = nil             # Right-hand side

    @cond     = nil             #-------------------------------
    @then     = nil             #
    @els      = nil             # "if", "while" or "for" statement
    @init     = nil             #
    @inc      = nil             #-------------------------------

    @body     = nil             # Block

    @menber   = nil      # Struct member access

    @funcname = nil             # Function call
    @args     = nil             #

    @var     = Var.new          # Variable name
    @val      = nil             # value if kind == NodeKind::NUM
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

def enter_scope()
  sc = Scope.new
  sc.var_scope = $var_scope
  sc.tag_scope = $tag_scope
  return sc
end

def leave_scope(sc)
  $var_scope = sc.var_scope
  $tag_scope = sc.tag_scope
end

def find_var(tok)
  vl = $var_scope
  while vl
    var = vl.var
    if var.name.length == tok.len && tok.str == var.name
      return var
    end
    vl = vl.next
  end
  return nil
end

def find_tag(tok)
  sc = $tag_scope
  while sc
    if sc.name.length == tok.len && tok.str == sc.name
      return sc
    end
    sc = sc.next
  end
  return nil
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

def new_var_node(var)
  node = new_node(NodeKind::VAR)
  node.var = var
  return node
end

def new_var(name, ty, is_local)
  var = Var.new
  var.name = name
  var.ty = ty
  var.is_local = is_local

  sc = VarList.new
  sc.var = var
  sc.next = $var_scope
  $var_scope = sc
  return var
end

def new_lvar(name, ty)
  var = new_var(name, ty, true)

  vl = VarList.new
  vl.var = var
  vl.next = $locals
  $locals = vl
  return var
end

def new_gvar(name, ty)
  var = new_var(name, ty, false)

  vl = VarList.new
  vl.var = var
  vl.next = $globals
  $globals = vl
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

  is_func = consume_ident() && consume("(")
  $token = tok
  return !!is_func
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
  if !is_typename()
    error("typename expected")
  end

  ty = nil
  if consume("char")
    ty = char_type()
  elsif consume("int")
    ty = int_type()
  else
    ty = struct_decl()
  end

  while consume("*")
    ty = pointer_to(ty)
  end
  return ty
end

def read_type_suffix(base)
  if !consume("[")
    return base
  end
  sz = expect_number()
  expect("]")
  base = read_type_suffix(base)
  return array_of(base, sz)
end

def push_tag_scope(tok, ty)
  sc = TagScope.new
  sc.next = $tag_scope
  sc.name = tok.str
  sc.ty = ty
  $tag_scope = sc
end

def struct_decl
  expect("struct")

  tag = consume_ident()
  if tag && !peek("{")
    sc = find_tag(tag)
    if !sc
      error("unknown struct type")
    end
    return sc.ty
  end

  expect("{")

  head = Member.new
  cur = head

  while !consume("}")
    cur.next = struct_member()
    cur = cur.next
  end

  ty = struct_type()
  ty.members = head.next

  offset = 0
  mem = ty.members
  while mem
    offset = align_to(offset, mem.ty.align)
    mem.offset = offset
    offset += mem.ty.size

    if ty.align < mem.ty.align
      ty.align = mem.ty.align
    end

    mem = mem.next
  end
  ty.size = align_to(offset, ty.align)

  if tag
    push_tag_scope(tag, ty)
  end

  return ty
end

def struct_member
  mem = Member.new
  mem.ty = basetype()
  mem.name = expect_ident()
  mem.ty = read_type_suffix(mem.ty)
  expect(";")
  return mem
end

def read_func_param
  ty = basetype()
  name = expect_ident()
  ty = read_type_suffix(ty)

  vl = VarList.new
  vl.var = new_lvar(name, ty)
  return vl
end

def read_func_params
  if consume(")")
    return nil
  end

  head = read_func_param()
  cur = head

  while !consume(")")
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

  sc = enter_scope()
  fn.params = read_func_params()
  expect("{")

  head = Node.new
  cur = head

  while !consume("}")
    cur.next = stmt()
    cur = cur.next
  end
  leave_scope(sc)

  fn.node = head.next
  fn.locals = $locals
  return fn
end

def global_var
  ty = basetype()
  name = expect_ident()
  ty = read_type_suffix(ty)
  expect(";")
  new_gvar(name, ty)
end

def declaration
  ty = basetype()
  if consume(";")
    return new_node(NodeKind::NULL)
  end

  name = expect_ident()
  ty = read_type_suffix(ty)
  var = new_lvar(name, ty)

  if consume(";")
    return new_node(NodeKind::NULL)
  end

  expect("=")
  lhs = new_var_node(var)
  rhs = expr()
  expect(";")
  node = new_binary(NodeKind::ASSIGN, lhs, rhs)
  return new_unary(NodeKind::EXPR_STMT, node)
end

def read_expr_stmt
  return new_unary(NodeKind::EXPR_STMT, expr())
end

def is_typename
  return peek("char") || peek("int") || peek("struct")
end

def stmt
  node = stmt2()
  add_type(node)
  return node
end

def stmt2
  if consume("return")
    node = new_unary(NodeKind::RETURN, expr())
    expect(";")
    return node
  end

  if consume("if")
    node = new_node(NodeKind::IF)
    expect("(")
    node.cond = expr()
    expect(")")
    node.then = stmt()
    if consume("else")
      node.els = stmt()
    end
    return node
  end

  if consume("while")
    node = new_node(NodeKind::WHILE)
    expect("(")
    node.cond = expr()
    expect(")")
    node.then = stmt()
    return node
  end

  if consume("for")
    node = new_node(NodeKind::FOR)
    expect("(")
    if !consume(";")
      node.init = read_expr_stmt()
      expect(";")
    end
    if !consume(";")
      node.cond = expr()
      expect(";")
    end
    if !consume(")")
      node.inc = read_expr_stmt()
      expect(")")
    end
    node.then = stmt()
    return node
  end

  if consume("{")
    head = Node.new
    cur = head

    sc = enter_scope()
    while !consume("}")
      cur.next = stmt()
      cur = cur.next
    end
    leave_scope(sc)

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
  if consume("=")
    node = new_binary(NodeKind::ASSIGN, node, assign())
  end
  return node
end

def equality
  node = relational()

  loop do
    if consume("==")
      node = new_binary(NodeKind::EQ, node, relational())
    elsif consume("!=")
      node = new_binary(NodeKind::NE, node, relational())
    else
      return node
    end
  end
end

def relational
  node = add()

  loop do
    if consume("<")
      node = new_binary(NodeKind::LT, node, add())
    elsif consume("<=")
      node = new_binary(NodeKind::LE, node, add())
    elsif consume(">")
      node = new_binary(NodeKind::LT, add(), node)
    elsif consume(">=")
      node = new_binary(NodeKind::LE, add(), node)
    else
      return node
    end
  end
end

def new_add(lhs, rhs)
  add_type(lhs)
  add_type(rhs)

  # puts !!is_integer(lhs.ty) && !!is_integer(rhs.ty)
  # puts !!lhs.ty.base && !!is_integer(rhs.ty)
  # puts !!is_integer(lhs.ty) && !!rhs.ty.base

  if !!is_integer(lhs.ty) && !!is_integer(rhs.ty)
    return new_binary(NodeKind::ADD, lhs, rhs)
  end
  if !!lhs.ty.base && !!is_integer(rhs.ty)
    return new_binary(NodeKind::PTR_ADD, lhs, rhs)
  end
  if !!is_integer(lhs.ty) && !!rhs.ty.base
    return new_binary(NodeKind::PTR_ADD, rhs, lhs)
  end
  error_at("invalid operands")
end

def new_sub(lhs, rhs)
  add_type(lhs)
  add_type(rhs)

  # puts !!is_integer(lhs.ty) && !!is_integer(rhs.ty)
  # puts !!lhs.ty.base && !!is_integer(rhs.ty)
  # puts !!is_integer(lhs.ty.base) && !!rhs.ty.base

  if !!is_integer(lhs.ty) && !!is_integer(rhs.ty)
    return new_binary(NodeKind::SUB, lhs, rhs)
  end
  if !!lhs.ty.base && !!is_integer(rhs.ty)
    return new_binary(NodeKind::PTR_SUB, lhs, rhs)
  end
  if !!is_integer(lhs.ty.base) && !!rhs.ty.base
    return new_binary(NodeKind::PTR_DIFF, rhs, lhs)
  end
  error("invalid operands")
end

def add
  node = mul()

  loop do
    if consume("+")
      node = new_add(node, mul())
    elsif consume("-")
      node = new_sub(node, mul())
    else
      return node
    end
  end
end

def mul
  node = unary()

  loop do
    if consume("*")
      node = new_binary(NodeKind::MUL, node, unary())
    elsif consume("/")
      node = new_binary(NodeKind::DIV, node, unary())
    else
      return node
    end
  end
end

def unary
  if consume("+")
    return unary()
  end
  if consume("-")
    return new_binary(NodeKind::SUB, new_num(0), unary())
  end
  if consume("&")
    return new_unary(NodeKind::ADDR, unary())
  end
  if consume("*")
    return new_unary(NodeKind::DEREF, unary())
  end
  return postfix()
end

def find_member(ty, name)
  mem = ty.members
  while mem
    if mem.name == name
      return mem
    end
    mem = mem.next
  end

  return nil
end

def struct_ref(lhs)
  add_type(lhs)
  if lhs.ty.kind != TypeKind::STRUCT
    error("not a struct")
  end

  mem = find_member(lhs.ty, expect_ident())
  if !mem
    error("no such member")
  end

  node = new_unary(NodeKind::MEMBER, lhs)
  node.member = mem

  return node
end

def postfix
  node = primary()

  loop do
    if consume("[")
      exp = new_add(node, expr())
      expect("]")
      node = new_unary(NodeKind::DEREF, exp)
      next
    end

    if consume(".")
      node = struct_ref(node)
      next
    end

    if consume("->")
      node = new_unary(NodeKind::DEREF, node)
      node = struct_ref(node)
      next
    end

    return node
  end
end

def stmt_expr
  sc = enter_scope()

  node = new_node(NodeKind::STMT_EXPR)
  node.body = stmt()
  cur = node.body

  while !consume("}")
    cur.next = stmt()
    cur = cur.next
  end
  expect(")")

  leave_scope(sc)

  if cur.kind != NodeKind::EXPR_STMT
    error("stmt expr returning void is not supported")
  end
  cur = cur.lhs
  return node
end

def func_args
  if consume(")")
    return nil
  end

  head = assign()
  cur = head

  while consume(",")
    cur.next = assign()
    cur = cur.next
  end

  expect(")")
  return head
end

def primary
  tok = nil
  if tok = consume("(")
    if consume("{")
      return stmt_expr()
    end
    node = expr()
    expect(")")
    return node
  end

  if tok = consume("sizeof")
    node = unary()
    add_type(node)
    return new_num(node.ty.size)
  end

  if tok = consume_ident()
    if consume("(")
      node = new_node(NodeKind::FUNCALL)
      node.funcname = strndup(tok.str, tok.len)
      node.args = func_args()
      return node
    end

    var = find_var(tok)
    if !var
      error("undefined variable")
    end
    return new_var_node(var)
  end

  tok = $token
  if tok.kind == TokenKind::STR
    $token = $token.next

    ty = array_of(char_type(), tok.cont_len)
    var = new_gvar(new_label(), ty)
    var.contents = tok.contents
    var.cont_len = tok.cont_len
    return new_var_node(var)
  end

  if tok.kind != TokenKind::NUM
    error("expected expression")
  end

  return new_num(expect_number())
end
