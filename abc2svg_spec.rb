
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
        FileUtils.rm "#{$conf[:testoutputfolder]}/#{outfilename}.#{ext}"  rescue nil
      end

      cmd         = %Q{#{$conf[:abc2svghome]}/abcnode "#{sourcefilename}" 1> "#{$conf[:testoutputfolder]}/#{outfilename}.html" 2> "#{$conf[:testoutputfolder]}/#{outfilename}.err"  }
      %x{#{cmd}}



      ["err", "html"].each do |ext|
        referenceoutput = File.read("#{$conf[:testreferencefolder] }/#{outfilename}.#{ext}").cleanfordiff
        testoutput = File.read("#{$conf[:testoutputfolder]}/#{outfilename}.#{ext}").cleanfordiff

        expect(testoutput).not_to include("*** Abort")
        expect(testoutput).to eq referenceoutput
      end

    end
  end

end

