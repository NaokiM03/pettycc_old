def gen_lval(node)
  if node.kind != NodeKind::LVAR
    error("not an lvalue")
  end

  puts("  mov rax, rbp\n")
  puts("  sub rax, #{node.lvar.offset}\n")
  puts("  push rax\n")
end

def gen(node)
  case node.kind
  when NodeKind::NUM then
    puts("  push #{node.val}\n")
    return
  when NodeKind::EXPR_STMT then
    gen(node.lhs)
    puts("  add rsp, 8\n")
    return
  when NodeKind::LVAR then
    gen_lval(node)
    puts("  pop rax\n")
    puts("  mov rax, [rax]\n")
    puts("  push rax\n")
    return
  when NodeKind::ASSIGN then
    gen_lval(node.lhs)
    gen(node.rhs)
    puts("  pop rdi\n")
    puts("  pop rax\n")
    puts("  mov [rax], rdi\n")
    puts("  push rdi\n")
    return
  when NodeKind::RETURN then
    gen(node.lhs)
    puts("  pop rax\n")
    puts("  jmp .Lreturn\n")
    return
  end

  gen(node.lhs)
  gen(node.rhs)

  puts("  pop rdi\n")
  puts("  pop rax\n")

  case node.kind
  when NodeKind::ADD then
    puts("  add rax, rdi\n")
  when NodeKind::SUB then
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
  puts(".intel_syntax noprefix\n")
  puts(".global main\n")
  puts("main:\n")

  puts("  push rbp\n")
  puts("  mov rbp, rsp\n")
  puts("  sub rsp, #{prog.stack_size}\n")

  node = prog.node
  loop do
    gen(node)
    break if node.next.nil?
    node = node.next
  end

  puts(".Lreturn:\n")
  puts("  mov rsp, rbp\n")
  puts("  pop rbp\n")
  puts("  ret\n")
end
