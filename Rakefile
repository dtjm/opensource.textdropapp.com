task :default => [:test]

desc "Watch coffeescripts and compile"
task :coffee do |t|
  sh "coffee -o public/js -w views/*.coffee &"
end