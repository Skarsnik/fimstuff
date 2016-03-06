use v6;
use lib './';

use FicClass;
use StoryFactory;
use DBIish;
use Config::Simple;

use Template::Mojo;

my $basedir = $*PROGRAM.dirname;
my $wwwdir = "wwwgen/";

my $conf = Config::Simple.read("{$basedir}/fimstuff.ini", :f<ini>);

my $dbh = DBIish.connect("Pg", :host<localhost>, :database<fimstat>, :user($conf<database><user>), :password($conf<database><password>), :RaiseError);

my $req = $dbh.prepare("SELECT story from trackedstory;");
$req.execute();
initDBstuff("localhost", :user($conf<database><user>), :password($conf<database><password>));

my %authors;

while (my @row = $req.fetchrow_array) {
  my $stid = @row[0];
  my Story $story = fromDB($stid.Int);
  die "Story descrp does not exist in DB" if (!$story.defined);
  %authors{$story.author.name}.push($story);
}

#say %authors.perl;

my $liststorytt = Template::Mojo.from-file("{$basedir}/wwwtemplates/liststory.tm");
my $flist = open "{$wwwdir}/liststory.html", :w or die "Can't create liststory";
my $html_header = slurp "$basedir/wwwstuff/header.html";
my $html_footer = '</body></html>';

my $footstatst = Template::Mojo.from-file("{$basedir}/wwwtemplates/footer.tm");
my %sparam = (today => Date.today.Str, gtime => 1, p6version => "Perl "~$*PERL.version~" ("~$*PERL.compiler.gist~")");

$flist.print($html_header);
my %param = ( authors => %authors);
#say $liststorytt.render(%param);
$flist.print($liststorytt.render(%param));
$flist.print($footstatst.render(%sparam));
$flist.print($html_footer);
$flist.close();


my @maxs;
my @inits;

my $mt = Template::Mojo.from-file("{$basedir}/wwwtemplates/story.tm");

for %authors.kv -> $key, $value {
  for @($value) -> $s {
     my $time = now;
     say "traiting story: ", $s.title;
     my @rawdata;
     my @finaldata;
     my $id = $s.id;
     $req = $dbh.prepare("SELECT DISTINCT dateu from tracked_story_$id ORDER by dateu;");
     $req.execute();
     next if $req.rows eq "0E0";
     my @dates = $req.fetchall_arrayref;
     say "Last update is {@dates.tail(1)[0]}";
     $req = $dbh.prepare("SELECT numchapter, chapterid from tracked_story_$id WHERE dateu=?;");
     $req.execute(@dates[@dates.elems - 1]);
     
     my Int %chapter_order{Int};
     my @tmp;
     while (@tmp = $req.fetchrow_array) {
        %chapter_order{@tmp[1].Int} = @tmp[0].Int;
     }
     
     for @dates -> $d {
       #say $d;
       $req = $dbh.prepare("SELECT chapterid,views from tracked_story_$id WHERE dateu=?;");
       $req.execute($d);
       while (@tmp = $req.fetchrow_array) {
        @rawdata[%chapter_order{@tmp[0].Int} - 1].push(@tmp[1].Int);
       }
     }
     my $max_size = @rawdata[0].elems;
     #say "Max size : "~$max_size;
     my $i = 0;
     my @maxcol;
     for 0..1000 -> $p {@maxcol[$p] = 0};
     for @rawdata -> $data {
       for 0..($max_size - 1) -> $p {@finaldata[$i][$p] = -1};
       @finaldata[$i][$max_size - $data.elems] = $data[0];
       loop (my $j = $max_size - $data.elems + 1; $j < $max_size; $j++) {
         #say $j, ' - ', $j - ($max_size - $data.elems) + 1;
         @finaldata[$i][$j] = $data[$j - ($max_size - $data.elems)] - $data[$j - ($max_size - $data.elems) - 1];
         if (@finaldata[$i][$j].defined && @maxcol[$j].defined && @finaldata[$i][$j] > @maxcol[$j]) {
           @maxcol[$j] = @finaldata[$i][$j]         
         }
       }
       #say @finaldata[$i].perl;
       $i++;
     }
     my $ftmp = open "{$wwwdir}stats_"~$id~".html", :w;
     $ftmp.print($html_header);
     #say @maxcol.perl;
     %sparam = (story => $s, dates => @dates, data => @finaldata, maxcol => @maxcol);
     $ftmp.print($mt.render(%sparam));
     %sparam = (today => Date.today.Str, gtime => now - $time, p6version => "Perl "~$*PERL.version~" ("~$*PERL.compiler.gist~")");
     $ftmp.print($footstatst.render(%sparam));
     $ftmp.print($html_footer);
     $ftmp.close();
  }
}


