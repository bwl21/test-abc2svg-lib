require 'diff/lcs'
require 'diff/lcs/ldiff'

configfile = "config.mft.rb"

def process_example_argument(args)
  if args[:example]
    example     = "-e #{args[:example]}" if args[:example]
    example_doc = "_#{args[:example]}".gsub(/[^A-Za-z\-_0-9]/, "_")
  else
    example_doc = ""
  end

  return example, example_doc
end


def get_reference_version(referenceversionfile)
  refabc2svgversion = File.read(referenceversionfile).split("reference produced with abc2svg").last.strip rescue "_unknown_"
  "abc2svg-#{refabc2svgversion}"
end


if File.exist?(configfile)
  load("config.mft.rb")
  referenceversionfile = "#{$conf[:testreferencefolder]}/0000_abc2svg_version.txt"
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
        testsourcefolder:    "\#{testfolder}/test-source",
        sourcefiles:         Dir["../**/*.abc"].uniq {|f| File.basename(f)},

        chrome:              '/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome',

        abc2svghome:         "../abc2svg"
    }

       }
  exit
end

chrome = $conf[:chrome]

Rake::TaskManager.record_task_metadata = true

abc2svgversion = "unknown" # need to do this to allocate abcversion
cd $conf[:abc2svghome], verbose: false do
  abc2svgversion = `git describe`.strip
end

refabc2svgversion = get_reference_version(referenceversionfile)


#desc "compile abc2svg"
task :buildabc2svg do
  cd $conf[:abc2svghome] do
    puts `./ninja`
  end
end


desc "execute rspec with given examples"
task :rspec, [:example] => :buildabc2svg do |t, args|

  example, example_doc = process_example_argument(args)

  Dir["test-diff/*"].each{|f| rm f} if example.nil?

  resultfile = "#{$conf[:testresultfolder]}/abc2svg-#{abc2svgversion}/abc2svg-#{abc2svgversion}_vs_#{refabc2svgversion}#{example_doc}.html"


  sh "rspec #{File.dirname(__FILE__)}/abc2svg_spec.rb #{example } -f html --out '#{resultfile}' -f progress" rescue nil
end

