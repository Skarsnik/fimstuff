use v6;

use lib './';
use FicClass;
use Gumbo;
use StoryFactory;
use HTTP::UserAgent;
use HTTP::Cookie;
use Config::Simple;

my $bbaseurl = "http://www.fimfiction.net/bookshelf/";
my $fimbaseurl = "http://www.fimfiction.net/";

my $bookid = @*ARGS[0];
my $story_id = @*ARGS[1];

my $conf = Config::Simple.read('fimstuff.ini', :f<ini>);

initDBstuff(:user($conf<database><user>), :password($conf<database><password>));

if ($story_id.defined) {
  my Story $story = get_story($story_id.Int);
  $story.character_tags = "Soarin", "Original Character";
  saveToDB($story);
  return ;
}


my Bookshelf $bookshelf = Bookshelf.new;

$bookshelf.id = $bookid.Int;


my $ua = HTTP::UserAgent.new;
$ua.cookies.set-cookie('Set-Cookie:view_mature=true; ');

my $url = "$bbaseurl$bookid";
get_bookshelf();

saveToDB($bookshelf);
#say $bookshelf.perl;

sub get_story (Int $id) {
    my $surl = "$fimbaseurl" ~ "api/story.php?story=$id";
    say "Getting info for story $id - $surl";
    my $time = time;
    my $rep = $ua.get($surl);
    my $p = $rep.content;
    #my $p = qqx{wget -o /dev/null -O - $surl};
    if False {
      my $timewget = time - $time;
      $time = time;
      #my $rep = $ua.get($surl);
      my $timeua = time - $time;
      $time = time;
      $p = LWP::Simple.get($surl);
      my $timelwp = time - $time;
      say "Request took (wget, ua, lwp) : $timewget ; $timeua ; $timelwp (" ~ $p.defined ~ ")";
    }
    my Story $story = fromJSON($p);
    return $story;
}


sub get_bookshelf {
  my $rep = $ua.get("$bbaseurl$bookid");

  if ! $rep.is-success {
    die "Can't contact $bbaseurl";
  }
  # first we need to know the number of page
  my $xmldoc = parse-html($rep.content, :TAG<div>, :class<page_list>, :SINGLE, :nowhitespace);
  my @pages = $xmldoc.elements(:TAG<li>, :RECURSE);
  my $number_of_page;
  if (@pages.elems eq 1) {
    $number_of_page = 1;
  } else {
    $number_of_page = @pages[@pages.elems-2][0][0].text;
  }

  say "Number of page : $number_of_page";
  for (1..$number_of_page) {
    $rep = $ua.get("$url?order=date_added&page=$_");
    if ! $rep.is-success {
      die "can't get $url?order=date_added&page=$_";
    }
    my $innerdiv = parse-html($rep.content, :TAG<div>, :class<inner>, :SINGLE, :nowhitespace);
    if $_ == 1 {
      my $ul = $innerdiv.elements(:TAG<span>, :class<bookshelf-name>, :SINGLE, :RECURSE);
      $bookshelf.name = $ul[0][0].text;
    }
    my @storydiv = $innerdiv.lookfor(:TAG<div>, :class<story_content_box>);
    for @storydiv -> $storydiv {
      my $idstory = substr($storydiv<id>, 6);
      my Story $story = get_story($idstory.Int);
      my $extradiv = $storydiv.lookfor(:TAG<div>, :class<extra_story_data>, :SINGLE);
      my @charactera = $extradiv.lookfor(:TAG<a>, :class<character_icon>);
      for @charactera -> $aelem {
	$story.character_tags.push($aelem<title>);
      }
      say $story.title;
      #show_mem();
      $bookshelf.stories.push($story);
    }
  }
  
}

sub show_mem {
  say $*PID;
  say slurp("/proc/self/statm");
  #my @statm = slurp("/proc/$*PID/statm").split(/\s+/);
  #say @statm;
}
