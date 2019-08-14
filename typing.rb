module TypeKind
  CHAR  = "CHAR"
  INT   = "INT"
  PTR   = "PTR"
  ARRAY = "ARRAY"
end

class Type
  attr_accessor :kind, :base, :array_size

  def initialize
    @kind       = nil
    @base       = nil
    @array_size = nil
  end
end

def new_type(kind)
  ty = Type.new
  ty.kind = kind
  return ty
end

def char_type()
  return new_type(TypeKind::CHAR)
end

def int_type()
  return new_type(TypeKind::INT)
end

def pointer_to(base)
  ty = new_type(TypeKind::PTR)
  ty.base = base
  return ty
end

def array_of(base, size)
  ty = new_type(TypeKind::ARRAY)
  ty.base = base
  ty.array_size = size
  return ty
end

def size_of(ty)
  case ty.kind
  when TypeKind::CHAR then
    return 1
  when TypeKind::INT, TypeKind::PTR then
    return 8
  else
    return size_of(ty.base) * ty.array_size
  end
end

def visit(node)
  if !node
    return
  end

  visit(node.lhs)
  visit(node.rhs)
  visit(node.cond)
  visit(node.then)
  visit(node.els)
  visit(node.init)
  visit(node.inc)

  n = node.body
  while n
    visit(n)
    n = n.next
  end
  n = node.args
  while n
    visit(n)
    n = n.next
  end

  case node.kind
  when NodeKind::MUL then
  when NodeKind::DIV then
  when NodeKind::EQ then
  when NodeKind::NE then
  when NodeKind::LT then
  when NodeKind::LE then
  when NodeKind::FUNCALL then
  when NodeKind::NUM then
    node.ty = int_type()
    return
  when NodeKind::VAR then
    node.ty = node.var.ty
    return
  when NodeKind::ADD then
    if node.rhs.ty.base
      tmp = node.lhs
      node.lhs = node.rhs
      node.rhs = tmp
    end
    if node.rhs.ty.base
      error("invalid pointer arithmetic operands")
    end
    node.ty = node.lhs.ty
    return
  when NodeKind::SUB then
    if node.rhs.ty.base
      error("invalid pointer arithmetic operands")
    end
    node.ty = node.lhs.ty
    return
  when NodeKind::ASSIGN then
    node.ty = node.lhs.ty
    return
  when NodeKind::ADDR then
    if node.lhs.ty.kind == TypeKind::ARRAY
      node.ty = pointer_to(node.lhs.ty.base)
    else
      node.ty = pointer_to(node.lhs.ty)
    end
    return
  when NodeKind::DEREF then
    if !node.lhs.ty.base
      error("invalid pointer dereference")
    end
    node.ty = node.lhs.ty.base
    return
  when NodeKind::SIZEOF then
    node.kind = NodeKind::NUM
    node.ty = int_type()
    node.val = size_of(node.lhs.ty)
    node.lhs = nil
    return
  when NodeKind::STMT_EXPR then
    # last = node.body
    # while last.next
    #   last = last.next
    # end
    # node.ty = last.ty
    node.body = remove_last_expr_stmt(node.body)
    return
  end
end

def add_type(prog)
  fn = prog.fns
  while fn
    node = fn.node
    while node
      visit(node)
      node = node.next
    end
    fn = fn.next
  end
end

def remove_last_expr_stmt(node)
  if node.next.nil?
    node = node.lhs
    return node
  end
  node.next = remove_last_expr_stmt(node.next)
  return node
end
