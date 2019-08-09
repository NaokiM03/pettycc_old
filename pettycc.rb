
def int?(str)
  str.to_i.to_s == str.to_s
end

def next_cur(p)
  str = p.slice!(0)
  return if str.nil?
  $user_input_cur += 1
  return str
end

#
#  Tokenizer
#

module TokenKind
  RESERVED = "RESERVED"
  NUM = "NUM"
  EOF = "EOF"
end

class Token
  attr_accessor :kind, :next, :val, :str, :cur

  def initialize
    @kind = nil
    @next = nil
    @val  = nil
    @str  = nil
    @cur  = nil
  end
end

def new_token(kind, cur, str)
  tok = Token.new
  tok.kind = kind
  tok.str = str
  tok.cur = $user_input_cur
  cur.next = tok
  return tok
end

def error(msg)
  STDERR.puts(msg)
  exit!
end

def error_at(msg)
  pos = $user_input_cur
  STDERR.puts("#{ARGV[0]}\n" + "#{" "*$token.cur + "^ " + msg}\n")
  exit!
end

def consume(op)
  if $token.kind != TokenKind::RESERVED || $token.str != op
    return false
  end
  $token = $token.next
  return true
end

def expect(op)
  if $token.kind != TokenKind::RESERVED || $token.str != op
    error_at("expected '#{op}'")
  end
  $token = $token.next
end

def expect_number
  if $token.kind != TokenKind::NUM
    error_at("expected a number")
  end
  val = $token.val
  $token = $token.next
  return val
end

def at_eof
  return $token.kind == TokenKind::EOF
end

def tokenize()
  p = $user_input.dup
  cur = Token.new
  $token = cur

  while p.length != 0
    if p[0] == " "
      next_cur(p)
      next
    end

    if ["+", "-", "*", "/", "(", ")"].include?(p[0])
      cur = new_token(TokenKind::RESERVED, cur, next_cur(p))
      next
    end

    if int?(p[0])
      num = ""
      while int?(p[0])
        num += next_cur(p)
      end
      cur = new_token(TokenKind::NUM, cur, num)
      cur.val = num.to_i
      next
    end

    error_at("invalid token")
  end

  new_token(TokenKind::EOF, cur, p[0])
  $token = $token.next
end

#
#  Parser
#

module NodeKind
  ADD = "ADD" # +
  SUB = "SUB" # -
  MUL = "MUL" # *
  DIV = "DIV" # /
  NUM = "NUM" # Integer
end

class Node
  attr_accessor :kind, :lhs, :rhs, :val

  def initialize
    @kind = nil # NodeKind
    @lhs  = nil # Left-hand side
    @rhs  = nil # Right-hand side
    @val  = nil # value if kind == NodeKind::NUM
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

def new_num(val)
  node = new_node(NodeKind::NUM)
  node.val = val
  return node
end

def expr
  node = mul()

  loop do
    if consume("+")
      node = new_binary(NodeKind::ADD, node, mul())
    elsif consume("-")
      node = new_binary(NodeKind::SUB, node, mul())
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
  return term()
end

def term
  if consume("(")
    node = expr()
    expect(")")
    return node
  end

  return new_num(expect_number())
end

#
#  Code generator
#

def gen(node)
  if node.kind == NodeKind::NUM
    puts("  push #{node.val}\n")
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
  end

  puts("  push rax\n")
end

$token
$user_input
$user_input_cur

def main
  if ARGV.length != 1
    error "#{$0}: invalid number of arguments\n"
  end

  # Tokenize and parse
  $user_input = ARGV[0]
  $user_input_cur = -1
  $token = tokenize()
  node = expr()

  puts(".intel_syntax noprefix\n")
  puts(".global main\n")
  puts("main:\n")

  gen(node)

  puts("  pop rax\n")
  puts("  ret\n")
end

if __FILE__ == $0
  main()
end
