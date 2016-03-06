use Discord;
use FimFictionStuff;
use Config::Simple;
use NativeCall;
use DateTime::Format;

sub fork is native(Str) returns ulong {*};
sub wait(int32 is rw) is native(Str) returns ulong {*};
sub waitpid(ulong, int32 is rw, int32) is native(Str) returns ulong {*};

say "Started";
my $basedir = $*PROGRAM.dirname ~ "/../";
my $conf = Config::Simple.read("{$basedir}fimstuff.ini", :f('ini'));

my $fim = FimFictionStuff.new(:uadebug($*ERR));
my $disc = Discord::Client.new;
my $qnb = 'Quill & Blade';

die "Can't login to fimfiction" unless $fim.login($conf<FimFiction><login>, $conf<FimFiction><password>);
$disc.login($conf<Discord><login>, $conf<Discord><password>);

my $qnb-channel = $disc.me{$qnb}<qnb-public-sfw>;

#$disc.send-message($qnb-channel, "Hello");

my $last-msg-id = $qnb-channel.last-message-id;
my @imsg;
@imsg = $disc.get-messages($qnb-channel, :after($last-msg-id));
while @imsg.elems > 0 {
  @imsg = $disc.get-messages($qnb-channel,:after($last-msg-id));
  $last-msg-id = @imsg.tail[0].id;
}



react {

  whenever Supply.interval(2) {
    #We only want new message
    my @msg = $disc.get-messages($qnb-channel, :after($last-msg-id));
    for @msg -> $msg {
      if $msg.content ~~ /^"!last"$/ {
        my %chapter = $fim.chapter-history.tail(1)[0];
        my $time = strftime "%A, %B %d at %H:%M", DateTime.new(%chapter<time>.Int);
        my $smsg = "The lastest update ($time) is : %chapter<title> (%chapter<wordcount> words) of %chapter<story> by %chapter<author> -  http://www.fimfiction.net%chapter<link>";
        $disc.send-message($qnb-channel, $smsg);
      }
      if $msg.content ~~ /^"!last-blog"$/ {
        my %blog = $fim.blog-history.tail(1)[0];
        my $time = strftime "%A, %B %d at %H:%M", DateTime.new(%blog<time>.Int);
        my $smsg = "The last blog post ($time) is : %blog<title> by %blog<author> -  http://www.fimfiction.net%blog<link>";
        $disc.send-message($qnb-channel, $smsg);
      }
      #if $msg.content ~~ /^"!last"\s+()/ {
      #  my $smsg = "The lastest update for %chapter<story> ($time) is : %chapter<title> (%chapter<wordcount> words) -  http://www.fimfiction.net%chapter<link>";
      #}
      LAST {
        $last-msg-id = $msg.id;
      }
    }
  }
  whenever Supply.interval(120) {
#     my ulong $pid = fork;
#     if $pid == 0 {
#       say "child $pid";
      try {
      if $fim.look-for-new-chapters {
         my %chapter = $fim.chapter-history.tail(1)[0];
         my $message = "%chapter<author> posted a new chapter of %chapter<story> : %chapter<title> (%chapter<wordcount> words) - https://www.fimfiction.net%chapter<link>";
         say $message;
         $disc.send-message($qnb-channel, $message);
      }
      if $fim.look-for-new-blogs {
         my %blog = $fim.blog-history.tail(1)[0];
         my $message = "%blog<author> posted a new blog %blog<title> - https://www.fimfiction.net%blog<link>";
         say $message;
         $disc.send-message($qnb-channel, $message);
      }
      }
      CATCH {
      }
#     } else {
#       my int32 $status;
#       my int32 $p = 0;
#       say "parent $pid";
#       waitpid($pid, $status, $p);
#       say "Stop waiting";
#     }
  }
}
