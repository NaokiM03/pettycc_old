def gen_addr(node)
  case node.kind
  when NodeKind::VAR then
    var = node.var
    if var.is_local
      puts("  lea rax, [rbp-#{var.offset}]\n")
      puts("  push rax\n")
    else
      puts("  push offset #{var.name}\n")
    end
    return
  when NodeKind::DEREF then
    gen(node.lhs)
    return
  end

  error("not an lvalue")
end

def gen_lval(node)
  if node.ty.kind == TypeKind::ARRAY
    error("not an lvalue")
  end
  gen_addr(node)
end

def load(ty)
  puts("  pop rax\n")
  if size_of(ty) == 1
    puts("  movzx rax, byte ptr [rax]\n")
  else
    puts("  mov rax, [rax]\n")
  end
  puts("  push rax\n")
end

def store(ty)
  puts("  pop rdi\n")
  puts("  pop rax\n")

  if size_of(ty) == 1
    puts("  mov [rax], dil\n")
  else
    puts("  mov [rax], rdi\n")
  end
  puts("  push rdi\n")
end

def gen(node)
  case node.kind
  when NodeKind::NULL then
    return
  when NodeKind::NUM then
    puts("  push #{node.val}\n")
    return
  when NodeKind::EXPR_STMT then
    gen(node.lhs)
    puts("  add rsp, 8\n")
    return
  when NodeKind::VAR then
    gen_addr(node)
    if node.ty.kind != TypeKind::ARRAY
      load(node.ty)
    end
    return
  when NodeKind::ASSIGN then
    gen_lval(node.lhs)
    gen(node.rhs)
    store(node.ty)
    return
  when NodeKind::ADDR then
    gen_addr(node.lhs)
    return
  when NodeKind::DEREF then
    gen(node.lhs)
    if node.ty.kind != TypeKind::ARRAY
      load(node.ty)
    end
    return
  when NodeKind::IF then
    seq = $labelseq
    $labelseq += 1
    if node.els
      gen(node.cond)
      puts("  pop rax\n")
      puts("  cmp rax, 0\n")
      puts("  je  .L.else#{seq}\n")
      gen(node.then)
      puts("  jmp .L.end#{seq}\n")
      puts(".L.else#{seq}:\n")
      gen(node.els)
      puts(".L.end#{seq}:\n")
    else
      gen(node.cond)
      puts("  pop rax\n")
      puts("  cmp rax, 0\n")
      puts("  je  .L.end#{seq}\n")
      gen(node.then)
      puts(".L.end#{seq}:\n")
    end
    return
  when NodeKind::WHILE then
    seq = $labelseq
    $labelseq += 1
    puts(".L.begin#{seq}:\n")
    gen(node.cond)
    puts("  pop rax\n")
    puts("  cmp rax, 0\n")
    puts("  je  .L.end#{seq}\n")
    gen(node.then)
    puts("  jmp .L.begin#{seq}\n")
    puts(".L.end#{seq}:\n")
    return
  when NodeKind::FOR then
    seq = $labelseq
    $labelseq += 1
    if node.init
      gen(node.init)
    end
    puts(".L.begin#{seq}:\n")
    if node.cond
      gen(node.cond)
      puts("  pop rax\n")
      puts("  cmp rax, 0\n")
      puts("  je  .L.end#{seq}\n")
    end
    gen(node.then)
    if node.inc
      gen(node.inc)
    end
    puts("  jmp .L.begin#{seq}\n")
    puts(".L.end#{seq}:\n")
    return
  when NodeKind::BLOCK, NodeKind::STMT_EXPR then
    n = node.body
    while n
      gen(n)
      n = n.next
    end
    return
  when NodeKind::FUNCALL then
    nargs = 0

    arg = node.args
    while arg
      gen(arg)
      nargs += 1
      arg = arg.next
    end

    i = nargs - 1
    while i >= 0
      puts("  pop #{$argreg8[i]}\n")
      i -= 1
    end

    seq = $labelseq
    $labelseq += 1
    puts("  mov rax, rsp\n")
    puts("  and rax, 15\n")
    puts("  jnz .L.call#{seq}\n")
    puts("  mov rax, 0\n")
    puts("  call #{node.funcname}\n")
    puts("  jmp .L.end#{seq}\n")
    puts(".L.call#{seq}:\n")
    puts("  sub rsp, 8\n")
    puts("  mov rax, 0\n")
    puts("  call #{node.funcname}\n")
    puts("  add rsp, 8\n")
    puts(".L.end#{seq}:\n")
    puts("  push rax\n")
    return
  when NodeKind::RETURN then
    gen(node.lhs)
    puts("  pop rax\n")
    puts("  jmp .L.return.#{$funcname}\n")
    return
  end

  gen(node.lhs)
  gen(node.rhs)

  puts("  pop rdi\n")
  puts("  pop rax\n")

  case node.kind
  when NodeKind::ADD then
    if node.ty.base
      puts("  imul rdi, #{size_of(node.ty.base)}\n")
    end
    puts("  add rax, rdi\n")
  when NodeKind::SUB then
    if node.ty.base
      puts("  imul rdi, #{size_of(node.ty.base)}\n")
    end
    puts("  sub rax, rdi\n")
  when NodeKind::MUL then
    puts("  imul rax, rdi\n")
  when NodeKind::DIV then
    puts("  cqo\n")
    puts("  idiv rdi\n")
  when NodeKind::EQ then
    puts("  cmp rax, rdi\n")
    puts("  sete al\n")
    puts("  movzb rax, al\n")
  when NodeKind::NE then
    puts("  cmp rax, rdi\n")
    puts("  setne al\n")
    puts("  movzb rax, al\n")
  when NodeKind::LT then
    puts("  cmp rax, rdi\n")
    puts("  setl al\n")
    puts("  movzb rax, al\n")
  when NodeKind::LE then
    puts("  cmp rax, rdi\n")
    puts("  setle al\n")
    puts("  movzb rax, al\n")
  end

  puts("  push rax\n")
