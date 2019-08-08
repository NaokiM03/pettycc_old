def main
  if ARGV.length != 1
    STDERR.puts "#{$0}: invalid number of arguments\n"
    return
  end

  puts(".intel_syntax noprefix\n")
  puts(".global main\n")
  puts("main:\n")
  puts("  mov rax, #{ARGV[0].dup}\n")
  puts("  ret\n")
end

if __FILE__ == $0
  main
end
