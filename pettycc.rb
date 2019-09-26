require "./codegen.rb"
require "./parse.rb"
require "./tokenize.rb"
require "./type.rb"

def int?(str)
  str.to_i.to_s == str.to_s
end

def downcase?(s)
  (s =~ /^[a-z]+$/) == 0
end

def alpha?(c)
  (c =~ /\A[A-Za-z]+\z/) == 0 || c == "_"
end

def alnum?(c)
  (c =~ /\A[A-Za-z0-9]+\z/) == 0 || c == "_"
end

def ispunct?(c)
  [ "!", "\"", "#", "$", "%", "&", "'", "(", ")",
    "*", "+", ",", "-", ".", "/",
    ":", ";", "<", "=", ">", "?",
    "@",
    "[", "\\", "]", "^", "_",
    "`",
    "{", "|", "}"].include?(c)
end

def next_cur(p)
  str = p.slice!(0)
  return nil if str.nil?
  $user_input_cur += 1
  return str
end

def n_next_cur(p, num)
  str = ""
  num.times{ str += next_cur(p) }
  return str
end

def startswith(p, q)
  len = q.length
  len.times{|i|
    return if p[i].nil?
  }
  op = ""
  len.times{|i|
    op += p[i]
  }
  return op == q
end

def error(msg)
  STDERR.puts(msg)
  exit!
end

def error_at(msg)
  pos = $token.cur || 0
  pos = pos - $token.str.length + 1
  STDERR.puts($user_input + "#{" " * pos + "^ " + msg}\n")
  exit!
end

def align_to(n, align)
  return (n + align - 1) & ~(align - 1)
end

def read_file(path)
  begin
    File.read(path)
  rescue => e
    puts("class=#{e.class} message=#{e.message}")
  end
end

$token
$locals
$globals
$scope
$user_input
$user_input_cur

def main
  if ARGV.length != 1
    error "#{$0}: invalid number of arguments\n"
  end

  # Tokenize and parse
  $user_input = read_file(ARGV[0])
  $user_input_cur = 0
  $token = tokenize()
  prog = program()

  fn = prog.fns
  while fn
    offset = 0

    vl = fn.locals
    while vl
      var = vl.var
      offset += var.ty.size
      var.offset = offset
      vl = vl.next
    end
    fn.stack_size = align_to(offset, 8)

    fn = fn.next
  end

  codegen(prog)
end

if __FILE__ == $0
  main()
end
