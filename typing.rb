def int_type
  ty = Type.new
  ty.kind = TypeKind::INT
  return ty
end

def pointer_to(base)
  ty = Type.new
  ty.kind = TypeKind::PTR
  ty.base = base
  return ty
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
    node.ty = node.lvar.ty
    return
  when NodeKind::ADD then
    if node.rhs.ty.kind == TypeKind::PTR
      tmp = node.lhs
      node.lhs = node.rhs
      node.rhs = tmp
    end
    if node.rhs.ty.kind == TypeKind::PTR
      error("invalid pointer arithmetic operands")
    end
    node.ty = node.lhs.ty
    return
  when NodeKind::SUB then
    if node.rhs.ty.kind == TypeKind::PTR
      error("invalid pointer arithmetic operands")
    end
    node.ty = node.lhs.ty
    return
  when NodeKind::ASSIGN then
    node.ty = node.lhs.ty
    return
  when NodeKind::ADDR then
    node.ty = pointer_to(node.lhs.ty)
    return
  when NodeKind::DEREF then
    if node.lhs.ty.kind != TypeKind::PTR
      error("invalid pointer dereference")
    end
    node.ty = node.lhs.ty.base
    return
  end
end

def add_type(prog)
  fn = prog
  while fn
    node = fn.node
    while node
      visit(node)
      node = node.next
    end
    fn = fn.next
  end
end
