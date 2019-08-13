def gen_addr(node)
  case node.kind
  when NodeKind::VAR then
    puts("  lea rax, [rbp-#{node.lvar.offset}]\n")
    puts("  push rax\n")
    return
  when NodeKind::DEREF then
    gen(node.lhs)
    return
  end

  error("not an lvalue")
end

def load
  puts("  pop rax\n")
  puts("  mov rax, [rax]\n")
  puts("  push rax\n")
end

def store
  puts("  pop rdi\n")
  puts("  pop rax\n")
  puts("  mov [rax], rdi\n")
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
    load()
    return
  when NodeKind::ASSIGN then
    gen_addr(node.lhs)
    gen(node.rhs)
    store()
    return
  when NodeKind::ADDR then
    gen_addr(node.lhs)
    return
  when NodeKind::DEREF then
    gen(node.lhs)
    load()
    return
  when NodeKind::IF then
    seq = $labelseq
    $labelseq += 1
    if node.els
      gen(node.cond)
      puts("  pop rax\n")
      puts("  cmp rax, 0\n")
      puts("  je  .Lelse#{seq}\n")
      gen(node.then)
      puts("  jmp .Lend#{seq}\n")
      puts(".Lelse#{seq}:\n")
      gen(node.els)
      puts(".Lend#{seq}:\n")
    else
      gen(node.cond)
      puts("  pop rax\n")
      puts("  cmp rax, 0\n")
      puts("  je  .Lend#{seq}\n")
      gen(node.then)
      puts(".Lend#{seq}:\n")
    end
    return
  when NodeKind::WHILE then
    seq = $labelseq
    $labelseq += 1
    puts(".Lbegin#{seq}:\n")
    gen(node.cond)
    puts("  pop rax\n")
    puts("  cmp rax, 0\n")
    puts("  je  .Lend#{seq}\n")
    gen(node.then)
    puts("  jmp .Lbegin#{seq}\n")
    puts(".Lend#{seq}:\n")
    return
  when NodeKind::FOR then
    seq = $labelseq
    $labelseq += 1
    if node.init
      gen(node.init)
    end
    puts(".Lbegin#{seq}:\n")
    if node.cond
      gen(node.cond)
      puts("  pop rax\n")
      puts("  cmp rax, 0\n")
      puts("  je  .Lend#{seq}\n")
    end
    gen(node.then)
    if node.inc
      gen(node.inc)
    end
    puts("  jmp .Lbegin#{seq}\n")
    puts(".Lend#{seq}:\n")
    return
  when NodeKind::BLOCK then
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
      puts("  pop #{$argreg[i]}\n")
      i -= 1
    end

    seq = $labelseq
    $labelseq += 1
    puts("  mov rax, rsp\n")
    puts("  and rax, 15\n")
    puts("  jnz .Lcall#{seq}\n")
    puts("  mov rax, 0\n")
    puts("  call #{node.funcname}\n")
    puts("  jmp .Lend#{seq}\n")
    puts(".Lcall#{seq}:\n")
    puts("  sub rsp, 8\n")
    puts("  mov rax, 0\n")
    puts("  call #{node.funcname}\n")
    printf("  add rsp, 8\n")
    printf(".Lend#{seq}:\n")
    puts("  push rax\n")
    return
  when NodeKind::RETURN then
    gen(node.lhs)
    puts("  pop rax\n")
    puts("  jmp .Lreturn#{$funcname}\n")
    return
  end

  gen(node.lhs)
  gen(node.rhs)

  puts("  pop rdi\n")
  puts("  pop rax\n")

  case node.kind
  when NodeKind::ADD then
    if node.ty.kind == TypeKind::PTR
      puts("  imul rdi, 8\n")
    end
    puts("  add rax, rdi\n")
  when NodeKind::SUB then
    if node.ty.kind == TypeKind::PTR
      puts("  imul rdi, 8\n")
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

def codegen(prog)
  $argreg = ["rdi", "rsi", "rdx", "rcx", "r8", "r9"]
  $labelseq = 0;
  $funcname

  puts(".intel_syntax noprefix\n")

  fn = prog
  while fn
    puts(".global #{fn.name}\n")
    puts("#{fn.name}:\n")
    $funcname = fn.name

    puts("  push rbp\n")
    puts("  mov rbp, rsp\n")
    puts("  sub rsp, #{fn.stack_size}\n")

    i = 0
    p = fn.params
    while p
      var = p.var
      puts("  mov [rbp-#{var.offset}], #{$argreg[i]}\n")
      i += 1
      p = p.next
    end

    node = fn.node
    while node
      gen(node)
      node = node.next
    end

    puts(".Lreturn#{$funcname}:\n")
    puts("  mov rsp, rbp\n")
    puts("  pop rbp\n")
    puts("  ret\n")

    fn = fn.next
  end
end