end

def emit_data(prog)
  puts(".data\n")

  vl = prog.globals
  while vl
    var = vl.var
    puts("#{var.name}:\n")

    if !var.contents
      puts("  .zero #{size_of(var.ty)}\n")
      vl = vl.next
      next
    end

    if var.contents == "27\0"
      puts("  .byte #{27}\n")
      puts("  .byte #{0}\n")
      vl = vl.next
      next
    end

    var.cont_len.times{|i|
      puts("  .byte #{var.contents[i].ord}\n")
    }

    vl = vl.next
  end
end

def load_arg(var, idx)
  sz = size_of(var.ty)
  if sz == 1
    puts("  mov [rbp-#{var.offset}], #{$argreg1[idx]}\n")
  else
    puts("  mov [rbp-#{var.offset}], #{$argreg8[idx]}\n")
  end
end

def emit_text(prog)
  puts(".text\n")

  fn = prog.fns
  while fn
    puts(".global #{fn.name}\n")
    puts("#{fn.name}:\n")
    $funcname = fn.name

    puts("  push rbp\n")
    puts("  mov rbp, rsp\n")
    puts("  sub rsp, #{fn.stack_size}\n")

    i = 0
    vl = fn.params
    while vl
      load_arg(vl.var, i)
      i += 1
      vl = vl.next
    end

    node = fn.node
    while node
      gen(node)
      node = node.next
    end

    puts(".L.return.#{$funcname}:\n")
    puts("  mov rsp, rbp\n")
    puts("  pop rbp\n")
    puts("  ret\n")

    fn = fn.next
  end
end

def codegen(prog)
  $argreg1 = ["dil", "sil", "dl", "cl", "r8b", "r9b"]
  $argreg8 = ["rdi", "rsi", "rdx", "rcx", "r8", "r9"]
  $labelseq = 0;
  $funcname

  puts(".intel_syntax noprefix\n")
  emit_data(prog)
  emit_text(prog)
end