desc "copy testresults to reference"
task :buildreference, [:example] do |t, args|
  pattern = "*#{args[:example]}*"
  File.open("#{$conf[:testreferencefolder]}/0000_abc2svg_version.txt", "w") do |f|
    f.puts %Q{reference produced with abc2svg #{abc2svgversion} }
  end

  Dir["#{$conf[:testoutputfolder]}/#{pattern}"].each {|file| cp file, $conf[:testreferencefolder]}
end

# install file tasks to produce reference pngs
Dir[%Q{#{$conf[:testreferencefolder]}/*.html}].each do |f|
  pngfilename = %Q{#{File.dirname(f)}/#{File.basename(f, ".html")}.png}

  file pngfilename => f do |t, args|
    htmlfile = t.source
    fullfile = File.absolute_path("#{htmlfile}").gsub(" ", "%20")

    cmd = %Q{#{chrome} --headless --disable-gpu --screenshot --window-size=#{$conf[:windowsize]} "file://#{fullfile}" &> chrome.log}
    %x{#{cmd}}
    FileUtils.mv "screenshot.png", pngfilename
  end
end


desc "create reference pngs"
task :buildreferencepngs => Dir[%Q{#{$conf[:testreferencefolder]}/*.html}].map {|f| %Q{#{File.dirname(f)}/#{File.basename(f, ".html")}.png}}

desc "show testresult html page"
task :show, [:example] do |t, args|

  example, example_doc, resultfile = process_example_argument(args)

  resultfile = "#{$conf[:testresultfolder]}/abc2svg-#{abc2svgversion}/abc2svg-#{abc2svgversion}_vs_#{refabc2svgversion}#{example_doc}.html"

  cmd = %Q{open "#{resultfile}"}
  `#{cmd}`
end

desc "show the changed png"
task :showpng, [:example] do |t, args|
  pattern     = "*#{args[:example]}*.png"
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

desc "collect sources"
task :buildsources do
  $conf[:sourcefiles].each do |source|
    cp source, $conf[:testsourcefolder]
  end
end

desc "initialize the requested folders"
task :init do
  [:testreferencefolder, :testoutputfolder, :testresultfolder, :testdifffolder, :testsourcefolder].each do |name|
    mkdir_p $conf[name]
  end
end

desc "list avaliable examples"
task :list, [:example] do |t, args|
  pattern = "*#{args[:example]}*"

  puts $conf[:sourcefiles].select {|f| File.fnmatch(pattern, f)}.map {|f| File.basename(f)}
end

task :default do
  tasks     = Rake.application.tasks.select {|t| t.is_a? Rake::Task}
  tasks     = tasks.select {|t| t.comment}
  tasknames = tasks.map {|t| t.name}

  name_width = tasks.map {|t| t.name_with_args.length}.max || 10
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

desc "show the changed png"
task :showdiff, [:example] do |t, args|

  def mk_row(difffilename)
    filename = difffilename.gsub(".diff.", ".")

    referr = File.read(%Q{#{$conf[:testreferencefolder]}/#{File.basename(filename, ".png")}.err})
    outerr = File.read(%Q{#{$conf[:testoutputfolder]}/#{File.basename(filename, ".png")}.err})


    diff_as_html = []
    diff_as_html.push %Q{<p>}
    callback_obj = DiffToHtmlCallbacks.new(diff_as_html)
    xx           = Diff::LCS.traverse_balanced(referr, outerr, callback_obj)
    diff_as_html.push %Q{</p>}
    diff_as_html = diff_as_html.join

    %Q{
       <h1 style="page-break-before: always;">#{filename}</h>
       <table width="100%" border="1">
            <tr valign="top">
               <td width="30%"><img src="../../#{$conf[:testreferencefolder]}/#{filename}" width="100%"></img><p>#{referr.gsub("\n", "<br/>")}</p></td>
               <td width="30%"><img src="../../#{$conf[:testdifffolder]}/#{difffilename}" width="100%">#{diff_as_html.gsub("\n", "<br/>")}</img></td>
               <td width="30%"><img src="../../#{$conf[:testoutputfolder]}/#{filename}" width="100%"></img><p>#{outerr.gsub("\n", "<br/>")}</p></td>
            </tr>
          </table>
    }
  end

  files_to_show = Dir["#{$conf[:testdifffolder]}/*.diff.png"].map{|f| File.basename(f)}

  showfile = "#{$conf[:testresultfolder]}/abc2svg-#{abc2svgversion}/abc2svg-#{abc2svgversion}_vs_#{refabc2svgversion}.diff.html"

  File.open(showfile, "w") do |f|
    f.puts %Q{
        <html>
        <body>
         #{files_to_show.map {|f| mk_row(f)}.join("\n")}
        </body>
      </html>
    }

    cmd = %Q{open "#{showfile}"}
    `#{cmd}`

  end
end


task :help => :default

class DiffToHtmlCallbacks
  attr_accessor :output

  def initialize(output, options = {})
    @output       = output
    @state        = :init
    @line_started = true
    options       ||= {}

    @styles={
        ins: "text-decoration: underline;color:#006622; background-color: #ccffdd; ",
        del: "text-decoration: line-through;color:#ff0000; background-color: #ffe6e6;",
        eq:  ""
    }

  end

  def to_html(element)
    case element
      when "\n"
        result = "<br/>"
        @line_started = true
      when " "
        result = @line_started ? '&nbsp' : " "
      else
        @line_started = false
        result = element.gsub(/[<>&]/, {"\n" => '<br/>', '<' => '&lt;', '>' => '&gt;', '&' => '&amp;'})
    end
    result
  end

  def handle_entry(element, state)
    unless @state == state
      @output.push "</span>" unless @state == :init
      @state = state
      @output.push %Q{<span style="#{@styles[state]}">}
    end

    @output.push(to_html(element))
  end

  private :handle_entry

# This will be called with both lines are the same
  def match(event)
    handle_entry(event.old_element, :eq)
  end

# This will be called when there is a line in A that isn't in B
  def discard_a(event)
    handle_entry(event.old_element, :del)
  end

# This will be called when there is a line in B that isn't in A
  def discard_b(event)
    handle_entry(event.new_element, :ins)
  end

end