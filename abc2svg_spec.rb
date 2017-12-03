load("config.mft.rb")

sourcefiles = Dir["#{$conf[:testsourcefolder]}/*.abc"]
#sourcefiles = $conf[:sourcefiles]

class String
  def cleanfordiff
    self.gsub(/<!-- CreationDate:[^-]*-->/, "").gsub(/<meta name="generator".*\/>/, "")
  end

  def cleandirname(dirname)
    self.gsub(dirname, "")
  end
end

describe "abc2svg commandline" do

  sourcefiles.each do |sourcefilename|
    it "handles #{sourcefilename}" do
      outfilename = File.basename(sourcefilename)

      outfilebase = "#{$conf[:testoutputfolder]}/#{outfilename}"
      outfilebasename = File.basename(outfilebase)
      reffilebase = "#{$conf[:testreferencefolder]}/#{outfilename}"
      difffilebase = "#{$conf[:testdifffolder]}/#{outfilename}"

      # cleanup output folder
      ["err", "html"].each do |ext|
        FileUtils.rm "#{outfilebase}}.#{ext}" rescue nil
      end

      cmd = %Q{#{$conf[:abc2svghome]}/abcnode "#{sourcefilename}" 1> "#{outfilebase}.html" 2> "#{outfilebase}.err"  }
      %x{#{cmd}}

      chrome = $conf[:chrome]

      ext     = "html"
      verdict = {}
      testoutput = File.read("#{outfilebase}.#{ext}").cleanfordiff rescue nil
      testreference = File.read("#{reffilebase}.#{ext}").cleanfordiff rescue testoutput

      unless testreference == testoutput
        if chrome
          fullfile = File.absolute_path("#{outfilebase}.html").gsub(" ", "%20")
          cmd      = %Q{#{chrome} --headless --disable-gpu --screenshot --window-size=#{$conf[:windowsize]} "file://#{fullfile}" &> chrome.log}
          %x{#{cmd}}

          FileUtils.mv "screenshot.png", "#{outfilebase}.png"

          if File.exist?("#{reffilebase}.png")
            cmd            = %Q{pixelmatch "#{outfilebase}.png" "#{reffilebase}.png" "#{difffilebase}.diff.png" 0.1}
            changed_pixels = %x{#{cmd}}
            changed_pixels = changed_pixels.match(/.*pixels:\s*(\d+).*/)[1].to_i
            FileUtils.rm "#{difffilebase}.diff.png" if changed_pixels == 0
            verdict[:changed_pixels] = changed_pixels unless changed_pixels == 0
          end
        end
      end

      ["err", "html"].each do |ext|

        testoutput      = File.read("#{outfilebase}.#{ext}").cleanfordiff.gsub(/^.*#{outfilebasename}/, outfilebasename)
        referenceoutput = File.read("#{reffilebase}.#{ext}").cleanfordiff.gsub(/^.*#{outfilebasename}/, outfilebasename) rescue testoutput

        verdict[:abort] = true if testoutput.include?("*** Abort")
        verdict[ext.to_sym] = "different" unless testoutput == referenceoutput
      end

      expect(verdict).to eq({})
    end
  end

end

