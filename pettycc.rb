def int? str
  str.to_i.to_s == str.to_s
end

def strtol p
  unless int? p[0]
    p.slice!(0)
    return 0
  end

  num =""
  while int? p[0]
    num += p.slice!(0)
  end
  return num
end

def main
  if ARGV.length != 1
    STDERR.puts "#{$0}: invalid number of arguments\n"
    return
  end

  p = ARGV[0].dup

  puts(".intel_syntax noprefix\n")
  puts(".global main\n")
  puts("main:\n")
  puts("  mov rax, #{strtol p}\n")

  while p.length != 0
    if p[0] == "+"
      strtol p
      puts("  add rax, #{strtol p}\n")
      next
    end

    if p[0] == "-"
      strtol p
      puts("  sub rax, #{strtol p}\n")
      next
    end

    STDERR.puts "unexpected character: '#{p[0]}'\n"
    return 1
  end

  puts("  ret\n")
end

if __FILE__ == $0
  main
end
