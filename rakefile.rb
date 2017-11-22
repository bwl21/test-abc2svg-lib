configfile = "config.mft.rb"

if File.exist?(configfile)
  load("config.mft.rb")
else
  puts %Q{
  could not find #{configfile}

  please create a #{configfile} similar to

    testfolder = "."
    $conf      = {
        testoutputfolder:    "\#{testfolder}/test-output",
        testreferencefolder: "\#{testfolder}/test-reference",
        testresultfolder:    "\#{testfolder}/test-results",
        sourcefiles:         Dir["../**/*.abc"].uniq {|f| File.basename(f)},

        abc2svghome:         "../abc2svg"
    }

       }
  exit
end

Rake::TaskManager.record_task_metadata = true

abcversion = "unknown"  # need to do this to allocate abcversion
cd $conf[:abc2svghome], verbose: false do
  abcversion = `git describe`.strip
end

#desc "compile abc2svg"
task :buildabc2svg do
  cd $conf[:abc2svghome] do
    puts `./ninja`
  end
end


desc "execute rspec with given examples"
task :rspec, [:example] => :buildabc2svg do |t, args|
  example = ""
  example = "-e #{args[:example]}" if args[:example]
  sh "rspec #{File.dirname(__FILE__)}/abc2svg_spec.rb #{example } -f html --out '#{$conf[:testresultfolder]}/#{abcversion}.html' -f progress"
end

desc "copy testresults to reference"
task :buildreference, [:example]  do |t, args|
  pattern = "*#{args[:example]}*"
  File.open("#{$conf[:testreferencefolder]}/0000_abcversion.txt", "w") do |f|
    f.puts %Q{reference produced with #{abcversion} }
  end

  Dir["#{$conf[:testoutputfolder]}/#{pattern}"].each{|file| cp file, $conf[:testreferencefolder]}
end

desc "show testresult html page"
task :show do
  cmd = %Q{open "#{$conf[:testresultfolder]}/#{abcversion}.html"}
  `#{cmd}`
end


desc "initialize the requested folders"
task :init do
  [:testreferencefolder, :testoutputfolder, :testresultfolder].each do |name|
    mkdir_p $conf[name]
  end
end

desc "list avaliable examples"
task :list, [:example]  do |t, args|
  pattern = "*#{args[:example]}*"

  puts $conf[:sourcefiles].select{|f| File.fnmatch(pattern, f ) }.map{|f| File.basename(f)}

end

task :default do
  tasks     = Rake.application.tasks.select { |t| t.is_a? Rake::Task }
  tasks     = tasks.select { |t| t.comment }
  tasknames = tasks.map { |t| t.name }

  name_width = tasks.map { |t| t.name_with_args.length }.max || 10
  max_column = Rake.application.terminal_width

  tasks.each do |t|
    printf("rake %-#{name_width}s  # %s\n",
           "#{t.name_with_args}",
           max_column ? Rake.application.truncate(t.comment, max_column) : t.comment)
  end

  puts %Q{
  Example usage:

  rake rspec[9999]  # execute test with example matching *9999*
  rake list [9999]  # list  example matching *9999*

       }
end

task :help => :default