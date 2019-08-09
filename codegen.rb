def gen(node)
  case node.kind
  when NodeKind::NUM then
    puts("  push #{node.val}\n")
    return
  when NodeKind::RETURN then
    gen(node.lhs)
    puts("  pop rax\n")
    puts("  ret\n")
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

def codegen(node)
  puts(".intel_syntax noprefix\n")
  puts(".global main\n")
  puts("main:\n")

  loop do
    gen(node)
    puts("  pop rax\n")
    break if node.next.nil?
    node = node.next
  end

  puts("  ret\n")
end
