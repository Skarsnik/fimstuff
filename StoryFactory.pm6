use v6;

use FicClass;
use JSON::Tiny;
use DBIish;

module StoryFactory {

my $dbh;
my $newstory_req;
my $newbookshelf_req;
my $newauthor_req;
my $newchapter_req;
my $newstory_book_req;
my $updatestory_req;
my $exclude_story = ("author", "chapters", "tags", "character_tags");
my $selectchapter_req;
my $selectstory_req;
my $selectauthor_req;

  sub initDBstuff (Str $server = "localhost", :$user, :$password) is export {
    $dbh = DBIish.connect("Pg", :host($server), :database<fimstat>, :user($user), :password($password), :RaiseError);
    my @tmp = build_insert(Story.^attributes, $exclude_story);
    #say @tmp.perl;
    $newstory_req = $dbh.prepare("INSERT INTO Story(" ~ @tmp[0].chop ~ ", author_id, character_tags, tags) VALUES(" ~ @tmp[1].chop ~ ", ?, ?, ?);");
    $updatestory_req = $dbh.prepare("UPDATE Story SET (" ~ @tmp[0].chop ~ ", author_id, character_tags, tags) = (" ~ @tmp[1].chop ~ ", ?, ?, ?) WHERE id=?;");
    $newbookshelf_req = $dbh.prepare("INSERT INTO Bookshelf(id, name) VALUES(?, ?);");
    $newauthor_req = $dbh.prepare("INSERT INTO Author(id, name) VALUES(?, ?);");
    @tmp = build_insert(Chapter.^attributes, ());
    $newchapter_req = $dbh.prepare("INSERT INTO Chapter(" ~ @tmp[0].chop ~ ", story_id) VALUES(" ~ @tmp[1].chop ~ ", ?);");
    #$updateschapter_req = $dbh.prepare("UPDATE Chapter SET (" ~ @tmp[0].chop ~ ", story_id) = (" ~ @tmp[1].chop ~ ", ?) WHERE id=?;");
    $newstory_book_req = $dbh.prepare("INSERT INTO story_bookshelf(bookshelf_id, story_id) VALUES(?, ?);");
    $selectchapter_req = $dbh.prepare("SELECT * from Chapter WHERE story_id=?");
    $selectstory_req = $dbh.prepare("SELECT * from Story where id=?");
    $selectauthor_req = $dbh.prepare("SELECT * from Author where id=?");
  }
  sub fromJSON(Str $jsonstr) is export returns Story {
    my $json = from-json($jsonstr);
    my $story = Story.new;
    my $rstory = $json<story>;
    $story.id = $rstory<id>;
    $story.title = $rstory<title>;
    $story.url = $rstory<url>;
    $story.upvotes = $rstory<likes>;
    $story.downvotes = $rstory<dislikes>;
    $story.cover = $rstory<full_image>.defined ?? $rstory<full_image> !! '';
    $story.description = $rstory<description>;
    $story.short_description = $rstory<short_description>;
    $story.nb_comment = $rstory<comments>;
    $story.rating = ('E', 'T', 'M')[$rstory<content_rating>];
    $story.views = $rstory<views>;
    
    for $rstory<categories>.keys -> $k {
      $story.tags.push($k) if $rstory<categories>{$k};
    }
    $story.status = $rstory<status>;
    
    for @($rstory<chapters>) -> $chapter {
      my Chapter $newchap = Chapter.new;
      $newchap.id = $chapter<id>;
      $newchap.title = $chapter<title>;
      $newchap.words = $chapter<words>;
      $newchap.views = $chapter<views>;
      $newchap.date_modified = $chapter<date_modified>;
      $story.chapters.push($newchap);
    }
    $story.author = Author.new;
    $story.author.id = $rstory<author><id>;
    $story.author.name = $rstory<author><name>;
    return $story;
  }
  
  sub fromDB(Int $id) returns Story is export {
     $selectstory_req.execute($id);
     #say $selectstory_req.can('column_names');
     my %hash = $selectstory_req.row(:hash);
     return Any if !%hash.defined;
     #say %hash.perl;
     
     $selectauthor_req.execute(%hash<author_id>);
     my $hashref = $selectauthor_req.fetchrow_hashref;
     my $p = $hashref<name>;
     my $s = "$p ".chop;
     %hash<author> = Author.new(id => $hashref<id>.Int, name => $s);
     %hash<author_id> :delete;
     my Story $story = Story.new(|%hash);
     
     $selectchapter_req.execute(%hash<id>);
     while (my %chapter = $selectchapter_req.row(:hash)) {
       %chapter<story_id> :delete;
       $story.chapters.push(Chapter.new(|%chapter));
     }
     
     return $story;
  }
  
  sub build_insert(@tab, @exclude) {
    my $str = '';
    my $str2 = '';
    for @tab -> $attr {
      if ! @exclude.first($attr.name.substr(2)) {
        $str2 ~= '?,';
        $str ~= $attr.name.substr(2) ~ ',';
      }
    }
    return ($str, $str2);
  }
  
  multi sub saveToDB(Author $author) {
    my $rep = $dbh.do("SELECT id FROM Author WHERE id=" ~ $author.id ~ ";");
    $newauthor_req.execute($author.id, $author.name) if $rep eq "0E0";
  }
  
  multi sub saveToDB(Chapter $chapter, Int $story_id) {
    my @values;
    
    for $chapter.^attributes -> $attr {  
        @values.push($attr.get_value($chapter));
    }
    @values.push($story_id);
    $newchapter_req.execute(@values);
  }
  
  multi sub saveToDB(Story $story) is export { 
    my @values;
    for $story.^attributes -> $attr {
      if ! $exclude_story.first($attr.name.substr(2)) {
        @values.push($attr.get_value($story));
      }
    }
    saveToDB($story.author);
    @values.push($story.author.id);
    @values.push($updatestory_req.pg-array-str($story.character_tags));
    @values.push($updatestory_req.pg-array-str($story.tags));
    say @values.perl;
    my $rep = $dbh.do("SELECT id FROM Story WHERE id=" ~ $story.id ~ ";");
    $newstory_req.execute(@values) if $rep eq "0E0";
    $updatestory_req.execute(@values, $story.id) if $rep ne "0E0";
    $dbh.do("DELETE FROM Chapter WHERE story_id=" ~ $story.id ~ ";") if $rep ne "0E0";
    for $story.chapters -> $chapter {
      saveToDB($chapter, $story.id);
    }
  }
  multi sub saveToDB(Bookshelf $bookshelf) is export {
    my $rep = $dbh.do("SELECT id FROM Bookshelf WHERE id=" ~ $bookshelf.id ~ ";");
    $newbookshelf_req.execute($bookshelf.id, $bookshelf.name) if $rep eq "0E0";
    for $bookshelf.stories -> Story $story {
      saveToDB($story);
      $rep = $dbh.do("SELECT * FROM story_bookshelf WHERE bookshelf_id=" ~ $bookshelf.id ~ " AND story_id=" ~ $story.id ~ ';');
      $newstory_book_req.execute($bookshelf.id, $story.id) if $rep eq "0E0";
    }
  }
}
