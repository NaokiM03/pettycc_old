module TokenKind
  RESERVED = "RESERVED"
  NUM = "NUM"
  EOF = "EOF"
end

class Token
  attr_accessor :kind, :next, :val, :str

  def initialize
    @kind = nil
    @next = nil
    @val  = nil
    @str  = nil
  end
end

def error(msg)
  STDERR.puts(msg)
  exit!
end

def int? str
  str.to_i.to_s == str.to_s
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
    STDERR.puts("expected '#{op}'")
  end
  $token = $token.next
end

def expect_number
  if $token.kind != TokenKind::NUM
    STDERR.puts("expected a number")
  end
  val = $token.val
  $token = $token.next
  return val
end

def at_eof
  return $token.kind == TokenKind::EOF
end

def new_token(kind, cur, str)
  tok = Token.new
  tok.kind = kind
  tok.str = str
  cur.next = tok
  return tok
end

def tokenize(p)
  cur = Token.new
  $token = cur

  while p.length != 0
    if p[0] == " "
      input.slice!(0)
      next
    end

    if p[0] == "+" || p[0] == "-"
      cur = new_token(TokenKind::RESERVED, cur, p.slice!(0))
      next
    end

    if int?(p[0])
      num = ""
      while int?(p[0])
        num += p.slice!(0)
      end
      cur = new_token(TokenKind::NUM, cur, num)
      cur.val = num.to_i
      next
    end

    error("invalid token")
  end

  new_token(TokenKind::EOF, cur, p[0])
  $token = $token.next
end

$token

def main
  if ARGV.length != 1
    error "#{$0}: invalid number of arguments\n"
  end

  tokenize(ARGV[0].dup)

  puts(".intel_syntax noprefix\n")
  puts(".global main\n")
  puts("main:\n")

  puts("  mov rax, #{expect_number()}\n")

  while !at_eof()
    if consume("+")
      puts("  add rax, #{expect_number()}\n")
    end

    expext("-")
    puts("  sub rax, #{expect_number()}\n")
  end

  puts("  ret\n")
end

if __FILE__ == $0
  main
end
