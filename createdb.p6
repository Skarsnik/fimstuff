use v6;

use lib "./";
use FicClass;
use DBIish;

my $create_story_r;


my $bookshelf_table = 'Create TABLE Bookshelf(';

my Attribute @attrs = Bookshelf.^attributes;
$bookshelf_table ~= plain_attr({primary_key => 'id'}, @attrs);

$bookshelf_table ~= ');';

sub plain_attr(Hash $opt, Attribute @tab) {
  my $str = '';
  my $i = 0;
  for @tab -> $attr {
    #say $attr.name, " : ", $attr.type;
    $str ~= ", " if ($i++ != 0) && ($attr.type ~~ Str | Int | Bool);
    $str ~= $attr.name.substr(2) ~ " varchar(255) " if $attr.type ~~ Str;
    $str ~= $attr.name.substr(2) ~ " Int " if $attr.type ~~ Int;
    $str ~= $attr.name.substr(2) ~ " Boolean " if $attr.type ~~ Bool;
    $str ~= " PRIMARY KEY " if '$!' ~ $opt<primary_key> eq $attr.name;
  }
  return $str;
}

say $bookshelf_table;

my $author_table = 'Create TABLE Author(';

@attrs = Author.^attributes;
$author_table ~= plain_attr({primary_key => 'id'}, @attrs);
$author_table ~= ');';
say $author_table;

my $story_table = 'Create TABLE Story(';

@attrs = Story.^attributes;
$story_table ~= plain_attr({primary_key => 'id'}, @attrs);
$story_table ~~ s:x(1)=\sdescription\svarchar\(255\)=description text=;
$story_table ~= ', author_id Int REFERENCES Author(id),';
$story_table ~= 'tags text[], character_tags text[]);';

say $story_table;


my $chapter_table = 'Create TABLE Chapter(';

@attrs = Chapter.^attributes;
$chapter_table ~= plain_attr({primary_key => 'id'}, @attrs);
$chapter_table ~= ', story_id Int REFERENCES Story(id));';

say $chapter_table;

my $link = 'Create TABLE story_bookshelf(story_id Int REFERENCES Story(id), bookshelf_id Int REFERENCES Bookshelf(id), PRIMARY KEY(story_id, bookshelf_id));';

say $link;

#my $dbh = DBIish.connect("Pg", :host<localhost>, :database<fimstat>, :user<>, :password<>, :RaiseError);

$dbh.do('DROP TABLE if exists Bookshelf CASCADE;');
$dbh.do('DROP TABLE if exists Author CASCADE;');
$dbh.do('DROP TABLE if exists Story CASCADE;');
$dbh.do('DROP TABLE if exists Chapter CASCADE;');
$dbh.do('DROP TABLE if exists story_bookshelf CASCADE;');

$dbh.do($bookshelf_table);
$dbh.do($author_table);
$dbh.do($story_table);
$dbh.do($chapter_table);
$dbh.do($link);




