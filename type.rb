module TypeKind
  CHAR  = "CHAR"
  INT   = "INT"
  PTR   = "PTR"
  ARRAY = "ARRAY"
end

class Type
  attr_accessor :kind, :size, :base, :array_len

  def initialize
    @kind       = nil
    @size       = nil
    @base       = nil
    @array_len  = nil
  end
end

def new_type(kind)
  ty = Type.new
  ty.kind = kind
  return ty
end

def char_type()
  ty = new_type(TypeKind::CHAR)
  ty.size = 1
  return ty
end

def int_type()
  ty = new_type(TypeKind::INT)
  ty.size = 8
  return ty
end

def is_integer(ty)
  return ty.kind == TypeKind::CHAR || ty.kind == TypeKind::INT
end

def pointer_to(base)
  ty = new_type(TypeKind::PTR)
  ty.size = 8
  ty.base = base
  return ty
end

def array_of(base, len)
  ty = new_type(TypeKind::ARRAY)
  ty.size = base.size * len
  ty.base = base
  ty.array_len = len
  return ty
end

def add_type(node)
  if !node || node.ty
    return
  end

  add_type(node.lhs)
  add_type(node.rhs)
  add_type(node.cond)
  add_type(node.then)
  add_type(node.els)
  add_type(node.init)
  add_type(node.inc)

  n = node.body
  while n
    add_type(n)
    n = n.next
  end

  n = node.args
  while n
    add_type(n)
    n = n.next
  end

  case node.kind
  when NodeKind::ADD,
        NodeKind::SUB,
        NodeKind::PTR_DIFF,
        NodeKind::MUL,
        NodeKind::DIV,
        NodeKind::EQ,
        NodeKind::NE,
        NodeKind::LT,
        NodeKind::LE,
        NodeKind::FUNCALL,
        NodeKind::NUM then
    node.ty = int_type()
    return
  when NodeKind::PTR_ADD,
        NodeKind::PTR_SUB,
        NodeKind::PTR_SUB,
        NodeKind::ASSIGN then
    node.ty = node.lhs.ty
    return
  when NodeKind::VAR then
    node.ty = node.var.ty
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

def remove_last_expr_stmt(node)
  if node.next.nil?
    node = node.lhs
    return node
  end
  node.next = remove_last_expr_stmt(node.next)
  return node
end
