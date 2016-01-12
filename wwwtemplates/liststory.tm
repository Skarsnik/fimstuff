% my (%h) = @_;
% for %h<authors>.kv -> $name, @stories {
<h2><%= $name %></h2>
<table>
% for @stories -> $story {
<tr><td><%= $story.title %></td><td><a href="stats_<%= $story.id %>.html">Stats</a></td></tr>
% }
</table>
% }
