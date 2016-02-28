use HTTP::UserAgent;
use Gumbo;
use XML;
use JSON::Tiny;
use Config::Simple;

my $loginpage = "http://www.fimfiction.net/ajax/login";
my $feedpage = "http://www.fimfiction.net/feed";
my $storyapipage = "http://www.fimfiction.net/api/story.php";
my $conffile = "fimstuff.ini";
my $conf;
if $conffile.IO.e {
  $conf = Config::Simple.read($conffile, :f<ini>);
} else {
  $conf = Config::Simple.new(:f<ini>);
  $conf.filename = $conffile;
}

class FimFictionStuff {
  has	HTTP::UserAgent $!ua;
  has		@.chapter-history;
  has		@.blog-history;
  has		$logged;
  has		$last-chapter-timestamp = 0;
  has		$last-blog-timestamp = 0;
  has		$first = True;
  
  method BUILD(:$uadebug) {
      $!ua = HTTP::UserAgent.new(:useragent("This A Bot"), :debug($uadebug));
      if $conffile.IO.e {
        $last-chapter-timestamp = $conf<_><lastchapter> if $conf<_>.defined;
        $last-blog-timestamp = $conf<_><lastblog> if $conf<_>.defined;
      }
  }
  
  method login(Str $login, Str $password) {
      my $rep = $!ua.post($loginpage, {username => $login, password => $password});
      return $logged = $rep.is-success;
  }
  
  method fetch-feed() {
      my $rep = $!ua.get($feedpage);
      if $rep.is-success {
         my XML::Document $xml = parse-html($rep.content, :nowhitespace, :TAG<div>, :class(/^feed_item/));
         #say "End parse html";
         for $xml.root.nodes -> $feed_item {
             #say "divchapter";
             my $t = $feed_item.lookfor(:TAG<a>, :class<author>, :SINGLE);
             my $time = $feed_item.lookfor(:TAG<span>, :class<time_offset>, :SINGLE)<data-time>;
             my $author = $t.contents[0].text;
             if $feed_item<class> ~~ /feed_item\s+feed_new_chapter/ {
               my %chapter-info;
               %chapter-info<author> = $author;
               my $storya = $feed_item.lookfor(:TAG<a>, :href(rx/^.story/), :SINGLE);
               %chapter-info<story> = $storya[0].text;
               %chapter-info<time> = $time;
               my $feedbody = $feed_item.lookfor(:TAG<div>, :class<feed_body>, :SINGLE);
               my $a = $feedbody.lookfor(:TAG<a>, :SINGLE);
               %chapter-info<title> = $a.contents[0].text;
               %chapter-info<link> = $a<href>;
               my $wordtext = $feedbody.lookfor(:TAG<span>, :SINGLE).contents[0].text;
               %chapter-info<wordcount> = ($wordtext ~~ /([\d+\,]?\d+)\swords/).Str;
               if $!first or @!chapter-history.elems == 0 or %chapter-info<time> > @!chapter-history.tail(1)[0]<time> {
                  $!first ?? @!chapter-history.unshift(%chapter-info) !! @!chapter-history.push(%chapter-info);
               }
             }
             if $feed_item<class> ~~ /feed_item\s+feed_blog_post/ {
               my %blog-info;
               %blog-info<author> = $author;
               %blog-info<time> = $time;
               my $storya = $feed_item.lookfor(:TAG<a>, :href(rx/^.story/), :SINGLE);
               %blog-info<story> = $storya[0].text if $storya.defined;
               my $feedbody = $feed_item.lookfor(:TAG<div>, :class<feed_body>, :SINGLE);
               my $a = $feedbody.lookfor(:TAG<a>, :SINGLE);
               %blog-info<title> = $a.contents[0].text;
               %blog-info<link> = $a<href>;   
               if $!first or @!blog-history.elems == 0 or %blog-info<time> > @!blog-history.tail(1)[0]<time> {
                 $!first ?? @!blog-history.unshift(%blog-info) !! @!blog-history.push(%blog-info);
               }
             }
         }  
      } else {
	die "Can't get feed page";
      }
      $!first = False;
  }
  
  method look-for-new-chapters returns Bool {
      self.fetch-feed();
      if @!chapter-history.elems > 0 && @!chapter-history.tail(1)[0]<time> > $last-chapter-timestamp {
         $last-chapter-timestamp = @!chapter-history.tail(1)[0]<time>;
         $conf<_><lastchapter> = $last-chapter-timestamp;
         $conf.write;
         return True;
      }
      return False;
  }
  method look-for-new-blogs returns Bool {
      self.fetch-feed();
      if @!blog-history.elems > 0 && @!blog-history.tail(1)[0]<time> > $last-blog-timestamp {
         $last-blog-timestamp = @!blog-history.tail(1)[0]<time>;
         $conf<_><lastblog> = $last-blog-timestamp;
         $conf.write;
         return True;
      }
      return False;
  }
  
}
