

module FicClass {

  class Author is export is rw {
    has Int $.id;
    has Str $.name;
  }
  
  class Chapter is export is rw {
	has Int $.id; #= qdb:primarykey
	has Str $.title;
	has Int $.words;
	has Int $.views;
	has Int $.date_modified;
   }
  
  class Story is export is rw {
	has Int $.id; #= qdb:primarykey
	has Str $.title;
	has Author $.author;
	has Str $.url;
	has Str $.short_description;
	has Str $.description;

	has Str @.tags;
	has Str @.character_tags;
	has Str $.rating;
	has Str $.status;


	has Str $.cover;
	has Bool $.prequel = False;
	has Int $.prequel_id = 0;
	
	has Int $.downvotes;
	has Int $.upvotes;
	has Int $.nb_comment;
	has Int $.views;
	has Chapter @.chapters;
  }
  
  class Bookshelf is export is rw {
    has Int $.id;
    has Str $.name;
    has Story @.stories;
  } 
}