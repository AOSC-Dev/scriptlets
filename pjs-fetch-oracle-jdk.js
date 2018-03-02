var JDK_DL_PAGE = 'http://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html';
var page = require('webpage').create();
var url = JDK_DL_PAGE;
page.open(url, function(status) {
  if (status != 'success') {
    phantom.exit(1);
  }
  var links = page.evaluate(function() {
    var JDK_VER = '8u162';
    var results = '';
    document.getElementById('agreementjdk-' + JDK_VER + '-oth-JPR-a').click();
    suffixes = ['-linux-arm32-vfp-hflt.tar.gz', '-linux-arm64-vfp-hflt.tar.gz', '-linux-x64.tar.gz'];
    for (var i = 0; i < suffixes.length; i++) {
      console.log('jdk-' + JDK_VER + '-oth-JPRXXXjdk-' + JDK_VER + suffixes[i]);
      var tmp = document.getElementById('jdk-' + JDK_VER + '-oth-JPRXXXjdk-' + JDK_VER + suffixes[i]).href;
      if (!tmp) {
        results += 'err ';
        continue;
      }
      results += (tmp + ' ');
    }
    return results;
  });
  console.log('js-out: ' + links);
  phantom.exit();
});
