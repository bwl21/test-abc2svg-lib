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
        testdifffolder:      "\#{testfolder}/test-diff",
        sourcefiles:         Dir["../**/*.abc"].uniq {|f| File.basename(f)},

        chrome:              '/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome',

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
  sh "rspec #{File.dirname(__FILE__)}/abc2svg_spec.rb #{example } -f html --out '#{$conf[:testresultfolder]}/#{abcversion}.html' -f progress" rescue nil
end

desc "copy testresults to reference"
task :buildreference, [:example]  do |t, args|
  pattern = "*#{args[:example]}*"
  File.open("#{$conf[:testreferencefolder]}/0000_abc2svg_version.txt", "w") do |f|
    f.puts %Q{reference produced with abc2svg #{abcversion} }
  end

  Dir["#{$conf[:testoutputfolder]}/#{pattern}"].each{|file| cp file, $conf[:testreferencefolder]}
end

desc "show testresult html page"
task :show do
  cmd = %Q{open "#{$conf[:testresultfolder]}/#{abcversion}.html"}
  `#{cmd}`
end

desc "show the changed png"
task :showpng, [:example] do |t, args|
  pattern = "*#{args[:example]}*.png"
  diffpattern = "*#{args[:example]}*.diff.png"

  [:testreferencefolder, :testoutputfolder, :testdifffolder].each do |folder|
    files = Dir["#{$conf[folder]}/#{pattern}"]
    files = Dir["#{$conf[folder]}/#{diffpattern}"] if files.empty?

    if files.count == 1
      cmd = %Q{open "#{files.first}"}
      `#{cmd}`
    else
      puts "Should have exactly one file to display! Found #{files.count} files for #{pattern} #{files}"
      exit(0)
    end
  end
end


desc "initialize the requested folders"
task :init do
  [:testreferencefolder, :testoutputfolder, :testresultfolder, :testdifffolder].each do |name|
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