load("config.mft.rb")

sourcefiles = $conf[:sourcefiles]

class String
  def cleanfordiff
    self.gsub(/<!-- CreationDate:[^-]*-->/, "").gsub(/<meta name="generator".*\/>/, "")
  end
end

describe "abc2svg commandline" do

  sourcefiles.each do |sourcefilename|
    it "handles #{sourcefilename}" do
      outfilename = File.basename(sourcefilename)

      ["err", "html"].each do |ext|
        FileUtils.rm "#{$conf[:testoutputfolder]}/#{outfilename}.#{ext}" rescue nil
      end

      cmd = %Q{#{$conf[:abc2svghome]}/abcnode "#{sourcefilename}" 1> "#{$conf[:testoutputfolder]}/#{outfilename}.html" 2> "#{$conf[:testoutputfolder]}/#{outfilename}.err"  }
      %x{#{cmd}}

      chrome = $conf[:chrome]

      ext     = "html"
      verdict = {}
      unless File.read("#{$conf[:testreferencefolder] }/#{outfilename}.#{ext}").cleanfordiff == File.read("#{$conf[:testoutputfolder]}/#{outfilename}.#{ext}").cleanfordiff


        if chrome
          fullfile = File.absolute_path("#{$conf[:testoutputfolder]}/#{outfilename}.html").gsub(" ", "%20")
          cmd      = %Q{#{chrome} --headless --disable-gpu --screenshot --window-size=1280,1696 "file://#{fullfile}" &> chrome.log}
          %x{#{cmd}}

          FileUtils.mv "screenshot.png", "#{$conf[:testoutputfolder]}/#{outfilename}.png"

          if File.exist?("#{$conf[:testreferencefolder]}/#{outfilename}.png")
            cmd            = %Q{pixelmatch "#{$conf[:testoutputfolder]}/#{outfilename}.png" "#{$conf[:testreferencefolder]}/#{outfilename}.png" "#{$conf[:testdifffolder]}/#{outfilename}.diff.png" 0.1}
            changed_pixels = %x{#{cmd}}
            changed_pixels = changed_pixels.match(/.*pixels:\s*(\d+).*/)[1].to_i
            FileUtils.rm "#{$conf[:testdifffolder]}/#{outfilename}.diff.png" if changed_pixels == 0
            verdict[:changed_pixels] = changed_pixels unless changed_pixels == 0
          end
        end
      end

      ["err", "html"].each do |ext|
        referenceoutput = File.read("#{$conf[:testreferencefolder] }/#{outfilename}.#{ext}").cleanfordiff
        testoutput      = File.read("#{$conf[:testoutputfolder]}/#{outfilename}.#{ext}").cleanfordiff

        verdict[:abort] = true if testoutput.include?("*** Abort")
        verdict[ext.to_sym] = "different" unless testoutput == referenceoutput
      end

      expect(verdict).to eq({})
    end
  end

end

