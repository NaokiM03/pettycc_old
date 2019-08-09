require "./codegen.rb"
require "./parse.rb"

def int?(str)
  str.to_i.to_s == str.to_s
end

def downcase?(s)
  (s =~ /^[a-z]+$/) == 0
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
  STDERR.puts("#{ARGV[0]}\n" + "#{" "*pos + "^ " + msg}\n")
  exit!
end


$token
$locals
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
  prog = program()

  offset = 0
  var = prog.locals
  loop do
    break if var.nil?
    offset += 8
    var.offset = offset
    break if var.next.nil?
    var = var.next
  end
  prog.stack_size = offset

  codegen(prog)
end

if __FILE__ == $0
  main()
end
