# test-abc2svg-lib

This repository provides an environment to to regression tests for
abc2svg (https://github.com/moinejf/abc2svg)

-   it is implemented this using ruby / rake / spec
-   it uses abcnode to create process a bunch of inputfiles. It captures
    HTML from stdout and log from stderr
-   it uses rspec as unit test framework to compare the results with a
    reference and to examine if the generated html contains "\*\*\*
    Abort“
-   it collects the test cases from a source directory
-   it stores the test-evaluation in a file based on abc2svg
    `git describe`
-   It can process all test cases or selected ones

# prerequisites

-   ruby 2.4.1
-   bundler
-   abc2svg
-   node

# installation

1.  clone this repository to `{wherever}/test-abc2svg-lib`
2.  cd to `{wherever}/test-abc2svg-lib`
3.  install the required ruby gems

    ``` {.sh}
    bundle install 
    ```

4.  install pixelmatch (https://github.com/mapbox/pixelmatch)

    ``` {.sh}
    npm install -g pixelmatch
    ```

5.  create a folder for your testdata, e.g. `{wherever}/test-abc2svg`
6.  cd to `{wherever}/test-abc2svg`
7.  create `{wherever}/test-abc2svg/rakefile.rb`

    ``` {.ruby}
    require '../test-abc2svg-lib/rakefile.rb'
    ```

8.  create `{wherever}/test-abc2svg/config.mft.rb`

    ``` {.ruby}
    testfolder = "."
    $conf      = {
        testoutputfolder:    "#{testfolder}/test-output",
        testreferencefolder: "#{testfolder}/test-reference",
        testresultfolder:    "#{testfolder}/test-results",
        testdifffolder:      "#{testfolder}/test-diff",
        sourcefiles:         Dir["../**/*.abc"].uniq {|f| File.basename(f)}, 
        chrome:              '/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome',

        abc2svghome:         "../abc2svg"
    }
    ```

    Be sure to enter a proper glob patten for `sourcefiles:`

    The entry `chrome:` is optional. It should point to the executeable
    for headless chromee. If it is given we get visual diffs in
    testdifffolder.

9.  initialize

    ``` {.sh}
    rake init    
    ```

10. list available tasks

    ``` {.sh}
    rake 
    ```

11. create first reference

    ``` {.sh}
    rake rspec
    rake buildreference
    ```

12. commit this to git if you wish

# Hints

-   the very first rspec run will flag all examples to fail since there
    is no reference
-   if you take all your available abc files, there might be dupliate
    filenames in diffent folders. The example configuration avoids this
    by `uniq {|f| File.basename(f)}`
-   you need to investigate failing results in `test-output`

# License

This stuff is proviced under the same conditions as abc2svg:

    // abc2svg-core is free software: you can redistribute it and/or modify
    // it under the terms of the GNU Lesser General Public License as published by
    // the Free Software Foundation, either version 3 of the License, or
    // (at your option) any later version.
    //
    // abc2svg-core is distributed in the hope that it will be useful,
    // but WITHOUT ANY WARRANTY; without even the implied warranty of
    // MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    // GNU Lesser General Public License for more details.
