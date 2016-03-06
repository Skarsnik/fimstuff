use FimFictionStuff;

my $f = FimFictionStuff.new;
$f.login('ExFerrel', 'ilfaitbeau');

say "New chapter", $f.look-for-new-chapters();

say $f.chapter-history.perl;

say "New blog", $f.look-for-new-blogs();

say $f.blog-history.perl;

